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

class _StreamlineStabilizer {
  static const double _minDeltaMs = 1.0;
  static const double _maxDeltaMs = 80.0;
  static const double _defaultDeltaMs = 16.0;
  static const double _maxRopeLength = 80.0;
  static const double _maxTimeConstantMs = 180.0;

  Offset? _filtered;

  void start(Offset position) {
    _filtered = position;
  }

  Offset filter(
    Offset position,
    double strength, {
    double? deltaTimeMillis,
  }) {
    final double t = strength.isFinite ? strength.clamp(0.0, 1.0) : 0.0;
    final Offset? previous = _filtered;
    if (previous == null) {
      start(position);
      return position;
    }
    if (t <= 0.0001) {
      _filtered = position;
      return position;
    }

    final double rawDelta = deltaTimeMillis ?? _defaultDeltaMs;
    final double dt = rawDelta.isFinite
        ? rawDelta.clamp(_minDeltaMs, _maxDeltaMs)
        : _defaultDeltaMs;
    final double rope =
        ui.lerpDouble(0.0, _maxRopeLength, math.pow(t, 2.2).toDouble()) ?? 0.0;
    final double tau =
        ui.lerpDouble(0.0, _maxTimeConstantMs, math.pow(t, 1.4).toDouble()) ??
        0.0;
    final double alpha =
        tau <= 0.0001 ? 1.0 : 1.0 - math.exp(-dt / tau);

    Offset next = previous + (position - previous) * alpha.clamp(0.0, 1.0);
    if (rope > 0.0001) {
      final Offset delta = position - next;
      final double dist = delta.distance;
      if (dist.isFinite && dist > rope) {
        final Offset dir = delta / dist;
        next = position - dir * rope;
      }
    } else {
      next = position;
    }

    _filtered = next;
    return next;
  }

  void reset() {
    _filtered = null;
  }
}

class _StreamlinePathData {
  const _StreamlinePathData({
    required this.points,
    required this.radii,
  });

  final List<Offset> points;
  final List<double> radii;
}

const double _kStreamlineCatmullSampleSpacing = 4.0;
const double _kStreamlineCatmullMinSegment = 0.5;
const int _kStreamlineCatmullMaxSamplesPerSegment = 48;

_StreamlinePathData _buildStreamlinePostProcessTarget(
  List<Offset> rawPoints,
  List<double> rawRadii,
  double strength,
) {
  if (rawPoints.isEmpty) {
    return const _StreamlinePathData(points: <Offset>[], radii: <double>[]);
  }
  if (rawPoints.length < 3 || strength <= 0.0001) {
    return _StreamlinePathData(
      points: List<Offset>.from(rawPoints),
      radii: List<double>.from(rawRadii),
    );
  }

  final List<Offset> stabilized = _streamlineZeroPhaseSmoothPoints(
    rawPoints,
    strength,
  );
  return _streamlineCatmullRomResample(stabilized, rawRadii);
}

List<Offset> _streamlineZeroPhaseSmoothPoints(
  List<Offset> points,
  double strength,
) {
  if (points.length < 3) {
    return List<Offset>.from(points);
  }

  final double t = strength.isFinite ? strength.clamp(0.0, 1.0) : 0.0;
  if (t <= 0.0001) {
    return List<Offset>.from(points);
  }

  final double eased = math.pow(t, 1.35).toDouble();
  final double alpha =
      (ui.lerpDouble(1.0, 0.08, eased) ?? 1.0).clamp(0.0, 1.0);
  final int iterations = (1 + (eased * 2.0).floor()).clamp(1, 3);

  List<Offset> current = List<Offset>.from(points);
  for (int i = 0; i < iterations; i++) {
    current = _streamlineZeroPhaseIir(current, alpha);
    current[0] = points.first;
    current[current.length - 1] = points.last;
  }
  return current;
}

