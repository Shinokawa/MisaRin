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
    this.lightDirection,
    this.ambient = 0.55,
    this.diffuse = 0.45,
    this.sunColor = const Color(0xFFFFFFFF),
    this.skyColor = const Color(0xFFBFD9FF),
    this.groundBounceColor = const Color(0xFFFFFFFF),
    this.specularStrength = 0.25,
    this.roughness = 0.55,
    this.exposure = 1.0,
    this.lightFollowsCamera = true,
    this.showGround = false,
    this.groundY = 0.0,
    this.alignModelToGround = false,
    this.groundColor = const Color(0xFFFFFFFF),
    this.showGroundShadow = false,
    this.groundShadowStrength = 0.55,
    this.groundShadowBlurRadius = 2,
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
  final Vector3? lightDirection;
  final double ambient;
  final double diffuse;
  final Color sunColor;
  final Color skyColor;
  final Color groundBounceColor;
  final double specularStrength;
  final double roughness;
  final double exposure;
  final bool lightFollowsCamera;
  final bool showGround;
  final double groundY;
  final bool alignModelToGround;
  final Color groundColor;
  final bool showGroundShadow;
  final double groundShadowStrength;
  final int groundShadowBlurRadius;

  @override
  State<_BedrockModelZBufferView> createState() => _BedrockModelZBufferViewState();
}

class _BedrockModelZBufferViewState extends State<_BedrockModelZBufferView> {
  static const double _kMaxRenderScale = 2.0;
  static const double _kShadowDirectionEpsilon = 1e-6;
  static const int _kLinearToSrgbTableSize = 4096;

  static final Float32List _srgbToLinearTable = _buildSrgbToLinearTable();
  static final Uint8List _linearToSrgbTable = _buildLinearToSrgbTable();

  ui.Image? _rendered;
  int _renderWidth = 0;
  int _renderHeight = 0;
  double _renderScale = 1.0;

  Uint8List? _colorBuffer;
  Uint32List? _colorBuffer32;
  Float32List? _depthBuffer;
  Uint8List? _shadowMask;
  Uint8List? _shadowMaskScratch;

  ui.Image? _textureSource;
  Uint8List? _textureRgba;
  int _textureWidth = 0;
  int _textureHeight = 0;

  bool _dirty = true;
  bool _renderScheduled = false;
  bool _renderInProgress = false;
  int _renderGeneration = 0;

  static final Vector3 _defaultLightDirection =
      Vector3(0.35, 0.7, -1)..normalize();

  static Float32List _buildSrgbToLinearTable() {
    final Float32List table = Float32List(256);
    for (int i = 0; i < 256; i++) {
      final double c = i / 255.0;
      table[i] = _srgbToLinear(c).toDouble();
    }
    return table;
  }

  static Uint8List _buildLinearToSrgbTable() {
    final Uint8List table = Uint8List(_kLinearToSrgbTableSize);
    for (int i = 0; i < _kLinearToSrgbTableSize; i++) {
      final double l = i / (_kLinearToSrgbTableSize - 1);
      final double c = _linearToSrgb(l);
      table[i] = (c * 255).round().clamp(0, 255);
    }
    return table;
  }

