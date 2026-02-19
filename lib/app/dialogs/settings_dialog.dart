import 'dart:async';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/locale_controller.dart';
import '../l10n/l10n.dart';
import '../theme/theme_controller.dart';
import '../preferences/app_preferences.dart';
import '../utils/tablet_input_bridge.dart';
import '../widgets/app_notification.dart';
import '../../performance/stroke_latency_monitor.dart';
import 'misarin_dialog.dart';
import '../../canvas/canvas_backend.dart';
import '../../brushes/brush_library.dart';
import '../utils/file_manager.dart';

Future<void> showSettingsDialog(
  BuildContext context, {
  bool openAboutTab = false,
}) {
  final GlobalKey<_SettingsDialogContentState> contentKey =
      GlobalKey<_SettingsDialogContentState>();
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final l10n = dialogContext.l10n;
      return MisarinDialog(
        title: Text(l10n.settingsTitle),
        content: _SettingsDialogContent(
          key: contentKey,
          initialSection:
              openAboutTab ? _SettingsSection.about : _SettingsSection.language,
        ),
        contentWidth: null,
        maxWidth: 920,
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
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.ok),
          ),
        ],
      );
    },
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

enum _SettingsSection {
  language,
  theme,
  stylus,
  brush,
  history,
  canvasBackend,
  developer,
  about,
}

class _SettingsDialogContent extends StatefulWidget {
  const _SettingsDialogContent({
    super.key,
    required this.initialSection,
  });

  final _SettingsSection initialSection;

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
  late CanvasBackend _canvasBackend;
  late _SettingsSection _selectedSection;
  PackageInfo? _packageInfo;
  String? _brushShapeFolderPath;

  @override
  void initState() {
    super.initState();
    _historyLimit = AppPreferences.instance.historyLimit;
    _localeOption = _optionForLocale(AppPreferences.instance.localeOverride);
    _stylusPressureEnabled = AppPreferences.instance.stylusPressureEnabled;
    _stylusCurve = AppPreferences.instance.stylusPressureCurve;
    _penSliderRange = AppPreferences.instance.penStrokeSliderRange;
    _fpsOverlayEnabled = AppPreferences.instance.showFpsOverlay;
    _canvasBackend = AppPreferences.instance.canvasBackend;
    _selectedSection = widget.initialSection;
    unawaited(_loadPackageInfo());
    unawaited(_loadBrushShapeFolderPath());
  }

  Future<void> _loadBrushShapeFolderPath() async {
    final String? path =
        await BrushLibrary.instance.shapeLibrary.resolveShapeDirectoryPath();
    if (!mounted) {
      return;
    }
    setState(() => _brushShapeFolderPath = path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final List<_SettingsSection> sections = [
      _SettingsSection.language,
      _SettingsSection.theme,
      _SettingsSection.stylus,
      _SettingsSection.brush,
      _SettingsSection.history,
      if (!kIsWeb) _SettingsSection.canvasBackend,
      if (!kIsWeb) _SettingsSection.developer,
      _SettingsSection.about,
    ];

    final Widget body = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 220,
          child: _buildSectionTabs(context, sections),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: theme.resources.subtleFillColorTertiary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.resources.controlStrokeColorDefault,
              ),
            ),
            child: SingleChildScrollView(
              primary: true,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: _buildSectionContent(context, _selectedSection),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return SizedBox(
      height: 520,
      child: body,
    );
  }

