import 'dart:typed_data';

/// 对 RGBA8888 像素进行就地预乘，以满足 Flutter 对预乘 alpha 的要求。
void premultiplyRgbaInPlace(Uint8List pixels) {
  for (int i = 0; i < pixels.length; i += 4) {
    final int alpha = pixels[i + 3];
    if (alpha == 0) {
      pixels[i] = 0;
      pixels[i + 1] = 0;
      pixels[i + 2] = 0;
      continue;
    }
    if (alpha == 255) {
      continue;
    }
    pixels[i] = ((pixels[i] * alpha) + 127) ~/ 255;
    pixels[i + 1] = ((pixels[i + 1] * alpha) + 127) ~/ 255;
    pixels[i + 2] = ((pixels[i + 2] * alpha) + 127) ~/ 255;
  }
}
