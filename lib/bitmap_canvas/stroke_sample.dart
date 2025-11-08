import 'dart:math' as math;
import 'dart:ui';

/// Represents a single pointer sample gathered while drawing a stroke.
class StrokeSample {
  const StrokeSample({
    required this.position,
    required this.timestamp,
    required this.deltaTime,
    required this.distance,
    required this.speed,
    required this.stationaryDuration,
  });

  final Offset position;
  final double timestamp;
  final double deltaTime;
  final double distance;
  final double speed;
  final double stationaryDuration;

  bool get hasMotion => distance > 0.0001;
  bool get isStationary => !hasMotion;
}

/// Maintains the history of samples for the current stroke and exposes
/// derived metrics (distance, pause duration, etc.).
class StrokeSampleSeries {
  StrokeSampleSeries({this.stationaryDistanceThreshold = 0.35});

  final List<StrokeSample> _samples = <StrokeSample>[];
  final double stationaryDistanceThreshold;

  Offset? _lastPosition;
  double? _lastTimestamp;
  double _totalDistance = 0;
  double _totalTime = 0;

  List<StrokeSample> get samples => List<StrokeSample>.unmodifiable(_samples);

  StrokeSample? get latest => _samples.isEmpty ? null : _samples.last;

  int get length => _samples.length;

  double get totalDistance => _totalDistance;

  double get totalTime => _totalTime;

  double get latestStationaryDuration => latest?.stationaryDuration ?? 0.0;

  void clear() {
    _samples.clear();
    _lastPosition = null;
    _lastTimestamp = null;
    _totalDistance = 0;
    _totalTime = 0;
  }

  StrokeSample add(Offset position, double timestampMillis) {
    final double deltaTime = _computeDeltaTime(timestampMillis);
    final double distance = _computeDistance(position);
    final double speed = _computeSpeed(distance, deltaTime);
    final double stationaryDuration = _computeStationaryDuration(
      distance,
      deltaTime,
    );

    final StrokeSample sample = StrokeSample(
      position: position,
      timestamp: timestampMillis,
      deltaTime: deltaTime,
      distance: distance,
      speed: speed,
      stationaryDuration: stationaryDuration,
    );

    _samples.add(sample);
    _totalDistance += distance;
    _totalTime += deltaTime;
    _lastPosition = position;
    _lastTimestamp = timestampMillis;
    return sample;
  }

  double _computeDeltaTime(double timestampMillis) {
    final double? lastTimestamp = _lastTimestamp;
    if (lastTimestamp == null) {
      return 0.0;
    }
    final double delta = timestampMillis - lastTimestamp;
    if (!delta.isFinite) {
      return 0.0;
    }
    return math.max(delta, 0.0);
  }

  double _computeDistance(Offset position) {
    final Offset? last = _lastPosition;
    if (last == null) {
      return 0.0;
    }
    return (position - last).distance;
  }

  double _computeSpeed(double distance, double deltaTime) {
    if (deltaTime <= 0.0001) {
      return 0.0;
    }
    return distance / deltaTime;
  }

  double _computeStationaryDuration(double distance, double deltaTime) {
    final StrokeSample? previous = latest;
    if (distance <= stationaryDistanceThreshold) {
      return (previous?.stationaryDuration ?? 0.0) + deltaTime;
    }
    return 0.0;
  }
}
