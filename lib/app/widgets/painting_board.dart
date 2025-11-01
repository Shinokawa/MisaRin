import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

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

  final StrokeStore _store = StrokeStore();
  final FocusNode _focusNode = FocusNode();
  CanvasTool _activeTool = CanvasTool.pen;
  bool _isDrawing = false;
  bool _isDragging = false;
  bool _isDirty = false;
  Offset _lastPointerPosition = Offset.zero;
  Offset _viewportOffset = Offset.zero;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  CanvasTool get activeTool => _activeTool;
  bool get hasContent => _store.strokes.isNotEmpty;
  bool get isDirty => _isDirty;
  Offset get viewportOffset => _viewportOffset;

  List<List<Offset>> snapshotStrokes() => _store.snapshot();

  void clear() {
    _store.clear();
    _viewportOffset = Offset.zero;
    _emitClean();
    setState(() {});
  }

  void _setActiveTool(CanvasTool tool) {
    if (_activeTool == tool) {
      return;
    }
    setState(() => _activeTool = tool);
  }

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

  bool _isPrimaryPointer(PointerEvent event) {
    return event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kPrimaryMouseButton) != 0;
  }

  bool _isInsideToolArea(Offset position) {
    const double buttonSize = 64;
    const double toolSpacing = 12;
    final bool withinHorizontal =
        position.dx >= _toolButtonPadding &&
        position.dx <= _toolButtonPadding + buttonSize;
    final double toolHeight = buttonSize * 4 + toolSpacing * 3;
    final bool withinVertical =
        position.dy >= _toolButtonPadding &&
        position.dy <= _toolButtonPadding + toolHeight;
    return withinHorizontal && withinVertical;
  }

  Offset _toScene(Offset local) => local - _viewportOffset;

  void _beginDrawing(PointerDownEvent event) {
    if (!_isPrimaryPointer(event) || _isInsideToolArea(event.localPosition)) {
      return;
    }
    _focusNode.requestFocus();
    final Offset scenePosition = _toScene(event.localPosition);
    setState(() {
      _isDrawing = true;
      _store.startStroke(scenePosition);
    });
    _markDirty();
  }

  void _continueDrawing(PointerMoveEvent event) {
    if (!_isDrawing || !_isPrimaryPointer(event)) {
      return;
    }
    final Offset scenePosition = _toScene(event.localPosition);
    setState(() => _store.appendPoint(scenePosition));
  }

  void _finishDrawing() {
    if (!_isDrawing) {
      return;
    }
    _store.finishStroke();
    setState(() => _isDrawing = false);
  }

  void _beginDrag(PointerDownEvent event) {
    if (!_isPrimaryPointer(event) || _isInsideToolArea(event.localPosition)) {
      return;
    }
    _focusNode.requestFocus();
    setState(() {
      _isDragging = true;
      _lastPointerPosition = event.localPosition;
    });
  }

  void _updateDrag(PointerMoveEvent event) {
    if (!_isDragging || !_isPrimaryPointer(event)) {
      return;
    }
    setState(() {
      final Offset delta = event.localPosition - _lastPointerPosition;
      _viewportOffset += delta;
      _lastPointerPosition = event.localPosition;
    });
  }

  void _finishDrag() {
    if (!_isDragging) {
      return;
    }
    setState(() => _isDragging = false);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activeTool == CanvasTool.pen) {
      _beginDrawing(event);
    } else {
      _beginDrag(event);
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_activeTool == CanvasTool.pen) {
      _continueDrawing(event);
    } else {
      _updateDrag(event);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activeTool == CanvasTool.pen) {
      _finishDrawing();
    } else {
      _finishDrag();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activeTool == CanvasTool.pen) {
      _finishDrawing();
    } else {
      _finishDrag();
    }
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

    return Card(
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: widget.settings.width,
        height: widget.settings.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _handlePointerDown,
            onPointerMove: _handlePointerMove,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerCancel,
            child: Shortcuts(
              shortcuts: <LogicalKeySet, Intent>{
                LogicalKeySet(
                  LogicalKeyboardKey.control,
                  LogicalKeyboardKey.keyZ,
                ): const UndoIntent(),
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: StrokePainter(
                          strokes: strokes,
                          backgroundColor: widget.settings.backgroundColor,
                          viewportOffset: _viewportOffset,
                        ),
                      ),
                      Positioned(
                        top: _toolButtonPadding,
                        left: _toolButtonPadding,
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
      ),
    );
  }
}

class UndoIntent extends Intent {
  const UndoIntent();
}
