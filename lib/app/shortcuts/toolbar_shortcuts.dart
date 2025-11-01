import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum ToolbarAction {
  exit,
  penTool,
  handTool,
  undo,
  redo,
}

class ShortcutInfo {
  const ShortcutInfo({
    required this.shortcuts,
    required this.tooltipLabel,
  });

  final List<LogicalKeySet> shortcuts;
  final String tooltipLabel;
}

class ToolbarShortcuts {
  const ToolbarShortcuts._();

  static final Map<ToolbarAction, ShortcutInfo> _shortcuts = {
    ToolbarAction.exit: ShortcutInfo(
      shortcuts: <LogicalKeySet>[
        LogicalKeySet(LogicalKeyboardKey.escape),
      ],
      tooltipLabel: 'Esc',
    ),
    ToolbarAction.penTool: ShortcutInfo(
      shortcuts: <LogicalKeySet>[
        LogicalKeySet(LogicalKeyboardKey.keyB),
      ],
      tooltipLabel: 'B',
    ),
    ToolbarAction.handTool: ShortcutInfo(
      shortcuts: <LogicalKeySet>[
        LogicalKeySet(LogicalKeyboardKey.keyH),
      ],
      tooltipLabel: 'H',
    ),
    ToolbarAction.undo: ShortcutInfo(
      shortcuts: <LogicalKeySet>[
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyZ),
      ],
      tooltipLabel: 'Ctrl+Z / Cmd+Z',
    ),
    ToolbarAction.redo: ShortcutInfo(
      shortcuts: <LogicalKeySet>[
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyZ,
        ),
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyZ,
        ),
      ],
      tooltipLabel: 'Ctrl+Shift+Z / Cmd+Shift+Z',
    ),
  };

  static ShortcutInfo of(ToolbarAction action) {
    return _shortcuts[action]!;
  }
}
