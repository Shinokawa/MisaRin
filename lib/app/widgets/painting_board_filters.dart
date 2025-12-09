part of 'painting_board.dart';

const double _kFilterPanelWidth = 320;
const double _kFilterPanelMinHeight = 180;
const double _kAntialiasPanelWidth = 280;
const double _kAntialiasPanelMinHeight = 140;
const double _kColorRangePanelWidth = 280;
const double _kColorRangePanelMinHeight = 150;
const int _kColorRangeMaxSelectableColors = 256;
const int _kColorRangeAlphaThreshold = 12;
const int _kColorRangeQuantizationStep = 8; // 5-bit per channel
const int _kColorRangeMinBucketSize = 3;
const double _kColorRangeSmallBucketFraction = 0.0005; // 0.05% coverage
const Duration _kColorRangePreviewDebounceDuration = Duration(
  milliseconds: 120,
);
const double _kGaussianBlurMaxRadius = 1000.0;
const double _kLeakRemovalMaxRadius = 20.0;
const double _kMorphologyMaxRadius = 20.0;
const double _kBlackWhiteMinRange = 1.0;
const double _kDefaultBinarizeAlphaThreshold = 128.0;
const ColorFilter _kViewBlackWhiteColorFilter = ColorFilter.matrix(<double>[
  0.299,
  0.587,
  0.114,
  0,
  0,
  0.299,
  0.587,
  0.114,
  0,
  0,
  0.299,
  0.587,
  0.114,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);
final Matrix4 _kViewMirrorTransform = Matrix4.diagonal3Values(-1, 1, 1);

enum _FilterPanelType {
  hueSaturation,
  brightnessContrast,
  blackWhite,
  binarize,
  gaussianBlur,
  leakRemoval,
  lineNarrow,
  fillExpand,
}

class _HueSaturationSettings {
  _HueSaturationSettings({
    this.hue = 0,
    this.saturation = 0,
    this.lightness = 0,
  });

  double hue;
  double saturation;
  double lightness;
}

class _BrightnessContrastSettings {
  _BrightnessContrastSettings({this.brightness = 0, this.contrast = 0});

  double brightness;
  double contrast;
}

class _GaussianBlurSettings {
  _GaussianBlurSettings({this.radius = 0});

  double radius;
}

class _LeakRemovalSettings {
  _LeakRemovalSettings({this.radius = 0});

  double radius;
}

class _MorphologySettings {
  _MorphologySettings({this.radius = 0});

  double radius;
}

class _BlackWhiteSettings {
  _BlackWhiteSettings({
    this.blackPoint = 0,
    this.whitePoint = 100,
    this.midTone = 0,
  });

  double blackPoint;
  double whitePoint;
  double midTone;
}

class _BinarizeSettings {
  _BinarizeSettings({this.alphaThreshold = _kDefaultBinarizeAlphaThreshold});

  double alphaThreshold;
}

class _FilterSession {
  _FilterSession({
    required this.type,
    required this.originalLayers,
    required this.activeLayerIndex,
    required this.activeLayerId,
  });

  final _FilterPanelType type;
  final List<CanvasLayerData> originalLayers;
  final int activeLayerIndex;
  final String activeLayerId;
  final _HueSaturationSettings hueSaturation = _HueSaturationSettings();
  final _BrightnessContrastSettings brightnessContrast =
      _BrightnessContrastSettings();
  final _BlackWhiteSettings blackWhite = _BlackWhiteSettings();
  final _BinarizeSettings binarize = _BinarizeSettings();
  final _GaussianBlurSettings gaussianBlur = _GaussianBlurSettings();
  final _LeakRemovalSettings leakRemoval = _LeakRemovalSettings();
  final _MorphologySettings lineNarrow = _MorphologySettings();
  final _MorphologySettings fillExpand = _MorphologySettings();
  CanvasLayerData? previewLayer;
}

class _ColorRangeSession {
  _ColorRangeSession({
    required this.layerId,
    required this.originalLayers,
    required this.activeLayerIndex,
  });

  final String layerId;
  final List<CanvasLayerData> originalLayers;
  final int activeLayerIndex;
  CanvasLayerData? previewLayer;
}

mixin _PaintingBoardFilterMixin
    on _PaintingBoardBase, _PaintingBoardLayerMixin {
  OverlayEntry? _filterOverlayEntry;
  _FilterSession? _filterSession;
  Offset _filterPanelOffset = Offset.zero;
  bool _filterPanelOffsetIsOverlay = false;
  _FilterPreviewWorker? _filterWorker;
  int _filterPreviewLastIssuedToken = 0;
  bool _filterPreviewRequestInFlight = false;
  bool _filterPreviewPendingChange = false;
  static const Duration _filterPreviewDebounceDuration = Duration(
    milliseconds: 50,
  );
  Timer? _filterPreviewDebounceTimer;
  bool _antialiasCardVisible = false;
  Offset _antialiasCardOffset = Offset.zero;
  Size? _antialiasCardSize;
  int _antialiasCardLevel = 2;
  bool _colorRangeCardVisible = false;
  Offset _colorRangeCardOffset = Offset.zero;
  Size? _colorRangeCardSize;
  int _colorRangeTotalColors = 0;
  int _colorRangeSelectedColors = 0;
  bool _colorRangeLoading = false;
  _ColorRangeSession? _colorRangeSession;
  bool _colorRangePreviewScheduled = false;
  bool _colorRangePreviewInFlight = false;
  int _colorRangePreviewToken = 0;
  Timer? _colorRangePreviewDebounceTimer;
  bool _colorRangeApplying = false;

  bool _filterLoading = false;
  ui.Image? _previewBackground;
  ui.Image? _previewActiveLayerImage;
  ui.Image? _previewFilteredActiveLayerImage;
  _FilterPanelType? _previewFilteredImageType;
  ui.Image? _previewForeground;
  Uint8List? _previewActiveLayerPixels;
  bool _previewHueSaturationUpdateScheduled = false;
  bool _previewHueSaturationUpdateInFlight = false;
  int _previewHueSaturationUpdateToken = 0;
  bool _previewBlackWhiteUpdateScheduled = false;
  bool _previewBlackWhiteUpdateInFlight = false;
  int _previewBlackWhiteUpdateToken = 0;
  bool _filterApplying = false;
  Completer<_FilterPreviewResult>? _filterApplyCompleter;
  bool _filterAwaitingFrameSwap = false;
  int? _filterAwaitedFrameGeneration;

  void showHueSaturationAdjustments() {
    _openFilterPanel(_FilterPanelType.hueSaturation);
  }

  void showBrightnessContrastAdjustments() {
    _openFilterPanel(_FilterPanelType.brightnessContrast);
  }

  void showBlackWhiteAdjustments() {
    _openFilterPanel(_FilterPanelType.blackWhite);
  }

  void showBinarizeAdjustments() {
    _openFilterPanel(_FilterPanelType.binarize);
  }

  void showGaussianBlurAdjustments() {
    _openFilterPanel(_FilterPanelType.gaussianBlur);
  }

  void showLeakRemovalAdjustments() {
    _openFilterPanel(_FilterPanelType.leakRemoval);
  }

  void showLineNarrowAdjustments() {
    _openFilterPanel(_FilterPanelType.lineNarrow);
  }

  void showFillExpandAdjustments() {
    _openFilterPanel(_FilterPanelType.fillExpand);
  }

  void _openFilterPanel(_FilterPanelType type) async {
    final String? activeLayerId = _activeLayerId;
    if (activeLayerId == null) {
      _showFilterMessage('请先选择一个可编辑的图层。');
      return;
    }
    _layerOpacityPreviewReset(this);
    final BitmapLayerState? layer = _layerById(activeLayerId);
    if (layer == null) {
      _showFilterMessage('无法定位当前图层。');
      return;
    }
    if (layer.locked) {
      _showFilterMessage('当前图层已锁定，无法应用滤镜。');
      return;
    }
    if (type == _FilterPanelType.binarize && layer.text != null) {
      _showFilterMessage('当前图层是文字图层，请先栅格化或切换其他图层。');
      return;
    }
    final List<CanvasLayerData> snapshot = _controller.snapshotLayers();
    final int layerIndex = snapshot.indexWhere(
      (item) => item.id == activeLayerId,
    );
    if (layerIndex < 0) {
      _showFilterMessage('无法定位当前图层。');
      return;
    }
    _removeFilterOverlay(restoreOriginal: false);

    _filterSession = _FilterSession(
      type: type,
      originalLayers: snapshot,
      activeLayerIndex: layerIndex,
      activeLayerId: activeLayerId,
    );
    _previewFilteredActiveLayerImage?.dispose();
    _previewFilteredActiveLayerImage = null;
    _previewFilteredImageType = null;
    _previewActiveLayerPixels = null;
    _previewHueSaturationUpdateScheduled = false;
    _previewHueSaturationUpdateInFlight = false;
    _previewHueSaturationUpdateToken++;
    _previewBlackWhiteUpdateScheduled = false;
    _previewBlackWhiteUpdateInFlight = false;
    _previewBlackWhiteUpdateToken++;

    if (_filterPanelOffset == Offset.zero) {
      final Offset workspaceOffset = _workspacePanelSpawnOffset(
        this,
        panelWidth: _kFilterPanelWidth,
        panelHeight: _kFilterPanelMinHeight,
      );
      _filterPanelOffset = _workspaceToOverlayOffset(this, workspaceOffset);
      _filterPanelOffsetIsOverlay = true;
    } else if (!_filterPanelOffsetIsOverlay) {
      _filterPanelOffset = _workspaceToOverlayOffset(this, _filterPanelOffset);
      _filterPanelOffsetIsOverlay = true;
    }

    // Initialize worker but don't use it for preview during drag
    _initializeFilterWorker();

    // Generate GPU preview images
    setState(() => _filterLoading = true);
    try {
      await _generatePreviewImages();
    } catch (e) {
      debugPrint('Failed to generate preview images: $e');
    } finally {
      if (mounted) {
        setState(() => _filterLoading = false);
      }
    }

    _insertFilterOverlay();
  }

  Future<void> _generatePreviewImages() async {
    final _FilterSession? session = _filterSession;
    if (session == null) {
      return;
    }
    final _LayerPreviewImages previews = await _captureLayerPreviewImages(
      controller: _controller,
      layers: _layers.toList(),
      activeLayerId: session.activeLayerId,
    );
    _previewBackground?.dispose();
    _previewActiveLayerImage?.dispose();
    _previewForeground?.dispose();
    _previewBackground = previews.background;
    _previewActiveLayerImage = previews.active;
    _previewForeground = previews.foreground;
    _previewFilteredActiveLayerImage?.dispose();
    _previewFilteredActiveLayerImage = null;
    _previewFilteredImageType = null;
    _previewActiveLayerPixels = null;
    if (_previewActiveLayerImage != null) {
      await _prepareActiveLayerPreviewPixels();
    }
    _previewHueSaturationUpdateToken++;
    _previewHueSaturationUpdateScheduled = false;
    _previewHueSaturationUpdateInFlight = false;
    _previewBlackWhiteUpdateToken++;
    _previewBlackWhiteUpdateScheduled = false;
    _previewBlackWhiteUpdateInFlight = false;
    if (session.type == _FilterPanelType.hueSaturation) {
      _scheduleHueSaturationPreviewImageUpdate();
    } else if (session.type == _FilterPanelType.blackWhite) {
      _scheduleBlackWhitePreviewImageUpdate();
    }
  }

  Future<void> _prepareActiveLayerPreviewPixels() async {
    final ui.Image? image = _previewActiveLayerImage;
    if (image == null) {
      _previewActiveLayerPixels = null;
      return;
    }
    try {
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) {
        _previewActiveLayerPixels = null;
        return;
      }
      _previewActiveLayerPixels = Uint8List.fromList(
        byteData.buffer.asUint8List(),
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to prepare preview pixels: $error');
      _previewActiveLayerPixels = null;
    }
  }

  void _scheduleHueSaturationPreviewImageUpdate() {
    if (_filterSession?.type != _FilterPanelType.hueSaturation) {
      return;
    }
    if (_previewActiveLayerPixels == null || _previewActiveLayerImage == null) {
      return;
    }
    _previewHueSaturationUpdateScheduled = true;
    if (!_previewHueSaturationUpdateInFlight) {
      unawaited(_runHueSaturationPreviewImageUpdate());
    }
  }

  Future<void> _runHueSaturationPreviewImageUpdate() async {
    if (_previewHueSaturationUpdateInFlight) {
      return;
    }
    _previewHueSaturationUpdateInFlight = true;
    while (_previewHueSaturationUpdateScheduled) {
      _previewHueSaturationUpdateScheduled = false;
      final _FilterSession? session = _filterSession;
      final ui.Image? baseImage = _previewActiveLayerImage;
      final Uint8List? source = _previewActiveLayerPixels;
      if (session == null ||
          session.type != _FilterPanelType.hueSaturation ||
          baseImage == null ||
          source == null) {
        break;
      }
      final _HueSaturationSettings settings = session.hueSaturation;
      final bool isIdentity =
          settings.hue == 0 &&
          settings.saturation == 0 &&
          settings.lightness == 0;
      if (isIdentity) {
        if (_previewFilteredActiveLayerImage != null) {
          setState(() {
            _previewFilteredActiveLayerImage?.dispose();
            _previewFilteredActiveLayerImage = null;
            _previewFilteredImageType = null;
          });
        }
        continue;
      }
      final int token = ++_previewHueSaturationUpdateToken;
      final List<Object?> args = <Object?>[
        source,
        settings.hue,
        settings.saturation,
        settings.lightness,
      ];
      Uint8List processed;
      try {
        processed = await _generateHueSaturationPreviewBytes(args);
      } catch (error, stackTrace) {
        debugPrint('Failed to compute hue preview: $error');
        break;
      }
      if (!mounted || token != _previewHueSaturationUpdateToken) {
        break;
      }
      final ui.Image image = await _decodeImage(
        processed,
        baseImage.width,
        baseImage.height,
      );
      if (!mounted || token != _previewHueSaturationUpdateToken) {
        image.dispose();
        break;
      }
      if (!mounted) {
        image.dispose();
        break;
      }
      setState(() {
        _previewFilteredActiveLayerImage?.dispose();
        _previewFilteredActiveLayerImage = image;
        _previewFilteredImageType = _FilterPanelType.hueSaturation;
      });
    }
    _previewHueSaturationUpdateInFlight = false;
    if (_previewHueSaturationUpdateScheduled) {
      unawaited(_runHueSaturationPreviewImageUpdate());
    }
  }

  void _scheduleBlackWhitePreviewImageUpdate() {
    if (_filterSession?.type != _FilterPanelType.blackWhite) {
      return;
    }
    if (_previewActiveLayerPixels == null || _previewActiveLayerImage == null) {
      return;
    }
    _previewBlackWhiteUpdateScheduled = true;
    if (!_previewBlackWhiteUpdateInFlight) {
      unawaited(_runBlackWhitePreviewImageUpdate());
    }
  }

  Future<void> _runBlackWhitePreviewImageUpdate() async {
    if (_previewBlackWhiteUpdateInFlight) {
      return;
    }
    _previewBlackWhiteUpdateInFlight = true;
    while (_previewBlackWhiteUpdateScheduled) {
      _previewBlackWhiteUpdateScheduled = false;
      final _FilterSession? session = _filterSession;
      final ui.Image? baseImage = _previewActiveLayerImage;
      final Uint8List? source = _previewActiveLayerPixels;
      if (session == null ||
          session.type != _FilterPanelType.blackWhite ||
          baseImage == null ||
          source == null) {
        break;
      }
      final _BlackWhiteSettings settings = session.blackWhite;
      final int token = ++_previewBlackWhiteUpdateToken;
      final List<Object?> args = <Object?>[
        source,
        settings.blackPoint,
        settings.whitePoint,
        settings.midTone,
      ];
      Uint8List processed;
      try {
        processed = await _generateBlackWhitePreviewBytes(args);
      } catch (error) {
        debugPrint('Failed to compute black & white preview: $error');
        break;
      }
      if (!mounted || token != _previewBlackWhiteUpdateToken) {
        break;
      }
      final ui.Image image = await _decodeImage(
        processed,
        baseImage.width,
        baseImage.height,
      );
      if (!mounted || token != _previewBlackWhiteUpdateToken) {
        image.dispose();
        break;
      }
      setState(() {
        _previewFilteredActiveLayerImage?.dispose();
        _previewFilteredActiveLayerImage = image;
        _previewFilteredImageType = _FilterPanelType.blackWhite;
      });
    }
    _previewBlackWhiteUpdateInFlight = false;
    if (_previewBlackWhiteUpdateScheduled) {
      unawaited(_runBlackWhitePreviewImageUpdate());
    }
  }

  List<double>? _calculateCurrentFilterMatrix() {
    final _FilterSession? session = _filterSession;
    if (session == null) return null;

    if (session.type == _FilterPanelType.hueSaturation) {
      final double hue = session.hueSaturation.hue;
      final double saturation = session.hueSaturation.saturation;
      if (hue == 0 && saturation == 0) return null;

      if (saturation == 0) {
        return ColorFilterGenerator.hue(hue);
      }
      return null; // Handled via chaining in build
    } else if (session.type == _FilterPanelType.brightnessContrast) {
      final double brightness = session.brightnessContrast.brightness;
      final double contrast = session.brightnessContrast.contrast;
      if (brightness == 0 && contrast == 0) return null;
      return ColorFilterGenerator.brightnessContrast(brightness, contrast);
    }
    return null;
  }

  void _showFilterMessage(String message) {
    AppNotifications.show(
      context,
      message: message,
      severity: InfoBarSeverity.warning,
    );
  }

  void _insertFilterOverlay() {
    final OverlayState? overlay = Overlay.of(context);
    if (overlay == null) {
      return;
    }
    final Size size = MediaQuery.sizeOf(context);
    if (_filterPanelOffset == Offset.zero) {
      _filterPanelOffset = Offset(
        math.max(16, size.width - _kFilterPanelWidth - 32),
        math.max(16, size.height * 0.2),
      );
      _filterPanelOffsetIsOverlay = true;
    }
    _filterOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final _FilterSession? session = _filterSession;
        if (session == null) {
          return const SizedBox.shrink();
        }
        final Size bounds = MediaQuery.sizeOf(overlayContext);
        final double clampedX = _filterPanelOffset.dx.clamp(
          16.0,
          math.max(16.0, bounds.width - _kFilterPanelWidth - 16.0),
        );
        final double clampedY = _filterPanelOffset.dy.clamp(
          16.0,
          math.max(16.0, bounds.height - _kFilterPanelMinHeight - 16.0),
        );
        _filterPanelOffset = Offset(clampedX, clampedY);
        final String panelTitle;
        final Widget panelBody;
        switch (session.type) {
          case _FilterPanelType.hueSaturation:
            panelTitle = '色相/饱和度';
            panelBody = _HueSaturationControls(
              settings: session.hueSaturation,
              onHueChanged: (value) => _updateHueSaturation(hue: value),
              onSaturationChanged: (value) =>
                  _updateHueSaturation(saturation: value),
              onLightnessChanged: (value) =>
                  _updateHueSaturation(lightness: value),
            );
            break;
          case _FilterPanelType.brightnessContrast:
            panelTitle = '亮度/对比度';
            panelBody = _BrightnessContrastControls(
              settings: session.brightnessContrast,
              onBrightnessChanged: (value) =>
                  _updateBrightnessContrast(brightness: value),
              onContrastChanged: (value) =>
                  _updateBrightnessContrast(contrast: value),
            );
            break;
          case _FilterPanelType.blackWhite:
            panelTitle = '黑白';
            panelBody = _BlackWhiteControls(
              settings: session.blackWhite,
              onBlackPointChanged: (value) =>
                  _updateBlackWhite(blackPoint: value),
              onWhitePointChanged: (value) =>
                  _updateBlackWhite(whitePoint: value),
              onMidToneChanged: (value) => _updateBlackWhite(midTone: value),
            );
            break;
          case _FilterPanelType.binarize:
            panelTitle = '二值化';
            panelBody = _BinarizeControls(
              threshold: session.binarize.alphaThreshold,
              onThresholdChanged: _updateBinarizeThreshold,
            );
            break;
          case _FilterPanelType.gaussianBlur:
            panelTitle = '高斯模糊';
            panelBody = _GaussianBlurControls(
              radius: session.gaussianBlur.radius,
              onRadiusChanged: _updateGaussianBlur,
            );
            break;
          case _FilterPanelType.leakRemoval:
            panelTitle = '去除漏色';
            panelBody = _LeakRemovalControls(
              radius: session.leakRemoval.radius,
              onRadiusChanged: _updateLeakRemovalRadius,
            );
            break;
          case _FilterPanelType.lineNarrow:
            panelTitle = '线条收窄';
            panelBody = _MorphologyControls(
              label: '收窄半径',
              radius: session.lineNarrow.radius,
              maxRadius: _kMorphologyMaxRadius,
              onRadiusChanged: _updateLineNarrow,
            );
            break;
          case _FilterPanelType.fillExpand:
            panelTitle = '填色拉伸';
            panelBody = _MorphologyControls(
              label: '拉伸半径',
              radius: session.fillExpand.radius,
              maxRadius: _kMorphologyMaxRadius,
              onRadiusChanged: _updateFillExpand,
            );
            break;
        }

        if (_filterLoading) {
          return Positioned(
            left: _filterPanelOffset.dx,
            top: _filterPanelOffset.dy,
            child: const SizedBox(
              width: _kFilterPanelWidth,
              height: 100,
              child: Center(child: ProgressRing()),
            ),
          );
        }

        return Positioned(
          left: _filterPanelOffset.dx,
          top: _filterPanelOffset.dy,
          child: WorkspaceFloatingPanel(
            width: _kFilterPanelWidth,
            minHeight: _kFilterPanelMinHeight,
            title: panelTitle,
            onClose: () => _removeFilterOverlay(),
            onDragUpdate: _handleFilterPanelDrag,
            headerPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            bodyPadding: const EdgeInsets.symmetric(horizontal: 16),
            footerPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            bodySpacing: 0,
            footerSpacing: 12,
            child: panelBody,
            footer: Row(
              children: [
                Button(
                  onPressed: _resetFilterSettings,
                  child: const Text('重置'),
                ),
                const Spacer(),
                Button(
                  onPressed: () => _removeFilterOverlay(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _filterApplying ? null : _confirmFilterChanges,
                  child: _filterApplying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: ProgressRing(strokeWidth: 2),
                        )
                      : const Text('应用'),
                ),
              ],
            ),
          ),
        );
      },
    );
    overlay.insert(_filterOverlayEntry!);
  }

  void _initializeFilterWorker() {
    final _FilterSession? session = _filterSession;
    if (session == null) {
      return;
    }
    final CanvasLayerData baseLayer =
        session.originalLayers[session.activeLayerIndex];
    _filterWorker?.dispose();
    _filterWorker = _FilterPreviewWorker(
      type: session.type,
      layerId: session.activeLayerId,
      baseLayer: baseLayer,
      canvasWidth: _controller.width,
      canvasHeight: _controller.height,
      onResult: _handleFilterPreviewResult,
      onError: _handleFilterWorkerError,
    );
  }

  void _handleFilterPanelDrag(Offset delta) {
    _filterPanelOffset = Offset(
      _filterPanelOffset.dx + delta.dx,
      _filterPanelOffset.dy + delta.dy,
    );
    _filterPanelOffsetIsOverlay = true;
    _filterOverlayEntry?.markNeedsBuild();
  }

  void _resetFilterSettings() {
    final _FilterSession? session = _filterSession;
    if (session == null) {
      return;
    }
    session.hueSaturation
      ..hue = 0
      ..saturation = 0
      ..lightness = 0;
    session.brightnessContrast
      ..brightness = 0
      ..contrast = 0;
    session.blackWhite
      ..blackPoint = 0
      ..whitePoint = 100
      ..midTone = 0;
    session.binarize.alphaThreshold = _kDefaultBinarizeAlphaThreshold;
    session.gaussianBlur.radius = 0;
    session.leakRemoval.radius = 0;
    session.lineNarrow.radius = 0;
    session.fillExpand.radius = 0;
    setState(() {});
    _filterOverlayEntry?.markNeedsBuild();
    _scheduleHueSaturationPreviewImageUpdate();
    _scheduleBlackWhitePreviewImageUpdate();
  }

  void _updateHueSaturation({
    double? hue,
    double? saturation,
    double? lightness,
  }) {
    final _FilterSession? session = _filterSession;
    if (session == null) {
      return;
    }
    session.hueSaturation
      ..hue = hue ?? session.hueSaturation.hue
      ..saturation = saturation ?? session.hueSaturation.saturation
      ..lightness = lightness ?? session.hueSaturation.lightness;
    setState(() {});
    _filterOverlayEntry?.markNeedsBuild();
    _scheduleHueSaturationPreviewImageUpdate();
  }

  void _updateBrightnessContrast({double? brightness, double? contrast}) {
    final _FilterSession? session = _filterSession;
    if (session == null) {
      return;
    }
    session.brightnessContrast
      ..brightness = brightness ?? session.brightnessContrast.brightness
      ..contrast = contrast ?? session.brightnessContrast.contrast;
    setState(() {});
    _filterOverlayEntry?.markNeedsBuild();
  }

  void _updateBlackWhite({
    double? blackPoint,
    double? whitePoint,
    double? midTone,
  }) {
    final _FilterSession? session = _filterSession;
    if (session == null) {
      return;
    }
    final double nextBlack = (blackPoint ?? session.blackWhite.blackPoint)
        .clamp(0.0, 100.0);
    double nextWhite = (whitePoint ?? session.blackWhite.whitePoint).clamp(
      0.0,
      100.0,
    );
    if (nextWhite <= nextBlack + _kBlackWhiteMinRange) {
      nextWhite = math.min(100.0, nextBlack + _kBlackWhiteMinRange);
    }
    session.blackWhite
      ..blackPoint = nextBlack
      ..whitePoint = nextWhite
      ..midTone = (midTone ?? session.blackWhite.midTone).clamp(-100.0, 100.0);
    setState(() {});
    _filterOverlayEntry?.markNeedsBuild();
    _scheduleBlackWhitePreviewImageUpdate();
  }

  void _updateBinarizeThreshold(double threshold) {
    final _FilterSession? session = _filterSession;
    if (session == null) {
      return;
    }
    session.binarize.alphaThreshold = threshold.clamp(0.0, 255.0);
    setState(() {});
    _filterOverlayEntry?.markNeedsBuild();
  }

  void _updateGaussianBlur(double radius) {
    final _FilterSession? session = _filterSession;
    if (session == null) {
      return;
    }
    session.gaussianBlur.radius = radius.clamp(0.0, _kGaussianBlurMaxRadius);
    setState(() {});
    _filterOverlayEntry?.markNeedsBuild();
  }

  void _updateLeakRemovalRadius(double radius) {
    final _FilterSession? session = _filterSession;
    if (session == null) {
      return;
    }
    session.leakRemoval.radius = radius.clamp(0.0, _kLeakRemovalMaxRadius);
    setState(() {});
    _filterOverlayEntry?.markNeedsBuild();
  }

  void _updateLineNarrow(double radius) {
    final _FilterSession? session = _filterSession;
    if (session == null) {
      return;
    }
    session.lineNarrow.radius = radius.clamp(0.0, _kMorphologyMaxRadius);
    setState(() {});
    _filterOverlayEntry?.markNeedsBuild();
  }

  void _updateFillExpand(double radius) {
    final _FilterSession? session = _filterSession;
    if (session == null) {
      return;
    }
    session.fillExpand.radius = radius.clamp(0.0, _kMorphologyMaxRadius);
    setState(() {});
    _filterOverlayEntry?.markNeedsBuild();
  }

  void _requestFilterPreview({bool immediate = false}) {
    // Only used for final apply now
    _applyFilterPreview();
  }

  void _applyFilterPreview() {
    final _FilterSession? session = _filterSession;
    if (session == null) {
      return;
    }
    if (_filterWorker == null) {
      _initializeFilterWorker();
    }
    _filterPreviewPendingChange = true;
    _tryDispatchFilterPreview();
  }

  void _tryDispatchFilterPreview() {
    if (!_filterPreviewPendingChange || _filterPreviewRequestInFlight) {
      return;
    }
    final _FilterSession? session = _filterSession;
    if (session == null) {
      _filterPreviewPendingChange = false;
      return;
    }

    final _FilterPreviewWorker? worker = _filterWorker;
    if (worker == null) {
      return;
    }
    _filterPreviewPendingChange = false;
    _filterPreviewRequestInFlight = true;
    final int token = ++_filterPreviewLastIssuedToken;
    final double morphRadius = switch (session.type) {
      _FilterPanelType.lineNarrow => session.lineNarrow.radius,
      _FilterPanelType.fillExpand => session.fillExpand.radius,
      _ => 0.0,
    };
    final double binarizeThreshold = session.binarize.alphaThreshold;
    unawaited(
      worker.requestPreview(
        token: token,
        hueSaturation: session.hueSaturation,
        brightnessContrast: session.brightnessContrast,
        blackWhite: session.blackWhite,
        blurRadius: session.gaussianBlur.radius,
        leakRadius: session.leakRemoval.radius,
        morphRadius: morphRadius,
        binarizeThreshold: binarizeThreshold,
      ),
    );
  }

  void _onFilterPreviewRequestComplete() {
    if (!_filterPreviewRequestInFlight) {
      return;
    }
    _filterPreviewRequestInFlight = false;
    if (_filterPreviewPendingChange) {
      _tryDispatchFilterPreview();
    }
  }

  Future<void> _confirmFilterChanges() async {
    final _FilterSession? session = _filterSession;
    if (session == null) {
      return;
    }
    if (_isFilterSessionIdentity(session)) {
      if (session.type == _FilterPanelType.binarize) {
        _showFilterMessage('未检测到可处理的半透明像素。');
      }
      _removeFilterOverlay();
      return;
    }

    setState(() {
      _filterApplying = true;
    });
    _filterOverlayEntry?.markNeedsBuild();

    final Completer<_FilterPreviewResult> completer =
        Completer<_FilterPreviewResult>();
    _filterApplyCompleter = completer;
    _requestFilterPreview(immediate: true);

    final _FilterPreviewResult result;
    try {
      result = await completer.future;
    } catch (error, stackTrace) {
      debugPrint('Filter apply failed: $error');
      _filterApplyCompleter = null;
      if (mounted) {
        setState(() {
          _filterApplying = false;
        });
        _filterOverlayEntry?.markNeedsBuild();
      }
      _showFilterMessage('应用滤镜失败，请重试。');
      return;
    }
    _filterApplyCompleter = null;
    await _finalizeFilterApply(session, result);
  }

  Future<void> _finalizeFilterApply(
    _FilterSession session,
    _FilterPreviewResult result,
  ) async {
    final CanvasLayerData original =
        session.originalLayers[session.activeLayerIndex];
    final CanvasLayerData adjusted = _buildAdjustedLayerFromResult(
      original,
      result,
    );
    await _pushUndoSnapshot();
    final int? awaitedGeneration = _controller.frame?.generation;
    _controller.replaceLayer(session.activeLayerId, adjusted);
    _controller.setActiveLayer(session.activeLayerId);
    _markDirty();
    setState(() {});
    _scheduleFilterOverlayRemovalAfterApply(awaitedGeneration);
  }

  void _scheduleFilterOverlayRemovalAfterApply(int? awaitedGeneration) {
    if (awaitedGeneration == null) {
      _removeFilterOverlay(restoreOriginal: false);
      return;
    }
    _filterAwaitedFrameGeneration = awaitedGeneration;
    _filterAwaitingFrameSwap = true;
    _tryFinalizeFilterApplyAfterFrameChange();
  }

  void _tryFinalizeFilterApplyAfterFrameChange([BitmapCanvasFrame? frame]) {
    if (!_filterAwaitingFrameSwap) {
      return;
    }
    frame ??= _controller.frame;
    if (frame == null) {
      return;
    }
    final int? awaitedGeneration = _filterAwaitedFrameGeneration;
    if (awaitedGeneration == null || frame.generation != awaitedGeneration) {
      _filterAwaitingFrameSwap = false;
      _filterAwaitedFrameGeneration = null;
      _removeFilterOverlay(restoreOriginal: false);
    }
  }

  void _handleFilterApplyFrameProgress(BitmapCanvasFrame? frame) {
    _tryFinalizeFilterApplyAfterFrameChange(frame);
  }

  bool _isFilterSessionIdentity(_FilterSession session) {
    switch (session.type) {
      case _FilterPanelType.hueSaturation:
        final _HueSaturationSettings settings = session.hueSaturation;
        return settings.hue == 0 &&
            settings.saturation == 0 &&
            settings.lightness == 0;
      case _FilterPanelType.brightnessContrast:
        final _BrightnessContrastSettings settings = session.brightnessContrast;
        return settings.brightness == 0 && settings.contrast == 0;
      case _FilterPanelType.blackWhite:
        final CanvasLayerData layer =
            session.originalLayers[session.activeLayerIndex];
        final bool hasBitmap =
            layer.bitmap != null &&
            (layer.bitmapWidth ?? 0) > 0 &&
            (layer.bitmapHeight ?? 0) > 0;
        final bool hasFill = layer.fillColor != null;
        return !hasBitmap && !hasFill;
      case _FilterPanelType.binarize:
        final CanvasLayerData layer =
            session.originalLayers[session.activeLayerIndex];
        final Uint8List? bitmap = layer.bitmap;
        bool hasPartialAlpha = false;
        if (bitmap != null) {
          for (int i = 3; i < bitmap.length; i += 4) {
            final int alpha = bitmap[i];
            if (alpha != 0 && alpha != 255) {
              hasPartialAlpha = true;
              break;
            }
          }
        }
        if (!hasPartialAlpha && layer.fillColor != null) {
          final int alpha = layer.fillColor!.alpha;
          if (alpha != 0 && alpha != 255) {
            hasPartialAlpha = true;
          }
        }
        final bool hasContent = (bitmap != null &&
                (layer.bitmapWidth ?? 0) > 0 &&
                (layer.bitmapHeight ?? 0) > 0) ||
            layer.fillColor != null;
        return !hasContent || !hasPartialAlpha;
      case _FilterPanelType.gaussianBlur:
        final double radius = session.gaussianBlur.radius;
        final CanvasLayerData layer =
            session.originalLayers[session.activeLayerIndex];
        final bool hasBitmap =
            layer.bitmap != null &&
            (layer.bitmapWidth ?? 0) > 0 &&
            (layer.bitmapHeight ?? 0) > 0;
        return radius <= 0 || !hasBitmap;
      case _FilterPanelType.leakRemoval:
        final double radius = session.leakRemoval.radius;
        final CanvasLayerData layer =
            session.originalLayers[session.activeLayerIndex];
        final bool hasBitmap =
            layer.bitmap != null &&
            (layer.bitmapWidth ?? 0) > 0 &&
            (layer.bitmapHeight ?? 0) > 0;
        return radius <= 0 || !hasBitmap;
      case _FilterPanelType.lineNarrow:
      case _FilterPanelType.fillExpand:
        final double radius = session.type == _FilterPanelType.lineNarrow
            ? session.lineNarrow.radius
            : session.fillExpand.radius;
        final CanvasLayerData layer =
            session.originalLayers[session.activeLayerIndex];
        final bool hasBitmap =
            layer.bitmap != null &&
            (layer.bitmapWidth ?? 0) > 0 &&
            (layer.bitmapHeight ?? 0) > 0;
        return radius <= 0 || !hasBitmap;
    }
  }

  void _handleFilterPreviewResult(_FilterPreviewResult result) {
    if (!mounted) {
      return;
    }
    if (result.token != _filterPreviewLastIssuedToken) {
      return;
    }
    final _FilterSession? session = _filterSession;
    if (session == null) {
      return;
    }
    if (result.layerId != session.activeLayerId) {
      return;
    }
    final Completer<_FilterPreviewResult>? completer = _filterApplyCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
      _onFilterPreviewRequestComplete();
      return;
    }
    final CanvasLayerData original =
        session.originalLayers[session.activeLayerIndex];
    final CanvasLayerData adjusted = _buildAdjustedLayerFromResult(
      original,
      result,
    );
    session.previewLayer = adjusted;
    _controller.replaceLayer(session.activeLayerId, adjusted);
    _controller.setActiveLayer(session.activeLayerId);
    setState(() {});
    _onFilterPreviewRequestComplete();
  }

  void _handleFilterWorkerError(Object error, StackTrace stackTrace) {
    debugPrint('Filter preview worker error: $error');
    final Completer<_FilterPreviewResult>? completer = _filterApplyCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
    _onFilterPreviewRequestComplete();
  }

  void _restoreFilterPreviewToOriginal(_FilterSession session) {
    if (session.previewLayer == null) {
      return;
    }
    final bool shouldNotify = mounted;
    final CanvasLayerData original =
        session.originalLayers[session.activeLayerIndex];
    _controller.replaceLayer(session.activeLayerId, original);
    _controller.setActiveLayer(session.activeLayerId);
    session.previewLayer = null;
    if (shouldNotify) {
      setState(() {});
    }
  }

  void _cancelFilterPreviewTasks() {
    _filterPreviewLastIssuedToken++;
    _filterWorker?.discardPendingResult();
    _filterPreviewPendingChange = false;
    _filterPreviewRequestInFlight = false;
    _filterPreviewDebounceTimer?.cancel();
    _filterPreviewDebounceTimer = null;
  }

  void _removeFilterOverlay({bool restoreOriginal = true}) {
    _filterOverlayEntry?.remove();
    _filterOverlayEntry = null;
    _cancelFilterPreviewTasks();
    final _FilterSession? session = _filterSession;
    if (restoreOriginal && session != null) {
      _restoreFilterPreviewToOriginal(session);
    }
    _filterWorker?.dispose();
    _filterWorker = null;
    _filterSession = null;
    if (_filterApplyCompleter != null && !_filterApplyCompleter!.isCompleted) {
      _filterApplyCompleter!.completeError(StateError('滤镜面板已关闭，操作被取消。'));
    }
    _filterApplyCompleter = null;
    _filterAwaitingFrameSwap = false;
    _filterAwaitedFrameGeneration = null;

    _previewBackground?.dispose();
    _previewBackground = null;
    _previewActiveLayerImage?.dispose();
    _previewActiveLayerImage = null;
    _previewFilteredActiveLayerImage?.dispose();
    _previewFilteredActiveLayerImage = null;
    _previewFilteredImageType = null;
    _previewForeground?.dispose();
    _previewForeground = null;
    _previewActiveLayerPixels = null;
    _previewHueSaturationUpdateScheduled = false;
    _previewHueSaturationUpdateInFlight = false;
    _previewHueSaturationUpdateToken++;
    _previewBlackWhiteUpdateScheduled = false;
    _previewBlackWhiteUpdateInFlight = false;
    _previewBlackWhiteUpdateToken++;
    _filterLoading = false;
    _filterApplying = false;

    if (_filterPanelOffset == Offset.zero) {
      _filterPanelOffsetIsOverlay = false;
    }
  }

  CanvasLayerData _buildAdjustedLayerFromResult(
    CanvasLayerData original,
    _FilterPreviewResult result,
  ) {
    final Uint8List? bitmap = result.bitmapBytes;
    final int? fillValue = result.fillColor;
    Color? fillColor = original.fillColor;
    if (fillValue != null) {
      fillColor = Color(fillValue);
    }
    final bool hasBitmap = bitmap != null;
    return CanvasLayerData(
      id: original.id,
      name: original.name,
      visible: original.visible,
      opacity: original.opacity,
      locked: original.locked,
      clippingMask: original.clippingMask,
      blendMode: original.blendMode,
      fillColor: fillColor,
      bitmap: bitmap,
      bitmapWidth: hasBitmap ? original.bitmapWidth : null,
      bitmapHeight: hasBitmap ? original.bitmapHeight : null,
      bitmapLeft: hasBitmap ? original.bitmapLeft : null,
      bitmapTop: hasBitmap ? original.bitmapTop : null,
      cloneBitmap: false,
    );
  }

  CanvasLayerData _buildColorRangeAdjustedLayer(
    CanvasLayerData original,
    _ColorRangeComputeResult result,
  ) {
    final Uint8List? bitmap = result.bitmap ?? original.bitmap;
    final int? fillValue = result.fillColor;
    Color? fillColor = original.fillColor;
    if (fillValue != null) {
      fillColor = Color(fillValue);
    }
    final bool hasBitmap = bitmap != null;
    return CanvasLayerData(
      id: original.id,
      name: original.name,
      visible: original.visible,
      opacity: original.opacity,
      locked: original.locked,
      clippingMask: original.clippingMask,
      blendMode: original.blendMode,
      fillColor: fillColor,
      bitmap: bitmap,
      bitmapWidth: hasBitmap ? original.bitmapWidth : null,
      bitmapHeight: hasBitmap ? original.bitmapHeight : null,
      bitmapLeft: hasBitmap ? original.bitmapLeft : null,
      bitmapTop: hasBitmap ? original.bitmapTop : null,
      text: original.text,
      cloneBitmap: false,
    );
  }

  Future<void> invertActiveLayerColors() async {
    if (_controller.frame == null) {
      _showFilterMessage('画布尚未准备好，无法颜色反转。');
      return;
    }
    final String? activeLayerId = _activeLayerId;
    if (activeLayerId == null) {
      _showFilterMessage('请先选择一个可编辑的图层。');
      return;
    }
    final BitmapLayerState? layer = _layerById(activeLayerId);
    if (layer == null) {
      _showFilterMessage('无法定位当前图层。');
      return;
    }
    if (layer.locked) {
      _showFilterMessage('当前图层已锁定，无法颜色反转。');
      return;
    }

    await _controller.waitForPendingWorkerTasks();
    final List<CanvasLayerData> snapshot = _controller.snapshotLayers();
    final int index = snapshot.indexWhere((item) => item.id == activeLayerId);
    if (index < 0) {
      _showFilterMessage('无法定位当前图层。');
      return;
    }
    final CanvasLayerData data = snapshot[index];
    if (data.bitmap == null && data.fillColor == null) {
      _showFilterMessage('当前图层为空，无法颜色反转。');
      return;
    }

    Uint8List? bitmap = data.bitmap != null
        ? Uint8List.fromList(data.bitmap!)
        : null;
    Color? fillColor = data.fillColor;
    bool bitmapModified = false;
    if (bitmap != null) {
      bool hasCoverage = false;
      for (int i = 0; i < bitmap.length; i += 4) {
        final int alpha = bitmap[i + 3];
        if (alpha == 0) {
          continue;
        }
        hasCoverage = true;
        bitmap[i] = 255 - bitmap[i];
        bitmap[i + 1] = 255 - bitmap[i + 1];
        bitmap[i + 2] = 255 - bitmap[i + 2];
      }
      if (hasCoverage) {
        bitmapModified = true;
      } else {
        bitmap = null;
      }
    }

    bool fillChanged = false;
    if (fillColor != null) {
      final Color inverted = Color.fromARGB(
        fillColor.alpha,
        255 - fillColor.red,
        255 - fillColor.green,
        255 - fillColor.blue,
      );
      if (inverted != fillColor) {
        fillColor = inverted;
        fillChanged = true;
      }
    }

    if (!bitmapModified && !fillChanged) {
      _showFilterMessage('当前图层没有可反转的像素。');
      return;
    }

    await _pushUndoSnapshot();
    final CanvasLayerData updated = CanvasLayerData(
      id: data.id,
      name: data.name,
      visible: data.visible,
      opacity: data.opacity,
      locked: data.locked,
      clippingMask: data.clippingMask,
      blendMode: data.blendMode,
      fillColor: fillColor,
      bitmap: bitmap,
      bitmapWidth: bitmap != null ? data.bitmapWidth : null,
      bitmapHeight: bitmap != null ? data.bitmapHeight : null,
      bitmapLeft: bitmap != null ? data.bitmapLeft : null,
      bitmapTop: bitmap != null ? data.bitmapTop : null,
      text: data.text,
      cloneBitmap: false,
    );
    _controller.replaceLayer(activeLayerId, updated);
    _controller.setActiveLayer(activeLayerId);
    setState(() {});
    _markDirty();
  }

  void showLayerAntialiasPanel() {
    if (!_ensureAntialiasLayerReady()) {
      return;
    }
    setState(() {
      if (_antialiasCardOffset == Offset.zero) {
        _antialiasCardOffset = _initialAntialiasCardOffset();
      } else {
        _antialiasCardOffset = _clampAntialiasCardOffset(
          _antialiasCardOffset,
          _antialiasCardSize,
        );
      }
      _antialiasCardVisible = true;
    });
  }

  void hideLayerAntialiasPanel() {
    if (!_antialiasCardVisible) {
      return;
    }
    setState(() {
      _antialiasCardVisible = false;
    });
  }

  void _handleAntialiasLevelChanged(int level) {
    final int clamped = level.clamp(0, 3);
    if (_antialiasCardLevel == clamped) {
      return;
    }
    setState(() {
      _antialiasCardLevel = clamped;
    });
  }

  void _applyAntialiasFromCard() async {
    if (!_ensureAntialiasLayerReady()) {
      return;
    }
    final bool applied = await applyLayerAntialiasLevel(_antialiasCardLevel);
    if (!applied) {
      _showFilterMessage('无法对当前图层应用边缘柔化，图层可能为空或已锁定。');
      return;
    }
    setState(() {
      _antialiasCardVisible = false;
    });
  }

  void _updateAntialiasCardOffset(Offset delta) {
    if (!_antialiasCardVisible) {
      return;
    }
    setState(() {
      _antialiasCardOffset = _clampAntialiasCardOffset(
        _antialiasCardOffset + delta,
        _antialiasCardSize,
      );
    });
  }

  void _handleAntialiasCardSizeChanged(Size size) {
    if (_antialiasCardSize == size) {
      return;
    }
    setState(() {
      _antialiasCardSize = size;
      _antialiasCardOffset = _clampAntialiasCardOffset(
        _antialiasCardOffset,
        size,
      );
    });
  }

  bool _isInsideAntialiasCardArea(Offset workspacePosition) {
    if (!_antialiasCardVisible) {
      return false;
    }
    final Size size =
        _antialiasCardSize ??
        const Size(_kAntialiasPanelWidth, _kAntialiasPanelMinHeight);
    final Rect rect = Rect.fromLTWH(
      _antialiasCardOffset.dx,
      _antialiasCardOffset.dy,
      size.width,
      size.height,
    );
    return rect.contains(workspacePosition);
  }

  bool _ensureAntialiasLayerReady() {
    final BitmapLayerState? layer = _currentActiveLayer();
    if (layer == null) {
      _showFilterMessage('请先选择一个可编辑的图层。');
      return false;
    }
    if (layer.locked) {
      _showFilterMessage('当前图层已锁定，无法应用边缘柔化。');
      return false;
    }
    return true;
  }

  Offset _initialAntialiasCardOffset() {
    return _workspacePanelSpawnOffset(
      this,
      panelWidth: _kAntialiasPanelWidth,
      panelHeight: _kAntialiasPanelMinHeight,
    );
  }

  Offset _clampAntialiasCardOffset(Offset value, Size? size) {
    if (_workspaceSize.isEmpty) {
      return value;
    }
    final double width = size?.width ?? _kAntialiasPanelWidth;
    final double height = size?.height ?? _kAntialiasPanelMinHeight;
    const double margin = 12.0;
    final double minX = margin;
    final double minY = margin;
    final double maxX = math.max(minX, _workspaceSize.width - width - margin);
    final double maxY = math.max(minY, _workspaceSize.height - height - margin);
    return Offset(value.dx.clamp(minX, maxX), value.dy.clamp(minY, maxY));
  }

  Future<void> showColorRangeCard() async {
    if (!isBoardReady) {
      _showFilterMessage('画布尚未准备好，无法统计色彩范围。');
      return;
    }
    final String? activeLayerId = _activeLayerId;
    if (activeLayerId == null) {
      _showFilterMessage('请先选择一个可编辑的图层。');
      return;
    }
    final BitmapLayerState? layer = _layerById(activeLayerId);
    if (layer == null) {
      _showFilterMessage('无法定位当前图层。');
      return;
    }
    if (layer.locked) {
      _showFilterMessage('当前图层已锁定，无法设置色彩范围。');
      return;
    }
    if (_colorRangeLoading) {
      setState(() {
        _colorRangeCardVisible = true;
      });
      return;
    }
    await _controller.waitForPendingWorkerTasks();
    final List<CanvasLayerData> snapshot = _controller.snapshotLayers();
    final int layerIndex = snapshot.indexWhere(
      (item) => item.id == activeLayerId,
    );
    if (layerIndex < 0) {
      _showFilterMessage('无法定位当前图层。');
      return;
    }
    final CanvasLayerData activeLayer = snapshot[layerIndex];
    final bool hasBitmap = activeLayer.bitmap != null &&
        activeLayer.bitmap!.isNotEmpty &&
        (activeLayer.bitmapWidth ?? 0) > 0 &&
        (activeLayer.bitmapHeight ?? 0) > 0;
    final Color? fillColor = activeLayer.fillColor;
    final bool hasFill = fillColor != null && fillColor.alpha != 0;
    if (!hasBitmap && !hasFill) {
      _showFilterMessage('当前图层为空，无法设置色彩范围。');
      return;
    }
    _teardownColorRangeSession();
    _colorRangeSession = _ColorRangeSession(
      layerId: activeLayerId,
      originalLayers: snapshot,
      activeLayerIndex: layerIndex,
    );
    _colorRangePreviewToken++;
    _colorRangePreviewScheduled = false;
    _colorRangePreviewInFlight = false;
    _colorRangePreviewDebounceTimer?.cancel();
    _colorRangePreviewDebounceTimer = null;
    _colorRangeApplying = false;
    Offset nextOffset = _colorRangeCardOffset;
    if (nextOffset == Offset.zero) {
      nextOffset = _initialColorRangeCardOffset();
    } else {
      nextOffset = _clampColorRangeCardOffset(
        _colorRangeCardOffset,
        _colorRangeCardSize,
      );
    }
    setState(() {
      _colorRangeCardOffset = nextOffset;
      _colorRangeCardVisible = true;
      _colorRangeLoading = true;
    });
    final int count = await _computeLayerColorCount(activeLayer);
    if (!mounted || _colorRangeSession?.layerId != activeLayerId) {
      return;
    }
    if (count <= 0) {
      setState(() {
        _colorRangeLoading = false;
        _colorRangeCardVisible = false;
      });
      _showFilterMessage('当前图层没有可处理的颜色。');
      _teardownColorRangeSession(restoreOriginal: false);
      return;
    }
    final int maxSelectable =
        math.min(_kColorRangeMaxSelectableColors, math.max(1, count));
    setState(() {
      _colorRangeTotalColors = count;
      final int previous = _colorRangeSelectedColors;
      _colorRangeSelectedColors =
          previous > 0 ? previous.clamp(1, maxSelectable) : maxSelectable;
      _colorRangeLoading = false;
    });
    _scheduleColorRangePreview(immediate: true);
  }

  void hideColorRangeCard() {
    _cancelColorRangeEditing();
  }

  void _updateColorRangeCardOffset(Offset delta) {
    if (!_colorRangeCardVisible) {
      return;
    }
    setState(() {
      _colorRangeCardOffset = _clampColorRangeCardOffset(
        _colorRangeCardOffset + delta,
        _colorRangeCardSize,
      );
    });
  }

  void _handleColorRangeCardSizeChanged(Size size) {
    if (_colorRangeCardSize == size) {
      return;
    }
    setState(() {
      _colorRangeCardSize = size;
      _colorRangeCardOffset = _clampColorRangeCardOffset(
        _colorRangeCardOffset,
        size,
      );
    });
  }

  void _updateColorRangeSelection(double value) {
    if (!_colorRangeCardVisible || _colorRangeSession == null) {
      return;
    }
    if (_colorRangeLoading || _colorRangeApplying) {
      return;
    }
    final int maxColors = _colorRangeMaxSelectable();
    final int clamped = value.round().clamp(1, maxColors);
    if (clamped == _colorRangeSelectedColors) {
      return;
    }
    setState(() {
      _colorRangeSelectedColors = clamped;
    });
    _scheduleColorRangePreview();
  }

  int _colorRangeMaxSelectable() {
    final int total = math.max(1, _colorRangeTotalColors);
    return math.min(_kColorRangeMaxSelectableColors, total);
  }

  void _resetColorRangeSelection() {
    if (_colorRangeSession == null || !_colorRangeCardVisible) {
      return;
    }
    final int target = _colorRangeMaxSelectable();
    if (_colorRangeSelectedColors == target && !_colorRangePreviewInFlight) {
      _scheduleColorRangePreview(immediate: true);
      return;
    }
    setState(() {
      _colorRangeSelectedColors = target;
    });
    _scheduleColorRangePreview(immediate: true);
  }

  void _scheduleColorRangePreview({bool immediate = false}) {
    if (_colorRangeSession == null ||
        !_colorRangeCardVisible ||
        _colorRangeLoading) {
      return;
    }
    _colorRangePreviewScheduled = true;
    _colorRangePreviewDebounceTimer?.cancel();
    if (immediate) {
      unawaited(_runColorRangePreview());
      return;
    }
    _colorRangePreviewDebounceTimer = Timer(
      _kColorRangePreviewDebounceDuration,
      () => unawaited(_runColorRangePreview()),
    );
  }

  Future<void> _runColorRangePreview() async {
    _colorRangePreviewDebounceTimer?.cancel();
    _colorRangePreviewDebounceTimer = null;
    if (_colorRangePreviewInFlight) {
      _colorRangePreviewScheduled = true;
      return;
    }
    final _ColorRangeSession? session = _colorRangeSession;
    if (session == null || !_colorRangeCardVisible) {
      _colorRangePreviewScheduled = false;
      return;
    }
    _colorRangePreviewScheduled = false;
    final int availableColors = math.max(1, _colorRangeTotalColors);
    final int targetColors = math.max(
      1,
      math.min(_colorRangeSelectedColors, _colorRangeMaxSelectable()),
    );
    if (targetColors >= availableColors) {
      _restoreColorRangePreviewToOriginal(session);
      if (mounted) {
        setState(() {});
      }
      return;
    }
    final int token = ++_colorRangePreviewToken;
    setState(() {
      _colorRangePreviewInFlight = true;
    });
    final CanvasLayerData baseLayer =
        session.originalLayers[session.activeLayerIndex];
    try {
      final _ColorRangeComputeResult result = await _generateColorRangeResult(
        baseLayer.bitmap,
        baseLayer.fillColor,
        targetColors,
      );
      if (!mounted ||
          token != _colorRangePreviewToken ||
          _colorRangeSession?.layerId != session.layerId) {
        return;
      }
      final CanvasLayerData adjusted =
          _buildColorRangeAdjustedLayer(baseLayer, result);
      session.previewLayer = adjusted;
      _controller.replaceLayer(session.layerId, adjusted);
      _controller.setActiveLayer(session.layerId);
      setState(() {});
    } catch (error, stackTrace) {
      debugPrint('Color range preview failed: $error\n$stackTrace');
      if (mounted) {
        _showFilterMessage('生成色彩范围预览失败，请重试。');
      }
    } finally {
      if (mounted) {
        setState(() {
          _colorRangePreviewInFlight = false;
        });
      } else {
        _colorRangePreviewInFlight = false;
      }
    }
    if (_colorRangePreviewScheduled) {
      unawaited(_runColorRangePreview());
    }
  }

  Future<void> _applyColorRangeSelection() async {
    final _ColorRangeSession? session = _colorRangeSession;
    if (session == null || _colorRangeLoading || !_colorRangeCardVisible) {
      return;
    }
    if (_colorRangeApplying) {
      return;
    }
    final int availableColors = math.max(1, _colorRangeTotalColors);
    final int targetColors = math.max(
      1,
      math.min(_colorRangeSelectedColors, _colorRangeMaxSelectable()),
    );
    if (targetColors >= availableColors) {
      _showFilterMessage('目标颜色数量不少于当前颜色数量，图层保持不变。');
      hideColorRangeCard();
      return;
    }
    setState(() {
      _colorRangeApplying = true;
    });
    final CanvasLayerData baseLayer =
        session.originalLayers[session.activeLayerIndex];
    try {
      final _ColorRangeComputeResult result = await _generateColorRangeResult(
        baseLayer.bitmap,
        baseLayer.fillColor,
        targetColors,
      );
      if (!mounted) {
        return;
      }
      await _pushUndoSnapshot();
      final CanvasLayerData adjusted =
          _buildColorRangeAdjustedLayer(baseLayer, result);
      _controller.replaceLayer(session.layerId, adjusted);
      _controller.setActiveLayer(session.layerId);
      _markDirty();
      setState(() {
        _colorRangeApplying = false;
        _colorRangeCardVisible = false;
      });
      _teardownColorRangeSession(restoreOriginal: false);
    } catch (error, stackTrace) {
      debugPrint('Apply color range failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _colorRangeApplying = false;
        });
        _showFilterMessage('应用色彩范围失败，请重试。');
      }
    }
  }

  void _cancelColorRangeEditing() {
    _teardownColorRangeSession();
    if (mounted) {
      setState(() {
        _colorRangeCardVisible = false;
        _colorRangeLoading = false;
        _colorRangeApplying = false;
      });
    }
  }

  void _teardownColorRangeSession({bool restoreOriginal = true}) {
    _colorRangePreviewDebounceTimer?.cancel();
    _colorRangePreviewDebounceTimer = null;
    _colorRangePreviewScheduled = false;
    _colorRangePreviewToken++;
    final _ColorRangeSession? session = _colorRangeSession;
    if (restoreOriginal && session != null) {
      _restoreColorRangePreviewToOriginal(session);
    }
    _colorRangeSession = null;
    _colorRangePreviewInFlight = false;
  }

  void _restoreColorRangePreviewToOriginal(_ColorRangeSession session) {
    if (session.previewLayer == null) {
      return;
    }
    final CanvasLayerData original =
        session.originalLayers[session.activeLayerIndex];
    _controller.replaceLayer(session.layerId, original);
    _controller.setActiveLayer(session.layerId);
    session.previewLayer = null;
    if (mounted) {
      setState(() {});
    }
  }

  bool _isInsideColorRangeCardArea(Offset workspacePosition) {
    if (!_colorRangeCardVisible) {
      return false;
    }
    final Size size =
        _colorRangeCardSize ??
        const Size(_kColorRangePanelWidth, _kColorRangePanelMinHeight);
    final Rect rect = Rect.fromLTWH(
      _colorRangeCardOffset.dx,
      _colorRangeCardOffset.dy,
      size.width,
      size.height,
    );
    return rect.contains(workspacePosition);
  }

  Offset _initialColorRangeCardOffset() {
    return _workspacePanelSpawnOffset(
      this,
      panelWidth: _kColorRangePanelWidth,
      panelHeight: _kColorRangePanelMinHeight,
      additionalDy: _antialiasCardVisible ? 32 : 0,
    );
  }

  Offset _clampColorRangeCardOffset(Offset value, Size? size) {
    if (_workspaceSize.isEmpty) {
      return value;
    }
    final double width = size?.width ?? _kColorRangePanelWidth;
    final double height = size?.height ?? _kColorRangePanelMinHeight;
    const double margin = 12.0;
    final double minX = margin;
    final double minY = margin;
    final double maxX = math.max(minX, _workspaceSize.width - width - margin);
    final double maxY = math.max(minY, _workspaceSize.height - height - margin);
    return Offset(value.dx.clamp(minX, maxX), value.dy.clamp(minY, maxY));
  }

  Future<int> _computeLayerColorCount(CanvasLayerData layer) async {
    final Uint8List? bitmap = layer.bitmap;
    final int? fillColor = layer.fillColor?.value;
    final bool hasFill = fillColor != null && ((fillColor >> 24) & 0xFF) != 0;
    if ((bitmap == null || bitmap.isEmpty) && !hasFill) {
      return 0;
    }
    try {
      return await compute(
        _countUniqueColorsForLayer,
        <Object?>[bitmap, fillColor],
      );
    } catch (_) {
      return _countUniqueColorsForLayer(<Object?>[bitmap, fillColor]);
    }
  }

}

