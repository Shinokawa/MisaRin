import 'dart:math' as math;

double mapStrokeStabilizerStrength(double raw) {
  if (!raw.isFinite) {
    return 0.0;
  }
  final double s = raw.clamp(0.0, 1.0);
  if (s <= 0.0001) {
    return 0.0;
  }
  // SAI2-like curve: keep low levels responsive, ramp up strongly near the top.
  final double eased = math.pow(s, 2.0).toDouble();
  final double mixed = (0.15 * s) + (0.85 * eased);
  return mixed.clamp(0.0, 1.0);
}
