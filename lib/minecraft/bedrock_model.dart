import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

sealed class BedrockCubeUv {
  const BedrockCubeUv();
}

class BedrockBoxUv extends BedrockCubeUv {
  const BedrockBoxUv({required this.offset, required this.mirror});

  final Offset offset;
  final bool mirror;
}

class BedrockFaceUv extends BedrockCubeUv {
  const BedrockFaceUv({required this.faces});

  final Map<String, BedrockUvFace> faces;
}

class BedrockUvFace {
  const BedrockUvFace({
    required this.uv,
    required this.uvSize,
    this.uvRotation = 0,
  });

  final Offset uv;
  final Offset uvSize;
  final int uvRotation;
}

class BedrockCube {
  const BedrockCube({
    required this.origin,
    required this.size,
    required this.uv,
    this.inflate = 0.0,
    this.pivot,
    this.rotation,
  });

  final Vector3 origin;
  final Vector3 size;
  final double inflate;
  final Vector3? pivot;
  final Vector3? rotation;
  final BedrockCubeUv uv;
}

class BedrockBone {
  const BedrockBone({
    required this.name,
    required this.pivot,
    this.parent,
    this.rotation,
    this.mirror = false,
    this.cubes = const <BedrockCube>[],
  });

  final String name;
  final String? parent;
  final Vector3 pivot;
  final Vector3? rotation;
  final bool mirror;
  final List<BedrockCube> cubes;
}

class BedrockGeometryModel {
  const BedrockGeometryModel({
    required this.identifier,
    required this.textureWidth,
    required this.textureHeight,
    required this.bones,
  });

  final String identifier;
  final int textureWidth;
  final int textureHeight;
  final List<BedrockBone> bones;

  static BedrockGeometryModel? tryParseFromJsonText(
    String jsonText, {
    String? preferredIdentifier,
  }) {
    final Object? decoded = json.decode(jsonText);
    if (decoded is! Map) {
      return null;
    }
    return tryParseFromRoot(decoded.cast<String, Object?>(),
        preferredIdentifier: preferredIdentifier);
  }

  static BedrockGeometryModel? tryParseFromRoot(
    Map<String, Object?> root, {
    String? preferredIdentifier,
  }) {
    final Object? geometriesRaw = root['minecraft:geometry'];
    if (geometriesRaw is! List) {
      return null;
    }
    final List<Map<String, Object?>> geometries = <Map<String, Object?>>[];
    for (final geo in geometriesRaw) {
      if (geo is Map) {
        geometries.add(geo.cast<String, Object?>());
      }
    }
    if (geometries.isEmpty) {
      return null;
    }

    Map<String, Object?> selected = geometries.first;
    if (preferredIdentifier != null && preferredIdentifier.isNotEmpty) {
      for (final geo in geometries) {
        final Map<String, Object?>? description =
            _asMap(geo['description'])?.cast<String, Object?>();
        final String? identifier = description?['identifier'] as String?;
        if (identifier == preferredIdentifier) {
          selected = geo;
          break;
        }
      }
    }

    final Map<String, Object?> description =
        _asMap(selected['description'])?.cast<String, Object?>() ??
            const <String, Object?>{};
    final String identifier =
        (description['identifier'] as String?)?.trim().isNotEmpty == true
            ? (description['identifier'] as String).trim()
            : 'geometry.unknown';
    final int textureWidth = _toInt(description['texture_width'], fallback: 16);
    final int textureHeight =
        _toInt(description['texture_height'], fallback: 16);

    final List<BedrockBone> bones = <BedrockBone>[];
    final Object? bonesRaw = selected['bones'];
    if (bonesRaw is List) {
      for (final boneRaw in bonesRaw) {
        if (boneRaw is! Map) continue;
        final Map<String, Object?> bone =
            boneRaw.cast<String, Object?>();
        final String? name = (bone['name'] as String?)?.trim();
        if (name == null || name.isEmpty) {
          continue;
        }
        final String? parent = (bone['parent'] as String?)?.trim();
        final Vector3 pivot = _parseBedrockPivot(bone['pivot']);
        final Vector3? rotation = _parseBedrockRotationNullable(bone['rotation']);
        final bool mirror = bone['mirror'] == true;

        final List<BedrockCube> cubes = <BedrockCube>[];
        final Object? cubesRaw = bone['cubes'];
        if (cubesRaw is List) {
          for (final cubeRaw in cubesRaw) {
            if (cubeRaw is! Map) continue;
            final Map<String, Object?> cube =
                cubeRaw.cast<String, Object?>();
            final Vector3 origin = _parseBedrockCubeOrigin(cube['origin'], cube['size']);
            final Vector3 size = _parseVec3(cube['size']);
            final double inflate = _toDouble(cube['inflate']);
            final Vector3? cubePivot = _parseBedrockPivotNullable(cube['pivot']);
            final Vector3? cubeRotation =
                _parseBedrockRotationNullable(cube['rotation']);
            final bool cubeMirror =
                cube.containsKey('mirror') ? cube['mirror'] == true : mirror;

            final BedrockCubeUv uv = _parseCubeUv(cube['uv'], mirror: cubeMirror, size: size);

            cubes.add(
              BedrockCube(
                origin: origin,
                size: size,
                inflate: inflate,
                pivot: cubePivot,
                rotation: cubeRotation,
                uv: uv,
              ),
            );
          }
        }

        bones.add(
          BedrockBone(
            name: name,
            parent: parent?.isEmpty == true ? null : parent,
            pivot: pivot,
            rotation: rotation,
            mirror: mirror,
            cubes: cubes,
          ),
        );
      }
    }

    return BedrockGeometryModel(
      identifier: identifier,
      textureWidth: textureWidth,
      textureHeight: textureHeight,
      bones: bones,
    );
  }
}

