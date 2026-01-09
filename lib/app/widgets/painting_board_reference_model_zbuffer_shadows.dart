part of 'painting_board.dart';

void _rasterizeContactShadowMask({
  required Float32List depthBuffer,
  required Uint8List mask,
  required int width,
  required int height,
  required double depthEpsilon,
}) {
  final double eps = depthEpsilon.isFinite
      ? depthEpsilon.clamp(0.0, 0.25).toDouble()
      : 0.01;
  if (eps <= 0) {
    mask.fillRange(0, mask.length, 0);
    return;
  }
  final double invScale = 1.0 / (1.0 - eps);
  final double relFactor = invScale - 1.0;

  final int pixelCount = width * height;
  double maxInvZ = 0.0;
  for (int i = 0; i < pixelCount && i < depthBuffer.length; i++) {
    final double v = depthBuffer[i];
    if (v > maxInvZ) {
      maxInvZ = v;
    }
  }
  if (maxInvZ <= 0 || relFactor <= 0) {
    mask.fillRange(0, mask.length, 0);
    return;
  }

  final int minDim = math.min(width, height);
  final double minDeltaScale = minDim <= 0
      ? 0.25
      : math.max(0.25, 1.0 / (relFactor * minDim));
  final double minDelta = maxInvZ * relFactor * minDeltaScale;
  mask.fillRange(0, mask.length, 0);

  for (int y = 0; y < height; y++) {
    final int row = y * width;
    for (int x = 0; x < width; x++) {
      final int index = row + x;
      final double invZ = depthBuffer[index];
      if (invZ <= 0) {
        continue;
      }
      final double threshold = invZ + math.max(invZ * relFactor, minDelta);

      bool occluded = false;
      for (int oy = -1; oy <= 1 && !occluded; oy++) {
        final int ny = y + oy;
        if (ny < 0 || ny >= height) {
          continue;
        }
        final int nRow = ny * width;
        for (int ox = -1; ox <= 1; ox++) {
          if (ox == 0 && oy == 0) {
            continue;
          }
          final int nx = x + ox;
          if (nx < 0 || nx >= width) {
            continue;
          }
          final double nInvZ = depthBuffer[nRow + nx];
          if (nInvZ > threshold) {
            occluded = true;
            break;
          }
        }
      }

      if (occluded) {
        mask[index] = 255;
      }
    }
  }
}

BedrockMesh _buildGroundMesh({
  required double groundY,
  required double halfSize,
  required bool doubleSided,
}) {
  final Vector3 p0 = Vector3(-halfSize, groundY, -halfSize);
  final Vector3 p1 = Vector3(halfSize, groundY, -halfSize);
  final Vector3 p2 = Vector3(halfSize, groundY, halfSize);
  final Vector3 p3 = Vector3(-halfSize, groundY, halfSize);

  final Vector3 up = Vector3(0, 1, 0);
  final Vector3 down = Vector3(0, -1, 0);

  return BedrockMesh(
    triangles: <BedrockMeshTriangle>[
      BedrockMeshTriangle(
        p0: p0,
        p1: p1,
        p2: p2,
        uv0: Offset.zero,
        uv1: Offset.zero,
        uv2: Offset.zero,
        normal: up,
      ),
      BedrockMeshTriangle(
        p0: p0,
        p1: p2,
        p2: p3,
        uv0: Offset.zero,
        uv1: Offset.zero,
        uv2: Offset.zero,
        normal: up,
      ),
      if (doubleSided) ...[
        BedrockMeshTriangle(
          p0: p0,
          p1: p2,
          p2: p1,
          uv0: Offset.zero,
          uv1: Offset.zero,
          uv2: Offset.zero,
          normal: down,
        ),
        BedrockMeshTriangle(
          p0: p0,
          p1: p3,
          p2: p2,
          uv0: Offset.zero,
          uv1: Offset.zero,
          uv2: Offset.zero,
          normal: down,
        ),
      ],
    ],
    boundsMin: Vector3(-halfSize, groundY, -halfSize),
    boundsMax: Vector3(halfSize, groundY, halfSize),
  );
}

