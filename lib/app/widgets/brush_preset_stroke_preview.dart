import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';

import '../../brushes/brush_preset.dart';
import '../../canvas/brush_shape_geometry.dart';
import '../../canvas/canvas_tools.dart';

class BrushPresetStrokePreview extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _BrushPresetStrokePainter(preset: preset, color: color),
      ),
    );
  }
}

class _BrushPresetStrokePainter extends CustomPainter {
  _BrushPresetStrokePainter({
    required BrushPreset preset,
    required this.color,
  })  : shape = preset.shape,
        spacing = _sanitizeDouble(preset.spacing, 0.15, 0.02, 2.5),
        hardness = _sanitizeDouble(preset.hardness, 0.8, 0.0, 1.0),
        flow = _sanitizeDouble(preset.flow, 1.0, 0.0, 1.0),
        scatter = _sanitizeDouble(preset.scatter, 0.0, 0.0, 1.0),
        randomRotation = preset.randomRotation,
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
    final double padding = 4;
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
      if (shape != BrushShape.circle) {
        rotation = math.atan2(tangent.vector.dy, tangent.vector.dx);
      }
      if (randomRotation) {
        rotation = _noise(i + 11) * math.pi * 2;
      } else if (rotationJitter > 0.001) {
        rotation += rotationJitter * 0.6 * math.sin(i * 0.7);
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
  bool shouldRepaint(covariant _BrushPresetStrokePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.shape != shape ||
        oldDelegate.spacing != spacing ||
        oldDelegate.hardness != hardness ||
        oldDelegate.flow != flow ||
        oldDelegate.scatter != scatter ||
        oldDelegate.randomRotation != randomRotation ||
        oldDelegate.rotationJitter != rotationJitter ||
        oldDelegate.antialiasLevel != antialiasLevel ||
        oldDelegate.hollowEnabled != hollowEnabled ||
        oldDelegate.hollowRatio != hollowRatio ||
        oldDelegate.autoSharpTaper != autoSharpTaper ||
        oldDelegate.snapToPixel != snapToPixel;
  }
}
