part of 'painting_board.dart';

const double _kFilterPanelWidth = 320;
const double _kFilterPanelMinHeight = 180;

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
  Map<String, Object?>? _pendingFilterComputeMessage;
  bool _filterPreviewComputeRunning = false;
  int _filterPreviewLastIssuedToken = 0;

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
          child: _FilterPanelShell(
            session: session,
            onDrag: _handleFilterPanelDrag,
            onClose: () => _removeFilterOverlay(),
            onCancel: () => _removeFilterOverlay(),
            onApply: _confirmFilterChanges,
            onReset: _resetFilterSettings,
            onHueChanged: (value) => _updateHueSaturation(hue: value),
            onSaturationChanged: (value) =>
                _updateHueSaturation(saturation: value),
            onLightnessChanged: (value) =>
                _updateHueSaturation(lightness: value),
            onBrightnessChanged: (value) =>
                _updateBrightnessContrast(brightness: value),
            onContrastChanged: (value) =>
                _updateBrightnessContrast(contrast: value),
          ),
        );
      },
    );
    overlay.insert(_filterOverlayEntry!);
    _applyFilterPreview();
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
    if (_isFilterSessionIdentity(session)) {
      _pendingFilterComputeMessage = null;
      _filterPreviewLastIssuedToken++;
      _restoreFilterPreviewToOriginal(session);
      return;
    }
    final CanvasLayerData original =
        session.originalLayers[session.activeLayerIndex];
    _pendingFilterComputeMessage = _buildFilterPreviewMessage(
      session,
      original,
    );
    _processNextFilterPreviewTask();
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

  Map<String, Object?> _buildFilterPreviewMessage(
    _FilterSession session,
    CanvasLayerData layer,
  ) {
    return <String, Object?>{
      'token': ++_filterPreviewLastIssuedToken,
      'layerId': session.activeLayerId,
      'type': session.type.index,
      'layer': <String, Object?>{
        'bitmap': layer.bitmap,
        'fillColor': layer.fillColor?.value,
      },
      'hue': <double>[
        session.hueSaturation.hue,
        session.hueSaturation.saturation,
        session.hueSaturation.lightness,
      ],
      'brightness': <double>[
        session.brightnessContrast.brightness,
        session.brightnessContrast.contrast,
      ],
    };
  }

  void _processNextFilterPreviewTask() {
    if (_filterPreviewComputeRunning) {
      return;
    }
    final Map<String, Object?>? message = _pendingFilterComputeMessage;
    if (message == null) {
      return;
    }
    _pendingFilterComputeMessage = null;
    _filterPreviewComputeRunning = true;
    compute<Map<String, Object?>, Map<String, Object?>>(
      _runFilterPreviewIsolate,
      message,
    ).then((Map<String, Object?> result) {
      _filterPreviewComputeRunning = false;
      _handleFilterPreviewResult(result);
      _processNextFilterPreviewTask();
    }).catchError((Object error, StackTrace stackTrace) {
      _filterPreviewComputeRunning = false;
      debugPrint('Filter preview failed: $error');
      _processNextFilterPreviewTask();
    });
  }

  void _handleFilterPreviewResult(Map<String, Object?> result) {
    if (!mounted) {
      return;
    }
    final int token = result['token'] as int? ?? -1;
    if (token != _filterPreviewLastIssuedToken) {
      return;
    }
    final _FilterSession? session = _filterSession;
    if (session == null) {
      return;
    }
    final String? layerId = result['layerId'] as String?;
    if (layerId == null || layerId != session.activeLayerId) {
      return;
    }
    final CanvasLayerData original =
        session.originalLayers[session.activeLayerIndex];
    final Uint8List? bitmap = result['bitmap'] as Uint8List?;
    final Object? fillValue = result['fillColor'];
    Color? fillColor = original.fillColor;
    if (fillValue is int) {
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
    _pendingFilterComputeMessage = null;
    _filterPreviewLastIssuedToken++;
  }

  void _removeFilterOverlay({bool restoreOriginal = true}) {
    _filterOverlayEntry?.remove();
    _filterOverlayEntry = null;
    _cancelFilterPreviewTasks();
    final _FilterSession? session = _filterSession;
    if (restoreOriginal && session != null) {
      _restoreFilterPreviewToOriginal(session);
    }
    _filterSession = null;
  }

}

