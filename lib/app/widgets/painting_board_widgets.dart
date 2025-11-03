part of 'painting_board.dart';

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class SelectToolIntent extends Intent {
  const SelectToolIntent(this.tool);

  final CanvasTool tool;
}

class ExitBoardIntent extends Intent {
  const ExitBoardIntent();
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.width,
    required this.title,
    required this.child,
    this.expand = false,
    this.trailing,
  });

  final double width;
  final String title;
  final Widget child;
  final bool expand;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final BorderRadius borderRadius = BorderRadius.circular(20);
    final Color fallbackColor = theme.brightness.isDark
        ? const Color(0xFF1F1F1F)
        : Colors.white;
    Color backgroundColor = theme.cardColor;
    if (backgroundColor.alpha != 0xFF) {
      backgroundColor = fallbackColor;
    }
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(title, style: theme.typography.subtitle),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                ],
              ),
              const SizedBox(height: 14),
              if (expand) Expanded(child: child) else child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolSettingsCard extends StatefulWidget {
  const _ToolSettingsCard({
    required this.activeTool,
    required this.penStrokeWidth,
    required this.previewColor,
    required this.onPenStrokeWidthChanged,
  });

  final CanvasTool activeTool;
  final double penStrokeWidth;
  final Color previewColor;
  final ValueChanged<double> onPenStrokeWidthChanged;

  static const double _minPenStrokeWidth = 1;
  static const double _maxPenStrokeWidth = 60;

  @override
  State<_ToolSettingsCard> createState() => _ToolSettingsCardState();
}

class _ToolSettingsCardState extends State<_ToolSettingsCard> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isProgrammaticTextUpdate = false;

  static final List<TextInputFormatter> _digitInputFormatters =
      <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatValue(widget.penStrokeWidth));
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _ToolSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus &&
        (widget.penStrokeWidth - oldWidget.penStrokeWidth).abs() >= 0.01) {
      final String nextValue = _formatValue(widget.penStrokeWidth);
      if (_controller.text != nextValue) {
        _isProgrammaticTextUpdate = true;
        _controller.text = nextValue;
        _isProgrammaticTextUpdate = false;
      }
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final BorderRadius borderRadius = BorderRadius.circular(12);
    final Color fallbackColor = theme.brightness.isDark
        ? const Color(0xFF1F1F1F)
        : Colors.white;
    Color backgroundColor = theme.cardColor;
    if (backgroundColor.alpha != 0xFF) {
      backgroundColor = fallbackColor;
    }

    Widget content;
    if (widget.activeTool == CanvasTool.pen) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('笔刷大小', style: theme.typography.bodyStrong),
          const SizedBox(width: 12),
          Expanded(
            child: Slider(
              value: widget.penStrokeWidth.clamp(
                _ToolSettingsCard._minPenStrokeWidth,
                _ToolSettingsCard._maxPenStrokeWidth,
              ),
              min: _ToolSettingsCard._minPenStrokeWidth,
              max: _ToolSettingsCard._maxPenStrokeWidth,
              divisions: (_ToolSettingsCard._maxPenStrokeWidth -
                      _ToolSettingsCard._minPenStrokeWidth)
                  .round(),
              onChanged: (value) => widget.onPenStrokeWidthChanged(
                value.roundToDouble(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: TextBox(
              focusNode: _focusNode,
              controller: _controller,
              inputFormatters: _digitInputFormatters,
              keyboardType:
                  const TextInputType.numberWithOptions(signed: false),
              onChanged: _handleTextChanged,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 6),
          Text('px', style: theme.typography.caption),
          const SizedBox(width: 12),
          _BrushPreview(
            strokeWidth: widget.penStrokeWidth,
            color: widget.previewColor,
          ),
        ],
      );
    } else {
      content = SizedBox(
        height: 40,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '该工具暂无可调节参数',
            style: theme.typography.body,
          ),
        ),
      );
    }

    return SizedBox(
      width: _toolSettingsCardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: content,
        ),
      ),
    );
  }

  void _handleTextChanged(String value) {
    if (_isProgrammaticTextUpdate) {
      return;
    }
    final double? parsed = double.tryParse(value);
    if (parsed == null) {
      return;
    }
    final double clamped = parsed
        .clamp(_ToolSettingsCard._minPenStrokeWidth,
            _ToolSettingsCard._maxPenStrokeWidth)
        .toDouble()
        .roundToDouble();
    final String formatted = _formatValue(clamped);
    if (_controller.text != formatted) {
      _isProgrammaticTextUpdate = true;
      _controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      _isProgrammaticTextUpdate = false;
    }
    if ((clamped - widget.penStrokeWidth).abs() < 0.01) {
      return;
    }
    widget.onPenStrokeWidthChanged(clamped);
  }

  void _handleFocusChange() {
    final String formatted = _formatValue(widget.penStrokeWidth);
    if (_controller.text != formatted) {
      _isProgrammaticTextUpdate = true;
      _controller.text = formatted;
      _isProgrammaticTextUpdate = false;
    }
  }

  static String _formatValue(double value) {
    return value.round().toString();
  }
}

class _BrushPreview extends StatelessWidget {
  const _BrushPreview({
    required this.strokeWidth,
    required this.color,
  });

  final double strokeWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double clampedDiameter = strokeWidth.clamp(4.0, 32.0);
    final FluentThemeData theme = FluentTheme.of(context);
    final Color borderColor = theme.brightness.isDark
        ? Colors.white.withOpacity(0.3)
        : Colors.black.withOpacity(0.1);
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: Container(
          width: clampedDiameter,
          height: clampedDiameter,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 1),
          ),
        ),
      ),
    );
  }
}