class BedrockMeshTriangle {
  const BedrockMeshTriangle({
    required this.p0,
    required this.p1,
    required this.p2,
    required this.uv0,
    required this.uv1,
    required this.uv2,
    required this.normal,
  });

  final Vector3 p0;
  final Vector3 p1;
  final Vector3 p2;
  final Offset uv0;
  final Offset uv1;
  final Offset uv2;
  final Vector3 normal;
}

class BedrockMesh {
  const BedrockMesh({
    required this.triangles,
    required this.boundsMin,
    required this.boundsMax,
  });

  final List<BedrockMeshTriangle> triangles;
  final Vector3 boundsMin;
  final Vector3 boundsMax;

  Vector3 get center => (boundsMin + boundsMax) * 0.5;
  Vector3 get size => boundsMax - boundsMin;
}

class BedrockModelMesh {
  const BedrockModelMesh({
    required this.model,
    required this.mesh,
    required this.center,
  });

  final BedrockGeometryModel model;
  final BedrockMesh mesh;
  final Vector3 center;
}

BedrockModelMesh buildBedrockModelMesh(BedrockGeometryModel model) {
  final ({
    List<BedrockMeshTriangle> triangles,
    Vector3? boundsMin,
    Vector3? boundsMax,
  }) built = _buildBedrockMeshTriangles(model);

  if (built.triangles.isEmpty || built.boundsMin == null || built.boundsMax == null) {
    return BedrockModelMesh(
      model: model,
      mesh: BedrockMesh(
        triangles: const <BedrockMeshTriangle>[],
        boundsMin: Vector3.zero(),
        boundsMax: Vector3.zero(),
      ),
      center: Vector3.zero(),
    );
  }

  final Vector3 center = (built.boundsMin! + built.boundsMax!) * 0.5;
  final List<BedrockMeshTriangle> centered = built.triangles
      .map(
        (tri) => BedrockMeshTriangle(
          p0: tri.p0 - center,
          p1: tri.p1 - center,
          p2: tri.p2 - center,
          uv0: tri.uv0,
          uv1: tri.uv1,
          uv2: tri.uv2,
          normal: tri.normal,
        ),
      )
      .toList(growable: false);
  final Vector3 centeredMin = built.boundsMin! - center;
  final Vector3 centeredMax = built.boundsMax! - center;

  return BedrockModelMesh(
    model: model,
    mesh: BedrockMesh(
      triangles: centered,
      boundsMin: centeredMin,
      boundsMax: centeredMax,
    ),
    center: center,
  );
}

