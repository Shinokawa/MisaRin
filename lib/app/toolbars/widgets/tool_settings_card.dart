import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../bitmap_canvas/stroke_dynamics.dart' show StrokePressureProfile;
import '../../../canvas/canvas_tools.dart';
import '../../preferences/app_preferences.dart' show PenStrokeSliderRange;
import 'measured_size.dart';

class ToolSettingsCard extends StatefulWidget {
  const ToolSettingsCard({
    super.key,
    required this.activeTool,
    required this.penStrokeWidth,
    required this.penStrokeSliderRange,
    required this.onPenStrokeWidthChanged,
    required this.brushShape,
    required this.onBrushShapeChanged,
    required this.strokeStabilizerStrength,
    required this.onStrokeStabilizerChanged,
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
    required this.bucketSwallowColorLine,
    required this.bucketAntialiasLevel,
    required this.onBucketSampleAllLayersChanged,
    required this.onBucketContiguousChanged,
    required this.onBucketSwallowColorLineChanged,
    required this.onBucketAntialiasChanged,
    required this.bucketTolerance,
    required this.onBucketToleranceChanged,
    required this.layerAdjustCropOutside,
    required this.onLayerAdjustCropOutsideChanged,
    required this.selectionShape,
    required this.onSelectionShapeChanged,
    required this.shapeToolVariant,
    required this.onShapeToolVariantChanged,
    required this.onSizeChanged,
    required this.magicWandTolerance,
    required this.onMagicWandToleranceChanged,
    required this.brushToolsEraserMode,
    required this.onBrushToolsEraserModeChanged,
    required this.strokeStabilizerMaxLevel,
    this.compactLayout = false,
  });

  final CanvasTool activeTool;
  final double penStrokeWidth;
  final PenStrokeSliderRange penStrokeSliderRange;
  final ValueChanged<double> onPenStrokeWidthChanged;
  final BrushShape brushShape;
  final ValueChanged<BrushShape> onBrushShapeChanged;
  final double strokeStabilizerStrength;
  final ValueChanged<double> onStrokeStabilizerChanged;
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
  final bool bucketSwallowColorLine;
  final int bucketAntialiasLevel;
  final ValueChanged<bool> onBucketSampleAllLayersChanged;
  final ValueChanged<bool> onBucketContiguousChanged;
  final ValueChanged<bool> onBucketSwallowColorLineChanged;
  final ValueChanged<int> onBucketAntialiasChanged;
  final int bucketTolerance;
  final ValueChanged<int> onBucketToleranceChanged;
  final bool layerAdjustCropOutside;
  final ValueChanged<bool> onLayerAdjustCropOutsideChanged;
  final SelectionShape selectionShape;
  final ValueChanged<SelectionShape> onSelectionShapeChanged;
  final ShapeToolVariant shapeToolVariant;
  final ValueChanged<ShapeToolVariant> onShapeToolVariantChanged;
  final ValueChanged<Size> onSizeChanged;
  final int magicWandTolerance;
  final ValueChanged<int> onMagicWandToleranceChanged;
  final bool brushToolsEraserMode;
  final ValueChanged<bool> onBrushToolsEraserModeChanged;
  final int strokeStabilizerMaxLevel;
  final bool compactLayout;

  @override
  State<ToolSettingsCard> createState() => _ToolSettingsCardState();
}