  static double _srgbToLinear(double c) {
    if (c <= 0.04045) {
      return c / 12.92;
    }
    return math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  static double _linearToSrgb(double l) {
    if (l <= 0.0031308) {
      return 12.92 * l;
    }
    return (1.055 * math.pow(l, 1.0 / 2.4) - 0.055).toDouble();
  }

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
        oldWidget.animation != widget.animation ||
        oldWidget.lightDirection != widget.lightDirection ||
        oldWidget.ambient != widget.ambient ||
        oldWidget.diffuse != widget.diffuse ||
        oldWidget.sunColor != widget.sunColor ||
        oldWidget.skyColor != widget.skyColor ||
        oldWidget.groundBounceColor != widget.groundBounceColor ||
        oldWidget.specularStrength != widget.specularStrength ||
        oldWidget.roughness != widget.roughness ||
        oldWidget.exposure != widget.exposure ||
        oldWidget.lightFollowsCamera != widget.lightFollowsCamera ||
        oldWidget.showGround != widget.showGround ||
        oldWidget.groundY != widget.groundY ||
        oldWidget.alignModelToGround != widget.alignModelToGround ||
        oldWidget.groundColor != widget.groundColor ||
        oldWidget.showGroundShadow != widget.showGroundShadow ||
        oldWidget.groundShadowStrength != widget.groundShadowStrength ||
        oldWidget.groundShadowBlurRadius != widget.groundShadowBlurRadius;
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

    if (_shadowMask == null || _shadowMask!.length != pixelCount) {
      _shadowMask = Uint8List(pixelCount);
      _shadowMaskScratch = Uint8List(pixelCount);
    } else if (_shadowMaskScratch == null ||
        _shadowMaskScratch!.length != pixelCount) {
      _shadowMaskScratch = Uint8List(pixelCount);
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

      final Vector3 modelSize = widget.baseModel.mesh.size;
      final double extentScalar = math.max(
        modelSize.x.abs(),
        math.max(modelSize.y.abs(), modelSize.z.abs()),
      );
      final double modelYOffset = widget.showGround && widget.alignModelToGround
          ? widget.groundY - widget.baseModel.mesh.boundsMin.y
          : 0.0;
      final double groundYLocal = widget.groundY;

      final Vector3 lightDir =
          (widget.lightDirection ?? _defaultLightDirection).clone();
      if (lightDir.length2 <= 0) {
        lightDir.setFrom(_defaultLightDirection);
      } else {
        lightDir.normalize();
      }

      if (widget.showGround && extentScalar > 0) {
        final double groundHalfSize = math.max(extentScalar * 128, 256);
        final BedrockMesh ground = _buildGroundMesh(
          groundY: groundYLocal,
          halfSize: groundHalfSize,
          doubleSided: true,
        );
        _rasterizeMesh(
          mesh: ground,
          colorBuffer: colorBuffer,
          colorBuffer32: color32,
          depthBuffer: depthBuffer,
          width: _renderWidth,
          height: _renderHeight,
          modelExtent: modelSize,
          yaw: widget.yaw,
          pitch: widget.pitch,
          zoom: widget.zoom,
          lightDirection: lightDir,
          ambient: 1.0,
          diffuse: 0.0,
          sunColor: widget.sunColor,
          skyColor: widget.skyColor,
          groundBounceColor: widget.groundBounceColor,
          specularStrength: widget.specularStrength,
          roughness: widget.roughness,
          exposure: widget.exposure,
          lightFollowsCamera: widget.lightFollowsCamera,
          unlit: true,
          textureRgba: null,
          textureWidth: 0,
          textureHeight: 0,
          modelTextureWidth: 0,
          modelTextureHeight: 0,
          untexturedBaseColor: widget.groundColor,
        );

        if (widget.showGroundShadow) {
          final Uint8List mask = _shadowMask!;
          mask.fillRange(0, mask.length, 0);
          _rasterizePlanarShadowMask(
            mesh: mesh,
            mask: mask,
            depthBuffer: depthBuffer,
            width: _renderWidth,
            height: _renderHeight,
            modelExtent: modelSize,
            yaw: widget.yaw,
            pitch: widget.pitch,
            zoom: widget.zoom,
            lightDirection: lightDir,
            lightFollowsCamera: widget.lightFollowsCamera,
            groundY: groundYLocal,
            translateY: modelYOffset,
          );
          final int blurRadius = widget.groundShadowBlurRadius;
          if (blurRadius > 0) {
            _blurMask(
              mask: mask,
              scratch: _shadowMaskScratch!,
              width: _renderWidth,
              height: _renderHeight,
              radius: blurRadius,
            );
          }
          _applyShadowMask(
            colorBuffer: colorBuffer,
            colorBuffer32: color32,
            depthBuffer: depthBuffer,
            mask: mask,
            strength: widget.groundShadowStrength,
          );
        }
      }

      _rasterizeMesh(
        mesh: mesh,
        colorBuffer: colorBuffer,
        colorBuffer32: color32,
        depthBuffer: depthBuffer,
        width: _renderWidth,
        height: _renderHeight,
        modelExtent: modelSize,
        yaw: widget.yaw,
        pitch: widget.pitch,
        zoom: widget.zoom,
        translateY: modelYOffset,
        lightDirection: lightDir,
        ambient: widget.ambient,
        diffuse: widget.diffuse,
        sunColor: widget.sunColor,
        skyColor: widget.skyColor,
        groundBounceColor: widget.groundBounceColor,
        specularStrength: widget.specularStrength,
        roughness: widget.roughness,
        exposure: widget.exposure,
        lightFollowsCamera: widget.lightFollowsCamera,
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
    required bool lightFollowsCamera,
    bool unlit = false,
    required Uint8List? textureRgba,
    required int textureWidth,
    required int textureHeight,
    required int modelTextureWidth,
    required int modelTextureHeight,
    Color untexturedBaseColor = const Color(0xFFFFFFFF),
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
      lightDir.setFrom(_defaultLightDirection);
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

    final Float32List srgbToLinear = _srgbToLinearTable;
    final Uint8List linearToSrgb = _linearToSrgbTable;
    final int linearMaxIndex = _kLinearToSrgbTableSize - 1;

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
    double triLightR = 1.0;
    double triLightG = 1.0;
    double triLightB = 1.0;
    double triSpecR = 0.0;
    double triSpecG = 0.0;
    double triSpecB = 0.0;

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
      required double x1w,
      required double y1w,
      required double z1,
      required double u1,
      required double v1,
      required double x2w,
      required double y2w,
      required double z2,
      required double u2,
      required double v2,
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
              final double rLin =
                  (srgbToLinear[tr] * triLightR + triSpecR) *
                  exposureClamped;
              final double gLin =
                  (srgbToLinear[tg] * triLightG + triSpecG) *
                  exposureClamped;
              final double bLin =
                  (srgbToLinear[tb] * triLightB + triSpecB) *
                  exposureClamped;
              final double rMapped = rLin / (1.0 + rLin);
              final double gMapped = gLin / (1.0 + gLin);
              final double bMapped = bLin / (1.0 + bLin);
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
              final double rLin =
                  (untexturedRLin * triLightR + triSpecR) * exposureClamped;
              final double gLin =
                  (untexturedGLin * triLightG + triSpecG) * exposureClamped;
              final double bLin =
                  (untexturedBLin * triLightB + triSpecB) * exposureClamped;
              final double rMapped = rLin / (1.0 + rLin);
              final double gMapped = gLin / (1.0 + gLin);
              final double bMapped = bLin / (1.0 + bLin);
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
          triLightR = ambientClamped;
          triLightG = ambientClamped;
          triLightB = ambientClamped;
          triSpecR = 0.0;
          triSpecG = 0.0;
          triSpecB = 0.0;
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

          triLightR = ambR + sunRLin * sunIntensity;
          triLightG = ambG + sunGLin * sunIntensity;
          triLightB = ambB + sunBLin * sunIntensity;

          triSpecR = 0.0;
          triSpecG = 0.0;
          triSpecB = 0.0;

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
        triLightR = 1.0;
        triLightG = 1.0;
        triLightB = 1.0;
        triSpecR = 0.0;
        triSpecG = 0.0;
        triSpecB = 0.0;
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
          x1w: x1w,
          y1w: y1w,
          z1: z1,
          u1: u1,
          v1: v1,
          x2w: x2w,
          y2w: y2w,
          z2: z2,
          u2: u2,
          v2: v2,
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
      lightDir.setFrom(_defaultLightDirection);
    } else {
      lightDir.normalize();
	    }

	    final Vector3 lightDirModel = lightFollowsCamera
	        ? ((rotation.clone()..transpose()).transform3(lightDir.clone())..normalize())
	        : lightDir;
	    final Vector3 shadowDir = -lightDirModel;
	    if (shadowDir.y.abs() <= _kShadowDirectionEpsilon) {
	      return;
	    }

    final double centerX = width * 0.5;
    final double centerY = height * 0.5;
    final double baseScale =
        (math.min(width.toDouble(), height.toDouble()) / extent) * 0.9;
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
        final int rx = removeX < 0
            ? 0
            : (removeX >= width ? width - 1 : removeX);
        final int ax =
            addX < 0 ? 0 : (addX >= width ? width - 1 : addX);
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
        final int ry = removeY < 0
            ? 0
            : (removeY >= height ? height - 1 : removeY);
        final int ay =
            addY < 0 ? 0 : (addY >= height ? height - 1 : addY);
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
	              lightDirection: widget.lightDirection,
	              ambient: widget.ambient,
	              diffuse: widget.diffuse,
	              lightFollowsCamera: widget.lightFollowsCamera,
	              showGround: widget.showGround,
	              groundY: widget.groundY,
	              alignModelToGround: widget.alignModelToGround,
	              groundColor: widget.groundColor,
	              showGroundShadow: widget.showGroundShadow,
	              groundShadowStrength: widget.groundShadowStrength,
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
    final double baseScale = (math.min(size.width, size.height) / extent) * 0.9;
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

	      canvas.drawPath(floorPath, Paint()..color = groundColor);

	      if (showGroundShadow && groundShadowStrength > 0) {
	        final Vector3 lightDirModel = lightFollowsCamera
	            ? ((rotation.clone()..transpose()).transform3(lightDir.clone())..normalize())
	            : lightDir;
	        final Vector3 shadowDir = -lightDirModel;
	        if (shadowDir.y.abs() > _BedrockModelZBufferViewState._kShadowDirectionEpsilon) {
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
          (ambientClamped + diffuseClamped * light).clamp(0.0, 1.0);
      final int shade = (brightness * 255).round().clamp(0, 255);
      final Color color = Color.fromARGB(255, shade, shade, shade);

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
