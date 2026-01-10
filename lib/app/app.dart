import 'dart:async';
import 'dart:io' show Platform;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';
import 'package:misa_rin/l10n/app_localizations.dart';

import 'dialogs/misarin_dialog.dart';
import 'l10n/locale_controller.dart';
import 'l10n/l10n.dart';
import 'menu/custom_menu_shell.dart';
import 'menu/macos_menu_shell.dart';
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
  late Locale? _locale;
  bool _windowListenerAttached = false;
  bool _closeRequestInProgress = false;

  @override
  void initState() {
    super.initState();
    _themeMode = AppPreferences.instance.themeMode;
    _locale = AppPreferences.instance.localeOverride;
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

  void _handleLocaleChanged(Locale? locale) {
    if (_locale == locale) {
      return;
    }
    setState(() => _locale = locale);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.localeOverride = locale;
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
    if (_closeRequestInProgress) {
      return;
    }
    unawaited(_handleWindowCloseRequest());
  }

  Future<void> _handleWindowCloseRequest() async {
    if (_closeRequestInProgress) {
      return;
    }
    _closeRequestInProgress = true;
    try {
      final bool isPreventClose = await windowManager.isPreventClose();
      if (!isPreventClose) {
        return;
      }
      final bool canClose = mounted ? await _confirmDiscardUnsavedProjects() : true;
      if (!canClose) {
        return;
      }
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } finally {
      _closeRequestInProgress = false;
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
    final l10n = context.l10n;
    final bool? discard = await showMisarinDialog<bool>(
      context: context,
      barrierDismissible: false,
      title: Text(l10n.closeAppTitle),
      content: Text(
        l10n.unsavedProjectsWarning(unsavedCount),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.discardAndExit),
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
	      child: LocaleController(
	        locale: _locale,
	        onLocaleChanged: _handleLocaleChanged,
	        child: FluentApp(
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Misa Rin',
        locale: _locale,
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          ...AppLocalizations.localizationsDelegates,
          FluentLocalizations.delegate,
        ],
	        supportedLocales: AppLocalizations.supportedLocales,
	        builder: (context, child) {
	          Widget content = child ?? const SizedBox.shrink();
	          if (widget.showCustomMenu && child != null) {
	            content = CustomMenuShell(
	              navigatorKey: _navigatorKey,
	              showMenus: widget.showCustomMenuItems,
	              child: child,
	            );
	          }
	          Widget appBody = ValueListenableBuilder<bool>(
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

	          // PlatformMenuBar needs AppLocalizations, so build it inside FluentApp.
	          if (!kIsWeb && Platform.isMacOS) {
	            appBody = MacosMenuShell(child: appBody);
	          }

	          final FluentThemeData theme = FluentTheme.of(context);
	          final Color selectionColor =
	              Color.lerp(
	                theme.resources.controlFillColorInputActive,
	                theme.resources.textFillColorPrimary,
	                0.25,
	              ) ??
	              theme.resources.textFillColorPrimary.withOpacity(0.25);

	          return DefaultSelectionStyle(
	            cursorColor:
	                theme.accentColor.defaultBrushFor(theme.brightness),
	            selectionColor: selectionColor,
	            child: appBody,
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
      ),
    );
  }
}
