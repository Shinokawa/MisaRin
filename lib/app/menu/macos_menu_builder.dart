import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'menu_action_dispatcher.dart';

class MacosMenuBuilder {
  const MacosMenuBuilder._();

  static List<PlatformMenu> build(MenuActionHandler handler) {
    return <PlatformMenu?>[
      _applicationMenu(handler),
      _fileMenu(handler),
      _editMenu(handler),
      _imageMenu(handler),
      _layerMenu(handler),
      _filterMenu(handler),
      _toolMenu(handler),
      _viewMenu(handler),
      _windowMenu(),
    ].whereType<PlatformMenu>().toList(growable: false);
  }

  static VoidCallback? _wrap(MenuAsyncAction? action) {
    if (action == null) {
      return null;
    }
    return () => unawaited(Future.sync(action));
  }

  static VoidCallback? _wrapPaletteSelection(
    MenuPaletteAction? action,
    String paletteId,
  ) {
    if (action == null) {
      return null;
    }
    return () => unawaited(Future.sync(() => action(paletteId)));
  }

  static PlatformMenu _applicationMenu(MenuActionHandler handler) {
    final List<PlatformMenuItem> menus = <PlatformMenuItem>[];

    final aboutAction = _wrap(handler.about);
    if (aboutAction != null) {
      menus.add(
        PlatformMenuItem(label: '关于 Misa Rin', onSelected: aboutAction),
      );
    }

    final preferencesAction = _wrap(handler.preferences);
    if (preferencesAction != null) {
      menus.add(
        PlatformMenuItemGroup(
          members: <PlatformMenuItem>[
            PlatformMenuItem(
              label: '偏好设置…',
              onSelected: preferencesAction,
              shortcut: const SingleActivator(
                LogicalKeyboardKey.comma,
                meta: true,
              ),
            ),
          ],
        ),
      );
    }

    menus.add(
      PlatformMenuItemGroup(
        members: const <PlatformMenuItem>[
          PlatformProvidedMenuItem(
            type: PlatformProvidedMenuItemType.servicesSubmenu,
          ),
        ],
      ),
    );

    menus.add(
      PlatformMenuItemGroup(
        members: const <PlatformMenuItem>[
          PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hide),
          PlatformProvidedMenuItem(
            type: PlatformProvidedMenuItemType.hideOtherApplications,
          ),
          PlatformProvidedMenuItem(
            type: PlatformProvidedMenuItemType.showAllApplications,
          ),
        ],
      ),
    );

    menus.add(
      PlatformMenuItemGroup(
        members: const <PlatformMenuItem>[
          PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
        ],
      ),
    );

