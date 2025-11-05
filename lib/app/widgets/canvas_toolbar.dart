import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';

import '../../canvas/canvas_tools.dart';
import '../shortcuts/toolbar_shortcuts.dart';
import 'exit_tool_button.dart';
import 'hand_tool_button.dart';
import 'bucket_tool_button.dart';
import 'magic_wand_tool_button.dart';
import 'pen_tool_button.dart';
import 'selection_tool_button.dart';
import 'redo_tool_button.dart';
import 'undo_tool_button.dart';
import 'layer_adjust_tool_button.dart';
import 'curve_pen_tool_button.dart';
import 'eyedropper_tool_button.dart';

class CanvasToolbar extends StatelessWidget {
  const CanvasToolbar({
    super.key,
    required this.activeTool,
    required this.selectionShape,
    required this.onToolSelected,
    required this.onUndo,
    required this.onRedo,
    required this.canUndo,
    required this.canRedo,
    required this.onExit,
  });

  final CanvasTool activeTool;
  final SelectionShape selectionShape;
  final ValueChanged<CanvasTool> onToolSelected;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onExit;

  static const int buttonCount = 11;

  static const TooltipThemeData _rightTooltipStyle = TooltipThemeData(
    preferBelow: false,
    verticalOffset: 24,
    waitDuration: Duration.zero,
  );

  static String _tooltipMessage(String base, ToolbarAction action) {
    final shortcutLabel = ToolbarShortcuts.labelForPlatform(
      action,
      defaultTargetPlatform,
    );
    if (shortcutLabel.isEmpty) {
      return base;
    }
    return '$base ($shortcutLabel)';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: _tooltipMessage('退出', ToolbarAction.exit),
          displayHorizontally: true,
          style: _rightTooltipStyle,
          useMousePosition: false,
          child: ExitToolButton(onPressed: onExit),
        ),
        const SizedBox(height: 9),
        Tooltip(
          message: _tooltipMessage('图层调节', ToolbarAction.layerAdjustTool),
          displayHorizontally: true,
          style: _rightTooltipStyle,
          useMousePosition: false,
          child: LayerAdjustToolButton(
            isSelected: activeTool == CanvasTool.layerAdjust,
            onPressed: () => onToolSelected(CanvasTool.layerAdjust),
          ),
        ),
        const SizedBox(height: 9),
        Tooltip(
          message: _tooltipMessage('画笔工具', ToolbarAction.penTool),
          displayHorizontally: true,
          style: _rightTooltipStyle,
          useMousePosition: false,
          child: PenToolButton(
            isSelected: activeTool == CanvasTool.pen,
            onPressed: () => onToolSelected(CanvasTool.pen),
          ),
        ),
        const SizedBox(height: 9),
        Tooltip(
          message: _tooltipMessage('曲线画笔', ToolbarAction.curvePenTool),
          displayHorizontally: true,
          style: _rightTooltipStyle,
          useMousePosition: false,
          child: CurvePenToolButton(
            isSelected: activeTool == CanvasTool.curvePen,
            onPressed: () => onToolSelected(CanvasTool.curvePen),
          ),
        ),
        const SizedBox(height: 9),
        Tooltip(
          message: _tooltipMessage('油漆桶', ToolbarAction.bucketTool),
          displayHorizontally: true,
          style: _rightTooltipStyle,
          useMousePosition: false,
          child: BucketToolButton(
            isSelected: activeTool == CanvasTool.bucket,
            onPressed: () => onToolSelected(CanvasTool.bucket),
          ),
        ),
        const SizedBox(height: 9),
        Tooltip(
          message: _tooltipMessage('魔棒工具', ToolbarAction.magicWandTool),
          displayHorizontally: true,
          style: _rightTooltipStyle,
          useMousePosition: false,
          child: MagicWandToolButton(
            isSelected: activeTool == CanvasTool.magicWand,
            onPressed: () => onToolSelected(CanvasTool.magicWand),
          ),
        ),
        const SizedBox(height: 9),
        Tooltip(
          message: _tooltipMessage('吸管工具', ToolbarAction.eyedropperTool),
          displayHorizontally: true,
          style: _rightTooltipStyle,
          useMousePosition: false,
          child: EyedropperToolButton(
            isSelected: activeTool == CanvasTool.eyedropper,
            onPressed: () => onToolSelected(CanvasTool.eyedropper),
          ),
        ),
        const SizedBox(height: 9),
        Tooltip(
          message: _tooltipMessage('选区工具', ToolbarAction.selectionTool),
          displayHorizontally: true,
          style: _rightTooltipStyle,
          useMousePosition: false,
          child: SelectionToolButton(
            isSelected: activeTool == CanvasTool.selection,
            selectionShape: selectionShape,
            onPressed: () => onToolSelected(CanvasTool.selection),
          ),
        ),
        const SizedBox(height: 9),
        Tooltip(
          message: _tooltipMessage('拖拽画布', ToolbarAction.handTool),
          displayHorizontally: true,
          style: _rightTooltipStyle,
          useMousePosition: false,
          child: HandToolButton(
            isSelected: activeTool == CanvasTool.hand,
            onPressed: () => onToolSelected(CanvasTool.hand),
          ),
        ),
        const SizedBox(height: 9),
        Tooltip(
          message: _tooltipMessage('撤销', ToolbarAction.undo),
          displayHorizontally: true,
          style: _rightTooltipStyle,
          useMousePosition: false,
          child: UndoToolButton(enabled: canUndo, onPressed: onUndo),
        ),
        const SizedBox(height: 9),
        Tooltip(
          message: _tooltipMessage('恢复', ToolbarAction.redo),
          displayHorizontally: true,
          style: _rightTooltipStyle,
          useMousePosition: false,
          child: RedoToolButton(enabled: canRedo, onPressed: onRedo),
        ),
      ],
    );
  }
}