void _rasterizePlanarShadowMask({
  required BedrockMesh mesh,
  required Uint8List mask,
  required Float32List depthBuffer,
  required int width,
  required int height,
  required Vector3 modelExtent,
  required double yaw,
  required double pitch,
  required double zoom,
  required Vector3 lightDirection,
  required bool lightFollowsCamera,
  required double groundY,
  double translateY = 0.0,
  Uint8List? textureRgba,
  int textureWidth = 0,
  int textureHeight = 0,
  int modelTextureWidth = 0,
  int modelTextureHeight = 0,
  int alphaCutoff = 1,
}) {
  if (mesh.triangles.isEmpty || width <= 0 || height <= 0) {
    return;
  }

  final double extent = math.max(
    modelExtent.x.abs(),
    math.max(modelExtent.y.abs(), modelExtent.z.abs()),
  );
  if (extent <= 0) {
    return;
  }

  final Matrix4 rotation = Matrix4.identity()
    ..rotateY(yaw)
    ..rotateX(pitch);
  final Float64List r = rotation.storage;

  double transformX(double x, double y, double z) =>
      r[0] * x + r[4] * y + r[8] * z;
  double transformY(double x, double y, double z) =>
      r[1] * x + r[5] * y + r[9] * z;
  double transformZ(double x, double y, double z) =>
      r[2] * x + r[6] * y + r[10] * z;

  final Vector3 lightDir = lightDirection.clone();
  if (lightDir.length2 <= 0) {
    lightDir.setFrom(_BedrockModelZBufferViewState._defaultLightDirection);
  } else {
    lightDir.normalize();
  }

  final Vector3 lightDirModel = lightFollowsCamera
      ? ((rotation.clone()..transpose()).transform3(lightDir.clone())
        ..normalize())
      : lightDir;
  final Vector3 shadowDir = -lightDirModel;
  if (shadowDir.y.abs() <= _BedrockModelZBufferViewState._kShadowDirectionEpsilon) {
    return;
  }

  final double centerX = width * 0.5;
  final double centerY = height * 0.5;
  final double baseScale =
      (math.min(width.toDouble(), height.toDouble()) / extent) * 0.9;
  final double scale = baseScale * zoom;
  final double cameraDistance = extent * 2.4;

  final int alphaCutoffClamped = alphaCutoff.clamp(1, 255);
  final bool alphaTest = textureRgba != null &&
      textureWidth > 0 &&
      textureHeight > 0 &&
      modelTextureWidth > 0 &&
      modelTextureHeight > 0;
  final double texUScale = alphaTest ? textureWidth / modelTextureWidth : 1.0;
  final double texVScale = alphaTest ? textureHeight / modelTextureHeight : 1.0;

  double edge(
    double ax,
    double ay,
    double bx,
    double by,
    double cx,
    double cy,
  ) {
    return (cx - ax) * (by - ay) - (cy - ay) * (bx - ax);
  }

  int clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  Vector3 project(Vector3 p) {
    final double y = p.y + translateY;
    final double t = (groundY - y) / shadowDir.y;
    return Vector3(
      p.x + shadowDir.x * t,
      y + shadowDir.y * t,
      p.z + shadowDir.z * t,
    );
  }

  for (final BedrockMeshTriangle tri in mesh.triangles) {
    final double tu0 = alphaTest ? tri.uv0.dx * texUScale : 0.0;
    final double tv0 = alphaTest ? tri.uv0.dy * texVScale : 0.0;
    final double tu1 = alphaTest ? tri.uv1.dx * texUScale : 0.0;
    final double tv1 = alphaTest ? tri.uv1.dy * texVScale : 0.0;
    final double tu2 = alphaTest ? tri.uv2.dx * texUScale : 0.0;
    final double tv2 = alphaTest ? tri.uv2.dy * texVScale : 0.0;

    final Vector3 a = project(tri.p0);
    final Vector3 b = project(tri.p1);
    final Vector3 c = project(tri.p2);

    final double axw = transformX(a.x, a.y, a.z);
    final double ayw = transformY(a.x, a.y, a.z);
    final double azw = transformZ(a.x, a.y, a.z);
    final double bxw = transformX(b.x, b.y, b.z);
    final double byw = transformY(b.x, b.y, b.z);
    final double bzw = transformZ(b.x, b.y, b.z);
    final double cxw = transformX(c.x, c.y, c.z);
    final double cyw = transformY(c.x, c.y, c.z);
    final double czw = transformZ(c.x, c.y, c.z);

    final double za = azw + cameraDistance;
    final double zb = bzw + cameraDistance;
    final double zc = czw + cameraDistance;
    if (za <= 0 || zb <= 0 || zc <= 0) {
      continue;
    }

    final double sa = cameraDistance / za;
    final double sb = cameraDistance / zb;
    final double sc = cameraDistance / zc;

    final double x0 = centerX + axw * sa * scale;
    final double y0 = centerY + (-ayw) * sa * scale;
    final double x1 = centerX + bxw * sb * scale;
    final double y1 = centerY + (-byw) * sb * scale;
    final double x2 = centerX + cxw * sc * scale;
    final double y2 = centerY + (-cyw) * sc * scale;

    final double area = edge(x0, y0, x1, y1, x2, y2);
    if (area == 0) {
      continue;
    }
    final double invArea = 1.0 / area;

    final double minX = math.min(x0, math.min(x1, x2));
    final double maxX = math.max(x0, math.max(x1, x2));
    final double minY = math.min(y0, math.min(y1, y2));
    final double maxY = math.max(y0, math.max(y1, y2));
    final int xStart = clampInt(minX.floor(), 0, width - 1);
    final int xEnd = clampInt(maxX.ceil(), 0, width - 1);
    final int yStart = clampInt(minY.floor(), 0, height - 1);
    final int yEnd = clampInt(maxY.ceil(), 0, height - 1);

    for (int y = yStart; y <= yEnd; y++) {
      final double py = y + 0.5;
      final int row = y * width;
      for (int x = xStart; x <= xEnd; x++) {
        final double px = x + 0.5;
        final double w0 = edge(x1, y1, x2, y2, px, py);
        final double w1 = edge(x2, y2, x0, y0, px, py);
        final double w2 = edge(x0, y0, x1, y1, px, py);
        if (area > 0) {
          if (w0 < 0 || w1 < 0 || w2 < 0) {
            continue;
          }
        } else {
          if (w0 > 0 || w1 > 0 || w2 > 0) {
            continue;
          }
        }

        final double alpha = w0 * invArea;
        final double beta = w1 * invArea;
        final double gamma = w2 * invArea;
        final double z = alpha * za + beta * zb + gamma * zc;
        if (z <= 0) {
          continue;
        }

        if (alphaTest) {
          final double uTex = alpha * tu0 + beta * tu1 + gamma * tu2;
          final double vTex = alpha * tv0 + beta * tv1 + gamma * tv2;
          final int uSample = clampInt(uTex.floor(), 0, textureWidth - 1);
          final int vSample = clampInt(vTex.floor(), 0, textureHeight - 1);
          final int texIndex = (vSample * textureWidth + uSample) * 4;
          final int a8 = textureRgba![texIndex + 3];
          if (a8 < alphaCutoffClamped) {
            continue;
          }
        }

        final int index = row + x;
        if (depthBuffer[index] <= 0) {
          continue;
        }
        mask[index] = 255;
      }
    }
  }
}

