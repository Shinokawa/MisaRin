part of 'painting_board.dart';

class _BedrockModelPainter extends CustomPainter {
  _BedrockModelPainter({
    required this.baseModel,
    required this.modelTextureWidth,
    required this.modelTextureHeight,
    required this.texture,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    this.animation,
    this.animationController,
    required this.lightDirection,
    required this.ambient,
    required this.diffuse,
    required this.lightFollowsCamera,
    required this.showGround,
    required this.groundY,
    required this.alignModelToGround,
    required this.groundColor,
    required this.showGroundShadow,
    required this.groundShadowStrength,
  }) : super(repaint: animationController);

  final BedrockModelMesh baseModel;
  final int modelTextureWidth;
  final int modelTextureHeight;
  final ui.Image? texture;
  final double yaw;
  final double pitch;
  final double zoom;
  final BedrockAnimation? animation;
  final AnimationController? animationController;
  final Vector3? lightDirection;
  final double ambient;
  final double diffuse;
  final bool lightFollowsCamera;
  final bool showGround;
  final double groundY;
  final bool alignModelToGround;
  final Color groundColor;
  final bool showGroundShadow;
  final double groundShadowStrength;

  static final Vector3 _defaultLightDirection =
      Vector3(0.35, 0.7, -1)..normalize();

