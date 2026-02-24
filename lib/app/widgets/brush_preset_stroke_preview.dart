import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';

import '../../bitmap_canvas/bitmap_canvas.dart';
import '../../brushes/brush_library.dart';
import '../../brushes/brush_preset.dart';
import '../../brushes/brush_shape_library.dart';
import '../../brushes/brush_shape_raster.dart';
import '../../canvas/brush_random_rotation.dart';
import '../../canvas/brush_shape_geometry.dart';
import '../../canvas/canvas_tools.dart';
import '../debug/brush_preset_timeline.dart';
import '../../src/rust/rust_cpu_brush_ffi.dart';

const double _kPreviewPadding = 4.0;
const bool _kPreviewLog = bool.fromEnvironment(
  'MISA_RIN_BRUSH_PREVIEW_LOG',
  defaultValue: false,
);

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
          final bool rustSupported = RustCpuBrushFfi.instance.isSupported;
          if (_image != null && rustSupported) {
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
          if (kIsWeb) {
            return CustomPaint(
              painter: _BrushPresetStrokeFallbackPainter(
                preset: widget.preset,
                color: widget.color,
              ),
            );
          }
          return const SizedBox();
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
    final int nextSignature = Object.hashAll(<Object?>[
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
      preset.screentoneEnabled,
      preset.screentoneSpacing,
      preset.screentoneDotSize,
      preset.screentoneRotation,
      preset.screentoneSoftness,
      widget.color.value,
      scale,
    ]);
    if (nextSignature == _signature) {
      return;
    }
    if (_kPreviewLog) {
      debugPrint(
        '[brush-preview] schedule id=${preset.id} '
        'size=${pixelWidth}x${pixelHeight} scale=$scale '
        'aa=${preset.antialiasLevel} snap=${preset.snapToPixel} '
        'hardness=${preset.hardness} flow=${preset.flow} '
        'shape=${preset.shape} rustSupported=${RustCpuBrushFfi.instance.isSupported}',
      );
    }
    _signature = nextSignature;
    if (BrushPresetTimeline.enabled) {
      BrushPresetTimeline.mark(
        'preview_schedule id=${preset.id} ${pixelWidth}x${pixelHeight} scale=$scale',
      );
    }
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
    final Stopwatch? stopwatch = BrushPresetTimeline.enabled
        ? (Stopwatch()..start())
        : null;
    final ui.Image? image = await _buildPreviewImage(
      preset: preset,
      color: widget.color,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
      scale: scale,
    );
    if (stopwatch != null) {
      BrushPresetTimeline.mark(
        'preview_done id=${preset.id} ${pixelWidth}x${pixelHeight} '
        't=${stopwatch.elapsedMilliseconds}ms image=${image != null}',
      );
    }
    if (_kPreviewLog) {
      debugPrint(
        '[brush-preview] done id=${preset.id} image=${image != null} '
        'aa=${preset.antialiasLevel} snap=${preset.snapToPixel}',
      );
    }
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
    final Stopwatch? shapeTimer = BrushPresetTimeline.enabled
        ? (Stopwatch()..start())
        : null;
    final BrushShapeRaster? customShape = await _resolveCustomShape(preset);
    if (shapeTimer != null && shapeTimer.elapsedMilliseconds > 0) {
      BrushPresetTimeline.mark(
        'preview_shape id=${preset.resolvedShapeId} '
        't=${shapeTimer.elapsedMilliseconds}ms',
      );
    }
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
      customShape: customShape,
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
        customShape: customShape,
      );
    }

    if (_kPreviewLog) {
      final _AlphaStats stats = _computeAlphaStats(surface.pixels);
      debugPrint(
        '[brush-preview] alpha id=${preset.id} aa=$antialias '
        'nonZero=${stats.nonZero} partial=${stats.partial} '
        'min=${stats.min} max=${stats.max}',
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

Future<BrushShapeRaster?> _resolveCustomShape(BrushPreset preset) async {
  final BrushShapeLibrary shapes = BrushLibrary.instance.shapeLibrary;
  final String shapeId = preset.resolvedShapeId;
  if (shapes.isBuiltInId(shapeId)) {
    return null;
  }
  return shapes.loadRaster(shapeId);
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
  BrushShapeRaster? customShape,
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
  final bool screentoneEnabled = preset.screentoneEnabled;
  final double screentoneSpacing = preset.screentoneSpacing;
  final double screentoneDotSize = preset.screentoneDotSize;
  final double screentoneRotation = preset.screentoneRotation;
  final double screentoneSoftness = preset.screentoneSoftness;

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
    screentoneEnabled: screentoneEnabled,
    screentoneSpacing: screentoneSpacing,
    screentoneDotSize: screentoneDotSize,
    screentoneRotation: screentoneRotation,
    screentoneSoftness: screentoneSoftness,
    customShape: customShape,
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
      screentoneEnabled: screentoneEnabled,
      screentoneSpacing: screentoneSpacing,
      screentoneDotSize: screentoneDotSize,
      screentoneRotation: screentoneRotation,
      screentoneSoftness: screentoneSoftness,
      customShape: customShape,
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
  required bool screentoneEnabled,
  required double screentoneSpacing,
  required double screentoneDotSize,
  required double screentoneRotation,
  required double screentoneSoftness,
  BrushShapeRaster? customShape,
}) {
  if (customShape != null) {
    _drawCustomStampSegment(
      surface: surface,
      shape: customShape,
      start: start,
      end: end,
      startRadius: startRadius,
      endRadius: endRadius,
      color: color,
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
      screentoneEnabled: screentoneEnabled,
      screentoneSpacing: screentoneSpacing,
      screentoneDotSize: screentoneDotSize,
      screentoneRotation: screentoneRotation,
      screentoneSoftness: screentoneSoftness,
    );
    return;
  }
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
    screentoneEnabled: screentoneEnabled,
    screentoneSpacing: screentoneSpacing,
    screentoneDotSize: screentoneDotSize,
    screentoneRotation: screentoneRotation,
    screentoneSoftness: screentoneSoftness,
    accumulate: true,
    selectionMask: null,
  );
  if (ok) {
    surface.markDirty();
  }
}

