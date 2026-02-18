import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';

import '../../brushes/brush_library.dart';
import '../../brushes/brush_preset.dart';
import '../../canvas/brush_shape_geometry.dart';
import '../../canvas/canvas_tools.dart';
import '../l10n/l10n.dart';
import 'brush_preset_editor_dialog.dart';

Future<String?> showBrushPresetPickerDialog(
  BuildContext context, {
  required BrushLibrary library,
  required String selectedId,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _BrushPresetPickerDialog(
      library: library,
      selectedId: selectedId,
    ),
  );
}

class _BrushPresetPickerDialog extends StatefulWidget {
  const _BrushPresetPickerDialog({
    required this.library,
    required this.selectedId,
  });

  final BrushLibrary library;
  final String selectedId;

  @override
  State<_BrushPresetPickerDialog> createState() =>
      _BrushPresetPickerDialogState();
}

class _BrushPresetPickerDialogState extends State<_BrushPresetPickerDialog> {
  late final ScrollController _scrollController;
  late List<BrushPreset> _presets;
  late String _selectedId;
  BrushPreset? _draftPreset;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _presets = widget.library.presets;
    _selectedId = _resolveSelectedId(widget.selectedId, _presets);
    _syncDraftWithSelection();
    widget.library.addListener(_handleLibraryChanged);
  }

  @override
  void dispose() {
    widget.library.removeListener(_handleLibraryChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleLibraryChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _presets = widget.library.presets;
      _selectedId = _resolveSelectedId(_selectedId, _presets);
      _syncDraftWithSelection();
    });
  }

  String _resolveSelectedId(String desired, List<BrushPreset> presets) {
    if (presets.any((preset) => preset.id == desired)) {
      return desired;
    }
    return presets.isNotEmpty ? presets.first.id : '';
  }

  BrushPreset? get _selectedPreset {
    if (_presets.isEmpty) {
      return null;
    }
    for (final BrushPreset preset in _presets) {
      if (preset.id == _selectedId) {
        return preset;
      }
    }
    return _presets.first;
  }

  BrushPreset? _presetForId(String id) {
    for (final BrushPreset preset in _presets) {
      if (preset.id == id) {
        return preset;
      }
    }
    return null;
  }

  void _syncDraftWithSelection([String? id]) {
    final BrushPreset? preset = _presetForId(id ?? _selectedId);
    _draftPreset = preset?.sanitized();
  }

  void _selectPreset(String id) {
    if (_selectedId == id) {
      return;
    }
    setState(() {
      _selectedId = id;
      _syncDraftWithSelection(id);
    });
  }

  void _handleDraftChanged(BrushPreset preset) {
    if (!mounted) {
      return;
    }
    if (preset.id != _selectedId) {
      return;
    }
    setState(() => _draftPreset = preset.sanitized());
  }

  void _saveDraft() {
    final BrushPreset? updated = _draftPreset ?? _selectedPreset;
    if (updated == null) {
      return;
    }
    widget.library.updatePreset(updated);
    setState(() {
      _selectedId = updated.id;
      _draftPreset = updated.sanitized();
    });
  }

  void _duplicateSelected() {
    final BrushPreset? preset = _selectedPreset;
    if (preset == null) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final String baseName = l10n.layerCopyName(preset.name);
    final String name = _uniqueName(baseName);
    final String id = _uniqueId('${preset.id}_copy');
    final BrushPreset copy = BrushPreset(
      id: id,
      name: name,
      shape: preset.shape,
      spacing: preset.spacing,
      hardness: preset.hardness,
      flow: preset.flow,
      scatter: preset.scatter,
      randomRotation: preset.randomRotation,
      rotationJitter: preset.rotationJitter,
      antialiasLevel: preset.antialiasLevel,
      hollowEnabled: preset.hollowEnabled,
      hollowRatio: preset.hollowRatio,
      hollowEraseOccludedParts: preset.hollowEraseOccludedParts,
      autoSharpTaper: preset.autoSharpTaper,
      snapToPixel: preset.snapToPixel,
    );
    widget.library.addPreset(copy);
    setState(() => _selectedId = id);
    _scrollToId(id);
  }

  String _uniqueId(String base) {
    final Set<String> ids = _presets.map((preset) => preset.id).toSet();
    if (!ids.contains(base)) {
      return base;
    }
    int counter = 2;
    while (ids.contains('${base}_$counter')) {
      counter += 1;
    }
    return '${base}_$counter';
  }

  String _uniqueName(String base) {
    final Set<String> names = _presets.map((preset) => preset.name).toSet();
    if (!names.contains(base)) {
      return base;
    }
    int counter = 2;
    while (names.contains('$base $counter')) {
      counter += 1;
    }
    return '$base $counter';
  }

  void _scrollToId(String id) {
    if (!_scrollController.hasClients) {
      return;
    }
    final int index =
        _presets.indexWhere((preset) => preset.id == id);
    if (index < 0) {
      return;
    }
    _scrollController.animateTo(
      math.min(
        _scrollController.position.maxScrollExtent,
        index * _listItemExtent,
      ),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _confirm() {
    if (_selectedId.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(_selectedId);
  }

  static const double _listItemExtent = 56;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final AppLocalizations l10n = context.l10n;
    final BrushPreset? selected = _selectedPreset;
    final BrushPreset? previewPreset =
        (_draftPreset != null && _draftPreset?.id == selected?.id)
            ? _draftPreset
            : selected;
    final Color selectedBackground =
        theme.accentColor.defaultBrushFor(theme.brightness);
    final Color selectedForeground =
        theme.resources.textOnAccentFillColorPrimary;

    final Widget presetList = Container(
      decoration: BoxDecoration(
        color: theme.resources.controlFillColorDefault,
        border: Border.all(color: theme.resources.controlStrokeColorDefault),
        borderRadius: BorderRadius.circular(6),
      ),
      child: _presets.isEmpty
          ? Center(
              child: Text(
                '--',
                style: theme.typography.caption,
                textAlign: TextAlign.center,
              ),
            )
          : Scrollbar(
              controller: _scrollController,
              child: ListView.builder(
                controller: _scrollController,
                itemExtent: _listItemExtent,
                itemCount: _presets.length,
                itemBuilder: (context, index) {
                  final BrushPreset preset = _presets[index];
                  final bool isSelected = preset.id == _selectedId;
                  final Color foreground = isSelected
                      ? selectedForeground
                      : theme.typography.body?.color ??
                          theme.resources.textFillColorPrimary;
                  return GestureDetector(
                    onDoubleTap: () {
                      _selectPreset(preset.id);
                      _confirm();
                    },
                    child: Button(
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all<EdgeInsets>(
                          const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                          (states) {
                            if (isSelected) {
                              return selectedBackground;
                            }
                            if (states.contains(WidgetState.hovered)) {
                              return theme.resources.controlFillColorSecondary;
                            }
                            return Colors.transparent;
                          },
                        ),
                      ),
                      onPressed: () => _selectPreset(preset.id),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: _BrushPresetStrokePreview(
                              preset: preset,
                              height: 24,
                              color: foreground,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              preset.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.body?.copyWith(
                                color: foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );

    final Widget previewArea = Container(
      decoration: BoxDecoration(
        color: theme.resources.controlFillColorSecondary,
        border: Border.all(color: theme.resources.controlStrokeColorDefault),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(12),
      child: previewPreset == null
          ? Center(child: Text('--', style: theme.typography.caption))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BrushPresetStrokePreview(
                  preset: previewPreset,
                  height: 120,
                  color: theme.resources.textFillColorPrimary,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.brushPresetDesc,
                  style: theme.typography.caption,
                ),
              ],
            ),
    );

    final Widget actionsRow = Row(
      children: [
        Button(
          onPressed: selected == null ? null : _duplicateSelected,
          child: Text(l10n.duplicate),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: selected == null ? null : _saveDraft,
          child: Text(l10n.save),
        ),
      ],
    );

    final Widget editorContent = selected == null
        ? Text('--', style: theme.typography.caption)
        : BrushPresetEditorForm(
            key: ValueKey<String?>(selected?.id),
            preset: previewPreset ?? selected,
            scrollable: false,
            onChanged: _handleDraftChanged,
          );

    final Widget rightBody = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          previewArea,
          const SizedBox(height: 16),
          Text(l10n.editBrushPreset, style: theme.typography.caption),
          const SizedBox(height: 4),
          Text(l10n.editBrushPresetDesc, style: theme.typography.caption),
          const SizedBox(height: 8),
          editorContent,
        ],
      ),
    );

    final Widget content = SizedBox(
      width: 820,
      height: 560,
      child: Row(
        children: [
          SizedBox(
            width: 320,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.brushPreset,
                    style: theme.typography.caption,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: presetList),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected?.name ?? '--',
                  style: theme.typography.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                actionsRow,
                const SizedBox(height: 12),
                Expanded(child: rightBody),
              ],
            ),
          ),
        ],
      ),
    );

    return ContentDialog(
      title: Text(l10n.brushPreset),
      constraints: const BoxConstraints(maxWidth: 860),
      content: content,
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _confirm, child: Text(l10n.confirm)),
      ],
    );
  }

}