class _HueSaturationControls extends StatelessWidget {
  const _HueSaturationControls({
    required this.settings,
    required this.onHueChanged,
    required this.onSaturationChanged,
    required this.onLightnessChanged,
  });

  final _HueSaturationSettings settings;
  final ValueChanged<double> onHueChanged;
  final ValueChanged<double> onSaturationChanged;
  final ValueChanged<double> onLightnessChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FilterSlider(
          label: '色相',
          value: settings.hue,
          min: -180,
          max: 180,
          onChanged: onHueChanged,
        ),
        _FilterSlider(
          label: '饱和度',
          value: settings.saturation,
          min: -100,
          max: 100,
          onChanged: onSaturationChanged,
        ),
        _FilterSlider(
          label: '明度',
          value: settings.lightness,
          min: -100,
          max: 100,
          onChanged: onLightnessChanged,
        ),
      ],
    );
  }
}

class _BrightnessContrastControls extends StatelessWidget {
  const _BrightnessContrastControls({
    required this.settings,
    required this.onBrightnessChanged,
    required this.onContrastChanged,
  });

  final _BrightnessContrastSettings settings;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onContrastChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FilterSlider(
          label: '亮度',
          value: settings.brightness,
          min: -100,
          max: 100,
          onChanged: onBrightnessChanged,
        ),
        _FilterSlider(
          label: '对比度',
          value: settings.contrast,
          min: -100,
          max: 100,
          onChanged: onContrastChanged,
        ),
      ],
    );
  }
}

