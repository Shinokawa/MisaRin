import 'dart:async';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../l10n/locale_controller.dart';
import '../l10n/l10n.dart';
import '../theme/theme_controller.dart';
import '../preferences/app_preferences.dart';
import '../utils/tablet_input_bridge.dart';
import '../../performance/stroke_latency_monitor.dart';
import 'misarin_dialog.dart';

Future<void> showSettingsDialog(BuildContext context) {
  final GlobalKey<_SettingsDialogContentState> contentKey =
      GlobalKey<_SettingsDialogContentState>();
  final l10n = context.l10n;
  return showMisarinDialog<void>(
    context: context,
    title: Text(l10n.settingsTitle),
    content: _SettingsDialogContent(key: contentKey),
    contentWidth: 420,
    maxWidth: 520,
    actions: [
      Button(
        onPressed: () => contentKey.currentState?.openTabletDiagnostic(),
        child: Text(l10n.tabletTest),
      ),
      Button(
        onPressed: () => contentKey.currentState?.resetToDefaults(),
        child: Text(l10n.restoreDefaults),
      ),
      Button(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.ok),
      ),
    ],
  );
}

enum _AppLocaleOption {
  system,
  english,
  japanese,
  korean,
  chineseSimplified,
  chineseTraditional,
}

class _SettingsDialogContent extends StatefulWidget {
  const _SettingsDialogContent({super.key});

  @override
  State<_SettingsDialogContent> createState() => _SettingsDialogContentState();
}

class _SettingsDialogContentState extends State<_SettingsDialogContent> {
  late int _historyLimit;
  late _AppLocaleOption _localeOption;
  late bool _stylusPressureEnabled;
  late double _stylusCurve;
  late PenStrokeSliderRange _penSliderRange;
  late bool _fpsOverlayEnabled;

  @override
  void initState() {
    super.initState();
    _historyLimit = AppPreferences.instance.historyLimit;
    _localeOption = _optionForLocale(AppPreferences.instance.localeOverride);
    _stylusPressureEnabled = AppPreferences.instance.stylusPressureEnabled;
    _stylusCurve = AppPreferences.instance.stylusPressureCurve;
    _penSliderRange = AppPreferences.instance.penStrokeSliderRange;
    _fpsOverlayEnabled = AppPreferences.instance.showFpsOverlay;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final l10n = context.l10n;
    final ThemeController controller = ThemeController.of(context);
    final ThemeMode themeMode = controller.themeMode;
    final int minHistory = AppPreferences.minHistoryLimit;
    final int maxHistory = AppPreferences.maxHistoryLimit;

    final Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoLabel(
          label: l10n.languageLabel,
          child: ComboBox<_AppLocaleOption>(
            isExpanded: true,
            value: _localeOption,
            items: _AppLocaleOption.values
                .map(
                  (option) => ComboBoxItem<_AppLocaleOption>(
                    value: option,
                    child: Text(_localeOptionLabel(option)),
                  ),
                )
                .toList(growable: false),
            onChanged: (option) {
              if (option == null || option == _localeOption) {
                return;
              }
              setState(() => _localeOption = option);
              final Locale? locale = _localeForOption(option);
              final LocaleController controller = LocaleController.of(context);
              controller.onLocaleChanged(locale);
              final AppPreferences prefs = AppPreferences.instance;
              if (prefs.localeOverride != locale) {
                prefs.localeOverride = locale;
                unawaited(AppPreferences.save());
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        InfoLabel(
          label: l10n.themeModeLabel,
          child: ComboBox<ThemeMode>(
            isExpanded: true,
            value: themeMode,
            items: [
              ComboBoxItem(value: ThemeMode.light, child: Text(l10n.themeLight)),
              ComboBoxItem(value: ThemeMode.dark, child: Text(l10n.themeDark)),
              ComboBoxItem(value: ThemeMode.system, child: Text(l10n.themeSystem)),
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
          label: l10n.stylusPressureSettingsLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(l10n.enableStylusPressure),
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
                label: l10n.responseCurveLabel,
                description: l10n.responseCurveDesc,
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
          label: l10n.brushSizeSliderRangeLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ComboBox<PenStrokeSliderRange>(
                isExpanded: true,
                value: _penSliderRange,
                items: PenStrokeSliderRange.values
                    .map(
                      (range) => ComboBoxItem<PenStrokeSliderRange>(
                        value: range,
                        child: Text(_sliderRangeLabel(range)),
                      ),
                    )
                    .toList(),
                onChanged: (range) {
                  if (range == null) {
                    return;
                  }
                  _updatePenSliderRange(range);
                },
              ),
              const SizedBox(height: 8),
              Text(
                l10n.brushSizeSliderRangeDesc,
                style: theme.typography.caption,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        InfoLabel(
          label: l10n.historyLimitLabel,
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
                l10n.historyLimitCurrent(_historyLimit),
                style: theme.typography.caption,
              ),
              Text(
                l10n.historyLimitDesc(minHistory, maxHistory),
                style: theme.typography.caption,
              ),
            ],
          ),
        ),
        if (!kIsWeb) ...[
          const SizedBox(height: 16),
          InfoLabel(
            label: l10n.developerOptionsLabel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l10n.performanceOverlayLabel)),
                    ToggleSwitch(
                      checked: _fpsOverlayEnabled,
                      onChanged: (value) {
                        setState(() => _fpsOverlayEnabled = value);
                        final AppPreferences prefs = AppPreferences.instance;
                        prefs.updateShowFpsOverlay(value);
                        unawaited(AppPreferences.save());
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.performanceOverlayDesc,
                  style: theme.typography.caption,
                ),
              ],
            ),
          ),
        ],
      ],
    );

    return SingleChildScrollView(
      primary: true,
      child: body,
    );
  }