class _BrushPresetStrokePreview extends StatelessWidget {
  const _BrushPresetStrokePreview({
    required this.preset,
    required this.height,
    required this.color,
  });

  final BrushPreset preset;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _BrushPresetStrokePainter(preset: preset, color: color),
      ),
    );
  }
}

class _BrushPresetStrokePainter extends CustomPainter {
  _BrushPresetStrokePainter({
    required BrushPreset preset,
    required this.color,
  })  : shape = preset.shape,
        spacing = _sanitizeDouble(preset.spacing, 0.15, 0.02, 2.5),
        hardness = _sanitizeDouble(preset.hardness, 0.8, 0.0, 1.0),
        flow = _sanitizeDouble(preset.flow, 1.0, 0.0, 1.0),
        scatter = _sanitizeDouble(preset.scatter, 0.0, 0.0, 1.0),
        randomRotation = preset.randomRotation,
        rotationJitter = _sanitizeDouble(preset.rotationJitter, 1.0, 0.0, 1.0),
        antialiasLevel = preset.antialiasLevel.clamp(0, 9),
        hollowEnabled = preset.hollowEnabled,
        hollowRatio = _sanitizeDouble(preset.hollowRatio, 0.0, 0.0, 1.0),
        autoSharpTaper = preset.autoSharpTaper,
        snapToPixel = preset.snapToPixel;

