import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'package:misa_rin/app/toolbars/widgets/canvas_toolbar.dart';

enum PaintingToolbarLayoutStyle { floating, sai2 }

class ToolbarPanelData {
  const ToolbarPanelData({
    required this.title,
    required this.child,
    this.trailing,
    this.expand = false,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final bool expand;
}

class PaintingToolbarElements {
  const PaintingToolbarElements({
    required this.toolbar,
    required this.toolSettings,
    required this.colorIndicator,
    required this.colorPanel,
    required this.layerPanel,
    required this.exitButton,
  });

  final Widget toolbar;
  final Widget toolSettings;
  final Widget colorIndicator;
  final ToolbarPanelData colorPanel;
  final ToolbarPanelData layerPanel;
  final Widget exitButton;
}

class PaintingToolbarMetrics {
  const PaintingToolbarMetrics({
    required this.toolbarLayout,
    required this.toolSettingsSize,
    required this.workspaceSize,
    required this.toolButtonPadding,
    required this.toolSettingsSpacing,
    required this.sidePanelWidth,
    required this.sidePanelSpacing,
    required this.colorIndicatorSize,
    required this.toolSettingsLeft,
    required this.sidebarLeft,
    required this.toolSettingsMaxWidth,
  });

  final CanvasToolbarLayout toolbarLayout;
  final Size toolSettingsSize;
  final Size workspaceSize;
  final double toolButtonPadding;
  final double toolSettingsSpacing;
  final double sidePanelWidth;
  final double sidePanelSpacing;
  final double colorIndicatorSize;
  final double toolSettingsLeft;
  final double sidebarLeft;
  final double? toolSettingsMaxWidth;
}

class PaintingToolbarLayoutResult {
  const PaintingToolbarLayoutResult({
    required this.widgets,
    required this.hitRegions,
  });

  final List<Widget> widgets;
  final List<Rect> hitRegions;

  static const PaintingToolbarLayoutResult empty = PaintingToolbarLayoutResult(
    widgets: <Widget>[],
    hitRegions: <Rect>[],
  );
}

abstract class PaintingToolbarLayoutDelegate {
  const PaintingToolbarLayoutDelegate();

  PaintingToolbarLayoutResult build(
    BuildContext context,
    PaintingToolbarElements elements,
    PaintingToolbarMetrics metrics,
  );
}