  @override
  void paint(Canvas canvas, Size size) {
    final BedrockMesh mesh = _buildMeshForFrame();
    if (mesh.triangles.isEmpty || size.isEmpty) {
      return;
    }
    final Vector3 meshSize = baseModel.mesh.size;
    final double extent = math.max(
      meshSize.x.abs(),
      math.max(meshSize.y.abs(), meshSize.z.abs()),
    );
    if (extent <= 0) {
      return;
    }

    final ui.Image? tex = texture;
    final bool hasTexture = tex != null && !tex.debugDisposed;
    final double uScale = hasTexture && modelTextureWidth > 0
        ? tex.width / modelTextureWidth
        : 1.0;
    final double vScale = hasTexture && modelTextureHeight > 0
        ? tex.height / modelTextureHeight
        : 1.0;

    final Matrix4 rotation = Matrix4.identity()
      ..rotateY(yaw)
      ..rotateX(pitch);

    final Vector3 lightDir =
        (lightDirection ?? _defaultLightDirection).clone();
    if (lightDir.length2 <= 0) {
      lightDir.setFrom(_defaultLightDirection);
    } else {
      lightDir.normalize();
    }
    final double ambientClamped = ambient.clamp(0.0, 1.0).toDouble();
    final double diffuseClamped = diffuse.clamp(0.0, 1.0).toDouble();

    final Offset center = size.center(Offset.zero);
    final double baseScale =
        (math.min(size.width, size.height) / extent) * 0.9;
    final double scale = baseScale * zoom;
    final double cameraDistance = extent * 2.4;

    final double modelYOffset = showGround && alignModelToGround
        ? groundY - baseModel.mesh.boundsMin.y
        : 0.0;
    final double groundYLocal = groundY;

    Offset projectPoint(Vector3 point) {
      final Vector3 p = rotation.transform3(point.clone());
      final double z = p.z + cameraDistance;
      if (z <= 0) {
        return center;
      }
      final double s = cameraDistance / z;
      return center + Offset(p.x * s * scale, -p.y * s * scale);
    }

    if (showGround) {
      final double floorSize = math.max(extent * 128, 256);
      final List<Offset> corners = <Offset>[
        projectPoint(Vector3(-floorSize, groundYLocal, -floorSize)),
        projectPoint(Vector3(floorSize, groundYLocal, -floorSize)),
        projectPoint(Vector3(floorSize, groundYLocal, floorSize)),
        projectPoint(Vector3(-floorSize, groundYLocal, floorSize)),
      ];

      final Path floorPath = Path()
        ..moveTo(corners[0].dx, corners[0].dy)
        ..lineTo(corners[1].dx, corners[1].dy)
        ..lineTo(corners[2].dx, corners[2].dy)
        ..lineTo(corners[3].dx, corners[3].dy)
        ..close();

      Vector3 groundNormalModel = Vector3(0, 1, 0);
      Vector3 groundNormalView =
          rotation.transform3(groundNormalModel.clone());
      if (groundNormalView.z >= 0) {
        groundNormalModel = Vector3(0, -1, 0);
        groundNormalView = -groundNormalView;
      }
      final double groundLight = lightFollowsCamera
          ? math.max(0.0, groundNormalView.dot(lightDir))
          : math.max(0.0, groundNormalModel.dot(lightDir));
      final double groundBrightness =
          (ambientClamped + diffuseClamped * groundLight)
              .clamp(0.0, 1.0)
              .toDouble();
      final Color litGroundColor = groundColor.withValues(
        red: (groundColor.r * groundBrightness).clamp(0.0, 1.0),
        green: (groundColor.g * groundBrightness).clamp(0.0, 1.0),
        blue: (groundColor.b * groundBrightness).clamp(0.0, 1.0),
      );
      canvas.drawPath(floorPath, Paint()..color = litGroundColor);

      if (showGroundShadow && groundShadowStrength > 0) {
        final Vector3 lightDirModel = lightFollowsCamera
            ? ((rotation.clone()..transpose())
                    .transform3(lightDir.clone())
                  ..normalize())
            : lightDir;
        final Vector3 shadowDir = -lightDirModel;
        if (shadowDir.y.abs() >
            _BedrockModelZBufferViewState._kShadowDirectionEpsilon) {
          final Paint shadowPaint = Paint()
            ..color = Colors.black.withValues(
              alpha: groundShadowStrength.clamp(0.0, 1.0).toDouble(),
            );
          Vector3 projectToPlane(Vector3 p) {
            final Vector3 world = p.clone()..y += modelYOffset;
            final double t = (groundYLocal - world.y) / shadowDir.y;
            return world + shadowDir * t;
          }

          canvas.save();
          canvas.clipPath(floorPath);
          for (final BedrockMeshTriangle tri in mesh.triangles) {
            final Offset a = projectPoint(projectToPlane(tri.p0));
            final Offset b = projectPoint(projectToPlane(tri.p1));
            final Offset c = projectPoint(projectToPlane(tri.p2));
            final Path shadow = Path()
              ..moveTo(a.dx, a.dy)
              ..lineTo(b.dx, b.dy)
              ..lineTo(c.dx, c.dy)
              ..close();
            canvas.drawPath(shadow, shadowPaint);
          }
          canvas.restore();
        }
      }
    }

    final List<_ProjectedTriangle> projected = <_ProjectedTriangle>[];

    for (final BedrockMeshTriangle tri in mesh.triangles) {
      final Vector3 n = rotation.transform3(tri.normal.clone());
      if (n.z >= 0) {
        continue;
      }
      final double light = lightFollowsCamera
          ? math.max(0, n.dot(lightDir))
          : math.max(0, tri.normal.dot(lightDir));
      final double brightness =
          (ambientClamped + diffuseClamped * light).clamp(0.0, 2.0);
      final double baseBrightness = brightness <= 1.0 ? brightness : 1.0;
      final double extraBrightness = brightness > 1.0
          ? (brightness - 1.0).clamp(0.0, 1.0).toDouble()
          : 0.0;
      final int baseShade = (baseBrightness * 255).round().clamp(0, 255);
      final int extraShade = (extraBrightness * 255).round().clamp(0, 255);
      final Color baseColor =
          Color.fromARGB(255, baseShade, baseShade, baseShade);
      final Color extraColor = extraShade == 0
          ? const Color.fromARGB(0, 0, 0, 0)
          : Color.fromARGB(255, extraShade, extraShade, extraShade);

      final Vector3 p0 = rotation.transform3(tri.p0.clone()..y += modelYOffset);
      final Vector3 p1 = rotation.transform3(tri.p1.clone()..y += modelYOffset);
      final Vector3 p2 = rotation.transform3(tri.p2.clone()..y += modelYOffset);

      final double z0 = p0.z + cameraDistance;
      final double z1 = p1.z + cameraDistance;
      final double z2 = p2.z + cameraDistance;
      if (z0 <= 0 || z1 <= 0 || z2 <= 0) {
        continue;
      }

      final double s0 = cameraDistance / z0;
      final double s1 = cameraDistance / z1;
      final double s2 = cameraDistance / z2;

      final Offset v0 = center + Offset(p0.x * s0 * scale, -p0.y * s0 * scale);
      final Offset v1 = center + Offset(p1.x * s1 * scale, -p1.y * s1 * scale);
      final Offset v2 = center + Offset(p2.x * s2 * scale, -p2.y * s2 * scale);

      projected.add(
        _ProjectedTriangle(
          depth: (z0 + z1 + z2) / 3,
          p0: v0,
          p1: v1,
          p2: v2,
          uv0: Offset(tri.uv0.dx * uScale, tri.uv0.dy * vScale),
          uv1: Offset(tri.uv1.dx * uScale, tri.uv1.dy * vScale),
          uv2: Offset(tri.uv2.dx * uScale, tri.uv2.dy * vScale),
          baseColor: baseColor,
          extraColor: extraColor,
        ),
      );
    }

    if (projected.isEmpty) {
      return;
    }

    projected.sort((a, b) => b.depth.compareTo(a.depth));

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    if (!hasTexture) {
      final Paint wire = Paint()
        ..color = const Color(0xFF4D4D4D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      for (final tri in projected) {
        final Path path = Path()
          ..moveTo(tri.p0.dx, tri.p0.dy)
          ..lineTo(tri.p1.dx, tri.p1.dy)
          ..lineTo(tri.p2.dx, tri.p2.dy)
          ..close();
        canvas.drawPath(path, wire);
      }
      canvas.restore();
      return;
    }

    final Paint paint = Paint()
      ..filterQuality = FilterQuality.none
      ..shader = ui.ImageShader(
        tex!,
        ui.TileMode.clamp,
        ui.TileMode.clamp,
        Matrix4.identity().storage,
      );

    final List<Offset> positions = <Offset>[];
    final List<Offset> texCoords = <Offset>[];
    final List<Color> baseColors = <Color>[];
    final List<Color> extraColors = <Color>[];
    bool hasExtraLight = false;
    for (final tri in projected) {
      positions.addAll([tri.p0, tri.p1, tri.p2]);
      texCoords.addAll([tri.uv0, tri.uv1, tri.uv2]);
      baseColors.addAll([tri.baseColor, tri.baseColor, tri.baseColor]);
      extraColors.addAll([tri.extraColor, tri.extraColor, tri.extraColor]);
      hasExtraLight = hasExtraLight || tri.extraColor.alpha != 0;
    }

    final ui.Vertices vertices = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texCoords,
      colors: baseColors,
    );
    canvas.drawVertices(vertices, ui.BlendMode.modulate, paint);
    if (hasExtraLight) {
      final ui.Vertices extraVertices = ui.Vertices(
        ui.VertexMode.triangles,
        positions,
        textureCoordinates: texCoords,
        colors: extraColors,
      );
      canvas.drawVertices(
        extraVertices,
        ui.BlendMode.modulate,
        Paint()
          ..filterQuality = FilterQuality.none
          ..blendMode = BlendMode.plus
          ..shader = paint.shader,
      );
    }
    canvas.restore();
  }

