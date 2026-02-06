import 'dart:math' as math;
import 'dart:ui';

double brushRandomRotationRadians({
  required Offset center,
  required int seed,
}) {
  final int x = (center.dx * 256.0).round();
  final int y = (center.dy * 256.0).round();

  int h = 0;
  h ^= seed & 0xffffffff;
  h ^= (x * 0x9e3779b1) & 0xffffffff;
  h ^= (y * 0x85ebca77) & 0xffffffff;
  h = _mix32(h);

  final int unsigned = h & 0xffffffff;
  final double unit = unsigned / 0x100000000;
  return unit * math.pi * 2.0;
}

double brushRandomUnit({
  required Offset center,
  required int seed,
  int salt = 0,
}) {
  final int x = (center.dx * 256.0).round();
  final int y = (center.dy * 256.0).round();

  int h = 0;
  h ^= seed & 0xffffffff;
  h ^= salt & 0xffffffff;
  h ^= (x * 0x9e3779b1) & 0xffffffff;
  h ^= (y * 0x85ebca77) & 0xffffffff;
  h = _mix32(h);

  final int unsigned = h & 0xffffffff;
  return unsigned / 0x100000000;
}

Offset brushScatterOffset({
  required Offset center,
  required int seed,
  required double radius,
  int salt = 0,
}) {
  if (!radius.isFinite || radius <= 0) {
    return Offset.zero;
  }
  final double u = brushRandomUnit(center: center, seed: seed, salt: salt);
  final double v = brushRandomUnit(center: center, seed: seed, salt: salt + 1);
  final double dist = math.sqrt(u) * radius;
  final double angle = v * math.pi * 2.0;
  return Offset(math.cos(angle) * dist, math.sin(angle) * dist);
}

int _mix32(int value) {
  int h = value & 0xffffffff;
  h ^= (h >> 16);
  h = (h * 0x7feb352d) & 0xffffffff;
  h ^= (h >> 15);
  h = (h * 0x846ca68b) & 0xffffffff;
  h ^= (h >> 16);
  return h;
}