void _drawCustomStampSegment({
  required BitmapSurface surface,
  required BrushShapeRaster shape,
  required Offset start,
  required Offset end,
  required double startRadius,
  required double endRadius,
  required Color color,
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
  required bool screentoneEnabled,
  required double screentoneSpacing,
  required double screentoneDotSize,
  required double screentoneRotation,
  required double screentoneSoftness,
}) {
  final double distance = (end - start).distance;
  if (!distance.isFinite || distance <= 0.0001) {
    final double rotation = _customStampRotation(
      center: end,
      start: start,
      end: end,
      randomRotation: randomRotation,
      smoothRotation: smoothRotation,
      rotationSeed: rotationSeed,
      rotationJitter: rotationJitter,
    );
    surface.drawCustomBrushStamp(
      shape: shape,
      center: end,
      radius: endRadius,
      color: color,
      erase: erase,
      softness: softness,
      rotation: rotation,
      snapToPixel: snapToPixel,
    );
    return;
  }
  final double maxRadius = math.max(
    math.max(startRadius.abs(), endRadius.abs()),
    0.01,
  );
  final double step = _strokeStampSpacing(maxRadius, spacing);
  final int samples = math.max(1, (distance / step).ceil());
  final int startIndex = includeStart ? 0 : 1;
  for (int i = startIndex; i <= samples; i++) {
    final double t = samples == 0 ? 1.0 : (i / samples);
    final double radius = ui.lerpDouble(startRadius, endRadius, t) ?? endRadius;
    final double sampleX = ui.lerpDouble(start.dx, end.dx, t) ?? end.dx;
    final double sampleY = ui.lerpDouble(start.dy, end.dy, t) ?? end.dy;
    final Offset baseCenter = Offset(sampleX, sampleY);
    final double scatterRadius = maxRadius * scatter.clamp(0.0, 1.0) * 2.0;
    final Offset jitter = scatterRadius > 0
        ? brushScatterOffset(
            center: baseCenter,
            seed: rotationSeed,
            radius: scatterRadius,
            salt: i,
          )
        : Offset.zero;
    final Offset center = baseCenter + jitter;
    final double rotation = _customStampRotation(
      center: center,
      start: start,
      end: end,
      randomRotation: randomRotation,
      smoothRotation: smoothRotation,
      rotationSeed: rotationSeed,
      rotationJitter: rotationJitter,
    );
    surface.drawCustomBrushStamp(
      shape: shape,
      center: center,
      radius: radius,
      color: color,
      erase: erase,
      softness: softness,
      rotation: rotation,
      snapToPixel: snapToPixel,
    );
  }
}

double _customStampRotation({
  required Offset center,
  required Offset start,
  required Offset end,
  required bool randomRotation,
  required bool smoothRotation,
  required int rotationSeed,
  required double rotationJitter,
}) {
  double rotation = 0.0;
  if (smoothRotation) {
    final Offset delta = end - start;
    if (delta.distanceSquared > 0.0001) {
      rotation = math.atan2(delta.dy, delta.dx);
    }
  }
  if (randomRotation) {
    rotation += brushRandomRotationRadians(center: center, seed: rotationSeed) *
        rotationJitter;
  }
  return rotation;
}

double _strokeStampSpacing(double radius, double spacing) {
  double r = radius.isFinite ? radius.abs() : 0.0;
  double s = spacing.isFinite ? spacing : 0.15;
  if (kIsWeb) {
    s *= 2.0;
  }
  s = s.clamp(0.02, 2.5);
  return math.max(r * 2.0 * s, 0.1);
}

class _AlphaStats {
  const _AlphaStats({
    required this.nonZero,
    required this.partial,
    required this.min,
    required this.max,
  });

  final int nonZero;
  final int partial;
  final int min;
  final int max;
}

_AlphaStats _computeAlphaStats(Uint32List pixels) {
  int nonZero = 0;
  int partial = 0;
  int minAlpha = 255;
  int maxAlpha = 0;
  for (final int argb in pixels) {
    final int alpha = (argb >> 24) & 0xff;
    if (alpha == 0) {
      continue;
    }
    nonZero += 1;
    if (alpha < minAlpha) {
      minAlpha = alpha;
    }
    if (alpha > maxAlpha) {
      maxAlpha = alpha;
    }
    if (alpha < 255) {
      partial += 1;
    }
  }
  if (nonZero == 0) {
    minAlpha = 0;
    maxAlpha = 0;
  }
  return _AlphaStats(
    nonZero: nonZero,
    partial: partial,
    min: minAlpha,
    max: maxAlpha,
  );
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
