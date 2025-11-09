import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/widgets.dart';

import 'menu/custom_menu_shell.dart';
import 'preferences/app_preferences.dart';
import 'theme/theme_controller.dart';
import 'view/home_page.dart';

class MisarinApp extends StatefulWidget {
  const MisarinApp({super.key, this.showCustomMenu = false});

  final bool showCustomMenu;

  @override
  State<MisarinApp> createState() => _MisarinAppState();
}

class _MisarinAppState extends State<MisarinApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = AppPreferences.instance.themeMode;
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
          if (!widget.showCustomMenu || child == null) {
            return child ?? const SizedBox.shrink();
          }
          return CustomMenuShell(child: child, navigatorKey: _navigatorKey);
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
