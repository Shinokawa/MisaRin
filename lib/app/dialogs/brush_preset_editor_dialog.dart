import 'package:fluent_ui/fluent_ui.dart';

import '../../brushes/brush_preset.dart';
import '../../canvas/canvas_tools.dart' show BrushShape;
import '../dialogs/misarin_dialog.dart';
import '../l10n/l10n.dart';

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
  late BrushShape _shape;
  late double _spacing;
  late double _hardness;
  late double _flow;
  late double _scatter;
  late bool _randomRotation;
  late double _rotationJitter;
  late int _antialiasLevel;
  late bool _hollowEnabled;
  late double _hollowRatio;
  late bool _hollowEraseOccludedParts;
  late bool _autoSharpTaper;
  late bool _snapToPixel;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _syncFromPreset(widget.preset);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BrushPresetEditorForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preset.id != widget.preset.id) {
      _syncFromPreset(widget.preset);
    }
  }

  void _syncFromPreset(BrushPreset preset) {
    final BrushPreset sanitized = preset.sanitized();
    _nameController.text = sanitized.name;
    _shape = sanitized.shape;
    _spacing = sanitized.spacing;
    _hardness = sanitized.hardness;
    _flow = sanitized.flow;
    _scatter = sanitized.scatter;
    _randomRotation = sanitized.randomRotation;
    _rotationJitter = sanitized.rotationJitter;
    _antialiasLevel = sanitized.antialiasLevel;
    _hollowEnabled = sanitized.hollowEnabled;
    _hollowRatio = sanitized.hollowRatio;
    _hollowEraseOccludedParts = sanitized.hollowEraseOccludedParts;
    _autoSharpTaper = sanitized.autoSharpTaper;
    _snapToPixel = sanitized.snapToPixel;
  }

  BrushPreset buildPreset() {
    return widget.preset.copyWith(
      name: _nameController.text.trim().isEmpty
          ? widget.preset.name
          : _nameController.text.trim(),
      shape: _shape,
      spacing: _spacing,
      hardness: _hardness,
      flow: _flow,
      scatter: _scatter,
      randomRotation: _randomRotation,
      rotationJitter: _rotationJitter,
      antialiasLevel: _antialiasLevel,
      hollowEnabled: _hollowEnabled,
      hollowRatio: _hollowRatio,
      hollowEraseOccludedParts: _hollowEraseOccludedParts,
      autoSharpTaper: _autoSharpTaper,
      snapToPixel: _snapToPixel,
    );
  }

  void _notifyChanged() {
    final ValueChanged<BrushPreset>? onChanged = widget.onChanged;
    if (onChanged == null || !mounted) {
      return;
    }
    onChanged(buildPreset());
  }

  void _setAndNotify(VoidCallback update) {
    setState(update);
    _notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoLabel(
          label: l10n.brushPresetNameLabel,
          child: TextBox(
            controller: _nameController,
            onChanged: (_) => _notifyChanged(),
          ),
        ),
        const SizedBox(height: 12),
        InfoLabel(
          label: l10n.brushShape,
          child: ComboBox<BrushShape>(
            isExpanded: true,
            value: _shape,
            items: BrushShape.values
                .map(
                  (shape) => ComboBoxItem<BrushShape>(
                    value: shape,
                    child: Text(_shapeLabel(l10n, shape)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              _setAndNotify(() => _shape = value);
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
          onChanged: (value) => _setAndNotify(() => _randomRotation = value),
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
      ],
    );

    if (!widget.scrollable) {
      return content;
    }
    return SingleChildScrollView(child: content);
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
  }) {
    final FluentThemeData theme = FluentTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.typography.bodyStrong),
        const SizedBox(width: 12),
        ToggleSwitch(checked: value, onChanged: onChanged),
      ],
    );
  }

  String _shapeLabel(AppLocalizations l10n, BrushShape shape) {
    switch (shape) {
      case BrushShape.circle:
        return l10n.circle;
      case BrushShape.triangle:
        return l10n.triangle;
      case BrushShape.square:
        return l10n.square;
      case BrushShape.star:
        return l10n.star;
    }
  }
}