class _BlackWhiteControls extends StatelessWidget {
  const _BlackWhiteControls({
    required this.settings,
    required this.onBlackPointChanged,
    required this.onWhitePointChanged,
    required this.onMidToneChanged,
  });

  final _BlackWhiteSettings settings;
  final ValueChanged<double> onBlackPointChanged;
  final ValueChanged<double> onWhitePointChanged;
  final ValueChanged<double> onMidToneChanged;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FilterSlider(
          label: '黑场',
          value: settings.blackPoint,
          min: 0,
          max: 100,
          onChanged: onBlackPointChanged,
        ),
        _FilterSlider(
          label: '白场',
          value: settings.whitePoint,
          min: 0,
          max: 100,
          onChanged: onWhitePointChanged,
        ),
        _FilterSlider(
          label: '中间灰',
          value: settings.midTone,
          min: -100,
          max: 100,
          onChanged: onMidToneChanged,
        ),
        const SizedBox(height: 8),
        Text(
          '将图像转换为灰度后微调黑场、白场与中间灰。白场会自动保持略高于黑场，避免出现色阶断层。',
          style: theme.typography.caption,
        ),
      ],
    );
  }
}

class _BinarizeControls extends StatelessWidget {
  const _BinarizeControls({
    required this.threshold,
    required this.onThresholdChanged,
  });

