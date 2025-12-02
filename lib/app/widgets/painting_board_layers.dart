part of 'painting_board.dart';

const int _layerPreviewRasterHeight = 128;
const double _layerPreviewDisplayHeight = 32;
const double _layerPreviewAspectRatio = 16 / 9;
const double _layerPreviewDisplayWidth =
    _layerPreviewDisplayHeight * _layerPreviewAspectRatio;

mixin _PaintingBoardLayerMixin
    on _PaintingBoardBase, _PaintingBoardLayerTransformMixin {
  final TextEditingController _layerRenameController = TextEditingController();
  final FocusNode _layerRenameFocusNode = FocusNode();
  String? _renamingLayerId;
  final FlyoutController _layerContextMenuController = FlyoutController();
  final FlyoutController _blendModeFlyoutController = FlyoutController();

  List<CanvasLayerData> _buildInitialLayers() {
    final List<CanvasLayerData>? provided = widget.initialLayers;
    if (provided != null && provided.isNotEmpty) {
      return List<CanvasLayerData>.from(provided);
    }
    final int width = widget.settings.width.round();
    final int height = widget.settings.height.round();
    final Color background = widget.settings.backgroundColor;
    return <CanvasLayerData>[
      CanvasLayerData(id: generateLayerId(), name: '背景', fillColor: background),
      CanvasLayerData(
        id: generateLayerId(),
        name: '图层 2',
        bitmap: Uint8List(width * height * 4),
        bitmapWidth: width,
        bitmapHeight: height,
      ),
    ];
  }

  Color get _backgroundPreviewColor {
    if (_layers.isEmpty) {
      return widget.settings.backgroundColor;
    }
    final BitmapLayerState baseLayer = _layers.first;
    final Uint32List pixels = baseLayer.surface.pixels;
    if (pixels.isNotEmpty && (pixels[0] >> 24) != 0) {
      return BitmapSurface.decodeColor(pixels[0]);
    }
    return widget.settings.backgroundColor;
  }

  void _handleLayerVisibilityChanged(String id, bool visible) async {
    BitmapLayerState? target;
    for (final BitmapLayerState layer in _layers) {
      if (layer.id == id) {
        target = layer;
        break;
      }
    }
    if (target != null && target.visible == visible) {
      return;
    }
    await _pushUndoSnapshot();
    _controller.updateLayerVisibility(id, visible);
    setState(() {});
    _markDirty();
  }

  void _handleLayerSelected(String id) {
    if (_guardTransformInProgress(message: '请先完成当前自由变换。')) {
      return;
    }
    _layerOpacityPreviewReset(this);
    _controller.setActiveLayer(id);
    setState(() {});
  }

  void _handleLayerRenameFocusChange() {
    if (!_layerRenameFocusNode.hasFocus && _renamingLayerId != null) {
      _finalizeLayerRename();
    }
  }

  void _beginLayerRename(BitmapLayerState layer) {
    if (layer.locked) {
      return;
    }
    if (_renamingLayerId != null && _renamingLayerId != layer.id) {
      _finalizeLayerRename(cancel: true);
    }
    _layerRenameController
      ..text = layer.name
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: layer.name.length,
      );
    setState(() {
      _renamingLayerId = layer.id;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _renamingLayerId != layer.id) {
        return;
      }
      if (!_layerRenameFocusNode.hasFocus) {
        _layerRenameFocusNode.requestFocus();
      }
    });
  }

  void _finalizeLayerRename({bool cancel = false}) async {
    final String? targetId = _renamingLayerId;
    if (targetId == null) {
      return;
    }
    final String nextName = _layerRenameController.text.trim();
    setState(() {
      _renamingLayerId = null;
    });
    if (cancel || nextName.isEmpty) {
      return;
    }
    BitmapLayerState? target;
    for (final BitmapLayerState layer in _layers) {
      if (layer.id == targetId) {
        target = layer;
        break;
      }
    }
    if (target == null || target.name == nextName) {
      return;
    }
    await _pushUndoSnapshot();
    _controller.renameLayer(target.id, nextName);
    setState(() {});
    _markDirty();
  }

  void _handleAddLayer() async {
    await _pushUndoSnapshot();
    _controller.addLayer(aboveLayerId: _activeLayerId);
    setState(() {});
    _markDirty();
  }

  void _handleRemoveLayer(String id) async {
    if (_layers.length <= 1) {
      return;
    }
    await _pushUndoSnapshot();
    _controller.removeLayer(id);
    setState(() {});
    _markDirty();
  }

  Widget _buildAddLayerButton() {
    return Button(
      onPressed: _handleAddLayer,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(FluentIcons.add, size: 14),
          SizedBox(width: 6),
          Text('新增图层'),
        ],
      ),
    );
  }

  void _handleLayerReorder(int oldIndex, int newIndex) async {
    final int length = _layers.length;
    if (length <= 1) {
      return;
    }
    int targetIndex = newIndex;
    if (targetIndex > oldIndex) {
      targetIndex -= 1;
    }
    final int actualOldIndex = length - 1 - oldIndex;
    final int actualNewIndex = length - 1 - targetIndex;
    if (actualOldIndex == actualNewIndex) {
      return;
    }
    await _pushUndoSnapshot();
    _controller.reorderLayer(actualOldIndex, actualNewIndex);
    setState(() {});
    _markDirty();
  }

  BitmapLayerState? _currentActiveLayer() {
    final String? activeId = _activeLayerId;
    if (activeId == null) {
      return null;
    }
    for (final BitmapLayerState layer in _layers) {
      if (layer.id == activeId) {
        return layer;
      }
    }
    return null;
  }

  void _handleLayerOpacityChangeStart(double _) {
    final BitmapLayerState? layer = _currentActiveLayer();
    if (layer == null) {
      return;
    }
    if (_layerOpacityGestureActive && _layerOpacityGestureLayerId == layer.id) {
      return;
    }
    _layerOpacityGestureActive = true;
    _layerOpacityGestureLayerId = layer.id;
    _layerOpacityUndoOriginalValue = layer.opacity;
    _ensureLayerOpacityPreview(layer);
  }

  void _handleLayerOpacityChangeEnd(double value) {
    _layerOpacityGestureActive = false;
    final String? targetLayerId = _layerOpacityGestureLayerId;
    final double? originalValue = _layerOpacityUndoOriginalValue;
    _layerOpacityGestureLayerId = null;
    _layerOpacityUndoOriginalValue = null;
    final double clampedValue = value.clamp(0.0, 1.0);
    final bool applied = _applyLayerOpacityValue(targetLayerId, clampedValue);
    final bool shouldHoldPreview =
        applied &&
        targetLayerId != null &&
        _layerOpacityPreviewActive &&
        _layerOpacityPreviewLayerId == targetLayerId &&
        _layerOpacityPreviewActiveLayerImage != null;
    if (shouldHoldPreview) {
      _layerOpacityPreviewAwaitedGeneration =
          _controller.frame?.generation ?? -1;
      if (_layerOpacityPreviewValue == null ||
          (_layerOpacityPreviewValue! - clampedValue).abs() >= 1e-4) {
        setState(() {
          _layerOpacityPreviewValue = clampedValue;
        });
      }
    } else {
      _layerOpacityPreviewDeactivate(this, notifyListeners: true);
    }
    if (targetLayerId != null && originalValue != null) {
      unawaited(_commitLayerOpacityUndoSnapshot(targetLayerId, originalValue));
    }
  }

  void _handleLayerOpacityChanged(double value) {
    final BitmapLayerState? layer = _currentActiveLayer();
    if (layer == null) {
      return;
    }
    _ensureLayerOpacityPreview(layer);
    final double clamped = value.clamp(0.0, 1.0);
    if (_layerOpacityPreviewValue == null ||
        (_layerOpacityPreviewValue! - clamped).abs() >= 1e-4) {
      setState(() {
        _layerOpacityPreviewValue = clamped;
      });
    }
  }

  bool _applyLayerOpacityValue(String? layerId, double value) {
    if (layerId == null) {
      return false;
    }
    final BitmapLayerState? layer = _layerById(layerId);
    if (layer == null) {
      return false;
    }
    final double clamped = value.clamp(0.0, 1.0);
    if ((layer.opacity - clamped).abs() < 1e-4) {
      return false;
    }
    _controller.setLayerOpacity(layerId, clamped);
    setState(() {});
    _markDirty();
    return true;
  }

  void _ensureLayerOpacityPreview(BitmapLayerState layer) {
    bool needsImages =
        _layerOpacityPreviewLayerId != layer.id ||
            _layerOpacityPreviewActiveLayerImage == null;
    if (!needsImages) {
      final int currentSignature = _layerOpacityPreviewSignature(_layers);
      needsImages = _layerOpacityPreviewCapturedSignature == null ||
          _layerOpacityPreviewCapturedSignature != currentSignature;
    }
    _layerOpacityPreviewLayerId = layer.id;
    _layerOpacityPreviewHasVisibleLowerLayers = _hasVisibleLayersBelow(layer);
    if (!_layerOpacityPreviewActive) {
      _layerOpacityPreviewActive = true;
    }
    _layerOpacityPreviewValue ??= layer.opacity.clamp(0.0, 1.0);
    setState(() {});
    if (needsImages) {
      final int requestId = ++_layerOpacityPreviewRequestId;
      unawaited(_loadLayerOpacityPreviewImages(layer.id, requestId));
    }
  }

  bool _hasVisibleLayersBelow(BitmapLayerState target) {
    for (final BitmapLayerState layer in _layers) {
      if (layer.id == target.id) {
        break;
      }
      if (layer.visible && layer.opacity > 1e-4) {
        return true;
      }
    }
    return false;
  }

  Future<void> _loadLayerOpacityPreviewImages(
    String layerId,
    int requestId,
  ) async {
    final List<BitmapLayerState> snapshot = _layers.toList();
    _LayerPreviewImages previews;
    try {
      previews = await _captureLayerPreviewImages(
        controller: _controller,
        layers: snapshot,
        activeLayerId: layerId,
        captureActiveLayerAtFullOpacity: true,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to capture opacity preview: $error');
      debugPrint('$stackTrace');
      return;
    }
    if (!mounted ||
        requestId != _layerOpacityPreviewRequestId ||
        _layerOpacityPreviewLayerId != layerId) {
      previews.dispose();
      return;
    }
    _layerOpacityPreviewDisposeImages(this);
    _layerOpacityPreviewBackground = previews.background;
    _layerOpacityPreviewActiveLayerImage = previews.active;
    _layerOpacityPreviewForeground = previews.foreground;
    _layerOpacityPreviewCapturedSignature =
        _layerOpacityPreviewSignature(snapshot);
    setState(() {});
  }

  Future<void> _commitLayerOpacityUndoSnapshot(
    String layerId,
    double originalOpacity,
  ) async {
    try {
      final _CanvasHistoryEntry base = await _createHistoryEntry();
      final List<CanvasLayerData> layers =
          List<CanvasLayerData>.from(base.layers);
      final int index = layers.indexWhere((layer) => layer.id == layerId);
      if (index < 0) {
        return;
      }
      layers[index] = layers[index].copyWith(
        opacity: originalOpacity,
        cloneBitmap: false,
      );
      await _pushUndoSnapshot(
        entry: _CanvasHistoryEntry(
          layers: layers,
          backgroundColor: base.backgroundColor,
          activeLayerId: base.activeLayerId,
          selectionShape: base.selectionShape,
          selectionMask: base.selectionMask,
          selectionPath: base.selectionPath != null
              ? (Path()..addPath(base.selectionPath!, Offset.zero))
              : null,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to capture opacity undo snapshot: $error');
      debugPrint('$stackTrace');
    }
  }

  void _applyLayerLockedState(BitmapLayerState layer, bool locked) async {
    if (layer.locked == locked) {
      return;
    }
    if (locked && _renamingLayerId == layer.id) {
      _finalizeLayerRename(cancel: true);
    }
    await _pushUndoSnapshot();
    _controller.setLayerLocked(layer.id, locked);
    setState(() {});
  }

  void _updateActiveLayerLocked(bool locked) {
    final BitmapLayerState? layer = _currentActiveLayer();
    if (layer == null) {
      return;
    }
    _applyLayerLockedState(layer, locked);
  }

  void _handleLayerLockToggle(BitmapLayerState layer) {
    _applyLayerLockedState(layer, !layer.locked);
  }

  BitmapLayerState? _layerById(String id) {
    for (final BitmapLayerState candidate in _layers) {
      if (candidate.id == id) {
        return candidate;
      }
    }
    return null;
  }

  bool _canMergeLayerDown(BitmapLayerState layer) {
    if (layer.locked) {
      return false;
    }
    final int index = _layers.indexWhere(
      (candidate) => candidate.id == layer.id,
    );
    if (index <= 0) {
      return false;
    }
    final BitmapLayerState below = _layers[index - 1];
    return !below.locked;
  }

  void _handleMergeLayerDown(BitmapLayerState layer) async {
    if (!_canMergeLayerDown(layer)) {
      return;
    }
    await _pushUndoSnapshot();
    if (!_controller.mergeLayerDown(layer.id)) {
      return;
    }
    setState(() {});
    _markDirty();
  }

  void _handleLayerClippingToggle(BitmapLayerState layer) async {
    if (layer.locked) {
      return;
    }
    final bool nextValue = !layer.clippingMask;
    await _pushUndoSnapshot();
    _controller.setLayerClippingMask(layer.id, nextValue);
    setState(() {});
    _markDirty();
  }

  void _handleDuplicateLayer(BitmapLayerState layer) async {
    final CanvasLayerData? snapshot = _controller.buildClipboardLayer(layer.id);
    if (snapshot == null) {
      return;
    }
    final String newId = generateLayerId();
    final String nextName = layer.name.isEmpty ? '复制图层' : '${layer.name} 副本';
    final CanvasLayerData duplicate = snapshot.copyWith(
      id: newId,
      name: nextName,
      visible: true,
      locked: false,
      clippingMask: layer.clippingMask,
    );
    await _pushUndoSnapshot();
    _controller.insertLayerFromData(duplicate, aboveLayerId: layer.id);
    _controller.setActiveLayer(newId);
    setState(() {});
    _markDirty();
  }

  void _showLayerContextMenu(BitmapLayerState layer, Offset position) {
    _handleLayerSelected(layer.id);
    _layerContextMenuController.showFlyout(
      position: position,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      builder: (context) {
        final BitmapLayerState? target = _layerById(layer.id);
        if (target == null) {
          return const SizedBox.shrink();
        }
        return MenuFlyout(items: _buildLayerContextMenuItems(target));
      },
    );
  }

  List<MenuFlyoutItemBase> _buildLayerContextMenuItems(BitmapLayerState layer) {
    final bool canDelete = _layers.length > 1 && !layer.locked;
    final bool canMerge = _canMergeLayerDown(layer);
    final bool isLocked = layer.locked;
    final bool isVisible = layer.visible;
    final bool isClipping = layer.clippingMask;

    return <MenuFlyoutItemBase>[
      MenuFlyoutItem(
        leading: Icon(isLocked ? FluentIcons.lock : FluentIcons.unlock),
        text: Text(isLocked ? '解锁图层' : '锁定图层'),
        onPressed: () => _handleLayerLockToggle(layer),
      ),
      MenuFlyoutItem(
        leading: const Icon(FluentIcons.combine),
        text: const Text('向下合并'),
        onPressed: canMerge ? () => _handleMergeLayerDown(layer) : null,
      ),
      MenuFlyoutItem(
        leading: Icon(
          isClipping ? FluentIcons.subtract_shape : FluentIcons.subtract_shape,
        ),
        text: Text(isClipping ? '取消剪贴蒙版' : '创建剪贴蒙版'),
        onPressed: isLocked ? null : () => _handleLayerClippingToggle(layer),
      ),
      MenuFlyoutItem(
        leading: Icon(isVisible ? FluentIcons.hide3 : FluentIcons.view),
        text: Text(isVisible ? '隐藏' : '显示'),
        onPressed: () =>
            _handleLayerVisibilityChanged(layer.id, !layer.visible),
      ),
      MenuFlyoutItem(
        leading: const Icon(FluentIcons.delete),
        text: const Text('删除'),
        onPressed: canDelete ? () => _handleRemoveLayer(layer.id) : null,
      ),
      MenuFlyoutItem(
        leading: const Icon(FluentIcons.copy),
        text: const Text('复制'),
        onPressed: () => _handleDuplicateLayer(layer),
      ),
    ];
  }

  void _updateActiveLayerClipping(bool clipping) async {
    final BitmapLayerState? layer = _currentActiveLayer();
    if (layer == null || layer.clippingMask == clipping) {
      return;
    }
    await _pushUndoSnapshot();
    _controller.setLayerClippingMask(layer.id, clipping);
    setState(() {});
  }

  void _updateActiveLayerBlendMode(CanvasLayerBlendMode mode) async {
    final BitmapLayerState? layer = _currentActiveLayer();
    if (layer == null || layer.blendMode == mode) {
      return;
    }
    await _pushUndoSnapshot();
    _controller.setLayerBlendMode(layer.id, mode);
    setState(() {});
  }

  void _toggleBlendModeFlyout(CanvasLayerBlendMode selected) {
    if (_blendModeFlyoutController.isOpen) {
      _blendModeFlyoutController.close();
      return;
    }
    _blendModeFlyoutController.showFlyout(
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      placementMode: FlyoutPlacementMode.bottomLeft,
      additionalOffset: 0,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      builder: (context) {
        return MenuFlyout(
          items: kCanvasBlendModeDisplayOrder
              .map(
                (CanvasLayerBlendMode mode) => MenuFlyoutItem(
                  selected: mode == selected,
                  text: Text(mode.label),
                  onPressed: () {
                    if (mode != selected) {
                      _updateActiveLayerBlendMode(mode);
                    }
                  },
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildBlendModeDropdown({
    required FluentThemeData theme,
    required CanvasLayerBlendMode mode,
    required bool isLocked,
  }) {
    final TextStyle baseStyle =
        theme.typography.body ?? const TextStyle(fontSize: 14);
    final Color textColor = isLocked
        ? theme.resources.textFillColorDisabled
        : baseStyle.color ?? theme.resources.textFillColorPrimary;
    return FlyoutTarget(
      controller: _blendModeFlyoutController,
      child: Button(
        style: const ButtonStyle(
          padding: WidgetStatePropertyAll(EdgeInsets.zero),
        ),
        onPressed: isLocked ? null : () => _toggleBlendModeFlyout(mode),
        child: Container(
          padding: const EdgeInsetsDirectional.only(start: 11, end: 15),
          constraints: const BoxConstraints(minHeight: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  mode.label,
                  style: baseStyle.copyWith(color: textColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                FluentIcons.chevron_down,
                size: 8,
                color: isLocked
                    ? theme.resources.textFillColorDisabled
                    : theme.resources.textFillColorSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> applyLayerAntialiasLevel(int level) async {
    final BitmapLayerState? layer = _currentActiveLayer();
    if (layer == null || layer.locked) {
      return false;
    }
    final int clamped = level.clamp(0, 3);
    if (!_controller.applyAntialiasToActiveLayer(clamped, previewOnly: true)) {
      return false;
    }
    await _pushUndoSnapshot();
    _controller.applyAntialiasToActiveLayer(clamped);
    setState(() {});
    _markDirty();
    return true;
  }

  Widget _buildPanelDivider(FluentThemeData theme) {
    final Color dividerColor = theme.resources.controlStrokeColorDefault
        .withOpacity(0.35);
    return SizedBox(
      height: 1,
      child: DecoratedBox(decoration: BoxDecoration(color: dividerColor)),
    );
  }

  Widget _buildInlineLayerRenameField(
    FluentThemeData theme, {
    required bool isActive,
    required String layerId,
    TextStyle? styleOverride,
  }) {
    final TextStyle style =
        styleOverride ??
        (isActive ? theme.typography.bodyStrong : theme.typography.body) ??
        const TextStyle(fontSize: 14);
    final double fontSize = style.fontSize ?? 14;
    final double lineHeight = (style.height ?? 1.0) * fontSize;
    final Color cursorColor = theme.accentColor.defaultBrushFor(
      theme.brightness,
    );
    final Color selectionColor = cursorColor.withOpacity(0.35);
    return SizedBox(
      height: lineHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: EditableText(
          key: ValueKey<String>('layer-rename-$layerId'),
          controller: _layerRenameController,
          focusNode: _layerRenameFocusNode,
          style: style,
          cursorColor: cursorColor,
          backgroundCursorColor: Colors.transparent,
          selectionColor: selectionColor,
          maxLines: 1,
          autofocus: true,
          cursorWidth: 1.3,
          cursorRadius: const Radius.circular(1.5),
          onSubmitted: (_) => _finalizeLayerRename(),
          onEditingComplete: _finalizeLayerRename,
          onTapOutside: (_) => _finalizeLayerRename(),
          textInputAction: TextInputAction.done,
          keyboardType: TextInputType.text,
          strutStyle: StrutStyle(
            forceStrutHeight: true,
            height: 1.0,
            fontSize: fontSize,
          ),
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
        ),
      ),
    );
  }

  Widget? _buildLayerControlStrip(
    FluentThemeData theme,
    BitmapLayerState? activeLayer,
  ) {
    if (activeLayer == null) {
      return null;
    }
    final bool isSai2Layout =
        widget.toolbarLayoutStyle == PaintingToolbarLayoutStyle.sai2;
    final bool showHistoryButtons = true;

    double clampedOpacity = activeLayer.opacity.clamp(0.0, 1.0).toDouble();
    if (_layerOpacityPreviewActive &&
        _layerOpacityPreviewLayerId == activeLayer.id &&
        _layerOpacityPreviewValue != null) {
      clampedOpacity = _layerOpacityPreviewValue!.clamp(0.0, 1.0);
    }
    final int opacityPercent = (clampedOpacity * 100).round();
    final TextStyle labelStyle =
        theme.typography.caption ??
        theme.typography.body?.copyWith(fontSize: 12) ??
        const TextStyle(fontSize: 12);

    Color _historyIconColor(bool enabled) {
      final Color baseColor =
          theme.typography.body?.color ??
          theme.typography.bodyStrong?.color ??
          (theme.brightness.isDark ? Colors.white : const Color(0xFF1F1F1F));
      if (enabled) {
        return baseColor;
      }
      return baseColor.withOpacity(theme.brightness.isDark ? 0.5 : 0.35);
    }

    Widget buildHistoryButton({
      required IconData icon,
      required String label,
      required bool enabled,
      required VoidCallback onPressed,
    }) {
      final Color color = _historyIconColor(enabled);
      return Tooltip(
        message: label,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(icon, size: 16, color: color),
            ),
          ),
        ),
      );
    }

    Widget historyRow() {
      final String undoShortcut = ToolbarShortcuts.labelForPlatform(
        ToolbarAction.undo,
        defaultTargetPlatform,
      );
      final String redoShortcut = ToolbarShortcuts.labelForPlatform(
        ToolbarAction.redo,
        defaultTargetPlatform,
      );
      final String undoLabel = undoShortcut.isEmpty
          ? '撤销'
          : '撤销 ($undoShortcut)';
      final String redoLabel = redoShortcut.isEmpty
          ? '恢复'
          : '恢复 ($redoShortcut)';
      return Row(
        children: [
          buildHistoryButton(
            icon: FluentIcons.undo,
            label: undoLabel,
            enabled: canUndo,
            onPressed: _handleUndo,
          ),
          const SizedBox(width: 8),
          buildHistoryButton(
            icon: FluentIcons.redo,
            label: redoLabel,
            enabled: canRedo,
            onPressed: _handleRedo,
          ),
        ],
      );
    }

    Widget opacityRow() {
      final bool locked = activeLayer.locked;
      final Slider slider = Slider(
        value: clampedOpacity,
        min: 0,
        max: 1,
        divisions: 100,
        onChangeStart: locked ? null : _handleLayerOpacityChangeStart,
        onChanged: locked ? null : _handleLayerOpacityChanged,
        onChangeEnd: locked ? null : _handleLayerOpacityChangeEnd,
      );
      if (isSai2Layout) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('不透明度 $opacityPercent%', style: labelStyle),
            const SizedBox(height: 8),
            slider,
          ],
        );
      }
      return Row(
        children: [
          SizedBox(width: 52, child: Text('不透明度', style: labelStyle)),
          const SizedBox(width: 8),
          Expanded(child: slider),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: Text(
              '$opacityPercent%',
              textAlign: TextAlign.end,
              style: theme.typography.bodyStrong,
            ),
          ),
        ],
      );
    }

    Widget toggleRow() {
      Widget buildLabeledCheckbox({
        required String label,
        required bool value,
        ValueChanged<bool>? onChanged,
      }) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 6),
            Checkbox(
              checked: value,
              content: const SizedBox.shrink(),
              onChanged: onChanged == null
                  ? null
                  : (checked) => onChanged(checked ?? value),
            ),
          ],
        );
      }

      final Widget lockCheckbox = buildLabeledCheckbox(
        label: '锁定图层',
        value: activeLayer.locked,
        onChanged: _updateActiveLayerLocked,
      );
      final Widget clipCheckbox = buildLabeledCheckbox(
        label: '剪贴蒙版',
        value: activeLayer.clippingMask,
        onChanged: activeLayer.locked ? null : _updateActiveLayerClipping,
      );
      if (isSai2Layout) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [lockCheckbox, const SizedBox(height: 8), clipCheckbox],
        );
      }
      return Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [lockCheckbox, clipCheckbox],
      );
    }

    Widget blendRow() {
      final Widget dropdown = _buildBlendModeDropdown(
        theme: theme,
        mode: activeLayer.blendMode,
        isLocked: activeLayer.locked,
      );
      if (isSai2Layout) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('混合模式', style: labelStyle),
            const SizedBox(height: 8),
            dropdown,
          ],
        );
      }
      return Row(
        children: [
          SizedBox(width: 52, child: Text('混合模式', style: labelStyle)),
          const SizedBox(width: 8),
          Expanded(child: dropdown),
        ],
      );
    }

    final List<Widget> controls = <Widget>[];
    if (showHistoryButtons) {
      controls
        ..add(historyRow())
        ..add(const SizedBox(height: 6));
    }
    if (!isSai2Layout) {
      controls
        ..add(_buildAddLayerButton())
        ..add(const SizedBox(height: 6));
    }
    controls
      ..add(opacityRow())
      ..add(const SizedBox(height: 6))
      ..add(toggleRow())
      ..add(const SizedBox(height: 6))
      ..add(blendRow());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: controls,
    );
  }

  Map<String, bool> _computeLayerTileDimStates() {
    final Map<String, bool> dimStates = <String, bool>{};
    BitmapLayerState? clippingOwner;
    for (final BitmapLayerState layer in _layers) {
      if (!layer.clippingMask) {
        clippingOwner = layer;
        dimStates[layer.id] = !layer.visible;
        continue;
      }
      final bool ownerDimmed = clippingOwner == null
          ? true
          : (dimStates[clippingOwner.id] ?? !clippingOwner.visible);
      dimStates[layer.id] = !layer.visible || ownerDimmed;
    }
    return dimStates;
  }

  void _pruneLayerPreviewCache(Iterable<BitmapLayerState> layers) {
    if (_layerPreviewCache.isEmpty) {
      return;
    }
    final Set<String> liveIds = layers.map((layer) => layer.id).toSet();
    final List<String> stale = <String>[];
    for (final String id in _layerPreviewCache.keys) {
      if (!liveIds.contains(id)) {
        stale.add(id);
      }
    }
    if (stale.isEmpty) {
      return;
    }
    for (final String id in stale) {
      final _LayerPreviewCacheEntry? entry = _layerPreviewCache.remove(id);
      entry?.dispose();
    }
  }

  void _ensureLayerPreview(BitmapLayerState layer) {
    final _LayerPreviewCacheEntry? entry = _layerPreviewCache[layer.id];
    if (entry != null && entry.revision == layer.revision) {
      return;
    }
    final int requestId = ++_layerPreviewRequestSerial;
    final _LayerPreviewCacheEntry target =
        entry ?? _LayerPreviewCacheEntry(requestId: requestId);
    target.requestId = requestId;
    _layerPreviewCache[layer.id] = target;
    unawaited(
      _captureLayerPreviewThumbnail(
        layerId: layer.id,
        surface: layer.surface,
        revision: layer.revision,
        requestId: requestId,
      ),
    );
  }

  ui.Image? _layerPreviewImage(String layerId) {
    return _layerPreviewCache[layerId]?.image;
  }

  Future<void> _captureLayerPreviewThumbnail({
    required String layerId,
    required BitmapSurface surface,
    required int revision,
    required int requestId,
  }) async {
    final _LayerPreviewPixels? pixels = _buildLayerPreviewPixels(surface);
    ui.Image? image;
    if (pixels != null) {
      try {
        image = await _decodeImage(
          pixels.bytes,
          pixels.width,
          pixels.height,
        );
      } catch (error, stackTrace) {
        debugPrint('Failed to build layer preview for $layerId: $error');
        debugPrint('$stackTrace');
        image = null;
      }
    }
    _applyLayerPreviewResult(
      layerId: layerId,
      revision: revision,
      requestId: requestId,
      image: image,
    );
  }

  void _applyLayerPreviewResult({
    required String layerId,
    required int revision,
    required int requestId,
    ui.Image? image,
  }) {
    if (!mounted) {
      image?.dispose();
      return;
    }
    final _LayerPreviewCacheEntry? entry = _layerPreviewCache[layerId];
    if (entry == null || entry.requestId != requestId) {
      image?.dispose();
      return;
    }
    final ui.Image? previous = entry.image;
    final bool changed = previous != image || entry.revision != revision;
    entry
      ..image = image
      ..revision = revision;
    if (!changed) {
      return;
    }
    setState(() {});
    if (previous != null && previous != image) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  _LayerPreviewPixels? _buildLayerPreviewPixels(BitmapSurface surface) {
    final int width = surface.width;
    final int height = surface.height;
    if (width <= 0 || height <= 0) {
      return null;
    }
    final int targetHeight = math.min(_layerPreviewRasterHeight, height);
    final double scale = targetHeight / height;
    final int targetWidth = math.max(1, (width * scale).round());
    if (targetWidth <= 0 || targetHeight <= 0) {
      return null;
    }
    final Uint8List rgba = Uint8List(targetWidth * targetHeight * 4);
    final double stepX = width / targetWidth;
    final double stepY = height / targetHeight;
    int dest = 0;
    for (int y = 0; y < targetHeight; y++) {
      final int sourceY = (y * stepY).floor().clamp(0, height - 1);
      final int rowBase = sourceY * width;
      for (int x = 0; x < targetWidth; x++) {
        final int sourceX = (x * stepX).floor().clamp(0, width - 1);
        final int argb = surface.pixels[rowBase + sourceX];
        rgba[dest++] = (argb >> 16) & 0xFF;
        rgba[dest++] = (argb >> 8) & 0xFF;
        rgba[dest++] = argb & 0xFF;
        rgba[dest++] = (argb >> 24) & 0xFF;
      }
    }
    return _LayerPreviewPixels(bytes: rgba, width: targetWidth, height: targetHeight);
  }

  void _disposeLayerPreviewCache() {
    if (_layerPreviewCache.isEmpty) {
      return;
    }
    for (final _LayerPreviewCacheEntry entry in _layerPreviewCache.values) {
      entry.dispose();
    }
    _layerPreviewCache.clear();
  }

  Widget _buildLayerPanelContent(FluentThemeData theme) {
    final bool isSai2Layout =
        widget.toolbarLayoutStyle == PaintingToolbarLayoutStyle.sai2;
    final List<BitmapLayerState> orderedLayers = _layers
        .toList(growable: false)
        .reversed
        .toList(growable: false);
    _pruneLayerPreviewCache(_layers);
    final Map<String, bool> layerTileDimStates = _computeLayerTileDimStates();
    final String? activeLayerId = _activeLayerId;
    final Color fallbackCardColor = theme.brightness.isDark
        ? const Color(0xFF1F1F1F)
        : Colors.white;
    Color tileBaseColor = theme.cardColor;
    if (tileBaseColor.alpha != 0xFF) {
      tileBaseColor = fallbackCardColor;
    }

    BitmapLayerState? activeLayer;
    if (activeLayerId != null) {
      for (final BitmapLayerState candidate in _layers) {
        if (candidate.id == activeLayerId) {
          activeLayer = candidate;
          break;
        }
      }
    }
    final Widget? layerControls = _buildLayerControlStrip(theme, activeLayer);

    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        if (isSai2Layout) ...[
          _buildPanelDivider(theme),
          const SizedBox(height: 6),
        ] else
          const SizedBox(height: 6),
        if (layerControls != null) ...[
          layerControls,
          const SizedBox(height: 6),
          _buildPanelDivider(theme),
          const SizedBox(height: 6),
        ],
        Expanded(
          child: FlyoutTarget(
            controller: _layerContextMenuController,
            child: Scrollbar(
              controller: _layerScrollController,
              child: Localizations.override(
                context: context,
                delegates: const [GlobalMaterialLocalizations.delegate],
                child: material.ReorderableListView.builder(
                  scrollController: _layerScrollController,
                  padding: EdgeInsets.zero,
                  buildDefaultDragHandles: false,
                  dragStartBehavior: DragStartBehavior.down,
                  proxyDecorator: (child, index, animation) => child,
                  itemCount: orderedLayers.length,
                  onReorder: _handleLayerReorder,
                  itemBuilder: (context, index) {
                    final BitmapLayerState layer = orderedLayers[index];
                    final bool isActive = layer.id == activeLayerId;
                    final bool tileDimmed =
                        layerTileDimStates[layer.id] ?? !layer.visible;
                    final double contentOpacity = tileDimmed ? 0.45 : 1.0;
                    final Color background = isActive
                        ? Color.alphaBlend(
                            theme.resources.subtleFillColorSecondary,
                            tileBaseColor,
                          )
                        : tileBaseColor;
                    final Color borderColor =
                        theme.resources.controlStrokeColorSecondary;
                    final Color tileBorder = Color.lerp(
                      borderColor,
                      Colors.transparent,
                      0.6,
                    )!;

                    final bool layerLocked = layer.locked;
                    final bool layerClipping = layer.clippingMask;
                    final bool showTileButtons = !isSai2Layout;
                    _ensureLayerPreview(layer);
                    final ui.Image? layerPreview = _layerPreviewImage(layer.id);

                    final Widget visibilityButton = LayerVisibilityButton(
                      visible: layer.visible,
                      onChanged: (value) =>
                          _handleLayerVisibilityChanged(layer.id, value),
                    );

                    Widget? lockButton;
                    Widget? clippingButton;
                    if (showTileButtons) {
                      lockButton = Tooltip(
                        message: layerLocked ? '解锁图层' : '锁定图层',
                        child: IconButton(
                          icon: Icon(
                            layerLocked ? FluentIcons.lock : FluentIcons.unlock,
                          ),
                          onPressed: () => _handleLayerLockToggle(layer),
                        ),
                      );
                      final Color clippingActiveBackground = Color.alphaBlend(
                        (theme.brightness.isDark ? Colors.white : Colors.black)
                            .withOpacity(theme.brightness.isDark ? 0.18 : 0.08),
                        background,
                      );
                      clippingButton = Tooltip(
                        message: layerClipping ? '取消剪贴蒙版' : '创建剪贴蒙版',
                        child: IconButton(
                          icon: const Icon(FluentIcons.subtract_shape),
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (layerClipping) {
                                return clippingActiveBackground;
                              }
                              if (states.contains(WidgetState.disabled)) {
                                return theme.resources.controlFillColorDisabled;
                              }
                              return null;
                            }),
                          ),
                          onPressed: layerLocked
                              ? null
                              : () => _handleLayerClippingToggle(layer),
                        ),
                      );
                    }

                    final bool canDelete = _layers.length > 1 && !layerLocked;
                    final Widget deleteButton = IconButton(
                      icon: const Icon(FluentIcons.delete),
                      onPressed: canDelete
                          ? () => _handleRemoveLayer(layer.id)
                          : null,
                    );
                    final List<Widget> trailingButtons = <Widget>[];
                    void addTrailingButton(Widget widget) {
                      if (trailingButtons.isNotEmpty) {
                        trailingButtons.add(const SizedBox(width: 4));
                      }
                      trailingButtons.add(widget);
                    }

                    if (clippingButton != null) {
                      addTrailingButton(clippingButton);
                    }
                    if (lockButton != null) {
                      addTrailingButton(lockButton);
                    }
                    addTrailingButton(deleteButton);
                    return material.ReorderableDragStartListener(
                      key: ValueKey(layer.id),
                      index: index,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: layer.clippingMask ? 18 : 0,
                          bottom: index == orderedLayers.length - 1 ? 0 : 8,
                        ),
                        child: _LayerTile(
                          onTapDown: (_) => _handleLayerSelected(layer.id),
                          onSecondaryTapDown: (details) =>
                              _showLayerContextMenu(
                                layer,
                                details.globalPosition,
                              ),
                          backgroundColor: background,
                          borderColor: tileBorder,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  visibilityButton,
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Opacity(
                                      opacity: contentOpacity,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _LayerNameView(
                                            layer: layer,
                                            theme: theme,
                                            isActive: isActive,
                                            isRenaming: !layerLocked &&
                                                _renamingLayerId == layer.id,
                                            isLocked: layerLocked,
                                            buildEditor: (style) =>
                                                _buildInlineLayerRenameField(
                                                  theme,
                                                  isActive: isActive,
                                                  layerId: layer.id,
                                                  styleOverride: style,
                                                ),
                                            onRequestRename: layerLocked
                                                ? null
                                                : () {
                                                    _handleLayerSelected(
                                                      layer.id,
                                                    );
                                                    _beginLayerRename(layer);
                                                  },
                                          ),
                                          const SizedBox(height: 6),
                                          _LayerPreviewThumbnail(
                                            image: layerPreview,
                                            theme: theme,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  ...trailingButtons,
                                ],
                              ),
                              if (layer.clippingMask)
                                Positioned(
                                  left: -10,
                                  top: 6,
                                  bottom: 6,
                                  child: _ClippingMaskIndicator(
                                    color: theme.accentColor.defaultBrushFor(
                                      theme.brightness,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        if (isSai2Layout) ...[
          _buildPanelDivider(theme),
          const SizedBox(height: 6),
        ] else
          const SizedBox(height: 6),
        if (layerControls != null) ...[
          layerControls,
          const SizedBox(height: 6),
          _buildPanelDivider(theme),
          const SizedBox(height: 6),
        ],
        Expanded(
          child: FlyoutTarget(
            controller: _layerContextMenuController,
            child: Scrollbar(
              controller: _layerScrollController,
              child: Localizations.override(
                context: context,
                delegates: const [GlobalMaterialLocalizations.delegate],
                child: material.ReorderableListView.builder(
                  scrollController: _layerScrollController,
                  padding: EdgeInsets.zero,
                  buildDefaultDragHandles: false,
                  dragStartBehavior: DragStartBehavior.down,
                  proxyDecorator: (child, index, animation) => child,
                  itemCount: orderedLayers.length,
                  onReorder: _handleLayerReorder,
                  itemBuilder: (context, index) {
                    final BitmapLayerState layer = orderedLayers[index];
                    final bool isActive = layer.id == activeLayerId;
                    final bool tileDimmed =
                        layerTileDimStates[layer.id] ?? !layer.visible;
                    final double contentOpacity = tileDimmed ? 0.45 : 1.0;
                    final Color background = isActive
                        ? Color.alphaBlend(
                            theme.resources.subtleFillColorSecondary,
                            tileBaseColor,
                          )
                        : tileBaseColor;
                    final Color borderColor =
                        theme.resources.controlStrokeColorSecondary;
                    final Color tileBorder = Color.lerp(
                      borderColor,
                      Colors.transparent,
                      0.6,
                    )!;

                    final Widget visibilityButton = LayerVisibilityButton(
                      visible: layer.visible,
                      onChanged: (value) =>
                          _handleLayerVisibilityChanged(layer.id, value),
                    );

                    final bool canDelete = _layers.length > 1;
                    final Widget deleteButton = IconButton(
                      icon: const Icon(FluentIcons.delete),
                      onPressed: canDelete
                          ? () => _handleRemoveLayer(layer.id)
                          : null,
                    );
                    _ensureLayerPreview(layer);
                    final ui.Image? layerPreview = _layerPreviewImage(layer.id);

                    return material.ReorderableDragStartListener(
                      key: ValueKey(layer.id),
                      index: index,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: layer.clippingMask ? 18 : 0,
                          bottom: index == orderedLayers.length - 1 ? 0 : 8,
                        ),
                        child: _LayerTile(
                          onTap: () => _handleLayerSelected(layer.id),
                          onSecondaryTapDown: (details) =>
                              _showLayerContextMenu(
                                layer,
                                details.globalPosition,
                              ),
                          backgroundColor: background,
                          borderColor: tileBorder,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  visibilityButton,
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Opacity(
                                      opacity: contentOpacity,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            layer.name,
                                            style: isActive
                                                ? theme.typography.bodyStrong
                                                : theme.typography.body,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          _LayerPreviewThumbnail(
                                            image: layerPreview,
                                            theme: theme,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  deleteButton,
                                ],
                              ),
                              if (layer.clippingMask)
                                Positioned(
                                  left: -18,
                                  top: 12,
                                  child: _ClippingMaskIndicator(
                                    color: theme.accentColor.defaultBrushFor(
                                      theme.brightness,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClippingMaskIndicator extends StatelessWidget {
  const _ClippingMaskIndicator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _LayerTile extends StatefulWidget {
  const _LayerTile({
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    this.onTap,
    this.onTapDown,
    this.onSecondaryTapDown,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback? onTap;
  final GestureTapDownCallback? onTapDown;
  final GestureTapDownCallback? onSecondaryTapDown;
  final HitTestBehavior behavior;

  @override
  State<_LayerTile> createState() => _LayerTileState();
}

class _LayerTileState extends State<_LayerTile> {
  bool _hovered = false;

  void _setHovered(bool hovered) {
    if (_hovered == hovered) {
      return;
    }
    setState(() => _hovered = hovered);
  }

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final bool isDark = theme.brightness.isDark;
    final Color hoverOverlay = (isDark ? Colors.white : Colors.black)
        .withOpacity(isDark ? 0.08 : 0.05);
    final Color background = _hovered
        ? Color.alphaBlend(hoverOverlay, widget.backgroundColor)
        : widget.backgroundColor;
    final Color border = _hovered
        ? Color.lerp(
                widget.borderColor,
                theme.resources.controlStrokeColorDefault,
                0.35,
              ) ??
              widget.borderColor
        : widget.borderColor;
    final List<BoxShadow>? shadows = _hovered
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ]
        : null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        behavior: widget.behavior,
        onTap: widget.onTap,
        onTapDown: widget.onTapDown,
        onSecondaryTapDown: widget.onSecondaryTapDown,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
            boxShadow: shadows,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _LayerNameView extends StatelessWidget {
  const _LayerNameView({
    required this.layer,
    required this.theme,
    required this.isActive,
    required this.isRenaming,
    required this.isLocked,
    required this.buildEditor,
    this.onRequestRename,
  });

  final BitmapLayerState layer;
  final FluentThemeData theme;
  final bool isActive;
  final bool isRenaming;
  final bool isLocked;
  final Widget Function(TextStyle? effectiveStyle) buildEditor;
  final VoidCallback? onRequestRename;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = isActive
        ? theme.typography.bodyStrong
        : theme.typography.body;
    final Widget text = Text(
      layer.name,
      style: style,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      softWrap: false,
    );
    final Widget display = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: onRequestRename,
      child: text,
    );
    if (!isRenaming || isLocked) {
      return display;
    }
    final double width = _measureWidth(context, style, layer.name) + 6;
    final double clampedWidth = width.clamp(32.0, 400.0).toDouble();
    return SizedBox(
      width: clampedWidth,
      child: Align(alignment: Alignment.centerLeft, child: buildEditor(style)),
    );
  }

  double _measureWidth(BuildContext context, TextStyle? style, String text) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text.isEmpty ? ' ' : text, style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }
}

class _LayerPreviewThumbnail extends StatelessWidget {
  const _LayerPreviewThumbnail({
    required this.image,
    required this.theme,
  });

  final ui.Image? image;
  final FluentThemeData theme;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(6);
    final Widget checkerBackground = CustomPaint(
      painter: _TransparencyGridPainter(
        light: theme.brightness.isDark
            ? const Color(0xFF363636)
            : const Color(0xFFF5F5F5),
        dark: theme.brightness.isDark
            ? const Color(0xFF2A2A2A)
            : const Color(0xFFE0E0E0),
      ),
    );
    final Widget imageWidget = image == null
        ? Center(
            child: Icon(
              FluentIcons.picture,
              size: 12,
              color: theme.resources.textFillColorTertiary,
            ),
          )
        : RawImage(
            image: image,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: ui.FilterQuality.none,
          );
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: _layerPreviewDisplayWidth,
        height: _layerPreviewDisplayHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            checkerBackground,
            imageWidget,
          ],
        ),
      ),
    );
  }
}

class _TransparencyGridPainter extends CustomPainter {
  const _TransparencyGridPainter({
    required this.light,
    required this.dark,
  });

  final Color light;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    const double cellSize = 4;
    final Paint lightPaint = Paint()..color = light;
    final Paint darkPaint = Paint()..color = dark;
    bool darkRow = false;
    for (double y = 0; y < size.height; y += cellSize) {
      bool darkCell = darkRow;
      final double nextY = math.min(size.height, y + cellSize);
      for (double x = 0; x < size.width; x += cellSize) {
        final double nextX = math.min(size.width, x + cellSize);
        canvas.drawRect(
          Rect.fromLTRB(x, y, nextX, nextY),
          darkCell ? darkPaint : lightPaint,
        );
        darkCell = !darkCell;
      }
      darkRow = !darkRow;
    }
  }

  @override
  bool shouldRepaint(covariant _TransparencyGridPainter oldDelegate) {
    return oldDelegate.light != light || oldDelegate.dark != dark;
  }
}

class _LayerPreviewPixels {
  const _LayerPreviewPixels({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

class _LayerPreviewCacheEntry {
  _LayerPreviewCacheEntry({
    required this.requestId,
    this.revision = -1,
    this.image,
  });

  int requestId;
  int revision;
  ui.Image? image;

  void dispose() {
    image?.dispose();
    image = null;
  }
}
