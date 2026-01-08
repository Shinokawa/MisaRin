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

extension _ReferenceModelCardStateBakeDialog on _ReferenceModelCardState {
  Future<void> _showBakeDialogImpl() async {
    if (!mounted) {
      return;
    }

    final BuildContext dialogContext = widget.dialogContext;
    final NavigatorState? navigator =
        Navigator.maybeOf(dialogContext, rootNavigator: true);
    final OverlayState? overlay =
        navigator?.overlay ?? Overlay.maybeOf(dialogContext);
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

    Future<void> exportBakeResult(
      BuildContext context,
      StateSetter setDialogState,
    ) async {
      final int? targetWidth = int.tryParse(widthController.text.trim());
      final int? targetHeight = int.tryParse(heightController.text.trim());
      if (targetWidth == null || targetHeight == null || targetWidth <= 0 || targetHeight <= 0) {
        AppNotifications.show(
          context,
          message: '分辨率无效：请输入合法的宽高像素值',
          severity: InfoBarSeverity.error,
        );
        return;
      }
      if (targetWidth > 8192 || targetHeight > 8192) {
        AppNotifications.show(
          context,
          message: '分辨率过大：单边最大支持 8192px',
          severity: InfoBarSeverity.error,
        );
        return;
      }
      if (targetWidth * targetHeight > 16000000) {
        AppNotifications.show(
          context,
          message: '分辨率过大：总像素建议不超过 1600 万（例如 4K）',
          severity: InfoBarSeverity.error,
        );
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

        final _BedrockModelZBufferViewState? rendererState =
            previewModelKey.currentState;
        if (rendererState == null) {
          throw StateError('无法获取模型渲染器');
        }

        final FluentThemeData theme = FluentTheme.of(context);
        final Color normalBackground = theme.brightness.isDark
            ? const Color(0xFF101010)
            : const Color(0xFFF7F7F7);
        final _ReferenceModelBakeLighting? lighting =
            rendererPreset.usesBakedLighting
                ? _lightingForTime(timeHours, isDark: theme.brightness.isDark)
                : null;
        final Color exportBackground = lighting?.background ?? normalBackground;

        final Uint8List bytes = await rendererState.renderPngBytes(
          width: targetWidth,
          height: targetHeight,
          background: exportBackground,
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

        if (!mounted) {
          return;
        }
        AppNotifications.show(
          context,
          message: kIsWeb ? '已下载：$downloadName' : '已导出：$normalizedPath',
          severity: InfoBarSeverity.success,
        );
      } catch (error) {
        if (!mounted) {
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
        return Navigator(
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
                  final Color accent = theme.accentColor.defaultBrushFor(
                    theme.brightness,
                  );
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
                    final int shadowMapSize = 1024;
                    final int shadowPcfRadius = isCycles ? 1 : 2;

                    final bool enableContactShadow = usesBakedLighting;
                    final double contactShadowStrength =
                        isCinematic ? 0.22 : 0.14;
                    final int contactShadowBlurRadius = isCinematic ? 4 : 2;
                    const double contactShadowDepthEpsilon = 0.012;
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
                      groundShadowBlurRadius: usesBakedLighting
                          ? bakedLighting!.shadowBlurRadius
                          : 0,
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
                            child: ColoredBox(
                              color: previewBackground,
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: buildModelPreview(),
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
                                  child: ComboBox<_ReferenceModelBakeResolutionPreset?>(
                                    isExpanded: true,
                                    value: resolutionPreset,
                                    items: [
                                      const ComboBoxItem<_ReferenceModelBakeResolutionPreset?>(
                                        value: null,
                                        child: Text('自定义'),
                                      ),
                                      ..._kReferenceModelBakeResolutionPresets.map(
                                        (preset) => ComboBoxItem<
                                          _ReferenceModelBakeResolutionPreset?
                                        >(
                                          value: preset,
                                          child: Text(preset.label),
                                        ),
                                      ),
                                    ],
                                    onChanged: isBaking
                                        ? null
                                        : (value) {
                                            setDialogState(() {
                                              resolutionPreset = value;
                                              if (value != null) {
                                                widthController.text =
                                                    value.width.toString();
                                                heightController.text =
                                                    value.height.toString();
                                              }
                                            });
                                          },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          InfoLabel(
                            label: '输出分辨率 (px)',
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormBox(
                                    controller: widthController,
                                    enabled: !isBaking,
                                    placeholder: '宽',
                                    inputFormatters: <TextInputFormatter>[
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('×'),
                                ),
                                Expanded(
                                  child: TextFormBox(
                                    controller: heightController,
                                    enabled: !isBaking,
                                    placeholder: '高',
                                    inputFormatters: <TextInputFormatter>[
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                  ),
                                ),
                              ],
                            ),
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
    final double sunHeight = math.sin(dayPhase);
    final double daylight = sunHeight.clamp(0.0, 1.0);

    final double altitude = 0.15 + 0.85 * daylight;
    final Vector3 light = Vector3(
      math.cos(azimuth),
      altitude,
      -math.sin(azimuth),
    )..normalize();

    final double ambient = (0.08 + 0.22 * daylight).clamp(0.05, 0.35);
    final double diffuse = (0.95 * daylight).clamp(0.0, 0.95);

    final Color sunWarm = const Color(0xFFFFA36D);
    final Color sunNeutral = const Color(0xFFFFFFFF);
    final double sunTintT = math.sqrt(daylight);
    final Color sunColor =
        Color.lerp(sunWarm, sunNeutral, sunTintT) ?? sunNeutral;

    final Color daySky = isDark
        ? const Color(0xFF2D4461)
        : const Color(0xFFBFD9FF);
    final Color nightSky = isDark
        ? const Color(0xFF0A1222)
        : const Color(0xFF121826);
    final Color skyColor = Color.lerp(nightSky, daySky, daylight) ?? daySky;

    const Color groundBounceColor = Color(0xFFFFFFFF);

    final double specularStrength = (0.15 + 0.35 * daylight).clamp(0.0, 0.6);
    const double roughness = 0.55;
    final double exposure = (1.1 + (1.0 - daylight) * 0.5).clamp(0.9, 1.7);

    final double shadowStrength = daylight <= 0
        ? 0.0
        : (0.18 + 0.62 * daylight).clamp(0.0, 0.85);
    final int shadowBlurRadius = daylight <= 0
        ? 0
        : (2 + (1.0 - daylight) * 3).round().clamp(1, 6);

    final Color dayBackground = isDark
        ? const Color(0xFF101010)
        : const Color(0xFFF7F7F7);
    final Color nightBackground = isDark
        ? const Color(0xFF050505)
        : const Color(0xFFE7E7E7);
    final Color background =
        Color.lerp(nightBackground, dayBackground, daylight) ?? dayBackground;

    return _ReferenceModelBakeLighting(
      lightDirection: light,
      ambient: ambient,
      diffuse: diffuse,
      sunColor: sunColor,
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