class BedrockBonePose {
  const BedrockBonePose({this.rotation, this.position});

  final Vector3? rotation;
  final Vector3? position;
}

BedrockMesh buildBedrockMeshForPose(
  BedrockGeometryModel model, {
  required Vector3 center,
  Map<String, BedrockBonePose> pose = const <String, BedrockBonePose>{},
}) {
  final ({
    List<BedrockMeshTriangle> triangles,
    Vector3? boundsMin,
    Vector3? boundsMax,
  }) built = _buildBedrockMeshTriangles(model, pose: pose);

  if (built.triangles.isEmpty || built.boundsMin == null || built.boundsMax == null) {
    return BedrockMesh(
      triangles: const <BedrockMeshTriangle>[],
      boundsMin: Vector3.zero(),
      boundsMax: Vector3.zero(),
    );
  }

  final List<BedrockMeshTriangle> centered = built.triangles
      .map(
        (tri) => BedrockMeshTriangle(
          p0: tri.p0 - center,
          p1: tri.p1 - center,
          p2: tri.p2 - center,
          uv0: tri.uv0,
          uv1: tri.uv1,
          uv2: tri.uv2,
          normal: tri.normal,
        ),
      )
      .toList(growable: false);

  return BedrockMesh(
    triangles: centered,
    boundsMin: built.boundsMin! - center,
    boundsMax: built.boundsMax! - center,
  );
}

