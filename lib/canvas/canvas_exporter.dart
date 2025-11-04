import 'dart:typed_data';
import 'dart:ui' as ui;

import '../bitmap_canvas/bitmap_canvas.dart';
import 'canvas_layer.dart';
import 'canvas_settings.dart';

class CanvasExporter {
  Future<Uint8List> exportToPng({
    required CanvasSettings settings,
    required List<CanvasLayerData> layers,
    int? maxDimension,
    ui.Size? outputSize,
  }) async {
    final int baseWidth = settings.width.round();
    final int baseHeight = settings.height.round();
    if (baseWidth <= 0 || baseHeight <= 0) {
      throw ArgumentError('画布尺寸必须大于 0');
    }

    double scale = 1.0;
    ui.Size? targetSize = outputSize;
    if (targetSize != null) {
      if (targetSize.width <= 0 || targetSize.height <= 0) {
        throw ArgumentError('输出尺寸必须大于 0');
      }
      final double widthScale = targetSize.width / baseWidth;
      final double heightScale = targetSize.height / baseHeight;
      if ((widthScale - heightScale).abs() > 1e-4) {
        throw ArgumentError('输出尺寸必须与画布保持相同长宽比');
      }
      scale = widthScale;
    } else if (maxDimension != null && maxDimension > 0) {
      final double longestSide = baseWidth > baseHeight
          ? baseWidth.toDouble()
          : baseHeight.toDouble();
      if (longestSide > 0) {
        scale = maxDimension / longestSide;
      }
    }
    if (scale <= 0) {
      scale = 1.0;
    }

    final int outputWidth = targetSize != null
        ? targetSize.width.round().clamp(1, 100000)
        : (baseWidth * scale).round().clamp(1, 100000);
    final int outputHeight = targetSize != null
        ? targetSize.height.round().clamp(1, 100000)
        : (baseHeight * scale).round().clamp(1, 100000);

    final BitmapSurface composite = _compositeLayers(
      width: baseWidth,
      height: baseHeight,
      layers: layers,
    );

    final Uint8List rgba = _surfaceToRgba(composite);
    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
      rgba,
    );
    final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: baseWidth,
      height: baseHeight,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final ui.Codec codec = await descriptor.instantiateCodec();
    buffer.dispose();
    final ui.FrameInfo frame = await codec.getNextFrame();
    ui.Image image = frame.image;
    codec.dispose();

    if (outputWidth != baseWidth || outputHeight != baseHeight) {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, baseWidth.toDouble(), baseHeight.toDouble()),
        ui.Rect.fromLTWH(0, 0, outputWidth.toDouble(), outputHeight.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.none,
      );
      final ui.Picture picture = recorder.endRecording();
      final ui.Image scaled = await picture.toImage(outputWidth, outputHeight);
      image.dispose();
      image = scaled;
    }

    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    if (byteData == null) {
      throw StateError('导出 PNG 时发生未知错误');
    }
    return byteData.buffer.asUint8List();
  }

  BitmapSurface _compositeLayers({
    required int width,
    required int height,
    required List<CanvasLayerData> layers,
  }) {
    final List<_PreparedLayer> prepared = <_PreparedLayer>[];
    for (final CanvasLayerData layer in layers) {
      if (!layer.visible) {
        continue;
      }
      prepared.add(
        _PreparedLayer(
          pixels: _buildLayerPixels(layer, width, height),
          opacity: _clampUnit(layer.opacity),
          clippingMask: layer.clippingMask,
          blendMode: layer.blendMode,
        ),
      );
    }

    final Uint32List composite = Uint32List(width * height);
    final Uint8List clipMask = Uint8List(width * height);

    for (int index = 0; index < composite.length; index++) {
      clipMask[index] = 0;
      int color = 0;
      bool initialized = false;
      for (final _PreparedLayer layer in prepared) {
        final double layerOpacity = layer.opacity;
        if (layerOpacity <= 0) {
          if (!layer.clippingMask) {
            clipMask[index] = 0;
          }
          continue;
        }
        final int src = layer.pixels[index];
        final int srcA = (src >> 24) & 0xff;
        if (!layer.clippingMask && srcA == 0) {
          clipMask[index] = 0;
        }
        if (srcA == 0) {
          continue;
        }

        double totalOpacity = layerOpacity;
        if (layer.clippingMask) {
          final int maskAlpha = clipMask[index];
          if (maskAlpha == 0) {
            continue;
          }
          totalOpacity *= maskAlpha / 255.0;
          if (totalOpacity <= 0) {
            continue;
          }
        }

        int effectiveA = (srcA * totalOpacity).round();
        if (effectiveA <= 0) {
          if (!layer.clippingMask) {
            clipMask[index] = 0;
          }
          continue;
        }
        effectiveA = effectiveA.clamp(0, 255);

        if (!layer.clippingMask) {
          clipMask[index] = effectiveA;
        }

        final int effectiveColor = (effectiveA << 24) | (src & 0x00FFFFFF);
        if (!initialized) {
          color = effectiveColor;
          initialized = true;
        } else {
          color = _blendWithMode(color, effectiveColor, layer.blendMode);
        }
      }
      composite[index] = initialized ? color : 0;
    }

    final BitmapSurface base = BitmapSurface(width: width, height: height);
    base.pixels.setAll(0, composite);
    return base;
  }

  Uint8List _surfaceToRgba(BitmapSurface surface) {
    final Uint8List rgba = Uint8List(surface.pixels.length * 4);
    for (int i = 0; i < surface.pixels.length; i++) {
      final int argb = surface.pixels[i];
      final int offset = i * 4;
      rgba[offset] = (argb >> 16) & 0xff;
      rgba[offset + 1] = (argb >> 8) & 0xff;
      rgba[offset + 2] = argb & 0xff;
      rgba[offset + 3] = (argb >> 24) & 0xff;
    }
    return rgba;
  }
}

