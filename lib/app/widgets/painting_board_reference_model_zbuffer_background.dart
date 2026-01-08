part of 'painting_board.dart';

class _BedrockSkyboxBackground {
  const _BedrockSkyboxBackground({
    required this.timeHours,
    required this.isDark,
    required this.skyColor,
    required this.sunColor,
    this.seed = 1337,
  });

  final double timeHours;
  final bool isDark;
  final Color skyColor;
  final Color sunColor;
  final int seed;
}

void _compositeOpaqueBackground({
  required Uint8List rgba,
  required int width,
  required int height,
  required Color background,
}) {
  if (width <= 0 || height <= 0) {
    return;
  }
  final int pixelCount = width * height;
  final int bgR = (background.r * 255).round().clamp(0, 255);
  final int bgG = (background.g * 255).round().clamp(0, 255);
  final int bgB = (background.b * 255).round().clamp(0, 255);

  for (int i = 0; i < pixelCount; i++) {
    final int byteIndex = i * 4;
    final int a = rgba[byteIndex + 3];
    if (a == 255) {
      continue;
    }
    if (a == 0) {
      rgba[byteIndex] = bgR;
      rgba[byteIndex + 1] = bgG;
      rgba[byteIndex + 2] = bgB;
      rgba[byteIndex + 3] = 255;
      continue;
    }
    final int invA = 255 - a;
    rgba[byteIndex] =
        ((rgba[byteIndex] * a + bgR * invA) / 255).round().clamp(0, 255);
    rgba[byteIndex + 1] =
        ((rgba[byteIndex + 1] * a + bgG * invA) / 255).round().clamp(0, 255);
    rgba[byteIndex + 2] =
        ((rgba[byteIndex + 2] * a + bgB * invA) / 255).round().clamp(0, 255);
    rgba[byteIndex + 3] = 255;
  }
}

