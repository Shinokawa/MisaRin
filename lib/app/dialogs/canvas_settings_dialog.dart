import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import '../../canvas/canvas_settings.dart';
import 'misarin_dialog.dart';

class NewProjectConfig {
  const NewProjectConfig({required this.name, required this.settings});

  final String name;
  final CanvasSettings settings;
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
  static const List<_ResolutionPreset> _presets = <_ResolutionPreset>[
    _ResolutionPreset(width: 7680, height: 4320, label: '8K UHD (7680 × 4320)'),
    _ResolutionPreset(width: 3840, height: 2160, label: '4K UHD (3840 × 2160)'),
    _ResolutionPreset(width: 2560, height: 1440, label: 'QHD (2560 × 1440)'),
    _ResolutionPreset(width: 1920, height: 1080, label: 'FHD (1920 × 1080)'),
    _ResolutionPreset(width: 1600, height: 1200, label: 'UXGA (1600 × 1200)'),
    _ResolutionPreset(width: 1280, height: 720, label: 'HD (1280 × 720)'),
    _ResolutionPreset(width: 1080, height: 1920, label: '移动端纵向 (1080 × 1920)'),
    _ResolutionPreset(width: 1024, height: 1024, label: '方形 (1024 × 1024)'),
  ];

  static const int _minDimension = 64;
  static const int _maxDimension = 16000;

  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  late final TextEditingController _nameController;
  late Color _selectedColor;
  late CanvasCreationLogic _selectedCreationLogic;
  _ResolutionPreset? _selectedPreset;
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
    _nameController = TextEditingController(text: '未命名项目');
    _selectedColor = widget.initialSettings.backgroundColor;
    _selectedCreationLogic = widget.initialSettings.creationLogic;
    _selectedPreset = _matchPreset(
      widget.initialSettings.width.round(),
      widget.initialSettings.height.round(),
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
    final int? width = int.tryParse(_widthController.text);
    final int? height = int.tryParse(_heightController.text);
    if (width == null || height == null) {
      setState(() => _errorMessage = '请输入有效的分辨率');
      return;
    }
    if (width < _minDimension || height < _minDimension) {
      setState(() => _errorMessage = '分辨率不能小于 $_minDimension 像素');
      return;
    }
    if (width > _maxDimension || height > _maxDimension) {
      setState(() => _errorMessage = '分辨率不能超过 $_maxDimension 像素');
      return;
    }

    final String rawName = _nameController.text.trim();
    final String resolvedName = rawName.isEmpty ? '未命名项目' : rawName;
    setState(() => _errorMessage = null);
    Navigator.of(context).pop(
      NewProjectConfig(
        name: resolvedName,
        settings: CanvasSettings(
          width: width.toDouble(),
          height: height.toDouble(),
          backgroundColor: _selectedColor,
          creationLogic: _selectedCreationLogic,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return MisarinDialog(
      title: const Text('新建画布设置'),
      contentWidth: 420,
      maxWidth: 520,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoLabel(
            label: '项目名称',
            child: TextBox(controller: _nameController, placeholder: '未命名项目'),
          ),
          const SizedBox(height: 12),
          InfoLabel(
            label: '分辨率预设',
            child: ComboBox<_ResolutionPreset?>(
              isExpanded: true,
              value: _selectedPreset,
              items: [
                const ComboBoxItem<_ResolutionPreset?>(
                  value: null,
                  child: Text('自定义'),
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
            label: '自定义分辨率',
            child: Row(
              children: [
                Expanded(
                  child: TextFormBox(
                    controller: _widthController,
                    placeholder: '宽度（像素）',
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
                    placeholder: '高度（像素）',
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
            style: theme.typography.caption ?? const TextStyle(fontSize: 12),
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
                if (color == null) {
                  return;
                }
                setState(() => _selectedColor = color);
              },
            ),
          ),
          const SizedBox(height: 12),
          InfoLabel(
            label: '画布创建逻辑',
            child: ComboBox<CanvasCreationLogic>(
              isExpanded: true,
              value: _selectedCreationLogic,
              items: CanvasCreationLogic.values
                  .map(
                    (logic) => ComboBoxItem<CanvasCreationLogic>(
                      value: logic,
                      child: Text(_creationLogicLabel(logic)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCreationLogic = value);
                }
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
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _handleSubmit, child: const Text('创建')),
      ],
    );
  }

  String _creationLogicLabel(CanvasCreationLogic logic) {
    switch (logic) {
      case CanvasCreationLogic.singleThread:
        return '单线程（稳定）';
      case CanvasCreationLogic.multiThread:
        return '多线程（实验性）';
    }
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
    final _ResolutionPreset? matched =
        width == null || height == null ? null : _matchPreset(width, height);
    if (matched != _selectedPreset) {
      setState(() => _selectedPreset = matched);
    }
  }

  String _sizePreviewText() {
    final int? width = int.tryParse(_widthController.text);
    final int? height = int.tryParse(_heightController.text);
    if (width == null || height == null || width <= 0 || height <= 0) {
      return '请输入有效的宽高数值';
    }
    final String ratio = _formatAspectRatio(width, height);
    return '最终尺寸：$width × $height 像素（比例 $ratio）';
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
}
