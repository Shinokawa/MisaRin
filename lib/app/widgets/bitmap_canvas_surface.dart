import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../canvas/canvas_frame.dart';
import '../../canvas/canvas_tile.dart';

class BitmapCanvasSurface extends StatelessWidget {
  const BitmapCanvasSurface({
    super.key,
    required this.canvasSize,
    required this.frame,
  });

  final ui.Size canvasSize;
  final CanvasFrame? frame;

  @override
  Widget build(BuildContext context) {
    final CanvasFrame? frame = this.frame;
    return SizedBox(
      width: canvasSize.width,
      height: canvasSize.height,
      child: CustomPaint(
        painter: _BitmapCanvasPainter(frame),
      ),
    );
  }
}

class _BitmapCanvasPainter extends CustomPainter {
  _BitmapCanvasPainter(this.frame);

  final CanvasFrame? frame;

  @override
  void paint(Canvas canvas, Size size) {
    final CanvasFrame? frame = this.frame;
    if (frame == null) {
      return;
    }
    final Paint paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none;
    for (final CanvasTile tile in frame.tiles) {
      canvas.drawImageRect(
        tile.image,
        tile.sourceRect,
        tile.destinationRect,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BitmapCanvasPainter oldDelegate) {
    final CanvasFrame? nextFrame = frame;
    final CanvasFrame? previousFrame = oldDelegate.frame;
    if (identical(nextFrame, previousFrame)) {
      return false;
    }
    if (nextFrame == null || previousFrame == null) {
      return true;
    }
    return nextFrame.generation != previousFrame.generation;
  }
}
