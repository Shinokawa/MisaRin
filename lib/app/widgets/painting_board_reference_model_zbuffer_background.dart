part of 'painting_board.dart';

class _BedrockSkyboxBackground {
  const _BedrockSkyboxBackground({
    required this.timeHours,
    required this.isDark,
    required this.skyColor,
    required this.sunColor,
    required this.lightDirection,
    this.seed = 1337,
  });

  final double timeHours;
  final bool isDark;
  final Color skyColor;
  final Color sunColor;
  final Vector3 lightDirection;
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
    rgba[byteIndex] = (rgba[byteIndex] + ((bgR * invA + 127) ~/ 255))
        .clamp(0, 255);
    rgba[byteIndex + 1] =
        (rgba[byteIndex + 1] + ((bgG * invA + 127) ~/ 255)).clamp(0, 255);
    rgba[byteIndex + 2] =
        (rgba[byteIndex + 2] + ((bgB * invA + 127) ~/ 255)).clamp(0, 255);
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

void _compositeSkyboxBackground({
  required Uint8List rgba,
  required int width,
  required int height,
  required _BedrockSkyboxBackground skybox,
  required double cameraYaw,
  required double cameraPitch,
  required double cameraZoom,
}) {
  if (width <= 0 || height <= 0) {
    return;
  }

  final _BakeSkyboxPalette palette = _computeBakeSkyboxPalette(
    timeHours: skybox.timeHours,
    isDark: skybox.isDark,
    skyColor: skybox.skyColor,
    sunColor: skybox.sunColor,
  );
  final Color zenith = palette.zenith;
  final Color horizon = palette.horizon;
  final Color cloudColor = palette.cloudColor;
  final Color highlightColor = palette.highlightColor;
  final Color shadowColor = palette.shadowColor;

  final double normalizedTime = skybox.timeHours.isFinite
      ? (skybox.timeHours % 24 + 24) % 24
      : 12.0;
  final double dayPhase = ((normalizedTime - 6.0) / 12.0) * math.pi;
  final double sunHeight = math.sin(dayPhase).clamp(-1.0, 1.0).toDouble();
  final double dayBlend = palette.dayBlend.clamp(0.0, 1.0).toDouble();
  final double nightBlend = (1.0 - dayBlend).clamp(0.0, 1.0).toDouble();

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

  final int highlightR = to8(highlightColor.r);
  final int highlightG = to8(highlightColor.g);
  final int highlightB = to8(highlightColor.b);

  final int shadowR = to8(shadowColor.r);
  final int shadowG = to8(shadowColor.g);
  final int shadowB = to8(shadowColor.b);

  final Color sunDiscBase = Color.lerp(
        const Color(0xFFFFA36D),
        skybox.sunColor,
        0.65,
      ) ??
      skybox.sunColor;
  final Color moonDiscBase =
      Color.lerp(const Color(0xFF8FA5CC), skybox.sunColor, 0.85) ??
          skybox.sunColor;
  final int sunDiscR = to8(sunDiscBase.r);
  final int sunDiscG = to8(sunDiscBase.g);
  final int sunDiscB = to8(sunDiscBase.b);
  final int moonDiscR = to8(moonDiscBase.r);
  final int moonDiscG = to8(moonDiscBase.g);
  final int moonDiscB = to8(moonDiscBase.b);

  final int cloudOpacity8 = (palette.cloudOpacity * 255).round().clamp(0, 255);
  final int shadowOpacity8 = (palette.shadowOpacity * 255).round().clamp(0, 255);
  final int highlightOpacity8 =
      (palette.highlightOpacity * 255).round().clamp(0, 255);

  int lerp8(int a, int b, int t) {
    return a + (((b - a) * t + 128) >> 8);
  }

  int rand8(int x, int y, int seedOffset) {
    final int h = _hash2d(x, y, seedOffset);
    return (h >> 16) & 0xff;
  }

  int sampleNoise(double x, double y, int seedOffset) {
    final int xi = x.floor();
    final int yi = y.floor();
    final int fx = ((x - xi) * 256).floor().clamp(0, 255);
    final int fy = ((y - yi) * 256).floor().clamp(0, 255);

    final int a00 = rand8(xi, yi, seedOffset);
    final int a10 = rand8(xi + 1, yi, seedOffset);
    final int a01 = rand8(xi, yi + 1, seedOffset);
    final int a11 = rand8(xi + 1, yi + 1, seedOffset);

    final int a0 = lerp8(a00, a10, fx);
    final int a1 = lerp8(a01, a11, fx);
    return lerp8(a0, a1, fy);
  }

  int fbm8(double x, double y, int seedOffset) {
    double sum = 0.0;
    double amp = 0.52;
    double norm = 0.0;
    double freq = 1.0;
    for (int i = 0; i < 5; i++) {
      sum += (sampleNoise(x * freq, y * freq, seedOffset) / 255.0) * amp;
      norm += amp;
      amp *= 0.5;
      freq *= 2.0;
    }
    if (norm <= 1e-6) {
      return 0;
    }
    return ((sum / norm) * 255).round().clamp(0, 255);
  }

  int blendOver(int dst, int src, int alpha) {
    if (alpha <= 0) {
      return dst;
    }
    if (alpha >= 255) {
      return src;
    }
    return (dst * (255 - alpha) + src * alpha + 127) ~/ 255;
  }

  int blendScreen(int dst, int src, int alpha) {
    if (alpha <= 0) {
      return dst;
    }
    final int screen = 255 - (((255 - dst) * (255 - src) + 127) ~/ 255);
    if (alpha >= 255) {
      return screen;
    }
    return dst + ((screen - dst) * alpha + 127) ~/ 255;
  }

  final double zoomFactor = cameraZoom.isFinite
      ? cameraZoom.clamp(0.8, 2.5).toDouble()
      : 1.0;
  final double fov = 1.1 / zoomFactor;
  final double aspect = width / math.max(height, 1);
  final double cosYaw = math.cos(cameraYaw.isFinite ? cameraYaw : 0.0);
  final double sinYaw = math.sin(cameraYaw.isFinite ? cameraYaw : 0.0);
  final double cosPitch = math.cos(cameraPitch.isFinite ? cameraPitch : 0.0);
  final double sinPitch = math.sin(cameraPitch.isFinite ? cameraPitch : 0.0);

  final double tileSize = math.max(
    128.0,
    math.min(width.toDouble(), height.toDouble()) * 1.60 * zoomFactor,
  );
  final double scale = 8.0 / tileSize;
  final double seedScrollX = _rand2d(17, 31, skybox.seed) * 900.0;
  final double seedScrollY = _rand2d(43, 59, skybox.seed) * 900.0;
  final double timeDrift = skybox.timeHours.isFinite ? skybox.timeHours : 0.0;
  final double camYaw = cameraYaw.isFinite ? cameraYaw : 0.0;
  final double camPitch = cameraPitch.isFinite ? cameraPitch : 0.0;
  final double scrollX =
      seedScrollX + timeDrift * 0.38 + camYaw / (math.pi * 2) * 120.0;
  final double scrollY =
      seedScrollY + timeDrift * 0.16 - camPitch / math.pi * 80.0;

  ({double x, double y})? projectDir(double x, double y, double z) {
    final double x1 = cosYaw * x + sinYaw * z;
    final double y1 = y;
    final double z1 = -sinYaw * x + cosYaw * z;
    final double x2 = x1;
    final double y2 = cosPitch * y1 - sinPitch * z1;
    final double z2 = sinPitch * y1 + cosPitch * z1;
    if (z2 <= 1e-3) {
      return null;
    }
    final double px = x2 * fov / z2;
    final double py = y2 * fov / z2;
    final double u = px / (2.0 * aspect) + 0.5;
    final double v = 0.5 - py / 2.0;
    if (u.isNaN || v.isNaN) {
      return null;
    }
    return (x: u * width, y: v * height);
  }

  final double azimuth = (normalizedTime / 24.0) * math.pi * 2.0;
  final Vector3 sunDir = Vector3(math.cos(azimuth), sunHeight, -math.sin(azimuth));
  if (sunDir.length2 > 1e-6) {
    sunDir.normalize();
  }
  final Vector3 moonDir =
      Vector3(math.cos(azimuth + math.pi), -sunHeight, -math.sin(azimuth + math.pi));
  if (moonDir.length2 > 1e-6) {
    moonDir.normalize();
  }

  final double sunVis =
      (_smoothstep(-0.12, 0.05, sunHeight) * dayBlend).clamp(0.0, 1.0);
  final double moonVis =
      (_smoothstep(-0.10, 0.06, -sunHeight) * nightBlend).clamp(0.0, 1.0);

  final ({double x, double y})? sunCenter =
      sunVis > 1e-6 ? projectDir(sunDir.x, sunDir.y, sunDir.z) : null;
  final ({double x, double y})? moonCenter =
      moonVis > 1e-6 ? projectDir(moonDir.x, moonDir.y, moonDir.z) : null;

  final double sunCoreRadius = math.tan(0.040) / fov * (height / 2.0);
  final double sunGlowRadius = math.tan(0.130) / fov * (height / 2.0);
  final double moonCoreRadius = math.tan(0.034) / fov * (height / 2.0);
  final double moonGlowRadius = math.tan(0.090) / fov * (height / 2.0);

  final double sunGlowR2 = sunGlowRadius * sunGlowRadius;
  final double sunCoreR2 = sunCoreRadius * sunCoreRadius;
  final double moonGlowR2 = moonGlowRadius * moonGlowRadius;
  final double moonCoreR2 = moonCoreRadius * moonCoreRadius;

  final double starStrength = math.pow(nightBlend, 1.8).clamp(0.0, 1.0).toDouble();
  final int starSeed = skybox.seed ^ 0x5bd1e995;
  final int starShiftX = ((camYaw / (math.pi * 2)) * 2048).round();
  final int starShiftY = ((-camPitch / math.pi) * 1024).round();

  double lightDx = skybox.lightDirection.x;
  double lightDy = -skybox.lightDirection.z;
  final double lightLen =
      math.sqrt(lightDx * lightDx + lightDy * lightDy).toDouble();
  if (lightLen > 1e-6) {
    lightDx /= lightLen;
    lightDy /= lightLen;
  } else {
    lightDx = 1.0;
    lightDy = 0.0;
  }
  final double offsetPx =
      (math.min(width.toDouble(), height.toDouble()) * 0.018)
          .clamp(2.0, 12.0);
  final double shiftX = lightDx * offsetPx * scale;
  final double shiftY = lightDy * offsetPx * scale;

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
    final double starFade = 1.0 - _smoothstep(0.40, 0.98, v);
    final int starRow8 = (starStrength * starFade * 255).round().clamp(0, 255);
    final int rowStart = y * width;
    final double my = scrollY + y * scale;

    for (int x = 0; x < width; x++) {
      final int pixelIndex = rowStart + x;
      final int byteIndex = pixelIndex * 4;
      final int a = rgba[byteIndex + 3];
      if (a == 255) {
        continue;
      }

      int bgR = baseR;
      int bgG = baseG;
      int bgB = baseB;

      if (starRow8 > 0) {
        final int qx = (x + starShiftX) >> 1;
        final int qy = (y + starShiftY) >> 1;
        final int h = _hash2d(qx, qy, starSeed);
        final int r8 = (h >> 16) & 0xff;
        if (r8 >= 252) {
          final int strength =
              (((r8 - 252) * 85).clamp(0, 255) * starRow8) ~/ 255;
          final int temp = (h >> 8) & 0xff;
          final int sR = (220 + (temp & 0x1f)).clamp(0, 255);
          final int sG = (232 + ((temp >> 2) & 0x1f)).clamp(0, 255);
          const int sB = 255;
          bgR = blendScreen(bgR, sR, strength);
          bgG = blendScreen(bgG, sG, strength);
          bgB = blendScreen(bgB, sB, strength);
        }
      }

      if (sunCenter != null) {
        final double dx = x - sunCenter.x;
        final double dy = y - sunCenter.y;
        final double d2 = dx * dx + dy * dy;
        if (d2 <= sunGlowR2) {
          final double w =
              ((1.0 - d2 / sunGlowR2).clamp(0.0, 1.0).toDouble());
          final int alpha =
              (sunVis * 255.0 * math.pow(w, 2.4)).round().clamp(0, 255);
          if (alpha > 0) {
            bgR = blendScreen(bgR, sunDiscR, (alpha * 115) ~/ 255);
            bgG = blendScreen(bgG, sunDiscG, (alpha * 115) ~/ 255);
            bgB = blendScreen(bgB, sunDiscB, (alpha * 115) ~/ 255);
          }
        }
        if (d2 <= sunCoreR2) {
          final double w = (1.0 - d2 / sunCoreR2).clamp(0.0, 1.0).toDouble();
          final int alpha =
              (sunVis * 255.0 * math.pow(w, 1.8)).round().clamp(0, 255);
          if (alpha > 0) {
            bgR = blendScreen(bgR, sunDiscR, (alpha * 230) ~/ 255);
            bgG = blendScreen(bgG, sunDiscG, (alpha * 230) ~/ 255);
            bgB = blendScreen(bgB, sunDiscB, (alpha * 230) ~/ 255);
          }
        }
      }

      if (moonCenter != null) {
        final double dx = x - moonCenter.x;
        final double dy = y - moonCenter.y;
        final double d2 = dx * dx + dy * dy;
        if (d2 <= moonGlowR2) {
          final double w =
              ((1.0 - d2 / moonGlowR2).clamp(0.0, 1.0).toDouble());
          final int alpha =
              (moonVis * 255.0 * math.pow(w, 2.0)).round().clamp(0, 255);
          if (alpha > 0) {
            bgR = blendScreen(bgR, moonDiscR, (alpha * 70) ~/ 255);
            bgG = blendScreen(bgG, moonDiscG, (alpha * 70) ~/ 255);
            bgB = blendScreen(bgB, moonDiscB, (alpha * 70) ~/ 255);
          }
        }
        if (d2 <= moonCoreR2) {
          final double w =
              (1.0 - d2 / moonCoreR2).clamp(0.0, 1.0).toDouble();
          final int alpha =
              (moonVis * 255.0 * math.pow(w, 1.6)).round().clamp(0, 255);
          if (alpha > 0) {
            bgR = blendScreen(bgR, moonDiscR, (alpha * 160) ~/ 255);
            bgG = blendScreen(bgG, moonDiscG, (alpha * 160) ~/ 255);
            bgB = blendScreen(bgB, moonDiscB, (alpha * 160) ~/ 255);
          }
        }
      }

      if (fade8 > 0 && cloudOpacity8 > 0) {
        final double sx = scrollX + x * scale;
        final int n0 = fbm8(sx, my, skybox.seed);
        final int nF = fbm8(sx + shiftX, my + shiftY, skybox.seed);
        final int nB = fbm8(sx - shiftX, my - shiftY, skybox.seed);

        final double cloudiness = cloudOpacity8 / 255.0;
        final double threshold = 0.64 - 0.14 * cloudiness;
        final int m0 = ((n0 / 255.0 - threshold) / 0.22 * 255)
            .round()
            .clamp(0, 255);
        final int mF = ((nF / 255.0 - threshold) / 0.22 * 255)
            .round()
            .clamp(0, 255);
        final int mB = ((nB / 255.0 - threshold) / 0.22 * 255)
            .round()
            .clamp(0, 255);

        if (m0 > 0 || mF > 0 || mB > 0) {
          final int cloudA = ((m0 * cloudOpacity8) ~/ 255 * fade8) ~/ 255;
          final int shadowA = ((mB * shadowOpacity8) ~/ 255 * fade8) ~/ 255;
          final int highlightA =
              ((mF * highlightOpacity8) ~/ 255 * fade8) ~/ 255;

          if (shadowA > 0) {
            bgR = blendOver(bgR, shadowR, shadowA);
            bgG = blendOver(bgG, shadowG, shadowA);
            bgB = blendOver(bgB, shadowB, shadowA);
          }

          if (cloudA > 0) {
            bgR = blendOver(bgR, cloudR, cloudA);
            bgG = blendOver(bgG, cloudG, cloudA);
            bgB = blendOver(bgB, cloudB, cloudA);
          }

          if (highlightA > 0) {
            bgR = blendScreen(bgR, highlightR, highlightA);
            bgG = blendScreen(bgG, highlightG, highlightA);
            bgB = blendScreen(bgB, highlightB, highlightA);
          }
        }
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
          (rgba[byteIndex] + ((bgR * invA + 127) ~/ 255)).clamp(0, 255);
      rgba[byteIndex + 1] =
          (rgba[byteIndex + 1] + ((bgG * invA + 127) ~/ 255)).clamp(0, 255);
      rgba[byteIndex + 2] =
          (rgba[byteIndex + 2] + ((bgB * invA + 127) ~/ 255)).clamp(0, 255);
      rgba[byteIndex + 3] = 255;
    }
  }
}
