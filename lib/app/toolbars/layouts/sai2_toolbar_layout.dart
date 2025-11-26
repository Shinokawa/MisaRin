import 'dart:math' as math;
import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart' show Scrollbar;
import 'package:flutter/widgets.dart';

import '../widgets/toolbar_panel_card.dart';
import 'painting_toolbar_layout.dart';

class Sai2ToolbarLayoutDelegate extends PaintingToolbarLayoutDelegate {
  const Sai2ToolbarLayoutDelegate();

  @override
  PaintingToolbarLayoutResult build(
    BuildContext context,
    PaintingToolbarElements elements,
    PaintingToolbarMetrics metrics,
  ) {
    final double padding = metrics.toolButtonPadding;
    final double columnWidth = metrics.sidePanelWidth;
    final double gutter = metrics.toolSettingsSpacing;
    final double columnHeight = (metrics.workspaceSize.height - 2 * padding)
        .clamp(0.0, double.infinity);

    Widget buildLayerPanel() {
      final card = ToolbarPanelCard(
        width: columnWidth,
        title: elements.layerPanel.title,
        trailing: elements.layerPanel.trailing,
        expand: true,
        child: elements.layerPanel.child,
      );
      return SizedBox(width: columnWidth, child: card);
    }

    Widget buildColorPanel() {
      return ToolbarPanelCard(
        width: columnWidth,
        title: elements.colorPanel.title,
        trailing: elements.colorPanel.trailing,
        expand: true,
        child: elements.colorPanel.child,
      );
    }

    Widget buildToolbarCard() {
      return ToolbarPanelCard(
        width: columnWidth,
        title: '工具栏',
        expand: true,
        child: Scrollbar(
          child: SingleChildScrollView(
            primary: false,
            child: Align(alignment: Alignment.topLeft, child: elements.toolbar),
          ),
        ),
      );
    }

    Widget buildToolSettingsCard() {
      return ToolbarPanelCard(
        width: columnWidth,
        title: '工具选项',
        expand: true,
        child: Scrollbar(
          child: SingleChildScrollView(
            primary: false,
            child: Align(
              alignment: Alignment.topLeft,
              child: elements.toolSettings,
            ),
          ),
        ),
      );
    }

    Widget buildToolWorkspace() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: buildToolbarCard()),
          SizedBox(height: gutter),
          Expanded(child: buildToolSettingsCard()),
        ],
      );
    }

    final Widget layout = Positioned(
      left: padding,
      top: padding,
      bottom: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildLayerPanel(),
          SizedBox(width: gutter),
          SizedBox(
            width: columnWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: buildColorPanel()),
                SizedBox(height: metrics.sidePanelSpacing),
                Expanded(child: buildToolWorkspace()),
              ],
            ),
          ),
        ],
      ),
    );

    final double indicatorSize = metrics.colorIndicatorSize;
    final double indicatorLeft =
        (metrics.workspaceSize.width - padding - indicatorSize).clamp(
          0.0,
          double.infinity,
        );
    final double indicatorTop =
        (metrics.workspaceSize.height - padding - indicatorSize).clamp(
          0.0,
          double.infinity,
        );
    final double exitTop = math.max(
      padding,
      indicatorTop - gutter - indicatorSize,
    );

    final Widget dockedControls = Positioned(
      right: padding,
      bottom: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          elements.exitButton,
          SizedBox(height: gutter),
          elements.colorIndicator,
        ],
      ),
    );

    final double rightColumnLeft = padding + columnWidth + gutter;

    final List<Rect> hitRegions = <Rect>[
      Rect.fromLTWH(padding, padding, columnWidth, columnHeight),
      Rect.fromLTWH(rightColumnLeft, padding, columnWidth, columnHeight),
      Rect.fromLTWH(indicatorLeft, indicatorTop, indicatorSize, indicatorSize),
      Rect.fromLTWH(indicatorLeft, exitTop, indicatorSize, indicatorSize),
    ];

    return PaintingToolbarLayoutResult(
      widgets: <Widget>[layout, dockedControls],
      hitRegions: hitRegions,
    );
  }
}