    return PlatformMenu(label: 'Misa Rin', menus: menus);
  }

  static PlatformMenu? _fileMenu(MenuActionHandler handler) {
    final List<PlatformMenuItem> menus = <PlatformMenuItem>[];

    final List<PlatformMenuItem> creationItems = <PlatformMenuItem>[];
    final newProjectAction = _wrap(handler.newProject);
    if (newProjectAction != null) {
      creationItems.add(
        PlatformMenuItem(
          label: '新建…',
          onSelected: newProjectAction,
          shortcut: const SingleActivator(LogicalKeyboardKey.keyN, meta: true),
        ),
      );
    }
    final openAction = _wrap(handler.open);
    if (openAction != null) {
      creationItems.add(
        PlatformMenuItem(
          label: '打开…',
          onSelected: openAction,
          shortcut: const SingleActivator(LogicalKeyboardKey.keyO, meta: true),
        ),
      );
    }
    final importImageAction = _wrap(handler.importImage);
    if (importImageAction != null) {
      creationItems.add(
        PlatformMenuItem(
          label: '导入图像…',
          onSelected: importImageAction,
          shortcut: const SingleActivator(LogicalKeyboardKey.keyI, meta: true),
        ),
      );
    }
    final importClipboardAction = _wrap(handler.importImageFromClipboard);
    if (importClipboardAction != null) {
      creationItems.add(
        PlatformMenuItem(label: '从剪贴板导入图像', onSelected: importClipboardAction),
      );
    }
    if (creationItems.isNotEmpty) {
      menus.add(PlatformMenuItemGroup(members: creationItems));
    }

    final List<PlatformMenuItem> saveItems = <PlatformMenuItem>[];
    final saveAction = _wrap(handler.save);
    if (saveAction != null) {
      saveItems.add(
        PlatformMenuItem(
          label: '保存',
          onSelected: saveAction,
          shortcut: const SingleActivator(LogicalKeyboardKey.keyS, meta: true),
        ),
      );
    }
    final saveAsAction = _wrap(handler.saveAs);
    if (saveAsAction != null) {
      saveItems.add(
        PlatformMenuItem(
          label: '另存为…',
          onSelected: saveAsAction,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyS,
            meta: true,
            shift: true,
          ),
        ),
      );
    }
    final exportAction = _wrap(handler.export);
    if (exportAction != null) {
      saveItems.add(
        PlatformMenuItem(
          label: '导出…',
          onSelected: exportAction,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyE,
            meta: true,
            shift: true,
          ),
        ),
      );
    }
    if (saveItems.isNotEmpty) {
      menus.add(PlatformMenuItemGroup(members: saveItems));
    }

    if (menus.isEmpty) {
      return null;
    }

    return PlatformMenu(label: '文件', menus: menus);
  }

  static PlatformMenu? _editMenu(MenuActionHandler handler) {
    final List<PlatformMenuItem> menus = <PlatformMenuItem>[];

    final List<PlatformMenuItem> historyItems = <PlatformMenuItem>[];
    final undoAction = _wrap(handler.undo);
    if (undoAction != null) {
      historyItems.add(
        PlatformMenuItem(
          label: '撤销',
          onSelected: undoAction,
          shortcut: const SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
        ),
      );
    }
    final redoAction = _wrap(handler.redo);
    if (redoAction != null) {
      historyItems.add(
        PlatformMenuItem(
          label: '恢复',
          onSelected: redoAction,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyZ,
            meta: true,
            shift: true,
          ),
        ),
      );
    }
    if (historyItems.isNotEmpty) {
      menus.add(PlatformMenuItemGroup(members: historyItems));
    }

    final List<PlatformMenuItem> clipboardItems = <PlatformMenuItem>[];
    final cutAction = _wrap(handler.cut);
    if (cutAction != null) {
      clipboardItems.add(
        PlatformMenuItem(
          label: '剪切',
          onSelected: cutAction,
          shortcut: const SingleActivator(LogicalKeyboardKey.keyX, meta: true),
        ),
      );
    }
    final copyAction = _wrap(handler.copy);
    if (copyAction != null) {
      clipboardItems.add(
        PlatformMenuItem(
          label: '复制',
          onSelected: copyAction,
          shortcut: const SingleActivator(LogicalKeyboardKey.keyC, meta: true),
        ),
      );
    }
    final pasteAction = _wrap(handler.paste);
    if (pasteAction != null) {
      clipboardItems.add(
        PlatformMenuItem(
          label: '粘贴',
          onSelected: pasteAction,
          shortcut: const SingleActivator(LogicalKeyboardKey.keyV, meta: true),
        ),
      );
    }
    if (clipboardItems.isNotEmpty) {
      menus.add(PlatformMenuItemGroup(members: clipboardItems));
    }

    if (menus.isEmpty) {
      return null;
    }

    return PlatformMenu(label: '编辑', menus: menus);
  }

  static PlatformMenu? _imageMenu(MenuActionHandler handler) {
    final List<PlatformMenuItem> menus = <PlatformMenuItem>[];

    final List<PlatformMenuItem> transformItems = <PlatformMenuItem>[];

    final rotate90CW = _wrap(handler.rotateCanvas90Clockwise);
    if (rotate90CW != null) {
      transformItems.add(
        PlatformMenuItem(label: '顺时针 90 度', onSelected: rotate90CW),
      );
    }
    final rotate90CCW = _wrap(handler.rotateCanvas90CounterClockwise);
    if (rotate90CCW != null) {
      transformItems.add(
        PlatformMenuItem(label: '逆时针 90 度', onSelected: rotate90CCW),
      );
    }
    final rotate180CW = _wrap(handler.rotateCanvas180Clockwise);
    if (rotate180CW != null) {
      transformItems.add(
        PlatformMenuItem(label: '顺时针 180 度', onSelected: rotate180CW),
      );
    }
    final rotate180CCW = _wrap(handler.rotateCanvas180CounterClockwise);
    if (rotate180CCW != null) {
      transformItems.add(
        PlatformMenuItem(label: '逆时针 180 度', onSelected: rotate180CCW),
      );
    }
    if (transformItems.isNotEmpty) {
      menus.add(PlatformMenu(label: '图像变换', menus: transformItems));
    }

    final List<PlatformMenuItem> sizeItems = <PlatformMenuItem>[];
    final resizeImageAction = _wrap(handler.resizeImage);
    if (resizeImageAction != null) {
      sizeItems.add(
        PlatformMenuItem(
          label: '图像大小…',
          onSelected: resizeImageAction,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyI,
            meta: true,
            alt: true,
          ),
        ),
      );
    }
    final resizeCanvasAction = _wrap(handler.resizeCanvas);
    if (resizeCanvasAction != null) {
      sizeItems.add(
        PlatformMenuItem(
          label: '画布大小…',
          onSelected: resizeCanvasAction,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyC,
            meta: true,
            alt: true,
          ),
        ),
      );
    }
    if (sizeItems.isNotEmpty) {
      menus.add(PlatformMenuItemGroup(members: sizeItems));
    }

    if (menus.isEmpty) {
      return null;
    }

    return PlatformMenu(label: '图像', menus: menus);
  }

  static PlatformMenu? _layerMenu(MenuActionHandler handler) {
    final List<PlatformMenuItem> menus = <PlatformMenuItem>[];

    final newLayerAction = _wrap(handler.newLayer);
    if (newLayerAction != null) {
      menus.add(
        PlatformMenu(
          label: '新建',
          menus: <PlatformMenuItem>[
            PlatformMenuItem(
              label: '图层…',
              onSelected: newLayerAction,
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyN,
                meta: true,
                shift: true,
              ),
            ),
          ],
        ),
      );
    }

    final List<PlatformMenuItem> antialiasItems = <PlatformMenuItem>[];
    final aa0 = _wrap(handler.applyLayerAntialias0);
    if (aa0 != null) {
      antialiasItems.add(PlatformMenuItem(label: '0', onSelected: aa0));
    }
    final aa1 = _wrap(handler.applyLayerAntialias1);
    if (aa1 != null) {
      antialiasItems.add(PlatformMenuItem(label: '1', onSelected: aa1));
    }
    final aa2 = _wrap(handler.applyLayerAntialias2);
    if (aa2 != null) {
      antialiasItems.add(PlatformMenuItem(label: '2', onSelected: aa2));
    }
    final aa3 = _wrap(handler.applyLayerAntialias3);
    if (aa3 != null) {
      antialiasItems.add(PlatformMenuItem(label: '3', onSelected: aa3));
    }
    if (antialiasItems.isNotEmpty) {
      menus.add(PlatformMenu(label: '抗锯齿', menus: antialiasItems));
    }

    final mergeLayerDownAction = _wrap(handler.mergeLayerDown);
    if (mergeLayerDownAction != null) {
      menus.add(
        PlatformMenuItem(label: '向下合并', onSelected: mergeLayerDownAction),
      );
    }

    if (menus.isEmpty) {
      return null;
    }

    return PlatformMenu(label: '图层', menus: menus);
  }

  static PlatformMenu? _toolMenu(MenuActionHandler handler) {
    final List<PlatformMenuItem> menus = <PlatformMenuItem>[];

    final List<PlatformMenuItem> paletteMenus = <PlatformMenuItem>[];
    final List<PlatformMenuItem> paletteActions = <PlatformMenuItem>[];

    final generatePaletteAction = _wrap(handler.generatePalette);
    if (generatePaletteAction != null) {
      paletteActions.add(
        PlatformMenuItem(label: '生成调色盘…', onSelected: generatePaletteAction),
      );
    }
    final importPaletteAction = _wrap(handler.importPalette);
    if (importPaletteAction != null) {
      paletteActions.add(
        PlatformMenuItem(label: '导入调色盘…', onSelected: importPaletteAction),
      );
    }
    if (paletteActions.isNotEmpty) {
      paletteMenus.add(PlatformMenuItemGroup(members: paletteActions));
    }

    if (handler.paletteMenuEntries.isNotEmpty &&
        handler.selectPaletteFromMenu != null) {
      final List<PlatformMenuItem> paletteLibraryItems = handler
          .paletteMenuEntries
          .map((entry) {
            return PlatformMenuItem(
              label: entry.label,
              onSelected: _wrapPaletteSelection(
                handler.selectPaletteFromMenu,
                entry.id,
              ),
            );
          })
          .toList(growable: false);
      if (paletteLibraryItems.isNotEmpty) {
        paletteMenus.add(PlatformMenuItemGroup(members: paletteLibraryItems));
      }
    }
    if (paletteMenus.isNotEmpty) {
      menus.add(PlatformMenu(label: '调色盘', menus: paletteMenus));
    }

    if (menus.isEmpty) {
      return null;
    }

    return PlatformMenu(label: '工具', menus: menus);
  }

  static PlatformMenu? _viewMenu(MenuActionHandler handler) {
    final List<PlatformMenuItem> menus = <PlatformMenuItem>[];

    final zoomInAction = _wrap(handler.zoomIn);
    if (zoomInAction != null) {
      menus.add(
        PlatformMenuItem(
          label: '放大',
          onSelected: zoomInAction,
          shortcut: const SingleActivator(LogicalKeyboardKey.equal, meta: true),
        ),
      );
    }
    final zoomOutAction = _wrap(handler.zoomOut);
    if (zoomOutAction != null) {
      menus.add(
        PlatformMenuItem(
          label: '缩小',
          onSelected: zoomOutAction,
          shortcut: const SingleActivator(LogicalKeyboardKey.minus, meta: true),
        ),
      );
    }

    if (menus.isEmpty) {
      return null;
    }

    return PlatformMenu(label: '视图', menus: menus);
  }

  static PlatformMenu _windowMenu() {
    return PlatformMenu(
      label: '窗口',
      menus: <PlatformMenuItem>[
        PlatformMenuItemGroup(
          members: const <PlatformMenuItem>[
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.minimizeWindow,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.zoomWindow,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.arrangeWindowsInFront,
            ),
          ],
        ),
      ],
    );
  }

  static PlatformMenu? _filterMenu(MenuActionHandler handler) {
    final List<PlatformMenuItem> items = <PlatformMenuItem>[];
    final hueSatAction = _wrap(handler.adjustHueSaturation);
    if (hueSatAction != null) {
      items.add(PlatformMenuItem(label: '色相/饱和度…', onSelected: hueSatAction));
    }
    final brightnessContrastAction = _wrap(handler.adjustBrightnessContrast);
    if (brightnessContrastAction != null) {
      items.add(
        PlatformMenuItem(
          label: '亮度/对比度…',
          onSelected: brightnessContrastAction,
        ),
      );
    }
    if (items.isEmpty) {
      return null;
    }
    return PlatformMenu(
      label: '滤镜',
      menus: <PlatformMenuItem>[PlatformMenuItemGroup(members: items)],
    );
  }
}