  void _updatePenSliderRange(PenStrokeSliderRange range) {
    setState(() => _penSliderRange = range);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.penStrokeSliderRange = range;
    _clampPenWidthForRange(prefs, range);
    unawaited(AppPreferences.save());
  }

  void _clampPenWidthForRange(
    AppPreferences prefs,
    PenStrokeSliderRange range,
  ) {
    final double adjusted = range.clamp(prefs.penStrokeWidth);
    if ((adjusted - prefs.penStrokeWidth).abs() > 0.0001) {
      prefs.penStrokeWidth = adjusted;
    }
  }

  String _sliderRangeLabel(PenStrokeSliderRange range) {
    final l10n = context.l10n;
    switch (range) {
      case PenStrokeSliderRange.compact:
        return l10n.penSliderRangeCompact;
      case PenStrokeSliderRange.medium:
        return l10n.penSliderRangeMedium;
      case PenStrokeSliderRange.full:
        return l10n.penSliderRangeFull;
    }
  }

  String _localeOptionLabel(_AppLocaleOption option) {
    final l10n = context.l10n;
    switch (option) {
      case _AppLocaleOption.system:
        return l10n.languageSystem;
      case _AppLocaleOption.english:
        return l10n.languageEnglish;
      case _AppLocaleOption.japanese:
        return l10n.languageJapanese;
      case _AppLocaleOption.korean:
        return l10n.languageKorean;
      case _AppLocaleOption.chineseSimplified:
        return l10n.languageChineseSimplified;
      case _AppLocaleOption.chineseTraditional:
        return l10n.languageChineseTraditional;
    }
  }

  static Locale? _localeForOption(_AppLocaleOption option) {
    switch (option) {
      case _AppLocaleOption.system:
        return null;
      case _AppLocaleOption.english:
        return const Locale('en');
      case _AppLocaleOption.japanese:
        return const Locale('ja');
      case _AppLocaleOption.korean:
        return const Locale('ko');
      case _AppLocaleOption.chineseSimplified:
        return const Locale('zh', 'CN');
      case _AppLocaleOption.chineseTraditional:
        return const Locale('zh', 'TW');
    }
  }

  static _AppLocaleOption _optionForLocale(Locale? locale) {
    if (locale == null) {
      return _AppLocaleOption.system;
    }
    final String languageCode = locale.languageCode.toLowerCase();
    final String? countryCode = locale.countryCode?.toUpperCase();
    if (languageCode == 'en') return _AppLocaleOption.english;
    if (languageCode == 'ja') return _AppLocaleOption.japanese;
    if (languageCode == 'ko') return _AppLocaleOption.korean;
    if (languageCode == 'zh' && countryCode == 'TW') {
      return _AppLocaleOption.chineseTraditional;
    }
    if (languageCode == 'zh') return _AppLocaleOption.chineseSimplified;
    return _AppLocaleOption.system;
  }