void _blurMask({
  required Uint8List mask,
  required Uint8List scratch,
  required int width,
  required int height,
  required int radius,
}) {
  if (radius <= 0 || width <= 0 || height <= 0) {
    return;
  }
  final int window = radius * 2 + 1;

  for (int y = 0; y < height; y++) {
    final int rowStart = y * width;
    int sum = 0;
    for (int i = -radius; i <= radius; i++) {
      final int x = i < 0 ? 0 : (i >= width ? width - 1 : i);
      sum += mask[rowStart + x];
    }
    for (int x = 0; x < width; x++) {
      scratch[rowStart + x] = sum ~/ window;
      final int removeX = x - radius;
      final int addX = x + radius + 1;
      final int rx =
          removeX < 0 ? 0 : (removeX >= width ? width - 1 : removeX);
      final int ax = addX < 0 ? 0 : (addX >= width ? width - 1 : addX);
      sum += mask[rowStart + ax] - mask[rowStart + rx];
    }
  }

  for (int x = 0; x < width; x++) {
    int sum = 0;
    for (int i = -radius; i <= radius; i++) {
      final int y = i < 0 ? 0 : (i >= height ? height - 1 : i);
      sum += scratch[y * width + x];
    }
    for (int y = 0; y < height; y++) {
      mask[y * width + x] = sum ~/ window;
      final int removeY = y - radius;
      final int addY = y + radius + 1;
      final int ry =
          removeY < 0 ? 0 : (removeY >= height ? height - 1 : removeY);
      final int ay = addY < 0 ? 0 : (addY >= height ? height - 1 : addY);
      sum += scratch[ay * width + x] - scratch[ry * width + x];
    }
  }
}

