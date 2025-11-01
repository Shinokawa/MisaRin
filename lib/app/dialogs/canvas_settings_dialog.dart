import 'package:fluent_ui/fluent_ui.dart';

import '../../canvas/canvas_settings.dart';
import 'misarin_dialog.dart';

Future<CanvasSettings?> showCanvasSettingsDialog(
  BuildContext context, {
  CanvasSettings? initialSettings,
}) {
  return showDialog<CanvasSettings>(
    context: context,
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
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  late Color _selectedColor;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _widthController = TextEditingController(
      text: widget.initialSettings.width.toStringAsFixed(0),
    );
    _heightController = TextEditingController(
      text: widget.initialSettings.height.toStringAsFixed(0),
    );
    _selectedColor = widget.initialSettings.backgroundColor;
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
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
    Navigator.of(context).pop(
      CanvasSettings(
        width: width,
        height: height,
        backgroundColor: _selectedColor,
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
}