  Widget _buildSectionTabs(
    BuildContext context,
    List<_SettingsSection> sections,
  ) {
    final theme = FluentTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.resources.subtleFillColorTertiary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.resources.controlStrokeColorDefault,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int index = 0; index < sections.length; index++) ...[
            _buildSectionTab(context, sections[index]),
            if (index != sections.length - 1) const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTab(BuildContext context, _SettingsSection section) {
    final theme = FluentTheme.of(context);
    final bool selected = _selectedSection == section;
    return ListTile.selectable(
      title: Text(
        _sectionLabel(context, section),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      selected: selected,
      onPressed: () => setState(() => _selectedSection = section),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      tileColor: WidgetStateProperty.resolveWith(
        (states) => states.isHovered || selected
            ? theme.resources.subtleFillColorSecondary
            : Colors.transparent,
      ),
    );
  }

  Widget _buildSectionContent(BuildContext context, _SettingsSection section) {
    final l10n = context.l10n;
    final theme = FluentTheme.of(context);
    switch (section) {
      case _SettingsSection.language:
        return InfoLabel(
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
        );
      case _SettingsSection.theme:
        final ThemeController controller = ThemeController.of(context);
        final ThemeMode themeMode = controller.themeMode;
        return InfoLabel(
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
        );
      case _SettingsSection.stylus:
        return InfoLabel(
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
        );
      case _SettingsSection.brush:
        return InfoLabel(
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
              if (!kIsWeb) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.brushShapeFolderLabel,
                  style: theme.typography.bodyStrong,
                ),
                const SizedBox(height: 8),
                Button(
                  onPressed: _brushShapeFolderPath == null
                      ? null
                      : () => revealInFileManager(_brushShapeFolderPath!),
                  child: Text(l10n.openBrushShapesFolder),
                ),
                if (_brushShapeFolderPath != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _brushShapeFolderPath!,
                    style: theme.typography.caption,
                  ),
                ],
              ],
            ],
          ),
        );
      case _SettingsSection.history:
        final int minHistory = AppPreferences.minHistoryLimit;
        final int maxHistory = AppPreferences.maxHistoryLimit;
        return InfoLabel(
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
        );
      case _SettingsSection.canvasBackend:
        if (kIsWeb) {
          return const SizedBox.shrink();
        }
        return InfoLabel(
          label: l10n.canvasBackendLabel,
          child: ComboBox<CanvasBackend>(
            isExpanded: true,
            value: _canvasBackend,
            items: CanvasBackend.values
                .map(
                  (backend) => ComboBoxItem<CanvasBackend>(
                    value: backend,
                    child: Text(_canvasBackendLabel(backend)),
                  ),
                )
                .toList(growable: false),
            onChanged: (backend) {
              if (backend == null || backend == _canvasBackend) {
                return;
              }
              _updateCanvasBackend(backend);
            },
          ),
        );
      case _SettingsSection.developer:
        if (kIsWeb) {
          return const SizedBox.shrink();
        }
        return InfoLabel(
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
        );
      case _SettingsSection.about:
        final PackageInfo? info = _packageInfo;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.aboutDescription, style: theme.typography.body),
            const SizedBox(height: 12),
            InfoLabel(
              label: l10n.aboutAppIdLabel,
              child: SelectableText(
                'com.aimessoft.misarin',
                style: theme.typography.bodyStrong,
              ),
            ),
            const SizedBox(height: 12),
            InfoLabel(
              label: l10n.aboutAppVersionLabel,
              child: SelectableText(
                info?.version ?? '—',
                style: theme.typography.bodyStrong,
              ),
            ),
            const SizedBox(height: 12),
            InfoLabel(
              label: l10n.aboutDeveloperLabel,
              child: SelectableText(
                'Aimes Soft',
                style: theme.typography.bodyStrong,
              ),
            ),
          ],
        );
    }
  }

  String _sectionLabel(BuildContext context, _SettingsSection section) {
    final l10n = context.l10n;
    switch (section) {
      case _SettingsSection.language:
        return l10n.languageLabel;
      case _SettingsSection.theme:
        return l10n.themeModeLabel;
      case _SettingsSection.stylus:
        return l10n.stylusPressureSettingsLabel;
      case _SettingsSection.brush:
        return l10n.brushSizeSliderRangeLabel;
      case _SettingsSection.history:
        return l10n.historyLimitLabel;
      case _SettingsSection.canvasBackend:
        return l10n.canvasBackendLabel;
      case _SettingsSection.developer:
        return l10n.developerOptionsLabel;
      case _SettingsSection.about:
        return l10n.aboutTitle;
    }
  }

  Future<void> _loadPackageInfo() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (!mounted) {
        return;
      }
      setState(() {
        _packageInfo = info;
      });
    } catch (_) {
      // Ignore lookup failures; show placeholder instead.
    }
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

  void _updateCanvasBackend(CanvasBackend backend) {
    setState(() => _canvasBackend = backend);
    final AppPreferences prefs = AppPreferences.instance;
    if (prefs.canvasBackend != backend) {
      prefs.canvasBackend = backend;
      unawaited(AppPreferences.save());
      AppNotifications.show(
        context,
        message: context.l10n.canvasBackendRestartHint,
        severity: InfoBarSeverity.warning,
      );
    }
  }

  String _canvasBackendLabel(CanvasBackend backend) {
    final l10n = context.l10n;
    switch (backend) {
      case CanvasBackend.rustWgpu:
        return l10n.canvasBackendGpu;
      case CanvasBackend.rustCpu:
        return l10n.canvasBackendCpu;
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
    final CanvasBackend defaultBackend = AppPreferences.defaultCanvasBackend;
    controller.onThemeModeChanged(defaultTheme);
    localeController.onLocaleChanged(defaultLocale);
    setState(() {
      _historyLimit = defaultHistory;
      _localeOption = _optionForLocale(defaultLocale);
      _stylusPressureEnabled = AppPreferences.defaultStylusPressureEnabled;
      _stylusCurve = AppPreferences.defaultStylusCurve;
      _penSliderRange = AppPreferences.defaultPenStrokeSliderRange;
      _fpsOverlayEnabled = AppPreferences.defaultShowFpsOverlay;
      _canvasBackend = defaultBackend;
    });
    prefs.historyLimit = defaultHistory;
    prefs.themeMode = defaultTheme;
    prefs.localeOverride = defaultLocale;
    prefs.stylusPressureEnabled = _stylusPressureEnabled;
    prefs.stylusPressureCurve = _stylusCurve;
    prefs.penStrokeSliderRange = _penSliderRange;
    prefs.updateShowFpsOverlay(_fpsOverlayEnabled);
    if (prefs.canvasBackend != defaultBackend) {
      prefs.canvasBackend = defaultBackend;
      AppNotifications.show(
        context,
        message: context.l10n.canvasBackendRestartHint,
        severity: InfoBarSeverity.warning,
      );
    }
    _clampPenWidthForRange(prefs, _penSliderRange);
    unawaited(AppPreferences.save());
  }

  void openTabletDiagnostic() {
    _showTabletInspectDialog(context);
  }
}

