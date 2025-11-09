import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../widgets/window_drag_area.dart';
import 'menu_action_dispatcher.dart';
import 'menu_definitions.dart';

class CustomMenuBar extends StatelessWidget {
  const CustomMenuBar({super.key, required this.menus});

  final List<MenuDefinition> menus;

  @override
  Widget build(BuildContext context) {
    final List<MenuDefinition> visibleMenus = menus
        .map(_pruneMenu)
        .whereType<MenuDefinition>()
        .toList(growable: false);
    if (visibleMenus.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = FluentTheme.of(context);
    final bool canDrag = _supportsWindowDragArea();
    final Widget dragArea = canDrag
        ? Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: WindowDragArea(
                enableDoubleClickToMaximize: true,
                canDragAtPosition: (_) => true,
                child: const SizedBox.expand(),
              ),
            ),
          )
        : const Spacer();
    return Container(
      decoration: BoxDecoration(
        color: theme.micaBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: theme.resources.controlStrokeColorDefault,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 36,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < visibleMenus.length; i++) ...[
                _MenuButton(definition: visibleMenus[i]),
                if (i != visibleMenus.length - 1) const SizedBox(width: 4),
              ],
              dragArea,
            ],
          ),
        ),
      ),
    );
  }

  static MenuDefinition? _pruneMenu(MenuDefinition menu) {
    final List<MenuEntry> entries = _pruneEntries(menu.entries);
    if (entries.isEmpty) {
      return null;
    }
    return MenuDefinition(label: menu.label, entries: entries);
  }

  static List<MenuEntry> _pruneEntries(List<MenuEntry> entries) {
    final List<MenuEntry> result = <MenuEntry>[];
    for (final MenuEntry entry in entries) {
      if (entry is MenuProvidedEntry) {
        continue;
      }
      if (entry is MenuSubmenuEntry) {
        final List<MenuEntry> children = _pruneEntries(entry.entries);
        if (children.isEmpty) {
          continue;
        }
        result.add(MenuSubmenuEntry(label: entry.label, entries: children));
        continue;
      }
      if (entry is MenuSeparatorEntry) {
        if (result.isEmpty || result.last is MenuSeparatorEntry) {
          continue;
        }
        result.add(entry);
        continue;
      }
      result.add(entry);
    }
    while (result.isNotEmpty && result.last is MenuSeparatorEntry) {
      result.removeLast();
    }
    return result;
  }

  static bool _supportsWindowDragArea() {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }
}

class _MenuButton extends StatefulWidget {
  const _MenuButton({required this.definition});

  final MenuDefinition definition;

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  late final FlyoutController _flyoutController = FlyoutController();
  bool _hovered = false;

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  void _showMenu() {
    if (widget.definition.entries.isEmpty) {
      return;
    }
    _flyoutController.showFlyout(
      barrierDismissible: true,
      placementMode: FlyoutPlacementMode.bottomLeft,
      builder: (context) {
        return MenuFlyout(
          items: _buildMenuItems(context, widget.definition.entries),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final TextStyle textStyle =
        theme.typography.body?.copyWith(fontWeight: FontWeight.w600) ??
        const TextStyle(fontWeight: FontWeight.w600);
    final Color textColor = _hovered
        ? theme.resources.textFillColorPrimary
        : theme.typography.body?.color ?? Colors.white;

    return FlyoutTarget(
      controller: _flyoutController,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showMenu,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _hovered
                  ? theme.resources.subtleFillColorSecondary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.definition.label,
              style: textStyle.copyWith(color: textColor),
            ),
          ),
        ),
      ),
    );
  }

  List<MenuFlyoutItemBase> _buildMenuItems(
    BuildContext context,
    List<MenuEntry> entries,
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
      final MenuFlyoutItemBase? flyoutItem = _convertEntry(context, entry);
      if (flyoutItem != null) {
        items.add(flyoutItem);
      }
    }
    if (items.isNotEmpty && items.last is MenuFlyoutSeparator) {
      items.removeLast();
    }
    return items;
  }

  MenuFlyoutItemBase? _convertEntry(BuildContext context, MenuEntry entry) {
    if (entry is MenuActionEntry) {
      final VoidCallback? onPressed = _wrapAction(entry.action);
      if (onPressed == null) {
        return null;
      }
      final String? shortcutLabel = _formatShortcut(entry.shortcut);
      final TextStyle? shortcutStyle = FluentTheme.of(context)
          .typography
          .caption
          ?.copyWith(
            color: FluentTheme.of(context).resources.textFillColorSecondary,
          );
      return MenuFlyoutItem(
        text: Text(entry.label),
        trailing: shortcutLabel == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Text(shortcutLabel, style: shortcutStyle),
              ),
        onPressed: onPressed,
      );
    }
    if (entry is MenuSubmenuEntry) {
      final List<MenuEntry> children = entry.entries;
      if (children.isEmpty) {
        return null;
      }
      return MenuFlyoutSubItem(
        text: Text(entry.label),
        items: (context) => _buildMenuItems(context, children),
      );
    }
    return null;
  }
}

VoidCallback? _wrapAction(MenuAsyncAction? action) {
  if (action == null) {
    return null;
  }
  return () => unawaited(Future.sync(action));
}

String? _formatShortcut(MenuSerializableShortcut? shortcut) {
  if (shortcut == null) {
    return null;
  }
  if (shortcut is! SingleActivator) {
    return null;
  }
  final bool isMac = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
  final List<String> parts = <String>[];

  if (shortcut.control) {
    parts.add(isMac ? '⌃' : 'Ctrl');
  }
  if (shortcut.meta) {
    parts.add(isMac ? '⌘' : 'Ctrl');
  }
  if (shortcut.alt) {
    parts.add(isMac ? '⌥' : 'Alt');
  }
  if (shortcut.shift) {
    parts.add(isMac ? '⇧' : 'Shift');
  }

  final String keyLabel = _describeLogicalKey(shortcut.trigger);
  if (keyLabel.isNotEmpty) {
    parts.add(isMac ? keyLabel : keyLabel.toUpperCase());
  }

  if (parts.isEmpty) {
    return null;
  }

  return isMac ? parts.join() : parts.join('+');
}

String _describeLogicalKey(LogicalKeyboardKey key) {
  final String label = key.keyLabel;
  if (label.isNotEmpty) {
    if (label.length == 1 &&
        label.codeUnitAt(0) >= 97 &&
        label.codeUnitAt(0) <= 122) {
      return label.toUpperCase();
    }
    return label;
  }
  return key.debugName ?? '';
}