class _ToolSettingsCardState extends State<ToolSettingsCard> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isProgrammaticTextUpdate = false;

  static final List<TextInputFormatter> _digitInputFormatters =
      <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ];

  double get _sliderMin => widget.penStrokeSliderRange.min;
  double get _sliderMax => widget.penStrokeSliderRange.max;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _formatValue(widget.penStrokeWidth),
    );
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant ToolSettingsCard oldWidget) {
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
            _buildLabeledComboField<ShapeToolVariant>(
              theme,
              label: '图形类型',
              width: 160,
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
            const SizedBox(height: 12),
            _buildBrushControls(theme),
          ],
        );
        break;
      case CanvasTool.bucket:
        content = _buildControlsGroup(
          [
            _buildToleranceSlider(
              theme,
              label: '容差',
              value: widget.bucketTolerance,
              onChanged: widget.onBucketToleranceChanged,
            ),
            _buildBucketAntialiasRow(theme),
            _BucketOptionTile(
              title: '跨图层',
              value: widget.bucketSampleAllLayers,
              onChanged: widget.onBucketSampleAllLayersChanged,
              compact: widget.compactLayout,
            ),
            _BucketOptionTile(
              title: '连续',
              value: widget.bucketContiguous,
              onChanged: widget.onBucketContiguousChanged,
              compact: widget.compactLayout,
            ),
            _BucketOptionTile(
              title: '吞并色线',
              value: widget.bucketSwallowColorLine,
              onChanged: widget.onBucketSwallowColorLineChanged,
              compact: widget.compactLayout,
            ),
          ],
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
        );
        break;
      case CanvasTool.magicWand:
        content = _buildToleranceSlider(
          theme,
          label: '容差',
          value: widget.magicWandTolerance,
          onChanged: widget.onMagicWandToleranceChanged,
        );
        break;
      case CanvasTool.layerAdjust:
        content = _buildToggleSwitchRow(
          theme,
          label: '裁剪出界画面',
          value: widget.layerAdjustCropOutside,
          onChanged: widget.onLayerAdjustCropOutsideChanged,
        );
        break;
      case CanvasTool.selection:
        content = _buildLabeledComboField<SelectionShape>(
          theme,
          label: '选区形状',
          width: 160,
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
        );
        break;
      default:
        content = Text('该工具暂无可调节参数', style: theme.typography.body);
        break;
    }

    return MeasuredSize(
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
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildBrushControls(FluentThemeData theme) {
    final bool showAdvancedBrushToggles =
        widget.activeTool == CanvasTool.pen ||
        widget.activeTool == CanvasTool.curvePen ||
        widget.activeTool == CanvasTool.shape;

    final List<Widget> wrapChildren = <Widget>[
      _buildBrushSizeRow(theme),
      _buildBrushShapeRow(theme),
      if (widget.activeTool == CanvasTool.pen) _buildStrokeStabilizerRow(theme),
    ];

    if (showAdvancedBrushToggles) {
      wrapChildren.add(_buildBrushAntialiasRow(theme));
      wrapChildren.add(
        _buildToggleSwitchRow(
          theme,
          label: '自动尖锐出峰',
          value: widget.autoSharpPeakEnabled,
          onChanged: widget.onAutoSharpPeakChanged,
        ),
      );
      wrapChildren.add(
        _buildToggleSwitchRow(
          theme,
          label: '数位笔笔压',
          value: widget.stylusPressureEnabled,
          onChanged: widget.onStylusPressureEnabledChanged,
        ),
      );
      wrapChildren.add(
        _buildToggleSwitchRow(
          theme,
          label: '模拟笔压',
          value: widget.simulatePenPressure,
          onChanged: widget.onSimulatePenPressureChanged,
        ),
      );
      wrapChildren.add(
        _buildToggleSwitchRow(
          theme,
          label: '转换为擦除',
          value: widget.brushToolsEraserMode,
          onChanged: widget.onBrushToolsEraserModeChanged,
        ),
      );
      if (widget.simulatePenPressure) {
        wrapChildren.add(
          SizedBox(
            width: widget.compactLayout ? double.infinity : 160,
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
        );
      }
    }

    return _buildControlsGroup(
      wrapChildren,
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
    );
  }

  Widget _buildBrushShapeRow(FluentThemeData theme) {
    return _buildLabeledComboField<BrushShape>(
      theme,
      label: '笔刷形状',
      width: 140,
      value: widget.brushShape,
      items: BrushShape.values
          .map(
            (shape) => ComboBoxItem<BrushShape>(
              value: shape,
              child: Text(_brushShapeLabel(shape)),
            ),
          )
          .toList(),
      onChanged: (shape) {
        if (shape != null) {
          widget.onBrushShapeChanged(shape);
        }
      },
    );
  }

  Widget _buildToleranceSlider(
    FluentThemeData theme, {
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    int max = 255,
  }) {
    final double sliderValue = value.clamp(0, max).toDouble();
    final Slider slider = Slider(
      value: sliderValue,
      min: 0,
      max: max.toDouble(),
      divisions: max,
      onChanged: (raw) => onChanged(raw.round()),
    );
    if (!widget.compactLayout) {
      return Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: theme.typography.bodyStrong),
          const SizedBox(width: 8),
          Expanded(child: slider),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text(
              '$value',
              textAlign: TextAlign.end,
              style: theme.typography.caption,
            ),
          ),
        ],
      );
    }
    return _buildCompactSliderField(
      theme,
      label: label,
      tooltipText: '$label：$value',
      slider: slider,
    );
  }

  Widget _buildBrushSizeRow(FluentThemeData theme) {
    final double brushSize =
        widget.penStrokeSliderRange.clamp(widget.penStrokeWidth);
    final Slider slider = Slider(
      value: brushSize,
      min: _sliderMin,
      max: _sliderMax,
      onChanged: widget.onPenStrokeWidthChanged,
    );
    if (!widget.compactLayout) {
      return Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('笔刷大小', style: theme.typography.bodyStrong),
          const SizedBox(width: 8),
          Expanded(child: slider),
          const SizedBox(width: 8),
          SizedBox(
            width: 124,
            child: SizedBox(
              height: 32,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  _buildStrokeAdjustButton(
                    icon: FluentIcons.calculator_subtract,
                    delta: -1,
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 56,
                    child: TextBox(
                      focusNode: _focusNode,
                      controller: _controller,
                      inputFormatters: _digitInputFormatters,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: false,
                        decimal: true,
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
          ),
          const SizedBox(width: 6),
          Text('px', style: theme.typography.caption),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCompactSliderField(
          theme,
          label: '笔刷大小',
          tooltipText: '笔刷大小：${_formatValue(brushSize)} px',
          slider: slider,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            _buildStrokeAdjustButton(
              icon: FluentIcons.calculator_subtract,
              delta: -1,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: SizedBox(
                height: 32,
                child: TextBox(
                  focusNode: _focusNode,
                  controller: _controller,
                  inputFormatters: _digitInputFormatters,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: false,
                    decimal: true,
                  ),
                  onChanged: _handleTextChanged,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 4),
            _buildStrokeAdjustButton(icon: FluentIcons.add, delta: 1),
            const SizedBox(width: 6),
            Text('px', style: theme.typography.caption),
          ],
        ),
      ],
    );
  }

  Widget _buildBrushAntialiasRow(FluentThemeData theme) {
    return _buildAntialiasRow(
      theme,
      value: widget.brushAntialiasLevel,
      onChanged: widget.onBrushAntialiasChanged,
    );
  }

  Widget _buildBucketAntialiasRow(FluentThemeData theme) {
    return _buildAntialiasRow(
      theme,
      value: widget.bucketAntialiasLevel,
      onChanged: widget.onBucketAntialiasChanged,
    );
  }

  Widget _buildAntialiasRow(
    FluentThemeData theme, {
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    final Slider slider = Slider(
      value: value.toDouble(),
      min: 0,
      max: 3,
      divisions: 3,
      onChanged: (raw) => onChanged(raw.round()),
    );
    if (!widget.compactLayout) {
      return Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Text('抗锯齿', style: theme.typography.bodyStrong),
          const SizedBox(width: 8),
          Expanded(child: slider),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(
              '等级 $value',
              style: theme.typography.caption,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      );
    }
    return _buildCompactSliderField(
      theme,
      label: '抗锯齿',
      tooltipText: '抗锯齿：等级 $value',
      slider: slider,
    );
  }

  Widget _buildStrokeStabilizerRow(FluentThemeData theme) {
    final double value = widget.strokeStabilizerStrength.clamp(0.0, 1.0);
    final double projected = (value * widget.strokeStabilizerMaxLevel).clamp(
      0.0,
      widget.strokeStabilizerMaxLevel.toDouble(),
    );
    final int level = projected.round().clamp(
      0,
      widget.strokeStabilizerMaxLevel,
    );
    final double sliderValue = level.toDouble();
    final String label = level == 0 ? '关' : '等级 $level';
    final Slider slider = Slider(
      value: sliderValue,
      min: 0,
      max: widget.strokeStabilizerMaxLevel.toDouble(),
      divisions: widget.strokeStabilizerMaxLevel,
      onChanged: (raw) => widget.onStrokeStabilizerChanged(
        (raw / widget.strokeStabilizerMaxLevel).clamp(0.0, 1.0),
      ),
    );
    if (!widget.compactLayout) {
      return Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Text('手抖修正', style: theme.typography.bodyStrong),
          const SizedBox(width: 8),
          Expanded(child: slider),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: theme.typography.caption,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      );
    }
    return _buildCompactSliderField(
      theme,
      label: '手抖修正',
      tooltipText: '手抖修正：$label',
      slider: slider,
    );
  }

  Widget _buildToggleSwitchRow(
    FluentThemeData theme, {
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.typography.bodyStrong),
        const SizedBox(width: 8),
        ToggleSwitch(checked: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildControlsGroup(
    List<Widget> children, {
    double spacing = 16,
    double runSpacing = 12,
    WrapCrossAlignment crossAxisAlignment = WrapCrossAlignment.center,
  }) {
    if (!widget.compactLayout) {
      return Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _separateChildren(children, runSpacing),
    );
  }

  List<Widget> _separateChildren(List<Widget> children, double spacing) {
    if (children.isEmpty) {
      return const <Widget>[];
    }
    final List<Widget> separated = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      separated.add(children[i]);
      if (i < children.length - 1) {
        separated.add(SizedBox(height: spacing));
      }
    }
    return separated;
  }

  Widget _buildCompactSliderField(
    FluentThemeData theme, {
    required String label,
    required String tooltipText,
    required Widget slider,
  }) {
    final Widget wrappedSlider = Tooltip(
      message: tooltipText,
      style: const TooltipThemeData(waitDuration: Duration.zero),
      useMousePosition: true,
      displayHorizontally: true,
      child: SizedBox(width: double.infinity, child: slider),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        wrappedSlider,
      ],
    );
  }

  Widget _buildLabeledComboField<T>(
    FluentThemeData theme, {
    required String label,
    required double width,
    required T value,
    required List<ComboBoxItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final Widget combo = SizedBox(
      width: widget.compactLayout ? double.infinity : width,
      child: ComboBox<T>(value: value, items: items, onChanged: onChanged),
    );
    if (!widget.compactLayout) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: theme.typography.bodyStrong),
          const SizedBox(width: 8),
          combo,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        combo,
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
    final double clamped = widget.penStrokeSliderRange.clamp(parsed);
    final String formatted = _formatValue(clamped);
    if (_controller.text != formatted) {
      _isProgrammaticTextUpdate = true;
      _controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      _isProgrammaticTextUpdate = false;
    }
    if ((clamped - widget.penStrokeWidth).abs() < 0.0005) {
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
    final double nextValue = widget.penStrokeSliderRange.clamp(
      widget.penStrokeWidth + delta,
    );
    if ((nextValue - widget.penStrokeWidth).abs() < 0.0005) {
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
      width: 28,
      height: 28,
      child: IconButton(
        icon: Icon(icon, size: 14),
        onPressed: () => _adjustStrokeWidthBy(delta),
      ),
    );
  }

  static String _formatValue(double value) {
    final double absValue = value.abs();
    String formatted;
    if (absValue >= 100.0) {
      formatted = value.toStringAsFixed(0);
    } else if (absValue >= 10.0) {
      formatted = value.toStringAsFixed(1);
    } else if (absValue >= 1.0) {
      formatted = value.toStringAsFixed(2);
    } else {
      formatted = value.toStringAsFixed(3);
    }
    return _stripTrailingZeros(formatted);
  }

  static String _stripTrailingZeros(String value) {
    if (!value.contains('.')) {
      return value;
    }
    String trimmed = value.replaceFirst(RegExp(r'0+$'), '');
    if (trimmed.endsWith('.')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed.isEmpty ? '0' : trimmed;
  }
}

class _BucketOptionTile extends StatelessWidget {
  const _BucketOptionTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Row(
      mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (compact)
          Expanded(
            child: Text(
              title,
              style: theme.typography.bodyStrong,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
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

String _brushShapeLabel(BrushShape shape) {
  switch (shape) {
    case BrushShape.circle:
      return '圆形';
    case BrushShape.triangle:
      return '三角形';
    case BrushShape.square:
      return '正方形';
  }
}
