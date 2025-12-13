import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../bitmap_canvas/stroke_dynamics.dart' show StrokePressureProfile;
import '../../../canvas/canvas_tools.dart';
import '../../../canvas/text_renderer.dart' show CanvasTextOrientation;
import '../../l10n/l10n.dart';
import '../../preferences/app_preferences.dart' show PenStrokeSliderRange;
import '../../constants/pen_constants.dart'
    show kSprayStrokeMin, kSprayStrokeMax;
import '../../tooltips/hover_detail_tooltip.dart';
import 'measured_size.dart';
import 'selection_shape_icon.dart';

class ToolSettingsCard extends StatefulWidget {
  const ToolSettingsCard({
    super.key,
    required this.activeTool,
    required this.penStrokeWidth,
    required this.sprayStrokeWidth,
    required this.sprayMode,
    required this.penStrokeSliderRange,
    required this.onPenStrokeWidthChanged,
    required this.onSprayStrokeWidthChanged,
    required this.onSprayModeChanged,
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
    required this.shapeFillEnabled,
    required this.onShapeFillChanged,
    required this.onSizeChanged,
    required this.magicWandTolerance,
    required this.onMagicWandToleranceChanged,
    required this.brushToolsEraserMode,
    required this.onBrushToolsEraserModeChanged,
    required this.vectorDrawingEnabled,
    required this.onVectorDrawingEnabledChanged,
    required this.vectorStrokeSmoothingEnabled,
    required this.onVectorStrokeSmoothingChanged,
    required this.strokeStabilizerMaxLevel,
    required this.textFontSize,
    required this.onTextFontSizeChanged,
    required this.textLineHeight,
    required this.onTextLineHeightChanged,
    required this.textLetterSpacing,
    required this.onTextLetterSpacingChanged,
    required this.textFontFamily,
    required this.onTextFontFamilyChanged,
    required this.availableFontFamilies,
    required this.fontsLoading,
    required this.textAlign,
    required this.onTextAlignChanged,
    required this.textOrientation,
    required this.onTextOrientationChanged,
    required this.textAntialias,
    required this.onTextAntialiasChanged,
    required this.textStrokeEnabled,
    required this.onTextStrokeEnabledChanged,
    required this.textStrokeWidth,
    required this.onTextStrokeWidthChanged,
    required this.textStrokeColor,
    required this.onTextStrokeColorPressed,
    this.compactLayout = false,
  });

  final CanvasTool activeTool;
  final double penStrokeWidth;
  final double sprayStrokeWidth;
  final SprayMode sprayMode;
  final PenStrokeSliderRange penStrokeSliderRange;
  final ValueChanged<double> onPenStrokeWidthChanged;
  final ValueChanged<double> onSprayStrokeWidthChanged;
  final ValueChanged<SprayMode> onSprayModeChanged;
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
  final bool shapeFillEnabled;
  final ValueChanged<bool> onShapeFillChanged;
  final ValueChanged<Size> onSizeChanged;
  final int magicWandTolerance;
  final ValueChanged<int> onMagicWandToleranceChanged;
  final bool brushToolsEraserMode;
  final ValueChanged<bool> onBrushToolsEraserModeChanged;
  final bool vectorDrawingEnabled;
  final ValueChanged<bool> onVectorDrawingEnabledChanged;
  final bool vectorStrokeSmoothingEnabled;
  final ValueChanged<bool> onVectorStrokeSmoothingChanged;
  final int strokeStabilizerMaxLevel;
  final bool compactLayout;
  final double textFontSize;
  final ValueChanged<double> onTextFontSizeChanged;
  final double textLineHeight;
  final ValueChanged<double> onTextLineHeightChanged;
  final double textLetterSpacing;
  final ValueChanged<double> onTextLetterSpacingChanged;
  final String textFontFamily;
  final ValueChanged<String> onTextFontFamilyChanged;
  final List<String> availableFontFamilies;
  final bool fontsLoading;
  final TextAlign textAlign;
  final ValueChanged<TextAlign> onTextAlignChanged;
  final CanvasTextOrientation textOrientation;
  final ValueChanged<CanvasTextOrientation> onTextOrientationChanged;
  final bool textAntialias;
  final ValueChanged<bool> onTextAntialiasChanged;
  final bool textStrokeEnabled;
  final ValueChanged<bool> onTextStrokeEnabledChanged;
  final double textStrokeWidth;
  final ValueChanged<double> onTextStrokeWidthChanged;
  final Color textStrokeColor;
  final VoidCallback onTextStrokeColorPressed;

  @override
  State<ToolSettingsCard> createState() => _ToolSettingsCardState();
}

class _ToolSettingsCardState extends State<ToolSettingsCard> {
  static const double _defaultSliderWidth = 220;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isProgrammaticTextUpdate = false;

