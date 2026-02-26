import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Localizations;

import '../../brushes/brush_library.dart';
import '../../brushes/brush_preset.dart';
import '../../brushes/brush_shape_library.dart';
import '../../canvas/canvas_tools.dart' show BrushShape;
import '../debug/brush_preset_timeline.dart';
import '../dialogs/misarin_dialog.dart';
import '../l10n/l10n.dart';

const bool _kBrushPresetEditLog = bool.fromEnvironment(
  'MISA_RIN_BRUSH_PREVIEW_LOG',
  defaultValue: false,
);

Future<BrushPreset?> showBrushPresetEditorDialog(
  BuildContext context, {
  required BrushPreset preset,
}) {
  final GlobalKey<BrushPresetEditorFormState> editorKey =
      GlobalKey<BrushPresetEditorFormState>();
  final AppLocalizations l10n = context.l10n;
  return showMisarinDialog<BrushPreset>(
    context: context,
    title: Text(l10n.brushPresetDialogTitle),
    content: BrushPresetEditorForm(key: editorKey, preset: preset),
    actions: [
      Button(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.cancel),
      ),
      FilledButton(
        onPressed: () {
          final BrushPreset? updated = editorKey.currentState?.buildPreset();
          if (updated != null) {
            Navigator.of(context).pop(updated);
          }
        },
        child: Text(l10n.save),
      ),
    ],
  );
}

class BrushPresetEditorForm extends StatefulWidget {
  const BrushPresetEditorForm({
    super.key,
    required this.preset,
    this.onChanged,
    this.scrollable = true,
  });

  final BrushPreset preset;
  final ValueChanged<BrushPreset>? onChanged;
  final bool scrollable;

  @override
  State<BrushPresetEditorForm> createState() => BrushPresetEditorFormState();
}

