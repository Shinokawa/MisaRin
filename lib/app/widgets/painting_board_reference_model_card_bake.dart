part of 'painting_board.dart';

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
    final OverlayState? overlay = Overlay.of(dialogContext, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    final GlobalKey previewKey = GlobalKey();

    double previewYaw = _yaw;
    double previewPitch = _pitch;
    double previewZoom = _zoom;
    double previewZoomScaleStart = previewZoom;

	    double timeHours = 12.0;

	    bool isBaking = false;

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

	    Future<Uint8List> capturePreviewPngBytes() async {
	      await Future<void>.delayed(const Duration(milliseconds: 16));
	      await WidgetsBinding.instance.endOfFrame;

	      final RenderObject? renderObject =
	          previewKey.currentContext?.findRenderObject();
	      if (renderObject is! RenderRepaintBoundary) {
	        throw StateError('无法获取预览区域渲染对象');
	      }

	      int retries = 0;
	      while (renderObject.debugNeedsPaint && retries < 3) {
	        retries += 1;
	        await WidgetsBinding.instance.endOfFrame;
	      }

	      final double devicePixelRatio = MediaQuery.devicePixelRatioOf(
	        dialogContext,
	      );
	      final double pixelRatio =
	          devicePixelRatio <= 0 ? 2.0 : devicePixelRatio.clamp(1.0, 2.0);

	      final ui.Image image = await renderObject.toImage(pixelRatio: pixelRatio);
	      try {
	        final ByteData? encoded =
	            await image.toByteData(format: ui.ImageByteFormat.png);
	        if (encoded == null) {
	          throw StateError('无法编码烘焙结果');
	        }
	        final Uint8List pngBytes = encoded.buffer.asUint8List(
	          encoded.offsetInBytes,
	          encoded.lengthInBytes,
	        );
	        return Uint8List.fromList(pngBytes);
	      } finally {
	        if (!image.debugDisposed) {
	          image.dispose();
	        }
	      }
	    }

	    Future<void> exportBakeResult(
	      BuildContext context,
	      StateSetter setDialogState,
	    ) async {
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
	        setDialogState(() => isBaking = true);
	        final Uint8List bytes = await capturePreviewPngBytes();
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
	          setDialogState(() => isBaking = false);
	        }
	      }
	    }

	    final Completer<void> completer = Completer<void>();
	    dialogCompleter = completer;
	    dialogEntry = OverlayEntry(
      builder: (BuildContext overlayContext) {
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
	                  final Color border = theme.resources.controlStrokeColorDefault;
	                  final _ReferenceModelBakeLighting lighting = _lightingForTime(
	                    timeHours,
	                    isDark: theme.brightness.isDark,
	                  );

	                  Widget buildModelPreview() {
	                    final Widget model = _BedrockModelZBufferView(
	                      baseModel: widget.modelMesh,
                      modelTextureWidth: widget.modelMesh.model.textureWidth,
                      modelTextureHeight: widget.modelMesh.model.textureHeight,
                      texture: widget.texture,
                      yaw: previewYaw,
                      pitch: previewPitch,
                      zoom: previewZoom,
                      animation: _selectedAnimation,
                      animationController: _actionController,
                      lightDirection: lighting.lightDirection,
                      ambient: lighting.ambient,
                      diffuse: lighting.diffuse,
                      sunColor: lighting.sunColor,
                      skyColor: lighting.skyColor,
                      groundBounceColor: lighting.groundBounceColor,
                      specularStrength: lighting.specularStrength,
                      roughness: lighting.roughness,
                      exposure: lighting.exposure,
                      lightFollowsCamera: false,
                      showGround: true,
                      groundY: 0.0,
                      alignModelToGround: true,
                      groundColor: Colors.white,
                      showGroundShadow: true,
                      groundShadowStrength: lighting.shadowStrength,
                      groundShadowBlurRadius: lighting.shadowBlurRadius,
                    );

                    Widget interactive = Listener(
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent) {
	                          setDialogState(() {
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
	                            previewYaw = 0;
	                            previewPitch = 0;
	                            previewZoom = 1.0;
	                          });
	                        },
	                        onScaleStart: (_) =>
	                            previewZoomScaleStart = previewZoom,
                        onScaleUpdate: (details) {
                          setDialogState(() {
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
	                                (previewPitch - details.focalPointDelta.dy * 0.01)
	                                    .clamp(-math.pi / 2, math.pi / 2);
	                          });
	                        },
	                        child: model,
	                      ),
	                    );

                    return IgnorePointer(ignoring: isBaking, child: interactive);
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
	                              color: lighting.background,
	                              child: AspectRatio(
	                                aspectRatio: 16 / 9,
	                                child: buildModelPreview(),
	                              ),
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
                    title: const Text('烘焙'),
                    contentWidth: null,
                    maxWidth: 920,
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        buildPreviewArea(),
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
	                                onChanged: isBaking
	                                    ? null
	                                    : (value) {
	                                        setDialogState(() {
	                                          timeHours = value;
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
    );

	    overlay.insert(dialogEntry!);
	    try {
	      await completer.future;
	    } finally {
	      closeDialog();
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
    final Color sunColor = Color.lerp(sunWarm, sunNeutral, sunTintT) ?? sunNeutral;

    final Color daySky =
        isDark ? const Color(0xFF2D4461) : const Color(0xFFBFD9FF);
    final Color nightSky =
        isDark ? const Color(0xFF0A1222) : const Color(0xFF121826);
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

    final Color dayBackground =
        isDark ? const Color(0xFF101010) : const Color(0xFFF7F7F7);
    final Color nightBackground =
        isDark ? const Color(0xFF050505) : const Color(0xFFE7E7E7);
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
