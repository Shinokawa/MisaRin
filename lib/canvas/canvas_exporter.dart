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
    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
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

    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
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
    final BitmapSurface base = BitmapSurface(width: width, height: height);
    for (final CanvasLayerData layer in layers) {
      if (!layer.visible) {
        continue;
      }
      if (layer.fillColor != null) {
        base.fill(layer.fillColor!);
      }
      if (layer.bitmap != null &&
          layer.bitmapWidth == width &&
          layer.bitmapHeight == height) {
        _blendBitmap(base, layer.bitmap!);
      }
    }
    return base;
  }

  void _blendBitmap(BitmapSurface target, Uint8List rgba) {
    final Uint32List dst = target.pixels;
    for (int i = 0; i < dst.length; i++) {
      final int offset = i * 4;
      final int r = rgba[offset];
      final int g = rgba[offset + 1];
      final int b = rgba[offset + 2];
      final int a = rgba[offset + 3];
      if (a == 0) {
        continue;
      }
      final int x = i % target.width;
      final int y = i ~/ target.width;
      target.blendPixel(x, y, ui.Color.fromARGB(a, r, g, b));
    }
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
