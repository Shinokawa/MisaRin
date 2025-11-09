import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/menu/macos_menu_shell.dart';
import 'app/preferences/app_preferences.dart';
import 'app/utils/tablet_input_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  TabletInputBridge.instance.ensureInitialized();

  await AppPreferences.load();

  final bool isDesktop =
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  if (isDesktop) {
    await windowManager.ensureInitialized();

    final bool isWindowsDesktop = !kIsWeb && Platform.isWindows;
    final Color windowBackgroundColor = isWindowsDesktop
        ? const Color(0xFF0F0F0F)
        : const Color(0x00000000);
    if (isWindowsDesktop) {
      await windowManager.setBackgroundColor(windowBackgroundColor);
    }

    final windowOptions = WindowOptions(
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: true,
      backgroundColor: windowBackgroundColor,
      skipTaskbar: false,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.maximize();
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final bool needsCustomMenu =
      kIsWeb || (!kIsWeb && (Platform.isWindows || Platform.isLinux));
  final app = MisarinApp(showCustomMenu: needsCustomMenu);

  if (!kIsWeb && Platform.isMacOS) {
    runApp(MacosMenuShell(child: app));
    return;
  }

  runApp(app);
}
