import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/widgets.dart';

import 'menu_definitions.dart';
import 'menu_helpers.dart';

class TouchMenuOverlay extends StatefulWidget {
  const TouchMenuOverlay({
    super.key,
    required this.anchorRect,
    required this.entries,
    required this.onDismiss,
    required this.menuBarHeight,
  });

  final Rect anchorRect;
  final List<MenuEntry> entries;
  final VoidCallback onDismiss;
  final double menuBarHeight;

  @override
  State<TouchMenuOverlay> createState() => _TouchMenuOverlayState();
}

class _MeasureSize extends StatefulWidget {
  const _MeasureSize({
    required this.onChange,
    required this.child,
  });

  final ValueChanged<Size> onChange;
  final Widget child;

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  Size? _size;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final Size? newSize = context.size;
      if (newSize == null || newSize == _size) {
        return;
      }
      _size = newSize;
      widget.onChange(newSize);
    });
    return widget.child;
  }
}

class _MenuLevel {
  const _MenuLevel({required this.entries, required this.anchorRect});

  final List<MenuEntry> entries;
  final Rect anchorRect;
}

class _TouchMenuOverlayState extends State<TouchMenuOverlay> {
  late List<_MenuLevel> _levels;
  List<Size?> _panelSizes = <Size?>[];
  bool _canDismiss = false;

  @override
  void initState() {
    super.initState();
    _levels = <_MenuLevel>[
      _MenuLevel(entries: widget.entries, anchorRect: widget.anchorRect),
    ];
    _panelSizes = List<Size?>.filled(_levels.length, null, growable: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _canDismiss = true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant TouchMenuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries != widget.entries ||
        oldWidget.anchorRect != widget.anchorRect) {
      _levels = <_MenuLevel>[
        _MenuLevel(entries: widget.entries, anchorRect: widget.anchorRect),
      ];
      _panelSizes = List<Size?>.filled(_levels.length, null, growable: true);
      _canDismiss = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _canDismiss = true);
        }
      });
    }
  }

  void _openSubmenu(MenuSubmenuEntry submenu, Rect anchorRect, int depth) {
    setState(() {
      if (_levels.length > depth + 1) {
        _levels = _levels.sublist(0, depth + 1);
      }
      _levels = List<_MenuLevel>.from(_levels)
        ..add(_MenuLevel(entries: submenu.entries, anchorRect: anchorRect));
      if (_panelSizes.length > _levels.length) {
        _panelSizes = _panelSizes.sublist(0, _levels.length);
      }
      while (_panelSizes.length < _levels.length) {
        _panelSizes.add(null);
      }
    });
  }

  void _updatePanelSize(int index, Size size) {
    if (index >= _panelSizes.length) {
      return;
    }
    if (_panelSizes[index] == size) {
      return;
    }
    setState(() => _panelSizes[index] = size);
  }

  List<MenuFlyoutItemBase> _buildLevelItems(
    BuildContext context,
    FluentThemeData theme,
    List<MenuEntry> entries,
    int depth,
  ) {
    final List<MenuFlyoutItemBase> items = <MenuFlyoutItemBase>[];
    for (final MenuEntry entry in entries) {
      if (entry is MenuSeparatorEntry) {
        if (items.isEmpty || items.last is MenuFlyoutSeparator) {
          continue;
        }
        items.add(const MenuFlyoutSeparator());
        continue;
      }
      if (entry is MenuProvidedEntry) {
        continue;
      }
      if (entry is MenuActionEntry) {
        final VoidCallback? action = wrapMenuAction(entry.action);
        if (action == null && entry.isEnabled) {
          continue;
        }
        final bool enabled = entry.isEnabled && action != null;
        final String? shortcutLabel = formatMenuShortcut(entry.shortcut);
        final TextStyle? shortcutStyle = theme.typography.caption?.copyWith(
          color: theme.resources.textFillColorSecondary,
        );
        items.add(
          MenuFlyoutItem(
            leading: entry.checked
                ? const Icon(FluentIcons.check_mark, size: 12)
                : null,
            text: Text(entry.label),
            trailing: shortcutLabel == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Text(shortcutLabel, style: shortcutStyle),
                  ),
            closeAfterClick: false,
            onPressed: enabled
                ? () {
                    widget.onDismiss();
                    action();
                  }
                : null,
          ),
        );
        continue;
      }
      if (entry is MenuSubmenuEntry) {
        if (entry.entries.isEmpty) {
          continue;
        }
        final GlobalKey itemKey = GlobalKey();
        items.add(
          MenuFlyoutItem(
            key: itemKey,
            text: Text(entry.label),
            trailing: const Icon(FluentIcons.chevron_right, size: 12),
            closeAfterClick: false,
            onPressed: () {
              final RenderBox? box =
                  itemKey.currentContext?.findRenderObject() as RenderBox?;
              if (box == null || !box.hasSize) {
                return;
              }
              final Offset global = box.localToGlobal(Offset.zero);
              final Rect rect = global & box.size;
              _openSubmenu(entry, rect, depth);
            },
          ),
        );
      }
    }
    if (items.isNotEmpty && items.last is MenuFlyoutSeparator) {
      items.removeLast();
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final FluentThemeData theme = FluentTheme.of(context);
    const double menuWidth = 240;
    const double margin = 8;
    final double maxHeight = screenSize.height - margin * 2;

    final List<Widget> panels = <Widget>[];
    for (int i = 0; i < _levels.length; i++) {
      final _MenuLevel level = _levels[i];
      final Rect anchor = level.anchorRect;
      final bool isRoot = i == 0;
      final bool openRight =
          anchor.right + menuWidth + margin <= screenSize.width;
      double x = isRoot
          ? anchor.left
          : (openRight ? anchor.right : anchor.left - menuWidth);
      double y = isRoot ? anchor.bottom : anchor.top;
      final Size? panelSize =
          i < _panelSizes.length ? _panelSizes[i] : null;
      final double panelHeight = panelSize?.height ?? 0;

      if (x < margin) {
        x = margin;
      } else if (x + menuWidth + margin > screenSize.width) {
        x = screenSize.width - menuWidth - margin;
      }

      if (panelHeight > 0 &&
          y + panelHeight + margin > screenSize.height) {
        y = screenSize.height - panelHeight - margin;
      }
      if (y < margin) {
        y = margin;
      }

      panels.add(
        Positioned(
          left: x,
          top: y,
          child: _MeasureSize(
            onChange: (size) => _updatePanelSize(i, size),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: menuWidth,
                maxWidth: menuWidth,
                maxHeight: maxHeight,
              ),
              child: MenuFlyout(
                items: _buildLevelItems(
                  context,
                  theme,
                  level.entries,
                  i,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final Widget barrier = Positioned(
      left: 0,
      right: 0,
      top: widget.menuBarHeight,
      bottom: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _canDismiss ? widget.onDismiss : null,
        child: const SizedBox.expand(),
      ),
    );

    return MenuInfoProvider(
      builder: (context, _, menus, __) {
        return Stack(
          children: [
            barrier,
            ...panels,
            ...menus,
          ],
        );
      },
    );
  }
}