  final double threshold;
  final ValueChanged<double> onThresholdChanged;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final double clamped = threshold.clamp(0.0, 255.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text('透明度阈值', style: theme.typography.bodyStrong),
            const Spacer(),
            Text(clamped.toStringAsFixed(0), style: theme.typography.caption),
          ],
        ),
        Slider(
          min: 0,
          max: 255,
          divisions: 255,
          value: clamped,
          onChanged: onThresholdChanged,
        ),
        const SizedBox(height: 8),
        Text(
          '低于阈值的半透明像素会被清除，其余像素提升为全不透明。默认阈值 128，适用于赛璐璐线稿与色块二值化。',
          style: theme.typography.caption,
        ),
      ],
    );
  }
}

class _GaussianBlurStepSegment {
  _GaussianBlurStepSegment({
    required this.start,
    required this.end,
    required this.step,
  }) : assert(end > start),
       assert(step > 0),
       assert(() {
         final double count = (end - start) / step;
         return (count - count.round()).abs() < 1e-6;
       }());

  final double start;
  final double end;
  final double step;

  int get stepCount => ((end - start) / step).round();
}

class _GaussianBlurSliderScale {
  _GaussianBlurSliderScale(this.segments)
    : assert(segments.isNotEmpty),
      assert(segments.last.end >= _kGaussianBlurMaxRadius);

  final List<_GaussianBlurStepSegment> segments;

  int get totalSteps => _totalSteps ??= _computeTotalSteps();
  int? _totalSteps;

  int _computeTotalSteps() {
    int steps = 0;
    for (final _GaussianBlurStepSegment segment in segments) {
      steps += segment.stepCount;
    }
    return steps;
  }

  double sliderValueFromRadius(double radius) {
    final double clamped = radius.clamp(0.0, _kGaussianBlurMaxRadius);
    if (clamped <= 0) {
      return 0;
    }
    double sliderPosition = 0;
    for (final _GaussianBlurStepSegment segment in segments) {
      if (clamped <= segment.end) {
        final double offset = clamped - segment.start;
        final double steps = (offset / segment.step).clamp(
          0.0,
          segment.stepCount.toDouble(),
        );
        return (sliderPosition + steps).clamp(0.0, totalSteps.toDouble());
      }
      sliderPosition += segment.stepCount;
    }
    return totalSteps.toDouble();
  }

  double radiusFromSliderValue(double sliderValue) {
    final int stepIndex = sliderValue.round().clamp(0, totalSteps);
    if (stepIndex == 0) {
      return 0;
    }
    int remaining = stepIndex;
    for (final _GaussianBlurStepSegment segment in segments) {
      if (remaining <= segment.stepCount) {
        return (segment.start + remaining * segment.step).clamp(
          0.0,
          _kGaussianBlurMaxRadius,
        );
      }
      remaining -= segment.stepCount;
    }
    return _kGaussianBlurMaxRadius;
  }
}

final _GaussianBlurSliderScale _gaussianBlurSliderScale =
    _GaussianBlurSliderScale(<_GaussianBlurStepSegment>[
      _GaussianBlurStepSegment(start: 0, end: 2, step: 0.1),
      _GaussianBlurStepSegment(start: 2, end: 10, step: 0.2),
      _GaussianBlurStepSegment(start: 10, end: 50, step: 1),
      _GaussianBlurStepSegment(start: 50, end: 200, step: 5),
      _GaussianBlurStepSegment(start: 200, end: 500, step: 10),
      _GaussianBlurStepSegment(start: 500, end: 1000, step: 20),
    ]);

class _GaussianBlurControls extends StatelessWidget {
  const _GaussianBlurControls({
    required this.radius,
    required this.onRadiusChanged,
  });

  final double radius;
  final ValueChanged<double> onRadiusChanged;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final double clamped = radius.clamp(0, _kGaussianBlurMaxRadius);
    final double sliderValue = _gaussianBlurSliderScale.sliderValueFromRadius(
      clamped,
    );
    final int sliderDivisions = _gaussianBlurSliderScale.totalSteps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text('模糊半径', style: theme.typography.bodyStrong),
            const Spacer(),
            Text(
              '${clamped.toStringAsFixed(1)} px',
              style: theme.typography.caption,
            ),
          ],
        ),
        Slider(
          min: 0,
          max: sliderDivisions.toDouble(),
          divisions: sliderDivisions,
          value: sliderValue,
          onChanged: (value) => onRadiusChanged(
            _gaussianBlurSliderScale.radiusFromSliderValue(value),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '调节模糊强度（0 - 1000 px）。滑块前段拥有更高的分辨率，向右拖动时步进会逐渐增大。',
          style: theme.typography.caption,
        ),
      ],
    );
  }
}

class _LeakRemovalControls extends StatelessWidget {
  const _LeakRemovalControls({
    required this.radius,
    required this.onRadiusChanged,
  });

  final double radius;
  final ValueChanged<double> onRadiusChanged;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final double clamped = radius.clamp(0, _kLeakRemovalMaxRadius);
    final int divisions = _kLeakRemovalMaxRadius.round().clamp(1, 1000).toInt();
    final int rounded = clamped.round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text('修复范围', style: theme.typography.bodyStrong),
            const Spacer(),
            Text('$rounded px', style: theme.typography.caption),
          ],
        ),
        Slider(
          min: 0,
          max: _kLeakRemovalMaxRadius,
          divisions: divisions,
          value: clamped,
          onChanged: onRadiusChanged,
        ),
        const SizedBox(height: 8),
        Text(
          '填充完全被线稿包围的透明针眼，可设置填补半径（像素）。数值越大，可修复的漏色面积越大。',
          style: theme.typography.caption,
        ),
      ],
    );
  }
}

class _MorphologyControls extends StatelessWidget {
  const _MorphologyControls({
    required this.label,
    required this.radius,
    required this.maxRadius,
    required this.onRadiusChanged,
  });

  final String label;
  final double radius;
  final double maxRadius;
  final ValueChanged<double> onRadiusChanged;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final double clamped = radius.clamp(0, maxRadius);
    final int divisions = maxRadius.round().clamp(1, 1000).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(label, style: theme.typography.bodyStrong),
            const Spacer(),
            Text('${clamped.toStringAsFixed(0)} px',
                style: theme.typography.caption),
          ],
        ),
        Slider(
          min: 0,
          max: maxRadius,
          divisions: divisions,
          value: clamped,
          onChanged: onRadiusChanged,
        ),
        const SizedBox(height: 8),
        Text(
          '基于透明度的形态学处理。收窄会让轮廓内缩，拉伸会让覆盖区域向外扩张。',
          style: theme.typography.caption,
        ),
      ],
    );
  }
}

class _AntialiasPanelBody extends StatelessWidget {
  const _AntialiasPanelBody({
    required this.level,
    required this.onLevelChanged,
  });

  final int level;
  final ValueChanged<int> onLevelChanged;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final int safeLevel = level.clamp(0, 3).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('选择边缘柔化级别', style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        Text(
          '在平滑边缘的同时保留线条密度，呈现接近 Retas 的细腻质感。',
          style: theme.typography.caption,
        ),
        const SizedBox(height: 12),
        Slider(
          value: safeLevel.toDouble(),
          min: 0,
          max: 3,
          divisions: 3,
          label: '等级 $safeLevel',
          onChanged: (value) => onLevelChanged(value.round()),
        ),
        const SizedBox(height: 8),
        Text(
          kAntialiasLevelDescriptions[safeLevel],
          style: theme.typography.caption,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List<Widget>.generate(4, (index) {
            final bool selected = index == safeLevel;
            final Widget button = selected
                ? FilledButton(
                    onPressed: () => onLevelChanged(index),
                    child: Text('等级 $index'),
                  )
                : Button(
                    onPressed: () => onLevelChanged(index),
                    child: Text('等级 $index'),
                  );
            return SizedBox(width: 72, child: button);
          }),
        ),
      ],
    );
  }
}

