import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import '../../canvas/canvas_settings.dart';
import '../l10n/l10n.dart';
import 'misarin_dialog.dart';

enum WorkspacePreset { none, illustration, celShading, pixel }

class NewProjectConfig {
  const NewProjectConfig({
    required this.name,
    required this.settings,
    required this.workspacePreset,
  });

  final String name;
  final CanvasSettings settings;
  final WorkspacePreset workspacePreset;
}

class _ResolutionPreset {
  const _ResolutionPreset({
    required this.width,
    required this.height,
    required this.label,
  });

  final int width;
  final int height;
  final String label;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ResolutionPreset &&
        other.width == width &&
        other.height == height &&
        other.label == label;
  }

  @override
  int get hashCode => Object.hash(width, height, label);
}

class _WorkspacePresetOption {
  const _WorkspacePresetOption({
    required this.preset,
    required this.title,
    required this.changes,
  });

  final WorkspacePreset preset;
  final String title;
  final List<String> changes;
}

Future<NewProjectConfig?> showCanvasSettingsDialog(
  BuildContext context, {
  CanvasSettings? initialSettings,
}) {
  return showDialog<NewProjectConfig>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _CanvasSettingsDialog(
      initialSettings: initialSettings ?? CanvasSettings.defaults,
    ),
  );
}

class _CanvasSettingsDialog extends StatefulWidget {
  const _CanvasSettingsDialog({required this.initialSettings});

  final CanvasSettings initialSettings;

  @override
  State<_CanvasSettingsDialog> createState() => _CanvasSettingsDialogState();
}

