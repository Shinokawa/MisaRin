import 'dart:math' as math;
import 'dart:ui';

import 'canvas_tools.dart';
import 'brush_shape_geometry.dart';

class VectorStrokePainter {
  static void paint({
    required Canvas canvas,
    required List<Offset> points,
    required List<double> radii,
    required Color color,
    required BrushShape shape,
    int antialiasLevel = 1,
    bool hollow = false,
    double hollowRatio = 0.0,
    Color hollowFillColor = const Color(0x00000000),
  }) {
    if (points.isEmpty) return;

    final int clampedAntialias = antialiasLevel.clamp(0, 3);
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = clampedAntialias > 0;

    if (clampedAntialias > 1) {
      // Simulate the "softer" look of higher legacy AA levels
      // Level 2 -> sigma 0.6
      // Level 3 -> sigma 1.2
      final double sigma = (clampedAntialias - 1) * 0.6;
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
    }

    final double ratio = hollowRatio.clamp(0.0, 1.0);
    final bool useHollow = hollow && ratio > 0.0001;
    if (!useHollow) {
      if (shape == BrushShape.circle) {
        _paintCircleStroke(canvas, points, radii, paint);
      } else {
        _paintStampStroke(canvas, points, radii, paint, shape);
      }
      return;
    }

    // Outer stroke (outline color)
    if (shape == BrushShape.circle) {
      _paintCircleStroke(canvas, points, radii, paint);
    } else {
      _paintStampStroke(canvas, points, radii, paint, shape);
    }

    // Cut out the inner stroke (hollow area)
    final Paint clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.fill
      ..isAntiAlias = clampedAntialias > 0;
    if (clampedAntialias > 1) {
      final double sigma = (clampedAntialias - 1) * 0.6;
      clearPaint.maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
    }
    if (shape == BrushShape.circle) {
      _paintCircleStroke(
        canvas,
        points,
        radii,
        clearPaint,
        radiusScale: ratio,
      );
    } else {
      _paintStampStroke(
        canvas,
        points,
        radii,
        clearPaint,
        shape,
        radiusScale: ratio,
      );
    }

    // Optional fill for the hollow interior.
    if (((hollowFillColor.a * 255.0).round() & 0xff) != 0) {
      final Paint fillPaint = Paint()
        ..color = hollowFillColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = clampedAntialias > 0;
      if (clampedAntialias > 1) {
        final double sigma = (clampedAntialias - 1) * 0.6;
        fillPaint.maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
      }
      if (shape == BrushShape.circle) {
        _paintCircleStroke(
          canvas,
          points,
          radii,
          fillPaint,
          radiusScale: ratio,
        );
      } else {
        _paintStampStroke(
          canvas,
          points,
          radii,
          fillPaint,
          shape,
          radiusScale: ratio,
        );
      }
    }
  }

  static void _paintCircleStroke(
    Canvas canvas,
    List<Offset> points,
    List<double> radii,
    Paint paint,
    {double radiusScale = 1.0}
  ) {
    for (int i = 0; i < points.length; i++) {
      final Offset p = points[i];
      final double r = (i < radii.length)
          ? radii[i]
          : (radii.isNotEmpty ? radii.last : 1.0);
      canvas.drawCircle(p, r * radiusScale, paint);
    }

    for (int i = 0; i < points.length - 1; i++) {
      final Offset p1 = points[i];
      final Offset p2 = points[i+1];
      final double rawR1 = (i < radii.length)
          ? radii[i]
          : (radii.isNotEmpty ? radii.last : 1.0);
      final double rawR2 = (i + 1 < radii.length) ? radii[i + 1] : rawR1;
      final double r1 = rawR1 * radiusScale;
      final double r2 = rawR2 * radiusScale;
      
      final double dist = (p2 - p1).distance;
      if (dist < 0.5 || dist <= (r1 - r2).abs()) continue;

      final Offset direction = (p2 - p1) / dist;
      final double angle = direction.direction;
      
      // sin(alpha) = (r1 - r2) / d
      final double sinAlpha = (r1 - r2) / dist;
      final double alpha = math.asin(sinAlpha.clamp(-1.0, 1.0));
      
      final double angle1 = angle + math.pi / 2 + alpha;
      final double angle2 = angle - math.pi / 2 - alpha;
      
      final Offset startL = p1 + Offset(math.cos(angle1), math.sin(angle1)) * r1;
      final Offset startR = p1 + Offset(math.cos(angle2), math.sin(angle2)) * r1;
      final Offset endL = p2 + Offset(math.cos(angle1), math.sin(angle1)) * r2;
      final Offset endR = p2 + Offset(math.cos(angle2), math.sin(angle2)) * r2;
      
      final Path segment = Path()
        ..moveTo(startL.dx, startL.dy)
        ..lineTo(endL.dx, endL.dy)
        ..lineTo(endR.dx, endR.dy)
        ..lineTo(startR.dx, startR.dy)
        ..close();
      
      canvas.drawPath(segment, paint);
    }
  }

  static void _paintStampStroke(
    Canvas canvas,
    List<Offset> points,
    List<double> radii,
    Paint paint,
    BrushShape shape,
    {double radiusScale = 1.0}
  ) {
    // Use a denser stamping for shapes to avoid gaps, but not too dense to kill performance
    // For vector drawing, we can just draw at every point if they are dense enough.
    // But if points are sparse (e.g. fast movement), we need to interpolate.
    
    if (points.isEmpty) return;

    // Draw first point
    _drawShapeAt(canvas, points.first, radii.first * radiusScale, paint, shape);

    for (int i = 0; i < points.length - 1; i++) {
      final Offset p1 = points[i];
      final Offset p2 = points[i+1];
      final double rawR1 = radii[i];
      final double rawR2 = (i + 1 < radii.length) ? radii[i + 1] : rawR1;
      final double r1 = rawR1 * radiusScale;
      final double r2 = rawR2 * radiusScale;
      
      final double dist = (p2 - p1).distance;
      if (dist <= 0.1) continue;

      // Determine step size based on radius. Smaller radius needs denser steps.
      // 0.2 * radius provides decent coverage.
      final double maxRadius = math.max(r1, r2);
      final double stepSize = math.max(0.5, maxRadius * 0.25); 
      
      final int steps = (dist / stepSize).ceil();
      
      for (int s = 1; s <= steps; s++) {
        final double t = s / steps;
        final Offset pos = Offset.lerp(p1, p2, t)!;
        final double r = lerpDouble(r1, r2, t)!;
        _drawShapeAt(canvas, pos, r, paint, shape);
      }
    }
  }

  static void _drawShapeAt(Canvas canvas, Offset center, double radius, Paint paint, BrushShape shape) {
    if (shape == BrushShape.square) {
      final Rect rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawRect(rect, paint);
    } else if (shape == BrushShape.triangle) {
      // Equilateral triangle inscribed in circle of radius
      // Pointing up? Or following direction?
      // Standard BrushShapeGeometry usually assumes static orientation unless rotation is supported.
      // Let's stick to static orientation for now as per standard brush behavior in this app
      final Path path = Path();
      final double r = radius;
      // Top vertex
      path.moveTo(center.dx, center.dy - r);
      // Bottom right
      path.lineTo(center.dx + r * 0.866, center.dy + r * 0.5);
      // Bottom left
      path.lineTo(center.dx - r * 0.866, center.dy + r * 0.5);
      path.close();
      canvas.drawPath(path, paint);
    }
  }
}