class _ColorRangeCardBody extends StatelessWidget {
  const _ColorRangeCardBody({
    required this.totalColors,
    required this.maxSelectableColors,
    required this.selectedColors,
    required this.isBusy,
    required this.onChanged,
  });

  final int totalColors;
  final int maxSelectableColors;
  final int selectedColors;
  final bool isBusy;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final int maxColors = math.max(1, maxSelectableColors);
    final int clampedSelection = selectedColors.clamp(1, maxColors).toInt();
    final int? divisions = maxColors > 1
        ? (maxColors <= 200 ? math.max(1, maxColors - 1) : null)
        : null;
    final bool limited = totalColors > maxSelectableColors;
    final bool sliderEnabled = !isBusy && maxColors > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text('色彩数量', style: theme.typography.bodyStrong),
            const Spacer(),
            if (isBusy)
              const SizedBox(
                width: 16,
                height: 16,
                child: ProgressRing(strokeWidth: 2),
              )
            else
              Text(
                '$clampedSelection / $maxColors 种',
                style: theme.typography.caption,
              ),
          ],
        ),
        Slider(
          min: 1,
          max: maxColors.toDouble(),
          value: clampedSelection.toDouble(),
          divisions: divisions,
          onChanged: sliderEnabled ? onChanged : null,
        ),
        const SizedBox(height: 8),
        Text(
          limited
              ? '当前图层包含 $totalColors 种颜色，为保证性能最多保留 $maxSelectableColors 种。'
              : '检测到当前图层包含 $maxColors 种颜色。拖动滑块标记需要保留的颜色数量。',
          style: theme.typography.caption,
        ),
        const SizedBox(height: 6),
        Text(
          '降低颜色数量会产生类似木刻/分色的效果，滑动后立即预览。',
          style: theme.typography.caption,
        ),
      ],
    );
  }
}

class _FilterSlider extends StatelessWidget {
  const _FilterSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: theme.typography.bodyStrong),
              const Spacer(),
              Text(value.toStringAsFixed(0), style: theme.typography.caption),
            ],
          ),
          Slider(
            min: min,
            max: max,
            value: value.clamp(min, max),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

const int _kFilterTypeHueSaturation = 0;
const int _kFilterTypeBrightnessContrast = 1;
const int _kFilterTypeBlackWhite = 2;
const int _kFilterTypeGaussianBlur = 3;
const int _kFilterTypeLeakRemoval = 4;
const int _kFilterTypeLineNarrow = 5;
const int _kFilterTypeFillExpand = 6;
const int _kFilterTypeBinarize = 7;

class _FilterPreviewWorker {
  _FilterPreviewWorker({
    required _FilterPanelType type,
    required String layerId,
    required CanvasLayerData baseLayer,
    required int canvasWidth,
    required int canvasHeight,
    required ValueChanged<_FilterPreviewResult> onResult,
    required void Function(Object error, StackTrace stackTrace) onError,
  }) : _type = type,
       _layerId = layerId,
       _canvasWidth = canvasWidth,
       _canvasHeight = canvasHeight,
       _onResult = onResult,
       _onError = onError {
    _start(baseLayer);
  }

  final _FilterPanelType _type;
  final String _layerId;
  final int _canvasWidth;
  final int _canvasHeight;
  final ValueChanged<_FilterPreviewResult> _onResult;
  final void Function(Object error, StackTrace stackTrace) _onError;

  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _sendPort;
  StreamSubscription<dynamic>? _subscription;
  final Completer<void> _readyCompleter = Completer<void>();
  bool _useMainThreadPreview = false;
  Uint8List? _baseBitmapSnapshot;
  int? _baseFillColorValue;
  int _baseBitmapWidth = 0;
  int _baseBitmapHeight = 0;
  bool _disposed = false;

  Future<void> _start(CanvasLayerData layer) async {
    if (kIsWeb) {
      _initializeSynchronousLayer(layer);
      return;
    }
    final TransferableTypedData? bitmapData = layer.bitmap != null
        ? TransferableTypedData.fromList(<Uint8List>[layer.bitmap!])
        : null;
    int filterType;
    switch (_type) {
      case _FilterPanelType.hueSaturation:
        filterType = _kFilterTypeHueSaturation;
        break;
      case _FilterPanelType.brightnessContrast:
        filterType = _kFilterTypeBrightnessContrast;
        break;
      case _FilterPanelType.blackWhite:
        filterType = _kFilterTypeBlackWhite;
        break;
      case _FilterPanelType.binarize:
        filterType = _kFilterTypeBinarize;
        break;
      case _FilterPanelType.gaussianBlur:
        filterType = _kFilterTypeGaussianBlur;
        break;
      case _FilterPanelType.leakRemoval:
        filterType = _kFilterTypeLeakRemoval;
        break;
      case _FilterPanelType.lineNarrow:
        filterType = _kFilterTypeLineNarrow;
        break;
      case _FilterPanelType.fillExpand:
        filterType = _kFilterTypeFillExpand;
        break;
    }
    final Map<String, Object?> initData = <String, Object?>{
      'type': filterType,
      'layerId': _layerId,
      'layer': <String, Object?>{
        'bitmap': bitmapData,
        'bitmapWidth': layer.bitmapWidth,
        'bitmapHeight': layer.bitmapHeight,
        'bitmapLeft': layer.bitmapLeft,
        'bitmapTop': layer.bitmapTop,
        'fillColor': layer.fillColor?.value,
        'canvasWidth': _canvasWidth,
        'canvasHeight': _canvasHeight,
      },
    };
    final ReceivePort port = ReceivePort();
    _receivePort = port;
    _subscription = port.listen(
      (dynamic message) {
        if (message is SendPort) {
          _sendPort = message;
          if (!_readyCompleter.isCompleted) {
            _readyCompleter.complete();
          }
          return;
        }
        if (message is Map<String, Object?>) {
          final _FilterPreviewResult result = _FilterPreviewResult(
            token: message['token'] as int? ?? -1,
            layerId: message['layerId'] as String? ?? _layerId,
            bitmapData: message['bitmap'] as TransferableTypedData?,
            fillColor: message['fillColor'] as int?,
          );
          if (!_disposed) {
            _onResult(result);
          }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_readyCompleter.isCompleted) {
          _readyCompleter.completeError(error, stackTrace);
        }
        _onError(error, stackTrace);
      },
    );
    try {
      _isolate = await Isolate.spawn<List<Object?>>(
        _filterPreviewWorkerMain,
        <Object?>[port.sendPort, initData],
        debugName: 'FilterPreviewWorker',
        errorsAreFatal: false,
      );
    } on Object catch (error, stackTrace) {
      await _subscription?.cancel();
      _subscription = null;
      _receivePort = null;
      port.close();
      _isolate = null;
      debugPrint('Filter preview worker isolate unavailable: $error');
      _initializeSynchronousLayer(layer);
    }
  }

  void _initializeSynchronousLayer(CanvasLayerData layer) {
    _useMainThreadPreview = true;
    _baseBitmapSnapshot = layer.bitmap != null
        ? Uint8List.fromList(layer.bitmap!)
        : null;
    _baseFillColorValue = layer.fillColor?.value;
    _baseBitmapWidth = layer.bitmapWidth ?? _canvasWidth;
    _baseBitmapHeight = layer.bitmapHeight ?? _canvasHeight;
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }
  }

  Future<void> requestPreview({
    required int token,
    required _HueSaturationSettings hueSaturation,
    required _BrightnessContrastSettings brightnessContrast,
    required _BlackWhiteSettings blackWhite,
    required double blurRadius,
    required double leakRadius,
    required double morphRadius,
    required double binarizeThreshold,
  }) async {
    if (_disposed) {
      return;
    }
    try {
      await _readyCompleter.future;
    } catch (_) {
      return;
    }
    if (_useMainThreadPreview) {
      _runPreviewSynchronously(
        token: token,
        hueSaturation: hueSaturation,
        brightnessContrast: brightnessContrast,
        blackWhite: blackWhite,
        blurRadius: blurRadius,
        leakRadius: leakRadius,
        morphRadius: morphRadius,
        binarizeThreshold: binarizeThreshold,
      );
      return;
    }
    final SendPort? port = _sendPort;
    if (port == null) {
      return;
    }
    port.send(<String, Object?>{
      'kind': 'preview',
      'token': token,
      'hue': <double>[
        hueSaturation.hue,
        hueSaturation.saturation,
        hueSaturation.lightness,
      ],
      'brightness': <double>[
        brightnessContrast.brightness,
        brightnessContrast.contrast,
      ],
      'blackWhite': <double>[
        blackWhite.blackPoint,
        blackWhite.whitePoint,
        blackWhite.midTone,
      ],
      'blur': blurRadius,
      'leakRadius': leakRadius,
      'morph': morphRadius,
      'binarize': binarizeThreshold,
    });
  }

  void _runPreviewSynchronously({
    required int token,
    required _HueSaturationSettings hueSaturation,
    required _BrightnessContrastSettings brightnessContrast,
    required _BlackWhiteSettings blackWhite,
    required double blurRadius,
    required double leakRadius,
    required double morphRadius,
    required double binarizeThreshold,
  }) {
    Uint8List? bitmap;
    final Uint8List? source = _baseBitmapSnapshot;
    if (source != null) {
      bitmap = Uint8List.fromList(source);
      final int leakSteps = leakRadius.round().clamp(
        0,
        _kLeakRemovalMaxRadius.toInt(),
      );
      if (_type == _FilterPanelType.hueSaturation) {
        _filterApplyHueSaturationToBitmap(
          bitmap,
          hueSaturation.hue,
          hueSaturation.saturation,
          hueSaturation.lightness,
        );
      } else if (_type == _FilterPanelType.brightnessContrast) {
        _filterApplyBrightnessContrastToBitmap(
          bitmap,
          brightnessContrast.brightness,
          brightnessContrast.contrast,
        );
      } else if (_type == _FilterPanelType.blackWhite) {
        _filterApplyBlackWhiteToBitmap(
          bitmap,
          blackWhite.blackPoint,
          blackWhite.whitePoint,
          blackWhite.midTone,
        );
      } else if (_type == _FilterPanelType.binarize) {
        _filterApplyBinarizeToBitmap(
          bitmap,
          binarizeThreshold.round().clamp(0, 255),
        );
      } else if (_type == _FilterPanelType.gaussianBlur &&
          blurRadius > 0 &&
          _baseBitmapWidth > 0 &&
          _baseBitmapHeight > 0) {
        _filterApplyGaussianBlurToBitmap(
          bitmap,
          _baseBitmapWidth,
          _baseBitmapHeight,
          blurRadius,
        );
      } else if (_type == _FilterPanelType.leakRemoval &&
          leakSteps > 0 &&
          _baseBitmapWidth > 0 &&
          _baseBitmapHeight > 0) {
        _filterApplyLeakRemovalToBitmap(
          bitmap,
          _baseBitmapWidth,
          _baseBitmapHeight,
          leakSteps,
        );
      } else if (_type == _FilterPanelType.lineNarrow &&
          morphRadius > 0 &&
          _baseBitmapWidth > 0 &&
          _baseBitmapHeight > 0) {
        final int morphSteps = morphRadius
            .round()
            .clamp(1, _kMorphologyMaxRadius.toInt())
            .toInt();
        _filterApplyMorphologyToBitmap(
          bitmap,
          _baseBitmapWidth,
          _baseBitmapHeight,
          morphSteps,
          dilate: false,
        );
      } else if (_type == _FilterPanelType.fillExpand &&
          morphRadius > 0 &&
          _baseBitmapWidth > 0 &&
          _baseBitmapHeight > 0) {
        final int morphSteps = morphRadius
            .round()
            .clamp(1, _kMorphologyMaxRadius.toInt())
            .toInt();
        _filterApplyMorphologyToBitmap(
          bitmap,
          _baseBitmapWidth,
          _baseBitmapHeight,
          morphSteps,
          dilate: true,
        );
      }
      if (bitmap != null && !_filterBitmapHasVisiblePixels(bitmap)) {
        bitmap = null;
      }
    }
    int? adjustedFill = _baseFillColorValue;
    if (adjustedFill != null) {
      final Color baseColor = Color(adjustedFill);
      Color output = baseColor;
      if (_type == _FilterPanelType.hueSaturation) {
        output = _filterApplyHueSaturationToColor(
          baseColor,
          hueSaturation.hue,
          hueSaturation.saturation,
          hueSaturation.lightness,
        );
      } else if (_type == _FilterPanelType.brightnessContrast) {
        output = _filterApplyBrightnessContrastToColor(
          baseColor,
          brightnessContrast.brightness,
          brightnessContrast.contrast,
        );
      } else if (_type == _FilterPanelType.blackWhite) {
        output = _filterApplyBlackWhiteToColor(
          baseColor,
          blackWhite.blackPoint,
          blackWhite.whitePoint,
          blackWhite.midTone,
        );
      } else if (_type == _FilterPanelType.binarize) {
        output = _filterApplyBinarizeToColor(
          baseColor,
          binarizeThreshold.round().clamp(0, 255),
        );
      }
      adjustedFill = output.value;
    }
    final _FilterPreviewResult result = _FilterPreviewResult(
      token: token,
      layerId: _layerId,
      bitmapBytes: bitmap,
      fillColor: adjustedFill,
    );
    if (_disposed) {
      return;
    }
    scheduleMicrotask(() {
      if (!_disposed) {
        _onResult(result);
      }
    });
  }

  void discardPendingResult() {}

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final SendPort? port = _sendPort;
    port?.send(const <String, Object?>{'kind': 'dispose'});
    _subscription?.cancel();
    _receivePort?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _sendPort = null;
    _baseBitmapSnapshot = null;
    _baseFillColorValue = null;
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }
  }
}

class _FilterPreviewResult {
  _FilterPreviewResult({
    required this.token,
    required this.layerId,
    TransferableTypedData? bitmapData,
    Uint8List? bitmapBytes,
    this.fillColor,
  }) : _bitmapData = bitmapData,
       _bytes = bitmapBytes;

  final int token;
  final String layerId;
  final int? fillColor;
  TransferableTypedData? _bitmapData;
  Uint8List? _bytes;

  Uint8List? get bitmapBytes {
    if (_bytes != null) {
      return _bytes;
    }
    final TransferableTypedData? data = _bitmapData;
    if (data == null) {
      return null;
    }
    _bitmapData = null;
    _bytes = data.materialize().asUint8List();
    return _bytes;
  }
}

@pragma('vm:entry-point')
void _filterPreviewWorkerMain(List<Object?> initialMessage) {
  final SendPort parent = initialMessage[0] as SendPort;
  final Map<String, Object?> initData =
      (initialMessage[1] as Map<String, Object?>?) ?? const <String, Object?>{};
  final int type = initData['type'] as int? ?? _kFilterTypeHueSaturation;
  final String layerId = initData['layerId'] as String? ?? '';
  final Map<String, Object?> layer =
      (initData['layer'] as Map<String, Object?>?) ?? const <String, Object?>{};
  final TransferableTypedData? bitmapData =
      layer['bitmap'] as TransferableTypedData?;
  final Uint8List? baseBitmap = bitmapData != null
      ? bitmapData.materialize().asUint8List()
      : null;
  final int? fillColorValue = layer['fillColor'] as int?;
  final int canvasWidth = layer['canvasWidth'] as int? ?? 0;
  final int canvasHeight = layer['canvasHeight'] as int? ?? 0;
  final int bitmapWidth = layer['bitmapWidth'] as int? ?? canvasWidth;
  final int bitmapHeight = layer['bitmapHeight'] as int? ?? canvasHeight;
  final ReceivePort port = ReceivePort();
  parent.send(port.sendPort);
  port.listen((dynamic message) {
    if (message is! Map<String, Object?>) {
      return;
    }
    final String kind = message['kind'] as String? ?? '';
    if (kind == 'dispose') {
      port.close();
      return;
    }
    if (kind != 'preview') {
      return;
    }
    final int token = message['token'] as int? ?? -1;
    final List<dynamic>? rawHue = message['hue'] as List<dynamic>?;
    final List<dynamic>? rawBrightness =
        message['brightness'] as List<dynamic>?;
    final List<dynamic>? rawBlackWhite =
        message['blackWhite'] as List<dynamic>?;
    final double hueDelta = _filterReadListValue(rawHue, 0);
    final double saturationPercent = _filterReadListValue(rawHue, 1);
    final double lightnessPercent = _filterReadListValue(rawHue, 2);
    final double brightnessPercent = _filterReadListValue(rawBrightness, 0);
    final double contrastPercent = _filterReadListValue(rawBrightness, 1);
    final double blackPoint = _filterReadListValue(rawBlackWhite, 0);
    final double whitePoint = _filterReadListValue(rawBlackWhite, 1);
    final double midTone = _filterReadListValue(rawBlackWhite, 2);
    final double blurRadius = (message['blur'] is num)
        ? (message['blur'] as num).toDouble()
        : 0.0;
    final double leakRadius = (message['leakRadius'] is num)
        ? (message['leakRadius'] as num).toDouble()
        : 0.0;
    final double morphRadius = (message['morph'] is num)
        ? (message['morph'] as num).toDouble()
        : 0.0;
    final double binarizeThreshold = (message['binarize'] is num)
        ? (message['binarize'] as num).toDouble()
        : _kDefaultBinarizeAlphaThreshold;

    Uint8List? bitmap;
    if (baseBitmap != null) {
      bitmap = Uint8List.fromList(baseBitmap);
      final int leakSteps = leakRadius.round().clamp(
        0,
        _kLeakRemovalMaxRadius.toInt(),
      );
      if (type == _kFilterTypeHueSaturation) {
        _filterApplyHueSaturationToBitmap(
          bitmap,
          hueDelta,
          saturationPercent,
          lightnessPercent,
        );
      } else if (type == _kFilterTypeBrightnessContrast) {
        _filterApplyBrightnessContrastToBitmap(
          bitmap,
          brightnessPercent,
          contrastPercent,
        );
      } else if (type == _kFilterTypeBlackWhite) {
        _filterApplyBlackWhiteToBitmap(bitmap, blackPoint, whitePoint, midTone);
      } else if (type == _kFilterTypeBinarize) {
        _filterApplyBinarizeToBitmap(
          bitmap,
          binarizeThreshold.round().clamp(0, 255),
        );
      } else if (type == _kFilterTypeGaussianBlur &&
          blurRadius > 0 &&
          bitmapWidth > 0 &&
          bitmapHeight > 0) {
        _filterApplyGaussianBlurToBitmap(
          bitmap,
          bitmapWidth,
          bitmapHeight,
          blurRadius,
        );
      } else if (type == _kFilterTypeLeakRemoval &&
          leakSteps > 0 &&
          bitmapWidth > 0 &&
          bitmapHeight > 0) {
        _filterApplyLeakRemovalToBitmap(
          bitmap,
          bitmapWidth,
          bitmapHeight,
          leakSteps,
        );
      } else if (type == _kFilterTypeLineNarrow &&
          morphRadius > 0 &&
          bitmapWidth > 0 &&
          bitmapHeight > 0) {
        final int morphSteps = morphRadius
            .round()
            .clamp(1, _kMorphologyMaxRadius.toInt())
            .toInt();
        _filterApplyMorphologyToBitmap(
          bitmap,
          bitmapWidth,
          bitmapHeight,
          morphSteps,
          dilate: false,
        );
      } else if (type == _kFilterTypeFillExpand &&
          morphRadius > 0 &&
          bitmapWidth > 0 &&
          bitmapHeight > 0) {
        final int morphSteps = morphRadius
            .round()
            .clamp(1, _kMorphologyMaxRadius.toInt())
            .toInt();
        _filterApplyMorphologyToBitmap(
          bitmap,
          bitmapWidth,
          bitmapHeight,
          morphSteps,
          dilate: true,
        );
      }
      if (!_filterBitmapHasVisiblePixels(bitmap)) {
        bitmap = null;
      }
    }

    int? adjustedFill = fillColorValue;
    if (fillColorValue != null) {
      final Color source = Color(fillColorValue);
      Color adjusted = source;
      if (type == _kFilterTypeHueSaturation) {
        adjusted = _filterApplyHueSaturationToColor(
          source,
          hueDelta,
          saturationPercent,
          lightnessPercent,
        );
      } else if (type == _kFilterTypeBrightnessContrast) {
        adjusted = _filterApplyBrightnessContrastToColor(
          source,
          brightnessPercent,
          contrastPercent,
        );
      } else if (type == _kFilterTypeBlackWhite) {
        adjusted = _filterApplyBlackWhiteToColor(
          source,
          blackPoint,
          whitePoint,
          midTone,
        );
      } else if (type == _kFilterTypeBinarize) {
        adjusted = _filterApplyBinarizeToColor(
          source,
          binarizeThreshold.round().clamp(0, 255),
        );
      }
      adjustedFill = adjusted.value;
    }

    parent.send(<String, Object?>{
      'token': token,
      'layerId': layerId,
      'bitmap': bitmap != null
          ? TransferableTypedData.fromList(<Uint8List>[bitmap])
          : null,
      'fillColor': adjustedFill,
    });
  });
}

