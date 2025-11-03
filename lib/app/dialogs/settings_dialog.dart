import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/widgets.dart' show GlobalKey;

import '../theme/theme_controller.dart';
import '../preferences/app_preferences.dart';
import 'misarin_dialog.dart';

Future<void> showSettingsDialog(BuildContext context) {
  final GlobalKey<_SettingsDialogContentState> contentKey =
      GlobalKey<_SettingsDialogContentState>();
  return showMisarinDialog<void>(
    context: context,
    title: const Text('设置'),
    content: _SettingsDialogContent(key: contentKey),
    contentWidth: 420,
    maxWidth: 520,
    actions: [
      Button(
        onPressed: () => contentKey.currentState?.resetToDefaults(),
        child: const Text('恢复默认'),
      ),
      Button(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('好的'),
      ),
    ],
  );
}

class _SettingsDialogContent extends StatefulWidget {
  const _SettingsDialogContent({super.key});

  @override
  State<_SettingsDialogContent> createState() => _SettingsDialogContentState();
}

class _SettingsDialogContentState extends State<_SettingsDialogContent> {
  late int _historyLimit;

  @override
  void initState() {
    super.initState();
    _historyLimit = AppPreferences.instance.historyLimit;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final ThemeController controller = ThemeController.of(context);
    final ThemeMode themeMode = controller.themeMode;
    final int minHistory = AppPreferences.minHistoryLimit;
    final int maxHistory = AppPreferences.maxHistoryLimit;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoLabel(
          label: '主题模式',
          child: ComboBox<ThemeMode>(
            isExpanded: true,
            value: themeMode,
            items: const [
              ComboBoxItem(
                value: ThemeMode.light,
                child: Text('浅色'),
              ),
              ComboBoxItem(
                value: ThemeMode.dark,
                child: Text('深色'),
              ),
              ComboBoxItem(
                value: ThemeMode.system,
                child: Text('跟随系统'),
              ),
            ],
            onChanged: (mode) {
              if (mode == null) {
                return;
              }
              controller.onThemeModeChanged(mode);
              final AppPreferences prefs = AppPreferences.instance;
              if (prefs.themeMode != mode) {
                prefs.themeMode = mode;
                unawaited(AppPreferences.save());
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        InfoLabel(
          label: '撤销/恢复步数上限',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Slider(
                value: _historyLimit.toDouble(),
                min: minHistory.toDouble(),
                max: maxHistory.toDouble(),
                divisions: maxHistory - minHistory,
                onChanged: (value) {
                  final int rounded = value.round().clamp(
                    minHistory,
                    maxHistory,
                  );
                  if (rounded == _historyLimit) {
                    return;
                  }
                  setState(() => _historyLimit = rounded);
                  final AppPreferences prefs = AppPreferences.instance;
                  prefs.historyLimit = rounded;
                  unawaited(AppPreferences.save());
                },
              ),
              Text(
                '当前上限：$_historyLimit 步',
                style: theme.typography.caption,
              ),
              Text(
                '调整撤销/恢复历史的保存数量，范围 $minHistory-$maxHistory。',
                style: theme.typography.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void resetToDefaults() {
    final ThemeController controller = ThemeController.of(context);
    final AppPreferences prefs = AppPreferences.instance;
    final int defaultHistory = AppPreferences.defaultHistoryLimit;
    final ThemeMode defaultTheme = AppPreferences.defaultThemeMode;
    controller.onThemeModeChanged(defaultTheme);
    setState(() {
      _historyLimit = defaultHistory;
    });
    prefs.historyLimit = defaultHistory;
    prefs.themeMode = defaultTheme;
    unawaited(AppPreferences.save());
  }
}
