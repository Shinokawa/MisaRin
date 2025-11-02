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
    required ui.Color strokeColor,
    required double strokeWidth,
    bool showCheckerboard = true,
  }) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas cacheCanvas = ui.Canvas(recorder);
    final ui.Rect bounds = ui.Offset.zero & _logicalSize;

    if (showCheckerboard) {
      _drawCheckerboard(cacheCanvas, bounds);
    }

    final ui.Paint strokePaint = ui.Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..strokeCap = ui.StrokeCap.round
      ..style = ui.PaintingStyle.stroke;

    for (final CanvasLayerData layer in layers) {
      if (!layer.visible) {
        continue;
      }
      switch (layer.type) {
        case CanvasLayerType.color:
          final ui.Color fillColor = layer.color ?? const ui.Color(0x00000000);
          cacheCanvas.drawRect(bounds, ui.Paint()..color = fillColor);
          break;
        case CanvasLayerType.strokes:
          for (final List<ui.Offset> stroke in layer.strokes) {
            _drawStroke(cacheCanvas, stroke, strokePaint);
          }
          break;
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
    this.strokeColor = const ui.Color(0xFF000000),
    this.strokeWidth = 3,
  });

  final StrokePictureCache cache;
  final int cacheVersion;
  final List<ui.Offset>? currentStroke;
  final int currentStrokeVersion;
  final double scale;
  final ui.Color strokeColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, ui.Size size) {
    final double effectiveScale = scale;

    canvas.save();
    if (effectiveScale != 1.0 && effectiveScale != 0) {
      canvas.scale(effectiveScale);
    }

    cache.paint(canvas);

    final List<ui.Offset>? stroke = currentStroke;
    if (stroke != null && stroke.isNotEmpty) {
      final ui.Paint strokePaint = ui.Paint()
        ..color = strokeColor
        ..strokeWidth = strokeWidth
        ..strokeCap = ui.StrokeCap.round
        ..style = ui.PaintingStyle.stroke;
      if (stroke.length == 1) {
        canvas.drawPoints(ui.PointMode.points, stroke, strokePaint);
      } else {
        for (int index = 0; index < stroke.length - 1; index++) {
          canvas.drawLine(stroke[index], stroke[index + 1], strokePaint);
        }
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) {
    return cacheVersion != oldDelegate.cacheVersion ||
        currentStrokeVersion != oldDelegate.currentStrokeVersion ||
        scale != oldDelegate.scale ||
        strokeColor != oldDelegate.strokeColor ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}
