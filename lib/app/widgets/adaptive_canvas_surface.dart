import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../canvas/canvas_engine_bridge.dart';
import '../../canvas/canvas_frame.dart';
import '../../canvas/canvas_tools.dart';
import 'bitmap_canvas_surface.dart';
import 'backend_canvas_surface.dart';

class AdaptiveCanvasSurface extends StatelessWidget {
  const AdaptiveCanvasSurface({
    super.key,
    required this.surfaceKey,
    required this.canvasSize,
    required this.frame,
    required this.enableDrawing,
    this.allowBackendCanvas = true,
    this.layerCount = 1,
    required this.brushColorArgb,
    required this.brushRadius,
    required this.erase,
    required this.brushShape,
    required this.brushRandomRotationEnabled,
    required this.brushSmoothRotationEnabled,
    required this.brushRotationSeed,
    required this.brushSpacing,
    required this.brushHardness,
    required this.brushFlow,
    required this.brushScatter,
    required this.brushRotationJitter,
    required this.brushSnapToPixel,
    required this.brushScreentoneEnabled,
    required this.brushScreentoneSpacing,
    required this.brushScreentoneDotSize,
    required this.brushScreentoneRotation,
    required this.brushScreentoneSoftness,
    required this.brushScreentoneShape,
    required this.brushBristleEnabled,
    required this.brushBristleDensity,
    required this.brushBristleRandom,
    required this.brushBristleScale,
    required this.brushBristleShear,
    required this.brushBristleThreshold,
    required this.brushBristleConnected,
    required this.brushBristleUsePressure,
    required this.brushBristleAntialias,
    required this.brushBristleUseCompositing,
    required this.brushInkAmount,
    required this.brushInkDepletion,
    required this.brushInkUseOpacity,
    required this.brushInkDepletionEnabled,
    required this.brushInkUseSaturation,
    required this.brushInkUseWeights,
    required this.brushInkPressureWeight,
    required this.brushInkBristleLengthWeight,
    required this.brushInkBristleInkAmountWeight,
    required this.brushInkDepletionWeight,
    required this.brushInkUseSoak,
    required this.brushInkDepletionCurve,
    this.hollowStrokeEnabled = false,
    this.hollowStrokeRatio = 0.0,
    this.hollowStrokeEraseOccludedParts = false,
    this.antialiasLevel = 1,
    this.backgroundColorArgb = 0xFFFFFFFF,
    this.usePressure = true,
    this.stylusCurve = 1.0,
    this.streamlineStrength = 0.0,
    this.strokeStabilizerStrength = 0.0,
    this.onStrokeBegin,
    this.onEngineInfoChanged,
  });

  final String surfaceKey;
  final ui.Size canvasSize;
  final CanvasFrame? frame;
  final bool enableDrawing;
  final bool allowBackendCanvas;
  final int layerCount;
  final int brushColorArgb;
  final double brushRadius;
  final bool erase;
  final BrushShape brushShape;
  final bool brushRandomRotationEnabled;
  final bool brushSmoothRotationEnabled;
  final int brushRotationSeed;
  final double brushSpacing;
  final double brushHardness;
  final double brushFlow;
  final double brushScatter;
  final double brushRotationJitter;
  final bool brushSnapToPixel;
  final bool brushScreentoneEnabled;
  final double brushScreentoneSpacing;
  final double brushScreentoneDotSize;
  final double brushScreentoneRotation;
  final double brushScreentoneSoftness;
  final BrushShape brushScreentoneShape;
  final bool brushBristleEnabled;
  final double brushBristleDensity;
  final double brushBristleRandom;
  final double brushBristleScale;
  final double brushBristleShear;
  final bool brushBristleThreshold;
  final bool brushBristleConnected;
  final bool brushBristleUsePressure;
  final bool brushBristleAntialias;
  final bool brushBristleUseCompositing;
  final double brushInkAmount;
  final double brushInkDepletion;
  final bool brushInkUseOpacity;
  final bool brushInkDepletionEnabled;
  final bool brushInkUseSaturation;
  final bool brushInkUseWeights;
  final double brushInkPressureWeight;
  final double brushInkBristleLengthWeight;
  final double brushInkBristleInkAmountWeight;
  final double brushInkDepletionWeight;
  final bool brushInkUseSoak;
  final List<double> brushInkDepletionCurve;
  final bool hollowStrokeEnabled;
  final double hollowStrokeRatio;
  final bool hollowStrokeEraseOccludedParts;
  final int antialiasLevel;
  final int backgroundColorArgb;
  final bool usePressure;
  final double stylusCurve;
  final double streamlineStrength;
  final double strokeStabilizerStrength;
  final VoidCallback? onStrokeBegin;
  final void Function(
    int? handle,
    ui.Size? engineSize,
    bool isNewEngine,
    int? textureId,
  )? onEngineInfoChanged;