class _PreparedLayer {
  _PreparedLayer({
    required this.pixels,
    required this.opacity,
    required this.clippingMask,
    required this.blendMode,
  });

  final Uint32List pixels;
  final double opacity;
  final bool clippingMask;
  final CanvasLayerBlendMode blendMode;
}

Uint32List _buildLayerPixels(CanvasLayerData layer, int width, int height) {
  final Uint32List pixels = Uint32List(width * height);
  if (layer.bitmap != null &&
      layer.bitmapWidth == width &&
      layer.bitmapHeight == height) {
    final Uint8List bitmap = layer.bitmap!;
    for (int i = 0; i < pixels.length; i++) {
      final int offset = i * 4;
      final int r = bitmap[offset];
      final int g = bitmap[offset + 1];
      final int b = bitmap[offset + 2];
      final int a = bitmap[offset + 3];
      pixels[i] = (a << 24) | (r << 16) | (g << 8) | b;
    }
  } else if (layer.fillColor != null) {
    final int encoded = _encodeColor(layer.fillColor!);
    for (int i = 0; i < pixels.length; i++) {
      pixels[i] = encoded;
    }
  }
  return pixels;
}

double _clampUnit(double value) {
  if (value <= 0) {
    return 0;
  }
  if (value >= 1) {
    return 1;
  }
  return value;
}

int _blendWithMode(int dst, int src, CanvasLayerBlendMode mode) {
  switch (mode) {
    case CanvasLayerBlendMode.normal:
      return _blendArgb(dst, src);
    case CanvasLayerBlendMode.multiply:
      return _blendMultiply(dst, src);
  }
}

int _blendArgb(int dst, int src) {
  final int srcA = (src >> 24) & 0xff;
  if (srcA == 0) {
    return dst;
  }
  if (srcA == 255) {
    return src;
  }

  final int dstA = (dst >> 24) & 0xff;
  final int invSrcA = 255 - srcA;
  final int outA = srcA + _mul255(dstA, invSrcA);
  if (outA == 0) {
    return 0;
  }

  final int srcR = (src >> 16) & 0xff;
  final int srcG = (src >> 8) & 0xff;
  final int srcB = src & 0xff;
  final int dstR = (dst >> 16) & 0xff;
  final int dstG = (dst >> 8) & 0xff;
  final int dstB = dst & 0xff;

  final int srcPremR = _mul255(srcR, srcA);
  final int srcPremG = _mul255(srcG, srcA);
  final int srcPremB = _mul255(srcB, srcA);
  final int dstPremR = _mul255(dstR, dstA);
  final int dstPremG = _mul255(dstG, dstA);
  final int dstPremB = _mul255(dstB, dstA);

  final int outPremR = srcPremR + _mul255(dstPremR, invSrcA);
  final int outPremG = srcPremG + _mul255(dstPremG, invSrcA);
  final int outPremB = srcPremB + _mul255(dstPremB, invSrcA);

  final int outR = _clampToByte(((outPremR * 255) + (outA >> 1)) ~/ outA);
  final int outG = _clampToByte(((outPremG * 255) + (outA >> 1)) ~/ outA);
  final int outB = _clampToByte(((outPremB * 255) + (outA >> 1)) ~/ outA);

  return (outA << 24) | (outR << 16) | (outG << 8) | outB;
}

int _blendMultiply(int dst, int src) {
  final int srcA = (src >> 24) & 0xff;
  if (srcA == 0) {
    return dst;
  }

  final int dstA = (dst >> 24) & 0xff;
  final double sa = srcA / 255.0;
  final double da = dstA / 255.0;
  final double outA = sa + da * (1 - sa);

  final int srcR = (src >> 16) & 0xff;
  final int srcG = (src >> 8) & 0xff;
  final int srcB = src & 0xff;
  final int dstR = (dst >> 16) & 0xff;
  final int dstG = (dst >> 8) & 0xff;
  final int dstB = dst & 0xff;

  double blendComponent(int sr, int dr) {
    final double srcNorm = sr / 255.0;
    final double dstNorm = dr / 255.0;
    return dstNorm * (1 - sa) + dstNorm * srcNorm * sa;
  }

  final int outR = _clampToByte((blendComponent(srcR, dstR) * 255).round());
  final int outG = _clampToByte((blendComponent(srcG, dstG) * 255).round());
  final int outB = _clampToByte((blendComponent(srcB, dstB) * 255).round());
  final int outAlpha = _clampToByte((outA * 255).round());

  return (outAlpha << 24) | (outR << 16) | (outG << 8) | outB;
}

int _mul255(int channel, int alpha) {
  return (channel * alpha + 127) ~/ 255;
}

int _clampToByte(int value) {
  if (value <= 0) {
    return 0;
  }
  if (value >= 255) {
    return 255;
  }
  return value;
}

int _encodeColor(ui.Color color) {
  return (color.alpha << 24) |
      (color.red << 16) |
      (color.green << 8) |
      color.blue;
}
