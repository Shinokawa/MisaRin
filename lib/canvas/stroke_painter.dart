import 'dart:ui';

import 'package:flutter/rendering.dart';

class StrokePainter extends CustomPainter {
  const StrokePainter({
    required this.strokes,
    required this.backgroundColor,
    this.scale = 1.0,
    this.strokeColor = const Color(0xFF000000),
    this.strokeWidth = 3,
  });

  final List<List<Offset>> strokes;
  final Color backgroundColor;
  final double scale;
  final Color strokeColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final double effectiveScale = scale;
    final Size logicalSize = effectiveScale == 0
        ? size
        : Size(size.width / effectiveScale, size.height / effectiveScale);

    canvas.save();
    if (effectiveScale != 1.0 && effectiveScale != 0) {
      canvas.scale(effectiveScale);
    }

    final Paint background = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & logicalSize, background);

    final Paint strokePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) {
        if (stroke.length == 1) {
          canvas.drawPoints(PointMode.points, stroke, strokePaint);
        }
        continue;
      }
      for (int index = 0; index < stroke.length - 1; index++) {
        canvas.drawLine(stroke[index], stroke[index + 1], strokePaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) => true;
}
