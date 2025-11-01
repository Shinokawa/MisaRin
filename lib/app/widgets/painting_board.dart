import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../../canvas/stroke_painter.dart';
import '../../canvas/stroke_store.dart';
import 'pen_tool_button.dart';
import 'undo_tool_button.dart';

class PaintingBoard extends StatefulWidget {
  const PaintingBoard({
    super.key,
    required this.isPenActive,
    required this.onPenChanged,
  });

  final bool isPenActive;
  final ValueChanged<bool> onPenChanged;

  @override
  State<PaintingBoard> createState() => _PaintingBoardState();
}

class _PaintingBoardState extends State<PaintingBoard> {
  static const double _toolButtonSize = 64;
  static const double _toolButtonPadding = 16;
  static const double _toolSpacing = 12;

  final StrokeStore _store = StrokeStore();
  final FocusNode _focusNode = FocusNode();
  bool _isDrawing = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool _canDraw(PointerEvent event) {
    if (!widget.isPenActive) {
      return false;
    }
    final bool isPrimaryMouseClick =
        event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kPrimaryMouseButton) != 0;
    return isPrimaryMouseClick;
  }

  bool _isInsideToolArea(Offset position) {
    final bool withinHorizontal =
        position.dx >= _toolButtonPadding &&
        position.dx <= _toolButtonPadding + _toolButtonSize;
    final double toolHeight = _toolButtonSize * 2 + _toolSpacing;
    final bool withinVertical =
        position.dy >= _toolButtonPadding &&
        position.dy <= _toolButtonPadding + toolHeight;
    return withinHorizontal && withinVertical;
  }

  void _startStroke(PointerDownEvent event) {
    if (!_canDraw(event) || _isInsideToolArea(event.localPosition)) {
      return;
    }
    _focusNode.requestFocus();
    setState(() {
      _isDrawing = true;
      _store.startStroke(event.localPosition);
    });
  }

  void _appendPoint(PointerMoveEvent event) {
    if (!_isDrawing || !_canDraw(event)) {
      return;
    }
    setState(() {
      _store.appendPoint(event.localPosition);
    });
  }

  void _finishStroke() {
    if (!_isDrawing) {
      return;
    }
    setState(() {
      _isDrawing = false;
      _store.finishStroke();
    });
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final strokes = _store.strokes;
    final bool canUndo = strokes.isNotEmpty;

    return Card(
      padding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 600),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: theme.resources.cardBackgroundFillColorDefault,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _startStroke,
                onPointerMove: _appendPoint,
                onPointerUp: (event) => _finishStroke(),
                onPointerCancel: (event) => _finishStroke(),
                child: Shortcuts(
                  shortcuts: <LogicalKeySet, Intent>{
                    LogicalKeySet(
                      LogicalKeyboardKey.control,
                      LogicalKeyboardKey.keyZ,
                    ): const UndoIntent(),
                    LogicalKeySet(
                      LogicalKeyboardKey.meta,
                      LogicalKeyboardKey.keyZ,
                    ): const UndoIntent(),
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
                          CustomPaint(painter: StrokePainter(strokes: strokes)),
                          Positioned(
                            top: _toolButtonPadding,
                            left: _toolButtonPadding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PenToolButton(
                                  isSelected: widget.isPenActive,
                                  onChanged: widget.onPenChanged,
                                ),
                                const SizedBox(height: _toolSpacing),
                                UndoToolButton(
                                  enabled: canUndo,
                                  onPressed: _handleUndo,
                                ),
                              ],
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
        ),
      ),
    );
  }
}

class UndoIntent extends Intent {
  const UndoIntent();
}
