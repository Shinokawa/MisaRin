import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import '../workspace/canvas_workspace_controller.dart';
import 'window_drag_area.dart';

typedef CanvasTabCallback = void Function(String id);

class CanvasTitleBar extends StatelessWidget {
  const CanvasTitleBar({
    super.key,
    required this.onSelectTab,
    required this.onCloseTab,
    required this.onCreateTab,
  });

  final CanvasTabCallback onSelectTab;
  final CanvasTabCallback onCloseTab;
  final VoidCallback onCreateTab;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final CanvasWorkspaceController controller =
        CanvasWorkspaceController.instance;
    final bool showNativeMacButtons =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: theme.micaBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: theme.resources.controlStrokeColorDefault,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (showNativeMacButtons) const SizedBox(width: 72),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final List<CanvasWorkspaceEntry> entries = controller.entries;
                final String? activeId = controller.activeId;
                if (entries.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Row(
                  children: [
                    Flexible(
                      child: _WorkspaceTabStrip(
                        entries: entries,
                        activeId: activeId,
                        onSelectTab: onSelectTab,
                        onCloseTab: onCloseTab,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double height = constraints.hasBoundedHeight
                              ? constraints.maxHeight
                              : 32;
                          return WindowDragArea(
                            canDragAtPosition: (_) => true,
                            child: SizedBox(
                              width: constraints.maxWidth,
                              height: height,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Button(
            onPressed: onCreateTab,
            style: ButtonStyle(
              padding: WidgetStateProperty.all<EdgeInsets>(
                const EdgeInsets.all(6),
              ),
              shape: WidgetStateProperty.all<OutlinedBorder>(
                const CircleBorder(),
              ),
            ),
            child: const Icon(FluentIcons.add, size: 14),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceTabStrip extends StatelessWidget {
  const _WorkspaceTabStrip({
    required this.entries,
    required this.activeId,
    required this.onSelectTab,
    required this.onCloseTab,
  });

  final List<CanvasWorkspaceEntry> entries;
  final String? activeId;
  final CanvasTabCallback onSelectTab;
  final CanvasTabCallback onCloseTab;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final CanvasWorkspaceEntry entry in entries)
              _WorkspaceTab(
                entry: entry,
                isActive: entry.id == activeId,
                onSelect: onSelectTab,
                onClose: onCloseTab,
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceTab extends StatefulWidget {
  const _WorkspaceTab({
    required this.entry,
    required this.isActive,
    required this.onSelect,
    required this.onClose,
  });

  final CanvasWorkspaceEntry entry;
  final bool isActive;
  final CanvasTabCallback onSelect;
  final CanvasTabCallback onClose;

  @override
  State<_WorkspaceTab> createState() => _WorkspaceTabState();
}

class _WorkspaceTabState extends State<_WorkspaceTab> {
  bool _hovered = false;

  void _handlePointer(bool hovered) {
    if (_hovered == hovered) {
      return;
    }
    setState(() => _hovered = hovered);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final bool isActive = widget.isActive;
    final bool showActiveBackground = isActive || _hovered;
    final Color activeBorder = isActive
        ? theme.resources.controlStrokeColorDefault
        : Colors.transparent;
    final TextStyle? textStyle = theme.typography.caption;
    final Color textColor = isActive
        ? theme.typography.bodyStrong?.color ??
              theme.typography.body?.color ??
              Colors.white
        : theme.typography.caption?.color ?? Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: MouseRegion(
        onEnter: (_) => _handlePointer(true),
        onExit: (_) => _handlePointer(false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onSelect(widget.entry.id),
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: showActiveBackground
                  ? theme.resources.subtleFillColorSecondary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: activeBorder, width: isActive ? 1 : 0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.entry.name,
                  style: textStyle?.copyWith(color: textColor),
                ),
                if (widget.entry.isDirty)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      FluentIcons.circle_shape_solid,
                      size: 6,
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onClose(widget.entry.id),
                      child: const Icon(FluentIcons.chrome_close, size: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