  @override
  Widget build(BuildContext context) {
    final bool useBackendCanvas =
        allowBackendCanvas && CanvasBackendFacade.instance.isSupported;
    if (useBackendCanvas) {
      return BackendCanvasSurface(
        surfaceKey: surfaceKey,
        canvasSize: canvasSize,
        enableDrawing: enableDrawing,
        layerCount: layerCount,
        brushColorArgb: brushColorArgb,
        brushRadius: brushRadius,
        erase: erase,
        brushShape: brushShape,
        brushRandomRotationEnabled: brushRandomRotationEnabled,
        brushSmoothRotationEnabled: brushSmoothRotationEnabled,
        brushRotationSeed: brushRotationSeed,
        brushSpacing: brushSpacing,
        brushHardness: brushHardness,
        brushFlow: brushFlow,
        brushScatter: brushScatter,
        brushRotationJitter: brushRotationJitter,
        brushSnapToPixel: brushSnapToPixel,
        brushScreentoneEnabled: brushScreentoneEnabled,
        brushScreentoneSpacing: brushScreentoneSpacing,
        brushScreentoneDotSize: brushScreentoneDotSize,
        brushScreentoneRotation: brushScreentoneRotation,
        brushScreentoneSoftness: brushScreentoneSoftness,
        brushScreentoneShape: brushScreentoneShape,
        brushBristleEnabled: brushBristleEnabled,
        brushBristleDensity: brushBristleDensity,
        brushBristleRandom: brushBristleRandom,
        brushBristleScale: brushBristleScale,
        brushBristleShear: brushBristleShear,
        brushBristleThreshold: brushBristleThreshold,
        brushBristleConnected: brushBristleConnected,
        brushBristleUsePressure: brushBristleUsePressure,
        brushBristleAntialias: brushBristleAntialias,
        brushBristleUseCompositing: brushBristleUseCompositing,
        brushInkAmount: brushInkAmount,
        brushInkDepletion: brushInkDepletion,
        brushInkUseOpacity: brushInkUseOpacity,
        brushInkDepletionEnabled: brushInkDepletionEnabled,
        brushInkUseSaturation: brushInkUseSaturation,
        brushInkUseWeights: brushInkUseWeights,
        brushInkPressureWeight: brushInkPressureWeight,
        brushInkBristleLengthWeight: brushInkBristleLengthWeight,
        brushInkBristleInkAmountWeight: brushInkBristleInkAmountWeight,
        brushInkDepletionWeight: brushInkDepletionWeight,
        brushInkUseSoak: brushInkUseSoak,
        brushInkDepletionCurve: brushInkDepletionCurve,
        hollowStrokeEnabled: hollowStrokeEnabled,
        hollowStrokeRatio: hollowStrokeRatio,
        hollowStrokeEraseOccludedParts: hollowStrokeEraseOccludedParts,
        antialiasLevel: antialiasLevel,
        backgroundColorArgb: backgroundColorArgb,
        usePressure: usePressure,
        stylusCurve: stylusCurve,
        streamlineStrength: streamlineStrength,
        strokeStabilizerStrength: strokeStabilizerStrength,
        onStrokeBegin: onStrokeBegin,
        onEngineInfoChanged: onEngineInfoChanged,
      );
    }
    return BitmapCanvasSurface(
      canvasSize: canvasSize,
      frame: frame,
    );
  }
}
