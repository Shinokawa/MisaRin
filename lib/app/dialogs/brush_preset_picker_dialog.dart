import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';

import '../../brushes/brush_library.dart';
import '../../brushes/brush_preset.dart';
import '../l10n/l10n.dart';
import '../widgets/brush_preset_stroke_preview.dart';
import 'misarin_dialog.dart';
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
  int _editorResetToken = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _presets = widget.library.presets;
    _selectedId = _resolveSelectedId(widget.selectedId, _presets);
    _syncDraftWithSelection();
    widget.library.addListener(_handleLibraryChanged);
    _refreshShapes();
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

  void _refreshShapes() {
    widget.library.shapeLibrary.refresh().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
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

  Future<void> _deleteSelected() async {
    final BrushPreset? preset = _selectedPreset;
    if (preset == null) {
      return;
    }
    await widget.library.removePreset(preset.id);
  }

  Future<void> _resetSelectedToDefault() async {
    final BrushPreset? preset = _selectedPreset;
    if (preset == null) {
      return;
    }
    await widget.library.resetPreset(preset.id);
    setState(() {
      _selectedId = preset.id;
      _draftPreset = widget.library.selectedPreset.sanitized();
      _editorResetToken += 1;
    });
  }

  Future<void> _duplicateSelected() async {
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
      smoothRotation: preset.smoothRotation,
      rotationJitter: preset.rotationJitter,
      antialiasLevel: preset.antialiasLevel,
      hollowEnabled: preset.hollowEnabled,
      hollowRatio: preset.hollowRatio,
      hollowEraseOccludedParts: preset.hollowEraseOccludedParts,
      autoSharpTaper: preset.autoSharpTaper,
      snapToPixel: preset.snapToPixel,
      author: preset.author,
      version: preset.version,
      shapeId: preset.shapeId,
    );
    await widget.library.addPreset(copy);
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

  Future<void> _confirm() async {
    if (_selectedId.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final bool ok = await _promptSaveIfNeeded();
    if (!ok) {
      return;
    }
    Navigator.of(context).pop(_selectedId);
  }

  bool _hasUnsavedChanges() {
    final BrushPreset? selected = _selectedPreset;
    final BrushPreset? draft = _draftPreset;
    if (selected == null || draft == null) {
      return false;
    }
    return !draft.isSameAs(selected);
  }

  Future<bool> _promptSaveIfNeeded() async {
    if (!_hasUnsavedChanges()) {
      return true;
    }
    final AppLocalizations l10n = context.l10n;
    final bool? shouldSave = await showMisarinDialog<bool>(
      context: context,
      title: Text(l10n.brushPreset),
      content: Text(l10n.unsavedBrushChangesPrompt),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.discardChanges),
        ),
        Button(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.save),
        ),
      ],
    );
    if (shouldSave == null) {
      return false;
    }
    if (shouldSave) {
      _saveDraft();
    }
    return true;
  }

  Future<void> _importBrush() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [BrushLibrary.brushFileExtension],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    BrushPreset? imported;
    if (kIsWeb) {
      final Uint8List? bytes = result.files.single.bytes;
      if (bytes == null) {
        return;
      }
      imported = await widget.library.importBrushBytes(bytes);
    } else {
      final String? path = result.files.single.path;
      if (path == null) {
        return;
      }
      imported = await widget.library.importBrushFile(path);
    }
    if (imported == null) {
      return;
    }
    setState(() {
      _selectedId = imported!.id;
      _syncDraftWithSelection(imported.id);
    });
    _scrollToId(imported.id);
  }

  Future<void> _exportBrush() async {
    final BrushPreset? preset = _selectedPreset;
    if (preset == null) {
      return;
    }
    final String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: context.l10n.exportBrushTitle,
      fileName: '${preset.name}.${BrushLibrary.brushFileExtension}',
      type: FileType.custom,
      allowedExtensions: [BrushLibrary.brushFileExtension],
    );
    if (outputPath == null) {
      return;
    }
    await widget.library.exportBrush(preset.id, outputPath);
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
    final bool isBuiltInPreset =
        selected != null && widget.library.isBuiltInPreset(selected.id);
    final bool canDelete =
        selected != null && !isBuiltInPreset && _presets.length > 1;
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
                            child: BrushPresetStrokePreview(
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
                BrushPresetStrokePreview(
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
          onPressed: selected == null ? null : _resetSelectedToDefault,
          child: Text(l10n.reset),
        ),
        if (!isBuiltInPreset) ...[
          const SizedBox(width: 8),
          Button(
            onPressed: canDelete ? _deleteSelected : null,
            child: Text(l10n.delete),
          ),
        ],
        const SizedBox(width: 8),
        Button(
          onPressed: selected == null ? null : _duplicateSelected,
          child: Text(l10n.duplicate),
        ),
        const SizedBox(width: 8),
        Button(
          onPressed: _importBrush,
          child: Text(l10n.importBrush),
        ),
        const SizedBox(width: 8),
        Button(
          onPressed: selected == null ? null : _exportBrush,
          child: Text(l10n.exportBrush),
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
            key: ValueKey<String?>('${selected?.id}-${_editorResetToken}'),
            preset: previewPreset ?? selected,
            scrollable: false,
            onChanged: _handleDraftChanged,
          );

    final Widget editorBody = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                previewArea,
                const SizedBox(height: 12),
                Expanded(child: editorBody),
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
          onPressed: () async {
            final bool ok = await _promptSaveIfNeeded();
            if (!ok) {
              return;
            }
            if (!mounted) {
              return;
            }
            Navigator.of(context).pop();
          },
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _confirm,
          child: Text(l10n.confirm),
        ),
      ],
    );
  }

}
