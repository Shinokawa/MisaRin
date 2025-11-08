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

class _ToolSettingsCard extends StatefulWidget {
  const _ToolSettingsCard({
    required this.activeTool,
    required this.penStrokeWidth,
    required this.onPenStrokeWidthChanged,
    required this.stylusPressureEnabled,
    required this.onStylusPressureEnabledChanged,
    required this.simulatePenPressure,
    required this.onSimulatePenPressureChanged,
    required this.penPressureProfile,
    required this.onPenPressureProfileChanged,
    required this.brushAntialiasLevel,
    required this.onBrushAntialiasChanged,
    required this.autoSharpPeakEnabled,
    required this.onAutoSharpPeakChanged,
    required this.bucketSampleAllLayers,
    required this.bucketContiguous,
    required this.onBucketSampleAllLayersChanged,
    required this.onBucketContiguousChanged,
    required this.selectionShape,
    required this.onSelectionShapeChanged,
    required this.shapeToolVariant,
    required this.onShapeToolVariantChanged,
    required this.onSizeChanged,
  });

  final CanvasTool activeTool;
  final double penStrokeWidth;
  final ValueChanged<double> onPenStrokeWidthChanged;
  final bool stylusPressureEnabled;
  final ValueChanged<bool> onStylusPressureEnabledChanged;
  final bool simulatePenPressure;
  final ValueChanged<bool> onSimulatePenPressureChanged;
  final StrokePressureProfile penPressureProfile;
  final ValueChanged<StrokePressureProfile> onPenPressureProfileChanged;
  final int brushAntialiasLevel;
  final ValueChanged<int> onBrushAntialiasChanged;
  final bool autoSharpPeakEnabled;
  final ValueChanged<bool> onAutoSharpPeakChanged;
  final bool bucketSampleAllLayers;
  final bool bucketContiguous;
  final ValueChanged<bool> onBucketSampleAllLayersChanged;
  final ValueChanged<bool> onBucketContiguousChanged;
  final SelectionShape selectionShape;
  final ValueChanged<SelectionShape> onSelectionShapeChanged;
  final ShapeToolVariant shapeToolVariant;
  final ValueChanged<ShapeToolVariant> onShapeToolVariantChanged;
  final ValueChanged<Size> onSizeChanged;

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
    switch (widget.activeTool) {
      case CanvasTool.pen:
      case CanvasTool.curvePen:
        content = _buildBrushControls(theme);
        break;
      case CanvasTool.shape:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('图形类型', style: theme.typography.bodyStrong),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: ComboBox<ShapeToolVariant>(
                    value: widget.shapeToolVariant,
                    items: ShapeToolVariant.values
                        .map(
                          (variant) => ComboBoxItem<ShapeToolVariant>(
                            value: variant,
                            child: Text(_shapeVariantLabel(variant)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        widget.onShapeToolVariantChanged(value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildBrushControls(theme),
          ],
        );
        break;
      case CanvasTool.bucket:
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BucketOptionTile(
              title: '跨图层',
              value: widget.bucketSampleAllLayers,
              onChanged: widget.onBucketSampleAllLayersChanged,
            ),
            const SizedBox(width: 16),
            _BucketOptionTile(
              title: '连续',
              value: widget.bucketContiguous,
              onChanged: widget.onBucketContiguousChanged,
            ),
          ],
        );
        break;
      case CanvasTool.selection:
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('选区形状', style: theme.typography.bodyStrong),
            const SizedBox(width: 12),
            SizedBox(
              width: 160,
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
        );
        break;
      default:
        content = Text('该工具暂无可调节参数', style: theme.typography.body);
        break;
    }

    return _MeasureSize(
      onChanged: widget.onSizeChanged,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Align(alignment: Alignment.centerLeft, child: content),
        ),
      ),
    );
  }

  Widget _buildBrushControls(FluentThemeData theme) {
    final bool showAdvancedBrushToggles =
        widget.activeTool == CanvasTool.pen ||
        widget.activeTool == CanvasTool.curvePen ||
        widget.activeTool == CanvasTool.shape;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('笔刷大小', style: theme.typography.bodyStrong),
        const SizedBox(width: 12),
        SizedBox(
          width: 200,
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
          height: 32,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStrokeAdjustButton(
                icon: FluentIcons.calculator_subtract,
                delta: -1,
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 64,
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
              const SizedBox(width: 4),
              _buildStrokeAdjustButton(icon: FluentIcons.add, delta: 1),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text('px', style: theme.typography.caption),
        if (showAdvancedBrushToggles) ...[
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('抗锯齿', style: theme.typography.bodyStrong),
              const SizedBox(width: 8),
              SizedBox(
                width: 140,
                child: Slider(
                  value: widget.brushAntialiasLevel.toDouble(),
                  min: 0,
                  max: 3,
                  divisions: 3,
                  onChanged: (value) =>
                      widget.onBrushAntialiasChanged(value.round()),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '等级 ${widget.brushAntialiasLevel}',
                style: theme.typography.caption,
              ),
            ],
          ),
         const SizedBox(width: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('数位笔笔压', style: theme.typography.bodyStrong),
              const SizedBox(width: 8),
              ToggleSwitch(
                checked: widget.stylusPressureEnabled,
                onChanged: widget.onStylusPressureEnabledChanged,
              ),
            ],
          ),
          const SizedBox(width: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('模拟笔压', style: theme.typography.bodyStrong),
              const SizedBox(width: 8),
              ToggleSwitch(
                checked: widget.simulatePenPressure,
                onChanged: widget.onSimulatePenPressureChanged,
              ),
            ],
          ),
          const SizedBox(width: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('自动尖锐出峰', style: theme.typography.bodyStrong),
              const SizedBox(width: 8),
              ToggleSwitch(
                checked: widget.autoSharpPeakEnabled,
                onChanged: widget.onAutoSharpPeakChanged,
              ),
            ],
          ),
          if (widget.simulatePenPressure) ...[
            const SizedBox(width: 16),
            SizedBox(
              width: 160,
              child: ComboBox<StrokePressureProfile>(
                value: widget.penPressureProfile,
                items: StrokePressureProfile.values
                    .map(
                      (profile) => ComboBoxItem<StrokePressureProfile>(
                        value: profile,
                        child: Text(_pressureProfileLabel(profile)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    widget.onPenPressureProfileChanged(value);
                  }
                },
              ),
            ),
          ],
        ],
      ],
    );
  }

  String _pressureProfileLabel(StrokePressureProfile profile) {
    switch (profile) {
      case StrokePressureProfile.taperEnds:
        return '两端粗中间细';
      case StrokePressureProfile.taperCenter:
        return '两端细中间粗';
      case StrokePressureProfile.auto:
        return '自动';
    }
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

  void _adjustStrokeWidthBy(int delta) {
    final double nextValue = (widget.penStrokeWidth + delta)
        .clamp(
          _ToolSettingsCard._minPenStrokeWidth,
          _ToolSettingsCard._maxPenStrokeWidth,
        )
        .roundToDouble();
    if ((nextValue - widget.penStrokeWidth).abs() < 0.01) {
      return;
    }
    widget.onPenStrokeWidthChanged(nextValue);
    final String formatted = _formatValue(nextValue);
    if (_controller.text != formatted) {
      _isProgrammaticTextUpdate = true;
      _controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      _isProgrammaticTextUpdate = false;
    }
  }

  Widget _buildStrokeAdjustButton({
    required IconData icon,
    required int delta,
  }) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        icon: Icon(icon, size: 14),
        onPressed: () => _adjustStrokeWidthBy(delta),
      ),
    );
  }

  static String _formatValue(double value) {
    return value.round().toString();
  }
}

class _PreviewPathPainter extends CustomPainter {
  const _PreviewPathPainter({
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
  bool shouldRepaint(_PreviewPathPainter oldDelegate) {
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: theme.typography.bodyStrong,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(width: 8),
        ToggleSwitch(checked: value, onChanged: onChanged),
      ],
    );
  }
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChanged, required super.child});

  final ValueChanged<Size> onChanged;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _MeasureSizeRender(onChanged);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MeasureSizeRender renderObject,
  ) {
    renderObject.onChanged = onChanged;
  }
}

class _MeasureSizeRender extends RenderProxyBox {
  _MeasureSizeRender(this.onChanged);

  ValueChanged<Size> onChanged;
  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    final Size size = child?.size ?? Size.zero;
    if (_lastSize == size) {
      return;
    }
    _lastSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(size));
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

String _shapeVariantLabel(ShapeToolVariant variant) {
  switch (variant) {
    case ShapeToolVariant.rectangle:
      return '矩形';
    case ShapeToolVariant.ellipse:
      return '椭圆';
    case ShapeToolVariant.triangle:
      return '三角形';
    case ShapeToolVariant.line:
      return '直线';
  }
}
