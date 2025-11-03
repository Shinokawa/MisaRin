import 'dart:typed_data';
import 'dart:ui' as ui;

import 'canvas_layer.dart';
import 'canvas_settings.dart';
import 'stroke_painter.dart';

class CanvasExporter {
  Future<Uint8List> exportToPng({
    required CanvasSettings settings,
    required List<CanvasLayerData> layers,
    int? maxDimension,
    ui.Size? outputSize,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    final double baseWidth = settings.width;
    final double baseHeight = settings.height;
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
          ? baseWidth
          : baseHeight;
      if (longestSide > 0) {
        scale = maxDimension / longestSide;
      }
    }
    if (scale <= 0) {
      scale = 1.0;
    }
    final double outputWidth = targetSize != null
        ? targetSize.width
        : (baseWidth * scale).clamp(1, double.infinity);
    final double outputHeight = targetSize != null
        ? targetSize.height
        : (baseHeight * scale).clamp(1, double.infinity);
    final StrokePictureCache cache = StrokePictureCache(
      logicalSize: ui.Size(baseWidth, baseHeight),
    );
    cache.sync(layers: layers, showCheckerboard: false);
    final StrokePainter painter = StrokePainter(
      cache: cache,
      cacheVersion: cache.version,
      currentStroke: null,
      currentStrokeVersion: 0,
      scale: scale,
    );

    painter.paint(canvas, ui.Size(outputWidth, outputHeight));
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(
      outputWidth.round(),
      outputHeight.round(),
    );
    cache.dispose();
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) {
      throw StateError('导出 PNG 时发生未知错误');
    }
    return byteData.buffer.asUint8List();
  }
}
