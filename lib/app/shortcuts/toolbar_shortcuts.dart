import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum ToolbarAction {
  exit,
  penTool,
  bucketTool,
  magicWandTool,
  selectionTool,
  handTool,
  undo,
  redo,
  deselect,
}

class ShortcutInfo {
  const ShortcutInfo({
    required this.shortcuts,
    required this.primaryLabel,
    String? macLabel,
  }) : macLabel = macLabel ?? primaryLabel;

  final List<LogicalKeySet> shortcuts;
  final String primaryLabel;
  final String macLabel;

  String labelForPlatform(TargetPlatform platform) {
    if (platform == TargetPlatform.macOS) {
      return macLabel;
    }
    return primaryLabel;
  }
}

class ToolbarShortcuts {
  const ToolbarShortcuts._();

  static final Map<ToolbarAction, ShortcutInfo> _shortcuts = {
    ToolbarAction.exit: ShortcutInfo(
      shortcuts: <LogicalKeySet>[LogicalKeySet(LogicalKeyboardKey.escape)],
      primaryLabel: 'Esc',
    ),
    ToolbarAction.bucketTool: ShortcutInfo(
      shortcuts: <LogicalKeySet>[LogicalKeySet(LogicalKeyboardKey.keyG)],
      primaryLabel: 'G',
    ),
    ToolbarAction.penTool: ShortcutInfo(
      shortcuts: <LogicalKeySet>[LogicalKeySet(LogicalKeyboardKey.keyB)],
      primaryLabel: 'B',
    ),
    ToolbarAction.magicWandTool: ShortcutInfo(
      shortcuts: <LogicalKeySet>[LogicalKeySet(LogicalKeyboardKey.keyW)],
      primaryLabel: 'W',
    ),
    ToolbarAction.selectionTool: ShortcutInfo(
      shortcuts: <LogicalKeySet>[LogicalKeySet(LogicalKeyboardKey.keyM)],
      primaryLabel: 'M',
    ),
    ToolbarAction.handTool: ShortcutInfo(
      shortcuts: <LogicalKeySet>[LogicalKeySet(LogicalKeyboardKey.keyH)],
      primaryLabel: 'H',
    ),
    ToolbarAction.undo: ShortcutInfo(
      shortcuts: <LogicalKeySet>[
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyZ),
      ],
      primaryLabel: 'Ctrl+Z',
      macLabel: 'Command+Z',
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
      primaryLabel: 'Ctrl+Shift+Z',
      macLabel: 'Command+Shift+Z',
    ),
    ToolbarAction.deselect: ShortcutInfo(
      shortcuts: <LogicalKeySet>[
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyD),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyD),
      ],
      primaryLabel: 'Ctrl+D',
      macLabel: 'Command+D',
    ),
  };

  static ShortcutInfo of(ToolbarAction action) {
    return _shortcuts[action]!;
  }

  static String labelForPlatform(
    ToolbarAction action,
    TargetPlatform platform,
  ) {
    return of(action).labelForPlatform(platform);
  }
}
