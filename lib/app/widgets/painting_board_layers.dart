part of 'painting_board.dart';

mixin _PaintingBoardLayerMixin on _PaintingBoardBase {
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

  void _handleLayerVisibilityChanged(String id, bool visible) {
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
    _pushUndoSnapshot();
    _controller.updateLayerVisibility(id, visible);
    setState(() {});
    _markDirty();
  }

  void _handleLayerSelected(String id) {
    _controller.setActiveLayer(id);
    setState(() {});
  }

  void _handleAddLayer() {
    _pushUndoSnapshot();
    _controller.addLayer();
    setState(() {});
    _markDirty();
  }

  void _handleRemoveLayer(String id) {
    if (_layers.length <= 1) {
      return;
    }
    _pushUndoSnapshot();
    _controller.removeLayer(id);
    setState(() {});
    _markDirty();
  }

  void _handleLayerReorder(int oldIndex, int newIndex) {
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
    _pushUndoSnapshot();
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
    _pushUndoSnapshot();
    _layerOpacityGestureActive = true;
    _layerOpacityGestureLayerId = layer.id;
  }

  void _handleLayerOpacityChangeEnd(double _) {
    _layerOpacityGestureActive = false;
    _layerOpacityGestureLayerId = null;
  }

  void _handleLayerOpacityChanged(double value) {
    final BitmapLayerState? layer = _currentActiveLayer();
    if (layer == null) {
      return;
    }
    final double clamped = value.clamp(0.0, 1.0);
    if ((layer.opacity - clamped).abs() < 1e-4) {
      return;
    }
    _controller.setLayerOpacity(layer.id, clamped);
    setState(() {});
  }

  void _updateActiveLayerLocked(bool locked) {
    final BitmapLayerState? layer = _currentActiveLayer();
    if (layer == null || layer.locked == locked) {
      return;
    }
    _pushUndoSnapshot();
    _controller.setLayerLocked(layer.id, locked);
    setState(() {});
  }

  void _updateActiveLayerClipping(bool clipping) {
    final BitmapLayerState? layer = _currentActiveLayer();
    if (layer == null || layer.clippingMask == clipping) {
      return;
    }
    _pushUndoSnapshot();
    _controller.setLayerClippingMask(layer.id, clipping);
    setState(() {});
  }

  void _updateActiveLayerBlendMode(CanvasLayerBlendMode mode) {
    final BitmapLayerState? layer = _currentActiveLayer();
    if (layer == null || layer.blendMode == mode) {
      return;
    }
    _pushUndoSnapshot();
    _controller.setLayerBlendMode(layer.id, mode);
    setState(() {});
  }

  Widget _buildPanelDivider(FluentThemeData theme) {
    final Color dividerColor =
        theme.resources.controlStrokeColorDefault.withOpacity(0.35);
    return SizedBox(
      height: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(color: dividerColor),
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

    final double clampedOpacity =
        activeLayer.opacity.clamp(0.0, 1.0).toDouble();
    final int opacityPercent = (clampedOpacity * 100).round();
    final TextStyle labelStyle = theme.typography.caption ??
        theme.typography.body?.copyWith(fontSize: 12) ??
        const TextStyle(fontSize: 12);

    Widget opacityRow() {
      return Row(
        children: [
          SizedBox(
            width: 52,
            child: Text('不透明度', style: labelStyle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Slider(
              value: clampedOpacity,
              min: 0,
              max: 1,
              divisions: 100,
              onChangeStart: _handleLayerOpacityChangeStart,
              onChanged: _handleLayerOpacityChanged,
              onChangeEnd: _handleLayerOpacityChangeEnd,
            ),
          ),
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
        required ValueChanged<bool> onChanged,
      }) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 6),
            Checkbox(
              checked: value,
              content: const SizedBox.shrink(),
              onChanged: (checked) => onChanged(checked ?? value),
            ),
          ],
        );
      }

      return Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          buildLabeledCheckbox(
            label: '锁定图层',
            value: activeLayer.locked,
            onChanged: _updateActiveLayerLocked,
          ),
          buildLabeledCheckbox(
            label: '剪贴蒙版',
            value: activeLayer.clippingMask,
            onChanged: _updateActiveLayerClipping,
          ),
        ],
      );
    }

    Widget blendRow() {
      return Row(
        children: [
          SizedBox(
            width: 52,
            child: Text('图层模式', style: labelStyle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ComboBox<CanvasLayerBlendMode>(
              value: activeLayer.blendMode,
              items: CanvasLayerBlendMode.values
                  .map(
                    (mode) => ComboBoxItem<CanvasLayerBlendMode>(
                      value: mode,
                      child: Text(_blendModeLabel(mode)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (mode) {
                if (mode != null) {
                  _updateActiveLayerBlendMode(mode);
                }
              },
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        opacityRow(),
        const SizedBox(height: 6),
        toggleRow(),
        const SizedBox(height: 6),
        blendRow(),
      ],
    );
  }

  String _blendModeLabel(CanvasLayerBlendMode mode) {
    switch (mode) {
      case CanvasLayerBlendMode.normal:
        return '正常';
      case CanvasLayerBlendMode.multiply:
        return '正片叠底';
    }
  }

  Widget _buildLayerPanelContent(FluentThemeData theme) {
    final List<BitmapLayerState> orderedLayers = _layers
        .toList(growable: false)
        .reversed
        .toList(growable: false);
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
        _buildPanelDivider(theme),
        const SizedBox(height: 6),
        if (layerControls != null) ...[
          layerControls,
          const SizedBox(height: 6),
          _buildPanelDivider(theme),
          const SizedBox(height: 6),
        ],
        Expanded(
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
                  final double contentOpacity = layer.visible ? 1.0 : 0.45;
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

                  return material.ReorderableDragStartListener(
                    key: ValueKey(layer.id),
                    index: index,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: layer.clippingMask ? 18 : 0,
                        bottom: index == orderedLayers.length - 1 ? 0 : 8,
                      ),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _handleLayerSelected(layer.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: tileBorder),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Row(
                                children: [
                                  visibilityButton,
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Opacity(
                                      opacity: contentOpacity,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              layer.name,
                                              style: isActive
                                                  ? theme.typography.bodyStrong
                                                  : theme.typography.body,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (layer.locked) ...[
                                            const SizedBox(width: 6),
                                            Icon(
                                              FluentIcons.lock,
                                              size: 12,
                                              color: theme.resources
                                                  .textFillColorSecondary,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  deleteButton,
                                ],
                              ),
                            if (layer.clippingMask)
                              Positioned(
                                left: -10,
                                top: 6,
                                bottom: 6,
                                child: _ClippingMaskIndicator(
                                  color: theme.accentColor
                                      .defaultBrushFor(theme.brightness),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
        _buildPanelDivider(theme),
        const SizedBox(height: 6),
        if (layerControls != null) ...[
          layerControls,
          const SizedBox(height: 6),
          _buildPanelDivider(theme),
          const SizedBox(height: 6),
        ],
        Expanded(
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
                  final double contentOpacity = layer.visible ? 1.0 : 0.45;
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

                  return material.ReorderableDragStartListener(
                    key: ValueKey(layer.id),
                    index: index,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: layer.clippingMask ? 18 : 0,
                        bottom: index == orderedLayers.length - 1 ? 0 : 8,
                      ),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _handleLayerSelected(layer.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: tileBorder),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Row(
                                children: [
                                  visibilityButton,
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Opacity(
                                      opacity: contentOpacity,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              layer.name,
                                              style: isActive
                                                  ? theme.typography.bodyStrong
                                                  : theme.typography.body,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (layer.locked) ...[
                                            const SizedBox(width: 6),
                                            Icon(
                                              FluentIcons.lock,
                                              size: 12,
                                              color: theme.resources
                                                  .textFillColorSecondary,
                                            ),
                                          ],
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
                                    color: theme.accentColor
                                        .defaultBrushFor(theme.brightness),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
