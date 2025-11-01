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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExitToolButton(onPressed: onExit),
        const SizedBox(height: 12),
        PenToolButton(
          isSelected: activeTool == CanvasTool.pen,
          onPressed: () => onToolSelected(CanvasTool.pen),
        ),
        const SizedBox(height: 12),
        HandToolButton(
          isSelected: activeTool == CanvasTool.hand,
          onPressed: () => onToolSelected(CanvasTool.hand),
        ),
        const SizedBox(height: 12),
        UndoToolButton(enabled: canUndo, onPressed: onUndo),
      ],
    );
  }
}
