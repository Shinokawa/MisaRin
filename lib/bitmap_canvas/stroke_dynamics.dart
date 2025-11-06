import 'dart:math' as math;

enum StrokePressureProfile { taperEnds, taperCenter }

/// Encapsulates speed-based brush radius simulation to mimic stylus pressure.
class StrokeDynamics {
  StrokeDynamics({
    this.profile = StrokePressureProfile.taperEnds,
    this.minRadiusFactor = 0.09,
    this.maxRadiusFactor = 1.85,
    this.minSpeed = 0.018,
    this.maxSpeed = 0.72,
    this.smoothingFactor = 0.32,
    this.highSpeedBias = 0.18,
  });

  StrokePressureProfile profile;

  /// Radius multiplier used for the thinnest parts of the stroke.
  final double minRadiusFactor;

  /// Radius multiplier used for the broadest, slow-moving segments.
  final double maxRadiusFactor;

  /// Speed (in px/ms) considered "very slow".
  final double minSpeed;

  /// Speed (in px/ms) considered "very fast".
  final double maxSpeed;

  /// Blend factor for smoothing speed changes between samples.
  final double smoothingFactor;

  /// Additional weight applied to sudden spikes in speed so fast flicks
  /// taper aggressively.
  final double highSpeedBias;

  static const double _minDeltaMs = 3.5;
  static const double _maxDeltaMs = 140.0;
  static const double _defaultDeltaMs = 16.0;

  double _baseRadius = 1.0;
  double? _smoothedIntensity;
  double _latestIntensity = 0.0;

  /// Prepares the dynamics calculator for a new stroke using the provided
  /// baseline radius.
  void start(double baseRadius, {StrokePressureProfile? profile}) {
    _baseRadius = math.max(baseRadius, 0.1);
    if (profile != null) {
      this.profile = profile;
    }
    _smoothedIntensity = null;
    _latestIntensity = 0.0;
  }

  void configure({required StrokePressureProfile profile}) {
    this.profile = profile;
  }

  double get minRadius => math.max(_baseRadius * minRadiusFactor, 0.08);

  double get maxRadius => math.max(_baseRadius * maxRadiusFactor, minRadius);

  /// Returns the preferred radius for the very first point of the stroke.
  double initialRadius() => minRadius * 0.85;

  /// Computes an interpolated radius for the next sample based on pointer
  /// movement over [distance] pixels within [deltaTimeMillis] milliseconds.
  double sample({required double distance, double? deltaTimeMillis}) {
    final double clampedDelta = _clampDelta(deltaTimeMillis);
    final double speed = _computeSpeed(distance, clampedDelta);
    final double normalized = _normalizeSpeed(speed);
    final double previous = _smoothedIntensity ?? normalized;
    _smoothedIntensity = previous + (normalized - previous) * smoothingFactor;

    // Mix in a bit of the unsmoothed spike to emphasise sudden accelerations.
    final double biased =
        (_smoothedIntensity! * (1 - highSpeedBias)) +
        (normalized * highSpeedBias);
    _latestIntensity = biased.clamp(0.0, 1.0);

    final double eased = math.pow(_latestIntensity, 0.6).toDouble();
    final double factor = profile == StrokePressureProfile.taperEnds
        ? _lerp(maxRadiusFactor, minRadiusFactor, eased)
        : _lerp(minRadiusFactor, maxRadiusFactor, eased);
    final double radius = _baseRadius * factor;
    final double ceiling = maxRadius;
    final double floor = minRadius * 0.55;
    return radius.clamp(floor, ceiling);
  }

  /// Radius used to draw the tail when finishing a stroke.
  double tipRadius() => minRadius * 0.6;

  double _clampDelta(double? deltaTimeMillis) {
    final double candidate = (deltaTimeMillis ?? _defaultDeltaMs).clamp(
      _minDeltaMs,
      _maxDeltaMs,
    );
    return candidate.isFinite ? candidate : _defaultDeltaMs;
  }

  double _computeSpeed(double distance, double deltaMs) {
    if (deltaMs <= 0.0001) {
      return maxSpeed;
    }
    return distance / deltaMs;
  }

  double _normalizeSpeed(double speed) {
    if (!speed.isFinite) {
      return 1.0;
    }
    final double clamped = speed.clamp(minSpeed, maxSpeed);
    final double span = maxSpeed - minSpeed;
    if (span <= 0.0001) {
      return 0.0;
    }
    return (clamped - minSpeed) / span;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;
}
