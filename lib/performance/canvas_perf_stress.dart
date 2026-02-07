class CanvasPerfStressReport {
  const CanvasPerfStressReport({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.layerCount,
    required this.duration,
    required this.pointsGenerated,
    required this.pointsPerSecond,
    required this.presentLatencySampleCount,
    required this.presentLatencyP50Ms,
    required this.presentLatencyP95Ms,
    required this.uiBuildSampleCount,
    required this.uiBuildP95Ms,
  });

  final int canvasWidth;
  final int canvasHeight;
  final int layerCount;
  final Duration duration;

  final int pointsGenerated;
  final double pointsPerSecond;

  final int presentLatencySampleCount;
  final double presentLatencyP50Ms;
  final double presentLatencyP95Ms;

  final int uiBuildSampleCount;
  final double uiBuildP95Ms;

  String toLogString() {
    final String seconds = (duration.inMilliseconds / 1000.0).toStringAsFixed(2);
    return '[perf-stress] ${canvasWidth}x$canvasHeight layers=$layerCount '
        'duration=${seconds}s points=$pointsGenerated '
        'pps=${pointsPerSecond.toStringAsFixed(1)} '
        'input->present(P50/P95)=${presentLatencyP50Ms.toStringAsFixed(2)}/${presentLatencyP95Ms.toStringAsFixed(2)}ms '
        'uiBuildP95=${uiBuildP95Ms.toStringAsFixed(2)}ms '
        'samples(latency/ui)=$presentLatencySampleCount/$uiBuildSampleCount';
  }
}

double percentileMs(List<double> samples, double percentile) {
  if (samples.isEmpty) {
    return 0;
  }
  final List<double> sorted = List<double>.from(samples)..sort();
  final double clamped = percentile.clamp(0.0, 1.0);
  final double index = (sorted.length - 1) * clamped;
  final int lower = index.floor();
  final int upper = index.ceil();
  if (lower == upper) {
    return sorted[lower];
  }
  final double t = index - lower;
  return sorted[lower] + (sorted[upper] - sorted[lower]) * t;
}

