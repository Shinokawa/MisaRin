import 'dart:math' as math;

enum StrokePressureProfile { taperEnds, taperCenter, auto }

/// Additional context calculated from pointer history to assist pressure
/// estimation in automatic mode.
class StrokeSampleMetrics {
  const StrokeSampleMetrics({
    required this.sampleIndex,
    required this.normalizedSpeed,
    required this.stationaryDuration,
    required this.totalDistance,
    required this.totalTime,
  });

  /// Index of the current sample within the stroke.
  final int sampleIndex;

  /// Smoothed speed normalised to [0, 1]. Smaller values indicate slower
  /// movement.
  final double normalizedSpeed;

  /// Accumulated milliseconds the pointer has remained within the
  /// stationary threshold up to the current sample.
  final double stationaryDuration;

  /// Total distance travelled so far in pixels.
  final double totalDistance;

  /// Total elapsed time in milliseconds since the stroke began.
  final double totalTime;
}

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
  static const double _autoHoldThresholdMs = 110.0;
  static const double _autoHoldRangeMs = 260.0;
  static const double _autoProgressDistance = 120.0;
  static const int _autoRampSamples = 4;

  double _baseRadius = 1.0;
  double? _smoothedIntensity;
  double _latestIntensity = 0.0;
  int _sampleCount = 0;

  /// Prepares the dynamics calculator for a new stroke using the provided
  /// baseline radius.
  void start(double baseRadius, {StrokePressureProfile? profile}) {
    _baseRadius = math.max(baseRadius, 0.1);
    if (profile != null) {
      this.profile = profile;
    }
    _smoothedIntensity = null;
    _latestIntensity = 0.0;
    _sampleCount = 0;
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
  ///
  /// When [metrics] is provided and the profile is [StrokePressureProfile.auto],
  /// additional history-derived signals influence the simulated pressure.
  /// When [intensityOverride] is supplied, it is treated as the normalized
  /// stylus intensity; assign [intensityBlend] below 1.0 to mix it with the
  /// speed-based estimator represented by [speedSignal].
  double sample({
    required double distance,
    double? deltaTimeMillis,
    StrokeSampleMetrics? metrics,
    double? intensityOverride,
    double? speedSignal,
    double intensityBlend = 1.0,
  }) {
    final double clampedDelta = _clampDelta(deltaTimeMillis);
    final double baseSpeed =
        (speedSignal ?? _normalizeSpeed(_computeSpeed(distance, clampedDelta)))
            .clamp(0.0, 1.0);
    final double blend = intensityOverride != null
        ? intensityBlend.clamp(0.0, 1.0)
        : 0.0;
    final double override = intensityOverride?.clamp(0.0, 1.0) ?? 0.0;
    final double targetIntensity = blend > 0.0
        ? (override * blend) + (baseSpeed * (1.0 - blend))
        : (intensityOverride ?? baseSpeed);
    final double previous = _smoothedIntensity ?? targetIntensity;
    _smoothedIntensity =
        previous + (targetIntensity - previous) * smoothingFactor;

    // Mix in a bit of the unsmoothed spike to emphasise sudden accelerations.
    final double biased =
        (_smoothedIntensity! * (1 - highSpeedBias)) +
        (targetIntensity * highSpeedBias);
    _latestIntensity = biased.clamp(0.0, 1.0);

    final double easedSpeed = math.pow(_latestIntensity, 0.6).toDouble();
    final double factor;
    switch (profile) {
      case StrokePressureProfile.taperEnds:
        factor = _lerp(maxRadiusFactor, minRadiusFactor, easedSpeed);
        break;
      case StrokePressureProfile.taperCenter:
        factor = _lerp(minRadiusFactor, maxRadiusFactor, easedSpeed);
        break;
      case StrokePressureProfile.auto:
        final bool stylusDominates =
            intensityOverride != null && blend >= 0.999;
        if (stylusDominates) {
          factor = _lerp(maxRadiusFactor, minRadiusFactor, easedSpeed);
        } else {
          final double normalizedSpeed = metrics?.normalizedSpeed ?? baseSpeed;
          factor = _autoFactor(
            smoothedSpeed: easedSpeed,
            normalizedSpeed: normalizedSpeed,
            metrics: metrics,
          );
        }
        break;
    }
    final double radius = _baseRadius * factor;
    final double ceiling = profile == StrokePressureProfile.auto
        ? maxRadius * 1.05
        : maxRadius;
    final double floor = minRadius * 0.55;
    _sampleCount += 1;
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

  double _autoFactor({
    required double smoothedSpeed,
    required double normalizedSpeed,
    StrokeSampleMetrics? metrics,
  }) {
    final double clampedSpeed = normalizedSpeed.clamp(0.0, 1.0);
    final double easedSpeed = math.pow(clampedSpeed, 0.85).toDouble();
    final double easedInverse = math.pow(1.0 - clampedSpeed, 0.9).toDouble();

    double factor = _lerp(
      minRadiusFactor * 0.92,
      maxRadiusFactor * 1.04,
      easedInverse,
    );

    final int sampleIndex = metrics?.sampleIndex ?? _sampleCount;
    final double ramp = ((sampleIndex + 1) / _autoRampSamples).clamp(0.0, 1.0);
    factor = _lerp(minRadiusFactor * 0.82, factor, ramp);

    if (metrics != null) {
      final double holdRatio =
          ((metrics.stationaryDuration - _autoHoldThresholdMs) /
                  _autoHoldRangeMs)
              .clamp(0.0, 1.0);
      if (holdRatio > 0.0) {
        factor = _lerp(factor, maxRadiusFactor * 1.05, holdRatio);
      }

      final double travel = metrics.totalDistance.clamp(0.0, double.infinity);
      final double progress = travel / (travel + _autoProgressDistance);
      factor = _lerp(
        factor,
        maxRadiusFactor * 0.98,
        (progress * 0.65).clamp(0.0, 1.0),
      );
    }

    final double flick = math
        .pow(smoothedSpeed.clamp(0.0, 1.0), 1.3)
        .toDouble();
    final double flickBlend = (flick * 0.55).clamp(0.0, 1.0);
    factor = _lerp(factor, minRadiusFactor * 0.88, flickBlend);

    return factor;
  }
}
