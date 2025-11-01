import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../../canvas/canvas_viewport.dart';
import '../../canvas/canvas_settings.dart';
import '../../canvas/canvas_tools.dart';
import '../../canvas/stroke_painter.dart';
import '../../canvas/stroke_store.dart';
import 'canvas_toolbar.dart';

class PaintingBoard extends StatefulWidget {
  const PaintingBoard({
    super.key,
    required this.settings,
    required this.onRequestExit,
    this.onDirtyChanged,
  });

  final CanvasSettings settings;
  final VoidCallback onRequestExit;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  State<PaintingBoard> createState() => PaintingBoardState();
}

class PaintingBoardState extends State<PaintingBoard> {
  static const double _toolButtonPadding = 16;
  static const double _toolbarButtonSize = 32;
  static const double _toolbarSpacing = 6;
  static const Color _workspaceColor = Color(0xFFE5E5E5);

  final StrokeStore _store = StrokeStore();
  final FocusNode _focusNode = FocusNode();

  CanvasTool _activeTool = CanvasTool.pen;
  bool _isDrawing = false;
  bool _isDraggingBoard = false;
  bool _isDirty = false;
  bool _isScalingGesture = false;
  double _scaleGestureInitialScale = 1.0;

  final CanvasViewport _viewport = CanvasViewport();
  Size _workspaceSize = Size.zero;
  Offset _layoutBaseOffset = Offset.zero;

  Size get _canvasSize => widget.settings.size;

  Size get _scaledBoardSize => Size(
    _canvasSize.width * _viewport.scale,
    _canvasSize.height * _viewport.scale,
  );

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  CanvasTool get activeTool => _activeTool;
  bool get hasContent => _store.strokes.isNotEmpty;
  bool get isDirty => _isDirty;

  List<List<Offset>> snapshotStrokes() => _store.snapshot();

  void clear() {
    _store.clear();
    _emitClean();
    setState(() {});
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
    _toolbarButtonSize * 4 + _toolbarSpacing * 3,
  );

  bool _isInsideToolArea(Offset workspacePosition) {
    return _toolbarRect.contains(workspacePosition);
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

  void _startStroke(Offset position) {
    setState(() {
      _isDrawing = true;
      _store.startStroke(position);
    });
    _markDirty();
  }

  void _appendPoint(Offset position) {
    if (!_isDrawing) {
      return;
    }
    setState(() => _store.appendPoint(position));
  }

  void _finishStroke() {
    if (!_isDrawing) {
      return;
    }
    _store.finishStroke();
    setState(() => _isDrawing = false);
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
    final bool undone = _store.undo();
    if (!undone) {
      return;
    }
    if (_isDrawing) {
      _isDrawing = false;
    }
    setState(() {});
    if (_store.strokes.isEmpty) {
      _emitClean();
    } else {
      _markDirty();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strokes = _store.strokes;
    final bool canUndo = strokes.isNotEmpty;

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
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
                const UndoIntent(),
            LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyZ):
                const UndoIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              UndoIntent: CallbackAction<UndoIntent>(
                onInvoke: (intent) {
                  _handleUndo();
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
                    color: _workspaceColor,
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
                                  color: const Color(0x33000000),
                                  width: 1,
                                ),
                              ),
                              child: ClipRect(
                                child: CustomPaint(
                                  painter: StrokePainter(
                                    strokes: strokes,
                                    backgroundColor:
                                        widget.settings.backgroundColor,
                                    scale: _viewport.scale,
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
                            canUndo: canUndo,
                            onExit: widget.onRequestExit,
                          ),
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
