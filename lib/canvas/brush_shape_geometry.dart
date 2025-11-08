import 'dart:math' as math;
import 'dart:ui';

import 'canvas_tools.dart';

class BrushShapeGeometry {
  BrushShapeGeometry._();

  static const double _sqrt3Over2 = 0.8660254037844386;

  static List<Offset> polygonFor(
    BrushShape shape,
    Offset center,
    double radius,
  ) {
    switch (shape) {
      case BrushShape.square:
        return _squareVertices(center, radius);
      case BrushShape.triangle:
        return _triangleVertices(center, radius);
      case BrushShape.circle:
        return const <Offset>[];
    }
  }

  static Path pathFor(BrushShape shape, Offset center, double radius) {
    final Path path = Path();
    switch (shape) {
      case BrushShape.circle:
        path.addOval(Rect.fromCircle(center: center, radius: radius));
        break;
      case BrushShape.square:
      case BrushShape.triangle:
        final List<Offset> vertices = polygonFor(shape, center, radius);
        if (vertices.isEmpty) {
          path.addOval(Rect.fromCircle(center: center, radius: radius));
          break;
        }
        path.moveTo(vertices.first.dx, vertices.first.dy);
        for (int i = 1; i < vertices.length; i++) {
          final Offset vertex = vertices[i];
          path.lineTo(vertex.dx, vertex.dy);
        }
        path.close();
        break;
    }
    return path;
  }

  static Rect boundsFor(BrushShape shape, Offset center, double radius) {
    switch (shape) {
      case BrushShape.circle:
        return Rect.fromCircle(center: center, radius: radius);
      case BrushShape.square:
      case BrushShape.triangle:
        final List<Offset> vertices = polygonFor(shape, center, radius);
        if (vertices.isEmpty) {
          return Rect.fromCircle(center: center, radius: radius);
        }
        double minX = vertices.first.dx;
        double maxX = vertices.first.dx;
        double minY = vertices.first.dy;
        double maxY = vertices.first.dy;
        for (final Offset vertex in vertices.skip(1)) {
          minX = math.min(minX, vertex.dx);
          maxX = math.max(maxX, vertex.dx);
          minY = math.min(minY, vertex.dy);
          maxY = math.max(maxY, vertex.dy);
        }
        return Rect.fromLTRB(minX, minY, maxX, maxY);
    }
  }

  static List<Offset> _squareVertices(Offset center, double radius) {
    final double clamped = math.max(radius.abs(), 0.0);
    final double halfSide = clamped <= 0 ? 0.0 : clamped / math.sqrt2;
    if (halfSide <= 0) {
      return <Offset>[center];
    }
    return <Offset>[
      Offset(center.dx - halfSide, center.dy - halfSide),
      Offset(center.dx + halfSide, center.dy - halfSide),
      Offset(center.dx + halfSide, center.dy + halfSide),
      Offset(center.dx - halfSide, center.dy + halfSide),
    ];
  }

  static List<Offset> _triangleVertices(Offset center, double radius) {
    final double clamped = math.max(radius.abs(), 0.0);
    if (clamped <= 0) {
      return <Offset>[center];
    }
    final double halfBase = clamped * _sqrt3Over2;
    final double topY = center.dy - clamped;
    final double baseY = center.dy + clamped * 0.5;
    return <Offset>[
      Offset(center.dx, topY),
      Offset(center.dx + halfBase, baseY),
      Offset(center.dx - halfBase, baseY),
    ];
  }
}
