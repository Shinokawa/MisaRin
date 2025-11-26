import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../widgets/toolbar_panel_card.dart';
import 'painting_toolbar_layout.dart';

class FloatingToolbarLayoutDelegate extends PaintingToolbarLayoutDelegate {
  const FloatingToolbarLayoutDelegate();

  @override
  PaintingToolbarLayoutResult build(
    BuildContext context,
    PaintingToolbarElements elements,
    PaintingToolbarMetrics metrics,
  ) {
    final double toolbarPadding = metrics.toolButtonPadding;
    final Widget toolbar = Positioned(
      left: toolbarPadding,
      top: toolbarPadding,
      child: elements.toolbar,
    );

    Widget toolSettings = elements.toolSettings;
    final double? maxWidth = metrics.toolSettingsMaxWidth;
    if (maxWidth != null) {
      toolSettings = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: toolSettings,
      );
    }
    toolSettings = Positioned(
      left: metrics.toolSettingsLeft,
      top: toolbarPadding,
      child: toolSettings,
    );

    final Widget colorIndicator = Positioned(
      left: toolbarPadding,
      bottom: toolbarPadding,
      child: elements.colorIndicator,
    );

    Widget buildPanel(ToolbarPanelData data) {
      return ToolbarPanelCard(
        width: metrics.sidePanelWidth,
        title: data.title,
        trailing: data.trailing,
        expand: data.expand,
        child: data.child,
      );
    }

    final Widget rightPanels = Positioned(
      right: toolbarPadding,
      top: toolbarPadding,
      bottom: toolbarPadding,
      child: SizedBox(
        width: metrics.sidePanelWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildPanel(elements.colorPanel),
            SizedBox(height: metrics.sidePanelSpacing),
            if (elements.layerPanel.expand)
              Expanded(child: buildPanel(elements.layerPanel))
            else
              buildPanel(elements.layerPanel),
          ],
        ),
      ),
    );

    final List<Rect> hitRegions = <Rect>[
      Rect.fromLTWH(
        toolbarPadding,
        toolbarPadding,
        metrics.toolbarLayout.width,
        metrics.toolbarLayout.height,
      ),
      Rect.fromLTWH(
        metrics.toolSettingsLeft,
        toolbarPadding,
        metrics.toolSettingsSize.width,
        metrics.toolSettingsSize.height,
      ),
      Rect.fromLTWH(
        toolbarPadding,
        (metrics.workspaceSize.height -
                toolbarPadding -
                metrics.colorIndicatorSize)
            .clamp(0.0, double.infinity),
        metrics.colorIndicatorSize,
        metrics.colorIndicatorSize,
      ),
      Rect.fromLTWH(
        metrics.sidebarLeft,
        toolbarPadding,
        metrics.sidePanelWidth,
        (metrics.workspaceSize.height - 2 * toolbarPadding).clamp(
          0.0,
          double.infinity,
        ),
      ),
    ];

    return PaintingToolbarLayoutResult(
      widgets: <Widget>[toolbar, toolSettings, colorIndicator, rightPanels],
      hitRegions: hitRegions,
    );
  }
}
