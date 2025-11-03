import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'canvas_layer.dart';

@immutable
class BucketFillOutcome {
  const BucketFillOutcome({
    this.region,
    this.recoloredStrokeIndices = const <int>[],
  });

  final CanvasFillRegion? region;
  final List<int> recoloredStrokeIndices;

  bool get appliesFill => region != null;
  bool get appliesStrokeRecolor => recoloredStrokeIndices.isNotEmpty;
}

class BucketFillEngine {
  const BucketFillEngine({
    required this.canvasSize,
    required this.layers,
    required this.targetLayer,
  });

  final ui.Size canvasSize;
  final List<CanvasLayerData> layers;
  final CanvasLayerData targetLayer;

  Future<BucketFillOutcome?> compute({
    required ui.Offset position,
    required bool sampleAllLayers,
    required bool contiguous,
    required ui.Color fillColor,
    double strokeHitTolerance = 2,
  }) async {
    final int width = canvasSize.width.round();
    final int height = canvasSize.height.round();
    if (width <= 0 || height <= 0) {
      return null;
    }

    if (!_withinBounds(position, width, height)) {
      return null;
    }

    final int? strokeIndex = _hitTestStroke(position, tolerance: strokeHitTolerance);
    if (strokeIndex != null) {
      return BucketFillOutcome(recoloredStrokeIndices: <int>[strokeIndex]);
    }

    final _RenderResult renderResult = await _renderComposite(
      width: width,
      height: height,
      sampleAllLayers: sampleAllLayers,
    );
    if (renderResult.pixels == null) {
      return null;
    }

    final Uint32List pixels = renderResult.pixels!;
    final int baseX = position.dx.floor().clamp(0, width - 1);
    final int baseY = position.dy.floor().clamp(0, height - 1);
    final int baseColor = pixels[baseY * width + baseX];
    final int fillValue = _encodeColor(fillColor);

    if (baseColor == fillValue) {
      return null;
    }

    final int totalPixels = width * height;
    final Uint8List mask = Uint8List(totalPixels);

    if (contiguous) {
      _floodFill(
        pixels: pixels,
        width: width,
        height: height,
        startX: baseX,
        startY: baseY,
        baseColor: baseColor,
        mask: mask,
      );
    } else {
      for (int index = 0; index < totalPixels; index++) {
        if (pixels[index] == baseColor) {
          mask[index] = 1;
        }
      }
    }

    if (!mask.contains(1)) {
      return null;
    }

    _expandMask(mask: mask, width: width, height: height, radius: 1);

    final CanvasFillRegion region = _maskToRegion(
      mask: mask,
      width: width,
      height: height,
      color: fillColor,
    );

    return BucketFillOutcome(region: region);
  }

  int? _hitTestStroke(ui.Offset position, {double tolerance = 2.0}) {
    final double toleranceSq = tolerance * tolerance;
    final List<CanvasStroke> strokes = targetLayer.strokes;
    for (int i = strokes.length - 1; i >= 0; i--) {
      final CanvasStroke stroke = strokes[i];
      final double effectiveTolerance = math.max(tolerance, stroke.width / 2);
      if (_strokeContainsPoint(stroke, position, effectiveTolerance)) {
        return i;
      }
    }
    return null;
  }

  bool _strokeContainsPoint(CanvasStroke stroke, ui.Offset point, double tolerance) {
    final double toleranceSq = tolerance * tolerance;
    final List<ui.Offset> points = stroke.points;
    if (points.isEmpty) {
      return false;
    }
    if (points.length == 1) {
      return (points.first - point).distanceSquared <= toleranceSq;
    }
    for (int index = 0; index < points.length - 1; index++) {
      final ui.Offset p0 = points[index];
      final ui.Offset p1 = points[index + 1];
      final double distanceSq = _distanceToSegmentSquared(point, p0, p1);
      if (distanceSq <= toleranceSq) {
        return true;
      }
    }
    return false;
  }

  bool _withinBounds(ui.Offset position, int width, int height) {
    return position.dx >= 0 &&
        position.dy >= 0 &&
        position.dx < width &&
        position.dy < height;
  }

