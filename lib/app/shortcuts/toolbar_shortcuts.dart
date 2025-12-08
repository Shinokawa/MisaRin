import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum ToolbarAction {
  exit,
  layerAdjustTool,
  freeTransform,
  penTool,
  sprayTool,
  curvePenTool,
  shapeTool,
  eraserTool,
  bucketTool,
  magicWandTool,
  eyedropperTool,
  selectionTool,
  textTool,
  handTool,
  undo,
  redo,
  resizeImage,
  resizeCanvas,
  adjustHueSaturation,
  adjustBrightnessContrast,
  gaussianBlur,
  removeColorLeak,
  layerAntialiasPanel,
  deselect,
  importReferenceImage,
  viewBlackWhiteOverlay,
  togglePixelGrid,
  viewMirrorOverlay,
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
    ToolbarAction.layerAdjustTool: ShortcutInfo(
      shortcuts: <LogicalKeySet>[LogicalKeySet(LogicalKeyboardKey.keyV)],
      primaryLabel: 'V',
    ),
    ToolbarAction.freeTransform: ShortcutInfo(
      shortcuts: <LogicalKeySet>[
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyT),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyT),
      ],
      primaryLabel: 'Ctrl+T',
      macLabel: 'Command+T',
    ),
    ToolbarAction.bucketTool: ShortcutInfo(
      shortcuts: <LogicalKeySet>[LogicalKeySet(LogicalKeyboardKey.keyG)],
      primaryLabel: 'G',
    ),
    ToolbarAction.penTool: ShortcutInfo(
      shortcuts: <LogicalKeySet>[LogicalKeySet(LogicalKeyboardKey.keyB)],
      primaryLabel: 'B',
    ),
    ToolbarAction.sprayTool: ShortcutInfo(
      shortcuts: <LogicalKeySet>[LogicalKeySet(LogicalKeyboardKey.keyJ)],
      primaryLabel: 'J',
    ),
    ToolbarAction.curvePenTool: ShortcutInfo(
      shortcuts: <LogicalKeySet>[LogicalKeySet(LogicalKeyboardKey.keyP)],
      primaryLabel: 'P',
    ),
    ToolbarAction.shapeTool: ShortcutInfo(
      shortcuts: <LogicalKeySet>[LogicalKeySet(LogicalKeyboardKey.keyR)],
      primaryLabel: 'R',
    ),
    ToolbarAction.eraserTool: ShortcutInfo(
      shortcuts: <LogicalKeySet>[LogicalKeySet(LogicalKeyboardKey.keyE)],
      primaryLabel: 'E',
    ),
    ToolbarAction.magicWandTool: ShortcutInfo(
      shortcuts: <LogicalKeySet>[LogicalKeySet(LogicalKeyboardKey.keyW)],
      primaryLabel: 'W',
    ),
    ToolbarAction.eyedropperTool: ShortcutInfo(
      shortcuts: <LogicalKeySet>[LogicalKeySet(LogicalKeyboardKey.keyI)],
      primaryLabel: 'I',
    ),
    ToolbarAction.selectionTool: ShortcutInfo(
      shortcuts: <LogicalKeySet>[LogicalKeySet(LogicalKeyboardKey.keyM)],
      primaryLabel: 'M',
    ),
    ToolbarAction.textTool: ShortcutInfo(
      shortcuts: <LogicalKeySet>[LogicalKeySet(LogicalKeyboardKey.keyT)],
      primaryLabel: 'T',
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
    ToolbarAction.resizeImage: ShortcutInfo(
      shortcuts: <LogicalKeySet>[
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.alt,
          LogicalKeyboardKey.keyI,
        ),
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.alt,
          LogicalKeyboardKey.keyI,
        ),
      ],
      primaryLabel: 'Ctrl+Alt+I',
      macLabel: 'Command+Option+I',
    ),
    ToolbarAction.resizeCanvas: ShortcutInfo(
      shortcuts: <LogicalKeySet>[
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.alt,
          LogicalKeyboardKey.keyC,
        ),
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.alt,
          LogicalKeyboardKey.keyC,
        ),
      ],
      primaryLabel: 'Ctrl+Alt+C',
      macLabel: 'Command+Option+C',
    ),
    ToolbarAction.adjustHueSaturation: ShortcutInfo(
      shortcuts: <LogicalKeySet>[
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyU),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyU),
      ],
      primaryLabel: 'Ctrl+U',
      macLabel: 'Command+U',
    ),
    ToolbarAction.adjustBrightnessContrast: ShortcutInfo(
      shortcuts: <LogicalKeySet>[
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyM),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyM),
      ],
      primaryLabel: 'Ctrl+M',
      macLabel: 'Command+M',
    ),
    ToolbarAction.gaussianBlur: ShortcutInfo(
      shortcuts: <LogicalKeySet>[
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.alt,
          LogicalKeyboardKey.keyG,
        ),
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.alt,
          LogicalKeyboardKey.keyG,
        ),
      ],
      primaryLabel: 'Ctrl+Alt+G',
      macLabel: 'Command+Option+G',
    ),
    ToolbarAction.removeColorLeak: ShortcutInfo(
      shortcuts: <LogicalKeySet>[
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.alt,
          LogicalKeyboardKey.keyL,
        ),
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.alt,
          LogicalKeyboardKey.keyL,
        ),
      ],
      primaryLabel: 'Ctrl+Alt+L',
      macLabel: 'Command+Option+L',
    ),
    ToolbarAction.layerAntialiasPanel: ShortcutInfo(
      shortcuts: <LogicalKeySet>[
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.alt,
          LogicalKeyboardKey.keyA,
        ),
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.alt,
          LogicalKeyboardKey.keyA,
        ),
      ],
      primaryLabel: 'Ctrl+Alt+A',
      macLabel: 'Command+Option+A',
    ),
    ToolbarAction.deselect: ShortcutInfo(
      shortcuts: <LogicalKeySet>[
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyD),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyD),
      ],
      primaryLabel: 'Ctrl+D',
      macLabel: 'Command+D',
    ),
    ToolbarAction.importReferenceImage: ShortcutInfo(
      shortcuts: <LogicalKeySet>[
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.alt,
          LogicalKeyboardKey.keyR,
        ),
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.alt,
          LogicalKeyboardKey.keyR,
        ),
      ],
      primaryLabel: 'Ctrl+Alt+R',
      macLabel: 'Command+Option+R',
    ),
    ToolbarAction.viewBlackWhiteOverlay: ShortcutInfo(
      shortcuts: <LogicalKeySet>[LogicalKeySet(LogicalKeyboardKey.keyK)],
      primaryLabel: 'K',
    ),
    ToolbarAction.togglePixelGrid: ShortcutInfo(
      shortcuts: <LogicalKeySet>[LogicalKeySet(LogicalKeyboardKey.keyQ)],
      primaryLabel: 'Q',
    ),
    ToolbarAction.viewMirrorOverlay: ShortcutInfo(
      shortcuts: <LogicalKeySet>[LogicalKeySet(LogicalKeyboardKey.keyF)],
      primaryLabel: 'F',
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
