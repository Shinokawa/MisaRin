part of 'painting_board.dart';

extension _BedrockModelZBufferViewStateRender on _BedrockModelZBufferViewState {
  void _renderSceneToBuffers({
    required BedrockMesh mesh,
    required Uint8List colorBuffer,
    required Uint32List? colorBuffer32,
    required Float32List depthBuffer,
    required int width,
    required int height,
    required Uint8List? textureRgba,
    required int textureWidth,
    required int textureHeight,
    Uint8List? shadowMask,
    Uint8List? shadowMaskScratch,
    Float32List? selfShadowDepthBuffer,
  }) {
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
        (widget.lightDirection ??
                _BedrockModelZBufferViewState._defaultLightDirection)
            .clone();
    if (lightDir.length2 <= 0) {
      lightDir.setFrom(_BedrockModelZBufferViewState._defaultLightDirection);
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
        colorBuffer32: colorBuffer32,
        depthBuffer: depthBuffer,
        width: width,
        height: height,
        modelExtent: modelSize,
        yaw: widget.yaw,
        pitch: widget.pitch,
        zoom: widget.zoom,
        lightDirection: lightDir,
        ambient: widget.ambient,
        diffuse: widget.diffuse,
        sunColor: widget.sunColor,
        skyColor: widget.skyColor,
        groundBounceColor: widget.groundBounceColor,
        specularStrength: widget.specularStrength,
        roughness: widget.roughness,
        exposure: widget.exposure,
        toneMap: widget.toneMap,
        lightFollowsCamera: widget.lightFollowsCamera,
        textureRgba: null,
        textureWidth: 0,
        textureHeight: 0,
        modelTextureWidth: 0,
        modelTextureHeight: 0,
        untexturedBaseColor: widget.groundColor,
      );

      if (widget.showGroundShadow) {
        final Uint8List? mask = shadowMask;
        final Uint8List? scratch = shadowMaskScratch;
        if (mask != null && scratch != null) {
          mask.fillRange(0, mask.length, 0);
          _rasterizePlanarShadowMask(
            mesh: mesh,
            mask: mask,
            depthBuffer: depthBuffer,
            width: width,
            height: height,
            modelExtent: modelSize,
            yaw: widget.yaw,
            pitch: widget.pitch,
            zoom: widget.zoom,
            lightDirection: lightDir,
            lightFollowsCamera: widget.lightFollowsCamera,
            groundY: groundYLocal,
            translateY: modelYOffset,
            textureRgba: textureRgba,
            textureWidth: textureWidth,
            textureHeight: textureHeight,
            modelTextureWidth: widget.modelTextureWidth,
            modelTextureHeight: widget.modelTextureHeight,
            alphaCutoff: 1,
          );
          final int blurRadius = widget.groundShadowBlurRadius;
          if (blurRadius > 0) {
            _blurMask(
              mask: mask,
              scratch: scratch,
              width: width,
              height: height,
              radius: blurRadius,
            );
          }
          _applyShadowMask(
            colorBuffer: colorBuffer,
            colorBuffer32: colorBuffer32,
            depthBuffer: depthBuffer,
            mask: mask,
            strength: widget.groundShadowStrength,
          );
        }
      }
    }

    if (widget.toneMap && widget.showGround && extentScalar > 0) {
      final double groundHalfSize = math.max(extentScalar * 128, 256);
      _applyGroundDistanceFade(
        colorBuffer: colorBuffer,
        colorBuffer32: colorBuffer32,
        depthBuffer: depthBuffer,
        width: width,
        height: height,
        cameraDistance: extentScalar * 2.4,
        groundHalfSize: groundHalfSize,
      );
    }

	    final _BedrockSelfShadowMap? selfShadowMap =
	        widget.enableSelfShadow && widget.selfShadowStrength > 0
	        ? _buildSelfShadowMap(
	            mesh: mesh,
	            modelExtent: modelSize,
	            yaw: widget.yaw,
	            pitch: widget.pitch,
	            translateY: modelYOffset,
	            lightDirection: lightDir,
	            lightFollowsCamera: widget.lightFollowsCamera,
	            mapSize: widget.selfShadowMapSize,
	            ensureDepthBuffer: (size) => _ensureSelfShadowDepth(size),
	            depthBuffer: selfShadowDepthBuffer,
	            textureRgba: textureRgba,
	            textureWidth: textureWidth,
	            textureHeight: textureHeight,
            modelTextureWidth: widget.modelTextureWidth,
            modelTextureHeight: widget.modelTextureHeight,
            alphaCutoff: 1,
          )
        : null;

