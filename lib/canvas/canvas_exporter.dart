import 'dart:typed_data';
import 'dart:ui' as ui;

import 'canvas_settings.dart';
import 'stroke_painter.dart';

class CanvasExporter {
  Future<Uint8List> exportToPng({
    required CanvasSettings settings,
    required List<List<ui.Offset>> strokes,
    required ui.Offset viewportOffset,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    final StrokePainter painter = StrokePainter(
      strokes: strokes,
      backgroundColor: settings.backgroundColor,
      viewportOffset: viewportOffset,
    );

    painter.paint(canvas, settings.size);
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(
      settings.width.toInt(),
      settings.height.toInt(),
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
