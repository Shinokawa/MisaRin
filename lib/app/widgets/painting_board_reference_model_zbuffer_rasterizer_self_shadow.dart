part of 'painting_board.dart';

double _computeSelfShadowFactor({
  required Float32List shadowDepth,
  required int shadowSize,
  required double suLin,
  required double svLin,
  required double sdLin,
  required double shadowUMin,
  required double shadowVMin,
  required double shadowUScale,
  required double shadowVScale,
  required int radius,
  required double bias,
  required double strength,
}) {
  if (shadowSize <= 0 || strength <= 0) {
    return 1.0;
  }
  final double sx = (suLin - shadowUMin) * shadowUScale;
  final double sy = (svLin - shadowVMin) * shadowVScale;
  if (!sx.isFinite || !sy.isFinite) {
    return 1.0;
  }

  final int baseX = sx.floor();
  final int baseY = sy.floor();
  if (baseX < 0 || baseY < 0 || baseX >= shadowSize || baseY >= shadowSize) {
    return 1.0;
  }

  int lit = 0;
  int total = 0;
  for (int oy = -radius; oy <= radius; oy++) {
    final int py = baseY + oy;
    if (py < 0 || py >= shadowSize) {
      continue;
    }
    final int row = py * shadowSize;
    for (int ox = -radius; ox <= radius; ox++) {
      final int px = baseX + ox;
      if (px < 0 || px >= shadowSize) {
        continue;
      }
      total += 1;
      final double mapDepth = shadowDepth[row + px];
      if (mapDepth.isInfinite && mapDepth.isNegative) {
        lit += 1;
        continue;
      }
      if (sdLin >= mapDepth - bias) {
        lit += 1;
      }
    }
  }

  if (total <= 0) {
    return 1.0;
  }
  final double visibility = lit / total;
  double shadow = 1.0 - strength * (1.0 - visibility);
  shadow = shadow.clamp(0.0, 1.0).toDouble();
  return shadow;
}