double _filterReadListValue(List<dynamic>? values, int index) {
  if (values == null || index < 0 || index >= values.length) {
    return 0.0;
  }
  final Object value = values[index];
  if (value is num) {
    return value.toDouble();
  }
  return 0.0;
}

int _countUniqueColorsInRgba(Uint8List rgba) {
  if (rgba.isEmpty) {
    return 0;
  }
  final Set<int> colors = <int>{};
  for (int i = 0; i + 3 < rgba.length; i += 4) {
    final int alpha = rgba[i + 3];
    if (alpha == 0) {
      continue;
    }
    final int color =
        (rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2];
    colors.add(color);
  }
  return colors.length;
}

int _countUniqueColorsForLayer(List<Object?> args) {
  final Uint8List? bitmap = args[0] as Uint8List?;
  final int? fillColor = args[1] as int?;
  return _buildColorHistogram(bitmap, fillColor).length;
}

Future<_ColorRangeComputeResult> _generateColorRangeResult(
  Uint8List? bitmap,
  Color? fillColor,
  int targetColors,
) async {
  final List<Object?> args = <Object?>[
    bitmap,
    fillColor?.value,
    targetColors,
  ];
  if (kIsWeb) {
    return _computeColorRangeReduction(args);
  }
  try {
    return await compute(_computeColorRangeReduction, args);
  } on UnsupportedError catch (_) {
    return _computeColorRangeReduction(args);
  }
}

_ColorRangeComputeResult _computeColorRangeReduction(List<Object?> args) {
  final Uint8List? bitmap = args[0] as Uint8List?;
  final int? fillColor = args[1] as int?;
  final int target = (args[2] as num?)?.toInt() ?? 1;
  return _applyColorRangeReduction(bitmap, fillColor, target);
}

_ColorRangeComputeResult _applyColorRangeReduction(
  Uint8List? bitmap,
  int? fillColor,
  int targetColors,
) {
  final Map<int, int> histogram = _buildColorHistogram(bitmap, fillColor);
  if (histogram.isEmpty) {
    return _ColorRangeComputeResult(
      bitmap: bitmap != null ? Uint8List.fromList(bitmap) : null,
      fillColor: fillColor,
    );
  }
  final int cappedTarget = math.max(
    1,
    math.min(targetColors, histogram.length),
  );
  if (cappedTarget >= histogram.length) {
    return _ColorRangeComputeResult(
      bitmap: bitmap != null ? Uint8List.fromList(bitmap) : null,
      fillColor: fillColor,
    );
  }
  final List<_ColorRangeBucket> buckets = <_ColorRangeBucket>[
    _ColorRangeBucket.fromHistogram(histogram),
  ];
  while (buckets.length < cappedTarget) {
    final int index = _colorRangeBucketToSplitIndex(buckets);
    if (index < 0) {
      break;
    }
    final _ColorRangeBucket bucket = buckets.removeAt(index);
    final List<_ColorRangeBucket> splits = bucket.split();
    if (splits.length != 2 || splits[0].isEmpty || splits[1].isEmpty) {
      buckets.add(bucket);
      break;
    }
    buckets.addAll(splits);
  }
  final List<int> palette =
      buckets.map((bucket) => bucket.averageColor).toList(growable: false);
  final Map<int, int> quantizedColorMap = <int, int>{};
  final Map<int, int> quantizedWeights = <int, int>{};
  histogram.forEach((int color, int count) {
    final int quantKey = _quantizeColorInt(color);
    final int mapped = _findNearestPaletteColor(color, palette);
    final int existingWeight = quantizedWeights[quantKey] ?? -1;
    if (count > existingWeight) {
      quantizedColorMap[quantKey] = mapped;
      quantizedWeights[quantKey] = count;
    }
  });
  Uint8List? reducedBitmap = bitmap != null ? Uint8List.fromList(bitmap) : null;
  if (reducedBitmap != null) {
    for (int i = 0; i + 3 < reducedBitmap.length; i += 4) {
      final int alpha = reducedBitmap[i + 3];
      if (alpha == 0) {
        continue;
      }
      final int quantKey = _quantizeColor(
        reducedBitmap[i],
        reducedBitmap[i + 1],
        reducedBitmap[i + 2],
      );
      final int mapped = quantizedColorMap[quantKey] ??
          _findNearestPaletteColor(quantKey, palette);
      reducedBitmap[i] = (mapped >> 16) & 0xFF;
      reducedBitmap[i + 1] = (mapped >> 8) & 0xFF;
      reducedBitmap[i + 2] = mapped & 0xFF;
    }
  }
  int? mappedFill = fillColor;
  if (fillColor != null) {
    final int alpha = (fillColor >> 24) & 0xFF;
    if (alpha != 0) {
      final int quantKey = _quantizeColorInt(fillColor & 0xFFFFFF);
      final int mapped = quantizedColorMap[quantKey] ??
          _findNearestPaletteColor(quantKey, palette);
      mappedFill = (fillColor & 0xFF000000) | mapped;
    }
  }
  return _ColorRangeComputeResult(
    bitmap: reducedBitmap,
    fillColor: mappedFill,
  );
}

int _quantizeColor(int r, int g, int b) {
  final int qr = (r ~/ _kColorRangeQuantizationStep) *
      _kColorRangeQuantizationStep;
  final int qg = (g ~/ _kColorRangeQuantizationStep) *
      _kColorRangeQuantizationStep;
  final int qb = (b ~/ _kColorRangeQuantizationStep) *
      _kColorRangeQuantizationStep;
  return (qr << 16) | (qg << 8) | qb;
}

int _quantizeColorInt(int color) {
  return _quantizeColor(
    (color >> 16) & 0xFF,
    (color >> 8) & 0xFF,
    color & 0xFF,
  );
}

class _ColorRangeHistogramBucket {
  _ColorRangeHistogramBucket();

  int count = 0;
  int sumR = 0;
  int sumG = 0;
  int sumB = 0;
}

Map<int, int> _buildColorHistogram(Uint8List? bitmap, int? fillColor) {
  final Map<int, _ColorRangeHistogramBucket> buckets =
      <int, _ColorRangeHistogramBucket>{};

  void addColor(int r, int g, int b) {
    final int qr = (r ~/ _kColorRangeQuantizationStep) *
        _kColorRangeQuantizationStep;
    final int qg = (g ~/ _kColorRangeQuantizationStep) *
        _kColorRangeQuantizationStep;
    final int qb = (b ~/ _kColorRangeQuantizationStep) *
        _kColorRangeQuantizationStep;
    final int key = (qr << 16) | (qg << 8) | qb;
    final _ColorRangeHistogramBucket bucket = buckets.putIfAbsent(
      key,
      _ColorRangeHistogramBucket.new,
    );
    bucket.count += 1;
    bucket.sumR += r;
    bucket.sumG += g;
    bucket.sumB += b;
  }

  if (bitmap != null) {
    for (int i = 0; i + 3 < bitmap.length; i += 4) {
      final int alpha = bitmap[i + 3];
      if (alpha < _kColorRangeAlphaThreshold) {
        continue;
      }
      addColor(bitmap[i], bitmap[i + 1], bitmap[i + 2]);
    }
  }
  if (fillColor != null) {
    final int alpha = (fillColor >> 24) & 0xFF;
    if (alpha >= _kColorRangeAlphaThreshold) {
      addColor(
        (fillColor >> 16) & 0xFF,
        (fillColor >> 8) & 0xFF,
        fillColor & 0xFF,
      );
    }
  }

  final Map<int, int> histogram = <int, int>{};
  buckets.forEach((_, _ColorRangeHistogramBucket bucket) {
    final int count = math.max(bucket.count, 1);
    final int r = (bucket.sumR / count).round().clamp(0, 255);
    final int g = (bucket.sumG / count).round().clamp(0, 255);
    final int b = (bucket.sumB / count).round().clamp(0, 255);
    final int color = (r << 16) | (g << 8) | b;
    histogram[color] = (histogram[color] ?? 0) + bucket.count;
  });

  if (histogram.length <= 1) {
    return histogram;
  }
  return _mergeSmallHistogramBuckets(histogram);
}

Map<int, int> _mergeSmallHistogramBuckets(Map<int, int> histogram) {
  final int total = histogram.values.fold<int>(0, (int acc, int value) {
    return acc + value;
  });
  if (total <= 0) {
    return histogram;
  }
  final int minCount = math.max(
    _kColorRangeMinBucketSize,
    (total * _kColorRangeSmallBucketFraction).round(),
  );
  if (minCount <= 1) {
    return histogram;
  }
  final List<MapEntry<int, int>> sorted = histogram.entries.toList()
    ..sort((MapEntry<int, int> a, MapEntry<int, int> b) {
      return b.value.compareTo(a.value);
    });
  final List<int> anchors = sorted
      .where((MapEntry<int, int> entry) => entry.value >= minCount)
      .map((MapEntry<int, int> entry) => entry.key)
      .toList();
  if (anchors.isEmpty) {
    return histogram;
  }
  final Map<int, int> merged = <int, int>{};
  for (final MapEntry<int, int> entry in sorted) {
    if (entry.value >= minCount) {
      merged[entry.key] = (merged[entry.key] ?? 0) + entry.value;
      continue;
    }
    final int nearest = _findNearestPaletteColor(entry.key, anchors);
    merged[nearest] = (merged[nearest] ?? 0) + entry.value;
  }
  return merged;
}

class _ColorRangeComputeResult {
  _ColorRangeComputeResult({this.bitmap, this.fillColor});

  final Uint8List? bitmap;
  final int? fillColor;
}

class _ColorCountEntry {
  _ColorCountEntry({required this.color, required this.count});

  final int color;
  final int count;

  int get r => (color >> 16) & 0xFF;
  int get g => (color >> 8) & 0xFF;
  int get b => color & 0xFF;

  int component(int channel) {
    switch (channel) {
      case 0:
        return r;
      case 1:
        return g;
      default:
        return b;
    }
  }
}

class _ColorRangeBucket {
  _ColorRangeBucket(this.entries) {
    _recomputeBounds();
  }

  _ColorRangeBucket.fromHistogram(Map<int, int> histogram)
    : entries = histogram.entries
          .map((entry) => _ColorCountEntry(
                color: entry.key,
                count: entry.value,
              ))
          .toList() {
    _recomputeBounds();
  }

  final List<_ColorCountEntry> entries;
  int _minR = 0;
  int _maxR = 0;
  int _minG = 0;
  int _maxG = 0;
  int _minB = 0;
  int _maxB = 0;
  int totalCount = 0;

  bool get isEmpty => entries.isEmpty;

  int get maxRange => math.max(
    _maxR - _minR,
    math.max(_maxG - _minG, _maxB - _minB),
  );

  int get averageColor {
    if (entries.isEmpty || totalCount <= 0) {
      return 0;
    }
    int rSum = 0;
    int gSum = 0;
    int bSum = 0;
    for (final _ColorCountEntry entry in entries) {
      rSum += entry.r * entry.count;
      gSum += entry.g * entry.count;
      bSum += entry.b * entry.count;
    }
    final int r = (rSum / totalCount).round().clamp(0, 255).toInt();
    final int g = (gSum / totalCount).round().clamp(0, 255).toInt();
    final int b = (bSum / totalCount).round().clamp(0, 255).toInt();
    return (r << 16) | (g << 8) | b;
  }

  List<_ColorRangeBucket> split() {
    if (entries.length <= 1) {
      return <_ColorRangeBucket>[this];
    }
    final int channel = _dominantChannel();
    final List<_ColorCountEntry> sorted = List<_ColorCountEntry>.from(entries)
      ..sort((a, b) => a.component(channel).compareTo(b.component(channel)));
    final int medianTarget = totalCount ~/ 2;
    int running = 0;
    int splitIndex = 0;
    for (int i = 0; i < sorted.length; i++) {
      running += sorted[i].count;
      splitIndex = i;
      if (running >= medianTarget) {
        break;
      }
    }
    final List<_ColorCountEntry> first = sorted.sublist(0, splitIndex + 1);
    final List<_ColorCountEntry> second =
        sorted.sublist(splitIndex + 1, sorted.length);
    if (first.isEmpty || second.isEmpty) {
      final int mid = sorted.length ~/ 2;
      return <_ColorRangeBucket>[
        _ColorRangeBucket(sorted.sublist(0, mid)),
        _ColorRangeBucket(sorted.sublist(mid)),
      ];
    }
    return <_ColorRangeBucket>[
      _ColorRangeBucket(first),
      _ColorRangeBucket(second),
    ];
  }

  int _dominantChannel() {
    final int rRange = _maxR - _minR;
    final int gRange = _maxG - _minG;
    final int bRange = _maxB - _minB;
    if (rRange >= gRange && rRange >= bRange) {
      return 0;
    }
    if (gRange >= rRange && gRange >= bRange) {
      return 1;
    }
    return 2;
  }

  void _recomputeBounds() {
    totalCount = 0;
    if (entries.isEmpty) {
      _minR = _minG = _minB = 0;
      _maxR = _maxG = _maxB = 0;
      return;
    }
    _minR = _minG = _minB = 255;
    _maxR = _maxG = _maxB = 0;
    for (final _ColorCountEntry entry in entries) {
      _minR = math.min(_minR, entry.r);
      _maxR = math.max(_maxR, entry.r);
      _minG = math.min(_minG, entry.g);
      _maxG = math.max(_maxG, entry.g);
      _minB = math.min(_minB, entry.b);
      _maxB = math.max(_maxB, entry.b);
      totalCount += entry.count;
    }
  }
}

int _colorRangeBucketToSplitIndex(List<_ColorRangeBucket> buckets) {
  int bestIndex = -1;
  int bestRange = -1;
  int bestCount = -1;
  for (int i = 0; i < buckets.length; i++) {
    final _ColorRangeBucket bucket = buckets[i];
    if (bucket.isEmpty || bucket.entries.length <= 1) {
      continue;
    }
    final int range = bucket.maxRange;
    if (range > bestRange ||
        (range == bestRange && bucket.totalCount > bestCount)) {
      bestRange = range;
      bestCount = bucket.totalCount;
      bestIndex = i;
    }
  }
  return bestIndex;
}

int _findNearestPaletteColor(int color, List<int> palette) {
  if (palette.isEmpty) {
    return color;
  }
  final int r = (color >> 16) & 0xFF;
  final int g = (color >> 8) & 0xFF;
  final int b = color & 0xFF;
  int bestColor = palette.first;
  int bestDistance = 0x7FFFFFFF;
  for (final int candidate in palette) {
    final int dr = r - ((candidate >> 16) & 0xFF);
    final int dg = g - ((candidate >> 8) & 0xFF);
    final int db = b - (candidate & 0xFF);
    final int distance = dr * dr + dg * dg + db * db;
    if (distance < bestDistance) {
      bestDistance = distance;
      bestColor = candidate;
      if (bestDistance == 0) {
        break;
      }
    }
  }
  return bestColor;
}

