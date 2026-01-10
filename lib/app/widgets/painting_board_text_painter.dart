part of 'painting_board.dart';

class _TextPreviewPainter extends CustomPainter {
  const _TextPreviewPainter({
    required this.renderer,
    required this.data,
    required this.bounds,
    required this.scale,
  });

  final CanvasTextRenderer renderer;
  final CanvasTextData data;
  final Rect bounds;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale, scale);
    canvas.translate(-bounds.left, -bounds.top);
    renderer.paint(canvas, data);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TextPreviewPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.bounds != bounds ||
        oldDelegate.scale != scale;
  }
}
