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

class _AspectRatioPreset {
  const _AspectRatioPreset({
    required this.width,
    required this.height,
    required this.label,
  });

  final int width;
  final int height;
  final String label;

  double get aspectRatio => width / height;
}

class _RatioPair {
  const _RatioPair(this.width, this.height);

  final int width;
  final int height;
}

class _SizePair {
  const _SizePair(this.width, this.height);

  final double width;
  final double height;
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
  static const double _baseLongSide = 1920.0;
  static const double _ratioTolerance = 0.01;

  static const List<_AspectRatioPreset> _presets = <_AspectRatioPreset>[
    _AspectRatioPreset(width: 16, height: 9, label: '16 : 9（横向）'),
    _AspectRatioPreset(width: 9, height: 16, label: '9 : 16（纵向）'),
    _AspectRatioPreset(width: 4, height: 3, label: '4 : 3'),
    _AspectRatioPreset(width: 3, height: 4, label: '3 : 4'),
    _AspectRatioPreset(width: 3, height: 2, label: '3 : 2'),
    _AspectRatioPreset(width: 2, height: 3, label: '2 : 3'),
    _AspectRatioPreset(width: 1, height: 1, label: '1 : 1'),
  ];

  late final TextEditingController _ratioWidthController;
  late final TextEditingController _ratioHeightController;
  late final TextEditingController _nameController;
  late Color _selectedColor;
  _AspectRatioPreset? _selectedPreset;
  String? _errorMessage;
  bool _isUpdatingRatio = false;

  @override
  void initState() {
    super.initState();
    final _RatioPair initialPair = _ratioFromSize(
      widget.initialSettings.width,
      widget.initialSettings.height,
    );
    _ratioWidthController = TextEditingController(
      text: initialPair.width.toString(),
    );
    _ratioHeightController = TextEditingController(
      text: initialPair.height.toString(),
    );
    _ratioWidthController.addListener(_handleRatioChanged);
    _ratioHeightController.addListener(_handleRatioChanged);
    _nameController = TextEditingController(text: '未命名项目');
    _selectedColor = widget.initialSettings.backgroundColor;
    _selectedPreset = _matchPreset(
      initialPair.width.toDouble(),
      initialPair.height.toDouble(),
    );
  }

  @override
  void dispose() {
    _ratioWidthController.removeListener(_handleRatioChanged);
    _ratioHeightController.removeListener(_handleRatioChanged);
    _ratioWidthController.dispose();
    _ratioHeightController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final double? ratioWidth = double.tryParse(_ratioWidthController.text);
    final double? ratioHeight = double.tryParse(_ratioHeightController.text);
    if (ratioWidth == null || ratioHeight == null) {
      setState(() => _errorMessage = '请输入有效的比例');
      return;
    }
    if (ratioWidth <= 0 || ratioHeight <= 0) {
      setState(() => _errorMessage = '比例必须大于 0');
      return;
    }

    final _SizePair size = _resolveCanvasSize(ratioWidth, ratioHeight);

    final String rawName = _nameController.text.trim();
    final String resolvedName = rawName.isEmpty ? '未命名项目' : rawName;
    setState(() => _errorMessage = null);
    Navigator.of(context).pop(
      NewProjectConfig(
        name: resolvedName,
        settings: CanvasSettings(
          width: size.width,
          height: size.height,
          backgroundColor: _selectedColor,
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
            label: '比例预设',
            child: ComboBox<_AspectRatioPreset?>(
              isExpanded: true,
              value: _selectedPreset,
              items: [
                const ComboBoxItem<_AspectRatioPreset?>(
                  value: null,
                  child: Text('自定义'),
                ),
                ..._presets.map(
                  (preset) => ComboBoxItem<_AspectRatioPreset?>(
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
            label: '自定义比例',
            child: Row(
              children: [
                Expanded(
                  child: TextFormBox(
                    controller: _ratioWidthController,
                    placeholder: '宽比',
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(':'),
                ),
                Expanded(
                  child: TextFormBox(
                    controller: _ratioHeightController,
                    placeholder: '高比',
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
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

  void _applyPreset(_AspectRatioPreset? preset) {
    setState(() => _selectedPreset = preset);
    if (preset == null) {
      return;
    }
    _isUpdatingRatio = true;
    _ratioWidthController.text = preset.width.toString();
    _ratioHeightController.text = preset.height.toString();
    _isUpdatingRatio = false;
  }

  void _handleRatioChanged() {
    if (_isUpdatingRatio) {
      return;
    }
    final double? ratioWidth = double.tryParse(_ratioWidthController.text);
    final double? ratioHeight = double.tryParse(_ratioHeightController.text);
    if (ratioWidth == null || ratioHeight == null) {
      if (_selectedPreset != null) {
        setState(() => _selectedPreset = null);
      }
      return;
    }
    if (ratioWidth <= 0 || ratioHeight <= 0) {
      if (_selectedPreset != null) {
        setState(() => _selectedPreset = null);
      }
      return;
    }
    final _AspectRatioPreset? matched = _matchPreset(ratioWidth, ratioHeight);
    if (matched != _selectedPreset) {
      setState(() => _selectedPreset = matched);
    }
  }

  String _sizePreviewText() {
    final double? ratioWidth = double.tryParse(_ratioWidthController.text);
    final double? ratioHeight = double.tryParse(_ratioHeightController.text);
    if (ratioWidth == null ||
        ratioHeight == null ||
        ratioWidth <= 0 ||
        ratioHeight <= 0) {
      return '长边固定为 ${_baseLongSide.toInt()} 像素，导出时可调整分辨率';
    }
    final _SizePair size = _resolveCanvasSize(ratioWidth, ratioHeight);
    return '预览尺寸 ≈ ${size.width.round()} × ${size.height.round()} 像素（长边 ${_baseLongSide.toInt()}）';
  }

  _AspectRatioPreset? _matchPreset(double widthRatio, double heightRatio) {
    if (widthRatio <= 0 || heightRatio <= 0) {
      return null;
    }
    final double ratio = widthRatio / heightRatio;
    for (final preset in _presets) {
      final double presetRatio = preset.aspectRatio;
      if ((ratio - presetRatio).abs() < _ratioTolerance) {
        return preset;
      }
    }
    return null;
  }

  _SizePair _resolveCanvasSize(double ratioWidth, double ratioHeight) {
    if (ratioWidth >= ratioHeight) {
      final double width = _baseLongSide;
      final double height = width * ratioHeight / ratioWidth;
      return _SizePair(math.max(1, width), math.max(1, height));
    }
    final double height = _baseLongSide;
    final double width = height * ratioWidth / ratioHeight;
    return _SizePair(math.max(1, width), math.max(1, height));
  }

  _RatioPair _ratioFromSize(double width, double height) {
    if (width <= 0 || height <= 0) {
      return const _RatioPair(16, 9);
    }
    final int widthInt = width.round();
    final int heightInt = height.round();
    final int divisor = _gcd(widthInt, heightInt);
    final int normalizedWidth = math.max(1, widthInt ~/ divisor);
    final int normalizedHeight = math.max(1, heightInt ~/ divisor);
    return _RatioPair(normalizedWidth, normalizedHeight);
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