class _FilterPanelShell extends StatelessWidget {
  const _FilterPanelShell({
    required this.session,
    required this.onDrag,
    required this.onClose,
    required this.onApply,
    required this.onReset,
    required this.onCancel,
    required this.onHueChanged,
    required this.onSaturationChanged,
    required this.onLightnessChanged,
    required this.onBrightnessChanged,
    required this.onContrastChanged,
  });

  final _FilterSession session;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onClose;
  final VoidCallback onApply;
  final VoidCallback onReset;
  final VoidCallback onCancel;
  final ValueChanged<double> onHueChanged;
  final ValueChanged<double> onSaturationChanged;
  final ValueChanged<double> onLightnessChanged;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onContrastChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      width: _kFilterPanelWidth,
      constraints: const BoxConstraints(minHeight: _kFilterPanelMinHeight),
      decoration: BoxDecoration(
        color: theme.cardColor.withAlpha(0xFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.resources.controlStrokeColorDefault),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) => onDrag(details.delta),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      session.type == _FilterPanelType.hueSaturation
                          ? '色相/饱和度'
                          : '亮度/对比度',
                      style: theme.typography.subtitle,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(FluentIcons.chrome_close),
                    onPressed: onClose,
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(const EdgeInsets.all(4)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: session.type == _FilterPanelType.hueSaturation
                ? _HueSaturationControls(
                    settings: session.hueSaturation,
                    onHueChanged: onHueChanged,
                    onSaturationChanged: onSaturationChanged,
                    onLightnessChanged: onLightnessChanged,
                  )
                : _BrightnessContrastControls(
                    settings: session.brightnessContrast,
                    onBrightnessChanged: onBrightnessChanged,
                    onContrastChanged: onContrastChanged,
                  ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Button(onPressed: onReset, child: const Text('重置')),
                const Spacer(),
                Button(onPressed: onCancel, child: const Text('取消')),
                const SizedBox(width: 8),
                FilledButton(onPressed: onApply, child: const Text('应用')),
              ],
            ),
          ),
        ],
      ),
    );
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

@pragma('vm:entry-point')
Map<String, Object?> _runFilterPreviewIsolate(
  Map<String, Object?> message,
) {
  final int type = message['type'] as int? ?? _kFilterTypeHueSaturation;
  final Map<String, Object?> layer =
      (message['layer'] as Map<String, Object?>?) ?? const <String, Object?>{};
  Uint8List? bitmap = layer['bitmap'] as Uint8List?;
  final int? fillColorValue = layer['fillColor'] as int?;
  final List<dynamic>? rawHue = message['hue'] as List<dynamic>?;
  final List<dynamic>? rawBrightness =
      message['brightness'] as List<dynamic>?;
  final double hueDelta = _filterReadListValue(rawHue, 0);
  final double saturationPercent = _filterReadListValue(rawHue, 1);
  final double lightnessPercent = _filterReadListValue(rawHue, 2);
  final double brightnessPercent = _filterReadListValue(rawBrightness, 0);
  final double contrastPercent = _filterReadListValue(rawBrightness, 1);

  if (bitmap != null) {
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

  return <String, Object?>{
    'token': message['token'],
    'layerId': message['layerId'],
    'bitmap': bitmap,
    'fillColor': adjustedFill,
  };
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
  final double contrastFactor = math.max(
    0.0,
    1.0 + contrastPercent / 100.0,
  );
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
  final double saturation = (hsv.saturation + saturationPercent / 100.0)
      .clamp(0.0, 1.0);
  final double value = (hsv.value + lightnessPercent / 100.0).clamp(0.0, 1.0);
  return HSVColor.fromAHSV(hsv.alpha, hue, saturation, value).toColor();
}

Color _filterApplyBrightnessContrastToColor(
  Color color,
  double brightnessPercent,
  double contrastPercent,
) {
  final double brightnessOffset = brightnessPercent / 100.0 * 255.0;
  final double contrastFactor = math.max(
    0.0,
    1.0 + contrastPercent / 100.0,
  );
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
