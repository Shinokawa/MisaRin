part of 'painting_board.dart';

class WorkspaceFloatingPanel extends StatelessWidget {
  const WorkspaceFloatingPanel({
    super.key,
    required this.title,
    required this.child,
    this.footer,
    this.width,
    this.minHeight,
    this.headerActions,
    this.onClose,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.headerPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    this.bodyPadding = const EdgeInsets.symmetric(horizontal: 16),
    this.footerPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 12,
    ),
    this.bodySpacing = 12,
    this.footerSpacing = 12,
    this.closeIconSize = 14,
  });

  final String title;
  final Widget child;
  final Widget? footer;
  final double? width;
  final double? minHeight;
  final List<Widget>? headerActions;
  final VoidCallback? onClose;
  final VoidCallback? onDragStart;
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onDragEnd;
  final EdgeInsetsGeometry headerPadding;
  final EdgeInsetsGeometry bodyPadding;
  final EdgeInsetsGeometry footerPadding;
  final double bodySpacing;
  final double footerSpacing;
  final double closeIconSize;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    Color background = theme.cardColor;
    if (background.alpha != 0xFF) {
      background = theme.brightness.isDark
          ? const Color(0xFF1F1F1F)
          : Colors.white;
    }
    final List<Widget> trailing = <Widget>[];
    if (headerActions != null && headerActions!.isNotEmpty) {
      trailing.addAll(headerActions!);
    }
    if (onClose != null) {
      if (trailing.isNotEmpty) {
        trailing.add(const SizedBox(width: 8));
      }
      trailing.add(
        IconButton(
          icon: Icon(FluentIcons.chrome_close, size: closeIconSize),
          iconButtonMode: IconButtonMode.small,
          style: ButtonStyle(
            padding: WidgetStateProperty.all(const EdgeInsets.all(4)),
          ),
          onPressed: onClose,
        ),
      );
    }
    return Container(
      width: width,
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.resources.controlStrokeColorDefault),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: onDragStart == null ? null : (_) => onDragStart!(),
            onPanUpdate: onDragUpdate == null
                ? null
                : (details) => onDragUpdate!(details.delta),
            onPanEnd: onDragEnd == null ? null : (_) => onDragEnd!(),
            onPanCancel: onDragEnd,
            child: Padding(
              padding: headerPadding,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.typography.subtitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...trailing,
                ],
              ),
            ),
          ),
          if (bodySpacing > 0) SizedBox(height: bodySpacing),
          Padding(padding: bodyPadding, child: child),
          if (footer != null) ...[
            if (footerSpacing > 0) SizedBox(height: footerSpacing),
            Padding(padding: footerPadding, child: footer!),
          ],
        ],
      ),
    );
  }
}

Offset _workspacePanelSpawnOffset(
  _PaintingBoardBase host, {
  required double panelWidth,
  required double panelHeight,
  double additionalDx = 0,
  double additionalDy = 0,
  double margin = 16,
  double verticalGap = 12,
}) {
  final double settingsLeft;
  if (host._toolbarHitRegions.isNotEmpty) {
    settingsLeft = host._toolbarHitRegions
        .map((rect) => rect.right)
        .fold(margin, math.max);
  } else {
    settingsLeft =
        _toolButtonPadding + host._toolbarLayout.width + _toolSettingsSpacing;
  }
  final double baseLeft = math.max(margin, settingsLeft);
  final double settingsBottom =
      _toolButtonPadding + host._toolSettingsCardSize.height;
  final double baseTop = math.max(margin, settingsBottom + verticalGap);
  double targetLeft = baseLeft + additionalDx;
  double targetTop = baseTop + additionalDy;
  final Size workspaceSize = host._workspaceSize;
  if (!workspaceSize.isEmpty) {
    final double maxLeft = math.max(
      margin,
      workspaceSize.width - panelWidth - margin,
    );
    final double maxTop = math.max(
      margin,
      workspaceSize.height - panelHeight - margin,
    );
    targetLeft = targetLeft.clamp(margin, maxLeft);
    targetTop = targetTop.clamp(margin, maxTop);
  }
  return Offset(targetLeft, targetTop);
}

Offset _workspaceToOverlayOffset(
  _PaintingBoardBase host,
  Offset workspaceOffset,
) {
  final RenderObject? renderObject = host.context.findRenderObject();
  if (renderObject is RenderBox) {
    final Offset origin = renderObject.localToGlobal(Offset.zero);
    return origin + workspaceOffset;
  }
  return workspaceOffset;
}

Offset _clampWorkspaceOffsetToViewport(
  _PaintingBoardBase host,
  Offset workspaceOffset, {
  required Size childSize,
  double margin = 12,
}) {
  final RenderObject? renderObject = host.context.findRenderObject();
  if (renderObject is! RenderBox) {
    return workspaceOffset;
  }
  final Offset origin = renderObject.localToGlobal(Offset.zero);
  final Size viewportSize = MediaQuery.sizeOf(host.context);
  final double minX = margin - origin.dx;
  final double minY = margin - origin.dy;
  final double maxX = math.max(
    minX,
    viewportSize.width - childSize.width - margin - origin.dx,
  );
  final double maxY = math.max(
    minY,
    viewportSize.height - childSize.height - margin - origin.dy,
  );
  return Offset(
    workspaceOffset.dx.clamp(minX, maxX),
    workspaceOffset.dy.clamp(minY, maxY),
  );
}
