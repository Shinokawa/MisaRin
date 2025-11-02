import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

class StrokePictureCache {
  StrokePictureCache({
    required ui.Size logicalSize,
    required ui.Color backgroundColor,
  })  : _logicalSize = logicalSize,
        _backgroundColor = backgroundColor;

  ui.Picture? _picture;
  ui.Size _logicalSize;
  ui.Color _backgroundColor;
  int _version = 0;

  int get version => _version;
  ui.Size get logicalSize => _logicalSize;

  void sync({
    required Iterable<List<ui.Offset>> strokes,
    required ui.Color backgroundColor,
    required ui.Color strokeColor,
    required double strokeWidth,
  }) {
    final Iterator<List<ui.Offset>> iterator = strokes.iterator;
    if (!iterator.moveNext()) {
      _setEmpty(backgroundColor: backgroundColor);
      return;
    }
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas cacheCanvas = ui.Canvas(recorder);
    final ui.Rect bounds = ui.Offset.zero & _logicalSize;
    cacheCanvas.drawRect(bounds, ui.Paint()..color = backgroundColor);

    final ui.Paint strokePaint = ui.Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..strokeCap = ui.StrokeCap.round
      ..style = ui.PaintingStyle.stroke;

    do {
      _drawStroke(cacheCanvas, iterator.current, strokePaint);
    } while (iterator.moveNext());

    _picture?.dispose();
    _picture = recorder.endRecording();
    _backgroundColor = backgroundColor;
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
    canvas.drawRect(bounds, ui.Paint()..color = _backgroundColor);
  }

  void dispose() {
    _picture?.dispose();
    _picture = null;
  }

  void _setEmpty({required ui.Color backgroundColor}) {
    final bool shouldInvalidate =
        _picture != null || _backgroundColor != backgroundColor;
    if (_picture != null) {
      _picture!.dispose();
      _picture = null;
    }
    _backgroundColor = backgroundColor;
    if (shouldInvalidate) {
      _version++;
    }
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
