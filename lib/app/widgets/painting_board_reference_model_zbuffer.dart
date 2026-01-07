part of 'painting_board.dart';

class _BedrockModelZBufferView extends StatefulWidget {
  const _BedrockModelZBufferView({
    required this.baseModel,
    required this.modelTextureWidth,
    required this.modelTextureHeight,
    required this.texture,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.animation,
    required this.animationController,
  });

  final BedrockModelMesh baseModel;
  final int modelTextureWidth;
  final int modelTextureHeight;
  final ui.Image? texture;
  final double yaw;
  final double pitch;
  final double zoom;
  final BedrockAnimation? animation;
  final AnimationController? animationController;

  @override
  State<_BedrockModelZBufferView> createState() => _BedrockModelZBufferViewState();
}

class _BedrockModelZBufferViewState extends State<_BedrockModelZBufferView> {
  static const double _kMaxRenderScale = 2.0;

  ui.Image? _rendered;
  int _renderWidth = 0;
  int _renderHeight = 0;
  double _renderScale = 1.0;

  Uint8List? _colorBuffer;
  Uint32List? _colorBuffer32;
  Float32List? _depthBuffer;

  ui.Image? _textureSource;
  Uint8List? _textureRgba;
  int _textureWidth = 0;
  int _textureHeight = 0;

  bool _dirty = true;
  bool _renderScheduled = false;
  bool _renderInProgress = false;
  int _renderGeneration = 0;

  static final Vector3 _lightDirection = Vector3(0.35, 0.7, -1)..normalize();

  @override
  void initState() {
    super.initState();
    widget.animationController?.addListener(_handleTick);
  }

  @override
  void didUpdateWidget(covariant _BedrockModelZBufferView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationController != widget.animationController) {
      oldWidget.animationController?.removeListener(_handleTick);
      widget.animationController?.addListener(_handleTick);
    }