List<Offset> _streamlineZeroPhaseIir(List<Offset> points, double alpha) {
  if (points.length < 2) {
    return List<Offset>.from(points);
  }
  final double resolvedAlpha =
      alpha.isFinite ? alpha.clamp(0.0, 1.0) : 1.0;

  final int length = points.length;
  final List<Offset> forward = List<Offset>.filled(length, Offset.zero);
  forward[0] = points[0];
  for (int i = 1; i < length; i++) {
    final Offset previous = forward[i - 1];
    final Offset next = points[i];
    forward[i] = previous + (next - previous) * resolvedAlpha;
  }

  final List<Offset> output = List<Offset>.filled(length, Offset.zero);
  output[length - 1] = forward[length - 1];
  for (int i = length - 2; i >= 0; i--) {
    final Offset previous = output[i + 1];
    final Offset next = forward[i];
    output[i] = previous + (next - previous) * resolvedAlpha;
  }

  return output;
}

_StreamlinePathData _streamlineCatmullRomResample(
  List<Offset> points,
  List<double> radii,
) {
  if (points.length < 3) {
    return _StreamlinePathData(
      points: List<Offset>.from(points),
      radii: List<double>.from(radii),
    );
  }

  final List<Offset> smoothedPoints = <Offset>[points.first];
  final List<double> smoothedRadii = <double>[
    _streamlineRadiusAtIndex(radii, 0),
  ];

  for (int i = 0; i < points.length - 1; i++) {
    final Offset p0 = i == 0 ? points[i] : points[i - 1];
    final Offset p1 = points[i];
    final Offset p2 = points[i + 1];
    final Offset p3 = (i + 2 < points.length) ? points[i + 2] : points[i + 1];
    final double r0 = i == 0
        ? _streamlineRadiusAtIndex(radii, i)
        : _streamlineRadiusAtIndex(radii, i - 1);
    final double r1 = _streamlineRadiusAtIndex(radii, i);
    final double r2 = _streamlineRadiusAtIndex(radii, i + 1);
    final double r3 = (i + 2 < points.length)
        ? _streamlineRadiusAtIndex(radii, i + 2)
        : _streamlineRadiusAtIndex(radii, i + 1);

    final double segmentLength = (p2 - p1).distance;
    if (segmentLength < _kStreamlineCatmullMinSegment) {
      continue;
    }

    final int samples = math.max(
      2,
      math.min(
        _kStreamlineCatmullMaxSamplesPerSegment,
        (segmentLength / _kStreamlineCatmullSampleSpacing).ceil() + 1,
      ),
    );

    for (int s = 1; s < samples; s++) {
      final double t = s / (samples - 1);
      final Offset smoothedPoint = _streamlineCatmullRomOffset(p0, p1, p2, p3, t);
      final double smoothedRadius =
          _streamlineCatmullRomScalar(r0, r1, r2, r3, t).clamp(
            0.0,
            double.infinity,
          );
      smoothedPoints.add(smoothedPoint);
      smoothedRadii.add(smoothedRadius);
    }
  }

  if (smoothedPoints.length == 1) {
    smoothedPoints.add(points.last);
    smoothedRadii.add(_streamlineRadiusAtIndex(radii, points.length - 1));
  } else {
    smoothedPoints[smoothedPoints.length - 1] = points.last;
    smoothedRadii[smoothedRadii.length - 1] =
        _streamlineRadiusAtIndex(radii, points.length - 1);
  }

  return _StreamlinePathData(points: smoothedPoints, radii: smoothedRadii);
}

double _streamlineRadiusAtIndex(List<double> radii, int index) {
  if (radii.isEmpty) {
    return 1.0;
  }
  if (index < 0) {
    return radii.first;
  }
  if (index >= radii.length) {
    return radii.last;
  }
  final double value = radii[index];
  if (value.isFinite && value >= 0) {
    return value;
  }
  return radii.last >= 0 ? radii.last : 1.0;
}

Offset _streamlineCatmullRomOffset(
  Offset p0,
  Offset p1,
  Offset p2,
  Offset p3,
  double t,
) {
  return Offset(
    _streamlineCatmullRomScalar(p0.dx, p1.dx, p2.dx, p3.dx, t),
    _streamlineCatmullRomScalar(p0.dy, p1.dy, p2.dy, p3.dy, t),
  );
}

