import 'dart:async';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

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
        onPressed: () => contentKey.currentState?.openTabletDiagnostic(),
        child: const Text('数位板测试'),
      ),
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

  void openTabletDiagnostic() {
    _showTabletInspectDialog(context);
  }
}

Future<void> _showTabletInspectDialog(BuildContext context) async {
  return showMisarinDialog<void>(
    context: context,
    title: const Text('数位板输入测试'),
    contentWidth: 720,
    maxWidth: 820,
    content: const _TabletInspectPane(),
    actions: [
      Button(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('关闭'),
      ),
    ],
  );
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

class _TabletInspectPane extends StatefulWidget {
  const _TabletInspectPane();

  @override
  State<_TabletInspectPane> createState() => _TabletInspectPaneState();
}

class _TabletInspectPaneState extends State<_TabletInspectPane> {
  final List<_TabletPoint> _points = <_TabletPoint>[];
  double? _latestPressure;
  double? _latestMin;
  double? _latestMax;
  double? _latestRadius;
  double? _latestTilt;
  int _sampleCount = 0;
  DateTime? _lastSample;
  double _estimatedRps = 0;

  void _handlePointer(PointerEvent event) {
    if (event.kind != PointerDeviceKind.stylus &&
        event.kind != PointerDeviceKind.invertedStylus) {
      return;
    }
    final Offset pos = event.localPosition;
    final double radius = math.sqrt(event.pressure).clamp(0.5, 4.0);
    setState(() {
      _points.add(
        _TabletPoint(
          position: pos,
          pressure: event.pressure,
          radius: radius,
        ),
      );
      _latestPressure = event.pressure;
      _latestMin = event.pressureMin;
      _latestMax = event.pressureMax;
      _latestRadius = radius;
      _latestTilt = event.orientation;
      final DateTime now = DateTime.now();
      if (_lastSample != null) {
        final Duration delta = now.difference(_lastSample!);
        if (delta.inMilliseconds > 0) {
          _estimatedRps =
              (_estimatedRps * 0.8) + (1000 / delta.inMilliseconds) * 0.2;
        }
      }
      _lastSample = now;
      _sampleCount += 1;
    });
  }

  void _clear() {
    setState(() {
      _points.clear();
      _sampleCount = 0;
      _estimatedRps = 0;
      _latestPressure = null;
      _latestRadius = null;
      _latestTilt = null;
      _lastSample = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    return SizedBox(
      width: 700,
      height: 420,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Listener(
              onPointerDown: _handlePointer,
              onPointerMove: _handlePointer,
              onPointerHover: _handlePointer,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color:
                      theme.brightness.isDark ? const Color(0xFF171717) : Colors.white,
                  border: Border.all(color: theme.accentColor.lighter),
                ),
                child: CustomPaint(
                  painter: _TabletPainter(_points),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('实时参数', style: theme.typography.subtitle),
                const SizedBox(height: 12),
                _buildStat('最近压力', _latestPressure),
                _buildStat('pressureMin', _latestMin),
                _buildStat('pressureMax', _latestMax),
                _buildStat('估算半径', _latestRadius),
                _buildStat('倾角(弧度)', _latestTilt),
                _buildStat('采样计数', _sampleCount.toDouble(), fractionDigits: 0),
                _buildStat('采样频率(Hz)', _estimatedRps),
                const Spacer(),
                Button(
                  onPressed: _clear,
                  child: const Text('清空涂鸦'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, double? value, {int fractionDigits = 2}) {
    final FluentThemeData theme = FluentTheme.of(context);
    final String text = value == null
        ? '—'
        : value.toStringAsFixed(fractionDigits);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.typography.caption),
          Text(text, style: theme.typography.body),
        ],
      ),
    );
  }
}

class _TabletPoint {
  const _TabletPoint({
    required this.position,
    required this.pressure,
    required this.radius,
  });

  final Offset position;
  final double pressure;
  final double radius;
}

class _TabletPainter extends CustomPainter {
  const _TabletPainter(this.points);

  final List<_TabletPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF0063B1).withOpacity(0.55);
    for (final _TabletPoint point in points) {
      final Offset clamped = Offset(
        point.position.dx.clamp(0.0, size.width),
        point.position.dy.clamp(0.0, size.height),
      );
      canvas.drawCircle(clamped, point.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_TabletPainter oldDelegate) {
    return oldDelegate.points.length != points.length;
  }
}
