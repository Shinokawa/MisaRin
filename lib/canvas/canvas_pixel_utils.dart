import 'dart:typed_data';

Uint32List rgbaToPixels(Uint8List rgba, int width, int height) {
  final int length = width * height;
  final Uint32List pixels = Uint32List(length);
  for (int i = 0; i < length; i++) {
    final int offset = i * 4;
    final int r = rgba[offset];
    final int g = rgba[offset + 1];
    final int b = rgba[offset + 2];
    final int a = rgba[offset + 3];
    pixels[i] = (a << 24) | (r << 16) | (g << 8) | b;
  }
  return pixels;
}