Future<void> _showTabletInspectDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final l10n = dialogContext.l10n;
      return MisarinDialog(
        title: Text(l10n.tabletInputTestTitle),
        contentWidth: 720,
        maxWidth: 820,
        content: const _TabletInspectPane(),
        actions: [
          Button(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.close),
          ),
        ],
      );
    },
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
    final l10n = context.l10n;
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
                Text(l10n.realtimeParams, style: theme.typography.subtitle),
                const SizedBox(height: 12),
                _buildStat(l10n.tabletPressureLatest, _latestPressure),
                _buildStat(l10n.tabletPressureMin, _latestMin),
                _buildStat(l10n.tabletPressureMax, _latestMax),
                _buildStat(l10n.tabletRadiusPx, _latestPhysicalRadius),
                _buildStat(l10n.tabletTiltRad, _latestTilt),
                _buildStat(l10n.tabletSampleCount, _sampleCount.toDouble(),
                    fractionDigits: 0),
                _buildStat(l10n.tabletSampleRateHz, _estimatedRps),
                _buildTextStat(
                    l10n.tabletPointerType, _pointerKindLabel(_latestPointerKind)),
                const Spacer(),
                Button(onPressed: _clear, child: Text(l10n.clearScribble)),
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
    final l10n = context.l10n;
    switch (kind) {
      case PointerDeviceKind.mouse:
        return l10n.pointerKindMouse;
      case PointerDeviceKind.touch:
        return l10n.pointerKindTouch;
      case PointerDeviceKind.stylus:
        return l10n.pointerKindStylus;
      case PointerDeviceKind.invertedStylus:
        return l10n.pointerKindInvertedStylus;
      case PointerDeviceKind.trackpad:
        return l10n.pointerKindTrackpad;
      case PointerDeviceKind.unknown:
        return l10n.pointerKindUnknown;
      case null:
        return '—';
    }
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
