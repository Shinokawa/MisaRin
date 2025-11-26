import 'dart:math' as math;
import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart' show Divider, FluentTheme, Scrollbar;
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

    Widget buildToolsPanel() {
      final theme = FluentTheme.of(context);
      Widget buildSectionHeader(String title, {Widget? trailing}) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: Text(title, style: theme.typography.bodyStrong)),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        );
      }

      Widget buildDivider() {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(),
        );
      }

      Widget buildColorSection() {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            buildSectionHeader(
              elements.colorPanel.title,
              trailing: elements.colorPanel.trailing,
            ),
            const SizedBox(height: 8),
            elements.colorPanel.child,
          ],
        );
      }

      Widget buildScrollableContent(Widget child) {
        return Scrollbar(
          child: SingleChildScrollView(
            primary: true,
            child: Align(
              alignment: Alignment.topLeft,
              child: child,
            ),
          ),
        );
      }

      Widget buildSection({
        required String title,
        Widget? trailing,
        required Widget child,
      }) {
        return Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildSectionHeader(title, trailing: trailing),
              const SizedBox(height: 8),
              Expanded(child: child),
            ],
          ),
        );
      }

      return ToolbarPanelCard(
        width: columnWidth,
        title: '工具面板',
        expand: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildColorSection(),
            buildDivider(),
            buildSection(
              title: '工具栏',
              child: buildScrollableContent(elements.toolbar),
            ),
            buildDivider(),
            buildSection(
              title: '工具选项',
              child: buildScrollableContent(elements.toolSettings),
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
          buildToolsPanel(),
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
