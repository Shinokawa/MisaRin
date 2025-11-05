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

class DeselectIntent extends Intent {
  const DeselectIntent();
}

class CutIntent extends Intent {
  const CutIntent();
}

class CopyIntent extends Intent {
  const CopyIntent();
}

class PasteIntent extends Intent {
  const PasteIntent();
}

class _CheckboardBackground extends StatelessWidget {
  const _CheckboardBackground({
    this.cellSize = 16.0,
    this.lightColor = const Color(0xFFF9F9F9),
    this.darkColor = const ui.Color.fromARGB(255, 211, 211, 211),
  });

  final double cellSize;
  final Color lightColor;
  final Color darkColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CheckboardPainter(
        cellSize: cellSize,
        lightColor: lightColor,
        darkColor: darkColor,
      ),
    );
  }
}

class _CheckboardPainter extends CustomPainter {
  const _CheckboardPainter({
    required this.cellSize,
    required this.lightColor,
    required this.darkColor,
  });

  final double cellSize;
  final Color lightColor;
  final Color darkColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint lightPaint = Paint()
      ..color = lightColor
      ..isAntiAlias = false;
    final Paint darkPaint = Paint()
      ..color = darkColor
      ..isAntiAlias = false;
    final double step = cellSize <= 0 ? 12.0 : cellSize;
    final int horizontalCount = (size.width / step).ceil();
    final int verticalCount = (size.height / step).ceil();

    for (int y = 0; y < verticalCount; y++) {
      final bool oddRow = y.isOdd;
      for (int x = 0; x < horizontalCount; x++) {
        final bool useDark = oddRow ? x.isEven : x.isOdd;
        final Rect rect = Rect.fromLTWH(x * step, y * step, step, step);
        canvas.drawRect(rect, useDark ? darkPaint : lightPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckboardPainter oldDelegate) {
    return oldDelegate.cellSize != cellSize ||
        oldDelegate.lightColor != lightColor ||
        oldDelegate.darkColor != darkColor;
  }
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
          border: Border.all(
            color: theme.brightness.isDark
                ? Colors.white.withOpacity(0.12)
                : Colors.black.withOpacity(0.08),
          ),
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

class _EyedropperCursorOverlay extends StatelessWidget {
  const _EyedropperCursorOverlay();

  static const double size = 20;
  static const Offset tipOffset = Offset(5, 17);

  @override
  Widget build(BuildContext context) {
    const double outlineRadius = 0.75;
    const List<Offset> outlineOffsets = <Offset>[
      Offset(-outlineRadius, 0),
      Offset(outlineRadius, 0),
      Offset(0, -outlineRadius),
      Offset(0, outlineRadius),
      Offset(-outlineRadius, -outlineRadius),
      Offset(outlineRadius, -outlineRadius),
      Offset(-outlineRadius, outlineRadius),
      Offset(outlineRadius, outlineRadius),
    ];

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final Offset offset in outlineOffsets)
            Transform.translate(
              offset: offset,
              child: const Icon(
                FluentIcons.eyedropper,
                size: size,
                color: Colors.white,
              ),
            ),
          const Icon(
            FluentIcons.eyedropper,
            size: size,
            color: Colors.black,
          ),
        ],
      ),
    );
  }
}

class _ToolSettingsCard extends StatefulWidget {
  const _ToolSettingsCard({
    required this.activeTool,
    required this.penStrokeWidth,
    required this.onPenStrokeWidthChanged,
    required this.bucketSampleAllLayers,
    required this.bucketContiguous,
    required this.onBucketSampleAllLayersChanged,
    required this.onBucketContiguousChanged,
    required this.selectionShape,
    required this.onSelectionShapeChanged,
  });

  final CanvasTool activeTool;
  final double penStrokeWidth;
  final ValueChanged<double> onPenStrokeWidthChanged;
  final bool bucketSampleAllLayers;
  final bool bucketContiguous;
  final ValueChanged<bool> onBucketSampleAllLayersChanged;
  final ValueChanged<bool> onBucketContiguousChanged;
  final SelectionShape selectionShape;
  final ValueChanged<SelectionShape> onSelectionShapeChanged;

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
    _controller = TextEditingController(
      text: _formatValue(widget.penStrokeWidth),
    );
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
    if (widget.activeTool == CanvasTool.pen ||
        widget.activeTool == CanvasTool.curvePen) {
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
              divisions:
                  (_ToolSettingsCard._maxPenStrokeWidth -
                          _ToolSettingsCard._minPenStrokeWidth)
                      .round(),
              onChanged: (value) =>
                  widget.onPenStrokeWidthChanged(value.roundToDouble()),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: SizedBox(
              height: 32,
              child: TextBox(
                focusNode: _focusNode,
                controller: _controller,
                inputFormatters: _digitInputFormatters,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: false,
                ),
                onChanged: _handleTextChanged,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('px', style: theme.typography.caption),
        ],
      );
    } else if (widget.activeTool == CanvasTool.bucket) {
      content = Row(
        children: [
          Expanded(
            child: _BucketOptionTile(
              title: '跨图层',
              value: widget.bucketSampleAllLayers,
              onChanged: widget.onBucketSampleAllLayersChanged,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _BucketOptionTile(
              title: '连续',
              value: widget.bucketContiguous,
              onChanged: widget.onBucketContiguousChanged,
            ),
          ),
        ],
      );
    } else if (widget.activeTool == CanvasTool.selection) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('选区形状', style: theme.typography.bodyStrong),
              const SizedBox(width: 12),
              Expanded(
                child: ComboBox<SelectionShape>(
                  value: widget.selectionShape,
                  items: SelectionShape.values
                      .map(
                        (shape) => ComboBoxItem<SelectionShape>(
                          value: shape,
                          child: Text(_selectionShapeLabel(shape)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      widget.onSelectionShapeChanged(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      content = SizedBox(
        height: 40,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('该工具暂无可调节参数', style: theme.typography.body),
        ),
      );
    }

    return SizedBox(
      width: _toolSettingsCardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
          border: Border.all(
            color: theme.brightness.isDark
                ? Colors.white.withOpacity(0.12)
                : Colors.black.withOpacity(0.08),
          ),
        ),
        child: SizedBox(
          height: _toolSettingsCardHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Align(alignment: Alignment.centerLeft, child: content),
          ),
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
        .clamp(
          _ToolSettingsCard._minPenStrokeWidth,
          _ToolSettingsCard._maxPenStrokeWidth,
        )
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

class _CurvePreviewPainter extends CustomPainter {
  const _CurvePreviewPainter({
    required this.path,
    required this.color,
    required this.strokeWidth,
  });

  final Path path;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth.clamp(1.0, 60.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CurvePreviewPainter oldDelegate) {
    return oldDelegate.path != path ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _BucketOptionTile extends StatelessWidget {
  const _BucketOptionTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return SizedBox(
      height: _toolSettingsCardHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              title,
              style: theme.typography.bodyStrong,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          ToggleSwitch(checked: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

String _selectionShapeLabel(SelectionShape shape) {
  switch (shape) {
    case SelectionShape.rectangle:
      return '矩形选区';
    case SelectionShape.ellipse:
      return '圆形选区';
    case SelectionShape.polygon:
      return '多边形套索';
  }
}