double _streamlineCatmullRomScalar(
  double p0,
  double p1,
  double p2,
  double p3,
  double t,
) {
  final double t2 = t * t;
  final double t3 = t2 * t;
  return 0.5 *
      ((2 * p1) +
          (-p0 + p2) * t +
          (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
          (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
}

List<double> _strokeProgressRatios(List<Offset> points) {
  if (points.isEmpty) {
    return const <double>[];
  }
  if (points.length == 1) {
    return const <double>[0.0];
  }

  final int length = points.length;
  final List<double> cumulative = List<double>.filled(length, 0.0);
  double total = 0.0;
  for (int i = 1; i < length; i++) {
    final double delta = (points[i] - points[i - 1]).distance;
    if (delta.isFinite) {
      total += delta;
    }
    cumulative[i] = total;
  }

  if (total <= 1e-5) {
    for (int i = 0; i < length; i++) {
      cumulative[i] = length == 1 ? 0.0 : (i / (length - 1));
    }
    return cumulative;
  }

  for (int i = 0; i < length; i++) {
    cumulative[i] = (cumulative[i] / total).clamp(0.0, 1.0);
  }
  cumulative[length - 1] = 1.0;
  return cumulative;
}

_StreamlinePathData _resampleStrokeAtRatios(
  List<Offset> points,
  List<double> radii,
  List<double> ratios,
) {
  if (points.isEmpty || ratios.isEmpty) {
    return const _StreamlinePathData(points: <Offset>[], radii: <double>[]);
  }
  if (points.length == 1) {
    final Offset p = points.first;
    final double r = _streamlineRadiusAtIndex(radii, 0);
    return _StreamlinePathData(
      points: List<Offset>.filled(ratios.length, p, growable: false),
      radii: List<double>.filled(ratios.length, r, growable: false),
    );
  }

  final int sourceLength = points.length;
  final List<double> cumulative = List<double>.filled(sourceLength, 0.0);
  double total = 0.0;
  for (int i = 1; i < sourceLength; i++) {
    final double delta = (points[i] - points[i - 1]).distance;
    if (delta.isFinite) {
      total += delta;
    }
    cumulative[i] = total;
  }
  if (total <= 1e-5) {
    final Offset p = points.first;
    final double r = _streamlineRadiusAtIndex(radii, 0);
    return _StreamlinePathData(
      points: List<Offset>.filled(ratios.length, p, growable: false),
      radii: List<double>.filled(ratios.length, r, growable: false),
    );
  }

  final List<Offset> sampledPoints = List<Offset>.filled(
    ratios.length,
    points.first,
    growable: false,
  );
  final List<double> sampledRadii = List<double>.filled(
    ratios.length,
    _streamlineRadiusAtIndex(radii, 0),
    growable: false,
  );

  int segment = 0;
  for (int i = 0; i < ratios.length; i++) {
    final double ratio = ratios[i].isFinite ? ratios[i].clamp(0.0, 1.0) : 0.0;
    final double targetDist = ratio * total;

    while (segment < sourceLength - 2 && cumulative[segment + 1] < targetDist) {
      segment++;
    }

    final double d0 = cumulative[segment];
    final double d1 = cumulative[segment + 1];
    final double segmentLen = d1 - d0;
    final double localT = segmentLen <= 1e-5 ? 0.0 : (targetDist - d0) / segmentLen;

    sampledPoints[i] =
        Offset.lerp(points[segment], points[segment + 1], localT) ??
        points[segment + 1];

    final double r0 = _streamlineRadiusAtIndex(radii, segment);
    final double r1 = _streamlineRadiusAtIndex(radii, segment + 1);
    sampledRadii[i] = (ui.lerpDouble(r0, r1, localT) ?? r1).clamp(
      0.0,
      double.infinity,
    );
  }

  if (sampledPoints.isNotEmpty) {
    sampledPoints[0] = points.first;
    sampledRadii[0] = _streamlineRadiusAtIndex(radii, 0);
    sampledPoints[sampledPoints.length - 1] = points.last;
    sampledRadii[sampledRadii.length - 1] =
        _streamlineRadiusAtIndex(radii, points.length - 1);
  }

  return _StreamlinePathData(points: sampledPoints, radii: sampledRadii);
}

double _streamlineMaxDelta(List<Offset> a, List<Offset> b) {
  if (a.isEmpty || b.isEmpty) {
    return 0.0;
  }
  final int count = math.min(a.length, b.length);
  double maxDelta = 0.0;
  for (int i = 0; i < count; i++) {
    final double dist = (a[i] - b[i]).distance;
    if (dist.isFinite && dist > maxDelta) {
      maxDelta = dist;
    }
  }
  return maxDelta;
}