  final Color color;
  final BrushShape shape;
  final double spacing;
  final double hardness;
  final double flow;
  final double scatter;
  final bool randomRotation;
  final double rotationJitter;
  final int antialiasLevel;
  final bool hollowEnabled;
  final double hollowRatio;
  final bool autoSharpTaper;
  final bool snapToPixel;

  static double _sanitizeDouble(
    double value,
    double fallback,
    double min,
    double max,
  ) {
    if (!value.isFinite) {
      return fallback;
    }
    return value.clamp(min, max);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final double padding = 4;
    final double width = size.width - padding * 2;
    final double height = size.height - padding * 2;
    if (width <= 0 || height <= 0) {
      return;
    }

    final Offset start = Offset(padding, padding + height * 0.65);
    final Offset control1 =
        Offset(padding + width * 0.3, padding + height * 0.1);
    final Offset control2 =
        Offset(padding + width * 0.65, padding + height * 0.9);
    final Offset end = Offset(padding + width, padding + height * 0.35);

    final ui.Path path = ui.Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        end.dx,
        end.dy,
      );
    final ui.PathMetrics metrics = path.computeMetrics();
    final Iterator<ui.PathMetric> iterator = metrics.iterator;
    if (!iterator.moveNext()) {
      return;
    }
    final ui.PathMetric metric = iterator.current;

