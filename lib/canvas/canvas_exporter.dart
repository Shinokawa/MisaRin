import 'dart:typed_data';
import 'dart:ui' as ui;

import 'canvas_settings.dart';
import 'stroke_painter.dart';

class CanvasExporter {
  Future<Uint8List> exportToPng({
    required CanvasSettings settings,
    required List<List<ui.Offset>> strokes,
    int? maxDimension,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    final double baseWidth = settings.width;
    final double baseHeight = settings.height;
    double scale = 1.0;
    if (maxDimension != null && maxDimension > 0) {
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
    final double outputWidth = (baseWidth * scale).clamp(1, double.infinity);
    final double outputHeight = (baseHeight * scale).clamp(1, double.infinity);
    final StrokePainter painter = StrokePainter(
      strokes: strokes,
      backgroundColor: settings.backgroundColor,
      scale: scale,
    );

    painter.paint(canvas, ui.Size(outputWidth, outputHeight));
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(
      outputWidth.round(),
      outputHeight.round(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) {
      throw StateError('导出 PNG 时发生未知错误');
    }
    return byteData.buffer.asUint8List();
  }
}
