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
      CanvasLayerData(
        id: generateLayerId(),
        name: '背景',
        fillColor: background,
      ),
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

  Widget _buildLayerPanelContent(FluentThemeData theme) {
    final List<BitmapLayerState> orderedLayers =
        _layers.toList(growable: false).reversed.toList(growable: false);
    final String? activeLayerId = _activeLayerId;
    final Color fallbackCardColor = theme.brightness.isDark
        ? const Color(0xFF1F1F1F)
        : Colors.white;
    Color tileBaseColor = theme.cardColor;
    if (tileBaseColor.alpha != 0xFF) {
      tileBaseColor = fallbackCardColor;
    }

    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                          child: Row(
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
                                    ],
                                  ),
                                ),
                              ),
                              deleteButton,
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
