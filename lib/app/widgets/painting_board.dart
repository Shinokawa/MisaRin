import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';

import '../../canvas/canvas_layer.dart';
import '../../canvas/canvas_viewport.dart';
import '../../canvas/canvas_settings.dart';
import '../../canvas/canvas_tools.dart';
import '../../canvas/stroke_painter.dart';
import '../../canvas/stroke_store.dart';
import 'canvas_toolbar.dart';
import '../shortcuts/toolbar_shortcuts.dart';
import 'layer_visibility_button.dart';

class PaintingBoard extends StatefulWidget {
  const PaintingBoard({
    super.key,
    required this.settings,
    required this.onRequestExit,
    this.onDirtyChanged,
    this.initialLayers,
  });

  final CanvasSettings settings;
  final VoidCallback onRequestExit;
  final ValueChanged<bool>? onDirtyChanged;
  final List<CanvasLayerData>? initialLayers;

  @override
  State<PaintingBoard> createState() => PaintingBoardState();
}

class PaintingBoardState extends State<PaintingBoard> {
  static const double _toolButtonPadding = 16;
  static const double _toolbarButtonSize = 48;
  static const double _toolbarSpacing = 9;
  static const double _zoomStep = 1.1;
  static const double _strokeWidth = 3;
  static const double _sidePanelWidth = 240;
  static const double _colorPanelHeight = 168;
  static const double _layersPanelHeight = 288;
  static const double _sidePanelSpacing = 12;
  static const double _colorIndicatorSize = 56;
  static const double _colorIndicatorBorder = 3;

  final StrokeStore _store = StrokeStore();
  final FocusNode _focusNode = FocusNode();
  late final StrokePictureCache _strokeCache;

  CanvasTool _activeTool = CanvasTool.pen;
  bool _isDrawing = false;
  bool _isDraggingBoard = false;
  bool _isDirty = false;
  bool _isScalingGesture = false;
  double _scaleGestureInitialScale = 1.0;
  int _currentStrokeVersion = 0;

  final CanvasViewport _viewport = CanvasViewport();
  Size _workspaceSize = Size.zero;
  Offset _layoutBaseOffset = Offset.zero;
  final ScrollController _layerScrollController = ScrollController();
  Color _primaryColor = const Color(0xFF000000);
  late HSVColor _primaryHsv;
  static const int _recentColorCapacity = 5;
  final List<Color> _recentColors = <Color>[];

  Size get _canvasSize => widget.settings.size;

  Size get _scaledBoardSize => Size(
    _canvasSize.width * _viewport.scale,
    _canvasSize.height * _viewport.scale,
  );

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

  List<CanvasLayerData> get _layers => _store.layers;

  String? get _activeLayerId => _store.activeLayerId;

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