  Future<_RenderResult> _renderComposite({
    required int width,
    required int height,
    required bool sampleAllLayers,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    final ui.Rect bounds = ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    canvas.clipRect(bounds);

    final Iterable<CanvasLayerData> renderLayers = sampleAllLayers
        ? layers
        : layers.where((layer) => layer.id == targetLayer.id);

    for (final CanvasLayerData layer in renderLayers) {
      if (!layer.visible) {
        continue;
      }
      if (layer.fillColor != null) {
        canvas.drawRect(
          bounds,
          ui.Paint()..color = layer.fillColor!,
        );
      }
      for (final CanvasFillRegion region in layer.fills) {
        _drawFillRegion(canvas, region);
      }
      for (final CanvasStroke stroke in layer.strokes) {
        _drawStroke(canvas, stroke);
      }
    }

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(width, height);
    picture.dispose();
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (byteData == null) {
      return const _RenderResult();
    }
    return _RenderResult(
      pixels: byteData.buffer.asUint32List(),
    );
  }

  void _drawStroke(ui.Canvas canvas, CanvasStroke stroke) {
    if (stroke.points.isEmpty) {
      return;
    }
    final ui.Paint paint = ui.Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round
      ..style = ui.PaintingStyle.stroke;
    if (stroke.points.length == 1) {
      final ui.Offset point = stroke.points.first;
      final ui.Paint dotPaint = ui.Paint()
        ..color = stroke.color
        ..style = ui.PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawCircle(point, stroke.width / 2, dotPaint);
      return;
    }
    canvas.drawPath(stroke.toPath(), paint);
  }

  void _drawFillRegion(ui.Canvas canvas, CanvasFillRegion region) {
    if (region.spans.isEmpty) {
      return;
    }
    final ui.Paint paint = ui.Paint()
      ..color = region.color
      ..style = ui.PaintingStyle.fill
      ..isAntiAlias = true;
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

  void _floodFill({
    required Uint32List pixels,
    required int width,
    required int height,
    required int startX,
    required int startY,
    required int baseColor,
    required Uint8List mask,
  }) {
    final ListQueue<ui.Offset> queue = ListQueue<ui.Offset>();
    queue.add(ui.Offset(startX.toDouble(), startY.toDouble()));
    mask[startY * width + startX] = 1;
    while (queue.isNotEmpty) {
      final ui.Offset current = queue.removeFirst();
      final int cx = current.dx.toInt();
      final int cy = current.dy.toInt();
      for (final ui.Offset delta in const <ui.Offset>[
        ui.Offset(1, 0),
        ui.Offset(-1, 0),
        ui.Offset(0, 1),
        ui.Offset(0, -1),
      ]) {
        final int nx = cx + delta.dx.toInt();
        final int ny = cy + delta.dy.toInt();
        if (nx < 0 || nx >= width || ny < 0 || ny >= height) {
          continue;
        }
        final int index = ny * width + nx;
        if (mask[index] == 1) {
          continue;
        }
        if (pixels[index] != baseColor) {
          continue;
        }
        mask[index] = 1;
        queue.add(ui.Offset(nx.toDouble(), ny.toDouble()));
      }
    }
  }

  CanvasFillRegion _maskToRegion({
    required Uint8List mask,
    required int width,
    required int height,
    required ui.Color color,
  }) {
    int minX = width;
    int maxX = -1;
    int minY = height;
    int maxY = -1;
    for (int y = 0; y < height; y++) {
      final int rowStart = y * width;
      for (int x = 0; x < width; x++) {
        if (mask[rowStart + x] == 1) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (minX > maxX || minY > maxY) {
      return CanvasFillRegion(
        color: color,
        origin: ui.Offset.zero,
        width: 0,
        height: 0,
      );
    }

    final List<CanvasFillSpan> spans = <CanvasFillSpan>[];
    for (int y = minY; y <= maxY; y++) {
      int? spanStart;
      for (int x = minX; x <= maxX; x++) {
        final bool filled = mask[y * width + x] == 1;
        if (filled) {
          spanStart ??= x;
        }
        final bool isLast = x == maxX;
        if ((spanStart != null && (!filled || isLast))) {
          final int end = filled && isLast ? x : x - 1;
          spans.add(
            CanvasFillSpan(
              dy: y - minY,
              start: spanStart - minX,
              end: end - minX,
            ),
          );
          spanStart = null;
        }
      }
    }

    return CanvasFillRegion(
      color: color,
      origin: ui.Offset(minX.toDouble(), minY.toDouble()),
      width: maxX - minX + 1,
      height: maxY - minY + 1,
      spans: spans,
    );
  }

  void _expandMask({
    required Uint8List mask,
    required int width,
    required int height,
    int radius = 1,
  }) {
    if (radius <= 0) {
      return;
    }
    final Uint8List expanded = Uint8List.fromList(mask);
    for (int y = 0; y < height; y++) {
      final int rowStart = y * width;
      for (int x = 0; x < width; x++) {
        if (mask[rowStart + x] != 1) {
          continue;
        }
        for (int dy = -radius; dy <= radius; dy++) {
          final int ny = y + dy;
          if (ny < 0 || ny >= height) {
            continue;
          }
          final int neighborRow = ny * width;
          for (int dx = -radius; dx <= radius; dx++) {
            final int nx = x + dx;
            if (nx < 0 || nx >= width) {
              continue;
            }
            expanded[neighborRow + nx] = 1;
          }
        }
      }
    }
    for (int i = 0; i < expanded.length; i++) {
      mask[i] = expanded[i];
    }
  }

  double _distanceToSegmentSquared(ui.Offset p, ui.Offset v, ui.Offset w) {
    final ui.Offset segment = w - v;
    final double lengthSq = segment.dx * segment.dx + segment.dy * segment.dy;
    if (lengthSq == 0) {
      return (p - v).distanceSquared;
    }
    double t = ((p.dx - v.dx) * segment.dx + (p.dy - v.dy) * segment.dy) / lengthSq;
    t = t.clamp(0.0, 1.0);
    final ui.Offset projection = ui.Offset(v.dx + t * segment.dx, v.dy + t * segment.dy);
    return (p - projection).distanceSquared;
  }

  int _encodeColor(ui.Color color) {
    final int a = (color.alpha) & 0xff;
    final int r = (color.red) & 0xff;
    final int g = (color.green) & 0xff;
    final int b = (color.blue) & 0xff;
    return (a << 24) | (r << 16) | (g << 8) | b;
  }
}

class _RenderResult {
  const _RenderResult({this.pixels});

  final Uint32List? pixels;
}
