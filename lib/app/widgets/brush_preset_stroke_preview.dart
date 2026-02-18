import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';

import '../../bitmap_canvas/bitmap_canvas.dart';
import '../../brushes/brush_preset.dart';
import '../../canvas/brush_shape_geometry.dart';
import '../../canvas/canvas_tools.dart';
import '../../src/rust/rust_cpu_brush_ffi.dart';

const double _kPreviewPadding = 4.0;

class BrushPresetStrokePreview extends StatefulWidget {
  const BrushPresetStrokePreview({
    super.key,
    required this.preset,
    required this.height,
    required this.color,
  });

  final BrushPreset preset;
  final double height;
  final Color color;

  @override
  State<BrushPresetStrokePreview> createState() =>
      _BrushPresetStrokePreviewState();
}

class _BrushPresetStrokePreviewState extends State<BrushPresetStrokePreview> {
  ui.Image? _image;
  int _signature = 0;
  int _renderToken = 0;

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : widget.height * 3.0;
          final Size size = Size(width, widget.height);
          _ensurePreview(context, size);
          if (_image != null && RustCpuBrushFfi.instance.isSupported) {
            return RawImage(
              image: _image,
              width: size.width,
              height: size.height,
              fit: BoxFit.fill,
              filterQuality: widget.preset.snapToPixel
                  ? FilterQuality.none
                  : FilterQuality.high,
            );
          }
          return CustomPaint(
            painter: _BrushPresetStrokeFallbackPainter(
              preset: widget.preset,
              color: widget.color,
            ),
          );
        },
      ),
    );
  }

  void _ensurePreview(BuildContext context, Size size) {
    if (!RustCpuBrushFfi.instance.isSupported) {
      return;
    }
    if (size.isEmpty) {
      return;
    }
    final double deviceScale =
        MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final double scale = deviceScale.clamp(1.0, 2.0);
    final int pixelWidth = (size.width * scale).round();
    final int pixelHeight = (size.height * scale).round();
    if (pixelWidth <= 0 || pixelHeight <= 0) {
      return;
    }
    final BrushPreset preset = widget.preset.sanitized();
    final int nextSignature = Object.hash(
      pixelWidth,
      pixelHeight,
      preset.id,
      preset.shape,
      preset.spacing,
      preset.hardness,
      preset.flow,
      preset.scatter,
      preset.randomRotation,
      preset.smoothRotation,
      preset.rotationJitter,
      preset.antialiasLevel,
      preset.hollowEnabled,
      preset.hollowRatio,
      preset.autoSharpTaper,
      preset.snapToPixel,
      widget.color.value,
      scale,
    );
    if (nextSignature == _signature) {
      return;
    }
    _signature = nextSignature;
    final int token = ++_renderToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _renderPreview(token, preset, pixelWidth, pixelHeight, scale);
    });
  }

  Future<void> _renderPreview(
    int token,
    BrushPreset preset,
    int pixelWidth,
    int pixelHeight,
    double scale,
  ) async {
    if (!mounted || token != _renderToken) {
      return;
    }
    final ui.Image? image = await _buildPreviewImage(
      preset: preset,
      color: widget.color,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
      scale: scale,
    );
    if (!mounted || token != _renderToken) {
      image?.dispose();
      return;
    }
    setState(() {
      _image?.dispose();
      _image = image;
    });
  }
}

class _PreviewStrokeSample {
  const _PreviewStrokeSample({
    required this.position,
    required this.radius,
  });

  final Offset position;
  final double radius;
}

