part of 'painting_board.dart';

const double _kFilterPanelWidth = 320;
const double _kFilterPanelMinHeight = 180;
const double _kAntialiasPanelWidth = 280;
const double _kAntialiasPanelMinHeight = 140;
const double _kGaussianBlurMaxRadius = 1000.0;
const List<String> _kAntialiasLevelDescriptions = <String>[
  '0 级（关闭）：保留像素硬边，不进行平滑处理。',
  '1 级（轻度）：轻微柔化锯齿，适合线稿与像素边缘。',
  '2 级（标准）：平衡锐度与平滑度，适合大多数上色场景。',
  '3 级（强力）：最强平滑效果，用于柔和、放大的边缘。',
];

enum _FilterPanelType { hueSaturation, brightnessContrast, gaussianBlur }

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
  final _GaussianBlurSettings gaussianBlur = _GaussianBlurSettings();
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

  void showHueSaturationAdjustments() {
    _openFilterPanel(_FilterPanelType.hueSaturation);
  }

  void showBrightnessContrastAdjustments() {
    _openFilterPanel(_FilterPanelType.brightnessContrast);
  }

  void showGaussianBlurAdjustments() {
    _openFilterPanel(_FilterPanelType.gaussianBlur);
  }

  void _openFilterPanel(_FilterPanelType type) {
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
      _showFilterMessage('当前图层已锁定，无法应用滤镜。');
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
    _initializeFilterWorker();
    _insertFilterOverlay();
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
          case _FilterPanelType.gaussianBlur:
            panelTitle = '高斯模糊';
            panelBody = _GaussianBlurControls(
              radius: session.gaussianBlur.radius,
              onRadiusChanged: _updateGaussianBlur,
            );
            break;
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
                  onPressed: _confirmFilterChanges,
                  child: const Text('应用'),
                ),
              ],
            ),
          ),
        );
      },
    );
    overlay.insert(_filterOverlayEntry!);
    _requestFilterPreview(immediate: true);
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
    session.gaussianBlur.radius = 0;
    _requestFilterPreview(immediate: true);
    _filterOverlayEntry?.markNeedsBuild();
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
    _requestFilterPreview();
    _filterOverlayEntry?.markNeedsBuild();
  }

  void _updateBrightnessContrast({double? brightness, double? contrast}) {
    final _FilterSession? session = _filterSession;
    if (session == null) {
      return;
    }
    session.brightnessContrast
      ..brightness = brightness ?? session.brightnessContrast.brightness
      ..contrast = contrast ?? session.brightnessContrast.contrast;
    _requestFilterPreview();
    _filterOverlayEntry?.markNeedsBuild();
  }

  void _updateGaussianBlur(double radius) {
    final _FilterSession? session = _filterSession;
    if (session == null) {
      return;
    }
    session.gaussianBlur.radius = radius.clamp(0.0, _kGaussianBlurMaxRadius);
    _requestFilterPreview();
    _filterOverlayEntry?.markNeedsBuild();
  }

  void _requestFilterPreview({bool immediate = false}) {
    if (immediate) {
      _filterPreviewDebounceTimer?.cancel();
      _filterPreviewDebounceTimer = null;
      _applyFilterPreview();
      return;
    }
    _filterPreviewDebounceTimer?.cancel();
    _filterPreviewDebounceTimer = Timer(_filterPreviewDebounceDuration, () {
      _filterPreviewDebounceTimer = null;
      _applyFilterPreview();
    });
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
    final bool isIdentity = _isFilterSessionIdentity(session);
    if (isIdentity) {
      _filterPreviewPendingChange = false;
      _filterPreviewLastIssuedToken++;
      _restoreFilterPreviewToOriginal(session);
      return;
    }
    final _FilterPreviewWorker? worker = _filterWorker;
    if (worker == null) {
      return;
    }
    _filterPreviewPendingChange = false;
    _filterPreviewRequestInFlight = true;
    final int token = ++_filterPreviewLastIssuedToken;
    unawaited(
      worker.requestPreview(
        token: token,
        hueSaturation: session.hueSaturation,
        brightnessContrast: session.brightnessContrast,
        blurRadius: session.gaussianBlur.radius,
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

  void _confirmFilterChanges() async {
    final _FilterSession? session = _filterSession;
    if (session == null) {
      return;
    }
    final CanvasLayerData? previewLayer = session.previewLayer;
    if (previewLayer == null) {
      _removeFilterOverlay();
      return;
    }
    _cancelFilterPreviewTasks();
    final CanvasLayerData original =
        session.originalLayers[session.activeLayerIndex];
    _controller.replaceLayer(session.activeLayerId, original);
    _controller.setActiveLayer(session.activeLayerId);
    await _pushUndoSnapshot();
    _controller.replaceLayer(session.activeLayerId, previewLayer);
    _controller.setActiveLayer(session.activeLayerId);
    session.previewLayer = null;
    setState(() {});
    _markDirty();
    _removeFilterOverlay(restoreOriginal: false);
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
      case _FilterPanelType.gaussianBlur:
        final double radius = session.gaussianBlur.radius;
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
    final CanvasLayerData original =
        session.originalLayers[session.activeLayerIndex];
    final Uint8List? bitmap = result.bitmapBytes;
    final int? fillValue = result.fillColor;
    Color? fillColor = original.fillColor;
    if (fillValue != null) {
      fillColor = Color(fillValue);
    }
    final bool hasBitmap = bitmap != null;
    final CanvasLayerData adjusted = CanvasLayerData(
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
    session.previewLayer = adjusted;
    _controller.replaceLayer(session.activeLayerId, adjusted);
    _controller.setActiveLayer(session.activeLayerId);
    setState(() {});
    _onFilterPreviewRequestComplete();
  }

  void _handleFilterWorkerError(Object error, StackTrace stackTrace) {
    debugPrint('Filter preview worker error: $error');
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
    if (_filterPanelOffset == Offset.zero) {
      _filterPanelOffsetIsOverlay = false;
    }
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
    final bool applied =
        await applyLayerAntialiasLevel(_antialiasCardLevel);
    if (!applied) {
      _showFilterMessage('无法对当前图层应用抗锯齿，图层可能为空或已锁定。');
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
    final Size size = _antialiasCardSize ??
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
      _showFilterMessage('当前图层已锁定，无法应用抗锯齿。');
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
        Text('选择抗锯齿级别', style: theme.typography.bodyStrong),
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
          _kAntialiasLevelDescriptions[safeLevel],
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
const int _kFilterTypeGaussianBlur = 2;

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
  bool _disposed = false;

  Future<void> _start(CanvasLayerData layer) async {
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
      case _FilterPanelType.gaussianBlur:
        filterType = _kFilterTypeGaussianBlur;
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
    _isolate = await Isolate.spawn<List<Object?>>(
      _filterPreviewWorkerMain,
      <Object?>[port.sendPort, initData],
      debugName: 'FilterPreviewWorker',
      errorsAreFatal: false,
    );
  }

  Future<void> requestPreview({
    required int token,
    required _HueSaturationSettings hueSaturation,
    required _BrightnessContrastSettings brightnessContrast,
    required double blurRadius,
  }) async {
    if (_disposed) {
      return;
    }
    try {
      await _readyCompleter.future;
    } catch (_) {
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
      'blur': blurRadius,
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
    this.fillColor,
  }) : _bitmapData = bitmapData;

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
    final double hueDelta = _filterReadListValue(rawHue, 0);
    final double saturationPercent = _filterReadListValue(rawHue, 1);
    final double lightnessPercent = _filterReadListValue(rawHue, 2);
    final double brightnessPercent = _filterReadListValue(rawBrightness, 0);
    final double contrastPercent = _filterReadListValue(rawBrightness, 1);
    final double blurRadius = (message['blur'] is num)
        ? (message['blur'] as num).toDouble()
        : 0.0;

    Uint8List? bitmap;
    if (baseBitmap != null) {
      bitmap = Uint8List.fromList(baseBitmap);
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

bool _filterBitmapHasVisiblePixels(Uint8List bitmap) {
  for (int i = 3; i < bitmap.length; i += 4) {
    if (bitmap[i] != 0) {
      return true;
    }
  }
  return false;
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
  final double clampedRadius = radius.clamp(0.0, _kGaussianBlurMaxRadius);
  if (clampedRadius <= 0) {
    return;
  }
  // Approximate a gaussian blur with three fast box blur passes so very large
  // radii (e.g. 1000px) stay responsive during preview.
  final double sigma = math.max(0.1, clampedRadius * 0.5);
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
