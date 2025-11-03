import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart'
    as material
    show ReorderableDragStartListener, ReorderableListView;
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, TextInputFormatter, TextInputType,
        TextEditingValue, TextSelection;
import 'package:flutter/rendering.dart' show RenderBox;
import 'package:flutter/widgets.dart' show FocusNode, TextEditingController, WidgetsBinding;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalMaterialLocalizations;

import '../../bitmap_canvas/bitmap_canvas.dart';
import '../../bitmap_canvas/controller.dart';
import '../../canvas/canvas_layer.dart';
import '../../canvas/canvas_settings.dart';
import '../../canvas/canvas_tools.dart';
import '../../canvas/canvas_viewport.dart';
import 'canvas_toolbar.dart';
import '../shortcuts/toolbar_shortcuts.dart';
import '../preferences/app_preferences.dart';
import 'layer_visibility_button.dart';

part 'painting_board_layers.dart';
part 'painting_board_colors.dart';
part 'painting_board_interactions.dart';
part 'painting_board_build.dart';
part 'painting_board_widgets.dart';

const double _toolButtonPadding = 16;
const double _toolbarButtonSize = 48;
const double _toolbarSpacing = 9;
const double _toolSettingsSpacing = 12;
const double _toolSettingsCardWidth = 320;
const double _toolSettingsCardHeight = _toolbarButtonSize;
const double _zoomStep = 1.1;
const double _defaultPenStrokeWidth = 3;
const double _sidePanelWidth = 240;
const double _sidePanelSpacing = 12;
const double _colorIndicatorSize = 56;
const double _colorIndicatorBorder = 3;
const int _recentColorCapacity = 5;
const double _initialViewportScaleFactor = 0.8;

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

abstract class _PaintingBoardBase extends State<PaintingBoard> {
  late BitmapCanvasController _controller;
  final FocusNode _focusNode = FocusNode();

  CanvasTool _activeTool = CanvasTool.pen;
  bool _isDrawing = false;
  bool _isDraggingBoard = false;
  bool _isDirty = false;
  bool _isScalingGesture = false;
  double _scaleGestureInitialScale = 1.0;
  double _penStrokeWidth = _defaultPenStrokeWidth;
  bool _bucketSampleAllLayers = false;
  bool _bucketContiguous = true;

  final CanvasViewport _viewport = CanvasViewport();
  bool _viewportInitialized = false;
  Size _workspaceSize = Size.zero;
  Offset _layoutBaseOffset = Offset.zero;
  bool _workspaceMeasurementScheduled = false;
  final ScrollController _layerScrollController = ScrollController();
  Color _primaryColor = const Color(0xFF000000);
  late HSVColor _primaryHsv;
  final List<Color> _recentColors = <Color>[];

  Size get _canvasSize => widget.settings.size;

  Size get _scaledBoardSize => Size(
    _canvasSize.width * _viewport.scale,
    _canvasSize.height * _viewport.scale,
  );

  Offset _baseOffsetForScale(double scale) {
    final Size workspace = _workspaceSize;
    if (workspace.width <= 0 ||
        workspace.height <= 0 ||
        !workspace.width.isFinite ||
        !workspace.height.isFinite) {
      return Offset.zero;
    }

    final double scaledWidth = _canvasSize.width * scale;
    final double scaledHeight = _canvasSize.height * scale;

    final double rawLeft = (workspace.width - scaledWidth) / 2;
    final double rawTop = (workspace.height - scaledHeight) / 2;

    final double left = rawLeft.isFinite ? rawLeft : 0.0;
    final double top = rawTop.isFinite ? rawTop : 0.0;

    return Offset(left, top);
  }