double _smoothstep(double edge0, double edge1, double x) {
  final double t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

int _hash2d(int x, int y, int seed) {
  int h = seed & 0xffffffff;
  h = (h ^ (x * 0x27d4eb2d)) & 0xffffffff;
  h = (h ^ (y * 0x165667b1)) & 0xffffffff;
  h = (h ^ (h >> 15)) & 0xffffffff;
  h = (h * 0x85ebca6b) & 0xffffffff;
  h = (h ^ (h >> 13)) & 0xffffffff;
  h = (h * 0xc2b2ae35) & 0xffffffff;
  h = (h ^ (h >> 16)) & 0xffffffff;
  return h;
}

double _rand2d(int x, int y, int seed) {
  final int h = _hash2d(x, y, seed);
  return (h & 0xffff) / 65535.0;
}

double _smooth01(double t) => t * t * (3.0 - 2.0 * t);

double _valueNoise(double x, double y, int seed) {
  final int xi = x.floor();
  final int yi = y.floor();
  final double xf = x - xi;
  final double yf = y - yi;

  final double v00 = _rand2d(xi, yi, seed);
  final double v10 = _rand2d(xi + 1, yi, seed);
  final double v01 = _rand2d(xi, yi + 1, seed);
  final double v11 = _rand2d(xi + 1, yi + 1, seed);

  final double u = _smooth01(xf);
  final double v = _smooth01(yf);

  final double x1 = v00 + (v10 - v00) * u;
  final double x2 = v01 + (v11 - v01) * u;
  return x1 + (x2 - x1) * v;
}

double _fbm(double x, double y, int seed) {
  double sum = 0.0;
  double amp = 0.5;
  double freq = 1.0;
  double norm = 0.0;
  for (int i = 0; i < 4; i++) {
    sum += amp * _valueNoise(x * freq, y * freq, seed + i * 1013);
    norm += amp;
    freq *= 2.0;
    amp *= 0.5;
  }
  return norm > 0 ? sum / norm : 0.0;
}

Uint8List _buildCloudMask({
  required int width,
  required int height,
  required int seed,
}) {
  final Uint8List mask = Uint8List(width * height);
  if (width <= 0 || height <= 0) {
    return mask;
  }

  const double scale = 6.5;
  final double invW = 1.0 / width;
  final double invH = 1.0 / height;

  for (int y = 0; y < height; y++) {
    final double ny = y * invH * scale;
    final int row = y * width;
    for (int x = 0; x < width; x++) {
      final double nx = x * invW * scale;
      double n = _fbm(nx, ny, seed);
      n = n * n;
      mask[row + x] = (n * 255).round().clamp(0, 255);
    }
  }
  return mask;
}

void _compositeSkyboxBackground({
  required Uint8List rgba,
  required int width,
  required int height,
  required _BedrockSkyboxBackground skybox,
}) {
  if (width <= 0 || height <= 0) {
    return;
  }

  final double normalized = skybox.timeHours.isFinite
      ? (skybox.timeHours % 24 + 24) % 24
      : 12.0;
  final double dayPhase = ((normalized - 6.0) / 12.0) * math.pi;
  final double sunHeight = math.sin(dayPhase).clamp(-1.0, 1.0).toDouble();
  final double dayBlend = _smoothstep(-0.35, 0.15, sunHeight);

  final Color zenith = skybox.skyColor;
  final Color horizonTint =
      Color.lerp(zenith, skybox.sunColor, 0.16 + 0.18 * dayBlend) ?? zenith;
  final double whiteMix = skybox.isDark
      ? (0.05 + 0.18 * dayBlend).clamp(0.0, 0.28)
      : (0.18 + 0.52 * dayBlend).clamp(0.0, 0.82);
  final Color horizon =
      Color.lerp(horizonTint, const Color(0xFFFFFFFF), whiteMix) ?? horizonTint;

  final Color cloudBase = Color.lerp(
        zenith,
        const Color(0xFFFFFFFF),
        skybox.isDark ? 0.18 : 0.55,
      ) ??
      const Color(0xFFFFFFFF);
  final Color cloudColor =
      Color.lerp(cloudBase, skybox.sunColor, 0.06 + 0.18 * dayBlend) ??
          cloudBase;

  int to8(double v) => (v * 255).round().clamp(0, 255);

  final int zenithR = to8(zenith.r);
  final int zenithG = to8(zenith.g);
  final int zenithB = to8(zenith.b);
  final int horizonR = to8(horizon.r);
  final int horizonG = to8(horizon.g);
  final int horizonB = to8(horizon.b);

  final int cloudR = to8(cloudColor.r);
  final int cloudG = to8(cloudColor.g);
  final int cloudB = to8(cloudColor.b);

  final double coverage =
      (skybox.isDark ? 0.60 : 0.55) + (0.04 * (1.0 - dayBlend));
  final int threshold = (coverage.clamp(0.0, 0.92) * 255).round().clamp(0, 254);
  final int denom = 255 - threshold;
  final int cloudStrength =
      ((0.25 + 0.60 * dayBlend) * (skybox.isDark ? 0.65 : 1.0) * 255)
          .round()
          .clamp(0, 255);

  final int maskW = math.min(512, math.max(128, width ~/ 4));
  final int maskH = math.max(64, (maskW * height / width).round());
  final Uint8List cloudMask = _buildCloudMask(
    width: maskW,
    height: maskH,
    seed: skybox.seed,
  );

  final int maxY = math.max(1, height - 1);
  for (int y = 0; y < height; y++) {
    final double v = y / maxY;
    final double t = v * v * (3.0 - 2.0 * v);
    final int lerpT = (t * 255).round().clamp(0, 255);

    final int baseR = (zenithR * (255 - lerpT) + horizonR * lerpT) ~/ 255;
    final int baseG = (zenithG * (255 - lerpT) + horizonG * lerpT) ~/ 255;
    final int baseB = (zenithB * (255 - lerpT) + horizonB * lerpT) ~/ 255;

    final double fade = 1.0 - _smoothstep(0.55, 0.98, v);
    final int fade8 = (fade * 255).round().clamp(0, 255);

    final int maskY = (y * maskH) ~/ height;
    final int maskRow = maskY * maskW;
    final int rowStart = y * width;

    for (int x = 0; x < width; x++) {
      final int pixelIndex = rowStart + x;
      final int byteIndex = pixelIndex * 4;
      final int a = rgba[byteIndex + 3];
      if (a == 255) {
        continue;
      }

      final int maskX = (x * maskW) ~/ width;
      final int m = cloudMask[maskRow + maskX];

      int cloudA = 0;
      if (fade8 > 0 && cloudStrength > 0 && m > threshold) {
        final int base = ((m - threshold) * 255) ~/ denom;
        final int faded = (base * fade8) ~/ 255;
        cloudA = (faded * cloudStrength) ~/ 255;
      }

      final int bgR = cloudA == 0
          ? baseR
          : (baseR * (255 - cloudA) + cloudR * cloudA) ~/ 255;
      final int bgG = cloudA == 0
          ? baseG
          : (baseG * (255 - cloudA) + cloudG * cloudA) ~/ 255;
      final int bgB = cloudA == 0
          ? baseB
          : (baseB * (255 - cloudA) + cloudB * cloudA) ~/ 255;

      if (a == 0) {
        rgba[byteIndex] = bgR;
        rgba[byteIndex + 1] = bgG;
        rgba[byteIndex + 2] = bgB;
        rgba[byteIndex + 3] = 255;
        continue;
      }

      final int invA = 255 - a;
      rgba[byteIndex] =
          ((rgba[byteIndex] * a + bgR * invA) / 255).round().clamp(0, 255);
      rgba[byteIndex + 1] = ((rgba[byteIndex + 1] * a + bgG * invA) / 255)
          .round()
          .clamp(0, 255);
      rgba[byteIndex + 2] = ((rgba[byteIndex + 2] * a + bgB * invA) / 255)
          .round()
          .clamp(0, 255);
      rgba[byteIndex + 3] = 255;
    }
  }
}