Future<ui.Image?> _buildPreviewImage({
  required BrushPreset preset,
  required Color color,
  required int pixelWidth,
  required int pixelHeight,
  required double scale,
}) async {
  if (!RustCpuBrushFfi.instance.isSupported) {
    return null;
  }
  if (pixelWidth <= 0 || pixelHeight <= 0) {
    return null;
  }
  final BitmapSurface surface = BitmapSurface(
    width: pixelWidth,
    height: pixelHeight,
    fillColor: const Color(0x00000000),
  );
  try {
    final double padding = _kPreviewPadding * scale;
    final double width = pixelWidth - padding * 2.0;
    final double height = pixelHeight - padding * 2.0;
    if (width <= 0 || height <= 0) {
      return null;
    }

    final Offset start = Offset(padding, padding + height * 0.65);
    final Offset control1 =
        Offset(padding + width * 0.3, padding + height * 0.1);
    final Offset control2 =
        Offset(padding + width * 0.65, padding + height * 0.9);
    final Offset end = Offset(padding + width, padding + height * 0.35);

    final ui.Path path = ui.Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        end.dx,
        end.dy,
      );
    final ui.PathMetrics metrics = path.computeMetrics();
    final Iterator<ui.PathMetric> iterator = metrics.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    final ui.PathMetric metric = iterator.current;

    final double baseRadius = math.max(2.2 * scale, height * 0.2);
    final double spacing = _effectiveSpacing(preset.spacing);
    final double step = math.max(0.1 * scale, baseRadius * 2.0 * spacing);
    final double totalLength = metric.length;
    final int maxStamps = math.max(6, (totalLength / step).ceil());
    final List<_PreviewStrokeSample> samples = <_PreviewStrokeSample>[];
    for (int i = 0; i <= maxStamps; i++) {
      final double distance = math.min(totalLength, i * step);
      final ui.Tangent? tangent = metric.getTangentForOffset(distance);
      if (tangent == null) {
        continue;
      }
      double radius = baseRadius;
      if (preset.autoSharpTaper && totalLength > 0.0001) {
        final double t = distance / totalLength;
        radius *= (0.5 + 0.5 * math.sin(math.pi * t));
      }
      if (!radius.isFinite || radius <= 0.0) {
        continue;
      }
      samples.add(_PreviewStrokeSample(position: tangent.position, radius: radius));
    }
    if (samples.isEmpty) {
      return null;
    }

    final double hardness = preset.hardness;
    final double flow = preset.flow;
    final double opacity = (0.25 + 0.75 * flow * (0.35 + 0.65 * hardness))
        .clamp(0.18, 1.0);
    final Color strokeColor = color.withOpacity(
      (color.opacity * opacity).clamp(0.0, 1.0),
    );
    final double softness = (1.0 - hardness).clamp(0.0, 1.0);
    final int antialias = _effectiveAntialias(preset.antialiasLevel);
    final int rotationSeed = Object.hash(
      preset.id,
      preset.shape,
      pixelWidth,
      pixelHeight,
    );

    _drawStrokeSegments(
      surface: surface,
      samples: samples,
      preset: preset,
      color: strokeColor,
      softness: softness,
      antialias: antialias,
      spacing: spacing,
      rotationSeed: rotationSeed,
      erase: false,
      radiusScale: 1.0,
    );

    final bool hollow =
        preset.hollowEnabled && preset.hollowRatio > 0.0001;
    if (hollow) {
      _drawStrokeSegments(
        surface: surface,
        samples: samples,
        preset: preset,
        color: strokeColor,
        softness: softness,
        antialias: antialias,
        spacing: spacing,
        rotationSeed: rotationSeed,
        erase: true,
        radiusScale: preset.hollowRatio.clamp(0.0, 1.0),
      );
    }

    if (surface.isClean) {
      return null;
    }
    final Uint8List rgba = _argbToRgba(surface.pixels);
    return _decodeRgbaImage(rgba, pixelWidth, pixelHeight);
  } finally {
    surface.dispose();
  }
}

double _effectiveSpacing(double spacing) {
  double value = spacing.isFinite ? spacing : 0.15;
  return value.clamp(0.02, 2.5);
}

int _effectiveAntialias(int level) {
  int aa = level.clamp(0, 9);
  if (kIsWeb && aa > 1) {
    aa = 1;
  }
  return aa;
}

void _drawStrokeSegments({
  required BitmapSurface surface,
  required List<_PreviewStrokeSample> samples,
  required BrushPreset preset,
  required Color color,
  required double softness,
  required int antialias,
  required double spacing,
  required int rotationSeed,
  required bool erase,
  required double radiusScale,
}) {
  if (samples.isEmpty) {
    return;
  }
  final double scatter = preset.scatter;
  final bool randomRotation = preset.randomRotation;
  final bool smoothRotation = preset.smoothRotation;
  final double rotationJitter = preset.rotationJitter;
  final bool snapToPixel = preset.snapToPixel;
  final BrushShape shape = preset.shape;

  final _PreviewStrokeSample first = samples.first;
  _drawStampSegment(
    surface: surface,
    start: first.position,
    end: first.position,
    startRadius: first.radius * radiusScale,
    endRadius: first.radius * radiusScale,
    color: color,
    shape: shape,
    antialias: antialias,
    includeStart: true,
    erase: erase,
    randomRotation: randomRotation,
    smoothRotation: smoothRotation,
    rotationSeed: rotationSeed,
    rotationJitter: rotationJitter,
    spacing: spacing,
    scatter: scatter,
    softness: softness,
    snapToPixel: snapToPixel,
  );

  for (int i = 0; i < samples.length - 1; i++) {
    final _PreviewStrokeSample a = samples[i];
    final _PreviewStrokeSample b = samples[i + 1];
    _drawStampSegment(
      surface: surface,
      start: a.position,
      end: b.position,
      startRadius: a.radius * radiusScale,
      endRadius: b.radius * radiusScale,
      color: color,
      shape: shape,
      antialias: antialias,
      includeStart: false,
      erase: erase,
      randomRotation: randomRotation,
      smoothRotation: smoothRotation,
      rotationSeed: rotationSeed,
      rotationJitter: rotationJitter,
      spacing: spacing,
      scatter: scatter,
      softness: softness,
      snapToPixel: snapToPixel,
    );
  }
}