Future<Uint8List> _generateHueSaturationPreviewBytes(List<Object?> args) async {
  if (kIsWeb) {
    return _computeHueSaturationPreviewPixels(args);
  }
  try {
    return await compute<List<Object?>, Uint8List>(
      _computeHueSaturationPreviewPixels,
      args,
    );
  } on UnsupportedError catch (_) {
    return _computeHueSaturationPreviewPixels(args);
  }
}

Uint8List _computeHueSaturationPreviewPixels(List<Object?> args) {
  final Uint8List source = args[0] as Uint8List;
  final double hue = (args[1] as num).toDouble();
  final double saturation = (args[2] as num).toDouble();
  final double lightness = (args[3] as num).toDouble();
  final Uint8List pixels = Uint8List.fromList(source);
  _filterApplyHueSaturationToBitmap(pixels, hue, saturation, lightness);
  return pixels;
}

Future<Uint8List> _generateBlackWhitePreviewBytes(List<Object?> args) async {
  if (kIsWeb) {
    return _computeBlackWhitePreviewPixels(args);
  }
  try {
    return await compute<List<Object?>, Uint8List>(
      _computeBlackWhitePreviewPixels,
      args,
    );
  } on UnsupportedError catch (_) {
    return _computeBlackWhitePreviewPixels(args);
  }
}

Uint8List _computeBlackWhitePreviewPixels(List<Object?> args) {
  final Uint8List source = args[0] as Uint8List;
  final double black = (args[1] as num).toDouble();
  final double white = (args[2] as num).toDouble();
  final double midTone = (args[3] as num).toDouble();
  final Uint8List pixels = Uint8List.fromList(source);
  _filterApplyBlackWhiteToBitmap(pixels, black, white, midTone);
  return pixels;
}

void _filterApplyHueSaturationToBitmap(
  Uint8List bitmap,
  double hueDelta,
  double saturationPercent,
  double lightnessPercent,
) {
  for (int i = 0; i < bitmap.length; i += 4) {
    final int alpha = bitmap[i + 3];
    if (alpha == 0) {
      continue;
    }
    final Color source = Color.fromARGB(
      alpha,
      bitmap[i],
      bitmap[i + 1],
      bitmap[i + 2],
    );
    final Color adjusted = _filterApplyHueSaturationToColor(
      source,
      hueDelta,
      saturationPercent,
      lightnessPercent,
    );
    bitmap[i] = adjusted.red;
    bitmap[i + 1] = adjusted.green;
    bitmap[i + 2] = adjusted.blue;
    bitmap[i + 3] = adjusted.alpha;
  }
}

void _filterApplyBrightnessContrastToBitmap(
  Uint8List bitmap,
  double brightnessPercent,
  double contrastPercent,
) {
  final double brightnessOffset = brightnessPercent / 100.0 * 255.0;
  final double contrastFactor = math.max(0.0, 1.0 + contrastPercent / 100.0);
  for (int i = 0; i < bitmap.length; i += 4) {
    final int alpha = bitmap[i + 3];
    if (alpha == 0) {
      continue;
    }
    bitmap[i] = _filterApplyBrightnessContrastChannel(
      bitmap[i],
      brightnessOffset,
      contrastFactor,
    );
    bitmap[i + 1] = _filterApplyBrightnessContrastChannel(
      bitmap[i + 1],
      brightnessOffset,
      contrastFactor,
    );
    bitmap[i + 2] = _filterApplyBrightnessContrastChannel(
      bitmap[i + 2],
      brightnessOffset,
      contrastFactor,
    );
  }
}

Color _filterApplyHueSaturationToColor(
  Color color,
  double hueDelta,
  double saturationPercent,
  double lightnessPercent,
) {
  final HSVColor hsv = HSVColor.fromColor(color);
  double hue = (hsv.hue + hueDelta) % 360.0;
  if (hue < 0) {
    hue += 360.0;
  }
  final double saturation = (hsv.saturation + saturationPercent / 100.0).clamp(
    0.0,
    1.0,
  );
  final double value = (hsv.value + lightnessPercent / 100.0).clamp(0.0, 1.0);
  return HSVColor.fromAHSV(hsv.alpha, hue, saturation, value).toColor();
}

Color _filterApplyBrightnessContrastToColor(
  Color color,
  double brightnessPercent,
  double contrastPercent,
) {
  final double brightnessOffset = brightnessPercent / 100.0 * 255.0;
  final double contrastFactor = math.max(0.0, 1.0 + contrastPercent / 100.0);
  final int r = _filterApplyBrightnessContrastChannel(
    color.red,
    brightnessOffset,
    contrastFactor,
  );
  final int g = _filterApplyBrightnessContrastChannel(
    color.green,
    brightnessOffset,
    contrastFactor,
  );
  final int b = _filterApplyBrightnessContrastChannel(
    color.blue,
    brightnessOffset,
    contrastFactor,
  );
  return Color.fromARGB(color.alpha, r, g, b);
}

int _filterApplyBrightnessContrastChannel(
  int channel,
  double brightnessOffset,
  double contrastFactor,
) {
  final double adjusted =
      ((channel - 128) * contrastFactor + 128 + brightnessOffset).clamp(
        0.0,
        255.0,
      );
  return adjusted.round();
}

void _filterApplyBlackWhiteToBitmap(
  Uint8List bitmap,
  double blackPoint,
  double whitePoint,
  double midTone,
) {
  final double black = blackPoint.clamp(0.0, 100.0) / 100.0;
  final double white = whitePoint.clamp(0.0, 100.0) / 100.0;
  final double safeWhite = math.max(
    black + (_kBlackWhiteMinRange / 100.0),
    white,
  );
  final double invRange = 1.0 / math.max(0.0001, safeWhite - black);
  final double gamma = math.pow(2.0, midTone / 100.0).toDouble();
  for (int i = 0; i < bitmap.length; i += 4) {
    final int alpha = bitmap[i + 3];
    if (alpha == 0) {
      continue;
    }
    final double luminance =
        (bitmap[i] * 0.299 + bitmap[i + 1] * 0.587 + bitmap[i + 2] * 0.114) /
        255.0;
    double normalized = ((luminance - black) * invRange).clamp(0.0, 1.0);
    normalized = math.pow(normalized, gamma).clamp(0.0, 1.0).toDouble();
    final int gray = _filterRoundChannel(normalized * 255.0);
    bitmap[i] = gray;
    bitmap[i + 1] = gray;
    bitmap[i + 2] = gray;
    bitmap[i + 3] = alpha;
  }
}

Color _filterApplyBlackWhiteToColor(
  Color color,
  double blackPoint,
  double whitePoint,
  double midTone,
) {
  final double black = blackPoint.clamp(0.0, 100.0) / 100.0;
  final double white = whitePoint.clamp(0.0, 100.0) / 100.0;
  final double safeWhite = math.max(
    black + (_kBlackWhiteMinRange / 100.0),
    white,
  );
  final double invRange = 1.0 / math.max(0.0001, safeWhite - black);
  final double gamma = math.pow(2.0, midTone / 100.0).toDouble();
  final double luminance =
      (color.red * 0.299 + color.green * 0.587 + color.blue * 0.114) / 255.0;
  double normalized = ((luminance - black) * invRange).clamp(0.0, 1.0);
  normalized = math.pow(normalized, gamma).clamp(0.0, 1.0).toDouble();
  final int gray = _filterRoundChannel(normalized * 255.0);
  return Color.fromARGB(color.alpha, gray, gray, gray);
}

void _filterApplyBinarizeToBitmap(Uint8List bitmap, int threshold) {
  final int clamped = threshold.clamp(0, 255);
  for (int i = 0; i < bitmap.length; i += 4) {
    final int alpha = bitmap[i + 3];
    if (alpha == 0) {
      continue;
    }
    if (alpha >= clamped) {
      if (alpha != 255) {
        bitmap[i + 3] = 255;
      }
      continue;
    }
    if (bitmap[i] != 0 || bitmap[i + 1] != 0 || bitmap[i + 2] != 0) {
      bitmap[i] = 0;
      bitmap[i + 1] = 0;
      bitmap[i + 2] = 0;
    }
    if (alpha != 0) {
      bitmap[i + 3] = 0;
    }
  }
}

Color _filterApplyBinarizeToColor(Color color, int threshold) {
  final int clamped = threshold.clamp(0, 255);
  if (color.alpha == 0 || color.alpha == 255) {
    return color;
  }
  final int nextAlpha = color.alpha >= clamped ? 255 : 0;
  if (nextAlpha == color.alpha) {
    return color;
  }
  return color.withAlpha(nextAlpha);
}

bool _filterBitmapHasVisiblePixels(Uint8List bitmap) {
  for (int i = 3; i < bitmap.length; i += 4) {
    if (bitmap[i] != 0) {
      return true;
    }
  }
  return false;
}

double _gaussianBlurSigmaForRadius(double radius) {
  final double clampedRadius = radius.clamp(0.0, _kGaussianBlurMaxRadius);
  if (clampedRadius <= 0) {
    return 0;
  }
  return math.max(0.1, clampedRadius * 0.5);
}

void _filterApplyGaussianBlurToBitmap(
  Uint8List bitmap,
  int width,
  int height,
  double radius,
) {
  if (bitmap.isEmpty || width <= 0 || height <= 0) {
    return;
  }
  final double sigma = _gaussianBlurSigmaForRadius(radius);
  if (sigma <= 0) {
    return;
  }
  // 使用预乘 alpha 防止在透明区域被卷积时产生黑边。
  _filterPremultiplyAlpha(bitmap);
  // Approximate a gaussian blur with three fast box blur passes so very large
  // radii (e.g. 1000px) stay responsive during preview.
  final List<int> boxSizes = _filterComputeBoxSizes(sigma, 3);
  final Uint8List scratch = Uint8List(bitmap.length);
  for (final int boxSize in boxSizes) {
    final int passRadius = math.max(0, (boxSize - 1) >> 1);
    if (passRadius <= 0) {
      continue;
    }
    _filterBoxBlurPass(
      source: bitmap,
      destination: scratch,
      width: width,
      height: height,
      radius: passRadius,
      horizontal: true,
    );
    _filterBoxBlurPass(
      source: scratch,
      destination: bitmap,
      width: width,
      height: height,
      radius: passRadius,
      horizontal: false,
    );
  }
  _filterUnpremultiplyAlpha(bitmap);
}

void _filterApplyMorphologyToBitmap(
  Uint8List bitmap,
  int width,
  int height,
  int radius, {
  required bool dilate,
}) {
  if (bitmap.isEmpty || width <= 0 || height <= 0) {
    return;
  }
  final int clampedRadius =
      radius.clamp(1, _kMorphologyMaxRadius.toInt()).toInt();
  final Uint8List? luminanceMask =
      _filterBuildLuminanceMaskIfFullyOpaque(bitmap, width, height);
  final bool preserveAlpha = luminanceMask != null;
  final Uint8List scratch = Uint8List(bitmap.length);
  Uint8List src = bitmap;
  Uint8List dest = scratch;

  for (int iteration = 0; iteration < clampedRadius; iteration++) {
    for (int y = 0; y < height; y++) {
      final int rowOffset = y * width;
      for (int x = 0; x < width; x++) {
        final int pixelIndex = rowOffset + x;
        int bestOffset = (pixelIndex << 2);
        int bestAlpha = luminanceMask != null
            ? luminanceMask[pixelIndex]
            : src[bestOffset + 3];

        for (int dy = -1; dy <= 1; dy++) {
          final int ny = y + dy;
          if (ny < 0 || ny >= height) {
            continue;
          }
          final int neighborRow = ny * width;
          for (int dx = -1; dx <= 1; dx++) {
            final int nx = x + dx;
            if (nx < 0 || nx >= width) {
              continue;
            }
            final int neighborIndex = neighborRow + nx;
            final int neighborOffset = (neighborIndex << 2);
            final int neighborAlpha = luminanceMask != null
                ? luminanceMask[neighborIndex]
                : src[neighborOffset + 3];
            if (dilate) {
              if (neighborAlpha > bestAlpha) {
                bestAlpha = neighborAlpha;
                bestOffset = neighborOffset;
              }
            } else {
              if (neighborAlpha < bestAlpha) {
                bestAlpha = neighborAlpha;
                bestOffset = neighborOffset;
              }
            }
          }
        }

        final int outOffset = ((rowOffset + x) << 2);
        if (bestAlpha == 0) {
          dest[outOffset] = preserveAlpha ? src[outOffset] : 0;
          dest[outOffset + 1] = preserveAlpha ? src[outOffset + 1] : 0;
          dest[outOffset + 2] = preserveAlpha ? src[outOffset + 2] : 0;
          dest[outOffset + 3] = preserveAlpha ? src[outOffset + 3] : 0;
        } else {
          dest[outOffset] = src[bestOffset];
          dest[outOffset + 1] = src[bestOffset + 1];
          dest[outOffset + 2] = src[bestOffset + 2];
          dest[outOffset + 3] = preserveAlpha ? src[outOffset + 3] : bestAlpha;
        }
      }
    }
    final Uint8List swap = src;
    src = dest;
    dest = swap;
  }

  if (!identical(src, bitmap)) {
    bitmap.setAll(0, src);
  }
}

/// 当图层完全不透明时，基于亮度构造“线稿掩码”，让线条收窄在无透明度的色稿上也能生效。
/// 返回 null 表示存在透明像素或图像过于明亮（没有可视的线稿）。
Uint8List? _filterBuildLuminanceMaskIfFullyOpaque(
  Uint8List bitmap,
  int width,
  int height,
) {
  final int pixelCount = width * height;
  final Uint8List mask = Uint8List(pixelCount);
  bool fullyOpaque = true;
  bool hasCoverage = false;
  for (int i = 0, offset = 0; i < pixelCount; i++, offset += 4) {
    final int alpha = bitmap[offset + 3];
    if (alpha != 255) {
      fullyOpaque = false;
      break;
    }
    // ITU-R BT.601 加权亮度，再取反得到线稿“覆盖度”。
    final int r = bitmap[offset];
    final int g = bitmap[offset + 1];
    final int b = bitmap[offset + 2];
    final int luma = ((r * 299 + g * 587 + b * 114) / 1000).round();
    final int coverage = (255 - luma).clamp(0, 255).toInt();
    if (coverage > 0) {
      hasCoverage = true;
    }
    mask[i] = coverage;
  }
  if (!fullyOpaque || !hasCoverage) {
    return null;
  }
  return mask;
}

void _filterApplyLeakRemovalToBitmap(
  Uint8List bitmap,
  int width,
  int height,
  int radius,
) {
  if (bitmap.isEmpty || width <= 0 || height <= 0) {
    return;
  }
  final int clampedRadius = radius.clamp(0, _kLeakRemovalMaxRadius.toInt());
  if (clampedRadius <= 0) {
    return;
  }
  // 全不透明图层使用亮度掩码推导覆盖度，避免因缺少透明度信息而无法检测针眼。
  final Uint8List? luminanceMask =
      _filterBuildLuminanceMaskIfFullyOpaque(bitmap, width, height);
  final bool useLuminanceMask = luminanceMask != null;
  final int pixelCount = width * height;
  final Uint8List holeMask = Uint8List(pixelCount);
  bool hasTransparent = false;
  for (int index = 0, offset = 0; index < pixelCount; index++, offset += 4) {
    final int coverage = useLuminanceMask
        ? luminanceMask![index]
        : bitmap[offset + 3];
    if (coverage == 0) {
      holeMask[index] = 1;
      hasTransparent = true;
    }
  }
  if (!hasTransparent) {
    return;
  }
  _filterMarkLeakBackground(holeMask, width, height);
  bool hasHole = false;
  for (final int value in holeMask) {
    if (value == 1) {
      hasHole = true;
      break;
    }
  }
  if (!hasHole) {
    return;
  }
  final int maxComponentExtent = clampedRadius * 2 + 1;
  final int maxComponentPixels = maxComponentExtent * maxComponentExtent;
  final ListQueue<int> queue = ListQueue<int>();
  final List<int> componentPixels = <int>[];
  final List<int> seeds = <int>[];
  final Set<int> seedSet = <int>{};

  for (int start = 0; start < pixelCount; start++) {
    if (holeMask[start] != 1) {
      continue;
    }
    queue.clear();
    componentPixels.clear();
    seeds.clear();
    seedSet.clear();
    queue.add(start);
    holeMask[start] = 2;
    bool touchesOpaque = false;
    bool componentTooLarge = false;
    int minX = start % width;
    int maxX = minX;
    int minY = start ~/ width;
    int maxY = minY;

    while (queue.isNotEmpty) {
      final int index = queue.removeFirst();
      final int y = index ~/ width;
      final int x = index - y * width;

      if (componentTooLarge) {
        holeMask[index] = 0;
      } else {
        componentPixels.add(index);
        if (x < minX) {
          minX = x;
        }
        if (x > maxX) {
          maxX = x;
        }
        if (y < minY) {
          minY = y;
        }
        if (y > maxY) {
          maxY = y;
        }
      }

      if (x > 0) {
        final int left = index - 1;
        if (holeMask[left] == 1) {
          holeMask[left] = 2;
          queue.add(left);
        }
      }
      if (x + 1 < width) {
        final int right = index + 1;
        if (holeMask[right] == 1) {
          holeMask[right] = 2;
          queue.add(right);
        }
      }
      if (y > 0) {
        final int up = index - width;
        if (holeMask[up] == 1) {
          holeMask[up] = 2;
          queue.add(up);
        }
      }
      if (y + 1 < height) {
        final int down = index + width;
        if (holeMask[down] == 1) {
          holeMask[down] = 2;
          queue.add(down);
        }
      }

      if (componentTooLarge) {
        continue;
      }

      for (int dy = -1; dy <= 1; dy++) {
        final int ny = y + dy;
        if (ny < 0 || ny >= height) {
          continue;
        }
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) {
            continue;
          }
          final int nx = x + dx;
          if (nx < 0 || nx >= width) {
            continue;
          }
          final int neighborIndex = ny * width + nx;
          if (holeMask[neighborIndex] == 2) {
            continue;
          }
          final int neighborOffset = neighborIndex << 2;
          final int neighborCoverage = useLuminanceMask
              ? luminanceMask![neighborIndex]
              : bitmap[neighborOffset + 3];
          if (neighborCoverage == 0) {
            continue;
          }
          touchesOpaque = true;
          if (seedSet.add(neighborIndex)) {
            seeds.add(neighborIndex);
          }
        }
      }

      final int componentWidth = maxX - minX + 1;
      final int componentHeight = maxY - minY + 1;
      if (componentPixels.length > maxComponentPixels ||
          componentWidth > maxComponentExtent ||
          componentHeight > maxComponentExtent) {
        componentTooLarge = true;
        touchesOpaque = false;
        for (final int visitedIndex in componentPixels) {
          holeMask[visitedIndex] = 0;
        }
        componentPixels.clear();
        seeds.clear();
        seedSet.clear();
      }
    }

    if (componentTooLarge) {
      continue;
    }
    if (componentPixels.isEmpty || seeds.isEmpty || !touchesOpaque) {
      _filterClearLeakComponent(componentPixels, holeMask);
      continue;
    }
    if (!_filterIsLeakComponentWithinRadius(
      componentPixels,
      width,
      height,
      clampedRadius,
      holeMask,
    )) {
      _filterClearLeakComponent(componentPixels, holeMask);
      continue;
    }
    _filterFillLeakComponent(
      bitmap: bitmap,
      width: width,
      height: height,
      holeMask: holeMask,
      seeds: seeds,
    );
    _filterClearLeakComponent(componentPixels, holeMask);
  }
}

