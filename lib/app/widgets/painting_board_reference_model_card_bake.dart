part of 'painting_board.dart';

enum _ReferenceModelBakeRendererPreset {
  normal,
  cinematic,
  cycles,
}

extension _ReferenceModelBakeRendererPresetLabel
    on _ReferenceModelBakeRendererPreset {
  String get label {
    return switch (this) {
      _ReferenceModelBakeRendererPreset.normal => '普通（快速）',
      _ReferenceModelBakeRendererPreset.cinematic => '电影（宣传片）',
      _ReferenceModelBakeRendererPreset.cycles => '写实（Cycles）',
    };
  }

  bool get usesBakedLighting => this != _ReferenceModelBakeRendererPreset.normal;
}

class _ReferenceModelBakeResolutionPreset {
  const _ReferenceModelBakeResolutionPreset({
    required this.label,
    required this.width,
    required this.height,
  });

  final String label;
  final int width;
  final int height;
}

const List<_ReferenceModelBakeResolutionPreset>
_kReferenceModelBakeResolutionPresets = <_ReferenceModelBakeResolutionPreset>[
  _ReferenceModelBakeResolutionPreset(label: '1280 × 720 (HD)', width: 1280, height: 720),
  _ReferenceModelBakeResolutionPreset(label: '1920 × 1080 (Full HD)', width: 1920, height: 1080),
  _ReferenceModelBakeResolutionPreset(label: '2560 × 1440 (QHD)', width: 2560, height: 1440),
  _ReferenceModelBakeResolutionPreset(label: '3840 × 2160 (4K)', width: 3840, height: 2160),
];

class _ReferenceModelBakeLighting {
  const _ReferenceModelBakeLighting({
    required this.lightDirection,
    required this.ambient,
    required this.diffuse,
    required this.sunColor,
    required this.skyColor,
    required this.groundBounceColor,
    required this.specularStrength,
    required this.roughness,
    required this.exposure,
    required this.background,
    required this.shadowStrength,
    required this.shadowBlurRadius,
  });

  final Vector3 lightDirection;
  final double ambient;
  final double diffuse;
  final Color sunColor;
  final Color skyColor;
  final Color groundBounceColor;
  final double specularStrength;
  final double roughness;
  final double exposure;
  final Color background;
  final double shadowStrength;
  final int shadowBlurRadius;
}

class _ReferenceModelBakeSkyboxBackground extends StatelessWidget {
  const _ReferenceModelBakeSkyboxBackground({
    required this.timeHours,
    required this.lighting,
    required this.isDark,
  });

  final double timeHours;
  final _ReferenceModelBakeLighting lighting;
  final bool isDark;

  static double _smoothstep(double edge0, double edge1, double x) {
    final double t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  static double _dayBlend(double timeHours) {
    final double normalized = timeHours.isFinite
        ? (timeHours % 24 + 24) % 24
        : 12.0;
    final double dayPhase = ((normalized - 6.0) / 12.0) * math.pi;
    final double sunHeight = math.sin(dayPhase).clamp(-1.0, 1.0).toDouble();
    return _smoothstep(-0.35, 0.15, sunHeight);
  }

  @override
  Widget build(BuildContext context) {
    final double dayBlend = _dayBlend(timeHours);
    final Color zenith = lighting.skyColor;
    final Color horizonTint =
        Color.lerp(zenith, lighting.sunColor, 0.16 + 0.18 * dayBlend) ?? zenith;
    final double whiteMix = isDark
        ? (0.05 + 0.18 * dayBlend).clamp(0.0, 0.28)
        : (0.18 + 0.52 * dayBlend).clamp(0.0, 0.82);
    final Color horizon =
        Color.lerp(horizonTint, const Color(0xFFFFFFFF), whiteMix) ??
            horizonTint;

    final Color cloudBase =
        Color.lerp(zenith, const Color(0xFFFFFFFF), isDark ? 0.18 : 0.55) ??
            const Color(0xFFFFFFFF);
    final Color cloudColor =
        Color.lerp(cloudBase, lighting.sunColor, 0.06 + 0.18 * dayBlend) ??
            cloudBase;
    final double cloudOpacity =
        (0.08 + 0.34 * dayBlend) * (isDark ? 0.65 : 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[zenith, horizon],
            ),
          ),
        ),
        CustomPaint(
          painter: _ReferenceModelBakeCloudPainter(
            seed: 1337,
            color: cloudColor,
            opacity: cloudOpacity,
          ),
        ),
      ],
    );
  }
}