void _applyShadowMask({
  required Uint8List colorBuffer,
  required Uint32List? colorBuffer32,
  required Float32List depthBuffer,
  required Uint8List mask,
  required double strength,
}) {
  final double s = strength.clamp(0.0, 1.0).toDouble();
  if (s <= 0) {
    return;
  }
  final int pixelCount = mask.length;

  if (colorBuffer32 != null) {
    for (int i = 0; i < pixelCount; i++) {
      final int a = mask[i];
      if (a == 0 || depthBuffer[i] <= 0) {
        continue;
      }
      final double factor = 1.0 - s * (a / 255.0);
      final int color = colorBuffer32[i];
      final int r = color & 0xFF;
      final int g = (color >> 8) & 0xFF;
      final int b = (color >> 16) & 0xFF;
      final int alpha = (color >> 24) & 0xFF;
      final int r2 = (r * factor).round().clamp(0, 255);
      final int g2 = (g * factor).round().clamp(0, 255);
      final int b2 = (b * factor).round().clamp(0, 255);
      colorBuffer32[i] = r2 | (g2 << 8) | (b2 << 16) | (alpha << 24);
    }
    return;
  }

  for (int i = 0; i < pixelCount; i++) {
    final int a = mask[i];
    if (a == 0 || depthBuffer[i] <= 0) {
      continue;
    }
    final double factor = 1.0 - s * (a / 255.0);
    final int byteIndex = i * 4;
    colorBuffer[byteIndex] =
        (colorBuffer[byteIndex] * factor).round().clamp(0, 255);
    colorBuffer[byteIndex + 1] =
        (colorBuffer[byteIndex + 1] * factor).round().clamp(0, 255);
    colorBuffer[byteIndex + 2] =
        (colorBuffer[byteIndex + 2] * factor).round().clamp(0, 255);
  }
}

