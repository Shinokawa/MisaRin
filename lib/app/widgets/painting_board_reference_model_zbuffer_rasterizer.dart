part of 'painting_board.dart';
	  void _rasterizeMesh({
	    required BedrockMesh mesh,
	    required Uint8List colorBuffer,
	    required Uint32List? colorBuffer32,
	    required Float32List depthBuffer,
	    required int width,
	    required int height,
	    required Vector3 modelExtent,
	    required double yaw,
	    required double pitch,
	    required double zoom,
	    double translateY = 0.0,
	    required Vector3 lightDirection,
	    required double ambient,
	    required double diffuse,
	    Color sunColor = const Color(0xFFFFFFFF),
	    Color skyColor = const Color(0xFFBFD9FF),
	    Color groundBounceColor = const Color(0xFFFFFFFF),
	    double specularStrength = 0.25,
	    double roughness = 0.55,
	    double exposure = 1.0,
	    required bool toneMap,
	    required bool lightFollowsCamera,
	    bool unlit = false,
	    required Uint8List? textureRgba,
	    required int textureWidth,
	    required int textureHeight,
	    required int modelTextureWidth,
	    required int modelTextureHeight,
	    Color untexturedBaseColor = const Color(0xFFFFFFFF),
      _BedrockSelfShadowMap? selfShadowMap,
      double selfShadowStrength = 1.0,
      double selfShadowBias = 0.02,
      double selfShadowSlopeBias = 0.03,
      int selfShadowPcfRadius = 1,
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

    final bool hasTexture =
        textureRgba != null &&
        textureWidth > 0 &&
        textureHeight > 0 &&
        modelTextureWidth > 0 &&
        modelTextureHeight > 0;
    final double uScale =
        hasTexture ? textureWidth / modelTextureWidth : 1.0;
    final double vScale =
        hasTexture ? textureHeight / modelTextureHeight : 1.0;

    final Vector3 lightDir = lightDirection.clone();
    if (lightDir.length2 <= 0) {
      lightDir.setFrom(_BedrockModelZBufferViewState._defaultLightDirection);
    } else {
      lightDir.normalize();
    }
    final double ambientClamped = ambient.clamp(0.0, 1.0).toDouble();
    final double diffuseClamped = diffuse.clamp(0.0, 1.0).toDouble();
    final bool meshUnlit = unlit;
    final double exposureClamped =
        exposure.isFinite ? exposure.clamp(0.0, 4.0).toDouble() : 1.0;
	    final double specularStrengthClamped =
	        specularStrength.clamp(0.0, 1.0).toDouble();
	    final double roughnessClamped = roughness.clamp(0.0, 1.0).toDouble();

    final _BedrockSelfShadowMap? shadowMap = selfShadowMap;
    final double selfShadowStrengthClamped =
        selfShadowStrength.clamp(0.0, 1.0).toDouble();
    final double selfShadowBiasClamped = selfShadowBias.isFinite
        ? selfShadowBias.clamp(0.0, 1.0).toDouble()
        : 0.02;
    final double selfShadowSlopeBiasClamped = selfShadowSlopeBias.isFinite
        ? selfShadowSlopeBias.clamp(0.0, 1.0).toDouble()
        : 0.03;
    final int selfShadowRadiusClamped = selfShadowPcfRadius
        .clamp(0, 4)
        .toInt();
    final bool enableSelfShadow =
        shadowMap != null && selfShadowStrengthClamped > 0.0 && diffuseClamped > 0.0;

    final Float32List? shadowDepth = enableSelfShadow ? shadowMap!.depth : null;
    final int shadowSize = enableSelfShadow ? shadowMap!.size : 0;
    final double shadowUMin = enableSelfShadow ? shadowMap!.uMin : 0.0;
    final double shadowVMin = enableSelfShadow ? shadowMap!.vMin : 0.0;
    final double shadowUScale = enableSelfShadow ? shadowMap!.uScale : 0.0;
    final double shadowVScale = enableSelfShadow ? shadowMap!.vScale : 0.0;
    final double shadowDirX = enableSelfShadow ? shadowMap!.lightDir.x : 0.0;
    final double shadowDirY = enableSelfShadow ? shadowMap!.lightDir.y : 0.0;
    final double shadowDirZ = enableSelfShadow ? shadowMap!.lightDir.z : 0.0;
    final double shadowRightX = enableSelfShadow ? shadowMap!.right.x : 0.0;
    final double shadowRightY = enableSelfShadow ? shadowMap!.right.y : 0.0;
    final double shadowRightZ = enableSelfShadow ? shadowMap!.right.z : 0.0;
    final double shadowUpX = enableSelfShadow ? shadowMap!.up.x : 0.0;
    final double shadowUpY = enableSelfShadow ? shadowMap!.up.y : 0.0;
    final double shadowUpZ = enableSelfShadow ? shadowMap!.up.z : 0.0;

    final Float32List srgbToLinear = _BedrockModelZBufferViewState._srgbToLinearTable;
    final Uint8List linearToSrgb = _BedrockModelZBufferViewState._linearToSrgbTable;
    final int linearMaxIndex = _BedrockModelZBufferViewState._kLinearToSrgbTableSize - 1;

    int channelTo8(double v) => (v * 255).round().clamp(0, 255);

    final double sunRLin = srgbToLinear[channelTo8(sunColor.r)];
    final double sunGLin = srgbToLinear[channelTo8(sunColor.g)];
    final double sunBLin = srgbToLinear[channelTo8(sunColor.b)];

    final double skyRLin = srgbToLinear[channelTo8(skyColor.r)];
    final double skyGLin = srgbToLinear[channelTo8(skyColor.g)];
    final double skyBLin = srgbToLinear[channelTo8(skyColor.b)];

    final double groundRLin = srgbToLinear[channelTo8(groundBounceColor.r)];
    final double groundGLin = srgbToLinear[channelTo8(groundBounceColor.g)];
    final double groundBLin = srgbToLinear[channelTo8(groundBounceColor.b)];

    final int untexturedR8 = channelTo8(untexturedBaseColor.r);
    final int untexturedG8 = channelTo8(untexturedBaseColor.g);
    final int untexturedB8 = channelTo8(untexturedBaseColor.b);
    final int untexturedA8 = channelTo8(untexturedBaseColor.a);
    final double untexturedRLin = srgbToLinear[untexturedR8];
    final double untexturedGLin = srgbToLinear[untexturedG8];
    final double untexturedBLin = srgbToLinear[untexturedB8];

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

    final double centerX = width * 0.5;
    final double centerY = height * 0.5;
	    final double baseScale = (math.min(width.toDouble(), height.toDouble()) / extent) * 0.9;
	    final double scale = baseScale * zoom;
	    final double cameraDistance = extent * 2.4;
	    final double nearPlane = math.max(1e-3, cameraDistance * 0.01);
	    double triAmbR = 1.0;
	    double triAmbG = 1.0;
	    double triAmbB = 1.0;
      double triSunR = 0.0;
      double triSunG = 0.0;
      double triSunB = 0.0;
	    double triSpecR = 0.0;
	    double triSpecG = 0.0;
	    double triSpecB = 0.0;
      double triShadowBias = 0.0;
      bool triUseSelfShadow = false;

	    ({double x, double y, double z, double u, double v}) intersectNearPlane({
	      required double ax,
	      required double ay,
	      required double az,
      required double au,
      required double av,
      required double bx,
      required double by,
      required double bz,
      required double bu,
      required double bv,
    }) {
      final double denom = bz - az;
      if (denom.abs() <= 1e-9) {
        return (x: ax, y: ay, z: nearPlane, u: au, v: av);
      }
      final double t = ((nearPlane - az) / denom).clamp(0.0, 1.0);
      return (
        x: ax + (bx - ax) * t,
        y: ay + (by - ay) * t,
        z: nearPlane,
        u: au + (bu - au) * t,
	        v: av + (bv - av) * t,
	      );
	    }

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

		    void rasterizeTriangle({
		      required double x0w,
		      required double y0w,
		      required double z0,
	      required double u0,
	      required double v0,
        double su0 = 0.0,
        double sv0 = 0.0,
        double sd0 = 0.0,
	      required double x1w,
	      required double y1w,
	      required double z1,
	      required double u1,
	      required double v1,
        double su1 = 0.0,
        double sv1 = 0.0,
        double sd1 = 0.0,
	      required double x2w,
	      required double y2w,
	      required double z2,
	      required double u2,
	      required double v2,
        double su2 = 0.0,
        double sv2 = 0.0,
        double sd2 = 0.0,
	    }) {
      if (z0 <= 0 || z1 <= 0 || z2 <= 0) {
        return;
      }

      final double invZ0 = 1.0 / z0;
      final double invZ1 = 1.0 / z1;
      final double invZ2 = 1.0 / z2;

      final double s0 = cameraDistance * invZ0;
      final double s1 = cameraDistance * invZ1;
      final double s2 = cameraDistance * invZ2;

      final double x0 = centerX + x0w * s0 * scale;
      final double y0 = centerY + (-y0w) * s0 * scale;
      final double x1 = centerX + x1w * s1 * scale;
      final double y1 = centerY + (-y1w) * s1 * scale;
      final double x2 = centerX + x2w * s2 * scale;
      final double y2 = centerY + (-y2w) * s2 * scale;

      final double area = edge(x0, y0, x1, y1, x2, y2);
      if (area == 0) {
        return;
      }
      final double invArea = 1.0 / area;

      final double minX = math.min(x0, math.min(x1, x2));
      final double maxX = math.max(x0, math.max(x1, x2));
      final double minY = math.min(y0, math.min(y1, y2));
      final double maxY = math.max(y0, math.max(y1, y2));
      int xStart = clampInt(minX.floor(), 0, width - 1);
      int xEnd = clampInt(maxX.ceil(), 0, width - 1);
      int yStart = clampInt(minY.floor(), 0, height - 1);
      int yEnd = clampInt(maxY.ceil(), 0, height - 1);

	      final double u0OverZ = u0 * invZ0;
	      final double v0OverZ = v0 * invZ0;
	      final double u1OverZ = u1 * invZ1;
	      final double v1OverZ = v1 * invZ1;
	      final double u2OverZ = u2 * invZ2;
	      final double v2OverZ = v2 * invZ2;

        final bool useSelfShadow = enableSelfShadow && triUseSelfShadow;
        final double su0OverZ = useSelfShadow ? su0 * invZ0 : 0.0;
        final double sv0OverZ = useSelfShadow ? sv0 * invZ0 : 0.0;
        final double sd0OverZ = useSelfShadow ? sd0 * invZ0 : 0.0;
        final double su1OverZ = useSelfShadow ? su1 * invZ1 : 0.0;
        final double sv1OverZ = useSelfShadow ? sv1 * invZ1 : 0.0;
        final double sd1OverZ = useSelfShadow ? sd1 * invZ1 : 0.0;
        final double su2OverZ = useSelfShadow ? su2 * invZ2 : 0.0;
        final double sv2OverZ = useSelfShadow ? sv2 * invZ2 : 0.0;
        final double sd2OverZ = useSelfShadow ? sd2 * invZ2 : 0.0;

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

          final double a = w0 * invArea;
          final double b = w1 * invArea;
          final double c = w2 * invArea;

          final double invZ = a * invZ0 + b * invZ1 + c * invZ2;
          if (invZ <= 0) {
            continue;
          }

          final int index = row + x;
          if (invZ <= depthBuffer[index]) {
            continue;
          }

          int rOut;
          int gOut;
          int bOut;
          int aOut;

	          if (hasTexture) {
	            final double u = (a * u0OverZ + b * u1OverZ + c * u2OverZ) / invZ;
	            final double v = (a * v0OverZ + b * v1OverZ + c * v2OverZ) / invZ;
            final int tu = clampInt(u.floor(), 0, textureWidth - 1);
            final int tv = clampInt(v.floor(), 0, textureHeight - 1);
            final int texIndex = (tv * textureWidth + tu) * 4;
            final int tr = textureRgba![texIndex];
            final int tg = textureRgba[texIndex + 1];
            final int tb = textureRgba[texIndex + 2];
            final int ta = textureRgba[texIndex + 3];
            if (ta == 0) {
              continue;
            }
	            if (meshUnlit) {
	              rOut = tr;
	              gOut = tg;
	              bOut = tb;
	            } else {
                double shadow = 1.0;
                if (useSelfShadow && shadowDepth != null && shadowSize > 0) {
                  final double suLin =
                      (a * su0OverZ + b * su1OverZ + c * su2OverZ) / invZ;
                  final double svLin =
                      (a * sv0OverZ + b * sv1OverZ + c * sv2OverZ) / invZ;
                  final double sdLin =
                      (a * sd0OverZ + b * sd1OverZ + c * sd2OverZ) / invZ;
                  shadow = _computeSelfShadowFactor(
                    shadowDepth: shadowDepth,
                    shadowSize: shadowSize,
                    suLin: suLin,
                    svLin: svLin,
                    sdLin: sdLin,
                    shadowUMin: shadowUMin,
                    shadowVMin: shadowVMin,
                    shadowUScale: shadowUScale,
                    shadowVScale: shadowVScale,
                    radius: selfShadowRadiusClamped,
                    bias: triShadowBias,
                    strength: selfShadowStrengthClamped,
                  );
	                }

                final double lightR = triAmbR + triSunR * shadow;
                final double lightG = triAmbG + triSunG * shadow;
                final double lightB = triAmbB + triSunB * shadow;
                final double specR = triSpecR * shadow;
                final double specG = triSpecG * shadow;
                final double specB = triSpecB * shadow;

	              final double rLin =
	                  (srgbToLinear[tr] * lightR + specR) *
	                  exposureClamped;
	              final double gLin =
	                  (srgbToLinear[tg] * lightG + specG) *
	                  exposureClamped;
	              final double bLin =
	                  (srgbToLinear[tb] * lightB + specB) *
	                  exposureClamped;
	              final double rMapped = toneMap ? (rLin / (1.0 + rLin)) : rLin;
	              final double gMapped = toneMap ? (gLin / (1.0 + gLin)) : gLin;
	              final double bMapped = toneMap ? (bLin / (1.0 + bLin)) : bLin;
              rOut =
                  linearToSrgb[(rMapped.clamp(0.0, 1.0).toDouble() * linearMaxIndex).round()];
              gOut =
                  linearToSrgb[(gMapped.clamp(0.0, 1.0).toDouble() * linearMaxIndex).round()];
              bOut =
                  linearToSrgb[(bMapped.clamp(0.0, 1.0).toDouble() * linearMaxIndex).round()];
            }
            aOut = ta;
          } else {
	            if (meshUnlit) {
	              rOut = untexturedR8;
	              gOut = untexturedG8;
	              bOut = untexturedB8;
	              aOut = untexturedA8;
	            } else {
                double shadow = 1.0;
                if (useSelfShadow && shadowDepth != null && shadowSize > 0) {
                  final double suLin =
                      (a * su0OverZ + b * su1OverZ + c * su2OverZ) / invZ;
                  final double svLin =
                      (a * sv0OverZ + b * sv1OverZ + c * sv2OverZ) / invZ;
                  final double sdLin =
                      (a * sd0OverZ + b * sd1OverZ + c * sd2OverZ) / invZ;
                  shadow = _computeSelfShadowFactor(
                    shadowDepth: shadowDepth,
                    shadowSize: shadowSize,
                    suLin: suLin,
                    svLin: svLin,
                    sdLin: sdLin,
                    shadowUMin: shadowUMin,
                    shadowVMin: shadowVMin,
                    shadowUScale: shadowUScale,
                    shadowVScale: shadowVScale,
                    radius: selfShadowRadiusClamped,
                    bias: triShadowBias,
                    strength: selfShadowStrengthClamped,
                  );
                }

                final double lightR = triAmbR + triSunR * shadow;
                final double lightG = triAmbG + triSunG * shadow;
                final double lightB = triAmbB + triSunB * shadow;
                final double specR = triSpecR * shadow;
                final double specG = triSpecG * shadow;
                final double specB = triSpecB * shadow;

	              final double rLin =
	                  (untexturedRLin * lightR + specR) * exposureClamped;
	              final double gLin =
	                  (untexturedGLin * lightG + specG) * exposureClamped;
	              final double bLin =
	                  (untexturedBLin * lightB + specB) * exposureClamped;
	              final double rMapped = toneMap ? (rLin / (1.0 + rLin)) : rLin;
	              final double gMapped = toneMap ? (gLin / (1.0 + gLin)) : gLin;
	              final double bMapped = toneMap ? (bLin / (1.0 + bLin)) : bLin;
              rOut =
                  linearToSrgb[(rMapped.clamp(0.0, 1.0).toDouble() * linearMaxIndex).round()];
              gOut =
                  linearToSrgb[(gMapped.clamp(0.0, 1.0).toDouble() * linearMaxIndex).round()];
              bOut =
                  linearToSrgb[(bMapped.clamp(0.0, 1.0).toDouble() * linearMaxIndex).round()];
              aOut = untexturedA8;
            }
          }

          depthBuffer[index] = invZ.toDouble();
          if (colorBuffer32 != null) {
            colorBuffer32[index] =
                rOut | (gOut << 8) | (bOut << 16) | (aOut << 24);
          } else {
            final int byteIndex = index * 4;
            colorBuffer[byteIndex] = rOut;
            colorBuffer[byteIndex + 1] = gOut;
            colorBuffer[byteIndex + 2] = bOut;
            colorBuffer[byteIndex + 3] = aOut;
          }
        }
	      }
	    }

	    for (final BedrockMeshTriangle tri in mesh.triangles) {
	      final Vector3 normal = tri.normal;
	      final double nx = transformX(normal.x, normal.y, normal.z);
	      final double ny = transformY(normal.x, normal.y, normal.z);
      final double nz = transformZ(normal.x, normal.y, normal.z);
      if (nz >= 0) {
        continue;
      }

      final Vector3 p0 = tri.p0;
      final Vector3 p1 = tri.p1;
      final Vector3 p2 = tri.p2;

      final double y0 = p0.y + translateY;
      final double y1 = p1.y + translateY;
      final double y2 = p2.y + translateY;

      final double x0w = transformX(p0.x, y0, p0.z);
      final double y0w = transformY(p0.x, y0, p0.z);
      final double z0w = transformZ(p0.x, y0, p0.z);
      final double x1w = transformX(p1.x, y1, p1.z);
      final double y1w = transformY(p1.x, y1, p1.z);
      final double z1w = transformZ(p1.x, y1, p1.z);
      final double x2w = transformX(p2.x, y2, p2.z);
      final double y2w = transformY(p2.x, y2, p2.z);
      final double z2w = transformZ(p2.x, y2, p2.z);

	      if (!meshUnlit) {
	        final double nLen = math.sqrt(nx * nx + ny * ny + nz * nz);
	        if (nLen <= 0) {
	          triAmbR = ambientClamped;
	          triAmbG = ambientClamped;
	          triAmbB = ambientClamped;
            triSunR = 0.0;
            triSunG = 0.0;
            triSunB = 0.0;
	          triSpecR = 0.0;
	          triSpecG = 0.0;
	          triSpecB = 0.0;
            triUseSelfShadow = false;
            triShadowBias = 0.0;
	        } else {
	          final double nvx = nx / nLen;
	          final double nvy = ny / nLen;
	          final double nvz = nz / nLen;

          double lvx = lightDir.x;
          double lvy = lightDir.y;
          double lvz = lightDir.z;
          if (!lightFollowsCamera) {
            lvx = transformX(lightDir.x, lightDir.y, lightDir.z);
            lvy = transformY(lightDir.x, lightDir.y, lightDir.z);
            lvz = transformZ(lightDir.x, lightDir.y, lightDir.z);
          }

          final double lLen = math.sqrt(lvx * lvx + lvy * lvy + lvz * lvz);
          if (lLen > 0) {
            lvx /= lLen;
            lvy /= lLen;
            lvz /= lLen;
          }

          final double ndotl = math.max(0.0, nvx * lvx + nvy * lvy + nvz * lvz);
          final double sunIntensity = diffuseClamped * ndotl;

          final double upDot = lightFollowsCamera ? nvy : normal.y;
          final double hemi =
              ((upDot * 0.5) + 0.5).clamp(0.0, 1.0).toDouble();
          final double invHemi = 1.0 - hemi;

          final double ambR =
              (groundRLin * invHemi + skyRLin * hemi) * ambientClamped;
          final double ambG =
              (groundGLin * invHemi + skyGLin * hemi) * ambientClamped;
          final double ambB =
              (groundBLin * invHemi + skyBLin * hemi) * ambientClamped;

	          triAmbR = ambR;
	          triAmbG = ambG;
	          triAmbB = ambB;
            triSunR = sunRLin * sunIntensity;
            triSunG = sunGLin * sunIntensity;
            triSunB = sunBLin * sunIntensity;

	          triSpecR = 0.0;
	          triSpecG = 0.0;
	          triSpecB = 0.0;
            triUseSelfShadow = enableSelfShadow && sunIntensity > 0.0;
            triShadowBias = triUseSelfShadow
                ? (selfShadowBiasClamped +
                    selfShadowSlopeBiasClamped * (1.0 - ndotl))
                : 0.0;

          if (specularStrengthClamped > 0.0 && sunIntensity > 0.0) {
            final double cx = (x0w + x1w + x2w) / 3.0;
            final double cy = (y0w + y1w + y2w) / 3.0;
            final double cz =
                (z0w + z1w + z2w) / 3.0 + cameraDistance;
            double vx = -cx;
            double vy = -cy;
            double vz = -cz;
            final double vLen = math.sqrt(vx * vx + vy * vy + vz * vz);
            if (vLen > 0.0) {
              vx /= vLen;
              vy /= vLen;
              vz /= vLen;
            }

            double hx = lvx + vx;
            double hy = lvy + vy;
            double hz = lvz + vz;
            final double hLen = math.sqrt(hx * hx + hy * hy + hz * hz);
            if (hLen > 0.0) {
              hx /= hLen;
              hy /= hLen;
              hz /= hLen;
            }

            final double ndoth =
                math.max(0.0, nvx * hx + nvy * hy + nvz * hz);
            final double ndotv =
                math.max(0.0, nvx * vx + nvy * vy + nvz * vz);

            final double smooth = 1.0 - roughnessClamped;
            final double shininess = 8.0 + (smooth * smooth) * 120.0;
            final double specPower = math.pow(ndoth, shininess).toDouble();

            final double oneMinus = 1.0 - ndotv;
            final double oneMinus2 = oneMinus * oneMinus;
            final double oneMinus5 = oneMinus2 * oneMinus2 * oneMinus;
            final double fresnel = 0.04 + (1.0 - 0.04) * oneMinus5;

            final double specIntensity =
                specularStrengthClamped * specPower * fresnel * sunIntensity;
            triSpecR = sunRLin * specIntensity;
            triSpecG = sunGLin * specIntensity;
            triSpecB = sunBLin * specIntensity;
          }
        }
	      } else {
	        triAmbR = 1.0;
	        triAmbG = 1.0;
	        triAmbB = 1.0;
          triSunR = 0.0;
          triSunG = 0.0;
          triSunB = 0.0;
	        triSpecR = 0.0;
	        triSpecG = 0.0;
	        triSpecB = 0.0;
          triUseSelfShadow = false;
          triShadowBias = 0.0;
	      }

      final Offset uv0 = tri.uv0;
      final Offset uv1 = tri.uv1;
      final Offset uv2 = tri.uv2;
      final double u0 = uv0.dx * uScale;
      final double v0 = uv0.dy * vScale;
      final double u1 = uv1.dx * uScale;
      final double v1 = uv1.dy * vScale;
      final double u2 = uv2.dx * uScale;
      final double v2 = uv2.dy * vScale;

	      final double z0 = z0w + cameraDistance;
	      final double z1 = z1w + cameraDistance;
	      final double z2 = z2w + cameraDistance;

        double su0 = 0.0;
        double sv0 = 0.0;
        double sd0 = 0.0;
        double su1 = 0.0;
        double sv1 = 0.0;
        double sd1 = 0.0;
        double su2 = 0.0;
        double sv2 = 0.0;
        double sd2 = 0.0;
        if (enableSelfShadow) {
          su0 = x0w * shadowRightX + y0w * shadowRightY + z0w * shadowRightZ;
          sv0 = x0w * shadowUpX + y0w * shadowUpY + z0w * shadowUpZ;
          sd0 = x0w * shadowDirX + y0w * shadowDirY + z0w * shadowDirZ;

          su1 = x1w * shadowRightX + y1w * shadowRightY + z1w * shadowRightZ;
          sv1 = x1w * shadowUpX + y1w * shadowUpY + z1w * shadowUpZ;
          sd1 = x1w * shadowDirX + y1w * shadowDirY + z1w * shadowDirZ;

          su2 = x2w * shadowRightX + y2w * shadowRightY + z2w * shadowRightZ;
          sv2 = x2w * shadowUpX + y2w * shadowUpY + z2w * shadowUpZ;
          sd2 = x2w * shadowDirX + y2w * shadowDirY + z2w * shadowDirZ;
        }

      final bool in0 = z0 > nearPlane;
      final bool in1 = z1 > nearPlane;
      final bool in2 = z2 > nearPlane;
      final int insideCount = (in0 ? 1 : 0) + (in1 ? 1 : 0) + (in2 ? 1 : 0);
      if (insideCount == 0) {
        continue;
      }

	      if (insideCount == 3) {
	        rasterizeTriangle(
	          x0w: x0w,
	          y0w: y0w,
	          z0: z0,
	          u0: u0,
	          v0: v0,
            su0: su0,
            sv0: sv0,
            sd0: sd0,
	          x1w: x1w,
	          y1w: y1w,
	          z1: z1,
	          u1: u1,
	          v1: v1,
            su1: su1,
            sv1: sv1,
            sd1: sd1,
	          x2w: x2w,
	          y2w: y2w,
	          z2: z2,
	          u2: u2,
	          v2: v2,
            su2: su2,
            sv2: sv2,
            sd2: sd2,
	        );
	        continue;
	      }

      if (insideCount == 1) {
        if (in0) {
          final p01 = intersectNearPlane(
            ax: x0w,
            ay: y0w,
            az: z0,
            au: u0,
            av: v0,
            bx: x1w,
            by: y1w,
            bz: z1,
            bu: u1,
            bv: v1,
          );
          final p02 = intersectNearPlane(
            ax: x0w,
            ay: y0w,
            az: z0,
            au: u0,
            av: v0,
            bx: x2w,
            by: y2w,
            bz: z2,
            bu: u2,
            bv: v2,
          );
          rasterizeTriangle(
            x0w: x0w,
            y0w: y0w,
            z0: z0,
            u0: u0,
            v0: v0,
            x1w: p01.x,
            y1w: p01.y,
            z1: p01.z,
            u1: p01.u,
            v1: p01.v,
            x2w: p02.x,
            y2w: p02.y,
            z2: p02.z,
            u2: p02.u,
            v2: p02.v,
          );
        } else if (in1) {
          final p10 = intersectNearPlane(
            ax: x1w,
            ay: y1w,
            az: z1,
            au: u1,
            av: v1,
            bx: x0w,
            by: y0w,
            bz: z0,
            bu: u0,
            bv: v0,
          );
          final p12 = intersectNearPlane(
            ax: x1w,
            ay: y1w,
            az: z1,
            au: u1,
            av: v1,
            bx: x2w,
            by: y2w,
            bz: z2,
            bu: u2,
            bv: v2,
          );
          rasterizeTriangle(
            x0w: x1w,
            y0w: y1w,
            z0: z1,
            u0: u1,
            v0: v1,
            x1w: p12.x,
            y1w: p12.y,
            z1: p12.z,
            u1: p12.u,
            v1: p12.v,
            x2w: p10.x,
            y2w: p10.y,
            z2: p10.z,
            u2: p10.u,
            v2: p10.v,
          );
        } else {
          final p20 = intersectNearPlane(
            ax: x2w,
            ay: y2w,
            az: z2,
            au: u2,
            av: v2,
            bx: x0w,
            by: y0w,
            bz: z0,
            bu: u0,
            bv: v0,
          );
          final p21 = intersectNearPlane(
            ax: x2w,
            ay: y2w,
            az: z2,
            au: u2,
            av: v2,
            bx: x1w,
            by: y1w,
            bz: z1,
            bu: u1,
            bv: v1,
          );
          rasterizeTriangle(
            x0w: x2w,
            y0w: y2w,
            z0: z2,
            u0: u2,
            v0: v2,
            x1w: p20.x,
            y1w: p20.y,
            z1: p20.z,
            u1: p20.u,
            v1: p20.v,
            x2w: p21.x,
            y2w: p21.y,
            z2: p21.z,
            u2: p21.u,
            v2: p21.v,
          );
        }
        continue;
      }

      // insideCount == 2
      if (!in0) {
        final p10 = intersectNearPlane(
          ax: x1w,
          ay: y1w,
          az: z1,
          au: u1,
          av: v1,
          bx: x0w,
          by: y0w,
          bz: z0,
          bu: u0,
          bv: v0,
        );
        final p20 = intersectNearPlane(
          ax: x2w,
          ay: y2w,
          az: z2,
          au: u2,
          av: v2,
          bx: x0w,
          by: y0w,
          bz: z0,
          bu: u0,
          bv: v0,
        );
        rasterizeTriangle(
          x0w: x1w,
          y0w: y1w,
          z0: z1,
          u0: u1,
          v0: v1,
          x1w: x2w,
          y1w: y2w,
          z1: z2,
          u1: u2,
          v1: v2,
          x2w: p20.x,
          y2w: p20.y,
          z2: p20.z,
          u2: p20.u,
          v2: p20.v,
        );
        rasterizeTriangle(
          x0w: x1w,
          y0w: y1w,
          z0: z1,
          u0: u1,
          v0: v1,
          x1w: p20.x,
          y1w: p20.y,
          z1: p20.z,
          u1: p20.u,
          v1: p20.v,
          x2w: p10.x,
          y2w: p10.y,
          z2: p10.z,
          u2: p10.u,
          v2: p10.v,
        );
      } else if (!in1) {
        final p01 = intersectNearPlane(
          ax: x0w,
          ay: y0w,
          az: z0,
          au: u0,
          av: v0,
          bx: x1w,
          by: y1w,
          bz: z1,
          bu: u1,
          bv: v1,
        );
        final p21 = intersectNearPlane(
          ax: x2w,
          ay: y2w,
          az: z2,
          au: u2,
          av: v2,
          bx: x1w,
          by: y1w,
          bz: z1,
          bu: u1,
          bv: v1,
        );
        rasterizeTriangle(
          x0w: x2w,
          y0w: y2w,
          z0: z2,
          u0: u2,
          v0: v2,
          x1w: x0w,
          y1w: y0w,
          z1: z0,
          u1: u0,
          v1: v0,
          x2w: p01.x,
          y2w: p01.y,
          z2: p01.z,
          u2: p01.u,
          v2: p01.v,
        );
        rasterizeTriangle(
          x0w: x2w,
          y0w: y2w,
          z0: z2,
          u0: u2,
          v0: v2,
          x1w: p01.x,
          y1w: p01.y,
          z1: p01.z,
          u1: p01.u,
          v1: p01.v,
          x2w: p21.x,
          y2w: p21.y,
          z2: p21.z,
          u2: p21.u,
          v2: p21.v,
        );
      } else {
        final p02 = intersectNearPlane(
          ax: x0w,
          ay: y0w,
          az: z0,
          au: u0,
          av: v0,
          bx: x2w,
          by: y2w,
          bz: z2,
          bu: u2,
          bv: v2,
        );
        final p12 = intersectNearPlane(
          ax: x1w,
          ay: y1w,
          az: z1,
          au: u1,
          av: v1,
          bx: x2w,
          by: y2w,
          bz: z2,
          bu: u2,
          bv: v2,
        );
        rasterizeTriangle(
          x0w: x0w,
          y0w: y0w,
          z0: z0,
          u0: u0,
          v0: v0,
          x1w: x1w,
          y1w: y1w,
          z1: z1,
          u1: u1,
          v1: v1,
          x2w: p12.x,
          y2w: p12.y,
          z2: p12.z,
          u2: p12.u,
          v2: p12.v,
        );
        rasterizeTriangle(
          x0w: x0w,
          y0w: y0w,
          z0: z0,
          u0: u0,
          v0: v0,
          x1w: p12.x,
          y1w: p12.y,
          z1: p12.z,
          u1: p12.u,
          v1: p12.v,
          x2w: p02.x,
          y2w: p02.y,
          z2: p02.z,
          u2: p02.u,
          v2: p02.v,
        );
      }
    }
  }