({
  List<BedrockMeshTriangle> triangles,
  Vector3? boundsMin,
  Vector3? boundsMax,
}) _buildBedrockMeshTriangles(
  BedrockGeometryModel model, {
  Map<String, BedrockBonePose> pose = const <String, BedrockBonePose>{},
}) {
  final Map<String, BedrockBone> bonesByName = <String, BedrockBone>{
    for (final bone in model.bones) bone.name: bone,
  };
  final Map<String, Matrix4> boneWorldTransforms = <String, Matrix4>{};

  Matrix4 boneTransform(BedrockBone bone) {
    final Matrix4? cached = boneWorldTransforms[bone.name];
    if (cached != null) {
      return cached;
    }
    final Matrix4 parentTransform;
    if (bone.parent != null && bonesByName[bone.parent] != null) {
      parentTransform = boneTransform(bonesByName[bone.parent]!);
    } else {
      parentTransform = Matrix4.identity();
    }

    final BedrockBonePose? bonePose = pose[bone.name];
    final Vector3? baseRotation = bone.rotation;
    final Vector3? deltaRotation = bonePose?.rotation;
    final Vector3 rotation = Vector3(
      (baseRotation?.x ?? 0) + (deltaRotation?.x ?? 0),
      (baseRotation?.y ?? 0) + (deltaRotation?.y ?? 0),
      (baseRotation?.z ?? 0) + (deltaRotation?.z ?? 0),
    );
    final Vector3 position = bonePose?.position ?? Vector3.zero();

    final Matrix4 local = Matrix4.identity();
    final Vector3 pivot = bone.pivot;
    if (position != Vector3.zero()) {
      local.translate(position.x, position.y, position.z);
    }
    local.translate(pivot.x, pivot.y, pivot.z);
    if (rotation != Vector3.zero()) {
      final double rx = _degToRad(rotation.x);
      final double ry = _degToRad(rotation.y);
      final double rz = _degToRad(rotation.z);
      local.rotateZ(rz);
      local.rotateY(ry);
      local.rotateX(rx);
    }
    local.translate(-pivot.x, -pivot.y, -pivot.z);

    final Matrix4 world = parentTransform.clone()..multiply(local);
    boneWorldTransforms[bone.name] = world;
    return world;
  }

  final List<BedrockMeshTriangle> triangles = <BedrockMeshTriangle>[];
  Vector3? boundsMin;
  Vector3? boundsMax;

  void includePoint(Vector3 p) {
    boundsMin ??= p.clone();
    boundsMax ??= p.clone();
    boundsMin!.x = math.min(boundsMin!.x, p.x);
    boundsMin!.y = math.min(boundsMin!.y, p.y);
    boundsMin!.z = math.min(boundsMin!.z, p.z);
    boundsMax!.x = math.max(boundsMax!.x, p.x);
    boundsMax!.y = math.max(boundsMax!.y, p.y);
    boundsMax!.z = math.max(boundsMax!.z, p.z);
  }

  void addTriangle({
    required Vector3 a,
    required Vector3 b,
    required Vector3 c,
    required Offset ua,
    required Offset ub,
    required Offset uc,
  }) {
    final Vector3 normal = (b - a).cross(c - a);
    if (normal.length2 == 0) {
      return;
    }
    triangles.add(
      BedrockMeshTriangle(
        p0: a,
        p1: b,
        p2: c,
        uv0: ua,
        uv1: ub,
        uv2: uc,
        normal: normal.normalized(),
      ),
    );
    includePoint(a);
    includePoint(b);
    includePoint(c);
  }

  for (final bone in model.bones) {
    final Matrix4 boneWorld = boneTransform(bone);
    for (final cube in bone.cubes) {
      final Matrix4 cubeTransform = _cubeLocalTransform(cube);
      final Matrix4 world = boneWorld.clone()..multiply(cubeTransform);

      final double sizeX = cube.size.x;
      final double sizeY = cube.size.y;
      final double sizeZ = cube.size.z;

      final double fromX = -(cube.origin.x + sizeX);
      final double toX = -cube.origin.x;
      final double fromY = cube.origin.y;
      final double toY = cube.origin.y + sizeY;
      final double fromZ = cube.origin.z;
      final double toZ = cube.origin.z + sizeZ;

      final List<Vector3> faceVertices = <Vector3>[
        // East
        Vector3(toX, toY, toZ),
        Vector3(toX, toY, fromZ),
        Vector3(toX, fromY, toZ),
        Vector3(toX, fromY, fromZ),
        // West
        Vector3(fromX, toY, fromZ),
        Vector3(fromX, toY, toZ),
        Vector3(fromX, fromY, fromZ),
        Vector3(fromX, fromY, toZ),
        // Up
        Vector3(fromX, toY, fromZ),
        Vector3(toX, toY, fromZ),
        Vector3(fromX, toY, toZ),
        Vector3(toX, toY, toZ),
        // Down
        Vector3(fromX, fromY, toZ),
        Vector3(toX, fromY, toZ),
        Vector3(fromX, fromY, fromZ),
        Vector3(toX, fromY, fromZ),
        // South
        Vector3(fromX, toY, toZ),
        Vector3(toX, toY, toZ),
        Vector3(fromX, fromY, toZ),
        Vector3(toX, fromY, toZ),
        // North
        Vector3(toX, toY, fromZ),
        Vector3(fromX, toY, fromZ),
        Vector3(toX, fromY, fromZ),
        Vector3(fromX, fromY, fromZ),
      ];

      // Apply cube inflate after building base positions so UV stays correct.
      if (cube.inflate != 0) {
        _inflateFaceVertices(
          faceVertices,
          inflate: cube.inflate,
          from: Vector3(fromX, fromY, fromZ),
          to: Vector3(toX, toY, toZ),
        );
      }

      const List<String> faceOrder = <String>[
        'east',
        'west',
        'up',
        'down',
        'south',
        'north',
      ];
      final Map<String, List<Offset>> uvByFace = _buildUvForCube(cube);

      for (int faceIndex = 0; faceIndex < faceOrder.length; faceIndex++) {
        final String face = faceOrder[faceIndex];
        final List<Offset>? uvs = uvByFace[face];
        if (uvs == null || uvs.length != 4) {
          continue;
        }
        final int base = faceIndex * 4;
        final Vector3 v0 = world.transform3(faceVertices[base + 0]);
        final Vector3 v1 = world.transform3(faceVertices[base + 1]);
        final Vector3 v2 = world.transform3(faceVertices[base + 2]);
        final Vector3 v3 = world.transform3(faceVertices[base + 3]);

        // Tri 1: 0,2,1
        addTriangle(
          a: v0,
          b: v2,
          c: v1,
          ua: uvs[0],
          ub: uvs[2],
          uc: uvs[1],
        );
        // Tri 2: 2,3,1
        addTriangle(
          a: v2,
          b: v3,
          c: v1,
          ua: uvs[2],
          ub: uvs[3],
          uc: uvs[1],
        );
      }
    }
  }

  return (triangles: triangles, boundsMin: boundsMin, boundsMax: boundsMax);
}

