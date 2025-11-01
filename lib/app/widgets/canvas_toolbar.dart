import 'package:fluent_ui/fluent_ui.dart';

import '../../canvas/canvas_tools.dart';
import 'exit_tool_button.dart';
import 'hand_tool_button.dart';
import 'pen_tool_button.dart';
import 'undo_tool_button.dart';

class CanvasToolbar extends StatelessWidget {
  const CanvasToolbar({
    super.key,
    required this.activeTool,
    required this.onToolSelected,
    required this.onUndo,
    required this.canUndo,
    required this.onExit,
  });

  final CanvasTool activeTool;
  final ValueChanged<CanvasTool> onToolSelected;
  final VoidCallback onUndo;
  final bool canUndo;
  final VoidCallback onExit;

  static const TooltipThemeData _rightTooltipStyle =
      TooltipThemeData(preferBelow: false, verticalOffset: 24);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: '退出',
          displayHorizontally: true,
          style: _rightTooltipStyle,
          useMousePosition: false,
          child: ExitToolButton(onPressed: onExit),
        ),
        const SizedBox(height: 6),
        Tooltip(
          message: '画笔工具',
          displayHorizontally: true,
          style: _rightTooltipStyle,
          useMousePosition: false,
          child: PenToolButton(
            isSelected: activeTool == CanvasTool.pen,
            onPressed: () => onToolSelected(CanvasTool.pen),
          ),
        ),
        const SizedBox(height: 6),
        Tooltip(
          message: '拖拽画布',
          displayHorizontally: true,
          style: _rightTooltipStyle,
          useMousePosition: false,
          child: HandToolButton(
            isSelected: activeTool == CanvasTool.hand,
            onPressed: () => onToolSelected(CanvasTool.hand),
          ),
        ),
        const SizedBox(height: 6),
        Tooltip(
          message: '撤销',
          displayHorizontally: true,
          style: _rightTooltipStyle,
          useMousePosition: false,
          child: UndoToolButton(enabled: canUndo, onPressed: onUndo),
        ),
      ],
    );
  }
}