    final double baseRadius = math.max(2.2, height * 0.2);
    final double step = math.max(0.1, baseRadius * 2.0 * spacing);
    final double totalLength = metric.length;
    final int maxStamps = math.max(6, (totalLength / step).ceil());

    final double opacity = (0.25 + 0.75 * flow * (0.35 + 0.65 * hardness))
        .clamp(0.18, 1.0);
    final Color strokeColor = color.withOpacity(
      (color.opacity * opacity).clamp(0.0, 1.0),
    );
    final Paint paint = Paint()
      ..color = strokeColor
      ..style = hollowEnabled ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = hollowEnabled
          ? math.max(1.0, baseRadius * (1.0 - hollowRatio).clamp(0.2, 0.9))
          : 1.0
      ..isAntiAlias = antialiasLevel > 0;

    for (int i = 0; i <= maxStamps; i++) {
      final double distance = math.min(totalLength, i * step);
      final ui.Tangent? tangent = metric.getTangentForOffset(distance);
      if (tangent == null) {
        continue;
      }
      double radius = baseRadius;
      if (autoSharpTaper) {
        final double t = distance / totalLength;
        radius *= (0.5 + 0.5 * math.sin(math.pi * t));
      }
      if (!radius.isFinite || radius <= 0.0) {
        continue;
      }

      Offset position = tangent.position;
      if (scatter > 0.0) {
        final double scatterRadius = radius * 2.0 * scatter;
        if (scatterRadius > 0.0001) {
          final double u = _noise(i + 3);
          final double v = _noise(i + 7);
          final double dist = math.sqrt(u) * scatterRadius;
          final double angle = v * math.pi * 2.0;
          position = position.translate(
            math.cos(angle) * dist,
            math.sin(angle) * dist,
          );
        }
      }
      if (snapToPixel) {
        position = Offset(
          position.dx.floor() + 0.5,
          position.dy.floor() + 0.5,
        );
        radius = (radius * 2.0).round() * 0.5;
        if (radius <= 0.0) {
          continue;
        }
      }

      double rotation = 0.0;
      if (shape != BrushShape.circle) {
        rotation = math.atan2(tangent.vector.dy, tangent.vector.dx);
      }
      if (randomRotation) {
        rotation = _noise(i + 11) * math.pi * 2;
      } else if (rotationJitter > 0.001) {
        rotation += rotationJitter * 0.6 * math.sin(i * 0.7);
      }

      canvas.save();
      canvas.translate(position.dx, position.dy);
      if (rotation != 0.0) {
        canvas.rotate(rotation);
      }
      final ui.Path stamp = BrushShapeGeometry.pathFor(
        shape,
        Offset.zero,
        radius,
      );
      canvas.drawPath(stamp, paint);
      canvas.restore();
    }
  }

  double _noise(int seed) {
    final double value = math.sin(seed * 12.9898 + 78.233) * 43758.5453;
    return value - value.floor();
  }

  @override
  bool shouldRepaint(covariant _BrushPresetStrokePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.shape != shape ||
        oldDelegate.spacing != spacing ||
        oldDelegate.hardness != hardness ||
        oldDelegate.flow != flow ||
        oldDelegate.scatter != scatter ||
        oldDelegate.randomRotation != randomRotation ||
        oldDelegate.rotationJitter != rotationJitter ||
        oldDelegate.antialiasLevel != antialiasLevel ||
        oldDelegate.hollowEnabled != hollowEnabled ||
        oldDelegate.hollowRatio != hollowRatio ||
        oldDelegate.autoSharpTaper != autoSharpTaper ||
        oldDelegate.snapToPixel != snapToPixel;
  }
}