class _CanvasSettingsDialogState extends State<_CanvasSettingsDialog> {
  static const int _minDimension = 1;
  static const int _maxDimension = 16000;

  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  late final TextEditingController _nameController;
  late Color _selectedColor;
  _ResolutionPreset? _selectedPreset;
  WorkspacePreset _selectedWorkspacePreset = WorkspacePreset.none;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _widthController = TextEditingController(
      text: widget.initialSettings.width.round().toString(),
    );
    _heightController = TextEditingController(
      text: widget.initialSettings.height.round().toString(),
    );
    _widthController.addListener(_handleDimensionChanged);
    _heightController.addListener(_handleDimensionChanged);
    _nameController = TextEditingController();
    _selectedColor = widget.initialSettings.backgroundColor;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nameController.text.isEmpty) {
      _nameController.text = context.l10n.untitledProject;
    }
    // Refresh preset match when l10n changes or init
    final matched = _matchPreset(
      int.tryParse(_widthController.text) ?? 0,
      int.tryParse(_heightController.text) ?? 0,
    );
    if (matched != null && _selectedPreset == null) {
      _selectedPreset = matched;
    }
  }

  List<_ResolutionPreset> get _presets {
    final l10n = context.l10n;
    return <_ResolutionPreset>[
      _ResolutionPreset(width: 7680, height: 4320, label: '8K UHD (7680 × 4320)'),
      _ResolutionPreset(width: 3840, height: 2160, label: '4K UHD (3840 × 2160)'),
      _ResolutionPreset(width: 2560, height: 1440, label: 'QHD (2560 × 1440)'),
      _ResolutionPreset(width: 1920, height: 1080, label: 'FHD (1920 × 1080)'),
      _ResolutionPreset(width: 1600, height: 1200, label: 'UXGA (1600 × 1200)'),
      _ResolutionPreset(width: 1280, height: 720, label: 'HD (1280 × 720)'),
      _ResolutionPreset(
          width: 1080, height: 1920, label: l10n.presetMobilePortrait),
      _ResolutionPreset(width: 1024, height: 1024, label: l10n.presetSquare),
      _ResolutionPreset(
          width: 64, height: 64, label: l10n.presetPixelArt(64, 64)),
      _ResolutionPreset(
          width: 32, height: 32, label: l10n.presetPixelArt(32, 32)),
      _ResolutionPreset(
          width: 16, height: 16, label: l10n.presetPixelArt(16, 16)),
    ];
  }

  List<_WorkspacePresetOption> get _workspacePresets {
    final l10n = context.l10n;
    return <_WorkspacePresetOption>[
      _WorkspacePresetOption(
        preset: WorkspacePreset.illustration,
        title: l10n.workspaceIllustration,
        changes: <String>[l10n.workspaceIllustrationDesc],
      ),
      _WorkspacePresetOption(
        preset: WorkspacePreset.celShading,
        title: l10n.workspaceCelShading,
        changes: <String>[
          l10n.workspaceCelShadingDesc1,
          l10n.workspaceCelShadingDesc2,
          l10n.workspaceCelShadingDesc3
        ],
      ),
      _WorkspacePresetOption(
        preset: WorkspacePreset.pixel,
        title: l10n.workspacePixel,
        changes: <String>[
          l10n.workspacePixelDesc1,
          l10n.workspacePixelDesc2,
          l10n.workspacePixelDesc3
        ],
      ),
      _WorkspacePresetOption(
        preset: WorkspacePreset.none,
        title: l10n.workspaceDefault,
        changes: <String>[l10n.workspaceDefaultDesc],
      ),
    ];
  }

  @override
  void dispose() {
    _widthController.removeListener(_handleDimensionChanged);
    _heightController.removeListener(_handleDimensionChanged);
    _widthController.dispose();
    _heightController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final l10n = context.l10n;
    final int? width = int.tryParse(_widthController.text);
    final int? height = int.tryParse(_heightController.text);
    if (width == null || height == null) {
      setState(() => _errorMessage = l10n.invalidResolution);
      return;
    }
    if (width < _minDimension || height < _minDimension) {
      setState(
          () => _errorMessage = l10n.minResolutionError(_minDimension));
      return;
    }
    if (width > _maxDimension || height > _maxDimension) {
      setState(
          () => _errorMessage = l10n.maxResolutionError(_maxDimension));
      return;
    }

    final String rawName = _nameController.text.trim();
    final String resolvedName =
        rawName.isEmpty ? l10n.untitledProject : rawName;
    setState(() => _errorMessage = null);
    Navigator.of(context).pop(
      NewProjectConfig(
        name: resolvedName,
        settings: CanvasSettings(
          width: width.toDouble(),
          height: height.toDouble(),
          backgroundColor: _selectedColor,
        ),
        workspacePreset: _selectedWorkspacePreset,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final l10n = context.l10n;
    return MisarinDialog(
      title: Text(l10n.newCanvasSettingsTitle),
      contentWidth: 420,
      maxWidth: 520,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 620),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoLabel(
                label: l10n.projectName,
                child: TextBox(
                  controller: _nameController,
                  placeholder: l10n.untitledProject,
                ),
              ),
              const SizedBox(height: 12),
              InfoLabel(
                label: l10n.workspacePreset,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.workspacePresetDesc,
                      style:
                          theme.typography.caption ??
                          const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _workspacePresets
                          .map((option) => _buildPresetButton(theme, option))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    _buildPresetDescription(theme),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              InfoLabel(
                label: l10n.resolutionPreset,
                child: ComboBox<_ResolutionPreset?>(
                  isExpanded: true,
                  value: _selectedPreset,
                  items: [
                    ComboBoxItem<_ResolutionPreset?>(
                      value: null,
                      child: Text(l10n.custom),
                    ),
                    ..._presets.map(
                      (preset) => ComboBoxItem<_ResolutionPreset?>(
                        value: preset,
                        child: Text(preset.label),
                      ),
                    ),
                  ],
                  onChanged: (value) => _applyPreset(value),
                ),
              ),
              const SizedBox(height: 12),
              InfoLabel(
                label: l10n.customResolution,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormBox(
                        controller: _widthController,
                        placeholder: l10n.widthPx,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('×'),
                    ),
                    Expanded(
                      child: TextFormBox(
                        controller: _heightController,
                        placeholder: l10n.heightPx,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _sizePreviewText(),
                style:
                    theme.typography.caption ?? const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              InfoLabel(
                label: l10n.backgroundColor,
                child: ComboBox<Color>(
                  isExpanded: true,
                  icon: const Icon(FluentIcons.color),
                  value: _selectedColor,
                  items: [
                    ComboBoxItem(
                        value: const Color(0xFFFFFFFF),
                        child: Text(l10n.colorWhite)),
                    ComboBoxItem(
                        value: const Color(0xFFF5F5F5),
                        child: Text(l10n.colorLightGray)),
                    ComboBoxItem(
                        value: const Color(0xFF000000),
                        child: Text(l10n.colorBlack)),
                  ],
                  onChanged: (color) {
                    if (color == null) {
                      return;
                    }
                    setState(() => _selectedColor = color);
                  },
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.warningPrimaryColor),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _handleSubmit, child: Text(l10n.create)),
      ],
    );
  }

  void _applyPreset(_ResolutionPreset? preset) {
    setState(() => _selectedPreset = preset);
    if (preset == null) {
      return;
    }
    _widthController.text = preset.width.toString();
    _heightController.text = preset.height.toString();
  }

  void _handleDimensionChanged() {
    final int? width = int.tryParse(_widthController.text);
    final int? height = int.tryParse(_heightController.text);
    final _ResolutionPreset? matched = width == null || height == null
        ? null
        : _matchPreset(width, height);
    if (matched != _selectedPreset) {
      // Only update if matched logic returns something different,
      // but we need to match based on values of the _presets list which is now a getter.
      // So checking equality of content might be needed or just ref matching.
      // Since _presets returns new list every time, we should probably check content or ID.
      // Actually _presets content (ResolutionPreset objects) will be new instances.
      // I should cache presets or rely on value equality if I implement ==
      // For now, _matchPreset implementation iterates _presets.
      setState(() => _selectedPreset = matched);
    }
  }

  String _sizePreviewText() {
    final l10n = context.l10n;
    final int? width = int.tryParse(_widthController.text);
    final int? height = int.tryParse(_heightController.text);
    if (width == null || height == null || width <= 0 || height <= 0) {
      return l10n.enterValidDimensions;
    }
    final String ratio = _formatAspectRatio(width, height);
    return l10n.finalSizePreview(width, height, ratio);
  }

  _ResolutionPreset? _matchPreset(int width, int height) {
    if (width <= 0 || height <= 0) {
      return null;
    }
    for (final preset in _presets) {
      if (preset.width == width && preset.height == height) {
        return preset;
      }
    }
    return null;
  }

  String _formatAspectRatio(int width, int height) {
    final int gcd = _gcd(width, height);
    final int normalizedWidth = math.max(1, width ~/ gcd);
    final int normalizedHeight = math.max(1, height ~/ gcd);
    return '$normalizedWidth:$normalizedHeight';
  }

  int _gcd(int a, int b) {
    a = a.abs();
    b = b.abs();
    if (a == 0 && b == 0) {
      return 1;
    }
    if (b == 0) {
      return a == 0 ? 1 : a;
    }
    while (b != 0) {
      final int temp = a % b;
      a = b;
      b = temp;
    }
    return a == 0 ? 1 : a;
  }

  Widget _buildPresetButton(
    FluentThemeData theme,
    _WorkspacePresetOption option,
  ) {
    final bool selected = _selectedWorkspacePreset == option.preset;
    final ButtonStyle style = ButtonStyle(
      padding: WidgetStateProperty.all(const EdgeInsets.all(12)),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (selected) {
          return theme.accentColor.withOpacity(0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return theme.resources.controlFillColorSecondary;
        }
        return theme.resources.controlFillColorDefault;
      }),
      shape: WidgetStateProperty.all<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: selected
                ? theme.accentColor
                : theme.resources.controlStrokeColorDefault,
          ),
        ),
      ),
    );

    return Button(
      style: style,
      onPressed: () => setState(() {
        _selectedWorkspacePreset = option.preset;
      }),
      child: SizedBox(
        width: 100,
        child: Center(
          child: Text(option.title, style: theme.typography.bodyStrong),
        ),
      ),
    );
  }

  Widget _buildPresetDescription(FluentThemeData theme) {
    final l10n = context.l10n;
    final _WorkspacePresetOption option = _workspacePresets.firstWhere(
      (item) => item.preset == _selectedWorkspacePreset,
      orElse: () => _workspacePresets.last,
    );
    final TextStyle caption =
        theme.typography.caption ?? const TextStyle(fontSize: 12);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.resources.subtleFillColorTertiary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.currentPreset(option.title),
                style: theme.typography.bodyStrong),
            const SizedBox(height: 6),
            ...option.changes.map(
              (text) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(text, style: caption)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
