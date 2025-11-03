import 'dart:convert';
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

  Future<Uint8List> exportToSvg({
    required CanvasSettings settings,
    required List<CanvasLayerData> layers,
  }) async {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" '
      'width="${_formatDouble(settings.width)}" '
      'height="${_formatDouble(settings.height)}" '
      'viewBox="0 0 ${_formatDouble(settings.width)} ${_formatDouble(settings.height)}">',
    );

    if (settings.backgroundColor.alpha > 0) {
      buffer.writeln(
        '<rect width="100%" height="100%" fill="${_colorToSvg(settings.backgroundColor)}"/>',
      );
    }

    final ui.Size canvasSize = ui.Size(settings.width, settings.height);
    final ui.Rect bounds = ui.Offset.zero & canvasSize;
    for (final CanvasLayerData layer in layers) {
      if (!layer.visible) {
        continue;
      }
      final ui.Color? fillColor = layer.fillColor;
      if (fillColor != null && fillColor.alpha > 0) {
        buffer.writeln(
          '<rect x="0" y="0" width="${_formatDouble(bounds.width)}" '
          'height="${_formatDouble(bounds.height)}" '
          'fill="${_colorToSvg(fillColor)}"/>',
        );
      }
      for (final CanvasStroke stroke in layer.strokes) {
        if (stroke.points.isEmpty || stroke.color.alpha == 0) {
          continue;
        }
        if (stroke.points.length == 1) {
          final ui.Offset point = stroke.points.first;
          final double radius = stroke.width / 2;
          if (radius <= 0) {
            continue;
          }
          buffer.writeln(
            '<circle cx="${_formatDouble(point.dx)}" cy="${_formatDouble(point.dy)}" '
            'r="${_formatDouble(radius)}" fill="${_colorToSvg(stroke.color)}"/>',
          );
          continue;
        }

        final StringBuffer path = StringBuffer();
        for (int index = 0; index < stroke.points.length; index++) {
          final ui.Offset point = stroke.points[index];
          if (index == 0) {
            path.write(
              'M${_formatDouble(point.dx)} ${_formatDouble(point.dy)}',
            );
          } else {
            path.write(
              ' L${_formatDouble(point.dx)} ${_formatDouble(point.dy)}',
            );
          }
        }
        buffer.writeln(
          '<path d="${path.toString()}" fill="none" stroke="${_colorToSvg(stroke.color)}" '
          'stroke-width="${_formatDouble(stroke.width)}" stroke-linecap="round" '
          'stroke-linejoin="round"/>',
        );
      }
      for (final CanvasFillRegion region in layer.fills) {
        if (region.spans.isEmpty || region.color.alpha == 0) {
          continue;
        }
        _writeFillRegionSvg(buffer, region);
      }
    }

    buffer.writeln('</svg>');
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  String _colorToSvg(ui.Color color) {
    if (color.alpha == 0) {
      return 'none';
    }
    final String hex = color.value.toRadixString(16).padLeft(8, '0');
    final String rgb = hex.substring(2);
    if (color.alpha == 0xFF) {
      return '#$rgb';
    }
    final String alpha = _formatDouble(color.alpha / 255.0);
    return 'rgba(${color.red}, ${color.green}, ${color.blue}, $alpha)';
  }

  String _formatDouble(num value) {
    final String text = value.toStringAsFixed(3);
    if (!text.contains('.')) {
      return text;
    }
    String trimmed = text;
    while (trimmed.endsWith('0')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed.endsWith('.')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed.isEmpty ? '0' : trimmed;
  }

  void _writeFillRegionSvg(StringBuffer buffer, CanvasFillRegion region) {
    final List<_SvgFillRect> rects = _collapseFillRegion(region);
    if (rects.isEmpty) {
      return;
    }
    final String fill = _colorToSvg(region.color);
    for (final _SvgFillRect rect in rects) {
      buffer.writeln(
        '<rect x="${_formatDouble(rect.x)}" y="${_formatDouble(rect.y)}" '
        'width="${_formatDouble(rect.width)}" height="${_formatDouble(rect.height)}" '
        'fill="$fill"/>',
      );
    }
  }

  List<_SvgFillRect> _collapseFillRegion(CanvasFillRegion region) {
    if (region.spans.isEmpty) {
      return const <_SvgFillRect>[];
    }
    final Map<int, List<CanvasFillSpan>> rows = <int, List<CanvasFillSpan>>{};
    for (final CanvasFillSpan span in region.spans) {
      rows.putIfAbsent(span.dy, () => <CanvasFillSpan>[]).add(span);
    }
    final List<int> sortedRows = rows.keys.toList()..sort();
    final Map<_SpanKey, _RectRun> active = <_SpanKey, _RectRun>{};
    final List<_RectRun> completed = <_RectRun>[];
    int? previousDy;
    for (final int dy in sortedRows) {
      if (previousDy != null && dy > previousDy + 1) {
        completed.addAll(active.values);
        active.clear();
      }
      final List<CanvasFillSpan> rowSpans = rows[dy]!
        ..sort((CanvasFillSpan a, CanvasFillSpan b) => a.start.compareTo(b.start));
      final Set<_SpanKey> currentKeys = rowSpans
          .map((CanvasFillSpan span) => _SpanKey(span.start, span.end))
          .toSet();

      final List<_SpanKey> toRemove = <_SpanKey>[];
      active.forEach((_SpanKey key, _RectRun run) {
        if (!currentKeys.contains(key)) {
          completed.add(run);
          toRemove.add(key);
        }
      });
      for (final _SpanKey key in toRemove) {
        active.remove(key);
      }

      for (final CanvasFillSpan span in rowSpans) {
        final _SpanKey key = _SpanKey(span.start, span.end);
        final _RectRun? run = active[key];
        if (run != null) {
          run.lastDy = dy;
        } else {
          active[key] = _RectRun(
            start: span.start,
            end: span.end,
            originDy: dy,
            lastDy: dy,
          );
        }
      }

      previousDy = dy;
    }

    completed.addAll(active.values);

    return completed
        .map(
          (_RectRun run) => _SvgFillRect(
            x: region.origin.dx + run.start,
            y: region.origin.dy + run.originDy,
            width: (run.end - run.start + 1).toDouble(),
            height: (run.lastDy - run.originDy + 1).toDouble(),
          ),
        )
        .toList(growable: false);
  }
}

class _SpanKey {
  const _SpanKey(this.start, this.end);

  final int start;
  final int end;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _SpanKey && other.start == start && other.end == end;
  }

  @override
  int get hashCode => Object.hash(start, end);
}

class _RectRun {
  _RectRun({
    required this.start,
    required this.end,
    required this.originDy,
    required this.lastDy,
  });

  final int start;
  final int end;
  final int originDy;
  int lastDy;
}

class _SvgFillRect {
  const _SvgFillRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}
