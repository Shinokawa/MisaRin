import 'package:fluent_ui/fluent_ui.dart';
import '../app/menu/menu_definitions.dart';
import '../app/menu/menu_action_dispatcher.dart';
import '../app/l10n/l10n.dart';
import 'mobile_utils.dart';

class MobileMenuSheet extends StatefulWidget {
  const MobileMenuSheet({
    super.key,
  });

  @override
  State<MobileMenuSheet> createState() => _MobileMenuSheetState();
}

class _MenuLevel {
  const _MenuLevel({required this.title, required this.entries});
  final String title;
  final List<MenuEntry> entries;
}

class _MobileMenuSheetState extends State<MobileMenuSheet> {
  final List<_MenuLevel> _stack = [];
  bool _initialized = false;

  void _initStack(BuildContext context) {
    if (_initialized) return;
    final dispatcher = MenuActionDispatcher.instance;
    final menus = MenuDefinitionBuilder.build(
      dispatcher.current,
      context.l10n,
    );
    final l10n = context.l10n;
    final List<MenuEntry> rootEntries = [];
    for (final menu in menus) {
      if (menu.label == l10n.menuWorkspace || menu.label == l10n.menuWindow) {
        continue;
      }
      if (menu.label == 'Misa Rin') {
        MenuActionEntry? preferencesEntry;
        for (final entry in menu.entries) {
          if (entry is MenuActionEntry &&
              entry.label == l10n.menuPreferences) {
            preferencesEntry = entry;
            break;
          }
        }
        if (preferencesEntry != null) {
          rootEntries.add(preferencesEntry);
        }
        continue;
      }
      rootEntries.add(
        MenuSubmenuEntry(label: menu.label, entries: menu.entries),
      );
    }
    _stack.add(_MenuLevel(
      title: l10n.menuRoot,
      entries: rootEntries,
    ));
    _initialized = true;
  }

  void _push(String title, List<MenuEntry> entries) {
    setState(() {
      _stack.add(_MenuLevel(title: title, entries: entries));
    });
  }

  void _pop() {
    if (_stack.length > 1) {
      setState(() {
        _stack.removeLast();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _initStack(context);
    final theme = FluentTheme.of(context);
    final dispatcher = MenuActionDispatcher.instance;

    return AnimatedBuilder(
      animation: dispatcher,
      builder: (context, _) {
        final current = _stack.last;
        final isRoot = _stack.length == 1;

        return Column(
          children: [
            // Header with Back button and Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (!isRoot)
                    IconButton(
                      icon: const Icon(FluentIcons.back, size: 20),
                      onPressed: _pop,
                    )
                  else
                    const SizedBox(width: 40),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      current.title,
                      style: theme.typography.subtitle?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Menu List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: current.entries.length,
                separatorBuilder: (context, index) {
                  if (current.entries[index] is MenuSeparatorEntry) {
                    return const Divider();
                  }
                  return const SizedBox.shrink();
                },                itemBuilder: (context, index) {
                  final entry = current.entries[index];
                  return _buildEntryTile(context, entry);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEntryTile(BuildContext context, MenuEntry entry) {
    final theme = FluentTheme.of(context);

    if (entry is MenuSeparatorEntry) {
      return const SizedBox.shrink();
    }

    if (entry is MenuSubmenuEntry) {
      return ListTile(
        title: Text(entry.label, style: const TextStyle(fontSize: 18)),
        trailing: const Icon(FluentIcons.chevron_right, size: 14),
        onPressed: () => _push(entry.label, entry.entries),
      );
    }

    if (entry is MenuActionEntry) {
      final bool enabled = entry.isEnabled;
      return ListTile(
        title: Text(
          entry.label,
          style: TextStyle(
            fontSize: 18,
            color: enabled ? null : theme.resources.textFillColorDisabled,
          ),
        ),
        trailing: entry.checked
            ? Icon(
                FluentIcons.check_mark,
                size: 16,
                color: theme.accentColor,
              )
            : null,
        onPressed: enabled
            ? () {
                Navigator.of(context).pop();
                entry.action?.call();
              }
            : null,
      );
    }

    if (entry is MenuProvidedEntry) {
      return const SizedBox.shrink();
    }

    return const SizedBox.shrink();
  }
}