double _degToRad(double degrees) => degrees * (math.pi / 180.0);

Vector3 _parseVec3(Object? value) {
  if (value is List && value.length >= 3) {
    return Vector3(
      _toDouble(value[0]),
      _toDouble(value[1]),
      _toDouble(value[2]),
    );
  }
  return Vector3.zero();
}

Vector3 _parseBedrockPivot(Object? value) {
  final Vector3 v = _parseVec3(value);
  v.x *= -1;
  return v;
}

Vector3? _parseBedrockPivotNullable(Object? value) {
  if (value == null) return null;
  final Vector3 v = _parseBedrockPivot(value);
  if (v == Vector3.zero()) {
    return null;
  }
  return v;
}

Vector3? _parseBedrockRotationNullable(Object? value) {
  if (value == null) return null;
  final Vector3 v = _parseVec3(value);
  if (v == Vector3.zero()) {
    return null;
  }
  v.x *= -1;
  v.y *= -1;
  return v;
}

Vector3 _parseBedrockCubeOrigin(Object? origin, Object? size) {
  final Vector3 o = _parseVec3(origin);
  // Cube origin is stored in the Bedrock coordinate space; keep as-is here and
  // convert when building from/to.
  return o;
}

BedrockCubeUv _parseCubeUv(Object? value, {required bool mirror, required Vector3 size}) {
  if (value is List && value.length >= 2) {
    return BedrockBoxUv(
      offset: Offset(_toDouble(value[0]), _toDouble(value[1])),
      mirror: mirror,
    );
  }
  if (value is Map) {
    final Map<String, BedrockUvFace> faces = <String, BedrockUvFace>{};
    for (final entry in value.entries) {
      final String face = entry.key;
      final Object? data = entry.value;
      if (data is! Map) continue;
      final Map<String, Object?> m = data.cast<String, Object?>();
      final Offset uv = _parseOffset2(m['uv']);
      final Offset uvSize = _parseOffset2(m['uv_size']);
      final int rotation = _toInt(m['uv_rotation'], fallback: 0);
      if (uv == Offset.zero && uvSize == Offset.zero) {
        continue;
      }
      faces[face] = BedrockUvFace(uv: uv, uvSize: uvSize, uvRotation: rotation);
    }
    return BedrockFaceUv(faces: faces);
  }

  // Fallback: treat as box UV starting at 0,0.
  return BedrockBoxUv(offset: Offset.zero, mirror: mirror);
}

Offset _parseOffset2(Object? value) {
  if (value is List && value.length >= 2) {
    return Offset(_toDouble(value[0]), _toDouble(value[1]));
  }
  return Offset.zero;
}

