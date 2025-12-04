import 'dart:math' as math;

/// Shared helper functions that convert a [softness] value (0-1) into
/// geometric parameters for soft circular brush stamps.
double softBrushExtentMultiplier(double softness) {
  if (softness <= 0.0) {
    return 0.0;
  }
  final double curve = _softBrushCurve(softness);
  return 0.55 + 1.75 * curve;
}

double softBrushInnerRadiusFraction(double softness) {
  if (softness <= 0.0) {
    return 1.0;
  }
  final double curve = _softBrushCurve(softness);
  final double shrink = (0.2 + 0.75 * curve).clamp(0.0, 0.98);
  return (1.0 - shrink).clamp(0.0, 1.0);
}

double softBrushFalloffExponent(double softness) {
  if (softness <= 0.0) {
    return 2.2;
  }
  final double curve = _softBrushCurve(softness);
  return 2.0 + 1.1 * curve;
}

double _softBrushCurve(double softness) =>
    math.pow(softness.clamp(0.0, 1.0), 0.85).toDouble();
