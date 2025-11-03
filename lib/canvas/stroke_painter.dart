import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'canvas_layer.dart';

class StrokePictureCache {
  StrokePictureCache({
    required ui.Size logicalSize,
  }) : _logicalSize = logicalSize;

  ui.Picture? _picture;
  ui.Size _logicalSize;
  int _version = 0;

  int get version => _version;
  ui.Size get logicalSize => _logicalSize;

  void sync({
    required List<CanvasLayerData> layers,
    bool showCheckerboard = true,
  }) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas cacheCanvas = ui.Canvas(recorder);
    final ui.Rect bounds = ui.Offset.zero & _logicalSize;

    if (showCheckerboard) {
      _drawCheckerboard(cacheCanvas, bounds);
    }

    for (final CanvasLayerData layer in layers) {
      if (!layer.visible) {
        continue;
      }
      if (layer.fillColor != null) {
        cacheCanvas.drawRect(
          bounds,
          ui.Paint()..color = layer.fillColor!,
        );
      }
      for (final CanvasFillRegion region in layer.fills) {
        _drawFillRegion(cacheCanvas, region);
      }
      for (final CanvasStroke stroke in layer.strokes) {
        _drawStroke(
          cacheCanvas,
          stroke.points,
          ui.Paint()
            ..color = stroke.color
            ..strokeWidth = stroke.width
            ..strokeCap = ui.StrokeCap.round
            ..style = ui.PaintingStyle.stroke,
        );
      }
    }

    _picture?.dispose();
    _picture = recorder.endRecording();
    _version++;
  }

  void updateLogicalSize(ui.Size size) {
    if (_logicalSize == size) {
      return;
    }
    _logicalSize = size;
    _version++;
  }

  void paint(Canvas canvas) {
    if (_picture != null) {
      canvas.drawPicture(_picture!);
      return;
    }
    final ui.Rect bounds = ui.Offset.zero & _logicalSize;
    _drawCheckerboard(canvas, bounds);
  }

  void dispose() {
    _picture?.dispose();
    _picture = null;
  }

  void _drawStroke(ui.Canvas canvas, List<ui.Offset> stroke, ui.Paint paint) {
    if (stroke.isEmpty) {
      return;
    }
    if (stroke.length == 1) {
      canvas.drawPoints(ui.PointMode.points, stroke, paint);
      return;
    }
    for (int index = 0; index < stroke.length - 1; index++) {
      canvas.drawLine(stroke[index], stroke[index + 1], paint);
    }
  }

  void _drawFillRegion(ui.Canvas canvas, CanvasFillRegion region) {
    if (region.spans.isEmpty) {
      return;
    }
    final ui.Paint paint = ui.Paint()
      ..color = region.color
      ..style = ui.PaintingStyle.fill
      ..isAntiAlias = false; // 避免油漆桶填充呈现半透明条纹
    final double originX = region.origin.dx;
    final double originY = region.origin.dy;
    for (final CanvasFillSpan span in region.spans) {
      final double left = originX + span.start;
      final double top = originY + span.dy;
      final double width = (span.end - span.start + 1).toDouble();
      canvas.drawRect(
        ui.Rect.fromLTWH(left, top, width, 1),
        paint,
      );
    }
  }

  void _drawCheckerboard(ui.Canvas canvas, ui.Rect bounds) {
    const double tileSize = 24;
    const ui.Color light = ui.Color(0xFFEFEFEF);
    const ui.Color dark = ui.Color(0xFFD0D0D0);
    final ui.Paint lightPaint = ui.Paint()..color = light;
    final ui.Paint darkPaint = ui.Paint()..color = dark;
    final int horizontalTiles = (bounds.width / tileSize).ceil();
    final int verticalTiles = (bounds.height / tileSize).ceil();
    for (int y = 0; y < verticalTiles; y++) {
      for (int x = 0; x < horizontalTiles; x++) {
        final bool isDark = (x + y) % 2 == 0;
        final double left = bounds.left + x * tileSize;
        final double top = bounds.top + y * tileSize;
        final double right = (left + tileSize).clamp(bounds.left, bounds.right);
        final double bottom =
            (top + tileSize).clamp(bounds.top, bounds.bottom);
        canvas.drawRect(
          ui.Rect.fromLTRB(left, top, right, bottom),
          isDark ? darkPaint : lightPaint,
        );
      }
    }
  }
}

class StrokePainter extends CustomPainter {
  const StrokePainter({
    required this.cache,
    required this.cacheVersion,
    required this.currentStroke,
    required this.currentStrokeVersion,
    this.scale = 1.0,
  });

  final StrokePictureCache cache;
  final int cacheVersion;
  final CanvasStroke? currentStroke;
  final int currentStrokeVersion;
  final double scale;

  @override
  void paint(Canvas canvas, ui.Size size) {
    final double effectiveScale = scale;

    canvas.save();
    if (effectiveScale != 1.0 && effectiveScale != 0) {
      canvas.scale(effectiveScale);
    }

    cache.paint(canvas);

    final CanvasStroke? stroke = currentStroke;
    if (stroke != null && stroke.points.isNotEmpty) {
      final ui.Paint strokePaint = ui.Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = ui.StrokeCap.round
        ..style = ui.PaintingStyle.stroke;
      if (stroke.points.length == 1) {
        canvas.drawPoints(ui.PointMode.points, stroke.points, strokePaint);
      } else {
        for (int index = 0; index < stroke.points.length - 1; index++) {
          canvas.drawLine(stroke.points[index], stroke.points[index + 1], strokePaint);
        }
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) {
    return cacheVersion != oldDelegate.cacheVersion ||
        currentStrokeVersion != oldDelegate.currentStrokeVersion ||
        scale != oldDelegate.scale;
  }
}