void _drawStampSegment({
  required BitmapSurface surface,
  required Offset start,
  required Offset end,
  required double startRadius,
  required double endRadius,
  required Color color,
  required BrushShape shape,
  required int antialias,
  required bool includeStart,
  required bool erase,
  required bool randomRotation,
  required bool smoothRotation,
  required int rotationSeed,
  required double rotationJitter,
  required double spacing,
  required double scatter,
  required double softness,
  required bool snapToPixel,
}) {
  final bool ok = RustCpuBrushFfi.instance.drawStampSegment(
    pixelsPtr: surface.pointerAddress,
    pixelsLen: surface.pixels.length,
    width: surface.width,
    height: surface.height,
    startX: start.dx,
    startY: start.dy,
    endX: end.dx,
    endY: end.dy,
    startRadius: startRadius,
    endRadius: endRadius,
    colorArgb: color.value,
    brushShape: shape.index,
    antialiasLevel: antialias,
    includeStart: includeStart,
    erase: erase,
    randomRotation: randomRotation,
    smoothRotation: smoothRotation,
    rotationSeed: rotationSeed,
    rotationJitter: rotationJitter,
    spacing: spacing,
    scatter: scatter,
    softness: softness,
    snapToPixel: snapToPixel,
    accumulate: true,
    selectionMask: null,
  );
  if (ok) {
    surface.markDirty();
  }
}

Uint8List _argbToRgba(Uint32List pixels) {
  final Uint8List rgba = Uint8List(pixels.length * 4);
  for (int i = 0; i < pixels.length; i++) {
    final int argb = pixels[i];
    final int offset = i * 4;
    rgba[offset] = (argb >> 16) & 0xff;
    rgba[offset + 1] = (argb >> 8) & 0xff;
    rgba[offset + 2] = argb & 0xff;
    rgba[offset + 3] = (argb >> 24) & 0xff;
  }
  return rgba;
}

