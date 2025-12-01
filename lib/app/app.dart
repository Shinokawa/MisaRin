import 'dart:async';
import 'dart:io' show Platform;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';

import 'dialogs/misarin_dialog.dart';
import 'menu/custom_menu_shell.dart';
import 'preferences/app_preferences.dart';
import 'theme/theme_controller.dart';
import 'view/home_page.dart';
import 'widgets/performance_pulse_overlay.dart';
import 'workspace/canvas_workspace_controller.dart';

class MisarinApp extends StatefulWidget {
  const MisarinApp({
    super.key,
    this.showCustomMenu = false,
    this.showCustomMenuItems = true,
  });

  final bool showCustomMenu;
  final bool showCustomMenuItems;

  @override
  State<MisarinApp> createState() => _MisarinAppState();
}

class _MisarinAppState extends State<MisarinApp> with WindowListener {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late ThemeMode _themeMode;
  bool _windowListenerAttached = false;

  @override
  void initState() {
    super.initState();
    _themeMode = AppPreferences.instance.themeMode;
    _initWindowCloseHandler();
  }

  void _handleThemeModeChanged(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }
    setState(() => _themeMode = mode);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.themeMode = mode;
    unawaited(AppPreferences.save());
  }

  void _initWindowCloseHandler() {
    if (!_supportsDesktopWindowManagement) {
      return;
    }
    windowManager.addListener(this);
    _windowListenerAttached = true;
    unawaited(windowManager.setPreventClose(true));
  }

  bool get _supportsDesktopWindowManagement =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  void dispose() {
    if (_windowListenerAttached) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() {
    if (!_windowListenerAttached) {
      return;
    }
    unawaited(_handleWindowCloseRequest());
  }

  Future<void> _handleWindowCloseRequest() async {
    if (!mounted) {
      await windowManager.destroy();
      return;
    }
    final bool isPreventClose = await windowManager.isPreventClose();
    if (!isPreventClose) {
      await windowManager.destroy();
      return;
    }
    final bool canClose = await _confirmDiscardUnsavedProjects();
    if (canClose) {
      await windowManager.destroy();
    }
  }

  Future<bool> _confirmDiscardUnsavedProjects() async {
    final CanvasWorkspaceController workspace =
        CanvasWorkspaceController.instance;
    final List<CanvasWorkspaceEntry> entries = workspace.entries;
    final Iterable<CanvasWorkspaceEntry> dirtyEntries = entries.where(
      (entry) => entry.isDirty,
    );
    if (entries.isEmpty || dirtyEntries.isEmpty) {
      return true;
    }
    final BuildContext? context = _navigatorKey.currentContext;
    if (context == null) {
      return true;
    }
    final int unsavedCount = dirtyEntries.length;
    final bool? discard = await showMisarinDialog<bool>(
      context: context,
      barrierDismissible: false,
      title: const Text('关闭应用'),
      content: Text(
        unsavedCount == 1
            ? '检测到 1 个未保存的项目。如果现在退出，最近的修改将会丢失。'
            : '检测到 $unsavedCount 个未保存的项目。如果现在退出，最近的修改将会丢失。',
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('丢弃并退出'),
        ),
      ],
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    return ThemeController(
      themeMode: _themeMode,
      onThemeModeChanged: _handleThemeModeChanged,
      child: FluentApp(
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Misa Rin',
        builder: (context, child) {
          Widget content = child ?? const SizedBox.shrink();
          if (widget.showCustomMenu && child != null) {
            content = CustomMenuShell(
              navigatorKey: _navigatorKey,
              showMenus: widget.showCustomMenuItems,
              child: child,
            );
          }
          return ValueListenableBuilder<bool>(
            valueListenable: AppPreferences.fpsOverlayEnabledNotifier,
            builder: (context, enabled, appChild) {
              final Widget resolvedChild = appChild ?? const SizedBox.shrink();
              if (!enabled) {
                return resolvedChild;
              }
              return Stack(
                fit: StackFit.passthrough,
                children: [resolvedChild, const PerformancePulseOverlay()],
              );
            },
            child: content,
          );
        },
        theme: FluentThemeData(
          brightness: Brightness.light,
          accentColor: Colors.black.toAccentColor(),
        ),
        darkTheme: FluentThemeData(
          brightness: Brightness.dark,
          accentColor: Colors.white.toAccentColor(),
        ),
        themeMode: _themeMode,
        home: const MisarinHomePage(),
      ),
    );
  }
}