void _filterMarkLeakBackground(Uint8List holeMask, int width, int height) {
  if (width <= 0 || height <= 0) {
    return;
  }
  final int pixelCount = width * height;
  final Uint32List queue = Uint32List(pixelCount);
  int head = 0;
  int tail = 0;

  void tryEnqueue(int index) {
    if (index < 0 || index >= pixelCount) {
      return;
    }
    if (holeMask[index] != 1) {
      return;
    }
    holeMask[index] = 0;
    queue[tail++] = index;
  }

  for (int x = 0; x < width; x++) {
    tryEnqueue(x);
    if (height > 1) {
      tryEnqueue((height - 1) * width + x);
    }
  }
  for (int y = 1; y < height - 1; y++) {
    tryEnqueue(y * width);
    if (width > 1) {
      tryEnqueue(y * width + (width - 1));
    }
  }

  while (head < tail) {
    final int index = queue[head++];
    final int row = index ~/ width;
    final int col = index - row * width;
    if (row > 0) {
      final int up = index - width;
      if (holeMask[up] == 1) {
        holeMask[up] = 0;
        queue[tail++] = up;
      }
    }
    if (row + 1 < height) {
      final int down = index + width;
      if (holeMask[down] == 1) {
        holeMask[down] = 0;
        queue[tail++] = down;
      }
    }
    if (col > 0) {
      final int left = index - 1;
      if (holeMask[left] == 1) {
        holeMask[left] = 0;
        queue[tail++] = left;
      }
    }
    if (col + 1 < width) {
      final int right = index + 1;
      if (holeMask[right] == 1) {
        holeMask[right] = 0;
        queue[tail++] = right;
      }
    }
  }
}

void _filterClearLeakComponent(List<int> componentPixels, Uint8List holeMask) {
  for (final int index in componentPixels) {
    holeMask[index] = 0;
  }
}

bool _filterIsLeakComponentWithinRadius(
  List<int> componentPixels,
  int width,
  int height,
  int maxRadius,
  Uint8List holeMask,
) {
  if (componentPixels.isEmpty || maxRadius <= 0) {
    return false;
  }
  final ListQueue<_LeakDistanceNode> queue = ListQueue<_LeakDistanceNode>();
  for (final int index in componentPixels) {
    if (_filterIsLeakBoundaryIndex(index, width, height, holeMask)) {
      queue.add(_LeakDistanceNode(index, 0));
      holeMask[index] = 3;
    }
  }
  if (queue.isEmpty) {
    for (final int index in componentPixels) {
      if (holeMask[index] == 3) {
        holeMask[index] = 2;
      }
    }
    return false;
  }
  int visitedCount = 0;
  int maxDistance = 0;
  while (queue.isNotEmpty) {
    final _LeakDistanceNode node = queue.removeFirst();
    visitedCount++;
    if (node.distance > maxDistance) {
      maxDistance = node.distance;
      if (maxDistance > maxRadius) {
        for (final int index in componentPixels) {
          if (holeMask[index] == 3) {
            holeMask[index] = 2;
          }
        }
        return false;
      }
    }
    final int index = node.index;
    final int y = index ~/ width;
    final int x = index - y * width;
    if (x > 0) {
      final int left = index - 1;
      if (holeMask[left] == 2) {
        holeMask[left] = 3;
        queue.add(_LeakDistanceNode(left, node.distance + 1));
      }
    }
    if (x + 1 < width) {
      final int right = index + 1;
      if (holeMask[right] == 2) {
        holeMask[right] = 3;
        queue.add(_LeakDistanceNode(right, node.distance + 1));
      }
    }
    if (y > 0) {
      final int up = index - width;
      if (holeMask[up] == 2) {
        holeMask[up] = 3;
        queue.add(_LeakDistanceNode(up, node.distance + 1));
      }
    }
    if (y + 1 < height) {
      final int down = index + width;
      if (holeMask[down] == 2) {
        holeMask[down] = 3;
        queue.add(_LeakDistanceNode(down, node.distance + 1));
      }
    }
  }
  final bool fullyCovered = visitedCount == componentPixels.length;
  for (final int index in componentPixels) {
    if (holeMask[index] == 3) {
      holeMask[index] = 2;
    }
  }
  return fullyCovered;
}

bool _filterIsLeakBoundaryIndex(
  int index,
  int width,
  int height,
  Uint8List holeMask,
) {
  final int y = index ~/ width;
  final int x = index - y * width;
  if (x == 0 || x == width - 1 || y == 0 || y == height - 1) {
    return true;
  }
  if (holeMask[index - 1] != 2) {
    return true;
  }
  if (holeMask[index + 1] != 2) {
    return true;
  }
  if (holeMask[index - width] != 2) {
    return true;
  }
  if (holeMask[index + width] != 2) {
    return true;
  }
  return false;
}

void _filterFillLeakComponent({
  required Uint8List bitmap,
  required int width,
  required int height,
  required Uint8List holeMask,
  required List<int> seeds,
}) {
  if (seeds.isEmpty) {
    return;
  }
  List<int> frontier = List<int>.from(seeds);
  List<int> nextFrontier = <int>[];
  while (frontier.isNotEmpty) {
    nextFrontier.clear();
    for (final int sourceIndex in frontier) {
      final int srcOffset = sourceIndex << 2;
      final int alpha = bitmap[srcOffset + 3];
      if (alpha == 0) {
        continue;
      }
      final int sy = sourceIndex ~/ width;
      final int sx = sourceIndex - sy * width;
      for (int dy = -1; dy <= 1; dy++) {
        final int ny = sy + dy;
        if (ny < 0 || ny >= height) {
          continue;
        }
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) {
            continue;
          }
          final int nx = sx + dx;
          if (nx < 0 || nx >= width) {
            continue;
          }
          final int neighborIndex = ny * width + nx;
          if (holeMask[neighborIndex] != 2) {
            continue;
          }
          final int destOffset = neighborIndex << 2;
          bitmap[destOffset] = bitmap[srcOffset];
          bitmap[destOffset + 1] = bitmap[srcOffset + 1];
          bitmap[destOffset + 2] = bitmap[srcOffset + 2];
          bitmap[destOffset + 3] = alpha;
          holeMask[neighborIndex] = 0;
          nextFrontier.add(neighborIndex);
        }
      }
    }
    final List<int> temp = frontier;
    frontier = nextFrontier;
    nextFrontier = temp;
  }
}

class _LeakDistanceNode {
  const _LeakDistanceNode(this.index, this.distance);

  final int index;
  final int distance;
}

List<int> _filterComputeBoxSizes(double sigma, int boxCount) {
  final double idealWidth = math.sqrt((12 * sigma * sigma / boxCount) + 1);
  int lowerWidth = idealWidth.floor();
  if (lowerWidth.isEven) {
    lowerWidth = math.max(1, lowerWidth - 1);
  }
  if (lowerWidth < 1) {
    lowerWidth = 1;
  }
  final int upperWidth = lowerWidth + 2;
  final double mIdeal =
      (12 * sigma * sigma -
          boxCount * lowerWidth * lowerWidth -
          4 * boxCount * lowerWidth -
          3 * boxCount) /
      (-4 * lowerWidth - 4);
  final int m = mIdeal.round();
  final int clampedM = m.clamp(0, boxCount).toInt();
  return List<int>.generate(
    boxCount,
    (int i) => i < clampedM ? lowerWidth : upperWidth,
  );
}

void _filterBoxBlurPass({
  required Uint8List source,
  required Uint8List destination,
  required int width,
  required int height,
  required int radius,
  required bool horizontal,
}) {
  if (radius <= 0) {
    destination.setRange(0, source.length, source);
    return;
  }
  final int kernelSize = radius * 2 + 1;
  if (horizontal) {
    for (int y = 0; y < height; y++) {
      final int rowOffset = y * width;
      double sumR = 0;
      double sumG = 0;
      double sumB = 0;
      double sumA = 0;
      for (int k = -radius; k <= radius; k++) {
        final int sampleX = _filterClampIndex(k, width);
        final int sampleIndex = ((rowOffset + sampleX) << 2);
        sumR += source[sampleIndex];
        sumG += source[sampleIndex + 1];
        sumB += source[sampleIndex + 2];
        sumA += source[sampleIndex + 3];
      }
      for (int x = 0; x < width; x++) {
        final int destIndex = ((rowOffset + x) << 2);
        destination[destIndex] = _filterRoundChannel(sumR / kernelSize);
        destination[destIndex + 1] = _filterRoundChannel(sumG / kernelSize);
        destination[destIndex + 2] = _filterRoundChannel(sumB / kernelSize);
        destination[destIndex + 3] = _filterRoundChannel(sumA / kernelSize);
        final int removeX = x - radius;
        final int addX = x + radius + 1;
        final int removeIndex =
            ((rowOffset + _filterClampIndex(removeX, width)) << 2);
        final int addIndex =
            ((rowOffset + _filterClampIndex(addX, width)) << 2);
        sumR += source[addIndex] - source[removeIndex];
        sumG += source[addIndex + 1] - source[removeIndex + 1];
        sumB += source[addIndex + 2] - source[removeIndex + 2];
        sumA += source[addIndex + 3] - source[removeIndex + 3];
      }
    }
    return;
  }
  for (int x = 0; x < width; x++) {
    double sumR = 0;
    double sumG = 0;
    double sumB = 0;
    double sumA = 0;
    for (int k = -radius; k <= radius; k++) {
      final int sampleY = _filterClampIndex(k, height);
      final int sampleIndex = (((sampleY * width) + x) << 2);
      sumR += source[sampleIndex];
      sumG += source[sampleIndex + 1];
      sumB += source[sampleIndex + 2];
      sumA += source[sampleIndex + 3];
    }
    for (int y = 0; y < height; y++) {
      final int destIndex = (((y * width) + x) << 2);
      destination[destIndex] = _filterRoundChannel(sumR / kernelSize);
      destination[destIndex + 1] = _filterRoundChannel(sumG / kernelSize);
      destination[destIndex + 2] = _filterRoundChannel(sumB / kernelSize);
      destination[destIndex + 3] = _filterRoundChannel(sumA / kernelSize);
      final int removeY = y - radius;
      final int addY = y + radius + 1;
      final int removeIndex =
          (((_filterClampIndex(removeY, height) * width) + x) << 2);
      final int addIndex =
          (((_filterClampIndex(addY, height) * width) + x) << 2);
      sumR += source[addIndex] - source[removeIndex];
      sumG += source[addIndex + 1] - source[removeIndex + 1];
      sumB += source[addIndex + 2] - source[removeIndex + 2];
      sumA += source[addIndex + 3] - source[removeIndex + 3];
    }
  }
}

void _filterPremultiplyAlpha(Uint8List bitmap) {
  for (int i = 0; i < bitmap.length; i += 4) {
    final int alpha = bitmap[i + 3];
    if (alpha == 0) {
      bitmap[i] = 0;
      bitmap[i + 1] = 0;
      bitmap[i + 2] = 0;
      continue;
    }
    bitmap[i] = _filterMultiplyChannelByAlpha(bitmap[i], alpha);
    bitmap[i + 1] = _filterMultiplyChannelByAlpha(bitmap[i + 1], alpha);
    bitmap[i + 2] = _filterMultiplyChannelByAlpha(bitmap[i + 2], alpha);
  }
}

void _filterUnpremultiplyAlpha(Uint8List bitmap) {
  for (int i = 0; i < bitmap.length; i += 4) {
    final int alpha = bitmap[i + 3];
    if (alpha == 0) {
      bitmap[i] = 0;
      bitmap[i + 1] = 0;
      bitmap[i + 2] = 0;
      continue;
    }
    bitmap[i] = _filterUnmultiplyChannelByAlpha(bitmap[i], alpha);
    bitmap[i + 1] = _filterUnmultiplyChannelByAlpha(bitmap[i + 1], alpha);
    bitmap[i + 2] = _filterUnmultiplyChannelByAlpha(bitmap[i + 2], alpha);
  }
}

int _filterMultiplyChannelByAlpha(int channel, int alpha) {
  return ((channel * alpha) + 127) ~/ 255;
}

int _filterUnmultiplyChannelByAlpha(int channel, int alpha) {
  final int value = ((channel * 255) + (alpha >> 1)) ~/ alpha;
  if (value < 0) {
    return 0;
  }
  if (value > 255) {
    return 255;
  }
  return value;
}

class _LayerPreviewImages {
  const _LayerPreviewImages({this.background, this.active, this.foreground});

  final ui.Image? background;
  final ui.Image? active;
  final ui.Image? foreground;

  void dispose() {
    background?.dispose();
    active?.dispose();
    foreground?.dispose();
  }
}

Future<_LayerPreviewImages> _captureLayerPreviewImages({
  required BitmapCanvasController controller,
  required List<BitmapLayerState> layers,
  required String activeLayerId,
  bool captureActiveLayerAtFullOpacity = false,
}) async {
  final int width = controller.width;
  final int height = controller.height;
  final CanvasRasterBackend tempBackend = CanvasRasterBackend(
    width: width,
    height: height,
    multithreaded: false,
  );
  ui.Image? background;
  ui.Image? active;
  ui.Image? foreground;
  try {
    final int activeIndex = layers.indexWhere(
      (layer) => layer.id == activeLayerId,
    );
    if (activeIndex < 0) {
      return const _LayerPreviewImages();
    }
    final List<BitmapLayerState> below = layers.sublist(0, activeIndex);
    final List<BitmapLayerState> above = layers.sublist(activeIndex + 1);
    final BitmapLayerState rawActiveLayer = layers[activeIndex];
    final bool forceFullOpacity =
        captureActiveLayerAtFullOpacity && rawActiveLayer.opacity < 0.999;
    final BitmapLayerState activeLayer = forceFullOpacity
        ? (BitmapLayerState(
            id: rawActiveLayer.id,
            name: rawActiveLayer.name,
            surface: rawActiveLayer.surface,
            visible: rawActiveLayer.visible,
            opacity: 1.0,
            locked: rawActiveLayer.locked,
            clippingMask: rawActiveLayer.clippingMask,
            blendMode: rawActiveLayer.blendMode,
          )..revision = rawActiveLayer.revision)
        : rawActiveLayer;
    if (below.isNotEmpty) {
      await tempBackend.composite(layers: below, requiresFullSurface: true);
      final Uint8List rgba = tempBackend.copySurfaceRgba();
      background = await _decodeImage(rgba, width, height);
    }
    tempBackend.resetClipMask();
    final Uint32List pixels = tempBackend.ensureCompositePixels();
    pixels.fillRange(0, pixels.length, 0);
    await tempBackend.composite(
      layers: <BitmapLayerState>[activeLayer],
      requiresFullSurface: true,
    );
    final Uint8List activeRgba = tempBackend.copySurfaceRgba();
    active = await _decodeImage(activeRgba, width, height);
    if (above.isNotEmpty) {
      pixels.fillRange(0, pixels.length, 0);
      await tempBackend.composite(layers: above, requiresFullSurface: true);
      final Uint8List aboveRgba = tempBackend.copySurfaceRgba();
      foreground = await _decodeImage(aboveRgba, width, height);
    }
  } finally {
    await tempBackend.dispose();
  }
  return _LayerPreviewImages(
    background: background,
    active: active,
    foreground: foreground,
  );
}

Future<ui.Image> _decodeImage(Uint8List pixels, int width, int height) {
  final Completer<ui.Image> completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

int _filterRoundChannel(double value) {
  final int rounded = value.round();
  if (rounded < 0) {
    return 0;
  }
  if (rounded > 255) {
    return 255;
  }
  return rounded;
}

int _filterClampIndex(int value, int maxExclusive) {
  if (maxExclusive <= 1) {
    return 0;
  }
  if (value < 0) {
    return 0;
  }
  if (value >= maxExclusive) {
    return maxExclusive - 1;
  }
  return value;
}
