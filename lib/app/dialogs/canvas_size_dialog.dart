import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
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
      setState(() => _errorMessage = context.l10n.invalidDimensions);
      return;
    }
    Navigator.of(context).pop(
      CanvasSizeConfig(width: width, height: height, anchor: _selectedAnchor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final l10n = context.l10n;
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 420),
      title: Text(l10n.canvasSizeTitle),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InfoLabel(
            label: l10n.widthPx,
            child: TextBox(
              controller: _widthController,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(height: 12),
          InfoLabel(
            label: l10n.heightPx,
            child: TextBox(
              controller: _heightController,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.canvasSizeAnchorLabel, style: theme.typography.caption),
          const SizedBox(height: 8),
          _AnchorGrid(selected: _selectedAnchor, onSelected: _selectAnchor),
          const SizedBox(height: 8),
          Text(l10n.canvasSizeAnchorDesc, style: theme.typography.caption),
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
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.confirm)),
      ],
    );
  }
}

class _AnchorGrid extends StatelessWidget {
  const _AnchorGrid({required this.selected, required this.onSelected});

  final CanvasResizeAnchor selected;
  final ValueChanged<CanvasResizeAnchor> onSelected;

  static Color _bestForegroundFor(Color background) {
    final double luminance = background.computeLuminance();
    final double contrastWithWhite = (1.05) / (luminance + 0.05);
    final double contrastWithBlack = (luminance + 0.05) / 0.05;
    return contrastWithWhite >= contrastWithBlack ? Colors.white : Colors.black;
  }

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
    final Color selectedBackground =
        theme.accentColor.defaultBrushFor(theme.brightness);
    final Color selectedForeground = _bestForegroundFor(selectedBackground);
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
                      ? selectedBackground
                      : theme.resources.controlFillColorDefault,
                ),
              ),
              onPressed: () => onSelected(anchor),
              child: Text(
                label,
                style: theme.typography.subtitle?.copyWith(
                  color: isSelected
                      ? selectedForeground
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
