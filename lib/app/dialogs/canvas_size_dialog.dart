import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import '../models/canvas_resize_anchor.dart';

class CanvasSizeConfig {
  const CanvasSizeConfig({
    required this.width,
    required this.height,
    required this.anchor,
  });

  final int width;
  final int height;
  final CanvasResizeAnchor anchor;
}

Future<CanvasSizeConfig?> showCanvasSizeDialog(
  BuildContext context, {
  required int initialWidth,
  required int initialHeight,
  CanvasResizeAnchor initialAnchor = CanvasResizeAnchor.center,
}) {
  return showDialog<CanvasSizeConfig>(
    context: context,
    builder: (context) => _CanvasSizeDialog(
      initialWidth: initialWidth,
      initialHeight: initialHeight,
      initialAnchor: initialAnchor,
    ),
  );
}

class _CanvasSizeDialog extends StatefulWidget {
  const _CanvasSizeDialog({
    required this.initialWidth,
    required this.initialHeight,
    required this.initialAnchor,
  });

  final int initialWidth;
  final int initialHeight;
  final CanvasResizeAnchor initialAnchor;

  @override
  State<_CanvasSizeDialog> createState() => _CanvasSizeDialogState();
}

class _CanvasSizeDialogState extends State<_CanvasSizeDialog> {
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  late CanvasResizeAnchor _selectedAnchor;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _widthController = TextEditingController(
      text: widget.initialWidth.toString(),
    )..addListener(_onDimensionChanged);
    _heightController = TextEditingController(
      text: widget.initialHeight.toString(),
    )..addListener(_onDimensionChanged);
    _selectedAnchor = widget.initialAnchor;
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _onDimensionChanged() {
    setState(() => _errorMessage = null);
  }

  void _selectAnchor(CanvasResizeAnchor anchor) {
    setState(() => _selectedAnchor = anchor);
  }

  void _submit() {
    final int? width = int.tryParse(_widthController.text);
    final int? height = int.tryParse(_heightController.text);
    if (width == null || height == null || width <= 0 || height <= 0) {
      setState(() => _errorMessage = '请输入有效的宽高（像素）。');
      return;
    }
    Navigator.of(context).pop(
      CanvasSizeConfig(width: width, height: height, anchor: _selectedAnchor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 420),
      title: const Text('画布大小'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InfoLabel(
            label: '宽度（像素）',
            child: TextBox(
              controller: _widthController,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(height: 12),
          InfoLabel(
            label: '高度（像素）',
            child: TextBox(
              controller: _heightController,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(height: 16),
          Text('定位方式', style: theme.typography.caption),
          const SizedBox(height: 8),
          _AnchorGrid(selected: _selectedAnchor, onSelected: _selectAnchor),
          const SizedBox(height: 8),
          Text('根据定位点裁剪或扩展画布尺寸。', style: theme.typography.caption),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: theme.typography.caption?.copyWith(color: Colors.red),
            ),
          ],
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('确定')),
      ],
    );
  }
}

class _AnchorGrid extends StatelessWidget {
  const _AnchorGrid({required this.selected, required this.onSelected});

  final CanvasResizeAnchor selected;
  final ValueChanged<CanvasResizeAnchor> onSelected;

  static final List<CanvasResizeAnchor> _anchors = <CanvasResizeAnchor>[
    CanvasResizeAnchor.topLeft,
    CanvasResizeAnchor.topCenter,
    CanvasResizeAnchor.topRight,
    CanvasResizeAnchor.centerLeft,
    CanvasResizeAnchor.center,
    CanvasResizeAnchor.centerRight,
    CanvasResizeAnchor.bottomLeft,
    CanvasResizeAnchor.bottomCenter,
    CanvasResizeAnchor.bottomRight,
  ];

  static final List<String> _labels = <String>[
    '↖',
    '↑',
    '↗',
    '←',
    '●',
    '→',
    '↙',
    '↓',
    '↘',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final buttons = <Widget>[];
    for (int i = 0; i < _anchors.length; i++) {
      final anchor = _anchors[i];
      final label = _labels[i];
      final bool isSelected = anchor == selected;
      buttons.add(
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Button(
              style: ButtonStyle(
                padding: WidgetStateProperty.all<EdgeInsets>(
                  const EdgeInsets.symmetric(vertical: 10),
                ),
                backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                  (states) => isSelected
                      ? theme.accentColor.defaultBrushFor(theme.brightness)
                      : theme.resources.controlFillColorDefault,
                ),
              ),
              onPressed: () => onSelected(anchor),
              child: Text(
                label,
                style: theme.typography.subtitle?.copyWith(
                  color: isSelected
                      ? Colors.white
                      : theme.typography.body?.color,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        Row(children: buttons.sublist(0, 3)),
        Row(children: buttons.sublist(3, 6)),
        Row(children: buttons.sublist(6, 9)),
      ],
    );
  }
}
