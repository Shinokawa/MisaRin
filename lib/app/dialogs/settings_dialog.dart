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
  late bool _stylusPressureEnabled;
  late double _stylusMinFactor;
  late double _stylusMaxFactor;
  late double _stylusCurve;

  @override
  void initState() {
    super.initState();
    _historyLimit = AppPreferences.instance.historyLimit;
    _stylusPressureEnabled = AppPreferences.instance.stylusPressureEnabled;
    _stylusMinFactor = AppPreferences.instance.stylusPressureMinFactor;
    _stylusMaxFactor = AppPreferences.instance.stylusPressureMaxFactor;
    _stylusCurve = AppPreferences.instance.stylusPressureCurve;
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
          label: '数位笔压设置',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('启用数位笔笔压'),
                  const SizedBox(width: 12),
                  ToggleSwitch(
                    checked: _stylusPressureEnabled,
                    onChanged: (value) {
                      setState(() => _stylusPressureEnabled = value);
                      final AppPreferences prefs = AppPreferences.instance;
                      prefs.stylusPressureEnabled = value;
                      unawaited(AppPreferences.save());
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StylusSliderTile(
                label: '最细倍数',
                description: '控制笔压最轻时笔刷半径与基础半径的倍数。',
                value: _stylusMinFactor,
                min: AppPreferences.stylusMinFactorLowerBound,
                max: AppPreferences.stylusMinFactorUpperBound,
                enabled: _stylusPressureEnabled,
                onChanged: (value) {
                  setState(() {
                    _stylusMinFactor = value;
                    if (_stylusMaxFactor <= _stylusMinFactor) {
                      _stylusMaxFactor = (_stylusMinFactor + 0.01)
                          .clamp(
                            AppPreferences.stylusMaxFactorLowerBound,
                            AppPreferences.stylusMaxFactorUpperBound,
                          );
                    }
                  });
                  final AppPreferences prefs = AppPreferences.instance;
                  prefs.stylusPressureMinFactor = _stylusMinFactor;
                  prefs.stylusPressureMaxFactor = _stylusMaxFactor;
                  unawaited(AppPreferences.save());
                },
              ),
              const SizedBox(height: 12),
              _StylusSliderTile(
                label: '最粗倍数',
                description: '控制笔压最重时笔刷半径与基础半径的倍数。',
                value: _stylusMaxFactor,
                min: AppPreferences.stylusMaxFactorLowerBound,
                max: AppPreferences.stylusMaxFactorUpperBound,
                enabled: _stylusPressureEnabled,
                onChanged: (value) {
                  setState(() => _stylusMaxFactor = value);
                  final AppPreferences prefs = AppPreferences.instance;
                  prefs.stylusPressureMaxFactor = _stylusMaxFactor;
                  unawaited(AppPreferences.save());
                },
              ),
              const SizedBox(height: 12),
              _StylusSliderTile(
                label: '响应曲线',
                description: '调整压力与笔触粗细之间的过渡速度。',
                value: _stylusCurve,
                min: AppPreferences.stylusCurveLowerBound,
                max: AppPreferences.stylusCurveUpperBound,
                enabled: _stylusPressureEnabled,
                asMultiplier: false,
                onChanged: (value) {
                  setState(() => _stylusCurve = value);
                  final AppPreferences prefs = AppPreferences.instance;
                  prefs.stylusPressureCurve = _stylusCurve;
                  unawaited(AppPreferences.save());
                },
              ),
            ],
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
      _stylusPressureEnabled = AppPreferences.defaultStylusPressureEnabled;
      _stylusMinFactor = AppPreferences.defaultStylusMinFactor;
      _stylusMaxFactor = AppPreferences.defaultStylusMaxFactor;
      _stylusCurve = AppPreferences.defaultStylusCurve;
    });
    prefs.historyLimit = defaultHistory;
    prefs.themeMode = defaultTheme;
    prefs.stylusPressureEnabled = _stylusPressureEnabled;
    prefs.stylusPressureMinFactor = _stylusMinFactor;
    prefs.stylusPressureMaxFactor = _stylusMaxFactor;
    prefs.stylusPressureCurve = _stylusCurve;
    unawaited(AppPreferences.save());
  }
}

class _StylusSliderTile extends StatelessWidget {
  const _StylusSliderTile({
    required this.label,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
    this.asMultiplier = true,
  });

  final String label;
  final String description;
  final double value;
  final double min;
  final double max;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final bool asMultiplier;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final double clampedValue = value.clamp(min, max);
    final Widget slider = Slider(
      value: clampedValue,
      min: min,
      max: max,
      divisions: 100,
      onChanged: enabled ? onChanged : null,
    );

    final String valueLabel = asMultiplier
        ? '${clampedValue.toStringAsFixed(2)}x'
        : clampedValue.toStringAsFixed(2);

    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label：$valueLabel', style: theme.typography.bodyStrong),
          slider,
          Text(description, style: theme.typography.caption),
        ],
      ),
    );
  }
}