class _ReferenceModelBakeCloudPainter extends CustomPainter {
  const _ReferenceModelBakeCloudPainter({
    required this.seed,
    required this.color,
    required this.opacity,
  });

  final int seed;
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || size.isEmpty) {
      return;
    }

    final math.Random random = math.Random(seed);
    final double blurSigma =
        (size.shortestSide * 0.035).clamp(6.0, 36.0).toDouble();
    final Paint paint = Paint()
      ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0).toDouble())
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blurSigma);

    const int cloudGroups = 10;
    for (int i = 0; i < cloudGroups; i++) {
      final double cx = (random.nextDouble() * 1.2 - 0.1) * size.width;
      final double cy = (0.06 + random.nextDouble() * 0.52) * size.height;
      final double base = (0.10 + random.nextDouble() * 0.14) * size.width;
      final int blobs = 6 + random.nextInt(4);

      for (int j = 0; j < blobs; j++) {
        final double dx = (random.nextDouble() - 0.5) * base * 0.65;
        final double dy = (random.nextDouble() - 0.5) * base * 0.18;
        final double r = base * (0.30 + random.nextDouble() * 0.22);
        canvas.drawCircle(Offset(cx + dx, cy + dy), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ReferenceModelBakeCloudPainter oldDelegate) {
    return seed != oldDelegate.seed ||
        color != oldDelegate.color ||
        opacity != oldDelegate.opacity;
  }
}

extension _ReferenceModelCardStateBakeDialog on _ReferenceModelCardState {
  Future<void> _showBakeDialogImpl() async {
    if (!mounted) {
      return;
    }

    final BuildContext dialogContext = widget.dialogContext;
    final OverlayState? overlay = Overlay.maybeOf(dialogContext, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    ui.Image? bakeTexture;
    final ui.Image? sourceTexture = widget.texture;
    if (sourceTexture != null && !sourceTexture.debugDisposed) {
      final _BedrockTextureBytes? bytes =
          await _BedrockModelZBufferViewState._loadTextureBytes(sourceTexture);
      if (!mounted) {
        return;
      }
      if (bytes != null) {
        final Completer<ui.Image> textureCompleter = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          bytes.rgba,
          bytes.width,
          bytes.height,
          ui.PixelFormat.rgba8888,
          textureCompleter.complete,
        );
        bakeTexture = await textureCompleter.future;
        if (!mounted) {
          if (!bakeTexture.debugDisposed) {
            bakeTexture.dispose();
          }
          return;
        }
        _BedrockModelZBufferViewState._textureBytesCache[bakeTexture] =
            Future<_BedrockTextureBytes?>.value(bytes);
      }
    }

    final GlobalKey previewKey = GlobalKey();
    final GlobalKey<_BedrockModelZBufferViewState> previewModelKey =
        GlobalKey<_BedrockModelZBufferViewState>();

    double previewYaw = _yaw;
    double previewPitch = _pitch;
    double previewZoom = _zoom;
    double previewZoomScaleStart = previewZoom;

    double timeHours = 12.0;
    bool isBaking = false;
    _ReferenceModelBakeRendererPreset rendererPreset =
        _ReferenceModelBakeRendererPreset.cinematic;

    _ReferenceModelBakeResolutionPreset? resolutionPreset =
        _kReferenceModelBakeResolutionPresets[1];
    final TextEditingController widthController = TextEditingController(
      text: resolutionPreset.width.toString(),
    );
    final TextEditingController heightController = TextEditingController(
      text: resolutionPreset.height.toString(),
    );

    int previewRenderKey = 0;

    void markPreviewDirty() {
      previewRenderKey += 1;
    }

    OverlayEntry? dialogEntry;
    Completer<void>? dialogCompleter;

    void closeDialog() {
      if (isBaking) {
        return;
      }
      dialogEntry?.remove();
      dialogEntry = null;
      dialogCompleter?.complete();
      dialogCompleter = null;
    }

    ({int width, int height})? parseAndValidateResolution(
      BuildContext context, {
      required String widthText,
      required String heightText,
    }) {
      final int? targetWidth = int.tryParse(widthText.trim());
      final int? targetHeight = int.tryParse(heightText.trim());
      if (targetWidth == null ||
          targetHeight == null ||
          targetWidth <= 0 ||
          targetHeight <= 0) {
        AppNotifications.show(
          context,
          message: '分辨率无效：请输入合法的宽高像素值',
          severity: InfoBarSeverity.error,
        );
        return null;
      }
      if (targetWidth > 8192 || targetHeight > 8192) {
        AppNotifications.show(
          context,
          message: '分辨率过大：单边最大支持 8192px',
          severity: InfoBarSeverity.error,
        );
        return null;
      }
      if (targetWidth * targetHeight > 16000000) {
        AppNotifications.show(
          context,
          message: '分辨率过大：总像素建议不超过 1600 万（例如 4K）',
          severity: InfoBarSeverity.error,
        );
        return null;
      }
      return (width: targetWidth, height: targetHeight);
    }

    Future<bool> editCustomResolution(BuildContext context) async {
      final TextEditingController customWidthController = TextEditingController(
        text: widthController.text.trim(),
      );
      final TextEditingController customHeightController = TextEditingController(
        text: heightController.text.trim(),
      );

      try {
        final ({int width, int height})? result =
            await showMisarinDialog<({int width, int height})>(
          context: context,
          title: const Text('自定义分辨率'),
          contentWidth: 360,
          maxWidth: 420,
          barrierDismissible: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InfoLabel(
                label: '宽度 (px)',
                child: TextFormBox(
                  controller: customWidthController,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
              ),
              const SizedBox(height: 12),
              InfoLabel(
                label: '高度 (px)',
                child: TextFormBox(
                  controller: customHeightController,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '提示：单边最大 8192px，总像素建议不超过 1600 万。',
              ),
            ],
          ),
          actions: [
            Button(
              child: Text(context.l10n.cancel),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Button(
              child: const Text('确定'),
              onPressed: () {
                final ({int width, int height})? resolution =
                    parseAndValidateResolution(
                  context,
                  widthText: customWidthController.text,
                  heightText: customHeightController.text,
                );
                if (resolution == null) {
                  return;
                }
                Navigator.of(context).pop(resolution);
              },
            ),
          ],
        );

        if (result == null) {
          return false;
        }
        widthController.text = result.width.toString();
        heightController.text = result.height.toString();
        return true;
      } finally {
        customWidthController.dispose();
        customHeightController.dispose();
      }
    }

    Future<void> exportBakeResult(
      BuildContext context,
      StateSetter setDialogState,
    ) async {
      final ({int width, int height})? resolution = parseAndValidateResolution(
        context,
        widthText: widthController.text,
        heightText: heightController.text,
      );
      if (resolution == null) {
        return;
      }

      final String suggestedName = _sanitizeFileName(
        'bake_${_formatTimeForFileName(timeHours)}.png',
      );

      String? normalizedPath;
      String? downloadName;

      if (kIsWeb) {
        final String? fileName = await showWebFileNameDialog(
          context: context,
          title: '导出烘焙结果',
          suggestedFileName: suggestedName,
          description: context.l10n.webDownloadDesc,
          confirmLabel: context.l10n.download,
        );
        if (fileName == null) {
          return;
        }
        downloadName = _ensurePngExtension(_sanitizeFileName(fileName));
      } else {
        final String? outputPath = await FilePicker.platform.saveFile(
          dialogTitle: '导出烘焙结果',
          fileName: suggestedName,
          type: FileType.custom,
          allowedExtensions: const <String>['png'],
        );
        if (outputPath == null) {
          return;
        }
        normalizedPath = _ensurePngExtension(outputPath);
      }

      try {
        setDialogState(() {
          isBaking = true;
          markPreviewDirty();
        });

        await Future<void>.delayed(const Duration(milliseconds: 16));
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || !context.mounted) {
          return;
        }

        final _BedrockModelZBufferViewState? rendererState =
            previewModelKey.currentState;
        if (rendererState == null) {
          throw StateError('无法获取模型渲染器');
        }

        final FluentThemeData theme = FluentTheme.of(context);
        final Color normalBackground = theme.brightness.isDark
            ? const Color(0xFF101010)
            : const Color(0xFFF7F7F7);
        final bool usesBakedLighting = rendererPreset.usesBakedLighting;
        final _ReferenceModelBakeLighting? lighting = usesBakedLighting
            ? _lightingForTime(timeHours, isDark: theme.brightness.isDark)
            : null;
        final Color exportBackground = lighting?.background ?? normalBackground;
        final _BedrockSkyboxBackground? skybox = usesBakedLighting && lighting != null
            ? _BedrockSkyboxBackground(
                timeHours: timeHours,
                isDark: theme.brightness.isDark,
                skyColor: lighting.skyColor,
                sunColor: lighting.sunColor,
              )
            : null;

        final Uint8List bytes = await rendererState.renderPngBytes(
          width: resolution.width,
          height: resolution.height,
          background: exportBackground,
          skybox: skybox,
        );
        if (kIsWeb) {
          await WebFileSaver.saveBytes(
            fileName: downloadName!,
            bytes: bytes,
            mimeType: 'image/png',
          );
        } else {
          final File file = File(normalizedPath!);
          await file.writeAsBytes(bytes, flush: true);
        }

        if (!mounted || !context.mounted) {
          return;
        }
        AppNotifications.show(
          context,
          message: kIsWeb ? '已下载：$downloadName' : '已导出：$normalizedPath',
          severity: InfoBarSeverity.success,
        );
      } catch (error) {
        if (!mounted || !context.mounted) {
          return;
        }
        AppNotifications.show(
          context,
          message: '导出失败：$error',
          severity: InfoBarSeverity.error,
        );
      } finally {
        if (mounted) {
          setDialogState(() {
            isBaking = false;
          });
        }
      }
    }

    final Completer<void> completer = Completer<void>();
    dialogCompleter = completer;
    dialogEntry = OverlayEntry(
      builder: (BuildContext overlayContext) {
        return HeroControllerScope.none(
          child: Navigator(
          onGenerateRoute: (settings) => PageRouteBuilder<void>(
            settings: settings,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (context, animation, secondaryAnimation) {
              final Color barrierColor = Colors.black.withValues(alpha: 0.35);
              return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!isBaking) {
                  closeDialog();
                }
              },
              child: ColoredBox(color: barrierColor),
            ),
            Center(
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setDialogState) {
                  final FluentThemeData theme = FluentTheme.of(context);
                  final Color border =
                      theme.resources.controlStrokeColorDefault;
                  final Color normalBackground = theme.brightness.isDark
                      ? const Color(0xFF101010)
                      : const Color(0xFFF7F7F7);

                  final _ReferenceModelBakeLighting? lighting =
                      rendererPreset.usesBakedLighting
                      ? _lightingForTime(
                          timeHours,
                          isDark: theme.brightness.isDark,
                        )
                      : null;
                  final Color previewBackground =
                      lighting?.background ?? normalBackground;

                  Widget buildModelPreview() {
                    final double groundY = widget.modelMesh.mesh.boundsMin.y;
                    final bool usesBakedLighting =
                        rendererPreset.usesBakedLighting;
                    final _ReferenceModelBakeLighting? bakedLighting = lighting;
                    final bool isCinematic = rendererPreset ==
                        _ReferenceModelBakeRendererPreset.cinematic;
                    final bool isCycles =
                        rendererPreset == _ReferenceModelBakeRendererPreset.cycles;

                    final double specularStrength = usesBakedLighting
                        ? (isCycles
                              ? bakedLighting!.specularStrength * 0.65
                              : bakedLighting!.specularStrength)
                        : 0.25;
                    final double roughness = usesBakedLighting
                        ? (isCycles ? 0.68 : bakedLighting!.roughness)
                        : 0.55;
                    final double exposure = usesBakedLighting
                        ? (isCinematic
                              ? bakedLighting!.exposure * 1.05
                              : bakedLighting!.exposure)
                        : 1.0;

                    final bool enableSelfShadow = usesBakedLighting;
                    final int shadowMapSize = isCinematic ? 2048 : 1024;
                    final int shadowPcfRadius = isCycles ? 3 : 0;

                    final bool enableContactShadow = usesBakedLighting;
                    final double contactShadowStrength =
                        isCinematic ? 0.22 : 0.14;
                    final int contactShadowBlurRadius = isCinematic
                        ? 0
                        : (isCycles ? 4 : 2);
                    const double contactShadowDepthEpsilon = 0.012;
                    final int groundShadowBlurRadius = usesBakedLighting
                        ? (isCinematic
                              ? 0
                              : (isCycles
                                    ? (bakedLighting!.shadowBlurRadius + 2)
                                        .clamp(0, 10)
                                        .toInt()
                                    : bakedLighting!.shadowBlurRadius))
                        : 0;
                    final Widget model = _BedrockModelZBufferView(
                      key: previewModelKey,
                      baseModel: widget.modelMesh,
                      modelTextureWidth: widget.modelMesh.model.textureWidth,
                      modelTextureHeight: widget.modelMesh.model.textureHeight,
                      texture: bakeTexture ?? widget.texture,
                      yaw: previewYaw,
                      pitch: previewPitch,
                      zoom: previewZoom,
                      animation: _selectedAnimation,
                      animationController: _actionController,
                      lightDirection:
                          usesBakedLighting ? bakedLighting!.lightDirection : null,
                      ambient: usesBakedLighting ? bakedLighting!.ambient : 0.55,
                      diffuse: usesBakedLighting ? bakedLighting!.diffuse : 0.45,
                      sunColor: usesBakedLighting
                          ? bakedLighting!.sunColor
                          : const Color(0xFFFFFFFF),
                      skyColor: usesBakedLighting
                          ? bakedLighting!.skyColor
                          : const Color(0xFFBFD9FF),
                      groundBounceColor: usesBakedLighting
                          ? bakedLighting!.groundBounceColor
                          : const Color(0xFFFFFFFF),
                      specularStrength: specularStrength,
                      roughness: roughness,
                      exposure: exposure,
                      toneMap: usesBakedLighting,
                      enableSelfShadow: enableSelfShadow,
                      selfShadowStrength: 1.0,
                      selfShadowMapSize: shadowMapSize,
                      selfShadowBias: isCycles ? 0.03 : 0.02,
                      selfShadowSlopeBias: isCycles ? 0.05 : 0.04,
                      selfShadowPcfRadius: shadowPcfRadius,
                      enableContactShadow: enableContactShadow,
                      contactShadowStrength: contactShadowStrength,
                      contactShadowBlurRadius: contactShadowBlurRadius,
                      contactShadowDepthEpsilon: contactShadowDepthEpsilon,
                      lightFollowsCamera: !usesBakedLighting,
                      showGround: usesBakedLighting,
                      groundY: groundY,
                      alignModelToGround: false,
                      groundColor: Colors.white,
                      showGroundShadow: usesBakedLighting,
                      groundShadowStrength: usesBakedLighting
                          ? bakedLighting!.shadowStrength
                          : 0.0,
                      groundShadowBlurRadius: groundShadowBlurRadius,
                      renderKey: previewRenderKey,
                    );

                    Widget interactive = Listener(
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent) {
                          setDialogState(() {
                            markPreviewDirty();
                            previewZoom =
                                (previewZoom - event.scrollDelta.dy * 0.002)
                                    .clamp(0.35, 6.0);
                          });
                        }
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onDoubleTap: () {
                          setDialogState(() {
                            markPreviewDirty();
                            previewYaw = 0;
                            previewPitch = 0;
                            previewZoom = 1.0;
                          });
                        },
                        onScaleStart: (_) =>
                            previewZoomScaleStart = previewZoom,
                        onScaleUpdate: (details) {
                          setDialogState(() {
                            markPreviewDirty();
                            final double scaleDelta = details.scale - 1.0;
                            if (scaleDelta.abs() > 0.001) {
                              previewZoom =
                                  (previewZoomScaleStart * details.scale).clamp(
                                    0.35,
                                    6.0,
                                  );
                              return;
                            }
                            previewYaw -= details.focalPointDelta.dx * 0.01;
                            previewPitch =
                                (previewPitch -
                                        details.focalPointDelta.dy * 0.01)
                                    .clamp(-math.pi / 2, math.pi / 2);
                          });
                        },
                        child: model,
                      ),
                    );

                    return IgnorePointer(
                      ignoring: isBaking,
                      child: interactive,
                    );
                  }

                  Widget buildPreviewArea() {
                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          RepaintBoundary(
                            key: previewKey,
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (rendererPreset.usesBakedLighting &&
                                      lighting != null)
                                    _ReferenceModelBakeSkyboxBackground(
                                      timeHours: timeHours,
                                      lighting: lighting,
                                      isDark: theme.brightness.isDark,
                                    )
                                  else
                                    ColoredBox(color: previewBackground),
                                  buildModelPreview(),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            bottom: 12,
                            child: HoverDetailTooltip(
                              message: '渲染器',
                              detail: rendererPreset.label,
                              child: const SizedBox.shrink(),
                            ),
                          ),
                          if (isBaking)
                            Positioned.fill(
                              child: AbsorbPointer(
                                child: ColoredBox(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  child: Center(
                                    child: SizedBox(
                                      width: 320,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          ProgressBar(value: null),
                                          SizedBox(height: 12),
                                          Text('烘焙中…'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }

                  return MisarinDialog(
                    title: Row(children: [const Text('烘焙')]),
                    contentWidth: null,
                    maxWidth: 920,
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          buildPreviewArea(),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: InfoLabel(
                                  label: '渲染器',
                                  child: ComboBox<_ReferenceModelBakeRendererPreset>(
                                    isExpanded: true,
                                    value: rendererPreset,
                                    items: _ReferenceModelBakeRendererPreset.values
                                        .map(
                                          (preset) => ComboBoxItem(
                                            value: preset,
                                            child: Text(preset.label),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: isBaking
                                        ? null
                                        : (value) {
                                            if (value == null) {
                                              return;
                                            }
                                            setDialogState(() {
                                              rendererPreset = value;
                                              markPreviewDirty();
                                            });
                                          },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InfoLabel(
                                  label: '分辨率预设',
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ComboBox<
                                            _ReferenceModelBakeResolutionPreset?>(
                                          isExpanded: true,
                                          value: resolutionPreset,
                                          items: [
                                            ComboBoxItem<
                                                _ReferenceModelBakeResolutionPreset?>(
                                              value: null,
                                              child: Text(
                                                '自定义 (${widthController.text} × ${heightController.text})',
                                              ),
                                            ),
                                            ..._kReferenceModelBakeResolutionPresets
                                                .map(
                                              (preset) => ComboBoxItem<
                                                  _ReferenceModelBakeResolutionPreset?>(
                                                value: preset,
                                                child: Text(preset.label),
                                              ),
                                            ),
                                          ],
                                          onChanged: isBaking
                                              ? null
                                              : (value) async {
                                                  if (value != null) {
                                                    setDialogState(() {
                                                      resolutionPreset = value;
                                                      widthController.text =
                                                          value.width.toString();
                                                      heightController.text =
                                                          value.height.toString();
                                                    });
                                                    return;
                                                  }

                                                  final _ReferenceModelBakeResolutionPreset?
                                                      previousPreset =
                                                      resolutionPreset;
                                                  final String previousWidth =
                                                      widthController.text;
                                                  final String previousHeight =
                                                      heightController.text;

                                                  final bool updated =
                                                      await editCustomResolution(
                                                    context,
                                                  );
                                                  if (!mounted) {
                                                    return;
                                                  }

                                                  setDialogState(() {
                                                    if (updated) {
                                                      resolutionPreset = null;
                                                    } else {
                                                      resolutionPreset =
                                                          previousPreset;
                                                      widthController.text =
                                                          previousWidth;
                                                      heightController.text =
                                                          previousHeight;
                                                    }
                                                  });
                                                },
                                        ),
                                      ),
                                      if (resolutionPreset == null) ...[
                                        const SizedBox(width: 8),
                                        Button(
                                          onPressed: isBaking
                                              ? null
                                              : () async {
                                                  final bool updated =
                                                      await editCustomResolution(
                                                    context,
                                                  );
                                                  if (!mounted) {
                                                    return;
                                                  }
                                                  if (!updated) {
                                                    return;
                                                  }
                                                  setDialogState(() {});
                                                },
                                          child: const Text('设置…'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text('时间'),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Slider(
                                  value: timeHours.clamp(0, 24),
                                  min: 0,
                                  max: 24,
                                  divisions: 96,
                                  onChanged: isBaking ||
                                          !rendererPreset.usesBakedLighting
                                      ? null
                                      : (value) {
                                          setDialogState(() {
                                            timeHours = value;
                                            markPreviewDirty();
                                          });
                                        },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _formatTimeForDisplay(timeHours),
                                style: theme.typography.bodyStrong,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      Button(
                        onPressed: isBaking ? null : closeDialog,
                        child: Text(dialogContext.l10n.cancel),
                      ),
                      Button(
                        onPressed: isBaking
                            ? null
                            : () => exportBakeResult(context, setDialogState),
                        child: const Text('导出'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
            },
          ),
          ),
        );
      },
    );

    overlay.insert(dialogEntry!);
    try {
      await completer.future;
    } finally {
      closeDialog();
      widthController.dispose();
      heightController.dispose();
      if (bakeTexture != null && !bakeTexture.debugDisposed) {
        bakeTexture.dispose();
      }
    }
  }

  static _ReferenceModelBakeLighting _lightingForTime(
    double timeHours, {
    required bool isDark,
  }) {
    final double normalized = timeHours.isFinite
        ? (timeHours % 24 + 24) % 24
        : 12.0;

    final double azimuth = (normalized / 24.0) * math.pi * 2.0;
    final double dayPhase = ((normalized - 6.0) / 12.0) * math.pi;
    final double sunHeight = math.sin(dayPhase).clamp(-1.0, 1.0).toDouble();
    final double daylight = sunHeight.clamp(0.0, 1.0).toDouble();
    final double night = (-sunHeight).clamp(0.0, 1.0).toDouble();

    double pow01(double value, double power) {
      if (value <= 0) {
        return 0.0;
      }
      if (value >= 1) {
        return 1.0;
      }
      return math.pow(value, power).toDouble();
    }

    double smoothstep(double edge0, double edge1, double x) {
      final double t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
      return t * t * (3.0 - 2.0 * t);
    }

    double lerpDouble(double a, double b, double t) {
      return a + (b - a) * t;
    }

    final double dayBlend = smoothstep(-0.35, 0.15, sunHeight);

    final double sunStrength = pow01(daylight, 1.25);
    final double sunContrast = pow01(daylight, 2.0);
    final double moonStrength = pow01(night, 1.10);
    final double moonContrast = pow01(night, 1.60);

    final Vector3 sunDir = Vector3(
      math.cos(azimuth),
      0.08 + 0.92 * daylight,
      -math.sin(azimuth),
    )..normalize();
    final double moonAzimuth = azimuth + math.pi;
    final Vector3 moonDir = Vector3(
      math.cos(moonAzimuth),
      0.10 + 0.90 * night,
      -math.sin(moonAzimuth),
    )..normalize();

    final Vector3 light = Vector3(
      moonDir.x + (sunDir.x - moonDir.x) * dayBlend,
      moonDir.y + (sunDir.y - moonDir.y) * dayBlend,
      moonDir.z + (sunDir.z - moonDir.z) * dayBlend,
    );
    if (light.length2 > 1e-9) {
      light.normalize();
    } else {
      light.setFrom(sunDir);
    }

    final double ambientDay = lerpDouble(
      isDark ? 0.32 : 0.28,
      isDark ? 0.14 : 0.10,
      sunContrast,
    ).clamp(0.08, 0.36);
    final double diffuseDay =
        lerpDouble(0.08, 0.95, sunStrength).clamp(0.0, 0.95);

    final double ambientNight = lerpDouble(
      isDark ? 0.18 : 0.16,
      isDark ? 0.26 : 0.20,
      moonContrast,
    ).clamp(0.08, 0.36);
    final double diffuseNight =
        lerpDouble(0.03, 0.08, moonStrength).clamp(0.0, 0.25);

    final double ambient =
        lerpDouble(ambientNight, ambientDay, dayBlend).clamp(0.0, 1.0);
    final double diffuse =
        lerpDouble(diffuseNight, diffuseDay, dayBlend).clamp(0.0, 1.0);

    final Color sunWarm = const Color(0xFFFFA36D);
    final Color sunNeutral = const Color(0xFFFFFFFF);
    final double sunTintT = math.sqrt(daylight);
    final Color sunColor =
        Color.lerp(sunWarm, sunNeutral, sunTintT) ?? sunNeutral;

    final Color moonColor = const Color(0xFFB8CFFF);
    final Color directionalColor =
        Color.lerp(moonColor, sunColor, dayBlend) ?? sunColor;

    final Color daySky = isDark
        ? const Color(0xFF2D4461)
        : const Color(0xFFBFD9FF);
    final Color starSky = isDark
        ? const Color(0xFF0A1222)
        : const Color(0xFF121826);
    final Color moonSky = isDark
        ? const Color(0xFF22344F)
        : const Color(0xFF324A6B);
    final Color nightSky = Color.lerp(starSky, moonSky, moonStrength) ?? moonSky;
    final Color skyColor =
        Color.lerp(nightSky, daySky, dayBlend) ?? daySky;

    const Color dayBounce = Color(0xFFD8D8D8);
    final Color nightBounceBase = isDark
        ? const Color(0xFF111A2A)
        : const Color(0xFF151C2A);
    final Color nightBounceMoon = isDark
        ? const Color(0xFF263651)
        : const Color(0xFF2E405E);
    final Color nightBounce =
        Color.lerp(nightBounceBase, nightBounceMoon, moonStrength) ??
            nightBounceMoon;
    final Color groundBounceColor =
        Color.lerp(nightBounce, dayBounce, dayBlend) ?? dayBounce;

    final double specDay =
        (0.12 + (0.58 - 0.12) * sunStrength).clamp(0.0, 0.7);
    final double specNight =
        (0.05 + (0.18 - 0.05) * moonStrength).clamp(0.0, 0.4);
    final double specularStrength =
        (specNight + (specDay - specNight) * dayBlend).clamp(0.0, 1.0);

    final double roughnessDay = 0.55;
    final double roughnessNight = 0.60;
    final double roughness = (roughnessNight +
            (roughnessDay - roughnessNight) * dayBlend)
        .clamp(0.0, 1.0);

    final double exposureDay =
        (1.05 + (0.95 - 1.05) * sunStrength).clamp(0.85, 1.25);
    final double exposureNight =
        (1.18 + (1.12 - 1.18) * moonStrength).clamp(0.85, 1.40);
    final double exposure =
        (exposureNight + (exposureDay - exposureNight) * dayBlend)
            .clamp(0.75, 1.70);

    final double shadowStrengthDay =
        (0.25 + (0.85 - 0.25) * sunStrength).clamp(0.0, 0.9);
    final double shadowStrengthNight =
        (0.08 + (0.32 - 0.08) * moonStrength).clamp(0.0, 0.6);
    final double shadowStrength =
        (shadowStrengthNight + (shadowStrengthDay - shadowStrengthNight) * dayBlend)
            .clamp(0.0, 0.85);

    int lerpInt(int a, int b, double t) {
      return (a + (b - a) * t).round();
    }

    final int shadowBlurDay = lerpInt(6, 2, sunStrength).clamp(1, 6);
    final int shadowBlurNight = lerpInt(7, 3, moonStrength).clamp(1, 6);
    final int shadowBlurRadius =
        lerpInt(shadowBlurNight, shadowBlurDay, dayBlend).clamp(1, 6);

    final Color dayBackground = isDark
        ? const Color(0xFF101010)
        : const Color(0xFFF7F7F7);
    final Color starBackground = isDark
        ? const Color(0xFF050505)
        : const Color(0xFFE7E7E7);
    final Color moonBackground = isDark
        ? const Color(0xFF070A12)
        : const Color(0xFFE7E7E7);
    final Color nightBackground =
        Color.lerp(starBackground, moonBackground, moonStrength) ??
            moonBackground;
    final Color background =
        Color.lerp(nightBackground, dayBackground, dayBlend) ?? dayBackground;

    return _ReferenceModelBakeLighting(
      lightDirection: light,
      ambient: ambient,
      diffuse: diffuse,
      sunColor: directionalColor,
      skyColor: skyColor,
      groundBounceColor: groundBounceColor,
      specularStrength: specularStrength,
      roughness: roughness,
      exposure: exposure,
      background: background,
      shadowStrength: shadowStrength,
      shadowBlurRadius: shadowBlurRadius,
    );
  }

  static String _formatTimeForDisplay(double timeHours) {
    final double normalized = timeHours.isFinite
        ? (timeHours % 24 + 24) % 24
        : 12.0;
    final int hour = normalized.floor();
    int minute = ((normalized - hour) * 60).round();
    int hourAdjusted = hour;
    if (minute >= 60) {
      minute = 0;
      hourAdjusted = (hourAdjusted + 1) % 24;
    }
    return '${hourAdjusted.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static String _formatTimeForFileName(double timeHours) {
    return _formatTimeForDisplay(timeHours).replaceAll(':', '-');
  }

  static String _ensurePngExtension(String path) {
    if (p.extension(path).toLowerCase() == '.png') {
      return path;
    }
    return p.setExtension(path, '.png');
  }

  static String _sanitizeFileName(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'bake.png';
    }
    return trimmed.replaceAll(RegExp(r'[\\\\/:*?"<>|]+'), '_');
  }
}
