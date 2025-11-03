import 'dart:ui';

import 'bitmap_canvas.dart';

/// Demonstrates how to construct a bitmap surface, draw a stroke, and
/// apply a bucket fill. This helper is not wired into the UI yet but
/// serves as a reference for future integration.
BitmapSurface createSampleBitmap() {
  final BitmapSurface surface = BitmapSurface(
    width: 512,
    height: 512,
    fillColor: const Color(0xFFFFFFFF),
  );
  final BitmapPainter painter = BitmapPainter(surface);

  painter.drawStroke(
    points: const [
      Offset(80, 80),
      Offset(430, 100),
      Offset(420, 420),
      Offset(100, 430),
    ],
    radius: 6,
    color: const Color(0xFF3366FF),
  );

  painter.floodFill(
    start: const Offset(256, 256),
    color: const Color(0xFFFFD54F),
  );

  return surface;
}
