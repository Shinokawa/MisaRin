import 'dart:ui';

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            elements.colorIndicator,
            const SizedBox(height: 12),
            Expanded(child: elements.colorPanel.child),
          ],
        ),
      );
    }

    Widget buildToolPanel() {
      return ToolbarPanelCard(
        width: columnWidth,
        title: '工具',
        expand: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(alignment: Alignment.centerLeft, child: elements.toolbar),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(child: elements.toolSettings),
            ),
          ],
        ),
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
                Expanded(child: buildToolPanel()),
              ],
            ),
          ),
        ],
      ),
    );

    final double rightColumnLeft = padding + columnWidth + gutter;

    final List<Rect> hitRegions = <Rect>[
      Rect.fromLTWH(padding, padding, columnWidth, columnHeight),
      Rect.fromLTWH(rightColumnLeft, padding, columnWidth, columnHeight),
    ];

    return PaintingToolbarLayoutResult(
      widgets: <Widget>[layout],
      hitRegions: hitRegions,
    );
  }
}