  void resetToDefaults() {
    final ThemeController controller = ThemeController.of(context);
    final LocaleController localeController = LocaleController.of(context);
    final AppPreferences prefs = AppPreferences.instance;
    final int defaultHistory = AppPreferences.defaultHistoryLimit;
    final ThemeMode defaultTheme = AppPreferences.defaultThemeMode;
    final Locale? defaultLocale = AppPreferences.defaultLocaleOverride;
    controller.onThemeModeChanged(defaultTheme);
    localeController.onLocaleChanged(defaultLocale);
    setState(() {
      _historyLimit = defaultHistory;
      _localeOption = _optionForLocale(defaultLocale);
      _stylusPressureEnabled = AppPreferences.defaultStylusPressureEnabled;
      _stylusCurve = AppPreferences.defaultStylusCurve;
      _penSliderRange = AppPreferences.defaultPenStrokeSliderRange;
      _fpsOverlayEnabled = AppPreferences.defaultShowFpsOverlay;
    });
    prefs.historyLimit = defaultHistory;
    prefs.themeMode = defaultTheme;
    prefs.localeOverride = defaultLocale;
    prefs.stylusPressureEnabled = _stylusPressureEnabled;
    prefs.stylusPressureCurve = _stylusCurve;
    prefs.penStrokeSliderRange = _penSliderRange;
    prefs.updateShowFpsOverlay(_fpsOverlayEnabled);
    _clampPenWidthForRange(prefs, _penSliderRange);
    unawaited(AppPreferences.save());
  }

  void openTabletDiagnostic() {
    _showTabletInspectDialog(context);
  }
}

Future<void> _showTabletInspectDialog(BuildContext context) async {
  final l10n = context.l10n;
  return showMisarinDialog<void>(
    context: context,
    title: Text(l10n.tabletInputTestTitle),
    contentWidth: 720,
    maxWidth: 820,
    content: const _TabletInspectPane(),
    actions: [
      Button(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.close),
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
  double? _latestPhysicalRadius;
  double? _latestTilt;
  PointerDeviceKind? _latestPointerKind;
  int _sampleCount = 0;
  DateTime? _lastSample;
  double _estimatedRps = 0;
  bool _isDrawingContact = false;
  bool _latencyPending = false;
  bool _latencyFrameScheduled = false;

  void _handlePointer(PointerEvent event) {
    if (!_shouldCaptureEvent(event)) {
      return;
    }
    final Offset pos = event.localPosition;
    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final double pressure =
        TabletInputBridge.instance.pressureForEvent(event) ??
        (event.pressure.isFinite ? event.pressure.clamp(0.0, 1.0) : 0.0);
    final double radius =
        _brushRadiusForPressure(pressure, devicePixelRatio);
    final double physicalRadius = radius * devicePixelRatio;
    final bool inContact = event.down || pressure > 0.0;
    setState(() {
      _latestPressure = pressure;
      _latestMin = event.pressureMin;
      _latestMax = event.pressureMax;
      _latestPhysicalRadius = physicalRadius;
      _latestTilt = event.orientation;
      _latestPointerKind = event.kind;
      final DateTime now = DateTime.now();
      if (_lastSample != null) {
        final Duration delta = now.difference(_lastSample!);
        if (delta.inMilliseconds > 0) {
          _estimatedRps =
              (_estimatedRps * 0.8) + (1000 / delta.inMilliseconds) * 0.2;
        }
      }
      _lastSample = now;
      if (!inContact) {
        _isDrawingContact = false;
        _latencyPending = false;
        return;
      }
      final bool isNewStroke = !_isDrawingContact;
      _isDrawingContact = true;
      if (isNewStroke) {
        StrokeLatencyMonitor.instance.recordStrokeStart();
        _latencyPending = true;
      }
      _points.add(
        _TabletPoint(
          position: pos,
          pressure: pressure,
          radius: radius,
          isNewStroke: isNewStroke,
        ),
      );
      _sampleCount += 1;
    });
    _scheduleLatencyFrameReport();
  }

  void _clear() {
    setState(() {
      _points.clear();
      _sampleCount = 0;
      _estimatedRps = 0;
      _latestPressure = null;
      _latestPhysicalRadius = null;
      _latestTilt = null;
      _latestPointerKind = null;
      _lastSample = null;
      _isDrawingContact = false;
      _latencyPending = false;
    });
    _latencyFrameScheduled = false;
  }

  bool _shouldCaptureEvent(PointerEvent event) {
    if (TabletInputBridge.instance.isTabletPointer(event) ||
        event.kind == PointerDeviceKind.unknown) {
      return true;
    }
    if (event.kind == PointerDeviceKind.mouse) {
      if (event is PointerDownEvent || event is PointerUpEvent) {
        return true;
      }
      if (event is PointerMoveEvent) {
        return event.down || (event.buttons & kPrimaryMouseButton) != 0;
      }
      return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    return SizedBox(
      width: 700,
      height: 420,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _handlePointer,
              onPointerMove: _handlePointer,
              onPointerUp: _handlePointerUp,
              onPointerHover: _handlePointer,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.brightness.isDark
                      ? const Color(0xFF171717)
                      : Colors.white,
                  border: Border.all(color: theme.accentColor.lighter),
                ),
                child: CustomPaint(
                  painter: _TabletPainter(_points, devicePixelRatio),
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
                _buildStat('估算半径 (px)', _latestPhysicalRadius),
                _buildStat('倾角(弧度)', _latestTilt),
                _buildStat('采样计数', _sampleCount.toDouble(), fractionDigits: 0),
                _buildStat('采样频率(Hz)', _estimatedRps),
                _buildTextStat('指针类型', _pointerKindLabel(_latestPointerKind)),
                const Spacer(),
                Button(onPressed: _clear, child: const Text('清空涂鸦')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _brushRadiusForPressure(double pressure, double devicePixelRatio) {
    const double minPhysicalRadius = 1.0;
    const double maxPhysicalRadius = 12.0;
    final double normalized = pressure.clamp(0.0, 1.0);
    final double eased = math.sqrt(normalized);
    final double physicalRadius =
        minPhysicalRadius + (maxPhysicalRadius - minPhysicalRadius) * eased;
    final double safePixelRatio =
        devicePixelRatio <= 0 ? 1.0 : devicePixelRatio;
    return physicalRadius / safePixelRatio;
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!_shouldCaptureEvent(event)) {
      return;
    }
    setState(() {
      _latestPointerKind = event.kind;
      _latestPressure = 0;
      _isDrawingContact = false;
    });
    _latencyPending = false;
  }

  void _scheduleLatencyFrameReport() {
    if (!_latencyPending || _latencyFrameScheduled) {
      return;
    }
    _latencyFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _latencyFrameScheduled = false;
      if (!_latencyPending) {
        return;
      }
      StrokeLatencyMonitor.instance.recordFramePresented();
      _latencyPending = false;
    });
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

  Widget _buildTextStat(String label, String value) {
    final FluentThemeData theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.typography.caption),
          Text(value, style: theme.typography.body),
        ],
      ),
    );
  }

  String _pointerKindLabel(PointerDeviceKind? kind) {
    if (kind == null) {
      return '—';
    }
    final String raw = kind.toString();
    final int dotIndex = raw.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == raw.length - 1) {
      return raw;
    }
    return raw.substring(dotIndex + 1);
  }
}

