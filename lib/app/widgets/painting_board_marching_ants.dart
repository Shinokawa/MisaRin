part of 'painting_board.dart';

class _MarchingAntsStroke {
  _MarchingAntsStroke({
    required this.dashLength,
    required this.dashGap,
    required double strokeWidth,
    required Color lightColor,
    required Color darkColor,
  }) : assert(dashLength > 0),
       assert(dashGap >= 0),
       _baseStrokeWidth = strokeWidth,
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
  double? _baseStrokeWidth;
  final Paint _lightPaint;
  final Paint _darkPaint;

  final LinkedHashMap<int, _MarchingAntsPathCache> _cache =
      LinkedHashMap<int, _MarchingAntsPathCache>();

  void paint(
    Canvas canvas,
    Path path,
    double phase, {
    double viewportScale = 1.0,
  }) {
    double effectivePhase = phase;
    if (!effectivePhase.isFinite) {
      effectivePhase = 0.0;
    }

    double effectiveScale = viewportScale;
    if (!effectiveScale.isFinite || effectiveScale <= 0) {
      effectiveScale = 1.0;
    }
    final double baseStrokeWidth = _resolveBaseStrokeWidth();
    final double targetStrokeWidth = baseStrokeWidth / effectiveScale;
    if (_lightPaint.strokeWidth != targetStrokeWidth) {
      _lightPaint.strokeWidth = targetStrokeWidth;
      _darkPaint.strokeWidth = targetStrokeWidth;
    }

    final double pattern = dashLength + dashGap;
    if (pattern <= 0) {
      return;
    }

    final _MarchingAntsPathCache cache = _resolveCache(path);
    if (cache.metrics.isEmpty) {
      return;
    }

    final double wrapsDouble = effectivePhase / pattern;
    int wrapCount = wrapsDouble.floor();
    double offset = effectivePhase - wrapCount * pattern;
    if (offset < 0) {
      offset += pattern;
      wrapCount -= 1;
    }

    final double distanceOffset = -offset;

    for (final ui.PathMetric metric in cache.metrics) {
      _paintMetric(canvas, metric, distanceOffset, pattern, wrapCount);
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
    int segmentIndex,
  ) {
    double distance = initialOffset;
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

  double _resolveBaseStrokeWidth() {
    final double? base = _baseStrokeWidth;
    if (base != null) {
      return base;
    }
    final double fallback = _lightPaint.strokeWidth;
    _baseStrokeWidth = fallback;
    return fallback;
  }
}

class _MarchingAntsPathCache {
  _MarchingAntsPathCache(this.path)
    : metrics = path.computeMetrics(forceClosed: false).toList(growable: false);

  final Path path;
  final List<ui.PathMetric> metrics;
}
