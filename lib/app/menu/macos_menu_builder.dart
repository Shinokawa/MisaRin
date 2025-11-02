import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'menu_action_dispatcher.dart';

typedef MenuLogger = void Function(String entry);

class MacosMenuBuilder {
  const MacosMenuBuilder._();

  static List<PlatformMenu> build(
    MenuActionHandler handler, {
    MenuLogger? onLog,
  }) {
    final log = onLog ?? _defaultLogger;
    return <PlatformMenu>[
      _applicationMenu(handler, log),
      _fileMenu(handler, log),
      _editMenu(handler, log),
      _imageMenu(log),
      _layerMenu(log),
      _selectMenu(log),
      _filterMenu(log),
      _viewMenu(handler, log),
      _windowMenu(log),
      _helpMenu(log),
    ];
  }

  static VoidCallback? _wrap(MenuAsyncAction? action) {
    if (action == null) {
      return null;
    }
    return () => unawaited(Future.sync(action));
  }

  static VoidCallback _placeholder(String label, MenuLogger log) {
    return () => log('macOS 菜单占位触发：$label');
  }

  static void _defaultLogger(String entry) {
    debugPrint(entry);
  }

  static PlatformMenu _applicationMenu(
    MenuActionHandler handler,
    MenuLogger log,
  ) {
    return PlatformMenu(
      label: 'Misa Rin',
      menus: <PlatformMenuItem>[
        PlatformMenuItem(
          label: '关于 Misa Rin',
          onSelected:
              _wrap(handler.about) ?? _placeholder('应用 > 关于 Misa Rin', log),
        ),
        PlatformMenuItemGroup(
          members: <PlatformMenuItem>[
            PlatformMenuItem(
              label: '偏好设置…',
              onSelected:
                  _wrap(handler.preferences) ?? _placeholder('偏好设置…', log),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.comma,
                meta: true,
              ),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: const <PlatformMenuItem>[
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.servicesSubmenu,
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: <PlatformMenuItem>[
            PlatformMenuItem(
              label: '隐藏 Misa Rin',
              onSelected: _placeholder('隐藏 Misa Rin', log),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyH,
                meta: true,
              ),
            ),
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.hideOtherApplications,
            ),
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.showAllApplications,
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: const <PlatformMenuItem>[
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
          ],
        ),
      ],
    );
  }

  static PlatformMenu _fileMenu(MenuActionHandler handler, MenuLogger log) {
    return PlatformMenu(
      label: '文件',
      menus: <PlatformMenuItem>[
        PlatformMenuItemGroup(
          members: <PlatformMenuItem>[
            PlatformMenuItem(
              label: '新建…',
              onSelected:
                  _wrap(handler.newProject) ?? _placeholder('文件 > 新建…', log),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyN,
                meta: true,
              ),
            ),
            PlatformMenuItem(
              label: '打开…',
              onSelected: _placeholder('文件 > 打开…', log),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyO,
                meta: true,
              ),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: <PlatformMenuItem>[
            PlatformMenuItem(
              label: '保存',
              onSelected: _wrap(handler.save) ?? _placeholder('文件 > 保存', log),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyS,
                meta: true,
              ),
            ),
            PlatformMenuItem(
              label: '另存为…',
              onSelected: _placeholder('文件 > 另存为…', log),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyS,
                meta: true,
                shift: true,
              ),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: <PlatformMenuItem>[
            PlatformMenuItem(
              label: '关闭',
              onSelected: _placeholder('文件 > 关闭', log),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyW,
                meta: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static PlatformMenu _editMenu(MenuActionHandler handler, MenuLogger log) {
    return PlatformMenu(
      label: '编辑',
      menus: <PlatformMenuItem>[
        PlatformMenuItemGroup(
          members: <PlatformMenuItem>[
            PlatformMenuItem(
              label: '撤销',
              onSelected: _wrap(handler.undo) ?? _placeholder('编辑 > 撤销', log),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyZ,
                meta: true,
              ),
            ),
            PlatformMenuItem(
              label: '恢复',
              onSelected: _wrap(handler.redo) ?? _placeholder('编辑 > 恢复', log),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyZ,
                meta: true,
                shift: true,
              ),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: <PlatformMenuItem>[
            PlatformMenuItem(
              label: '剪切',
              onSelected: _placeholder('编辑 > 剪切', log),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyX,
                meta: true,
              ),
            ),
            PlatformMenuItem(
              label: '复制',
              onSelected: _placeholder('编辑 > 复制', log),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyC,
                meta: true,
              ),
            ),
            PlatformMenuItem(
              label: '粘贴',
              onSelected: _placeholder('编辑 > 粘贴', log),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyV,
                meta: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static PlatformMenu _imageMenu(MenuLogger log) {
    return PlatformMenu(
      label: '图像',
      menus: <PlatformMenuItem>[
        PlatformMenuItem(
          label: '模式 > RGB 颜色',
          onSelected: _placeholder('图像 > 模式 > RGB 颜色', log),
        ),
        PlatformMenuItem(
          label: '调整 > 色阶…',
          onSelected: _placeholder('图像 > 调整 > 色阶…', log),
          shortcut: const SingleActivator(LogicalKeyboardKey.keyL, meta: true),
        ),
      ],
    );
  }

  static PlatformMenu _layerMenu(MenuLogger log) {
    return PlatformMenu(
      label: '图层',
      menus: <PlatformMenuItem>[
        PlatformMenuItem(
          label: '新建 > 图层…',
          onSelected: _placeholder('图层 > 新建 > 图层…', log),
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyN,
            meta: true,
            shift: true,
          ),
        ),
        PlatformMenuItem(
          label: '复制图层…',
          onSelected: _placeholder('图层 > 复制图层…', log),
        ),
      ],
    );
  }

  static PlatformMenu _selectMenu(MenuLogger log) {
    return PlatformMenu(
      label: '选择',
      menus: <PlatformMenuItem>[
        PlatformMenuItem(
          label: '全选',
          onSelected: _placeholder('选择 > 全选', log),
          shortcut: const SingleActivator(LogicalKeyboardKey.keyA, meta: true),
        ),
        PlatformMenuItem(
          label: '取消选择',
          onSelected: _placeholder('选择 > 取消选择', log),
          shortcut: const SingleActivator(LogicalKeyboardKey.keyD, meta: true),
        ),
      ],
    );
  }

  static PlatformMenu _filterMenu(MenuLogger log) {
    return PlatformMenu(
      label: '滤镜',
      menus: <PlatformMenuItem>[
        PlatformMenuItem(
          label: '转换为智能滤镜…',
          onSelected: _placeholder('滤镜 > 转换为智能滤镜…', log),
        ),
        PlatformMenuItem(
          label: 'Camera Raw 滤镜…',
          onSelected: _placeholder('滤镜 > Camera Raw 滤镜…', log),
        ),
      ],
    );
  }

  static PlatformMenu _viewMenu(MenuActionHandler handler, MenuLogger log) {
    return PlatformMenu(
      label: '视图',
      menus: <PlatformMenuItem>[
        PlatformMenuItem(
          label: '放大',
          onSelected: _wrap(handler.zoomIn) ?? _placeholder('视图 > 放大', log),
          shortcut: const SingleActivator(LogicalKeyboardKey.equal, meta: true),
        ),
        PlatformMenuItem(
          label: '缩小',
          onSelected: _wrap(handler.zoomOut) ?? _placeholder('视图 > 缩小', log),
          shortcut: const SingleActivator(LogicalKeyboardKey.minus, meta: true),
        ),
        PlatformMenuItem(
          label: '适合屏幕',
          onSelected: _placeholder('视图 > 适合屏幕', log),
          shortcut: const SingleActivator(
            LogicalKeyboardKey.digit0,
            meta: true,
          ),
        ),
      ],
    );
  }

  static PlatformMenu _windowMenu(MenuLogger log) {
    return PlatformMenu(
      label: '窗口',
      menus: <PlatformMenuItem>[
        PlatformMenuItem(label: '排列', onSelected: _placeholder('窗口 > 排列', log)),
        PlatformMenuItem(
          label: '工作区',
          onSelected: _placeholder('窗口 > 工作区', log),
        ),
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

  static PlatformMenu _helpMenu(MenuLogger log) {
    return PlatformMenu(
      label: '帮助',
      menus: <PlatformMenuItem>[
        PlatformMenuItem(
          label: 'Misa Rin 帮助',
          onSelected: _placeholder('帮助 > Misa Rin 帮助', log),
        ),
        PlatformMenuItem(
          label: '系统信息…',
          onSelected: _placeholder('帮助 > 系统信息…', log),
        ),
      ],
    );
  }
}
