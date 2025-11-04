part of 'painting_board.dart';

class _MarchingAntsStroke {
  _MarchingAntsStroke({
    required this.dashLength,
    required this.dashGap,
    required double strokeWidth,
    required Color lightColor,
    required Color darkColor,
  })  : assert(dashLength > 0),
        assert(dashGap >= 0),
        _lightPaint = Paint()
          ..color = lightColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.square,
        _darkPaint = Paint()
          ..color = darkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.square;

  final double dashLength;
  final double dashGap;
  final Paint _lightPaint;
  final Paint _darkPaint;

  final LinkedHashMap<int, _MarchingAntsPathCache> _cache =
      LinkedHashMap<int, _MarchingAntsPathCache>();

  void paint(Canvas canvas, Path path, double phase) {
    final double pattern = dashLength + dashGap;
    if (pattern <= 0) {
      return;
    }

    final _MarchingAntsPathCache cache = _resolveCache(path);
    if (cache.metrics.isEmpty) {
      return;
    }

    double distanceOffset = -(phase % pattern);
    if (distanceOffset.isNaN || distanceOffset.isInfinite) {
      distanceOffset = 0.0;
    }

    for (final ui.PathMetric metric in cache.metrics) {
      _paintMetric(canvas, metric, distanceOffset, pattern);
    }
  }

  _MarchingAntsPathCache _resolveCache(Path path) {
    final int key = identityHashCode(path);
    final _MarchingAntsPathCache? existing = _cache[key];
    if (existing != null && identical(existing.path, path)) {
      return existing;
    }
    final _MarchingAntsPathCache newCache = _MarchingAntsPathCache(path);
    _cache[key] = newCache;
    if (_cache.length > 6) {
      _cache.remove(_cache.keys.first);
    }
    return newCache;
  }

  void _paintMetric(
    Canvas canvas,
    ui.PathMetric metric,
    double initialOffset,
    double pattern,
  ) {
    double distance = initialOffset;
    int segmentIndex = 0;
    while (distance < metric.length) {
      final double start = math.max(0.0, distance);
      final double rawEnd = distance + dashLength;
      final double end = math.min(metric.length, rawEnd);
      if (end > start) {
        final Path segment = metric.extractPath(start, end);
        final bool isEven = segmentIndex.isEven;
        canvas.drawPath(segment, isEven ? _lightPaint : _darkPaint);
      }
      distance += pattern;
      segmentIndex += 1;
    }
  }
}

class _MarchingAntsPathCache {
  _MarchingAntsPathCache(this.path)
      : metrics = path.computeMetrics(forceClosed: false).toList(growable: false);

  final Path path;
  final List<ui.PathMetric> metrics;
}
