import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_performance_pulse/flutter_performance_pulse.dart';
import 'package:misa_rin/l10n/app_localizations.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/l10n/l10n.dart';
import 'app/preferences/app_preferences.dart';
import 'app/utils/tablet_input_bridge.dart';
import 'src/rust/rust_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  TabletInputBridge.instance.ensureInitialized();

  try {
    await ensureRustInitialized();
  } catch (error, stackTrace) {
    debugPrint('RustLib.init failed: $error\n$stackTrace');
  }

  final Future<void> preloadFuture = _preloadCoreServices();

  if (kIsWeb) {
    runApp(const _MisarinWebLoadingApp());
  }

  await preloadFuture;

  await _initializeDesktopWindowIfNeeded();

  final bool showCustomMenu =
      kIsWeb || (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS));
  final bool showCustomMenuItems =
      kIsWeb || (!kIsWeb && (Platform.isWindows || Platform.isLinux));
  final app = MisarinApp(
    showCustomMenu: showCustomMenu,
    showCustomMenuItems: showCustomMenuItems,
  );

  runApp(app);
}

Future<void> _preloadCoreServices() async {
  await AppPreferences.load();
  if (!kIsWeb) {
    await _initializePerformancePulse();
  }
}

Future<void> _initializeDesktopWindowIfNeeded() async {
  final bool isDesktop =
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  if (!isDesktop) {
    return;
  }
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

Future<void> _initializePerformancePulse() async {
  try {
    await PerformanceMonitor.instance.initialize(
      config: MonitorConfig(
        showMemory: true,
        showLogs: true,
        trackStartup: true,
        interceptNetwork: true,
        fpsWarningThreshold: 45,
        memoryWarningThreshold: 500 * 1024 * 1024,
        diskWarningThreshold: 85.0,
        enableNetworkMonitoring: true,
        enableBatteryMonitoring: true,
        enableDeviceInfo: true,
        enableDiskMonitoring: true,
        logLevel: LogLevel.info,
        exportLogs: false,
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('Performance monitor init failed: $error\n$stackTrace');
  }
}

class _MisarinWebLoadingApp extends StatelessWidget {
  const _MisarinWebLoadingApp();

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      debugShowCheckedModeBanner: false,
      title: 'Misa Rin',
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        ...AppLocalizations.localizationsDelegates,
        FluentLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _MisarinWebLoadingScreen(),
      theme: FluentThemeData(
        brightness: Brightness.dark,
        accentColor: Colors.white.toAccentColor(),
      ),
    );
  }
}

class _MisarinWebLoadingScreen extends StatelessWidget {
  const _MisarinWebLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final l10n = context.l10n;
    return Container(
      color: theme.micaBackgroundColor,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ProgressBar(),
              const SizedBox(height: 16),
              Text(
                l10n.webLoadingInitializingCanvas,
                style: theme.typography.subtitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Opacity(
                opacity: 0.75,
                child: Text(
                  l10n.webLoadingMayTakeTime,
                  style: theme.typography.body,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
