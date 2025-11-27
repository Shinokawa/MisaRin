import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';

import '../../../canvas/canvas_tools.dart';
import '../../shortcuts/toolbar_shortcuts.dart';
import 'exit_tool_button.dart';
import 'hand_tool_button.dart';
import 'bucket_tool_button.dart';
import 'magic_wand_tool_button.dart';
import 'pen_tool_button.dart';
import 'eraser_tool_button.dart';
import 'selection_tool_button.dart';
import 'redo_tool_button.dart';
import 'undo_tool_button.dart';
import 'layer_adjust_tool_button.dart';
import 'curve_pen_tool_button.dart';
import 'eyedropper_tool_button.dart';
import 'shape_tool_button.dart';

class CanvasToolbar extends StatelessWidget {
  const CanvasToolbar({
    super.key,
    required this.activeTool,
    required this.selectionShape,
    required this.shapeToolVariant,
    required this.onToolSelected,
    required this.onUndo,
    required this.onRedo,
    required this.canUndo,
    required this.canRedo,
    required this.onExit,
    required this.layout,
    this.includeExitButton = true,
    this.includeHistoryButtons = true,
  });

  final CanvasTool activeTool;
  final SelectionShape selectionShape;
  final ShapeToolVariant shapeToolVariant;
  final ValueChanged<CanvasTool> onToolSelected;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onExit;
  final CanvasToolbarLayout layout;
  final bool includeExitButton;
  final bool includeHistoryButtons;

  static const int buttonCount = 13;
  static const int buttonCountWithoutExit = buttonCount - 1;
  static const int historyButtonCount = 2;
  static const double buttonSize = 48;
  static const double spacing = 9;

  static CanvasToolbarLayout layoutForAvailableHeight(double availableHeight) {
    final double effectiveHeight = availableHeight.isFinite
        ? math.max(0, availableHeight)
        : double.infinity;

    final double singleColumnHeight =
        buttonSize * buttonCount + spacing * (buttonCount - 1);
    if (effectiveHeight >= singleColumnHeight) {
      return CanvasToolbarLayout(
        columns: 1,
        rows: buttonCount,
        width: buttonSize,
        height: singleColumnHeight,
        buttonExtent: buttonSize,
      );
    }

    const int columns = 2;
    final int rows = (buttonCount / columns).ceil();
    final double height = rows * buttonSize + spacing * (rows - 1);
    final double width = columns * buttonSize + spacing * (columns - 1);

    return CanvasToolbarLayout(
      columns: columns,
      rows: rows,
      width: width,
      height: height,
      buttonExtent: buttonSize,
    );
  }

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

  static String _shapeTooltipLabel(ShapeToolVariant variant) {
    switch (variant) {
      case ShapeToolVariant.rectangle:
        return '矩形工具';
      case ShapeToolVariant.ellipse:
        return '椭圆工具';
      case ShapeToolVariant.triangle:
        return '三角形工具';
      case ShapeToolVariant.line:
        return '直线工具';
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = <Widget>[];
    if (includeExitButton) {
      items.add(
        Tooltip(
          message: _tooltipMessage('退出', ToolbarAction.exit),
          displayHorizontally: true,
          style: _rightTooltipStyle,
          useMousePosition: false,
          child: ExitToolButton(onPressed: onExit),
        ),
      );
    }
    items.addAll([
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
      Tooltip(
        message: _tooltipMessage(
          _shapeTooltipLabel(shapeToolVariant),
          ToolbarAction.shapeTool,
        ),
        displayHorizontally: true,
        style: _rightTooltipStyle,
        useMousePosition: false,
        child: ShapeToolButton(
          isSelected: activeTool == CanvasTool.shape,
          variant: shapeToolVariant,
          onPressed: () => onToolSelected(CanvasTool.shape),
        ),
      ),
      Tooltip(
        message: _tooltipMessage('橡皮擦', ToolbarAction.eraserTool),
        displayHorizontally: true,
        style: _rightTooltipStyle,
        useMousePosition: false,
        child: EraserToolButton(
          isSelected: activeTool == CanvasTool.eraser,
          onPressed: () => onToolSelected(CanvasTool.eraser),
        ),
      ),
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
    ]);

    if (includeHistoryButtons) {
      items.addAll([
        Tooltip(
          message: _tooltipMessage('撤销', ToolbarAction.undo),
          displayHorizontally: true,
          style: _rightTooltipStyle,
          useMousePosition: false,
          child: UndoToolButton(enabled: canUndo, onPressed: onUndo),
        ),
        Tooltip(
          message: _tooltipMessage('恢复', ToolbarAction.redo),
          displayHorizontally: true,
          style: _rightTooltipStyle,
          useMousePosition: false,
          child: RedoToolButton(enabled: canRedo, onPressed: onRedo),
        ),
      ]);
    }

    final double buttonExtent = layout.buttonExtent;

    List<Widget> sizedItems(List<Widget> children) {
      return [
        for (final Widget child in children)
          SizedBox(width: buttonExtent, height: buttonExtent, child: child),
      ];
    }

    List<Widget> withVerticalSpacing(List<Widget> children) {
      if (children.isEmpty) {
        return const [];
      }
      return [
        for (int index = 0; index < children.length; index++) ...[
          if (index > 0) const SizedBox(height: spacing),
          children[index],
        ],
      ];
    }

    if (layout.columns <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: withVerticalSpacing(sizedItems(items)),
      );
    }

    final columnWidgets = <Widget>[];
    int startIndex = 0;
    for (
      int column = 0;
      column < layout.columns && startIndex < items.length;
      column++
    ) {
      final int remaining = items.length - startIndex;
      final int targetCount = column == layout.columns - 1
          ? remaining
          : math.min(layout.rows, remaining);
      final columnChildren = sizedItems(
        items.sublist(startIndex, startIndex + targetCount),
      );
      startIndex += targetCount;
      columnWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: withVerticalSpacing(columnChildren),
        ),
      );
    }

    final Widget multiColumnLayout = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int index = 0; index < columnWidgets.length; index++) ...[
          if (index > 0) const SizedBox(width: spacing),
          columnWidgets[index],
        ],
      ],
    );

    if (!layout.horizontalFlow) {
      return multiColumnLayout;
    }

    final wrappedItems = sizedItems(items);
    return SizedBox(
      width: layout.width,
      height: layout.height,
      child: Align(
        alignment: Alignment.topLeft,
        child: Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: wrappedItems,
        ),
      ),
    );
  }
}

class CanvasToolbarLayout {
  const CanvasToolbarLayout({
    required this.columns,
    required this.rows,
    required this.width,
    required this.height,
    this.buttonExtent = CanvasToolbar.buttonSize,
    this.horizontalFlow = false,
  });

  final int columns;
  final int rows;
  final double width;
  final double height;
  final double buttonExtent;
  final bool horizontalFlow;

  bool get isMultiColumn => columns > 1;
}
