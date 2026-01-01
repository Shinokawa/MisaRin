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

int _mix32(int value) {
  int h = value & 0xffffffff;
  h ^= (h >> 16);
  h = (h * 0x7feb352d) & 0xffffffff;
  h ^= (h >> 15);
  h = (h * 0x846ca68b) & 0xffffffff;
  h ^= (h >> 16);
  return h;
}

