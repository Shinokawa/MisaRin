import 'package:fluent_ui/fluent_ui.dart';

import '../../canvas/canvas_settings.dart';
import 'misarin_dialog.dart';

class NewProjectConfig {
  const NewProjectConfig({
    required this.name,
    required this.settings,
  });

  final String name;
  final CanvasSettings settings;
}

class _CanvasPreset {
  const _CanvasPreset({
    required this.width,
    required this.height,
    this.note,
  });

  final int width;
  final int height;
  final String? note;

  String get displayLabel {
    if (note == null || note!.isEmpty) {
      return '$width × $height';
    }
    return '$width × $height（$note）';
  }

  bool matches(double width, double height) {
    return width.round() == this.width && height.round() == this.height;
  }
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
  static const List<_CanvasPreset> _presets = [
    _CanvasPreset(width: 1280, height: 720, note: '横向'),
    _CanvasPreset(width: 720, height: 1280, note: '纵向'),
    _CanvasPreset(width: 1920, height: 1080, note: '横向'),
    _CanvasPreset(width: 1080, height: 1920, note: '纵向'),
    _CanvasPreset(width: 2560, height: 1440, note: '横向'),
    _CanvasPreset(width: 1440, height: 2560, note: '纵向'),
    _CanvasPreset(width: 3840, height: 2160, note: '横向'),
    _CanvasPreset(width: 2160, height: 3840, note: '纵向'),
    _CanvasPreset(width: 256, height: 256, note: '正方形'),
    _CanvasPreset(width: 512, height: 512, note: '正方形'),
    _CanvasPreset(width: 1024, height: 1024, note: '正方形'),
  ];
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  late final TextEditingController _nameController;
  late Color _selectedColor;
  _CanvasPreset? _selectedPreset;
  String? _errorMessage;
  bool _isUpdatingPreset = false;

  @override
  void initState() {
    super.initState();
    _widthController = TextEditingController(
      text: widget.initialSettings.width.toStringAsFixed(0),
    );
    _heightController = TextEditingController(
      text: widget.initialSettings.height.toStringAsFixed(0),
    );
    _nameController = TextEditingController(text: '未命名项目');
    _widthController.addListener(_handleDimensionChanged);
    _heightController.addListener(_handleDimensionChanged);
    _selectedColor = widget.initialSettings.backgroundColor;
    _selectedPreset = _matchPreset(
      widget.initialSettings.width,
      widget.initialSettings.height,
    );
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
    final double? width = double.tryParse(_widthController.text);
    final double? height = double.tryParse(_heightController.text);
    if (width == null || height == null) {
      setState(() => _errorMessage = '请输入有效的宽度与高度');
      return;
    }
    if (width <= 0 || height <= 0) {
      setState(() => _errorMessage = '宽度与高度必须大于 0');
      return;
    }
    final String rawName = _nameController.text.trim();
    final String resolvedName = rawName.isEmpty ? '未命名项目' : rawName;
    Navigator.of(context).pop(
      NewProjectConfig(
        name: resolvedName,
        settings: CanvasSettings(
          width: width,
          height: height,
          backgroundColor: _selectedColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MisarinDialog(
      title: const Text('新建画布设置'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoLabel(
            label: '项目名称',
            child: TextBox(
              controller: _nameController,
              placeholder: '未命名项目',
            ),
          ),
          const SizedBox(height: 12),
          InfoLabel(
            label: '选择预设',
            child: ComboBox<_CanvasPreset?>(
              isExpanded: true,
              value: _selectedPreset,
              items: [
                const ComboBoxItem<_CanvasPreset?>(
                  value: null,
                  child: Text('自定义'),
                ),
                ..._buildPresetItems(),
              ],
              onChanged: _handlePresetChanged,
            ),
          ),
          const SizedBox(height: 12),
          InfoLabel(
            label: '画布宽度 (像素)',
            child: TextBox(
              controller: _widthController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          InfoLabel(
            label: '画布高度 (像素)',
            child: TextBox(
              controller: _heightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          InfoLabel(
            label: '背景颜色',
            child: ComboBox<Color>(
              isExpanded: true,
              icon: const Icon(FluentIcons.color),
              value: _selectedColor,
              items: const [
                ComboBoxItem(value: Color(0xFFFFFFFF), child: Text('白色')),
                ComboBoxItem(value: Color(0xFFF5F5F5), child: Text('浅灰')),
                ComboBoxItem(value: Color(0xFF000000), child: Text('黑色')),
              ],
              onChanged: (color) {
                if (color == null) return;
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
      contentWidth: 420,
      maxWidth: 520,
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _handleSubmit, child: const Text('创建')),
      ],
    );
  }

  List<ComboBoxItem<_CanvasPreset?>> _buildPresetItems() {
    return _presets
        .map(
          (preset) => ComboBoxItem<_CanvasPreset?>(
            value: preset,
            child: Text(preset.displayLabel),
          ),
        )
        .toList(growable: false);
  }

  void _handlePresetChanged(_CanvasPreset? preset) {
    if (preset == null) {
      setState(() => _selectedPreset = null);
      return;
    }
    setState(() => _selectedPreset = preset);
    _isUpdatingPreset = true;
    _widthController.text = preset.width.toString();
    _heightController.text = preset.height.toString();
    _isUpdatingPreset = false;
  }

  void _handleDimensionChanged() {
    if (_isUpdatingPreset) {
      return;
    }
    final double? width = double.tryParse(_widthController.text);
    final double? height = double.tryParse(_heightController.text);
    if (width == null || height == null) {
      if (_selectedPreset != null) {
        setState(() => _selectedPreset = null);
      }
      return;
    }
    final _CanvasPreset? matched = _matchPreset(width, height);
    if (matched == _selectedPreset) {
      return;
    }
    setState(() => _selectedPreset = matched);
  }

  _CanvasPreset? _matchPreset(double width, double height) {
    for (final preset in _presets) {
      if (preset.matches(width, height)) {
        return preset;
      }
    }
    return null;
  }
}
