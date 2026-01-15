part of 'painting_board.dart';

class _StrokeStabilizer {
  static const int _minSampleWindow = 1;
  static const int _maxSampleWindow = 64;

  Offset? _filtered;
  final List<Offset> _recentSamples = <Offset>[];

  void start(Offset position) {
    _filtered = position;
    _recentSamples
      ..clear()
      ..add(position);
  }

  Offset filter(Offset position, double strength) {
    final double clampedStrength = strength.clamp(0.0, 1.0);
    final Offset? previous = _filtered;
    if (previous == null) {
      start(position);
      return position;
    }

    final int maxSamples = _sampleWindowForStrength(clampedStrength);
    _recentSamples.add(position);
    while (_recentSamples.length > maxSamples) {
      _recentSamples.removeAt(0);
    }

    final Offset averaged = _weightedAverage(clampedStrength);
    final double smoothingBias =
        ui.lerpDouble(0.0, 0.95, math.pow(clampedStrength, 0.9).toDouble()) ??
        0.0;
    final Offset target =
        Offset.lerp(position, averaged, smoothingBias) ?? averaged;
    final double followMix =
        ui.lerpDouble(1.0, 0.18, math.pow(clampedStrength, 0.85).toDouble()) ??
        1.0;
    final Offset filtered =
        previous + (target - previous) * followMix.clamp(0.0, 1.0);
    _filtered = filtered;
    return filtered;
  }

  void reset() {
    _filtered = null;
    _recentSamples.clear();
  }

  int _sampleWindowForStrength(double strength) {
    if (strength <= 0.0) {
      return _minSampleWindow;
    }
    final double eased = math.pow(strength, 0.72).toDouble();
    final double lerped =
        ui.lerpDouble(
          _minSampleWindow.toDouble(),
          _maxSampleWindow.toDouble(),
          eased,
        ) ??
        _minSampleWindow.toDouble();
    final int rounded = lerped.round();
    if (rounded <= _minSampleWindow) {
      return _minSampleWindow;
    }
    if (rounded >= _maxSampleWindow) {
      return _maxSampleWindow;
    }
    return rounded;
  }

  Offset _weightedAverage(double strength) {
    if (_recentSamples.isEmpty) {
      return _filtered ?? Offset.zero;
    }
    if (_recentSamples.length == 1) {
      return _recentSamples.first;
    }
    final int length = _recentSamples.length;
    final double exponent =
        ui.lerpDouble(0.35, 2.4, math.pow(strength, 0.58).toDouble()) ?? 0.35;
    Offset accumulator = Offset.zero;
    double totalWeight = 0.0;
    for (int i = 0; i < length; i++) {
      final double progress = (i + 1) / length;
      final double weight = math
          .pow(progress.clamp(0.0, 1.0), exponent)
          .toDouble();
      accumulator += _recentSamples[i] * weight;
      totalWeight += weight;
    }
    if (totalWeight <= 1e-5) {
      return _recentSamples.last;
    }
    return accumulator / totalWeight;
  }
}