class _TabletPoint {
  const _TabletPoint({
    required this.position,
    required this.pressure,
    required this.radius,
    required this.isNewStroke,
  });

  final Offset position;
  final double pressure;
  final double radius;
  final bool isNewStroke;
}

class _TabletPainter extends CustomPainter {
  const _TabletPainter(this.points, this.devicePixelRatio);

  final List<_TabletPoint> points;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }
    final double safePixelRatio =
        devicePixelRatio <= 0 ? 1.0 : devicePixelRatio;
    final double minLogicalStroke = 1.0 / safePixelRatio;
    final double maxLogicalStroke = 12.0 / safePixelRatio;
    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF0063B1).withOpacity(0.85);
    final Paint dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF0063B1).withOpacity(0.6);

    Offset? previous;
    double previousRadius = 0;
    for (final _TabletPoint point in points) {
      final Offset clamped = Offset(
        point.position.dx.clamp(0.0, size.width),
        point.position.dy.clamp(0.0, size.height),
      );
      if (point.isNewStroke || previous == null) {
        final double radius = math.max(point.radius, minLogicalStroke);
        canvas.drawCircle(clamped, radius, dotPaint);
        previous = clamped;
        previousRadius = point.radius;
        continue;
      }
      final double strokeWidth = ((previousRadius + point.radius) / 2)
          .clamp(minLogicalStroke, maxLogicalStroke)
          .toDouble();
      strokePaint.strokeWidth = strokeWidth;
      canvas.drawLine(previous, clamped, strokePaint);
      previous = clamped;
      previousRadius = point.radius;
    }
  }

  @override
  bool shouldRepaint(_TabletPainter oldDelegate) {
    return oldDelegate.points.length != points.length ||
        oldDelegate.devicePixelRatio != devicePixelRatio;
  }
}