  Future<void> _pickColor({
    required String title,
    required Color initialColor,
    required ValueChanged<Color> onSelected,
    VoidCallback? onCleared,
  }) async {
    Color previewColor = initialColor;
    final Color? result = await showDialog<Color>(
      context: context,
      builder: (context) {
        return ContentDialog(
          title: Text(title),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 320,
                child: ColorPicker(
                  color: previewColor,
                  onChanged: (Color color) {
                    setState(() => previewColor = color);
                  },
                  isMoreButtonVisible: false,
                  isColorChannelTextInputVisible: false,
                  isHexInputVisible: true,
                  isAlphaTextInputVisible: false,
                ),
              );
            },
          ),
          actions: [
            if (onCleared != null)
              Button(
                onPressed: () {
                  Navigator.of(context).pop();
                  onCleared();
                },
                child: const Text('清除填充'),
              ),
            Button(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(previewColor),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    if (result != null) {
      onSelected(result);
    }
  }

  void _applyPaintBucket(Offset position) {
    final CanvasLayerData? active = _store.activeLayer;
    bool applied = false;
    if (active != null) {
      applied = _store.setLayerFillColor(active.id, _primaryColor);
    }
    if (!applied) {
      for (final CanvasLayerData layer in _layers.reversed) {
        if (!layer.visible) {
          continue;
        }
        applied = _store.setLayerFillColor(layer.id, _primaryColor);
        if (applied) {
          break;
        }
      }
    }
    if (!applied) {
      _store.addLayer(
        name: '填充',
        fillColor: _primaryColor,
        aboveLayerId: active?.id,
      );
      applied = true;
    }

    if (!applied) {
      return;
    }
    _syncStrokeCache();
    setState(() {
      _bumpCurrentStrokeVersion();
    });
    _markDirty();
  }

  void _updatePrimaryFromSquare(Offset position, double size) {
    final double x = position.dx.clamp(0.0, size);
    final double y = position.dy.clamp(0.0, size);
    final double saturation = (x / size).clamp(0.0, 1.0);
    final double value = (1 - y / size).clamp(0.0, 1.0);
    final HSVColor updated = _primaryHsv
        .withSaturation(saturation)
        .withValue(value);
    _applyPrimaryHsv(updated);
  }

  void _updatePrimaryHue(double dy, double height) {
    final double y = dy.clamp(0.0, height);
    final double hue = (y / height).clamp(0.0, 1.0) * 360.0;
    final HSVColor updated = _primaryHsv.withHue(hue);
    _applyPrimaryHsv(updated);
  }

  void _applyPrimaryHsv(HSVColor hsv, {bool remember = false}) {
    setState(() {
      _primaryHsv = hsv;
      _primaryColor = hsv.toColor();
      if (remember) {
        _rememberColor(_primaryColor);
      }
    });
  }

  void _setPrimaryColor(Color color, {bool remember = true}) {
    setState(() {
      _primaryColor = color;
      _primaryHsv = HSVColor.fromColor(color);
      if (remember) {
        _rememberColor(color);
      }
    });
  }

  void _rememberCurrentPrimary() {
    if (_recentColors.isNotEmpty &&
        _recentColors.first.value == _primaryColor.value) {
      return;
    }
    setState(() {
      _rememberColor(_primaryColor);
    });
  }

  void _rememberColor(Color color) {
    _recentColors.removeWhere((c) => c.value == color.value);
    _recentColors.insert(0, color);
    if (_recentColors.length > _recentColorCapacity) {
      _recentColors.removeRange(
        _recentColorCapacity,
        _recentColors.length,
      );
    }
  }

  void _selectRecentColor(Color color) {
    _setPrimaryColor(color);
  }

  String _formatColorHex(Color color) {
    final int a = (color.a * 255.0).round().clamp(0, 255);
    final int r = (color.r * 255.0).round().clamp(0, 255);
    final int g = (color.g * 255.0).round().clamp(0, 255);
    final int b = (color.b * 255.0).round().clamp(0, 255);
    final String alpha = a.toRadixString(16).padLeft(2, '0').toUpperCase();
    final String red = r.toRadixString(16).padLeft(2, '0').toUpperCase();
    final String green = g.toRadixString(16).padLeft(2, '0').toUpperCase();
    final String blue = b.toRadixString(16).padLeft(2, '0').toUpperCase();
    if (a == 0xFF) {
      return '#$red$green$blue';
    }
    return '#$alpha$red$green$blue';
  }

  Widget _buildRightPanel(FluentThemeData theme) {
    return SizedBox(
      width: _sidePanelWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PanelCard(
            width: _sidePanelWidth,
            title: '取色',
            child: _buildColorPanelContent(theme),
          ),
          const SizedBox(height: _sidePanelSpacing),
          _PanelCard(
            width: _sidePanelWidth,
            title: '图层管理',
            child: _buildLayerPanelContent(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPanelContent(FluentThemeData theme) {
    final Color borderColor = theme.resources.controlStrokeColorDefault;
    final Color previewBorder =
        Color.lerp(borderColor, Colors.transparent, 0.35)!;
    final Color textColor = theme.typography.caption?.color ??
        (theme.brightness.isDark ? Colors.white : const Color(0xFF323130));
    final Color backgroundColor = _backgroundPreviewColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        double sliderWidth = 24;
        const double spacing = 12;
        double squareSize = constraints.maxWidth - sliderWidth - spacing;
        if (squareSize <= 0) {
          squareSize = constraints.maxWidth;
          sliderWidth = 0;
        }

        final HSVColor hsv = _primaryHsv;

        Widget buildColorSquare(double size) {
          return GestureDetector(
            onPanDown: (details) =>
                _updatePrimaryFromSquare(details.localPosition, size),
            onPanUpdate: (details) =>
                _updatePrimaryFromSquare(details.localPosition, size),
            onPanEnd: (_) => _rememberCurrentPrimary(),
            onPanCancel: _rememberCurrentPrimary,
            onTapUp: (_) => _rememberCurrentPrimary(),
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.white,
                                  HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x00FFFFFF),
                                  Color(0xFF000000),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: (hsv.saturation.clamp(0.0, 1.0)) * size - 8,
                    top: ((1 - hsv.value.clamp(0.0, 1.0)) * size) - 8,
                    child: _ColorPickerHandle(color: hsv.toColor()),
                  ),
                ],
              ),
            ),
          );
        }

        Widget buildHueSlider(double height) {
          const List<Color> hueColors = [
            Color(0xFFFF0000),
            Color(0xFFFF00FF),
            Color(0xFF0000FF),
            Color(0xFF00FFFF),
            Color(0xFF00FF00),
            Color(0xFFFFFF00),
            Color(0xFFFF0000),
          ];
          final double handleY =
              (hsv.hue.clamp(0.0, 360.0) / 360.0) * height;
          return GestureDetector(
            onPanDown: (details) =>
                _updatePrimaryHue(details.localPosition.dy, height),
            onPanUpdate: (details) =>
                _updatePrimaryHue(details.localPosition.dy, height),
            onPanEnd: (_) => _rememberCurrentPrimary(),
            onPanCancel: _rememberCurrentPrimary,
            onTapUp: (_) => _rememberCurrentPrimary(),
            child: SizedBox(
              width: sliderWidth,
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: hueColors,
                        ),
                      ),
                      child: SizedBox.expand(),
                    ),
                  ),
                  Positioned(
                    top: handleY.clamp(0.0, height) - 8,
                    left: -4,
                    child: const _HueSliderHandle(),
                  ),
                ],
              ),
            ),
          );
        }

        Widget buildRecentColorsSection() {
          if (_recentColors.isEmpty) {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '最近颜色',
                style: theme.typography.caption?.copyWith(color: textColor),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recentColors
                    .map(
                      (color) => _RecentColorSwatch(
                        color: color,
                        selected: color.value == _primaryColor.value,
                        borderColor: previewBorder,
                        onTap: () => _selectRecentColor(color),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          );
        }

        final Widget recentSection = buildRecentColorsSection();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前颜色 ${_formatColorHex(_primaryColor)}',
              style: theme.typography.caption?.copyWith(color: textColor),
            ),
            const SizedBox(height: 4),
            Text(
              '画布底色 ${_formatColorHex(backgroundColor)}',
              style: theme.typography.caption?.copyWith(color: textColor),
            ),
            if (_recentColors.isNotEmpty) ...[
              const SizedBox(height: 12),
              recentSection,
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: squareSize,
                  height: squareSize,
                  child: buildColorSquare(squareSize),
                ),
                if (sliderWidth > 0) ...[
                  const SizedBox(width: spacing),
                  SizedBox(
                    width: sliderWidth,
                    height: squareSize,
                    child: buildHueSlider(squareSize),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildLayerPanelContent(FluentThemeData theme) {
    final List<CanvasLayerData> orderedLayers =
        _layers.reversed.toList(growable: false);
    final String? activeLayerId = _activeLayerId;
    final double listHeight =
        (_layersPanelHeight - 64).clamp(120.0, 320.0).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: listHeight,
          child: Scrollbar(
            controller: _layerScrollController,
            child: ListView.separated(
              controller: _layerScrollController,
              primary: false,
              padding: EdgeInsets.zero,
              itemCount: orderedLayers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final CanvasLayerData layer = orderedLayers[index];
                final bool isActive = layer.id == activeLayerId;
                final double contentOpacity = layer.visible ? 1.0 : 0.45;
                final Color background = isActive
                    ? theme.resources.subtleFillColorSecondary
                    : theme.resources.subtleFillColorTransparent;
                final Color borderColor =
                    theme.resources.controlStrokeColorSecondary;
                final Color tileBorder =
                    Color.lerp(borderColor, Colors.transparent, 0.6)!;

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

                return GestureDetector(
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
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _handleAddLayer,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(FluentIcons.add),
              SizedBox(width: 8),
              Text('新增图层'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorIndicator(FluentThemeData theme) {
    final Color borderColor = theme.resources.controlStrokeColorDefault;
    return Tooltip(
      message: '当前颜色 ${_formatColorHex(_primaryColor)}',
      child: Container(
        width: _colorIndicatorSize,
        height: _colorIndicatorSize,
        decoration: BoxDecoration(
          color: _primaryColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: _colorIndicatorBorder),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _primaryHsv = HSVColor.fromColor(_primaryColor);
    _rememberColor(widget.settings.backgroundColor);
    _rememberColor(_primaryColor);
    final List<CanvasLayerData> layers = _buildInitialLayers();
    _strokeCache = StrokePictureCache(
      logicalSize: _canvasSize,
    );
    _store.initialize(layers);
    _syncStrokeCache();
  }

  @override
  void dispose() {
    _strokeCache.dispose();
    _layerScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PaintingBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool sizeChanged = widget.settings.size != oldWidget.settings.size;
    final bool backgroundChanged =
        widget.settings.backgroundColor != oldWidget.settings.backgroundColor;
    if (sizeChanged || backgroundChanged) {
      if (backgroundChanged && _layers.isNotEmpty) {
        final CanvasLayerData baseLayer = _layers.first;
        if (baseLayer.fillColor == oldWidget.settings.backgroundColor) {
          _store.setLayerFillColor(
            baseLayer.id,
            widget.settings.backgroundColor,
          );
        }
      }
      _syncStrokeCache();
      setState(() {
        if (sizeChanged) {
          _viewport.reset();
          _workspaceSize = Size.zero;
          _layoutBaseOffset = Offset.zero;
        }
        _bumpCurrentStrokeVersion();
      });
    }
  }

  CanvasTool get activeTool => _activeTool;
  bool get hasContent => _store.hasStrokes;
  bool get isDirty => _isDirty;
  bool get canUndo => _store.canUndo;
  bool get canRedo => _store.canRedo;

  List<CanvasLayerData> snapshotLayers() => _store.snapshotLayers();

  void clear() {
    _store.clear();
    _emitClean();
    _syncStrokeCache();
    setState(() {
      _bumpCurrentStrokeVersion();
    });
  }

  void markSaved() {
    if (!_isDirty) {
      return;
    }
    _isDirty = false;
    widget.onDirtyChanged?.call(false);
  }

  Rect get _boardRect {
    final Offset position = _layoutBaseOffset + _viewport.offset;
    final Size size = _scaledBoardSize;
    return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
  }

  Offset _toBoardLocal(Offset workspacePosition) {
    final Rect boardRect = _boardRect;
    return (workspacePosition - boardRect.topLeft) / _viewport.scale;
  }

  bool _isPrimaryPointer(PointerEvent event) {
    return event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kPrimaryMouseButton) != 0;
  }

  Rect get _toolbarRect => Rect.fromLTWH(
    _toolButtonPadding,
    _toolButtonPadding,
    _toolbarButtonSize,
    _toolbarButtonSize * 6 + _toolbarSpacing * 5,
  );

  Rect get _colorIndicatorRect {
    final double top = (_workspaceSize.height - _toolButtonPadding - _colorIndicatorSize)
        .clamp(0.0, double.infinity);
    return Rect.fromLTWH(
      _toolButtonPadding,
      top,
      _colorIndicatorSize,
      _colorIndicatorSize,
    );
  }

  Rect get _rightPanelRect {
    final double left =
        (_workspaceSize.width - _sidePanelWidth - _toolButtonPadding)
            .clamp(0.0, double.infinity)
            .toDouble();
    final double totalHeight = (_colorPanelHeight + _sidePanelSpacing +
            _layersPanelHeight)
        .clamp(0.0, _workspaceSize.height)
        .toDouble();
    return Rect.fromLTWH(
      left,
      _toolButtonPadding,
      _sidePanelWidth,
      totalHeight,
    );
  }

  bool _isInsideToolArea(Offset workspacePosition) {
    return _toolbarRect.contains(workspacePosition) ||
        _rightPanelRect.contains(workspacePosition) ||
        _colorIndicatorRect.contains(workspacePosition);
  }

  void _setActiveTool(CanvasTool tool) {
    if (_activeTool == tool) {
      return;
    }
    setState(() => _activeTool = tool);
  }

  void _markDirty() {
    if (_isDirty) {
      return;
    }
    _isDirty = true;
    widget.onDirtyChanged?.call(true);
  }

  void _emitClean() {
    if (!_isDirty) {
      return;
    }
    _isDirty = false;
    widget.onDirtyChanged?.call(false);
  }

  void _bumpCurrentStrokeVersion() {
    _currentStrokeVersion++;
  }

  void _syncStrokeCache() {
    _strokeCache.updateLogicalSize(_canvasSize);
    _strokeCache.sync(
      layers: _store.committedLayers(),
    );
  }

  void _startStroke(Offset position) {
    setState(() {
      _isDrawing = true;
      _store.startStroke(
        position,
        color: _primaryColor,
        width: _strokeWidth,
      );
      _bumpCurrentStrokeVersion();
    });
    _markDirty();
  }

  void _appendPoint(Offset position) {
    if (!_isDrawing) {
      return;
    }
    setState(() {
      _store.appendPoint(position);
      _bumpCurrentStrokeVersion();
    });
  }

  void _finishStroke() {
    if (!_isDrawing) {
      return;
    }
    _store.finishStroke();
    _syncStrokeCache();
    setState(() {
      _isDrawing = false;
      _bumpCurrentStrokeVersion();
    });
  }

  void _beginDragBoard() {
    setState(() => _isDraggingBoard = true);
  }

  void _updateDragBoard(Offset delta) {
    if (!_isDraggingBoard) {
      return;
    }
    setState(() {
      _viewport.translate(delta);
    });
  }

  void _finishDragBoard() {
    if (!_isDraggingBoard) {
      return;
    }
    setState(() => _isDraggingBoard = false);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_isPrimaryPointer(event)) {
      return;
    }
    if (_isScalingGesture) {
      return;
    }
    final Offset pointer = event.localPosition;
    if (_isInsideToolArea(pointer)) {
      return;
    }
    final Rect boardRect = _boardRect;
    if (!boardRect.contains(pointer)) {
      return;
    }
    final Offset boardLocal = _toBoardLocal(pointer);
    if (_activeTool == CanvasTool.pen) {
      _focusNode.requestFocus();
      _startStroke(boardLocal);
    } else if (_activeTool == CanvasTool.bucket) {
      _focusNode.requestFocus();
      _applyPaintBucket(boardLocal);
    } else {
      _beginDragBoard();
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_isPrimaryPointer(event)) {
      return;
    }
    if (_isScalingGesture) {
      return;
    }
    if (_isDrawing && _activeTool == CanvasTool.pen) {
      final Offset boardLocal = _toBoardLocal(event.localPosition);
      _appendPoint(boardLocal);
    } else if (_isDraggingBoard && _activeTool == CanvasTool.hand) {
      _updateDragBoard(event.delta);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_isDrawing && _activeTool == CanvasTool.pen) {
      _finishStroke();
    }
    if (_isDraggingBoard && _activeTool == CanvasTool.hand) {
      _finishDragBoard();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_isDrawing && _activeTool == CanvasTool.pen) {
      _finishStroke();
    }
    if (_isDraggingBoard && _activeTool == CanvasTool.hand) {
      _finishDragBoard();
    }
  }

  void _applyZoom(double targetScale, Offset workspaceFocalPoint) {
    if (_workspaceSize.isEmpty) {
      return;
    }
    final double currentScale = _viewport.scale;
    final double clamped = _viewport.clampScale(targetScale);
    if ((clamped - currentScale).abs() < 0.0005) {
      return;
    }
    final Size currentScaledSize = Size(
      _canvasSize.width * currentScale,
      _canvasSize.height * currentScale,
    );
    final Offset currentBase = Offset(
      (_workspaceSize.width - currentScaledSize.width) / 2,
      (_workspaceSize.height - currentScaledSize.height) / 2,
    );
    final Offset currentOrigin = currentBase + _viewport.offset;
    final Offset boardLocal =
        (workspaceFocalPoint - currentOrigin) / currentScale;

    final Size newScaledSize = Size(
      _canvasSize.width * clamped,
      _canvasSize.height * clamped,
    );
    final Offset newBase = Offset(
      (_workspaceSize.width - newScaledSize.width) / 2,
      (_workspaceSize.height - newScaledSize.height) / 2,
    );
    final Offset newOrigin = workspaceFocalPoint - boardLocal * clamped;
    final Offset newOffset = newOrigin - newBase;

    setState(() {
      _viewport.setScale(clamped);
      _viewport.setOffset(newOffset);
    });
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final double scrollDelta = event.scrollDelta.dy;
    if (scrollDelta == 0) {
      return;
    }
    final Offset focalPoint = box.globalToLocal(event.position);
    const double sensitivity = 0.0015;
    final double targetScale =
        _viewport.scale * (1 - scrollDelta * sensitivity);
    _applyZoom(targetScale, focalPoint);
  }

  void _handleScaleStart(ScaleStartDetails details) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final bool shouldScale =
        details.pointerCount == 0 || details.pointerCount > 1;
    _isScalingGesture = shouldScale;
    if (!shouldScale) {
      return;
    }
    _scaleGestureInitialScale = _viewport.scale;
    final Offset focalPoint = box.globalToLocal(details.focalPoint);
    _applyZoom(_viewport.scale, focalPoint);
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (!_isScalingGesture) {
      return;
    }
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final Offset focalPoint = box.globalToLocal(details.focalPoint);
    final double targetScale = _scaleGestureInitialScale * details.scale;
    _applyZoom(targetScale, focalPoint);
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _isScalingGesture = false;
  }

  void _handleUndo() {
    undo();
  }

  void _handleRedo() {
    redo();
  }

  bool undo() {
    final bool undone = _store.undo();
    if (!undone) {
      return false;
    }
    _syncStrokeCache();
    setState(() {
      _isDrawing = false;
      _bumpCurrentStrokeVersion();
    });
    if (!_store.hasStrokes) {
      _emitClean();
    } else {
      _markDirty();
    }
    return true;
  }

  bool redo() {
    final bool redone = _store.redo();
    if (!redone) {
      return false;
    }
    _syncStrokeCache();
    setState(() {
      _bumpCurrentStrokeVersion();
    });
    _markDirty();
    return true;
  }

  bool zoomIn() {
    return _zoomByFactor(_zoomStep);
  }

  bool zoomOut() {
    return _zoomByFactor(1 / _zoomStep);
  }

  bool _zoomByFactor(double factor) {
    if (_workspaceSize.isEmpty) {
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        return false;
      }
      _workspaceSize = box.size;
    }
    final Offset focalPoint = Offset(
      _workspaceSize.width / 2,
      _workspaceSize.height / 2,
    );
    _applyZoom(_viewport.scale * factor, focalPoint);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bool canUndo = _store.canUndo;
    final bool canRedo = _store.canRedo;
    final Map<LogicalKeySet, Intent> shortcutBindings = {
      for (final key in ToolbarShortcuts.of(ToolbarAction.undo).shortcuts)
        key: const UndoIntent(),
      for (final key in ToolbarShortcuts.of(ToolbarAction.redo).shortcuts)
        key: const RedoIntent(),
      for (final key in ToolbarShortcuts.of(ToolbarAction.penTool).shortcuts)
        key: const SelectToolIntent(CanvasTool.pen),
      for (final key in ToolbarShortcuts.of(ToolbarAction.bucketTool).shortcuts)
        key: const SelectToolIntent(CanvasTool.bucket),
      for (final key in ToolbarShortcuts.of(ToolbarAction.handTool).shortcuts)
        key: const SelectToolIntent(CanvasTool.hand),
      for (final key in ToolbarShortcuts.of(ToolbarAction.exit).shortcuts)
        key: const ExitBoardIntent(),
    };

    final theme = FluentTheme.of(context);
    final bool isDark = theme.brightness.isDark;
    final Color workspaceColor = isDark
        ? const Color(0xFF1B1B1F)
        : const Color(0xFFE5E5E5);

    return LayoutBuilder(
      builder: (context, constraints) {
        _workspaceSize = constraints.biggest;
        final Size scaledSize = _scaledBoardSize;
        _layoutBaseOffset = Offset(
          (_workspaceSize.width - scaledSize.width) / 2,
          (_workspaceSize.height - scaledSize.height) / 2,
        );
        final Rect boardRect = _boardRect;

        return Shortcuts(
          shortcuts: shortcutBindings,
          child: Actions(
            actions: <Type, Action<Intent>>{
              UndoIntent: CallbackAction<UndoIntent>(
                onInvoke: (intent) {
                  _handleUndo();
                  return null;
                },
              ),
              RedoIntent: CallbackAction<RedoIntent>(
                onInvoke: (intent) {
                  _handleRedo();
                  return null;
                },
              ),
              SelectToolIntent: CallbackAction<SelectToolIntent>(
                onInvoke: (intent) {
                  _setActiveTool(intent.tool);
                  return null;
                },
              ),
              ExitBoardIntent: CallbackAction<ExitBoardIntent>(
                onInvoke: (intent) {
                  widget.onRequestExit();
                  return null;
                },
              ),
            },
            child: Focus(
              focusNode: _focusNode,
              autofocus: true,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
                onScaleEnd: _handleScaleEnd,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _handlePointerDown,
                  onPointerMove: _handlePointerMove,
                  onPointerUp: _handlePointerUp,
                  onPointerCancel: _handlePointerCancel,
                  onPointerSignal: _handlePointerSignal,
                  child: Container(
                    color: workspaceColor,
                    child: Stack(
                      children: [
                        Positioned(
                          left: boardRect.left,
                          top: boardRect.top,
                          child: SizedBox(
                            width: _scaledBoardSize.width,
                            height: _scaledBoardSize.height,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isDark
                                      ? Color.lerp(
                                            Colors.white,
                                            Colors.transparent,
                                            0.88,
                                          )!
                                      : const Color(0x33000000),
                                  width: 1,
                                ),
                              ),
                              child: ClipRect(
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    painter: StrokePainter(
                                      cache: _strokeCache,
                                      cacheVersion: _strokeCache.version,
                                      currentStroke: _store.currentStroke,
                                      currentStrokeVersion:
                                          _currentStrokeVersion,
                                      scale: _viewport.scale,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: _toolButtonPadding,
                          top: _toolButtonPadding,
                          child: CanvasToolbar(
                            activeTool: _activeTool,
                            onToolSelected: _setActiveTool,
                            onUndo: _handleUndo,
                            onRedo: _handleRedo,
                            canUndo: canUndo,
                            canRedo: canRedo,
                            onExit: widget.onRequestExit,
                          ),
                        ),
                        Positioned(
                          left: _toolButtonPadding,
                          bottom: _toolButtonPadding,
                          child: _buildColorIndicator(theme),
                        ),
                        Positioned(
                          right: _toolButtonPadding,
                          top: _toolButtonPadding,
                          child: _buildRightPanel(theme),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class SelectToolIntent extends Intent {
  const SelectToolIntent(this.tool);

  final CanvasTool tool;
}

class ExitBoardIntent extends Intent {
  const ExitBoardIntent();
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.width,
    required this.title,
    required this.child,
  });

  final double width;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final BorderRadius borderRadius = BorderRadius.circular(20);
    final Color fallbackColor =
        theme.brightness.isDark ? const Color(0xFF1F1F1F) : Colors.white;
    Color backgroundColor = theme.cardColor;
    if (backgroundColor.alpha != 0xFF) {
      backgroundColor = fallbackColor;
    }
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.typography.subtitle,
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorPickerHandle extends StatelessWidget {
  const _ColorPickerHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.black.withOpacity(0.8),
          width: 2,
        ),
        color: color,
      ),
    );
  }
}

class _HueSliderHandle extends StatelessWidget {
  const _HueSliderHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.black.withOpacity(0.7),
          width: 2,
        ),
        color: Colors.white,
      ),
    );
  }
}

class _RecentColorSwatch extends StatelessWidget {
  const _RecentColorSwatch({
    required this.color,
    required this.selected,
    required this.borderColor,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final Color highlight = theme.accentColor.defaultBrushFor(theme.brightness);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: color,
          border: Border.all(
            color: selected ? highlight : borderColor,
            width: selected ? 2 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