    _rasterizeMesh(
      mesh: mesh,
      colorBuffer: colorBuffer,
      colorBuffer32: colorBuffer32,
      depthBuffer: depthBuffer,
      width: width,
      height: height,
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
      toneMap: widget.toneMap,
      lightFollowsCamera: widget.lightFollowsCamera,
      textureRgba: textureRgba,
      textureWidth: textureWidth,
      textureHeight: textureHeight,
      modelTextureWidth: widget.modelTextureWidth,
      modelTextureHeight: widget.modelTextureHeight,
      selfShadowMap: selfShadowMap,
      selfShadowStrength: widget.selfShadowStrength,
      selfShadowBias: widget.selfShadowBias,
      selfShadowSlopeBias: widget.selfShadowSlopeBias,
      selfShadowPcfRadius: widget.selfShadowPcfRadius,
    );

    if (widget.enableContactShadow && widget.contactShadowStrength > 0) {
      final Uint8List? mask = shadowMask;
      final Uint8List? scratch = shadowMaskScratch;
      if (mask != null && scratch != null) {
        _rasterizeContactShadowMask(
          depthBuffer: depthBuffer,
          mask: mask,
          width: width,
          height: height,
          depthEpsilon: widget.contactShadowDepthEpsilon,
        );
        final int blurRadius = widget.contactShadowBlurRadius;
        if (blurRadius > 0) {
          _blurMask(
            mask: mask,
            scratch: scratch,
            width: width,
            height: height,
            radius: blurRadius,
          );
        }
        _applyShadowMask(
          colorBuffer: colorBuffer,
          colorBuffer32: colorBuffer32,
          depthBuffer: depthBuffer,
          mask: mask,
          strength: widget.contactShadowStrength,
        );
      }
    }
  }

  Future<Uint8List> renderPngBytes({
    required int width,
    required int height,
    required Color background,
    _BedrockSkyboxBackground? skybox,
  }) async {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Invalid render size: ${width}x$height');
    }

    final int pixelCount = width * height;
    final Uint8List colorBuffer = Uint8List(pixelCount * 4);
    final Uint32List? color32 = Endian.host == Endian.little
        ? colorBuffer.buffer.asUint32List(0, pixelCount)
        : null;
    final Float32List depthBuffer = Float32List(pixelCount);
    final Uint8List shadowMask = Uint8List(pixelCount);
    final Uint8List shadowMaskScratch = Uint8List(pixelCount);

    Uint8List? textureRgba;
    int textureWidth = 0;
    int textureHeight = 0;
    final ui.Image? texture = widget.texture;
    if (texture != null && !texture.debugDisposed) {
      if (identical(_textureSource, texture) && _textureRgba != null) {
        textureRgba = _textureRgba;
        textureWidth = _textureWidth;
        textureHeight = _textureHeight;
      } else {
        try {
          final _BedrockTextureBytes? bytes =
              await _BedrockModelZBufferViewState._loadTextureBytes(texture);
          if (bytes != null) {
            textureRgba = bytes.rgba;
            textureWidth = bytes.width;
            textureHeight = bytes.height;
          }
        } catch (error, stackTrace) {
          debugPrint(
            'Failed to read reference model texture for export: $error\n$stackTrace',
          );
        }
      }
    }

    final BedrockMesh mesh = _buildMeshForFrame();
    if (mesh.triangles.isEmpty) {
      final _BedrockSkyboxBackground? s = skybox;
      if (s != null) {
        try {
          final ui.FragmentProgram program = await _BakeCloudPrograms.program;
          final _BakeSkyboxPalette palette = _computeBakeSkyboxPalette(
            timeHours: s.timeHours,
            isDark: s.isDark,
            skyColor: s.skyColor,
            sunColor: s.sunColor,
          );
          final Color zenith = palette.zenith;
          final Color horizon = palette.horizon;
          final Color cloudColor = palette.cloudColor;
          final double cloudOpacity = palette.cloudOpacity;
          final double shadowStrength = palette.shaderShadowStrength;

          final ui.FragmentShader shader = program.fragmentShader()
            ..setFloat(0, width.toDouble())
            ..setFloat(1, height.toDouble())
            ..setFloat(2, s.timeHours.isFinite ? s.timeHours : 0.0)
            ..setFloat(3, s.seed.toDouble())
            ..setFloat(4, widget.yaw)
            ..setFloat(5, widget.pitch)
            ..setFloat(6, widget.zoom)
            ..setFloat(7, s.lightDirection.x)
            ..setFloat(8, s.lightDirection.y)
            ..setFloat(9, s.lightDirection.z)
            ..setFloat(10, s.sunColor.r)
            ..setFloat(11, s.sunColor.g)
            ..setFloat(12, s.sunColor.b)
            ..setFloat(13, zenith.r)
            ..setFloat(14, zenith.g)
            ..setFloat(15, zenith.b)
            ..setFloat(16, horizon.r)
            ..setFloat(17, horizon.g)
            ..setFloat(18, horizon.b)
            ..setFloat(19, cloudColor.r)
            ..setFloat(20, cloudColor.g)
            ..setFloat(21, cloudColor.b)
            ..setFloat(22, 60.0)
            ..setFloat(23, 260.0)
            ..setFloat(24, 24.0)
            ..setFloat(25, cloudOpacity.clamp(0.0, 1.0).toDouble())
            ..setFloat(26, shadowStrength.clamp(0.0, 1.0).toDouble());

          final ui.PictureRecorder recorder = ui.PictureRecorder();
          final Canvas canvas = Canvas(recorder);
          canvas.drawRect(
            Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
            Paint()..shader = shader,
          );
          final ui.Picture picture = recorder.endRecording();
          final ui.Image image = await picture.toImage(width, height);
          picture.dispose();
          try {
            final ByteData? encoded = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (encoded == null) {
              throw StateError('无法编码导出结果');
            }
            return Uint8List.fromList(
              encoded.buffer.asUint8List(
                encoded.offsetInBytes,
                encoded.lengthInBytes,
              ),
            );
          } finally {
            if (!image.debugDisposed) {
              image.dispose();
            }
          }
        } catch (error, stackTrace) {
          debugPrint('Failed to render procedural skybox: $error\n$stackTrace');
        }
      }

      if (skybox != null) {
        _compositeSkyboxBackground(
          rgba: colorBuffer,
          width: width,
          height: height,
          skybox: skybox,
          cameraYaw: widget.yaw,
          cameraPitch: widget.pitch,
          cameraZoom: widget.zoom,
        );
      } else {
        _compositeOpaqueBackground(
          rgba: colorBuffer,
          width: width,
          height: height,
          background: background,
        );
      }
      final ui.Image image = await _decodeRgbaImage(colorBuffer, width, height);
      try {
        final ByteData? encoded = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (encoded == null) {
          throw StateError('无法编码导出结果');
        }
        return Uint8List.fromList(
          encoded.buffer.asUint8List(
            encoded.offsetInBytes,
            encoded.lengthInBytes,
          ),
        );
      } finally {
        if (!image.debugDisposed) {
          image.dispose();
        }
      }
    }

    if (color32 != null) {
      color32.fillRange(0, color32.length, 0);
    } else {
      colorBuffer.fillRange(0, colorBuffer.length, 0);
    }
    depthBuffer.fillRange(0, depthBuffer.length, 0);

    Float32List? exportSelfShadowDepth;
    if (widget.enableSelfShadow && widget.selfShadowStrength > 0) {
      final int size = widget.selfShadowMapSize.clamp(64, 2048).toInt();
      exportSelfShadowDepth = Float32List(size * size);
    }

    _renderSceneToBuffers(
      mesh: mesh,
      colorBuffer: colorBuffer,
      colorBuffer32: color32,
      depthBuffer: depthBuffer,
      width: width,
      height: height,
      textureRgba: textureRgba,
      textureWidth: textureWidth,
      textureHeight: textureHeight,
      shadowMask: shadowMask,
      shadowMaskScratch: shadowMaskScratch,
      selfShadowDepthBuffer: exportSelfShadowDepth,
    );

    if (skybox != null) {
      final ui.Image modelImage = await _decodeRgbaImage(colorBuffer, width, height);
      ui.Image? finalImage;
      ui.Picture? picture;
      try {
        final ui.FragmentProgram program = await _BakeCloudPrograms.program;
        final _BedrockSkyboxBackground s = skybox;
        final _BakeSkyboxPalette palette = _computeBakeSkyboxPalette(
          timeHours: s.timeHours,
          isDark: s.isDark,
          skyColor: s.skyColor,
          sunColor: s.sunColor,
        );
        final Color zenith = palette.zenith;
        final Color horizon = palette.horizon;
        final Color cloudColor = palette.cloudColor;
        final double cloudOpacity = palette.cloudOpacity;
        final double shadowStrength = palette.shaderShadowStrength;

        final ui.FragmentShader shader = program.fragmentShader()
          ..setFloat(0, width.toDouble())
          ..setFloat(1, height.toDouble())
          ..setFloat(2, s.timeHours.isFinite ? s.timeHours : 0.0)
          ..setFloat(3, s.seed.toDouble())
          ..setFloat(4, widget.yaw)
          ..setFloat(5, widget.pitch)
          ..setFloat(6, widget.zoom)
          ..setFloat(7, s.lightDirection.x)
          ..setFloat(8, s.lightDirection.y)
          ..setFloat(9, s.lightDirection.z)
          ..setFloat(10, s.sunColor.r)
          ..setFloat(11, s.sunColor.g)
          ..setFloat(12, s.sunColor.b)
          ..setFloat(13, zenith.r)
          ..setFloat(14, zenith.g)
          ..setFloat(15, zenith.b)
          ..setFloat(16, horizon.r)
          ..setFloat(17, horizon.g)
          ..setFloat(18, horizon.b)
          ..setFloat(19, cloudColor.r)
          ..setFloat(20, cloudColor.g)
          ..setFloat(21, cloudColor.b)
          ..setFloat(22, 60.0)
          ..setFloat(23, 260.0)
          ..setFloat(24, 24.0)
          ..setFloat(25, cloudOpacity.clamp(0.0, 1.0).toDouble())
          ..setFloat(26, shadowStrength.clamp(0.0, 1.0).toDouble());

        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final Canvas canvas = Canvas(recorder);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          Paint()..shader = shader,
	        );
	        canvas.drawImage(modelImage, Offset.zero, Paint());
	        final ui.Picture recorded = recorder.endRecording();
	        picture = recorded;
	        finalImage = await recorded.toImage(width, height);
	        final ByteData? encoded = await finalImage.toByteData(
	          format: ui.ImageByteFormat.png,
	        );
        if (encoded == null) {
          throw StateError('无法编码导出结果');
        }
        return Uint8List.fromList(
          encoded.buffer.asUint8List(
            encoded.offsetInBytes,
            encoded.lengthInBytes,
          ),
        );
      } catch (error, stackTrace) {
        debugPrint(
          'Failed to render procedural skybox overlay: $error\n$stackTrace',
        );
      } finally {
        if (!modelImage.debugDisposed) {
          modelImage.dispose();
        }
        picture?.dispose();
        if (finalImage != null && !finalImage.debugDisposed) {
          finalImage.dispose();
        }
      }
    }

    if (skybox != null) {
      _compositeSkyboxBackground(
        rgba: colorBuffer,
        width: width,
        height: height,
        skybox: skybox,
        cameraYaw: widget.yaw,
        cameraPitch: widget.pitch,
        cameraZoom: widget.zoom,
      );
    } else {
      _compositeOpaqueBackground(
        rgba: colorBuffer,
        width: width,
        height: height,
        background: background,
      );
    }

    final ui.Image image = await _decodeRgbaImage(colorBuffer, width, height);
    try {
      final ByteData? encoded = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (encoded == null) {
        throw StateError('无法编码导出结果');
      }
      return Uint8List.fromList(
        encoded.buffer.asUint8List(
          encoded.offsetInBytes,
          encoded.lengthInBytes,
        ),
      );
    } finally {
      if (!image.debugDisposed) {
        image.dispose();
      }
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

    final _BedrockTextureBytes? bytes =
        await _BedrockModelZBufferViewState._loadTextureBytes(image);
    if (!mounted || generation != _renderGeneration) {
      return;
    }
    if (bytes == null) {
      _textureRgba = null;
      return;
    }
    _textureRgba = bytes.rgba;
    _textureWidth = bytes.width;
    _textureHeight = bytes.height;
  }

  BedrockMesh _buildMeshForFrame() {
    final BedrockAnimation? animation = widget.animation;
    final AnimationController? controller = widget.animationController;
    if (animation == null || controller == null) {
      return widget.baseModel.mesh;
    }

    final Duration? elapsed = controller.lastElapsedDuration;
    final double lifeTimeSeconds = elapsed == null
        ? 0
        : elapsed.inMicroseconds / 1000000.0;
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

  Future<ui.Image> _decodeRgbaImage(Uint8List bytes, int width, int height) {
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
}