Future<ui.Image> _decodeRgbaImage(
  Uint8List bytes,
  int width,
  int height,
) {
  final Completer<ui.Image> completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    bytes,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

class _BrushPresetStrokeFallbackPainter extends CustomPainter {
  _BrushPresetStrokeFallbackPainter({
    required BrushPreset preset,
    required this.color,
  })  : shape = preset.shape,
        spacing = _sanitizeDouble(preset.spacing, 0.15, 0.02, 2.5),
        hardness = _sanitizeDouble(preset.hardness, 0.8, 0.0, 1.0),
        flow = _sanitizeDouble(preset.flow, 1.0, 0.0, 1.0),
        scatter = _sanitizeDouble(preset.scatter, 0.0, 0.0, 1.0),
        randomRotation = preset.randomRotation,
        smoothRotation = preset.smoothRotation,
        rotationJitter = _sanitizeDouble(preset.rotationJitter, 1.0, 0.0, 1.0),
        antialiasLevel = preset.antialiasLevel.clamp(0, 9),
        hollowEnabled = preset.hollowEnabled,
        hollowRatio = _sanitizeDouble(preset.hollowRatio, 0.0, 0.0, 1.0),
        autoSharpTaper = preset.autoSharpTaper,
        snapToPixel = preset.snapToPixel;

  final Color color;
  final BrushShape shape;
  final double spacing;
  final double hardness;
  final double flow;
  final double scatter;
  final bool randomRotation;
  final bool smoothRotation;
  final double rotationJitter;
  final int antialiasLevel;
  final bool hollowEnabled;
  final double hollowRatio;
  final bool autoSharpTaper;
  final bool snapToPixel;

  static double _sanitizeDouble(
    double value,
    double fallback,
    double min,
    double max,
  ) {
    if (!value.isFinite) {
      return fallback;
    }
    return value.clamp(min, max);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final double padding = _kPreviewPadding;
    final double width = size.width - padding * 2;
    final double height = size.height - padding * 2;
    if (width <= 0 || height <= 0) {
      return;
    }

    final Offset start = Offset(padding, padding + height * 0.65);
    final Offset control1 =
        Offset(padding + width * 0.3, padding + height * 0.1);
    final Offset control2 =
        Offset(padding + width * 0.65, padding + height * 0.9);
    final Offset end = Offset(padding + width, padding + height * 0.35);

    final ui.Path path = ui.Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        end.dx,
        end.dy,
      );
    final ui.PathMetrics metrics = path.computeMetrics();
    final Iterator<ui.PathMetric> iterator = metrics.iterator;
    if (!iterator.moveNext()) {
      return;
    }
    final ui.PathMetric metric = iterator.current;

    final double baseRadius = math.max(2.2, height * 0.2);
    final double step = math.max(0.1, baseRadius * 2.0 * spacing);
    final double totalLength = metric.length;
    final int maxStamps = math.max(6, (totalLength / step).ceil());

    final double opacity = (0.25 + 0.75 * flow * (0.35 + 0.65 * hardness))
        .clamp(0.18, 1.0);
    final Color strokeColor = color.withOpacity(
      (color.opacity * opacity).clamp(0.0, 1.0),
    );
    final Paint paint = Paint()
      ..color = strokeColor
      ..style = hollowEnabled ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = hollowEnabled
          ? math.max(1.0, baseRadius * (1.0 - hollowRatio).clamp(0.2, 0.9))
          : 1.0
      ..isAntiAlias = antialiasLevel > 0;

    for (int i = 0; i <= maxStamps; i++) {
      final double distance = math.min(totalLength, i * step);
      final ui.Tangent? tangent = metric.getTangentForOffset(distance);
      if (tangent == null) {
        continue;
      }
      double radius = baseRadius;
      if (autoSharpTaper) {
        final double t = distance / totalLength;
        radius *= (0.5 + 0.5 * math.sin(math.pi * t));
      }
      if (!radius.isFinite || radius <= 0.0) {
        continue;
      }

      Offset position = tangent.position;
      if (scatter > 0.0) {
        final double scatterRadius = radius * 2.0 * scatter;
        if (scatterRadius > 0.0001) {
          final double u = _noise(i + 3);
          final double v = _noise(i + 7);
          final double dist = math.sqrt(u) * scatterRadius;
          final double angle = v * math.pi * 2.0;
          position = position.translate(
            math.cos(angle) * dist,
            math.sin(angle) * dist,
          );
        }
      }
      if (snapToPixel) {
        position = Offset(
          position.dx.floor() + 0.5,
          position.dy.floor() + 0.5,
        );
        radius = (radius * 2.0).round() * 0.5;
        if (radius <= 0.0) {
          continue;
        }
      }

      double rotation = 0.0;
      if (shape != BrushShape.circle && smoothRotation) {
        rotation = math.atan2(tangent.vector.dy, tangent.vector.dx);
      }
      if (randomRotation && shape != BrushShape.circle) {
        rotation += _noise(i + 11) * math.pi * 2.0 * rotationJitter;
      }

      canvas.save();
      canvas.translate(position.dx, position.dy);
      if (rotation != 0.0) {
        canvas.rotate(rotation);
      }
      final ui.Path stamp = BrushShapeGeometry.pathFor(
        shape,
        Offset.zero,
        radius,
      );
      canvas.drawPath(stamp, paint);
      canvas.restore();
    }
  }

  double _noise(int seed) {
    final double value = math.sin(seed * 12.9898 + 78.233) * 43758.5453;
    return value - value.floor();
  }

  @override
  bool shouldRepaint(covariant _BrushPresetStrokeFallbackPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.shape != shape ||
        oldDelegate.spacing != spacing ||
        oldDelegate.hardness != hardness ||
        oldDelegate.flow != flow ||
        oldDelegate.scatter != scatter ||
        oldDelegate.randomRotation != randomRotation ||
        oldDelegate.smoothRotation != smoothRotation ||
        oldDelegate.rotationJitter != rotationJitter ||
        oldDelegate.antialiasLevel != antialiasLevel ||
        oldDelegate.hollowEnabled != hollowEnabled ||
        oldDelegate.hollowRatio != hollowRatio ||
        oldDelegate.autoSharpTaper != autoSharpTaper ||
        oldDelegate.snapToPixel != snapToPixel;
  }
}
