part of 'painting_board.dart';

class _BedrockSelfShadowMap {
  _BedrockSelfShadowMap({
    required this.depth,
    required this.size,
    required this.lightDir,
    required this.right,
    required this.up,
    required this.uMin,
    required this.vMin,
    required this.uScale,
    required this.vScale,
  });

  final Float32List depth;
  final int size;
  final Vector3 lightDir;
  final Vector3 right;
  final Vector3 up;
  final double uMin;
  final double vMin;
  final double uScale;
  final double vScale;
}

_BedrockSelfShadowMap? _buildSelfShadowMap({
  required BedrockMesh mesh,
  required Vector3 modelExtent,
  required double yaw,
  required double pitch,
  required double translateY,
  required Vector3 lightDirection,
  required bool lightFollowsCamera,
  required int mapSize,
  required Float32List Function(int size) ensureDepthBuffer,
  Float32List? depthBuffer,
  Uint8List? textureRgba,
  int textureWidth = 0,
  int textureHeight = 0,
  int modelTextureWidth = 0,
  int modelTextureHeight = 0,
  int alphaCutoff = 1,
}) {
  if (mesh.triangles.isEmpty) {
    return null;
  }
  final int size = mapSize.clamp(64, 2048).toInt();

  final double extent = math.max(
    modelExtent.x.abs(),
    math.max(modelExtent.y.abs(), modelExtent.z.abs()),
  );
  if (extent <= 0) {
    return null;
  }

  final Matrix4 rotation = Matrix4.identity()
    ..rotateY(yaw)
    ..rotateX(pitch);
  final Float64List r = rotation.storage;

  double transformX(double x, double y, double z) => r[0] * x + r[4] * y + r[8] * z;
  double transformY(double x, double y, double z) => r[1] * x + r[5] * y + r[9] * z;
  double transformZ(double x, double y, double z) => r[2] * x + r[6] * y + r[10] * z;

  final Vector3 lightDir = lightDirection.clone();
  if (lightDir.length2 <= 0) {
    return null;
  }
  lightDir.normalize();

  final Vector3 lightDirView = lightFollowsCamera
      ? lightDir
      : Vector3(
          transformX(lightDir.x, lightDir.y, lightDir.z),
          transformY(lightDir.x, lightDir.y, lightDir.z),
          transformZ(lightDir.x, lightDir.y, lightDir.z),
        )..normalize();

  Vector3 upRef = Vector3(0, 1, 0);
  if (lightDirView.dot(upRef).abs() > 0.92) {
    upRef = Vector3(1, 0, 0);
  }
  final Vector3 right = upRef.cross(lightDirView)..normalize();
  final Vector3 up = lightDirView.cross(right)..normalize();

  final double rx = right.x;
  final double ry = right.y;
  final double rz = right.z;
  final double ux = up.x;
  final double uy = up.y;
  final double uz = up.z;

  double uMin = double.infinity;
  double uMax = double.negativeInfinity;
  double vMin = double.infinity;
  double vMax = double.negativeInfinity;

  for (final BedrockMeshTriangle tri in mesh.triangles) {
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

    final double u0 = x0w * rx + y0w * ry + z0w * rz;
    final double v0 = x0w * ux + y0w * uy + z0w * uz;
    final double u1 = x1w * rx + y1w * ry + z1w * rz;
    final double v1 = x1w * ux + y1w * uy + z1w * uz;
    final double u2 = x2w * rx + y2w * ry + z2w * rz;
    final double v2 = x2w * ux + y2w * uy + z2w * uz;

    uMin = math.min(uMin, math.min(u0, math.min(u1, u2)));
    uMax = math.max(uMax, math.max(u0, math.max(u1, u2)));
    vMin = math.min(vMin, math.min(v0, math.min(v1, v2)));
    vMax = math.max(vMax, math.max(v0, math.max(v1, v2)));
  }

  final double uSpan = uMax - uMin;
  final double vSpan = vMax - vMin;
  if (!uSpan.isFinite || !vSpan.isFinite || uSpan <= 1e-9 || vSpan <= 1e-9) {
    return null;
  }

  final double padU = uSpan * 0.06 + 1e-3;
  final double padV = vSpan * 0.06 + 1e-3;
  uMin -= padU;
  uMax += padU;
  vMin -= padV;
  vMax += padV;

  final double invUSpan = 1.0 / (uMax - uMin);
  final double invVSpan = 1.0 / (vMax - vMin);
  final double uScale = (size - 1) * invUSpan;
  final double vScale = (size - 1) * invVSpan;

  final int requiredLength = size * size;
  final Float32List depth = depthBuffer != null && depthBuffer.length == requiredLength
      ? depthBuffer
      : ensureDepthBuffer(size);
  depth.fillRange(0, depth.length, -double.infinity);

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

  final double ldx = lightDirView.x;
  final double ldy = lightDirView.y;
  final double ldz = lightDirView.z;

  final int alphaCutoffClamped = alphaCutoff.clamp(1, 255);
  final bool alphaTest = textureRgba != null &&
      textureWidth > 0 &&
      textureHeight > 0 &&
      modelTextureWidth > 0 &&
      modelTextureHeight > 0;
  final double texUScale = alphaTest ? textureWidth / modelTextureWidth : 1.0;
  final double texVScale = alphaTest ? textureHeight / modelTextureHeight : 1.0;

  for (final BedrockMeshTriangle tri in mesh.triangles) {
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

    final double u0 = (x0w * rx + y0w * ry + z0w * rz - uMin) * uScale;
    final double v0 = (x0w * ux + y0w * uy + z0w * uz - vMin) * vScale;
    final double u1 = (x1w * rx + y1w * ry + z1w * rz - uMin) * uScale;
    final double v1 = (x1w * ux + y1w * uy + z1w * uz - vMin) * vScale;
    final double u2 = (x2w * rx + y2w * ry + z2w * rz - uMin) * uScale;
    final double v2 = (x2w * ux + y2w * uy + z2w * uz - vMin) * vScale;

    final double d0 = x0w * ldx + y0w * ldy + z0w * ldz;
    final double d1 = x1w * ldx + y1w * ldy + z1w * ldz;
    final double d2 = x2w * ldx + y2w * ldy + z2w * ldz;

    final double tu0 = alphaTest ? tri.uv0.dx * texUScale : 0.0;
    final double tv0 = alphaTest ? tri.uv0.dy * texVScale : 0.0;
    final double tu1 = alphaTest ? tri.uv1.dx * texUScale : 0.0;
    final double tv1 = alphaTest ? tri.uv1.dy * texVScale : 0.0;
    final double tu2 = alphaTest ? tri.uv2.dx * texUScale : 0.0;
    final double tv2 = alphaTest ? tri.uv2.dy * texVScale : 0.0;

    final double area = edge(u0, v0, u1, v1, u2, v2);
    if (area == 0) {
      continue;
    }
    final double invArea = 1.0 / area;

    final double minX = math.min(u0, math.min(u1, u2));
    final double maxX = math.max(u0, math.max(u1, u2));
    final double minY = math.min(v0, math.min(v1, v2));
    final double maxY = math.max(v0, math.max(v1, v2));

    final int xStart = clampInt(minX.floor(), 0, size - 1);
    final int xEnd = clampInt(maxX.ceil(), 0, size - 1);
    final int yStart = clampInt(minY.floor(), 0, size - 1);
    final int yEnd = clampInt(maxY.ceil(), 0, size - 1);

    for (int y = yStart; y <= yEnd; y++) {
      final double py = y + 0.5;
      final int row = y * size;
      for (int x = xStart; x <= xEnd; x++) {
        final double px = x + 0.5;
        final double w0 = edge(u1, v1, u2, v2, px, py);
        final double w1 = edge(u2, v2, u0, v0, px, py);
        final double w2 = edge(u0, v0, u1, v1, px, py);
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

        if (alphaTest) {
          final double uTex = a * tu0 + b * tu1 + c * tu2;
          final double vTex = a * tv0 + b * tv1 + c * tv2;
          final int uSample = clampInt(uTex.floor(), 0, textureWidth - 1);
          final int vSample = clampInt(vTex.floor(), 0, textureHeight - 1);
          final int texIndex = (vSample * textureWidth + uSample) * 4;
          final int alpha = textureRgba![texIndex + 3];
          if (alpha < alphaCutoffClamped) {
            continue;
          }
        }

        final double depthValue = a * d0 + b * d1 + c * d2;

        final int index = row + x;
        if (depthValue > depth[index]) {
          depth[index] = depthValue.toDouble();
        }
      }
    }
  }

  return _BedrockSelfShadowMap(
    depth: depth,
    size: size,
    lightDir: lightDirView,
    right: right,
    up: up,
    uMin: uMin,
    vMin: vMin,
    uScale: uScale,
    vScale: vScale,
  );
}

