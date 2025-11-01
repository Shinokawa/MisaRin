import 'package:flutter/rendering.dart';

class StrokePainter extends CustomPainter {
  const StrokePainter({required this.strokes});

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint background = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(Offset.zero & size, background);

    final Paint strokePaint = Paint()
      ..color = const Color(0xFF000000)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) {
        continue;
      }
      for (int index = 0; index < stroke.length - 1; index++) {
        canvas.drawLine(stroke[index], stroke[index + 1], strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) => true;
}
