import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';

import '../../canvas/stroke_painter.dart';
import 'pen_tool_button.dart';

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
  static const double _penButtonSize = 64;
  static const double _penButtonPadding = 16;

  final List<List<Offset>> _strokes = <List<Offset>>[];
  bool _isDrawing = false;

  bool _canDraw(PointerEvent event) {
    if (!widget.isPenActive) {
      return false;
    }
    final bool isPrimaryMouseClick =
        event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kPrimaryMouseButton) != 0;
    return isPrimaryMouseClick;
  }

  bool _isInsidePenButtonArea(Offset position) {
    final bool withinHorizontal =
        position.dx >= _penButtonPadding &&
        position.dx <= _penButtonPadding + _penButtonSize;
    final bool withinVertical =
        position.dy >= _penButtonPadding &&
        position.dy <= _penButtonPadding + _penButtonSize;
    return withinHorizontal && withinVertical;
  }

  void _startStroke(PointerDownEvent event) {
    if (!_canDraw(event) || _isInsidePenButtonArea(event.localPosition)) {
      return;
    }
    setState(() {
      _isDrawing = true;
      _strokes.add(<Offset>[event.localPosition]);
    });
  }

  void _appendPoint(PointerMoveEvent event) {
    if (!_isDrawing || !_canDraw(event)) {
      return;
    }
    setState(() {
      _strokes.last.add(event.localPosition);
    });
  }

  void _finishStroke() {
    if (!_isDrawing) {
      return;
    }
    setState(() {
      _isDrawing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: StrokePainter(strokes: _strokes)),
                    Positioned(
                      top: _penButtonPadding,
                      left: _penButtonPadding,
                      child: PenToolButton(
                        isSelected: widget.isPenActive,
                        onChanged: widget.onPenChanged,
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
  }
}
