import 'package:fluent_ui/fluent_ui.dart';

import 'theme/theme_controller.dart';
import 'view/home_page.dart';

class MisarinApp extends StatefulWidget {
  const MisarinApp({super.key});

  @override
  State<MisarinApp> createState() => _MisarinAppState();
}

class _MisarinAppState extends State<MisarinApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _handleThemeModeChanged(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return ThemeController(
      themeMode: _themeMode,
      onThemeModeChanged: _handleThemeModeChanged,
      child: FluentApp(
        debugShowCheckedModeBanner: false,
        title: 'misa rin',
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