  BedrockMesh _buildMeshForFrame() {
    final BedrockAnimation? animation = this.animation;
    final AnimationController? controller = animationController;
    if (animation == null || controller == null) {
      return baseModel.mesh;
    }

    final Duration? elapsed = controller.lastElapsedDuration;
    final double lifeTimeSeconds = elapsed == null
        ? 0
        : elapsed.inMicroseconds / 1000000.0;
    final double timeSeconds = animation.lengthSeconds <= 0
        ? 0
        : controller.value * animation.lengthSeconds;

    final Map<String, BedrockBonePose> pose = animation.samplePose(
      baseModel.model,
      timeSeconds: timeSeconds,
      lifeTimeSeconds: lifeTimeSeconds,
    );

    return buildBedrockMeshForPose(
      baseModel.model,
      center: baseModel.center,
      pose: pose,
    );
  }

  @override
  bool shouldRepaint(covariant _BedrockModelPainter oldDelegate) {
    return oldDelegate.baseModel != baseModel ||
        oldDelegate.texture != texture ||
        oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.zoom != zoom ||
        oldDelegate.lightDirection != lightDirection ||
        oldDelegate.ambient != ambient ||
        oldDelegate.diffuse != diffuse ||
        oldDelegate.lightFollowsCamera != lightFollowsCamera ||
        oldDelegate.showGround != showGround ||
        oldDelegate.groundY != groundY ||
        oldDelegate.alignModelToGround != alignModelToGround ||
        oldDelegate.groundColor != groundColor ||
        oldDelegate.showGroundShadow != showGroundShadow ||
        oldDelegate.groundShadowStrength != groundShadowStrength ||
        oldDelegate.modelTextureWidth != modelTextureWidth ||
        oldDelegate.modelTextureHeight != modelTextureHeight ||
        oldDelegate.animation != animation;
  }
}

class _ProjectedTriangle {
  const _ProjectedTriangle({
    required this.depth,
    required this.p0,
    required this.p1,
    required this.p2,
    required this.uv0,
    required this.uv1,
    required this.uv2,
    required this.baseColor,
    required this.extraColor,
  });

  final double depth;
  final Offset p0;
  final Offset p1;
  final Offset p2;
  final Offset uv0;
  final Offset uv1;
  final Offset uv2;
  final Color baseColor;
  final Color extraColor;
}