    final bool propsChanged =
        oldWidget.baseModel != widget.baseModel ||
        oldWidget.modelTextureWidth != widget.modelTextureWidth ||
        oldWidget.modelTextureHeight != widget.modelTextureHeight ||
        oldWidget.texture != widget.texture ||
        oldWidget.yaw != widget.yaw ||
        oldWidget.pitch != widget.pitch ||
        oldWidget.zoom != widget.zoom ||
        oldWidget.animation != widget.animation;
    if (propsChanged) {
      _markDirty();
    }
  }

  @override
  void dispose() {
    widget.animationController?.removeListener(_handleTick);
    final ui.Image? rendered = _rendered;
    if (rendered != null && !rendered.debugDisposed) {
      rendered.dispose();
    }
    super.dispose();
  }

  void _handleTick() {
    if (!mounted) return;
    _markDirty();
  }

  void _markDirty() {
    _dirty = true;
    if (_renderScheduled) {
      return;
    }
    _renderScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _renderScheduled = false;
      _maybeStartRender();
    });
  }

  void _maybeStartRender() {
    if (!mounted || _renderInProgress || !_dirty) {
      return;
    }
    if (_renderWidth <= 0 || _renderHeight <= 0) {
      return;
    }
    _dirty = false;
    _renderInProgress = true;
    final int generation = ++_renderGeneration;
    unawaited(_renderFrame(generation));
  }

  void _ensureBuffers(int width, int height) {
    final int pixelCount = width * height;
    final int byteCount = pixelCount * 4;
    if (_colorBuffer == null || _colorBuffer!.lengthInBytes != byteCount) {
      _colorBuffer = Uint8List(byteCount);
      _colorBuffer32 = Endian.host == Endian.little
          ? _colorBuffer!.buffer.asUint32List(0, pixelCount)
          : null;
      _depthBuffer = Float32List(pixelCount);
    } else if (_depthBuffer == null || _depthBuffer!.length != pixelCount) {
      _depthBuffer = Float32List(pixelCount);
    }
  }

  Future<void> _ensureTextureBytes(int generation) async {
    final ui.Image? image = widget.texture;
    if (image == null || image.debugDisposed) {
      _textureSource = null;
      _textureRgba = null;
      _textureWidth = 0;
      _textureHeight = 0;
      return;
    }
    if (identical(_textureSource, image) && _textureRgba != null) {
      return;
    }
    _textureSource = image;
    _textureRgba = null;
    _textureWidth = image.width;
    _textureHeight = image.height;

    try {
      final ByteData? data =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (!mounted || generation != _renderGeneration) {
        return;
      }
      if (data == null) {
        _textureRgba = null;
        return;
      }
      _textureRgba = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to read reference model texture: $error\n$stackTrace');
      _textureRgba = null;
    }
  }

  BedrockMesh _buildMeshForFrame() {
    final BedrockAnimation? animation = widget.animation;
    final AnimationController? controller = widget.animationController;
    if (animation == null || controller == null) {
      return widget.baseModel.mesh;
    }

    final Duration? elapsed = controller.lastElapsedDuration;
    final double lifeTimeSeconds =
        elapsed == null ? 0 : elapsed.inMicroseconds / 1000000.0;
    final double timeSeconds = animation.lengthSeconds <= 0
        ? 0
        : controller.value * animation.lengthSeconds;

    final Map<String, BedrockBonePose> pose = animation.samplePose(
      widget.baseModel.model,
      timeSeconds: timeSeconds,
      lifeTimeSeconds: lifeTimeSeconds,
    );

    return buildBedrockMeshForPose(
      widget.baseModel.model,
      center: widget.baseModel.center,
      pose: pose,
    );
  }

  Future<void> _renderFrame(int generation) async {
    try {
      await _ensureTextureBytes(generation);
      if (!mounted || generation != _renderGeneration) {
        return;
      }

      _ensureBuffers(_renderWidth, _renderHeight);
      final Uint8List? colorBuffer = _colorBuffer;
      final Float32List? depthBuffer = _depthBuffer;
      if (colorBuffer == null || depthBuffer == null) {
        return;
      }

      final Uint32List? color32 = _colorBuffer32;
      if (color32 != null) {
        color32.fillRange(0, color32.length, 0);
      } else {
        colorBuffer.fillRange(0, colorBuffer.length, 0);
      }
      depthBuffer.fillRange(0, depthBuffer.length, 0);

      final BedrockMesh mesh = _buildMeshForFrame();
      _rasterizeMesh(
        mesh: mesh,
        colorBuffer: colorBuffer,
        colorBuffer32: color32,
        depthBuffer: depthBuffer,
        width: _renderWidth,
        height: _renderHeight,
        modelExtent: widget.baseModel.mesh.size,
        yaw: widget.yaw,
        pitch: widget.pitch,
        zoom: widget.zoom,
        textureRgba: _textureRgba,
        textureWidth: _textureWidth,
        textureHeight: _textureHeight,
        modelTextureWidth: widget.modelTextureWidth,
        modelTextureHeight: widget.modelTextureHeight,
      );

      final ui.Image image = await _decodeRgbaImage(
        colorBuffer,
        _renderWidth,
        _renderHeight,
      );
      if (!mounted || generation != _renderGeneration) {
        if (!image.debugDisposed) {
          image.dispose();
        }
        return;
      }
      final ui.Image? previous = _rendered;
      setState(() {
        _rendered = image;
      });
      if (previous != null && !previous.debugDisposed) {
        previous.dispose();
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to render reference model: $error\n$stackTrace');
    } finally {
      if (!mounted || generation != _renderGeneration) {
        _renderInProgress = false;
        return;
      }
      _renderInProgress = false;
      if (_dirty) {
        _markDirty();
      }
    }
  }

  Future<ui.Image> _decodeRgbaImage(
    Uint8List bytes,
    int width,
    int height,
  ) {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bytes,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

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
    required Uint8List? textureRgba,
    required int textureWidth,
    required int textureHeight,
    required int modelTextureWidth,
    required int modelTextureHeight,
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

    for (final BedrockMeshTriangle tri in mesh.triangles) {
      final Vector3 normal = tri.normal;
      final double nx = transformX(normal.x, normal.y, normal.z);
      final double ny = transformY(normal.x, normal.y, normal.z);
      final double nz = transformZ(normal.x, normal.y, normal.z);
      if (nz >= 0) {
        continue;
      }

      final double light =
          math.max(0, nx * _lightDirection.x + ny * _lightDirection.y + nz * _lightDirection.z);
      final double brightness = (0.55 + 0.45 * light).clamp(0.0, 1.0);
      final int shade = (brightness * 255).round().clamp(0, 255);

      final Vector3 p0 = tri.p0;
      final Vector3 p1 = tri.p1;
      final Vector3 p2 = tri.p2;

      final double x0w = transformX(p0.x, p0.y, p0.z);
      final double y0w = transformY(p0.x, p0.y, p0.z);
      final double z0w = transformZ(p0.x, p0.y, p0.z);
      final double x1w = transformX(p1.x, p1.y, p1.z);
      final double y1w = transformY(p1.x, p1.y, p1.z);
      final double z1w = transformZ(p1.x, p1.y, p1.z);
      final double x2w = transformX(p2.x, p2.y, p2.z);
      final double y2w = transformY(p2.x, p2.y, p2.z);
      final double z2w = transformZ(p2.x, p2.y, p2.z);

      final double z0 = z0w + cameraDistance;
      final double z1 = z1w + cameraDistance;
      final double z2 = z2w + cameraDistance;
      if (z0 <= 0 || z1 <= 0 || z2 <= 0) {
        continue;
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
        continue;
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

      final Offset uv0 = tri.uv0;
      final Offset uv1 = tri.uv1;
      final Offset uv2 = tri.uv2;
      final double u0 = uv0.dx * uScale;
      final double v0 = uv0.dy * vScale;
      final double u1 = uv1.dx * uScale;
      final double v1 = uv1.dy * vScale;
      final double u2 = uv2.dx * uScale;
      final double v2 = uv2.dy * vScale;

      final double u0OverZ = u0 * invZ0;
      final double v0OverZ = v0 * invZ0;
      final double u1OverZ = u1 * invZ1;
      final double v1OverZ = v1 * invZ1;
      final double u2OverZ = u2 * invZ2;
      final double v2OverZ = v2 * invZ2;

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
            rOut = (tr * shade) ~/ 255;
            gOut = (tg * shade) ~/ 255;
            bOut = (tb * shade) ~/ 255;
            aOut = ta;
          } else {
            rOut = shade;
            gOut = shade;
            bOut = shade;
            aOut = 255;
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
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth;
        final double maxHeight = constraints.maxHeight;
        if (!maxWidth.isFinite || !maxHeight.isFinite || maxWidth <= 0 || maxHeight <= 0) {
          return const SizedBox.expand();
        }

        final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        final double scale = devicePixelRatio <= 0
            ? 1.0
            : devicePixelRatio.clamp(1.0, _kMaxRenderScale);
        final int width = math.max(1, (maxWidth * scale).round());
        final int height = math.max(1, (maxHeight * scale).round());

        final bool sizeChanged =
            width != _renderWidth ||
            height != _renderHeight ||
            scale != _renderScale;
        if (sizeChanged) {
          _renderWidth = width;
          _renderHeight = height;
          _renderScale = scale;
          _markDirty();
        } else if (_dirty && !_renderInProgress) {
          _maybeStartRender();
        }

        final ui.Image? image = _rendered;
        if (image == null || image.debugDisposed) {
          return CustomPaint(
            painter: _BedrockModelPainter(
              baseModel: widget.baseModel,
              modelTextureWidth: widget.modelTextureWidth,
              modelTextureHeight: widget.modelTextureHeight,
              texture: widget.texture,
              yaw: widget.yaw,
              pitch: widget.pitch,
              zoom: widget.zoom,
              animation: widget.animation,
              animationController: widget.animationController,
            ),
          );
        }

        return RawImage(
          image: image,
          scale: _renderScale,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.none,
        );
      },
    );
  }
}

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

  static final Vector3 _lightDirection = Vector3(0.35, 0.7, -1)..normalize();

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

    final Offset center = size.center(Offset.zero);
    final double baseScale = (math.min(size.width, size.height) / extent) * 0.9;
    final double scale = baseScale * zoom;
    final double cameraDistance = extent * 2.4;

    final List<_ProjectedTriangle> projected = <_ProjectedTriangle>[];

    for (final BedrockMeshTriangle tri in mesh.triangles) {
      final Vector3 n = rotation.transform3(tri.normal.clone());
      if (n.z >= 0) {
        continue;
      }
      final double light = math.max(0, n.dot(_lightDirection));
      final double brightness = (0.55 + 0.45 * light).clamp(0.0, 1.0);
      final int shade = (brightness * 255).round().clamp(0, 255);
      final Color color = Color.fromARGB(255, shade, shade, shade);

      final Vector3 p0 = rotation.transform3(tri.p0.clone());
      final Vector3 p1 = rotation.transform3(tri.p1.clone());
      final Vector3 p2 = rotation.transform3(tri.p2.clone());

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
          color: color,
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
    final List<Color> colors = <Color>[];
    for (final tri in projected) {
      positions.addAll([tri.p0, tri.p1, tri.p2]);
      texCoords.addAll([tri.uv0, tri.uv1, tri.uv2]);
      colors.addAll([tri.color, tri.color, tri.color]);
    }

    final ui.Vertices vertices = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texCoords,
      colors: colors,
    );
    canvas.drawVertices(vertices, ui.BlendMode.modulate, paint);
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
    required this.color,
  });

  final double depth;
  final Offset p0;
  final Offset p1;
  final Offset p2;
  final Offset uv0;
  final Offset uv1;
  final Offset uv2;
  final Color color;
}
