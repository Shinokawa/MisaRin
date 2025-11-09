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
}

mixin _PaintingBoardFilterMixin
    on _PaintingBoardBase, _PaintingBoardLayerMixin {
  OverlayEntry? _filterOverlayEntry;
  _FilterSession? _filterSession;
  Offset _filterPanelOffset = const Offset(420, 140);

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
    final List<CanvasLayerData> previewLayers = List<CanvasLayerData>.from(
      session.originalLayers,
      growable: false,
    );
    final CanvasLayerData original =
        session.originalLayers[session.activeLayerIndex];
    CanvasLayerData adjusted;
    switch (session.type) {
      case _FilterPanelType.hueSaturation:
        adjusted = _applyHueSaturationToLayer(original, session.hueSaturation);
        break;
      case _FilterPanelType.brightnessContrast:
        adjusted = _applyBrightnessContrastToLayer(
          original,
          session.brightnessContrast,
        );
        break;
    }
    previewLayers[session.activeLayerIndex] = adjusted;
    _controller.loadLayers(previewLayers, _controller.backgroundColor);
    _controller.setActiveLayer(session.activeLayerId);
    setState(() {});
  }

  void _confirmFilterChanges() {
    final _FilterSession? session = _filterSession;
    if (session == null) {
      return;
    }
    final List<CanvasLayerData> previewLayers = List<CanvasLayerData>.from(
      session.originalLayers,
      growable: false,
    );
    final CanvasLayerData original =
        session.originalLayers[session.activeLayerIndex];
    CanvasLayerData adjusted;
    switch (session.type) {
      case _FilterPanelType.hueSaturation:
        adjusted = _applyHueSaturationToLayer(original, session.hueSaturation);
        break;
      case _FilterPanelType.brightnessContrast:
        adjusted = _applyBrightnessContrastToLayer(
          original,
          session.brightnessContrast,
        );
        break;
    }
    previewLayers[session.activeLayerIndex] = adjusted;
    _controller.loadLayers(session.originalLayers, _controller.backgroundColor);
    _controller.setActiveLayer(session.activeLayerId);
    _pushUndoSnapshot();
    _controller.loadLayers(previewLayers, _controller.backgroundColor);
    _controller.setActiveLayer(session.activeLayerId);
    setState(() {});
    _markDirty();
    _removeFilterOverlay(restoreOriginal: false);
  }

  void _removeFilterOverlay({bool restoreOriginal = true}) {
    _filterOverlayEntry?.remove();
    _filterOverlayEntry = null;
    if (restoreOriginal) {
      final _FilterSession? session = _filterSession;
      if (session != null) {
        _controller.loadLayers(
          session.originalLayers,
          _controller.backgroundColor,
        );
        _controller.setActiveLayer(session.activeLayerId);
        setState(() {});
      }
    }
    _filterSession = null;
  }

  CanvasLayerData _applyHueSaturationToLayer(
    CanvasLayerData layer,
    _HueSaturationSettings settings,
  ) {
    Uint8List? adjustedBitmap;
    if (layer.bitmap != null) {
      adjustedBitmap = Uint8List.fromList(layer.bitmap!);
      _applyHueSaturationToBitmap(adjustedBitmap, settings);
      if (!_hasVisiblePixels(adjustedBitmap)) {
        adjustedBitmap = null;
      }
    }
    Color? fill = layer.fillColor;
    if (fill != null) {
      fill = _applyHueSaturationToColor(fill, settings);
    }
    return layer.copyWith(
      fillColor: fill,
      bitmap: adjustedBitmap,
      bitmapWidth: layer.bitmapWidth,
      bitmapHeight: layer.bitmapHeight,
      bitmapLeft: layer.bitmapLeft,
      bitmapTop: layer.bitmapTop,
      clearBitmap: adjustedBitmap == null && layer.bitmap != null,
    );
  }

  CanvasLayerData _applyBrightnessContrastToLayer(
    CanvasLayerData layer,
    _BrightnessContrastSettings settings,
  ) {
    Uint8List? adjustedBitmap;
    if (layer.bitmap != null) {
      adjustedBitmap = Uint8List.fromList(layer.bitmap!);
      _applyBrightnessContrastToBitmap(adjustedBitmap, settings);
      if (!_hasVisiblePixels(adjustedBitmap)) {
        adjustedBitmap = null;
      }
    }
    Color? fill = layer.fillColor;
    if (fill != null) {
      fill = _applyBrightnessContrastToColor(fill, settings);
    }
    return layer.copyWith(
      fillColor: fill,
      bitmap: adjustedBitmap,
      bitmapWidth: layer.bitmapWidth,
      bitmapHeight: layer.bitmapHeight,
      bitmapLeft: layer.bitmapLeft,
      bitmapTop: layer.bitmapTop,
      clearBitmap: adjustedBitmap == null && layer.bitmap != null,
    );
  }

  void _applyHueSaturationToBitmap(
    Uint8List bitmap,
    _HueSaturationSettings settings,
  ) {
    final double hueDelta = settings.hue;
    final double saturationDelta = settings.saturation / 100.0;
    final double lightnessDelta = settings.lightness / 100.0;
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
      final HSVColor hsv = HSVColor.fromColor(source);
      double hue = (hsv.hue + hueDelta) % 360.0;
      if (hue < 0) {
        hue += 360.0;
      }
      final double saturation = (hsv.saturation + saturationDelta).clamp(
        0.0,
        1.0,
      );
      final double value = (hsv.value + lightnessDelta).clamp(0.0, 1.0);
      final Color adjusted = HSVColor.fromAHSV(
        hsv.alpha,
        hue,
        saturation,
        value,
      ).toColor();
      bitmap[i] = adjusted.red;
      bitmap[i + 1] = adjusted.green;
      bitmap[i + 2] = adjusted.blue;
      bitmap[i + 3] = adjusted.alpha;
    }
  }

  void _applyBrightnessContrastToBitmap(
    Uint8List bitmap,
    _BrightnessContrastSettings settings,
  ) {
    final double brightnessOffset = settings.brightness / 100.0 * 255.0;
    final double contrastFactor = math.max(
      0.0,
      1.0 + settings.contrast / 100.0,
    );
    for (int i = 0; i < bitmap.length; i += 4) {
      final int alpha = bitmap[i + 3];
      if (alpha == 0) {
        continue;
      }
      bitmap[i] = _applyBrightnessContrastChannel(
        bitmap[i],
        brightnessOffset,
        contrastFactor,
      );
      bitmap[i + 1] = _applyBrightnessContrastChannel(
        bitmap[i + 1],
        brightnessOffset,
        contrastFactor,
      );
      bitmap[i + 2] = _applyBrightnessContrastChannel(
        bitmap[i + 2],
        brightnessOffset,
        contrastFactor,
      );
    }
  }

  Color _applyHueSaturationToColor(
    Color color,
    _HueSaturationSettings settings,
  ) {
    final HSVColor hsv = HSVColor.fromColor(color);
    double hue = (hsv.hue + settings.hue) % 360.0;
    if (hue < 0) {
      hue += 360.0;
    }
    final double saturation = (hsv.saturation + settings.saturation / 100.0)
        .clamp(0.0, 1.0);
    final double value = (hsv.value + settings.lightness / 100.0).clamp(
      0.0,
      1.0,
    );
    return HSVColor.fromAHSV(hsv.alpha, hue, saturation, value).toColor();
  }

  Color _applyBrightnessContrastToColor(
    Color color,
    _BrightnessContrastSettings settings,
  ) {
    final double brightnessOffset = settings.brightness / 100.0 * 255.0;
    final double contrastFactor = math.max(
      0.0,
      1.0 + settings.contrast / 100.0,
    );
    final int r = _applyBrightnessContrastChannel(
      color.red,
      brightnessOffset,
      contrastFactor,
    );
    final int g = _applyBrightnessContrastChannel(
      color.green,
      brightnessOffset,
      contrastFactor,
    );
    final int b = _applyBrightnessContrastChannel(
      color.blue,
      brightnessOffset,
      contrastFactor,
    );
    return Color.fromARGB(color.alpha, r, g, b);
  }

  int _applyBrightnessContrastChannel(
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
