part of 'painting_board.dart';

mixin _PaintingBoardLayerMixin on _PaintingBoardBase {
  List<CanvasLayerData> _buildInitialLayers() {
    final List<CanvasLayerData>? provided = widget.initialLayers;
    if (provided != null && provided.isNotEmpty) {
      return List<CanvasLayerData>.from(provided);
    }
    return <CanvasLayerData>[
      CanvasLayerData(
        id: generateLayerId(),
        name: '图层 1',
        fillColor: widget.settings.backgroundColor,
      ),
    ];
  }

  CanvasLayerData? _layerById(String id) {
    for (final CanvasLayerData layer in _layers) {
      if (layer.id == id) {
        return layer;
      }
    }
    return null;
  }

  Color get _backgroundPreviewColor {
    if (_layers.isEmpty) {
      return widget.settings.backgroundColor;
    }
    final CanvasLayerData baseLayer = _layers.first;
    return baseLayer.fillColor ?? widget.settings.backgroundColor;
  }

  void _handleLayerVisibilityChanged(String id, bool visible) {
    if (!_store.updateLayerVisibility(id, visible)) {
      return;
    }
    if (!visible && _store.activeLayerId == id) {
      for (final CanvasLayerData layer in _layers.reversed) {
        if (layer.visible) {
          _store.setActiveLayer(layer.id);
          break;
        }
      }
    }
    _syncStrokeCache();
    setState(() {
      _bumpCurrentStrokeVersion();
    });
    _markDirty();
  }

  void _handleLayerSelected(String id) {
    if (_store.setActiveLayer(id)) {
      setState(() {});
    }
  }

  void _handleAddLayer() {
    _store.addLayer();
    _syncStrokeCache();
    setState(() {
      _bumpCurrentStrokeVersion();
    });
    _markDirty();
  }

  Future<void> _handleEditLayerFill(String id) async {
    final CanvasLayerData? layer = _layerById(id);
    if (layer == null) {
      return;
    }
    await _pickColor(
      title: '调整图层填充',
      initialColor: layer.fillColor ?? _primaryColor,
      onSelected: (color) {
        if (_store.setLayerFillColor(id, color)) {
          _syncStrokeCache();
          setState(() {
            _bumpCurrentStrokeVersion();
          });
          _markDirty();
        }
      },
      onCleared: layer.fillColor == null
          ? null
          : () {
              if (_store.clearLayerFillColor(id)) {
                _syncStrokeCache();
                setState(() {
                  _bumpCurrentStrokeVersion();
                });
                _markDirty();
              }
            },
    );
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
    if (_store.reorderLayer(actualOldIndex, actualNewIndex)) {
      _syncStrokeCache();
      setState(() {
        _bumpCurrentStrokeVersion();
      });
      _markDirty();
    }
  }

  Widget _buildLayerPanelContent(FluentThemeData theme) {
    final List<CanvasLayerData> orderedLayers = _layers.reversed.toList(
      growable: false,
    );
    final String? activeLayerId = _activeLayerId;
    return Column(
      mainAxisSize: MainAxisSize.max,
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
                  final CanvasLayerData layer = orderedLayers[index];
                  final bool isActive = layer.id == activeLayerId;
                  final double contentOpacity = layer.visible ? 1.0 : 0.45;
                  final Color background = isActive
                      ? theme.resources.subtleFillColorSecondary
                      : theme.resources.subtleFillColorTransparent;
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

                  final Color? fillColor = layer.fillColor;
                  final Widget? fillSwatch = fillColor != null
                      ? Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: fillColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: theme.resources.controlStrokeColorDefault,
                            ),
                          ),
                        )
                      : null;

                  final Widget editFillButton = IconButton(
                    icon: const Icon(FluentIcons.color, size: 16),
                    onPressed: () => _handleEditLayerFill(layer.id),
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
                                      if (fillSwatch != null) ...[
                                        fillSwatch,
                                        const SizedBox(width: 8),
                                      ],
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
                              editFillButton,
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
