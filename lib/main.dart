import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/menu/custom_menu_shell.dart';
import 'app/menu/macos_menu_shell.dart';
import 'app/preferences/app_preferences.dart';
import 'app/utils/tablet_input_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  TabletInputBridge.instance.ensureInitialized();

  await AppPreferences.load();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: true,
      backgroundColor: Color(0x00000000),
      skipTaskbar: false,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.maximize();
      await windowManager.show();
      await windowManager.focus();
    });
  }

  const app = MisarinApp();

  if (!kIsWeb && Platform.isMacOS) {
    runApp(const MacosMenuShell(child: app));
    return;
  }

  final bool needsCustomMenu =
      kIsWeb || (!kIsWeb && (Platform.isWindows || Platform.isLinux));

  if (needsCustomMenu) {
    runApp(const CustomMenuShell(child: app));
    return;
  }

  runApp(app);
}
