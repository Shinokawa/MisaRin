part of 'painting_board.dart';

const double _kFilterPanelWidth = 320;
const double _kFilterPanelMinHeight = 180;
const double _kAntialiasPanelWidth = 280;
const double _kAntialiasPanelMinHeight = 140;
const List<String> _kAntialiasLevelDescriptions = <String>[
  '0 级（关闭）：保留像素硬边，不进行平滑处理。',
  '1 级（轻度）：轻微柔化锯齿，适合线稿与像素边缘。',
  '2 级（标准）：平衡锐度与平滑度，适合大多数上色场景。',
  '3 级（强力）：最强平滑效果，用于柔和、放大的边缘。',
];

enum _FilterPanelType { hueSaturation, brightnessContrast }

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
  CanvasLayerData? previewLayer;
}

mixin _PaintingBoardFilterMixin
    on _PaintingBoardBase, _PaintingBoardLayerMixin {
  OverlayEntry? _filterOverlayEntry;
  _FilterSession? _filterSession;
  Offset _filterPanelOffset = const Offset(420, 140);
  _FilterPreviewWorker? _filterWorker;
  int _filterPreviewLastIssuedToken = 0;
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
    _filterPanelOffset = Offset(
      math.max(16, size.width - _kFilterPanelWidth - 32),
      math.max(16, size.height * 0.2),
    );
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
        return Positioned(
          left: _filterPanelOffset.dx,
          top: _filterPanelOffset.dy,
          child: WorkspaceFloatingPanel(
            width: _kFilterPanelWidth,
            minHeight: _kFilterPanelMinHeight,
            title: session.type == _FilterPanelType.hueSaturation
                ? '色相/饱和度'
                : '亮度/对比度',
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
            child: session.type == _FilterPanelType.hueSaturation
                ? _HueSaturationControls(
                    settings: session.hueSaturation,
                    onHueChanged: (value) => _updateHueSaturation(hue: value),
                    onSaturationChanged: (value) =>
                        _updateHueSaturation(saturation: value),
                    onLightnessChanged: (value) =>
                        _updateHueSaturation(lightness: value),
                  )
                : _BrightnessContrastControls(
                    settings: session.brightnessContrast,
                    onBrightnessChanged: (value) =>
                        _updateBrightnessContrast(brightness: value),
                    onContrastChanged: (value) =>
                        _updateBrightnessContrast(contrast: value),
                  ),
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
    _applyFilterPreview();
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
      onResult: _handleFilterPreviewResult,
      onError: _handleFilterWorkerError,
    );
  }

  void _handleFilterPanelDrag(Offset delta) {
    _filterPanelOffset = Offset(
      _filterPanelOffset.dx + delta.dx,
      _filterPanelOffset.dy + delta.dy,
    );
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
    _applyFilterPreview();
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
    _applyFilterPreview();
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
    _applyFilterPreview();
    _filterOverlayEntry?.markNeedsBuild();
  }

  void _applyFilterPreview() {
    final _FilterSession? session = _filterSession;
    if (session == null) {
      return;
    }
    if (_filterWorker == null) {
      _initializeFilterWorker();
    }
    final bool isIdentity = _isFilterSessionIdentity(session);
    if (isIdentity) {
      _filterPreviewLastIssuedToken++;
      _restoreFilterPreviewToOriginal(session);
      return;
    }
    final _FilterPreviewWorker? worker = _filterWorker;
    if (worker == null) {
      return;
    }
    final int token = ++_filterPreviewLastIssuedToken;
    unawaited(
      worker.requestPreview(
        token: token,
        hueSaturation: session.hueSaturation,
        brightnessContrast: session.brightnessContrast,
      ),
    );
  }

  void _confirmFilterChanges() {
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
    _pushUndoSnapshot();
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
  }

  void _handleFilterWorkerError(Object error, StackTrace stackTrace) {
    debugPrint('Filter preview worker error: $error');
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

  void _applyAntialiasFromCard() {
    if (!_ensureAntialiasLayerReady()) {
      return;
    }
    final bool applied = applyLayerAntialiasLevel(_antialiasCardLevel);
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
    if (_workspaceSize.isEmpty) {
      return const Offset(420, 160);
    }
    const double margin = 16.0;
    final double baseLeft = math.max(
      margin,
      _workspaceSize.width - _kAntialiasPanelWidth - margin,
    );
    final double baseTop = math.max(margin, _workspaceSize.height * 0.25);
    return Offset(baseLeft, baseTop);
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

class _FilterPreviewWorker {
  _FilterPreviewWorker({
    required _FilterPanelType type,
    required String layerId,
    required CanvasLayerData baseLayer,
    required ValueChanged<_FilterPreviewResult> onResult,
    required void Function(Object error, StackTrace stackTrace) onError,
  }) : _type = type,
       _layerId = layerId,
       _onResult = onResult,
       _onError = onError {
    _start(baseLayer);
  }

  final _FilterPanelType _type;
  final String _layerId;
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
    final Map<String, Object?> initData = <String, Object?>{
      'type': _type == _FilterPanelType.hueSaturation
          ? _kFilterTypeHueSaturation
          : _kFilterTypeBrightnessContrast,
      'layerId': _layerId,
      'layer': <String, Object?>{
        'bitmap': bitmapData,
        'bitmapWidth': layer.bitmapWidth,
        'bitmapHeight': layer.bitmapHeight,
        'bitmapLeft': layer.bitmapLeft,
        'bitmapTop': layer.bitmapTop,
        'fillColor': layer.fillColor?.value,
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
      } else {
        _filterApplyBrightnessContrastToBitmap(
          bitmap,
          brightnessPercent,
          contrastPercent,
        );
      }
      if (!_filterBitmapHasVisiblePixels(bitmap)) {
        bitmap = null;
      }
    }

    int? adjustedFill = fillColorValue;
    if (fillColorValue != null) {
      final Color source = Color(fillColorValue);
      final Color adjusted = type == _kFilterTypeHueSaturation
          ? _filterApplyHueSaturationToColor(
              source,
              hueDelta,
              saturationPercent,
              lightnessPercent,
            )
          : _filterApplyBrightnessContrastToColor(
              source,
              brightnessPercent,
              contrastPercent,
            );
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