void _applyGroundDistanceFade({
  required Uint8List colorBuffer,
  required Uint32List? colorBuffer32,
  required Float32List depthBuffer,
  required int width,
  required int height,
  required double cameraDistance,
  required double groundHalfSize,
}) {
  if (width <= 0 || height <= 0) {
    return;
  }
  final int pixelCount = width * height;
  if (depthBuffer.length < pixelCount || colorBuffer.length < pixelCount * 4) {
    return;
  }
  if (!cameraDistance.isFinite || !groundHalfSize.isFinite) {
    return;
  }
  if (cameraDistance <= 0 || groundHalfSize <= 0) {
    return;
  }

  final double start = cameraDistance + groundHalfSize * 0.85;
  final double end = cameraDistance + groundHalfSize * 1.45;
  if (!start.isFinite || !end.isFinite || end <= start) {
    return;
  }

  final double invStart = 1.0 / start;
  final double invEnd = 1.0 / end;
  if (!invStart.isFinite || !invEnd.isFinite || invStart <= invEnd) {
    return;
  }
  final double invRange = 1.0 / (invStart - invEnd);

  double smoothstep01(double x) {
    final double t = x.clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  int dither8(int i) {
    final int n = i * 1103515245 + 12345;
    return (n >> 16) & 0xFF;
  }

  if (colorBuffer32 != null && colorBuffer32.length >= pixelCount) {
    for (int i = 0; i < pixelCount; i++) {
      final double invZ = depthBuffer[i];
      if (invZ <= 0) {
        continue;
      }

      final double fadeT = smoothstep01((invStart - invZ) * invRange);
      if (fadeT <= 0) {
        continue;
      }
      final double fadeAlphaFloat = 255.0 * (1.0 - fadeT);
      int fadeAlpha = fadeAlphaFloat.floor();
      int frac = ((fadeAlphaFloat - fadeAlpha) * 256.0).floor();
      if (frac < 0) {
        frac = 0;
      } else if (frac > 255) {
        frac = 255;
      }
      if (frac > dither8(i)) {
        fadeAlpha += 1;
      }
      if (fadeAlpha < 0) {
        fadeAlpha = 0;
      } else if (fadeAlpha > 255) {
        fadeAlpha = 255;
      }
      if (fadeAlpha >= 255) {
        continue;
      }

      final int color = colorBuffer32[i];
      final int a = (color >> 24) & 0xFF;
      if (a == 0 || a <= fadeAlpha) {
        continue;
      }
      if (fadeAlpha <= 0) {
        colorBuffer32[i] = 0;
        continue;
      }

      final int halfA = a >> 1;
      final int r = color & 0xFF;
      final int g = (color >> 8) & 0xFF;
      final int b = (color >> 16) & 0xFF;
      final int r2 = ((r * fadeAlpha) + halfA) ~/ a;
      final int g2 = ((g * fadeAlpha) + halfA) ~/ a;
      final int b2 = ((b * fadeAlpha) + halfA) ~/ a;
      colorBuffer32[i] = r2 | (g2 << 8) | (b2 << 16) | (fadeAlpha << 24);
    }
    return;
  }

  for (int i = 0; i < pixelCount; i++) {
    final double invZ = depthBuffer[i];
    if (invZ <= 0) {
      continue;
    }

    final double fadeT = smoothstep01((invStart - invZ) * invRange);
    if (fadeT <= 0) {
      continue;
    }
    final double fadeAlphaFloat = 255.0 * (1.0 - fadeT);
    int fadeAlpha = fadeAlphaFloat.floor();
    int frac = ((fadeAlphaFloat - fadeAlpha) * 256.0).floor();
    if (frac < 0) {
      frac = 0;
    } else if (frac > 255) {
      frac = 255;
    }
    if (frac > dither8(i)) {
      fadeAlpha += 1;
    }
    if (fadeAlpha < 0) {
      fadeAlpha = 0;
    } else if (fadeAlpha > 255) {
      fadeAlpha = 255;
    }
    if (fadeAlpha >= 255) {
      continue;
    }

    final int byteIndex = i * 4;
    final int a = colorBuffer[byteIndex + 3];
    if (a == 0 || a <= fadeAlpha) {
      continue;
    }
    if (fadeAlpha <= 0) {
      colorBuffer[byteIndex] = 0;
      colorBuffer[byteIndex + 1] = 0;
      colorBuffer[byteIndex + 2] = 0;
      colorBuffer[byteIndex + 3] = 0;
      continue;
    }

    final int halfA = a >> 1;
    final int r = colorBuffer[byteIndex];
    final int g = colorBuffer[byteIndex + 1];
    final int b = colorBuffer[byteIndex + 2];
    colorBuffer[byteIndex] = ((r * fadeAlpha) + halfA) ~/ a;
    colorBuffer[byteIndex + 1] = ((g * fadeAlpha) + halfA) ~/ a;
    colorBuffer[byteIndex + 2] = ((b * fadeAlpha) + halfA) ~/ a;
    colorBuffer[byteIndex + 3] = fadeAlpha;
  }
}