  void _scheduleWorkspaceMeasurement(BuildContext context) {
    if (_workspaceMeasurementScheduled) {
      return;
    }
    _workspaceMeasurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _workspaceMeasurementScheduled = false;
      if (!mounted) {
        return;
      }
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        return;
      }
      final Size size = box.size;
      if (size.width <= 0 ||
          size.height <= 0 ||
          !size.width.isFinite ||
          !size.height.isFinite) {
        return;
      }
      final bool widthChanged = (size.width - _workspaceSize.width).abs() > 0.5;
      final bool heightChanged = (size.height - _workspaceSize.height).abs() > 0.5;
      if (!widthChanged && !heightChanged) {
        return;
      }
      setState(() {
        _workspaceSize = size;
        if (!_viewportInitialized) {
          // 仍需初始化视口，下一帧会根据新尺寸完成初始化
        }
      });
    });
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

  CanvasTool get activeTool => _activeTool;
  bool get hasContent => _controller.hasVisibleContent;
  bool get isDirty => _isDirty;
  bool get canUndo => false;
  bool get canRedo => false;

  UnmodifiableListView<BitmapLayerState> get _layers => _controller.layers;
  String? get _activeLayerId => _controller.activeLayerId;
  Color get _backgroundPreviewColor;

  List<CanvasLayerData> _buildInitialLayers();

  Future<void> _pickColor({
    required String title,
    required Color initialColor,
    required ValueChanged<Color> onSelected,
    VoidCallback? onCleared,
  });

  void _rememberColor(Color color);
  Future<void> _applyPaintBucket(Offset position);

  void _setActiveTool(CanvasTool tool);

  void _handlePointerDown(PointerDownEvent event);
  void _handlePointerMove(PointerMoveEvent event);
  void _handlePointerUp(PointerUpEvent event);
  void _handlePointerCancel(PointerCancelEvent event);
  void _handlePointerSignal(PointerSignalEvent event);

  void _handleScaleStart(ScaleStartDetails details);
  void _handleScaleUpdate(ScaleUpdateDetails details);
  void _handleScaleEnd(ScaleEndDetails details);

  void _handleUndo();
  void _handleRedo();

  void _updatePenStrokeWidth(double value);
  void _updateBucketSampleAllLayers(bool value);
  void _updateBucketContiguous(bool value);

  void _handleAddLayer();
  void _handleRemoveLayer(String id);

  Widget _buildLayerPanelContent(FluentThemeData theme);
  Widget _buildColorPanelContent(FluentThemeData theme);
  Widget _buildColorIndicator(FluentThemeData theme);

  List<CanvasLayerData> snapshotLayers() => _controller.snapshotLayers();

  void markSaved() {
    if (!_isDirty) {
      return;
    }
    _isDirty = false;
    widget.onDirtyChanged?.call(false);
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

  void _initializeViewportIfNeeded() {
    if (_viewportInitialized) {
      return;
    }

    final Size workspaceSize = _workspaceSize;
    if (workspaceSize.width <= 0 ||
        workspaceSize.height <= 0 ||
        !workspaceSize.width.isFinite ||
        !workspaceSize.height.isFinite) {
      return;
    }

    final Size canvasSize = _canvasSize;
    if (canvasSize.width <= 0 ||
        canvasSize.height <= 0 ||
        !canvasSize.width.isFinite ||
        !canvasSize.height.isFinite) {
      _viewportInitialized = true;
      return;
    }

    final double widthScale = workspaceSize.width / canvasSize.width;
    final double heightScale = workspaceSize.height / canvasSize.height;
    final double baseScale = widthScale < heightScale
        ? widthScale
        : heightScale;

    double targetScale = baseScale * _initialViewportScaleFactor;
    if (!targetScale.isFinite || targetScale <= 0) {
      targetScale = baseScale.isFinite && baseScale > 0 ? baseScale : 1.0;
    }

    if (targetScale > baseScale && baseScale.isFinite && baseScale > 0) {
      targetScale = baseScale;
    }

    _viewport.setScale(targetScale);
    _viewport.setOffset(Offset.zero);
    _viewportInitialized = true;
  }
}

class PaintingBoardState extends _PaintingBoardBase
    with
        _PaintingBoardLayerMixin,
        _PaintingBoardColorMixin,
        _PaintingBoardInteractionMixin,
        _PaintingBoardBuildMixin {
  @override
  void initState() {
    super.initState();
    final AppPreferences prefs = AppPreferences.instance;
    _bucketSampleAllLayers = prefs.bucketSampleAllLayers;
    _bucketContiguous = prefs.bucketContiguous;
    _primaryHsv = HSVColor.fromColor(_primaryColor);
    _rememberColor(widget.settings.backgroundColor);
    _rememberColor(_primaryColor);
    final List<CanvasLayerData> layers = _buildInitialLayers();
    _controller = BitmapCanvasController(
      width: widget.settings.width.round(),
      height: widget.settings.height.round(),
      backgroundColor: widget.settings.backgroundColor,
      initialLayers: layers,
    );
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    unawaited(_controller.disposeController());
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
      _controller.removeListener(_handleControllerChanged);
      unawaited(_controller.disposeController());
      _controller = BitmapCanvasController(
        width: widget.settings.width.round(),
        height: widget.settings.height.round(),
        backgroundColor: widget.settings.backgroundColor,
        initialLayers: _buildInitialLayers(),
      );
      _controller.addListener(_handleControllerChanged);
      setState(() {
        if (sizeChanged) {
          _viewport.reset();
          _workspaceSize = Size.zero;
          _layoutBaseOffset = Offset.zero;
          _viewportInitialized = false;
        }
      });
    }
  }

  void _handleControllerChanged() {
    setState(() {});
  }
}
