import 'package:fluent_ui/fluent_ui.dart';

import '../../brushes/brush_preset.dart';
import '../../canvas/canvas_tools.dart' show BrushShape;
import '../dialogs/misarin_dialog.dart';
import '../l10n/l10n.dart';

Future<BrushPreset?> showBrushPresetEditorDialog(
  BuildContext context, {
  required BrushPreset preset,
}) {
  final GlobalKey<_BrushPresetEditorState> editorKey =
      GlobalKey<_BrushPresetEditorState>();
  final AppLocalizations l10n = context.l10n;
  return showMisarinDialog<BrushPreset>(
    context: context,
    title: Text(l10n.brushPresetDialogTitle),
    content: _BrushPresetEditor(key: editorKey, preset: preset),
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

class _BrushPresetEditor extends StatefulWidget {
  const _BrushPresetEditor({super.key, required this.preset});

  final BrushPreset preset;

  @override
  State<_BrushPresetEditor> createState() => _BrushPresetEditorState();
}

class _BrushPresetEditorState extends State<_BrushPresetEditor> {
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
    final BrushPreset preset = widget.preset.sanitized();
    _nameController = TextEditingController(text: preset.name);
    _shape = preset.shape;
    _spacing = preset.spacing;
    _hardness = preset.hardness;
    _flow = preset.flow;
    _scatter = preset.scatter;
    _randomRotation = preset.randomRotation;
    _rotationJitter = preset.rotationJitter;
    _antialiasLevel = preset.antialiasLevel;
    _hollowEnabled = preset.hollowEnabled;
    _hollowRatio = preset.hollowRatio;
    _hollowEraseOccludedParts = preset.hollowEraseOccludedParts;
    _autoSharpTaper = preset.autoSharpTaper;
    _snapToPixel = preset.snapToPixel;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoLabel(
            label: l10n.brushPresetNameLabel,
            child: TextBox(controller: _nameController),
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
                setState(() => _shape = value);
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
            onChanged: (value) => setState(() => _spacing = value),
          ),
          const SizedBox(height: 12),
          _buildPercentSlider(
            context,
            label: l10n.brushHardness,
            value: _hardness,
            onChanged: (value) => setState(() => _hardness = value),
          ),
          const SizedBox(height: 12),
          _buildPercentSlider(
            context,
            label: l10n.brushFlow,
            value: _flow,
            onChanged: (value) => setState(() => _flow = value),
          ),
          const SizedBox(height: 12),
          _buildPercentSlider(
            context,
            label: l10n.brushScatter,
            value: _scatter,
            onChanged: (value) => setState(() => _scatter = value),
          ),
          const SizedBox(height: 12),
          _buildToggleRow(
            context,
            label: l10n.randomRotation,
            value: _randomRotation,
            onChanged: (value) => setState(() => _randomRotation = value),
          ),
          const SizedBox(height: 12),
          _buildPercentSlider(
            context,
            label: l10n.brushRotationJitter,
            value: _rotationJitter,
            enabled: _randomRotation,
            onChanged: (value) => setState(() => _rotationJitter = value),
          ),
          const SizedBox(height: 12),
          _buildAntialiasSlider(context),
          const SizedBox(height: 12),
          _buildToggleRow(
            context,
            label: l10n.hollowStroke,
            value: _hollowEnabled,
            onChanged: (value) => setState(() => _hollowEnabled = value),
          ),
          if (_hollowEnabled) ...[
            const SizedBox(height: 12),
            _buildPercentSlider(
              context,
              label: l10n.hollowStrokeRatio,
              value: _hollowRatio,
              onChanged: (value) => setState(() => _hollowRatio = value),
            ),
            const SizedBox(height: 12),
            _buildToggleRow(
              context,
              label: l10n.eraseOccludedParts,
              value: _hollowEraseOccludedParts,
              onChanged: (value) =>
                  setState(() => _hollowEraseOccludedParts = value),
            ),
          ],
          const SizedBox(height: 12),
          _buildToggleRow(
            context,
            label: l10n.autoSharpTaper,
            value: _autoSharpTaper,
            onChanged: (value) => setState(() => _autoSharpTaper = value),
          ),
          const SizedBox(height: 12),
          _buildToggleRow(
            context,
            label: l10n.brushSnapToPixel,
            value: _snapToPixel,
            onChanged: (value) => setState(() => _snapToPixel = value),
          ),
        ],
      ),
    );
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
          setState(() => _antialiasLevel = value.round()),
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