Map<String, List<Offset>> _buildUvForCube(BedrockCube cube) {
  const List<String> faces = <String>[
    'east',
    'west',
    'up',
    'down',
    'south',
    'north',
  ];
  final Map<String, List<Offset>> result = <String, List<Offset>>{};

  final BedrockCubeUv uv = cube.uv;
  if (uv is BedrockBoxUv) {
    final double dx = cube.size.x.abs();
    final double dy = cube.size.y.abs();
    final double dz = cube.size.z.abs();
    final double u = uv.offset.dx;
    final double v = uv.offset.dy;

    final List<_UvRect> rects = <_UvRect>[
      _UvRect(face: 'east', x: 0, y: dz, w: dz, h: dy),
      _UvRect(face: 'west', x: dz + dx, y: dz, w: dz, h: dy),
      _UvRect(face: 'up', x: dz + dx, y: dz, w: -dx, h: -dz),
      _UvRect(face: 'down', x: dz + dx * 2, y: 0, w: -dx, h: dz),
      _UvRect(face: 'south', x: dz * 2 + dx, y: dz, w: dx, h: dy),
      _UvRect(face: 'north', x: dz, y: dz, w: dx, h: dy),
    ];

    if (uv.mirror) {
      for (int i = 0; i < rects.length; i++) {
        rects[i] = rects[i].mirrored();
      }
      final _UvRect east = rects[0];
      rects[0] = rects[1];
      rects[1] = east;
    }

    for (final rect in rects) {
      final double u0 = u + rect.x;
      final double v0 = v + rect.y;
      final double u1 = u + rect.x + rect.w;
      final double v1 = v + rect.y + rect.h;
      result[rect.face] = <Offset>[
        Offset(u0, v0),
        Offset(u1, v0),
        Offset(u0, v1),
        Offset(u1, v1),
      ];
    }
    return result;
  }

  if (uv is BedrockFaceUv) {
    for (final face in faces) {
      final BedrockUvFace? uvFace = uv.faces[face];
      if (uvFace == null) continue;
      final double u0 = uvFace.uv.dx;
      final double v0 = uvFace.uv.dy;
      final double u1 = uvFace.uv.dx + uvFace.uvSize.dx;
      final double v1 = uvFace.uv.dy + uvFace.uvSize.dy;
      List<Offset> corners = <Offset>[
        Offset(u0, v0),
        Offset(u1, v0),
        Offset(u0, v1),
        Offset(u1, v1),
      ];
      final int rotation = ((uvFace.uvRotation % 360) + 360) % 360;
      int times = (rotation / 90).round() % 4;
      while (times > 0) {
        final Offset a = corners[0];
        corners = <Offset>[corners[2], a, corners[3], corners[1]];
        times--;
      }
      result[face] = corners;
    }
  }

  return result;
}

Matrix4 _cubeLocalTransform(BedrockCube cube) {
  final Vector3? pivot = cube.pivot;
  final Vector3? rotation = cube.rotation;
  if (pivot == null || rotation == null) {
    return Matrix4.identity();
  }
  final Matrix4 m = Matrix4.identity();
  m.translate(pivot.x, pivot.y, pivot.z);
  final double rx = _degToRad(rotation.x);
  final double ry = _degToRad(rotation.y);
  final double rz = _degToRad(rotation.z);
  m.rotateZ(rz);
  m.rotateY(ry);
  m.rotateX(rx);
  m.translate(-pivot.x, -pivot.y, -pivot.z);
  return m;
}

void _inflateFaceVertices(
  List<Vector3> vertices, {
  required double inflate,
  required Vector3 from,
  required Vector3 to,
}) {
  final Vector3 halfSize = (to - from) * 0.5;
  final Vector3 center = from + halfSize;
  for (int i = 0; i < vertices.length; i++) {
    final Vector3 p = vertices[i];
    final Vector3 dir = (p - center);
    final Vector3 unit = Vector3(
      dir.x.sign,
      dir.y.sign,
      dir.z.sign,
    );
    vertices[i] = p + unit * inflate;
  }
}

class _UvRect {
  const _UvRect({
    required this.face,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final String face;
  final double x;
  final double y;
  final double w;
  final double h;

  _UvRect mirrored() => _UvRect(face: face, x: x + w, y: y, w: -w, h: h);
}

Map<Object?, Object?>? _asMap(Object? value) => value is Map ? value : null;

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return 0.0;
}

int _toInt(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}