class BrushPresetEditorFormState extends State<BrushPresetEditorForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _authorController;
  late final TextEditingController _versionController;
  late String _originalName;
  bool _nameEdited = false;
  bool _nameIsLocalized = false;
  late BrushShape _shape;
  late String _shapeId;
  late double _spacing;
  late double _hardness;
  late double _flow;
  late double _scatter;
  late bool _randomRotation;
  late bool _smoothRotation;
  late double _rotationJitter;
  late int _antialiasLevel;
  late bool _hollowEnabled;
  late double _hollowRatio;
  late bool _hollowEraseOccludedParts;
  late bool _autoSharpTaper;
  late bool _snapToPixel;
  late bool _screentoneEnabled;
  late double _screentoneSpacing;
  late double _screentoneDotSize;
  late double _screentoneRotation;
  late double _screentoneSoftness;
  late BrushShape _screentoneShape;
  late bool _bristleEnabled;
  late double _bristleDensity;
  late double _bristleRandom;
  late double _bristleScale;
  late double _bristleShear;
  late bool _bristleThreshold;
  late bool _bristleConnected;
  late bool _bristleUsePressure;
  late bool _bristleAntialias;
  late bool _bristleUseCompositing;
  late double _inkAmount;
  late double _inkDepletion;
  late bool _inkUseOpacity;
  late bool _inkDepletionEnabled;
  late bool _inkUseSaturation;
  late bool _inkUseWeights;
  late double _inkPressureWeight;
  late double _inkBristleLengthWeight;
  late double _inkBristleInkAmountWeight;
  late double _inkDepletionWeight;
  late bool _inkUseSoak;
  late List<double> _inkDepletionCurve;
  late List<double> _inkDepletionCurveRaw;
  bool _inkCurveEdited = false;
  ui.Locale? _lastLocale;
  bool _didSync = false;

  static const int _inkCurveEditorPoints = 16;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _authorController = TextEditingController();
    _versionController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ui.Locale locale = Localizations.localeOf(context);
    if (!_didSync || _lastLocale != locale) {
      _didSync = true;
      _lastLocale = locale;
      _syncFromPreset(widget.preset, locale);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _authorController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BrushPresetEditorForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preset.id != widget.preset.id) {
      _syncFromPreset(widget.preset, Localizations.localeOf(context));
    }
  }

  void _syncFromPreset(BrushPreset preset, ui.Locale locale) {
    final Stopwatch? stopwatch = BrushPresetTimeline.enabled
        ? (Stopwatch()..start())
        : null;
    final BrushPreset sanitized = preset.sanitized();
    final BrushLibrary library = BrushLibrary.instance;
    final String displayName = library.displayNameFor(sanitized, locale);
    _originalName = sanitized.name;
    _nameEdited = false;
    _nameIsLocalized = library.isNameLocalized(sanitized, locale);
    _nameController.text = displayName;
    _shape = sanitized.shape;
    _shapeId = sanitized.resolvedShapeId;
    _authorController.text = sanitized.author ?? '';
    _versionController.text = sanitized.version ?? '';
    _spacing = sanitized.spacing;
    _hardness = sanitized.hardness;
    _flow = sanitized.flow;
    _scatter = sanitized.scatter;
    _randomRotation = sanitized.randomRotation;
    _smoothRotation = sanitized.smoothRotation;
    _rotationJitter = sanitized.rotationJitter;
    _antialiasLevel = sanitized.antialiasLevel;
    _hollowEnabled = sanitized.hollowEnabled;
    _hollowRatio = sanitized.hollowRatio;
    _hollowEraseOccludedParts = sanitized.hollowEraseOccludedParts;
    _autoSharpTaper = sanitized.autoSharpTaper;
    _snapToPixel = sanitized.snapToPixel;
    _screentoneEnabled = sanitized.screentoneEnabled;
    _screentoneSpacing = sanitized.screentoneSpacing;
    _screentoneDotSize = sanitized.screentoneDotSize;
    _screentoneRotation = sanitized.screentoneRotation;
    _screentoneSoftness = sanitized.screentoneSoftness;
    _screentoneShape = sanitized.screentoneShape;
    _bristleEnabled = sanitized.bristleEnabled;
    _bristleDensity = sanitized.bristleDensity;
    _bristleRandom = sanitized.bristleRandom;
    _bristleScale = sanitized.bristleScale;
    _bristleShear = sanitized.bristleShear;
    _bristleThreshold = sanitized.bristleThreshold;
    _bristleConnected = sanitized.bristleConnected;
    _bristleUsePressure = sanitized.bristleUsePressure;
    _bristleAntialias = sanitized.bristleAntialias;
    _bristleUseCompositing = sanitized.bristleUseCompositing;
    _inkAmount = sanitized.inkAmount;
    _inkDepletion = sanitized.inkDepletion;
    _inkUseOpacity = sanitized.inkUseOpacity;
    _inkDepletionEnabled = sanitized.inkDepletionEnabled;
    _inkUseSaturation = sanitized.inkUseSaturation;
    _inkUseWeights = sanitized.inkUseWeights;
    _inkPressureWeight = sanitized.inkPressureWeight;
    _inkBristleLengthWeight = sanitized.inkBristleLengthWeight;
    _inkBristleInkAmountWeight = sanitized.inkBristleInkAmountWeight;
    _inkDepletionWeight = sanitized.inkDepletionWeight;
    _inkUseSoak = sanitized.inkUseSoak;
    _inkDepletionCurveRaw =
        List<double>.from(sanitized.inkDepletionCurve, growable: false);
    _inkDepletionCurve =
        _resampleCurve(_inkDepletionCurveRaw, _inkCurveEditorPoints);
    _inkCurveEdited = false;
    if (stopwatch != null) {
      BrushPresetTimeline.mark(
        'editor_sync id=${sanitized.id} t=${stopwatch.elapsedMilliseconds}ms',
      );
    }
  }

  BrushPreset buildPreset() {
    final List<double> curve = _inkCurveEdited
        ? _inkDepletionCurve
        : (_inkDepletionCurveRaw.isNotEmpty
            ? _inkDepletionCurveRaw
            : _inkDepletionCurve);
    return widget.preset.copyWith(
      name: _resolveName(),
      shape: _shapeFromId(_shapeId) ?? _shape,
      shapeId: _shapeId,
      author: _authorController.text.trim().isEmpty
          ? null
          : _authorController.text.trim(),
      version: _versionController.text.trim().isEmpty
          ? null
          : _versionController.text.trim(),
      spacing: _spacing,
      hardness: _hardness,
      flow: _flow,
      scatter: _scatter,
      randomRotation: _randomRotation,
      smoothRotation: _smoothRotation,
      rotationJitter: _rotationJitter,
      antialiasLevel: _antialiasLevel,
      hollowEnabled: _hollowEnabled,
      hollowRatio: _hollowRatio,
      hollowEraseOccludedParts: _hollowEraseOccludedParts,
      autoSharpTaper: _autoSharpTaper,
      snapToPixel: _snapToPixel,
      screentoneEnabled: _screentoneEnabled,
      screentoneSpacing: _screentoneSpacing,
      screentoneDotSize: _screentoneDotSize,
      screentoneRotation: _screentoneRotation,
      screentoneSoftness: _screentoneSoftness,
      screentoneShape: _screentoneShape,
      bristleEnabled: _bristleEnabled,
      bristleDensity: _bristleDensity,
      bristleRandom: _bristleRandom,
      bristleScale: _bristleScale,
      bristleShear: _bristleShear,
      bristleThreshold: _bristleThreshold,
      bristleConnected: _bristleConnected,
      bristleUsePressure: _bristleUsePressure,
      bristleAntialias: _bristleAntialias,
      bristleUseCompositing: _bristleUseCompositing,
      inkAmount: _inkAmount,
      inkDepletion: _inkDepletion,
      inkUseOpacity: _inkUseOpacity,
      inkDepletionEnabled: _inkDepletionEnabled,
      inkUseSaturation: _inkUseSaturation,
      inkUseWeights: _inkUseWeights,
      inkPressureWeight: _inkPressureWeight,
      inkBristleLengthWeight: _inkBristleLengthWeight,
      inkBristleInkAmountWeight: _inkBristleInkAmountWeight,
      inkDepletionWeight: _inkDepletionWeight,
      inkUseSoak: _inkUseSoak,
      inkDepletionCurve: curve,
    );
  }

  String _resolveName() {
    final String trimmed = _nameController.text.trim();
    if (_nameEdited) {
      return trimmed.isEmpty ? _originalName : trimmed;
    }
    if (_nameIsLocalized) {
      return _originalName;
    }
    return trimmed.isEmpty ? _originalName : trimmed;
  }

  void _notifyChanged() {
    final ValueChanged<BrushPreset>? onChanged = widget.onChanged;
    if (onChanged == null || !mounted) {
      return;
    }
    final BrushPreset updated = buildPreset();
    if (_kBrushPresetEditLog) {
      debugPrint(
        '[brush-editor] changed id=${updated.id} '
        'aa=${updated.antialiasLevel} snap=${updated.snapToPixel} '
        'hardness=${updated.hardness} flow=${updated.flow}',
      );
    }
    onChanged(updated);
  }

  void _setAndNotify(VoidCallback update) {
    setState(update);
    _notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    final Stopwatch? buildTimer = BrushPresetTimeline.enabled
        ? (Stopwatch()..start())
        : null;
    final AppLocalizations l10n = context.l10n;
    final FluentThemeData theme = FluentTheme.of(context);
    final BrushShapeLibrary shapeLibrary = BrushLibrary.instance.shapeLibrary;
    final List<ComboBoxItem<BrushShape>> screentoneShapeItems =
        BrushShape.values
            .map((shape) {
              final String id = _shapeIdForBuiltIn(shape);
              final String label = shapeLibrary.labelFor(l10n, id);
              return ComboBoxItem<BrushShape>(
                value: shape,
                child: Text(label),
              );
            })
            .toList(growable: false);
    final List<ComboBoxItem<String>> shapeItems = <ComboBoxItem<String>>[];
    final bool hasShapeId =
        shapeLibrary.shapes.any((shape) => shape.id == _shapeId);
    if (_shapeId.isNotEmpty && !hasShapeId) {
      shapeItems.add(
        ComboBoxItem<String>(
          value: _shapeId,
          child: Text(_shapeId),
        ),
      );
    }
    shapeItems.addAll(
      shapeLibrary.shapes
          .map(
            (shape) => ComboBoxItem<String>(
              value: shape.id,
              child: Text(shapeLibrary.labelFor(l10n, shape.id)),
            ),
          )
          .toList(growable: false),
    );
    final bool bristleActive = _bristleEnabled;
    final bool inkActive = _inkDepletionEnabled;
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoLabel(
          label: l10n.brushPresetNameLabel,
          child: TextBox(
            controller: _nameController,
            onChanged: (_) {
              _nameEdited = true;
              _notifyChanged();
            },
          ),
        ),
        const SizedBox(height: 12),
        InfoLabel(
          label: l10n.brushAuthorLabel,
          child: TextBox(
            controller: _authorController,
            onChanged: (_) => _notifyChanged(),
          ),
        ),
        const SizedBox(height: 12),
        InfoLabel(
          label: l10n.brushVersionLabel,
          child: TextBox(
            controller: _versionController,
            onChanged: (_) => _notifyChanged(),
          ),
        ),
        const SizedBox(height: 12),
        InfoLabel(
          label: l10n.brushShape,
          child: ComboBox<String>(
            isExpanded: true,
            value: shapeItems.any((item) => item.value == _shapeId)
                ? _shapeId
                : null,
            items: shapeItems,
            onChanged: (value) {
              if (value == null) {
                return;
              }
              _setAndNotify(() {
                _shapeId = value;
                _shape = _shapeFromId(value) ?? _shape;
              });
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildSlider(
          context,
          label: l10n.brushSpacing,
          value: _spacing,
          min: 0.02,
          max: 2.5,
          divisions: 248,
          formatter: (value) => value.toStringAsFixed(2),
          onChanged: (value) => _setAndNotify(() => _spacing = value),
        ),
        const SizedBox(height: 12),
        _buildPercentSlider(
          context,
          label: l10n.brushHardness,
          value: _hardness,
          onChanged: (value) => _setAndNotify(() => _hardness = value),
        ),
        const SizedBox(height: 12),
        _buildPercentSlider(
          context,
          label: l10n.brushFlow,
          value: _flow,
          onChanged: (value) => _setAndNotify(() => _flow = value),
        ),
        const SizedBox(height: 12),
        _buildPercentSlider(
          context,
          label: l10n.brushScatter,
          value: _scatter,
          onChanged: (value) => _setAndNotify(() => _scatter = value),
        ),
        const SizedBox(height: 12),
        _buildToggleRow(
          context,
          label: l10n.randomRotation,
          value: _randomRotation,
          onChanged: (value) => _setAndNotify(() {
            _randomRotation = value;
            if (value && _rotationJitter <= 0.0001) {
              _rotationJitter = 1.0;
            }
          }),
        ),
        const SizedBox(height: 12),
        _buildToggleRow(
          context,
          label: l10n.smoothRotation,
          value: _smoothRotation,
          onChanged: (value) => _setAndNotify(() => _smoothRotation = value),
        ),
        const SizedBox(height: 12),
        _buildPercentSlider(
          context,
          label: l10n.brushRotationJitter,
          value: _rotationJitter,
          enabled: _randomRotation,
          onChanged: (value) => _setAndNotify(() => _rotationJitter = value),
        ),
        const SizedBox(height: 12),
        _buildAntialiasSlider(context),
        const SizedBox(height: 12),
        _buildToggleRow(
          context,
          label: l10n.hollowStroke,
          value: _hollowEnabled,
          onChanged: (value) => _setAndNotify(() => _hollowEnabled = value),
        ),
        if (_hollowEnabled) ...[
          const SizedBox(height: 12),
          _buildPercentSlider(
            context,
            label: l10n.hollowStrokeRatio,
            value: _hollowRatio,
            onChanged: (value) => _setAndNotify(() => _hollowRatio = value),
          ),
          const SizedBox(height: 12),
          _buildToggleRow(
            context,
            label: l10n.eraseOccludedParts,
            value: _hollowEraseOccludedParts,
            onChanged: (value) =>
                _setAndNotify(() => _hollowEraseOccludedParts = value),
          ),
        ],
        const SizedBox(height: 12),
        _buildToggleRow(
          context,
          label: l10n.autoSharpTaper,
          value: _autoSharpTaper,
          onChanged: (value) => _setAndNotify(() => _autoSharpTaper = value),
        ),
        const SizedBox(height: 12),
        _buildToggleRow(
          context,
          label: l10n.brushSnapToPixel,
          value: _snapToPixel,
          onChanged: (value) => _setAndNotify(() => _snapToPixel = value),
        ),
        const SizedBox(height: 12),
        _buildToggleRow(
          context,
          label: l10n.screentoneEnabled,
          value: _screentoneEnabled,
          onChanged: (value) =>
              _setAndNotify(() => _screentoneEnabled = value),
        ),
        if (_screentoneEnabled) ...[
          const SizedBox(height: 12),
          InfoLabel(
            label: l10n.screentoneShape,
            child: ComboBox<BrushShape>(
              isExpanded: true,
              value: _screentoneShape,
              items: screentoneShapeItems,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                _setAndNotify(() => _screentoneShape = value);
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildSlider(
            context,
            label: l10n.screentoneSpacing,
            value: _screentoneSpacing,
            min: 2.0,
            max: 200.0,
            divisions: 198,
            formatter: (value) => value.toStringAsFixed(1),
            onChanged: (value) =>
                _setAndNotify(() => _screentoneSpacing = value),
          ),
          const SizedBox(height: 12),
          _buildPercentSlider(
            context,
            label: l10n.screentoneDotSize,
            value: _screentoneDotSize,
            onChanged: (value) =>
                _setAndNotify(() => _screentoneDotSize = value),
          ),
          const SizedBox(height: 12),
          _buildSlider(
            context,
            label: l10n.screentoneRotation,
            value: _screentoneRotation,
            min: -90.0,
            max: 90.0,
            divisions: 180,
            formatter: (value) => '${value.round()}°',
            onChanged: (value) =>
                _setAndNotify(() => _screentoneRotation = value),
          ),
          const SizedBox(height: 12),
          _buildPercentSlider(
            context,
            label: l10n.screentoneSoftness,
            value: _screentoneSoftness,
            onChanged: (value) =>
                _setAndNotify(() => _screentoneSoftness = value),
          ),
        ],
        const SizedBox(height: 16),
        Text(l10n.brushBristleSection, style: theme.typography.subtitle),
        const SizedBox(height: 8),
        _buildToggleRow(
          context,
          label: l10n.bristleEnabled,
          value: _bristleEnabled,
          onChanged: (value) => _setAndNotify(() => _bristleEnabled = value),
        ),
        if (bristleActive) ...[
          const SizedBox(height: 12),
          _buildPercentSlider(
            context,
            label: l10n.bristleDensity,
            value: _bristleDensity,
            onChanged: (value) => _setAndNotify(() => _bristleDensity = value),
          ),
          const SizedBox(height: 12),
          _buildSlider(
            context,
            label: l10n.bristleRandom,
            value: _bristleRandom,
            min: 0.0,
            max: 10.0,
            divisions: 100,
            formatter: (value) => value.toStringAsFixed(2),
            onChanged: (value) => _setAndNotify(() => _bristleRandom = value),
          ),
          const SizedBox(height: 12),
          _buildSlider(
            context,
            label: l10n.bristleScale,
            value: _bristleScale,
            min: 0.1,
            max: 10.0,
            divisions: 99,
            formatter: (value) => value.toStringAsFixed(2),
            onChanged: (value) => _setAndNotify(() => _bristleScale = value),
          ),
          const SizedBox(height: 12),
          _buildSlider(
            context,
            label: l10n.bristleShear,
            value: _bristleShear,
            min: 0.0,
            max: 2.0,
            divisions: 200,
            formatter: (value) => value.toStringAsFixed(2),
            onChanged: (value) => _setAndNotify(() => _bristleShear = value),
          ),
          const SizedBox(height: 12),
          _buildToggleRow(
            context,
            label: l10n.bristleUsePressure,
            value: _bristleUsePressure,
            onChanged: (value) =>
                _setAndNotify(() => _bristleUsePressure = value),
          ),
          const SizedBox(height: 12),
          _buildToggleRow(
            context,
            label: l10n.bristleThreshold,
            value: _bristleThreshold,
            onChanged: (value) =>
                _setAndNotify(() => _bristleThreshold = value),
          ),
          const SizedBox(height: 12),
          _buildToggleRow(
            context,
            label: l10n.bristleConnected,
            value: _bristleConnected,
            onChanged: (value) =>
                _setAndNotify(() => _bristleConnected = value),
          ),
          const SizedBox(height: 12),
          _buildToggleRow(
            context,
            label: l10n.bristleAntialias,
            value: _bristleAntialias,
            onChanged: (value) =>
                _setAndNotify(() => _bristleAntialias = value),
          ),
          const SizedBox(height: 12),
          _buildToggleRow(
            context,
            label: l10n.bristleUseCompositing,
            value: _bristleUseCompositing,
            onChanged: (value) =>
                _setAndNotify(() => _bristleUseCompositing = value),
          ),
        ],
        const SizedBox(height: 16),
        Text(l10n.brushInkSection, style: theme.typography.subtitle),
        const SizedBox(height: 8),
        _buildToggleRow(
          context,
          label: l10n.inkDepletionEnabled,
          value: _inkDepletionEnabled,
          onChanged: (value) =>
              _setAndNotify(() => _inkDepletionEnabled = value),
        ),
        if (inkActive) ...[
          const SizedBox(height: 12),
          _buildPercentSlider(
            context,
            label: l10n.inkAmount,
            value: _inkAmount,
            onChanged: (value) => _setAndNotify(() => _inkAmount = value),
          ),
          const SizedBox(height: 12),
          _buildPercentSlider(
            context,
            label: l10n.inkDepletionStrength,
            value: _inkDepletion,
            onChanged: (value) => _setAndNotify(() => _inkDepletion = value),
          ),
          const SizedBox(height: 12),
          _buildToggleRow(
            context,
            label: l10n.inkUseOpacity,
            value: _inkUseOpacity,
            onChanged: (value) => _setAndNotify(() => _inkUseOpacity = value),
          ),
          const SizedBox(height: 12),
          _buildToggleRow(
            context,
            label: l10n.inkUseSaturation,
            value: _inkUseSaturation,
            onChanged: (value) => _setAndNotify(() => _inkUseSaturation = value),
          ),
          const SizedBox(height: 12),
          _buildToggleRow(
            context,
            label: l10n.inkUseWeights,
            value: _inkUseWeights,
            onChanged: (value) => _setAndNotify(() => _inkUseWeights = value),
          ),
          if (_inkUseWeights) ...[
            const SizedBox(height: 12),
            _buildWeightSlider(
              context,
              label: l10n.inkPressureWeight,
              value: _inkPressureWeight,
              onChanged: (value) =>
                  _setAndNotify(() => _inkPressureWeight = value),
            ),
            const SizedBox(height: 12),
            _buildWeightSlider(
              context,
              label: l10n.inkBristleLengthWeight,
              value: _inkBristleLengthWeight,
              onChanged: (value) =>
                  _setAndNotify(() => _inkBristleLengthWeight = value),
            ),
            const SizedBox(height: 12),
            _buildWeightSlider(
              context,
              label: l10n.inkBristleInkAmountWeight,
              value: _inkBristleInkAmountWeight,
              onChanged: (value) =>
                  _setAndNotify(() => _inkBristleInkAmountWeight = value),
            ),
            const SizedBox(height: 12),
            _buildWeightSlider(
              context,
              label: l10n.inkDepletionWeight,
              value: _inkDepletionWeight,
              onChanged: (value) =>
                  _setAndNotify(() => _inkDepletionWeight = value),
            ),
          ],
          const SizedBox(height: 12),
          _buildToggleRow(
            context,
            label: l10n.inkUseSoak,
            value: _inkUseSoak,
            onChanged: (value) => _setAndNotify(() => _inkUseSoak = value),
          ),
          const SizedBox(height: 12),
          _buildInkCurveEditor(context),
        ],
      ],
    );

    final Widget built = widget.scrollable
        ? SingleChildScrollView(child: content)
        : content;
    if (buildTimer != null) {
      final int elapsedMs = buildTimer.elapsedMilliseconds;
      if (elapsedMs > 8) {
        BrushPresetTimeline.mark('editor_build t=${elapsedMs}ms');
      }
    }
    return built;
  }

  Widget _buildAntialiasSlider(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final int clamped = _antialiasLevel.clamp(0, 9);
    return _buildSlider(
      context,
      label: l10n.brushAntialiasing,
      value: clamped.toDouble(),
      min: 0,
      max: 9,
      divisions: 9,
      formatter: (value) => l10n.levelLabel(value.round()),
      onChanged: (value) =>
          _setAndNotify(() => _antialiasLevel = value.round()),
    );
  }

  Widget _buildWeightSlider(
    BuildContext context, {
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return _buildSlider(
      context,
      label: label,
      value: value,
      min: 0.0,
      max: 100.0,
      divisions: 100,
      formatter: (raw) => '${raw.round()}%',
      onChanged: onChanged,
    );
  }

  Widget _buildInkCurveEditor(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final FluentThemeData theme = FluentTheme.of(context);
    final List<Widget> sliders = <Widget>[];
    for (int i = 0; i < _inkDepletionCurve.length; i += 1) {
      sliders.add(
        _buildSlider(
          context,
          label: '${l10n.inkCurvePoint} ${i + 1}',
          value: _inkDepletionCurve[i],
          min: 0.0,
          max: 1.0,
          divisions: 100,
          formatter: (raw) => raw.toStringAsFixed(2),
          onChanged: (value) => _setAndNotify(() {
            _inkDepletionCurve[i] = value;
            _inkCurveEdited = true;
          }),
        ),
      );
      if (i != _inkDepletionCurve.length - 1) {
        sliders.add(const SizedBox(height: 8));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.inkDepletionCurve,
                style: theme.typography.bodyStrong,
              ),
            ),
            Button(
              onPressed: () => _setAndNotify(() {
                _inkDepletionCurve = _linearCurve(_inkCurveEditorPoints);
                _inkCurveEdited = true;
              }),
              child: Text(l10n.inkCurveReset),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...sliders,
      ],
    );
  }

  Widget _buildPercentSlider(
    BuildContext context, {
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    bool enabled = true,
  }) {
    return _buildSlider(
      context,
      label: label,
      value: value,
      min: 0.0,
      max: 1.0,
      divisions: 100,
      formatter: (raw) => '${(raw * 100).round()}%',
      enabled: enabled,
      onChanged: onChanged,
    );
  }

  Widget _buildSlider(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double value) formatter,
    required ValueChanged<double> onChanged,
    bool enabled = true,
  }) {
    final FluentThemeData theme = FluentTheme.of(context);
    final double clamped = value.clamp(min, max);
    final String valueLabel = formatter(clamped);
    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $valueLabel', style: theme.typography.bodyStrong),
          Slider(
            value: clamped,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(
    BuildContext context, {
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    final FluentThemeData theme = FluentTheme.of(context);
    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.typography.bodyStrong),
          const SizedBox(width: 12),
          ToggleSwitch(checked: value, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
  }

  List<double> _linearCurve(int count) {
    if (count <= 0) {
      return const <double>[];
    }
    if (count == 1) {
      return const <double>[0.0];
    }
    final int last = count - 1;
    return List<double>.generate(
      count,
      (int index) => (index / last).clamp(0.0, 1.0),
      growable: false,
    );
  }

  List<double> _resampleCurve(List<double> source, int count) {
    if (count <= 0) {
      return const <double>[];
    }
    if (source.isEmpty) {
      return _linearCurve(count);
    }
    if (source.length == 1) {
      final double value = source.first.clamp(0.0, 1.0);
      return List<double>.filled(count, value, growable: false);
    }
    final int last = source.length - 1;
    final int denom = count - 1;
    return List<double>.generate(
      count,
      (int index) {
        final double t = denom > 0 ? index / denom : 0.0;
        final double pos = t * last;
        int left = pos.floor();
        if (left < 0) {
          left = 0;
        } else if (left > last) {
          left = last;
        }
        int right = left + 1;
        if (right > last) {
          right = last;
        }
        final double frac = pos - left;
        final double a = source[left].clamp(0.0, 1.0);
        final double b = source[right].clamp(0.0, 1.0);
        return (a + (b - a) * frac).clamp(0.0, 1.0);
      },
      growable: false,
    );
  }

  BrushShape? _shapeFromId(String id) {
    switch (id) {
      case 'circle':
        return BrushShape.circle;
      case 'triangle':
        return BrushShape.triangle;
      case 'square':
        return BrushShape.square;
      case 'star':
        return BrushShape.star;
    }
    return null;
  }

  String _shapeIdForBuiltIn(BrushShape shape) {
    switch (shape) {
      case BrushShape.circle:
        return 'circle';
      case BrushShape.triangle:
        return 'triangle';
      case BrushShape.square:
        return 'square';
      case BrushShape.star:
        return 'star';
    }
  }
}
