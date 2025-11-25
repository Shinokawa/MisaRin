import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

/// Smooths pointer speed measurements by aggregating distance over a rolling
/// window before producing a normalized speed value.
class VelocitySmoother {
  VelocitySmoother({
    this.minTrackingDistance = 1.4,
    this.maxSampleHistory = 64,
    this.smoothingSamples = 3,
    this.maxSpeed = 2.5,
    this.avgDeltaSmoothing = 0.85,
  }) : assert(minTrackingDistance > 0),
       assert(maxSampleHistory > 1),
       assert(smoothingSamples > 0),
       assert(maxSpeed > 0),
       assert(avgDeltaSmoothing > 0 && avgDeltaSmoothing < 1);

  final double minTrackingDistance;
  final int maxSampleHistory;
  final int smoothingSamples;
  final double maxSpeed;
  final double avgDeltaSmoothing;

  final Queue<_DistanceSample> _history = Queue<_DistanceSample>();
  Offset? _lastPosition;
  double? _lastTimestamp;
  double? _avgDeltaTime;
  double _lastSpeed = 0.0;
  double _lastNormalized = 0.0;

  double get lastRawSpeed => _lastSpeed;
  double get lastNormalizedSpeed => _lastNormalized;

  bool get hasSamples => _lastTimestamp != null;

  void reset() {
    _history.clear();
    _lastPosition = null;
    _lastTimestamp = null;
    _avgDeltaTime = null;
    _lastSpeed = 0.0;
    _lastNormalized = 0.0;
  }

  /// Registers a new pointer sample and returns a normalized speed (0..1).
  double addSample(Offset position, double timestampMillis) {
    if (_lastPosition == null || _lastTimestamp == null) {
      _initialize(position, timestampMillis);
      return _lastNormalized;
    }

    final double deltaTime = math.max(0.0, timestampMillis - _lastTimestamp!);
    final double distance = (position - _lastPosition!).distance;
    if (!deltaTime.isFinite || !distance.isFinite) {
      return _lastNormalized;
    }

    _history.add(_DistanceSample(distance: distance));
    while (_history.length > maxSampleHistory) {
      _history.removeFirst();
    }

    _avgDeltaTime = _avgDeltaTime == null
        ? deltaTime
        : _avgDeltaTime! +
              (deltaTime - _avgDeltaTime!) * (1 - avgDeltaSmoothing);

    _lastPosition = position;
    _lastTimestamp = timestampMillis;

    if (_history.isEmpty || (_avgDeltaTime ?? 0.0) <= 0.0) {
      return _lastNormalized;
    }

    double totalDistance = 0.0;
    double totalTime = 0.0;
    int searchedSamples = 0;

    for (final _DistanceSample sample in _history.toList().reversed) {
      searchedSamples++;
      totalDistance += sample.distance;
      totalTime += _avgDeltaTime!;
      if (searchedSamples >= smoothingSamples &&
          totalDistance >= minTrackingDistance) {
        break;
      }
    }

    if (totalTime <= 0.0 || totalDistance < minTrackingDistance) {
      _lastSpeed = 0.0;
      _lastNormalized = 0.0;
      return 0.0;
    }

    _lastSpeed = totalDistance / totalTime;
    _lastNormalized = (_lastSpeed / maxSpeed).clamp(0.0, 1.0);
    return _lastNormalized;
  }

  void _initialize(Offset position, double timestampMillis) {
    _lastPosition = position;
    _lastTimestamp = timestampMillis;
    _history.clear();
    _avgDeltaTime = null;
    _lastSpeed = 0.0;
    _lastNormalized = 0.0;
  }
}

class _DistanceSample {
  const _DistanceSample({required this.distance});
  final double distance;
}
