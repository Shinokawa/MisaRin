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

/// 对 BGRA8888 像素进行就地预乘（B,G,R,A），以满足 Flutter 对预乘 alpha 的要求。
void premultiplyBgraInPlace(Uint8List pixels) {
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

/// 将预乘 alpha 的 RGBA8888 像素还原为 straight alpha（未预乘）格式。
///
/// Flutter 的 `ui.Image.toByteData(format: rawRgba)` 返回的是预乘 alpha 的 RGBA，
/// 而本项目内部像素管线使用的是 straight alpha（RGB 未预乘）。
void unpremultiplyRgbaInPlace(Uint8List pixels) {
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
    pixels[i] = ((pixels[i] * 255) + (alpha >> 1)) ~/ alpha;
    pixels[i + 1] = ((pixels[i + 1] * 255) + (alpha >> 1)) ~/ alpha;
    pixels[i + 2] = ((pixels[i + 2] * 255) + (alpha >> 1)) ~/ alpha;
  }
}
