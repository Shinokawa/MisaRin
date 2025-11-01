import 'dart:ui';

import 'package:flutter/rendering.dart';

class StrokePainter extends CustomPainter {
  const StrokePainter({
    required this.strokes,
    required this.backgroundColor,
    required this.viewportOffset,
    this.strokeColor = const Color(0xFF000000),
    this.strokeWidth = 3,
  });

  final List<List<Offset>> strokes;
  final Color backgroundColor;
  final Offset viewportOffset;
  final Color strokeColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint background = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, background);

    canvas.save();
    canvas.translate(viewportOffset.dx, viewportOffset.dy);

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