  static final List<TextInputFormatter> _digitInputFormatters =
      <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ];

  double get _sliderMin => widget.penStrokeSliderRange.min;
  double get _sliderMax => widget.penStrokeSliderRange.max;
  bool get _isSprayTool => widget.activeTool == CanvasTool.spray;
  double get _activeSliderMin => _isSprayTool ? kSprayStrokeMin : _sliderMin;
  double get _activeSliderMax => _isSprayTool ? kSprayStrokeMax : _sliderMax;
  bool get _sliderUsesIntegers =>
      _isSprayTool ||
      widget.penStrokeSliderRange == PenStrokeSliderRange.compact;
  double get _activeBrushValue => _isSprayTool
      ? widget.sprayStrokeWidth.clamp(kSprayStrokeMin, kSprayStrokeMax)
      : widget.penStrokeSliderRange.clamp(widget.penStrokeWidth);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _formatBrushValue(_activeBrushValue),
    );
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant ToolSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final double newValue = _activeBrushValue;
    final double previousValue = oldWidget.activeTool == CanvasTool.spray
        ? oldWidget.sprayStrokeWidth
        : oldWidget.penStrokeWidth;
    final bool toolChanged = widget.activeTool != oldWidget.activeTool;
    if (!_focusNode.hasFocus &&
        (toolChanged || (newValue - previousValue).abs() >= 0.01)) {
      final String nextValue = _formatBrushValue(newValue);
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
    final l10n = context.l10n;
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
      case CanvasTool.perspectivePen:
      case CanvasTool.curvePen:
        content = _buildBrushControls(theme);
        break;
      case CanvasTool.spray:
        content = _buildSprayControls(theme);
        break;
      case CanvasTool.eraser:
        content = _buildBrushControls(theme, includeEraserToggle: false);
        break;
      case CanvasTool.shape:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildShapeVariantRow(theme),
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
              label: l10n.tolerance,
              detail: l10n.toleranceDesc,
              value: widget.bucketTolerance,
              onChanged: widget.onBucketToleranceChanged,
            ),
            _buildBucketAntialiasRow(theme),
            _BucketOptionTile(
              title: l10n.sampleAllLayers,
              detail: l10n.sampleAllLayersDesc,
              value: widget.bucketSampleAllLayers,
              onChanged: widget.onBucketSampleAllLayersChanged,
              compact: widget.compactLayout,
            ),
            _BucketOptionTile(
              title: l10n.contiguous,
              detail: l10n.contiguousDesc,
              value: widget.bucketContiguous,
              onChanged: widget.onBucketContiguousChanged,
              compact: widget.compactLayout,
            ),
            _BucketOptionTile(
              title: l10n.swallowColorLine,
              detail: l10n.swallowColorLineDesc,
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
          label: l10n.tolerance,
          detail: l10n.toleranceDesc,
          value: widget.magicWandTolerance,
          onChanged: widget.onMagicWandToleranceChanged,
        );
        break;
      case CanvasTool.layerAdjust:
        content = _buildToggleSwitchRow(
          theme,
          label: l10n.cropOutsideCanvas,
          detail: l10n.cropOutsideCanvasDesc,
          value: widget.layerAdjustCropOutside,
          onChanged: widget.onLayerAdjustCropOutsideChanged,
        );
        break;
      case CanvasTool.selection:
        content = _buildSelectionShapeRow(theme);
        break;
      case CanvasTool.text:
        content = _buildTextControls(theme);
        break;
      default:
        content = Text(l10n.noAdjustableSettings, style: theme.typography.body);
        break;
    }

    Widget padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        widthFactor: 1,
        child: content,
      ),
    );
    if (!widget.compactLayout) {
      padded = DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
          border: Border.all(
            color: theme.brightness.isDark
                ? Colors.white.withOpacity(0.12)
                : Colors.black.withOpacity(0.08),
          ),
        ),
        child: padded,
      );
    }
    return MeasuredSize(onChanged: widget.onSizeChanged, child: padded);
  }

  Widget _buildBrushControls(
    FluentThemeData theme, {
    bool includeEraserToggle = true,
  }) {
    final l10n = context.l10n;
    final bool isPenTool = widget.activeTool == CanvasTool.pen ||
        widget.activeTool == CanvasTool.perspectivePen;
    final bool isEraserTool = widget.activeTool == CanvasTool.eraser;
    final bool isCurvePenTool = widget.activeTool == CanvasTool.curvePen;
    final bool isShapeTool = widget.activeTool == CanvasTool.shape;
    final bool showAdvancedBrushToggles =
        isPenTool || isCurvePenTool || isShapeTool || isEraserTool;

    final List<Widget> wrapChildren = <Widget>[
      _buildBrushSizeRow(theme),
      _buildBrushShapeRow(theme),
      if (isPenTool || isEraserTool) _buildStrokeStabilizerRow(theme),
    ];

    if (showAdvancedBrushToggles) {
      wrapChildren.add(_buildBrushAntialiasRow(theme));
      if (isShapeTool) {
        wrapChildren.add(
          _buildToggleSwitchRow(
            theme,
            label: l10n.solidFill,
            detail: l10n.solidFillDesc,
            value: widget.shapeFillEnabled,
            onChanged: widget.onShapeFillChanged,
          ),
        );
      }
      wrapChildren.add(
        _buildToggleSwitchRow(
          theme,
          label: l10n.autoSharpTaper,
          detail: l10n.autoSharpTaperDesc,
          value: widget.autoSharpPeakEnabled,
          onChanged: widget.onAutoSharpPeakChanged,
        ),
      );
      wrapChildren.add(
        _buildToggleSwitchRow(
          theme,
          label: l10n.stylusPressure,
          detail: l10n.stylusPressureDesc,
          value: widget.stylusPressureEnabled,
          onChanged: widget.onStylusPressureEnabledChanged,
        ),
      );
      wrapChildren.add(
        _buildToggleSwitchRow(
          theme,
          label: l10n.simulatedPressure,
          detail: l10n.simulatedPressureDesc,
          value: widget.simulatePenPressure,
          onChanged: widget.onSimulatePenPressureChanged,
        ),
      );
      if (includeEraserToggle) {
        wrapChildren.add(
          _buildToggleSwitchRow(
            theme,
            label: l10n.switchToEraser,
            detail: l10n.switchToEraserDesc,
            value: widget.brushToolsEraserMode,
            onChanged: widget.onBrushToolsEraserModeChanged,
          ),
        );
      }
      wrapChildren.add(
        _buildToggleSwitchRow(
          theme,
          label: l10n.vectorDrawing,
          detail: l10n.vectorDrawingDesc,
          value: widget.vectorDrawingEnabled,
          onChanged: widget.onVectorDrawingEnabledChanged,
        ),
      );
      if (widget.vectorDrawingEnabled) {
        wrapChildren.add(
          _buildToggleSwitchRow(
            theme,
            label: l10n.smoothCurve,
            detail: l10n.smoothCurveDesc,
            value: widget.vectorStrokeSmoothingEnabled,
            onChanged: widget.onVectorStrokeSmoothingChanged,
          ),
        );
      }
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

  Widget _buildSprayControls(FluentThemeData theme) {
    final l10n = context.l10n;
    final List<Widget> children = <Widget>[
      _buildBrushSizeRow(theme),
      _buildSprayModeSelector(theme),
      _buildToggleSwitchRow(
        theme,
        label: l10n.switchToEraser,
        detail: l10n.switchToEraserDesc,
        value: widget.brushToolsEraserMode,
        onChanged: widget.onBrushToolsEraserModeChanged,
      ),
    ];
    if (widget.sprayMode == SprayMode.splatter) {
      children.add(_buildBrushAntialiasRow(theme));
    }
    return _buildControlsGroup(
      children,
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
    );
  }

  Widget _buildSprayModeSelector(FluentThemeData theme) {
    return _buildLabeledComboField<SprayMode>(
      theme,
      label: context.l10n.sprayEffect,
      detail: context.l10n.sprayEffectDesc,
      width: 180,
      value: widget.sprayMode,
      items: SprayMode.values
          .map(
            (mode) => ComboBoxItem<SprayMode>(
              value: mode,
              child: Text(_sprayModeLabel(mode)),
            ),
          )
          .toList(growable: false),
      onChanged: (mode) {
        if (mode != null) {
          widget.onSprayModeChanged(mode);
        }
      },
    );
  }

  Widget _buildBrushShapeRow(FluentThemeData theme) {
    final Widget selector = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: BrushShape.values
          .map((shape) => _buildBrushShapeButton(theme, shape))
          .toList(),
    );

    if (!widget.compactLayout) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(context.l10n.brushShape, style: theme.typography.bodyStrong),
          const SizedBox(width: 8),
          selector,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.brushShape, style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        selector,
      ],
    );
  }

  Widget _buildSelectionShapeRow(FluentThemeData theme) {
    final Widget selector = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SelectionShape.values
          .map((shape) => _buildSelectionShapeButton(theme, shape))
          .toList(),
    );

    if (!widget.compactLayout) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(context.l10n.selectionShape, style: theme.typography.bodyStrong),
          const SizedBox(width: 8),
          selector,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.selectionShape, style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        selector,
      ],
    );
  }

  Widget _buildTextControls(FluentThemeData theme) {
    final l10n = context.l10n;
    final List<String> fontOptions = <String>[
      'System Default',
      ...widget.availableFontFamilies,
    ];
    final bool fontAvailable =
        widget.textFontFamily.isNotEmpty &&
        widget.availableFontFamilies.contains(widget.textFontFamily);
    final String selectedFont = fontAvailable ? widget.textFontFamily : 'System Default';
    final List<Widget> children = <Widget>[
      _buildFontSelectorRow(
        theme,
        fontOptions: fontOptions,
        selectedFont: selectedFont,
        isLoading: widget.fontsLoading,
      ),
      _buildLabeledSlider(
        theme: theme,
        label: l10n.fontSize,
        detail: l10n.fontSizeDesc,
        value: widget.textFontSize,
        min: 6,
        max: 200,
        formatter: (value) => '${value.toStringAsFixed(0)} px',
        onChanged: widget.onTextFontSizeChanged,
      ),
      _buildLabeledSlider(
        theme: theme,
        label: l10n.lineHeight,
        detail: l10n.lineHeightDesc,
        value: widget.textLineHeight,
        min: 0.5,
        max: 3.0,
        formatter: (value) => value.toStringAsFixed(2),
        onChanged: widget.onTextLineHeightChanged,
      ),
      _buildLabeledSlider(
        theme: theme,
        label: l10n.letterSpacing,
        detail: l10n.letterSpacingDesc,
        value: widget.textLetterSpacing,
        min: -100,
        max: 200,
        formatter: (value) => '${value.toStringAsFixed(1)} px',
        onChanged: widget.onTextLetterSpacingChanged,
      ),
      _buildTextAlignRow(theme),
      _buildTextOrientationRow(theme),
      _buildToggleSwitchRow(
        theme,
        label: l10n.antialiasingBeforeExport,
        detail: l10n.textAntialiasingDesc,
        value: widget.textAntialias,
        onChanged: widget.onTextAntialiasChanged,
      ),
      _buildToggleSwitchRow(
        theme,
        label: l10n.textStroke,
        detail: l10n.textStrokeDesc,
        value: widget.textStrokeEnabled,
        onChanged: widget.onTextStrokeEnabledChanged,
      ),
    ];

    if (widget.textStrokeEnabled) {
      children.add(_buildTextStrokeColorRow(theme));
      children.add(
        _buildLabeledSlider(
          theme: theme,
          label: l10n.strokeWidth,
          detail: l10n.strokeWidthDesc,
          value: widget.textStrokeWidth,
          min: 0.5,
          max: 20,
          formatter: (value) => value.toStringAsFixed(1),
          onChanged: widget.onTextStrokeWidthChanged,
        ),
      );
    }
    return _buildControlsGroup(
      children,
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
    );
  }

  Widget _buildFontSelectorRow(
    FluentThemeData theme, {
    required List<String> fontOptions,
    required String selectedFont,
    required bool isLoading,
  }) {
    final ComboBox<String> comboBox = ComboBox<String>(
      value: selectedFont,
      isExpanded: true,
      items: fontOptions
          .map(
            (family) => ComboBoxItem<String>(
              value: family,
              child: Text(
                _sanitizeDisplayText(family),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        if (value == null) {
          return;
        }
        widget.onTextFontFamilyChanged(value == 'System Default' ? '' : value);
      },
    );

    final Widget loadingIndicator = SizedBox(
      width: 18,
      height: 18,
      child: const ProgressRing(strokeWidth: 2.0),
    );

    if (!widget.compactLayout) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(context.l10n.fontFamily, style: theme.typography.bodyStrong),
          const SizedBox(width: 8),
          SizedBox(width: 220, child: comboBox),
          if (isLoading) ...[const SizedBox(width: 8), loadingIndicator],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.fontFamily, style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: comboBox),
            if (isLoading) ...[const SizedBox(width: 8), loadingIndicator],
          ],
        ),
      ],
    );
  }

  Widget _buildTextStrokeColorRow(FluentThemeData theme) {
    final l10n = context.l10n;
    final Color borderColor = theme.resources.controlStrokeColorDefault;
    final Widget colorButton = _wrapButtonTooltip(
      label: l10n.strokeColor,
      detail: 'Open color picker', // TODO: Add tooltip desc
      child: Button(
        onPressed: widget.onTextStrokeColorPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: widget.textStrokeColor,
                border: Border.all(color: borderColor),
              ),
            ),
            const SizedBox(width: 8),
            Text(l10n.pickColor),
          ],
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.strokeColor, style: theme.typography.bodyStrong),
        const SizedBox(width: 12),
        colorButton,
      ],
    );
  }

  Widget _buildTextAlignRow(FluentThemeData theme) {
    final l10n = context.l10n;
    final List<TextAlign> alignments = <TextAlign>[
      TextAlign.left,
      TextAlign.center,
      TextAlign.right,
    ];
    final Wrap alignSelector = Wrap(
      spacing: 8,
      children: alignments
          .map((alignment) {
            final bool selected = widget.textAlign == alignment;
            final IconData icon;
            final String optionLabel;
            switch (alignment) {
              case TextAlign.center:
                icon = FluentIcons.align_center;
                optionLabel = l10n.alignCenter;
                break;
              case TextAlign.right:
                icon = FluentIcons.align_right;
                optionLabel = l10n.alignRight;
                break;
              case TextAlign.left:
              default:
                icon = FluentIcons.align_left;
                optionLabel = l10n.alignLeft;
                break;
            }
            return _wrapButtonTooltip(
              label: '${l10n.alignment}: $optionLabel',
              detail: 'Switch alignment',
              child: ToggleButton(
                checked: selected,
                onChanged: (_) => widget.onTextAlignChanged(alignment),
                child: Icon(icon),
              ),
            );
          })
          .toList(growable: false),
    );
    if (!widget.compactLayout) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(l10n.alignment, style: theme.typography.bodyStrong),
          const SizedBox(width: 8),
          alignSelector,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.alignment, style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        alignSelector,
      ],
    );
  }

  Widget _buildTextOrientationRow(FluentThemeData theme) {
    final l10n = context.l10n;
    final Wrap orientationSelector = Wrap(
      spacing: 8,
      children: CanvasTextOrientation.values
          .map((orientation) {
            final bool selected = widget.textOrientation == orientation;
            final String label = orientation == CanvasTextOrientation.horizontal
                ? l10n.horizontal
                : l10n.vertical;
            return _wrapButtonTooltip(
              label: '${l10n.orientation}: $label',
              detail: 'Switch orientation',
              child: ToggleButton(
                checked: selected,
                onChanged: (_) => widget.onTextOrientationChanged(orientation),
                child: Text(label),
              ),
            );
          })
          .toList(growable: false),
    );
    if (!widget.compactLayout) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(l10n.orientation, style: theme.typography.bodyStrong),
          const SizedBox(width: 8),
          orientationSelector,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.orientation, style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        orientationSelector,
      ],
    );
  }

  Widget _buildTextToolHint(FluentThemeData theme) {
    return SizedBox(
      width: widget.compactLayout ? double.infinity : 320,
      child: Text(
        context.l10n.textToolHint,
        style: theme.typography.caption,
      ),
    );
  }

  String _sanitizeDisplayText(String raw) {
    if (raw.isEmpty) {
      return raw;
    }
    final List<int> units = raw.codeUnits;
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < units.length; i++) {
      final int unit = units[i];
      if (unit < 0x20) {
        continue;
      }
      if (_isLowSurrogate(unit)) {
        continue;
      }
      if (_isHighSurrogate(unit)) {
        if (i + 1 < units.length && _isLowSurrogate(units[i + 1])) {
          final int high = unit;
          final int low = units[++i];
          final int codePoint =
              0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00);
          buffer.writeCharCode(codePoint);
        } else {
          buffer.writeCharCode(0xFFFD);
        }
        continue;
      }
      buffer.writeCharCode(unit);
    }
    return buffer.toString();
  }

  bool _isHighSurrogate(int value) => value >= 0xD800 && value <= 0xDBFF;

  bool _isLowSurrogate(int value) => value >= 0xDC00 && value <= 0xDFFF;

  Widget _buildLabeledSlider({
    required FluentThemeData theme,
    required String label,
    required String detail,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    String Function(double)? formatter,
  }) {
    final String display = formatter == null
        ? value.toStringAsFixed(1)
        : formatter(value);
    final Slider slider = Slider(
      min: min,
      max: max,
      value: value.clamp(min, max),
      onChanged: onChanged,
    );
    if (!widget.compactLayout) {
      final Widget sliderControl = _wrapSliderTooltip(
        label: label,
        detail: detail,
        valueText: display,
        child: SizedBox(width: _defaultSliderWidth, child: slider),
      );
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('$label：$display', style: theme.typography.body),
          const SizedBox(width: 8),
          sliderControl,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label：$display', style: theme.typography.body),
        const SizedBox(height: 4),
        _wrapSliderTooltip(
          label: label,
          detail: detail,
          valueText: display,
          child: slider,
        ),
      ],
    );
  }

  Widget _buildShapeVariantRow(FluentThemeData theme) {
    final Widget selector = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ShapeToolVariant.values
          .map((variant) => _buildShapeVariantButton(theme, variant))
          .toList(),
    );

    if (!widget.compactLayout) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(context.l10n.shapeType, style: theme.typography.bodyStrong),
          const SizedBox(width: 8),
          selector,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.shapeType, style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        selector,
      ],
    );
  }

  Widget _buildShapeVariantButton(
    FluentThemeData theme,
    ShapeToolVariant variant,
  ) {
    return _buildIconToggleButton(
      theme: theme,
      isSelected: widget.shapeToolVariant == variant,
      tooltip: context.l10n.shapeVariantLabel(variant),
      detail: context.l10n.shapeVariantDesc(variant),
      onPressed: () => widget.onShapeToolVariantChanged(variant),
      iconBuilder: (color) => _buildShapeVariantIcon(variant, color),
    );
  }

  Widget _buildShapeVariantIcon(ShapeToolVariant variant, Color color) {
    switch (variant) {
      case ShapeToolVariant.rectangle:
        return Icon(FluentIcons.rectangle_shape, size: 18, color: color);
      case ShapeToolVariant.ellipse:
        return Icon(FluentIcons.circle_shape, size: 18, color: color);
      case ShapeToolVariant.triangle:
        return Icon(FluentIcons.triangle_shape, size: 18, color: color);
      case ShapeToolVariant.line:
        return SvgPicture.asset(
          'icons/line2.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
    }
  }

  Widget _buildSelectionShapeButton(
    FluentThemeData theme,
    SelectionShape shape,
  ) {
    return _buildIconToggleButton(
      theme: theme,
      isSelected: widget.selectionShape == shape,
      tooltip: context.l10n.selectionShapeLabel(shape),
      detail: context.l10n.selectionShapeDesc(shape),
      onPressed: () => widget.onSelectionShapeChanged(shape),
      iconBuilder: (color) => _buildSelectionShapeIcon(shape, color),
    );
  }

  Widget _buildSelectionShapeIcon(SelectionShape shape, Color color) {
    return SelectionShapeIcon(shape: shape, color: color, size: 18);
  }

  Widget _buildIconToggleButton({
    required FluentThemeData theme,
    required bool isSelected,
    required String tooltip,
    required String? detail,
    required VoidCallback onPressed,
    required Widget Function(Color color) iconBuilder,
  }) {
    final Color accent = theme.accentColor.defaultBrushFor(theme.brightness);
    final Color inactiveBackground = theme.resources.subtleFillColorSecondary;
    final Color baseBackground = isSelected
        ? accent.withOpacity(theme.brightness.isDark ? 0.35 : 0.2)
        : inactiveBackground;
    final Color hoverBackground =
        Color.lerp(baseBackground, accent.withOpacity(0.6), 0.2) ??
        baseBackground;
    final Color pressedBackground =
        Color.lerp(baseBackground, accent.withOpacity(0.8), 0.35) ??
        baseBackground;
    final Color borderColor = isSelected
        ? accent
        : theme.resources.controlStrokeColorDefault;
    final Color iconColor = isSelected
        ? accent
        : theme.typography.body?.color ?? theme.resources.textFillColorPrimary;

    return _wrapButtonTooltip(
      label: tooltip,
      detail: detail,
      child: Button(
        onPressed: onPressed,
        style: ButtonStyle(
          padding: WidgetStateProperty.all<EdgeInsets>(
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return pressedBackground;
            }
            if (states.contains(WidgetState.hovered)) {
              return hoverBackground;
            }
            return baseBackground;
          }),
          shape: WidgetStateProperty.all<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: borderColor, width: 1),
            ),
          ),
          foregroundColor: WidgetStateProperty.all<Color>(iconColor),
        ),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(child: iconBuilder(iconColor)),
        ),
      ),
    );
  }

  Widget _buildBrushShapeButton(FluentThemeData theme, BrushShape shape) {
    final l10n = context.l10n;
    final bool isSelected = widget.brushShape == shape;
    final Color accent = theme.accentColor.defaultBrushFor(theme.brightness);
    final Color inactiveBackground = theme.resources.subtleFillColorSecondary;
    final Color baseBackground = isSelected
        ? accent.withOpacity(theme.brightness.isDark ? 0.35 : 0.2)
        : inactiveBackground;
    final Color hoverBackground =
        Color.lerp(baseBackground, accent.withOpacity(0.6), 0.2) ??
        baseBackground;
    final Color pressedBackground =
        Color.lerp(baseBackground, accent.withOpacity(0.8), 0.35) ??
        baseBackground;
    final Color borderColor = isSelected
        ? accent
        : theme.resources.controlStrokeColorDefault;
    final TextStyle textStyle =
        (theme.typography.body ?? const TextStyle(fontSize: 12)).copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        );

    final String label = l10n.brushShapeLabel(shape);
    return _wrapButtonTooltip(
      label: label,
      detail: l10n.brushShapeDesc(shape),
      child: Button(
        onPressed: () => widget.onBrushShapeChanged(shape),
        style: ButtonStyle(
          padding: WidgetStateProperty.all<EdgeInsets>(
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return pressedBackground;
            }
            if (states.contains(WidgetState.hovered)) {
              return hoverBackground;
            }
            return baseBackground;
          }),
          shape: WidgetStateProperty.all<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: borderColor, width: 1),
            ),
          ),
          foregroundColor: WidgetStateProperty.all<Color>(
            theme.typography.body?.color ??
                theme.resources.textFillColorPrimary,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _brushShapeIcon(shape),
              size: 14,
              color: isSelected
                  ? accent
                  : theme.typography.body?.color ??
                        theme.resources.textFillColorPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: textStyle.copyWith(
                color:
                    theme.typography.body?.color ??
                    theme.resources.textFillColorPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToleranceSlider(
    FluentThemeData theme, {
    required String label,
    required String detail,
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
      final Widget sliderControl = _wrapSliderTooltip(
        label: label,
        detail: detail,
        valueText: '$value',
        child: SizedBox(width: _defaultSliderWidth, child: slider),
      );
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: theme.typography.bodyStrong),
          const SizedBox(width: 8),
          sliderControl,
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
    return _buildSliderSection(
      theme,
      label: label,
      valueText: '$value',
      slider: slider,
      tooltipText: '$label：$value',
      detail: detail,
    );
  }

  double _clampBrushValue(double value) {
    if (_isSprayTool) {
      final double clamped = value.clamp(kSprayStrokeMin, kSprayStrokeMax);
      return clamped.roundToDouble();
    }
    return widget.penStrokeSliderRange.clamp(value);
  }

  void _notifyBrushSizeChanged(double value) {
    final double clamped = _clampBrushValue(value);
    if (_isSprayTool) {
      if ((clamped - widget.sprayStrokeWidth).abs() < 0.0005) {
        return;
      }
      widget.onSprayStrokeWidthChanged(clamped);
    } else {
      if ((clamped - widget.penStrokeWidth).abs() < 0.0005) {
        return;
      }
      widget.onPenStrokeWidthChanged(clamped);
    }
  }

  String _formatBrushValue(double value) {
    if (_isSprayTool) {
      return value.round().toString();
    }
    return _formatValue(value);
  }

  Widget _buildBrushSizeRow(FluentThemeData theme) {
    final l10n = context.l10n;
    final double brushSize = _clampBrushValue(_activeBrushValue);
    final bool sliderUsesIntegers = _sliderUsesIntegers;
    final double sliderValue = sliderUsesIntegers
        ? brushSize.roundToDouble()
        : brushSize;
    final int? sliderDivisions = sliderUsesIntegers
        ? (_activeSliderMax - _activeSliderMin).round()
        : null;
    final String brushLabel = sliderUsesIntegers
        ? brushSize.round().toString()
        : _formatValue(brushSize);
    final String labelText = _isSprayTool ? l10n.spraySize : l10n.brushSize;
    final String detailText = _isSprayTool ? l10n.spraySizeDesc : l10n.brushSizeDesc;
    final Slider slider = Slider(
      value: sliderValue,
      min: _activeSliderMin,
      max: _activeSliderMax,
      divisions: sliderDivisions,
      onChanged: (raw) {
        final double nextValue = sliderUsesIntegers ? raw.roundToDouble() : raw;
        _notifyBrushSizeChanged(nextValue);
        if (!_focusNode.hasFocus) {
          final String formatted = _formatBrushValue(nextValue);
          if (_controller.text != formatted) {
            _isProgrammaticTextUpdate = true;
            _controller.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );
            _isProgrammaticTextUpdate = false;
          }
        }
      },
    );
    Widget buildStandardAdjustRow() {
      return Row(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(width: 6),
          Text('px', style: theme.typography.caption),
        ],
      );
    }

    Widget buildCompactAdjustRow() {
      return Row(
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
      );
    }

    if (!widget.compactLayout) {
      final Widget sliderControl = _wrapSliderTooltip(
        label: labelText,
        detail: detailText,
        valueText: '$brushLabel px',
        child: SizedBox(width: _defaultSliderWidth, child: slider),
      );
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(labelText, style: theme.typography.bodyStrong),
          const SizedBox(width: 8),
          sliderControl,
          const SizedBox(width: 8),
          buildStandardAdjustRow(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSliderSection(
          theme,
          label: labelText,
          valueText: '$brushLabel px',
          slider: slider,
          tooltipText: '$labelText：$brushLabel px',
          detail: detailText,
        ),
        const SizedBox(height: 8),
        buildCompactAdjustRow(),
      ],
    );
  }

  Widget _buildBrushAntialiasRow(FluentThemeData theme) {
    final l10n = context.l10n;
    return _buildAntialiasRow(
      theme,
      value: widget.brushAntialiasLevel,
      onChanged: widget.onBrushAntialiasChanged,
      detail: l10n.antialiasingSliderDesc,
    );
  }

  Widget _buildBucketAntialiasRow(FluentThemeData theme) {
    final l10n = context.l10n;
    return _buildAntialiasRow(
      theme,
      value: widget.bucketAntialiasLevel,
      onChanged: widget.onBucketAntialiasChanged,
      detail: l10n.antialiasingSliderDesc,
    );
  }

  Widget _buildAntialiasRow(
    FluentThemeData theme, {
    required int value,
    required ValueChanged<int> onChanged,
    required String detail,
  }) {
    final l10n = context.l10n;
    final Slider slider = Slider(
      value: value.toDouble(),
      min: 0,
      max: 3,
      divisions: 3,
      onChanged: (raw) => onChanged(raw.round()),
    );
    final String levelLabel = l10n.levelLabel(value);
    if (!widget.compactLayout) {
      final Widget sliderControl = _wrapSliderTooltip(
        label: l10n.antialiasingBeforeExport,
        detail: detail,
        valueText: levelLabel,
        child: SizedBox(width: _defaultSliderWidth, child: slider),
      );
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.antialiasingBeforeExport, style: theme.typography.bodyStrong),
          const SizedBox(width: 8),
          sliderControl,
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(
              levelLabel,
              style: theme.typography.caption,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      );
    }
    return _buildSliderSection(
      theme,
      label: l10n.antialiasingBeforeExport,
      valueText: levelLabel,
      slider: slider,
      tooltipText: '${l10n.antialiasingBeforeExport}: $levelLabel',
      detail: detail,
    );
  }

  Widget _buildStrokeStabilizerRow(FluentThemeData theme) {
    final l10n = context.l10n;
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
    final String label = level == 0 ? l10n.off : l10n.levelLabel(level);
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
      final Widget sliderControl = _wrapSliderTooltip(
        label: l10n.stabilizer,
        detail: l10n.stabilizerDesc,
        valueText: label,
        child: SizedBox(width: _defaultSliderWidth, child: slider),
      );
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.stabilizer, style: theme.typography.bodyStrong),
          const SizedBox(width: 8),
          sliderControl,
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
    return _buildSliderSection(
      theme,
      label: l10n.stabilizer,
      valueText: label,
      slider: slider,
      tooltipText: '${l10n.stabilizer}: $label',
      detail: l10n.stabilizerDesc,
    );
  }

  Widget _buildToggleSwitchRow(
    FluentThemeData theme, {
    required String label,
    required String detail,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    final Widget toggle = _wrapToggleTooltip(
      label: label,
      detail: detail,
      child: ToggleSwitch(checked: value, onChanged: onChanged),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.typography.bodyStrong),
        const SizedBox(width: 8),
        toggle,
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

  Widget _buildSliderSection(
    FluentThemeData theme, {
    required String label,
    required String valueText,
    required Widget slider,
    required String detail,
    String? tooltipText,
  }) {
    Widget sliderWidget = LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(width: constraints.maxWidth, child: slider);
      },
    );
    sliderWidget = _wrapSliderTooltip(
      label: label,
      detail: detail,
      valueText: valueText,
      child: sliderWidget,
      messageOverride: tooltipText,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(label, style: theme.typography.bodyStrong),
            const SizedBox(width: 8),
            Text(valueText, style: theme.typography.caption),
          ],
        ),
        const SizedBox(height: 8),
        sliderWidget,
      ],
    );
  }

  Widget _wrapSliderTooltip({
    required String label,
    required String detail,
    required String valueText,
    required Widget child,
    String? messageOverride,
  }) {
    final String message = messageOverride ?? '$label: $valueText';
    return HoverDetailTooltip(
      message: message,
      detail: detail,
      child: child,
    );
  }

  Widget _wrapButtonTooltip({
    required String label,
    required String? detail,
    required Widget child,
  }) {
    return HoverDetailTooltip(
      message: label,
      detail: detail,
      child: child,
    );
  }

  Widget _wrapToggleTooltip({
    required String label,
    required String detail,
    required Widget child,
  }) {
    return HoverDetailTooltip(
      message: label,
      detail: detail,
      child: child,
    );
  }

  Widget _wrapComboTooltip({
    required String label,
    required String detail,
    required Widget child,
  }) {
    return HoverDetailTooltip(
      message: label,
      detail: detail,
      child: child,
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

  Widget _buildLabeledComboField<T>(
    FluentThemeData theme, {
    required String label,
    required String detail,
    required double width,
    required T value,
    required List<ComboBoxItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final Widget combo = _wrapComboTooltip(
      label: label,
      detail: detail,
      child: SizedBox(
        width: widget.compactLayout ? double.infinity : width,
        child: ComboBox<T>(value: value, items: items, onChanged: onChanged),
      ),
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
    final l10n = context.l10n;
    switch (profile) {
      case StrokePressureProfile.taperEnds:
        return l10n.taperEnds;
      case StrokePressureProfile.taperCenter:
        return l10n.taperCenter;
      case StrokePressureProfile.auto:
        return l10n.auto;
    }
  }

  String _sprayModeLabel(SprayMode mode) {
    final l10n = context.l10n;
    switch (mode) {
      case SprayMode.smudge:
        return l10n.softSpray;
      case SprayMode.splatter:
        return l10n.splatter;
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
    final double clamped = _clampBrushValue(parsed);
    final String formatted = _formatBrushValue(clamped);
    if (_controller.text != formatted) {
      _isProgrammaticTextUpdate = true;
      _controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      _isProgrammaticTextUpdate = false;
    }
    _notifyBrushSizeChanged(clamped);
  }

  void _handleFocusChange() {
    final String formatted = _formatBrushValue(_activeBrushValue);
    if (_controller.text != formatted) {
      _isProgrammaticTextUpdate = true;
      _controller.text = formatted;
      _isProgrammaticTextUpdate = false;
    }
  }

  void _adjustBrushSizeBy(int delta) {
    final double nextValue = _clampBrushValue(_activeBrushValue + delta);
    final double previousValue = _isSprayTool
        ? widget.sprayStrokeWidth
        : widget.penStrokeWidth;
    if ((nextValue - previousValue).abs() < 0.0005) {
      return;
    }
    _notifyBrushSizeChanged(nextValue);
    final String formatted = _formatBrushValue(nextValue);
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
    final l10n = context.l10n;
    final String action = delta > 0 ? l10n.increase : l10n.decrease;
    final int amount = delta.abs();
    final String label = l10n.brushFineTune;
    final String detail = '$action ${l10n.brushSize} ${amount}px';
    return SizedBox(
      width: 28,
      height: 28,
      child: HoverDetailTooltip(
        message: '$label ($action)',
        detail: detail,
        child: IconButton(
          icon: Icon(icon, size: 14),
          onPressed: () => _adjustBrushSizeBy(delta),
        ),
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
    required this.detail,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final String title;
  final String detail;
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
        HoverDetailTooltip(
          message: title,
          detail: detail,
          child: ToggleSwitch(checked: value, onChanged: onChanged),
        ),
      ],
    );
  }
}

String _selectionShapeLabel(SelectionShape shape) {
  // Localization requires context, so this helper is less useful outside of widget build.
  // We will move this logic to build method or make it extension on context or pass l10n.
  return '';
}

// We will use extensions on l10n to map enums.
extension on AppLocalizations {
  String selectionShapeLabel(SelectionShape shape) {
    switch (shape) {
      case SelectionShape.rectangle:
        return rectSelection;
      case SelectionShape.ellipse:
        return ellipseSelection;
      case SelectionShape.polygon:
        return polygonLasso;
    }
  }

  String selectionShapeDesc(SelectionShape shape) {
    switch (shape) {
      case SelectionShape.rectangle:
        return rectSelectDesc;
      case SelectionShape.ellipse:
        return ellipseSelectDesc;
      case SelectionShape.polygon:
        return polyLassoDesc;
    }
  }

  String shapeVariantLabel(ShapeToolVariant variant) {
    switch (variant) {
      case ShapeToolVariant.rectangle:
        return rectangle;
      case ShapeToolVariant.ellipse:
        return ellipse;
      case ShapeToolVariant.triangle:
        return triangle;
      case ShapeToolVariant.line:
        return line;
    }
  }

  String shapeVariantDesc(ShapeToolVariant variant) {
    switch (variant) {
      case ShapeToolVariant.rectangle:
        return rectShapeDesc;
      case ShapeToolVariant.ellipse:
        return ellipseShapeDesc;
      case ShapeToolVariant.triangle:
        return triangleShapeDesc;
      case ShapeToolVariant.line:
        return lineShapeDesc;
    }
  }

  String brushShapeLabel(BrushShape shape) {
    switch (shape) {
      case BrushShape.circle:
        return circle;
      case BrushShape.triangle:
        return triangle;
      case BrushShape.square:
        return square;
    }
  }

  String brushShapeDesc(BrushShape shape) {
    switch (shape) {
      case BrushShape.circle:
        return circleTipDesc;
      case BrushShape.triangle:
        return triangleShapeDesc;
      case BrushShape.square:
        return squareTipDesc;
    }
  }
}

IconData _brushShapeIcon(BrushShape shape) {
  switch (shape) {
    case BrushShape.circle:
      return FluentIcons.circle_shape;
    case BrushShape.triangle:
      return FluentIcons.triangle_shape;
    case BrushShape.square:
      return FluentIcons.square_shape;
  }
}
