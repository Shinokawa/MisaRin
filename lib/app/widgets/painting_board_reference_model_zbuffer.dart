part of 'painting_board.dart';

class _BedrockModelZBufferView extends StatefulWidget {
  const _BedrockModelZBufferView({
    super.key,
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
    this.toneMap = false,
    this.enableSelfShadow = false,
    this.selfShadowStrength = 1.0,
    this.selfShadowMapSize = 512,
    this.selfShadowBias = 0.02,
    this.selfShadowSlopeBias = 0.03,
    this.selfShadowPcfRadius = 1,
    this.enableContactShadow = false,
    this.contactShadowStrength = 0.18,
    this.contactShadowBlurRadius = 3,
    this.contactShadowDepthEpsilon = 0.01,
    this.lightFollowsCamera = true,
    this.showGround = false,
    this.groundY = 0.0,
    this.alignModelToGround = false,
    this.groundColor = const Color(0xFFFFFFFF),
    this.showGroundShadow = false,
    this.groundShadowStrength = 0.55,
    this.groundShadowBlurRadius = 2,
    this.groundShadowIntoAlpha = false,
    this.renderKey = 0,
    this.onRendered,
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
  final bool toneMap;
  final bool enableSelfShadow;
  final double selfShadowStrength;
  final int selfShadowMapSize;
  final double selfShadowBias;
  final double selfShadowSlopeBias;
  final int selfShadowPcfRadius;
  final bool enableContactShadow;
  final double contactShadowStrength;
  final int contactShadowBlurRadius;
  final double contactShadowDepthEpsilon;
  final bool lightFollowsCamera;
  final bool showGround;
  final double groundY;
  final bool alignModelToGround;
  final Color groundColor;
  final bool showGroundShadow;
  final double groundShadowStrength;
  final int groundShadowBlurRadius;
  final bool groundShadowIntoAlpha;
  final int renderKey;
  final ValueChanged<int>? onRendered;

  @override
  State<_BedrockModelZBufferView> createState() =>
      _BedrockModelZBufferViewState();
}

class _BedrockTextureBytes {
  const _BedrockTextureBytes({
    required this.rgba,
    required this.width,
    required this.height,
  });

  final Uint8List rgba;
  final int width;
  final int height;
}

class _BedrockModelZBufferViewState extends State<_BedrockModelZBufferView> {
  static const double _kMaxRenderScale = 2.0;
  static const double _kShadowDirectionEpsilon = 1e-6;
  static const int _kLinearToSrgbTableSize = 4096;

  static final Float32List _srgbToLinearTable = _buildSrgbToLinearTable();
  static final Uint8List _linearToSrgbTable = _buildLinearToSrgbTable();

  static final Expando<Future<_BedrockTextureBytes?>> _textureBytesCache =
      Expando<Future<_BedrockTextureBytes?>>('_BedrockModelTextureBytes');

  ui.Image? _rendered;
  int _renderWidth = 0;
  int _renderHeight = 0;
  double _renderScale = 1.0;

  Uint8List? _colorBuffer;
  Uint32List? _colorBuffer32;
  Float32List? _depthBuffer;
  Uint8List? _shadowMask;
  Uint8List? _shadowMaskScratch;
  Float32List? _selfShadowDepth;

  ui.Image? _textureSource;
  Uint8List? _textureRgba;
  int _textureWidth = 0;
  int _textureHeight = 0;

  bool _dirty = true;
  bool _renderScheduled = false;
  bool _renderInProgress = false;
  int _renderGeneration = 0;

  static final Vector3 _defaultLightDirection = Vector3(0.35, 0.7, -1)
    ..normalize();

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

  static Future<_BedrockTextureBytes?> _loadTextureBytes(ui.Image image) {
    final Future<_BedrockTextureBytes?>? cached = _textureBytesCache[image];
    if (cached != null) {
      return cached;
    }

    final Future<_BedrockTextureBytes?> future = () async {
      try {
        final ByteData? data = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (data == null) {
          return null;
        }
        return _BedrockTextureBytes(
          rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          width: image.width,
          height: image.height,
        );
      } catch (_) {
        return null;
      }
    }();

    _textureBytesCache[image] = future;
    unawaited(
      future.then((value) {
        if (value == null) {
          _textureBytesCache[image] = null;
        }
      }),
    );
    return future;
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
        oldWidget.toneMap != widget.toneMap ||
        oldWidget.enableSelfShadow != widget.enableSelfShadow ||
        oldWidget.selfShadowStrength != widget.selfShadowStrength ||
        oldWidget.selfShadowMapSize != widget.selfShadowMapSize ||
        oldWidget.selfShadowBias != widget.selfShadowBias ||
        oldWidget.selfShadowSlopeBias != widget.selfShadowSlopeBias ||
        oldWidget.selfShadowPcfRadius != widget.selfShadowPcfRadius ||
        oldWidget.enableContactShadow != widget.enableContactShadow ||
        oldWidget.contactShadowStrength != widget.contactShadowStrength ||
        oldWidget.contactShadowBlurRadius != widget.contactShadowBlurRadius ||
        oldWidget.contactShadowDepthEpsilon !=
            widget.contactShadowDepthEpsilon ||
        oldWidget.lightFollowsCamera != widget.lightFollowsCamera ||
        oldWidget.showGround != widget.showGround ||
        oldWidget.groundY != widget.groundY ||
        oldWidget.alignModelToGround != widget.alignModelToGround ||
        oldWidget.groundColor != widget.groundColor ||
        oldWidget.showGroundShadow != widget.showGroundShadow ||
        oldWidget.groundShadowStrength != widget.groundShadowStrength ||
        oldWidget.groundShadowBlurRadius != widget.groundShadowBlurRadius ||
        oldWidget.groundShadowIntoAlpha != widget.groundShadowIntoAlpha ||
        oldWidget.renderKey != widget.renderKey;
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

  Future<void> _renderFrame(int generation) async {
    final int renderKey = widget.renderKey;
    try {
      await this._ensureTextureBytes(generation);
      if (!mounted || generation != _renderGeneration) {
        return;
      }

      this._ensureBuffers(_renderWidth, _renderHeight);
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

      final BedrockMesh mesh = this._buildMeshForFrame();
      this._renderSceneToBuffers(
        mesh: mesh,
        colorBuffer: colorBuffer,
        colorBuffer32: color32,
        depthBuffer: depthBuffer,
        width: _renderWidth,
        height: _renderHeight,
        textureRgba: _textureRgba,
        textureWidth: _textureWidth,
        textureHeight: _textureHeight,
        shadowMask: _shadowMask,
        shadowMaskScratch: _shadowMaskScratch,
      );

      final ui.Image image = await this._decodeRgbaImage(
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
      widget.onRendered?.call(renderKey);
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth;
        final double maxHeight = constraints.maxHeight;
        if (!maxWidth.isFinite ||
            !maxHeight.isFinite ||
            maxWidth <= 0 ||
            maxHeight <= 0) {
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
