part of 'painting_board.dart';

class _SyntheticStrokeSample {
  const _SyntheticStrokeSample({
    required this.point,
    required this.distance,
    required this.progress,
  });

  final Offset point;
  final double distance;
  final double progress;
}

enum _SyntheticStrokeTimelineStyle { natural, fastCurve }

const double _toolButtonPadding = 16;
const double _toolbarButtonSize = CanvasToolbar.buttonSize;
const double _toolbarSpacing = CanvasToolbar.spacing;
const double _toolSettingsSpacing = 12;
const double _zoomStep = 1.1;
const double _defaultPenStrokeWidth = 3;
const double _defaultSprayStrokeWidth = kDefaultSprayStrokeWidth;
const double _sidePanelWidth = 240;
const double _sidePanelSpacing = 12;
const double _colorIndicatorSize = 56;
const double _colorIndicatorBorder = 3;
const int _recentColorCapacity = 5;
const double _initialViewportScaleFactor = 0.8;
const double _curveStrokeSampleSpacing = 3.4;
const double _syntheticStrokeMinDeltaMs =
    3.6; // keep >= StrokeDynamics._minDeltaMs
const int _strokeStabilizerMaxLevel = 30;

enum CanvasRotation {
  clockwise90,
  counterClockwise90,
  clockwise180,
  counterClockwise180,
}

class CanvasRotationResult {
  const CanvasRotationResult({
    required this.layers,
    required this.width,
    required this.height,
  });

  final List<CanvasLayerData> layers;
  final int width;
  final int height;
}

class CanvasResizeResult {
  const CanvasResizeResult({
    required this.layers,
    required this.width,
    required this.height,
  });

  final List<CanvasLayerData> layers;
  final int width;
  final int height;
}

class _ImportedImageData {
  const _ImportedImageData({
    required this.width,
    required this.height,
    required this.bytes,
  });

  final int width;
  final int height;
  final Uint8List bytes;
}

class PaintingBoard extends StatefulWidget {
  const PaintingBoard({
    super.key,
    required this.settings,
    required this.onRequestExit,
    this.isActive = true,
    this.useRustCanvas = false,
    this.onDirtyChanged,
    this.initialLayers,
    this.initialPerspectiveGuide,
    this.onUndoFallback,
    this.onRedoFallback,
    this.externalCanUndo = false,
    this.externalCanRedo = false,
    this.onResizeImage,
    this.onResizeCanvas,
    this.onReadyChanged,
    this.toolbarLayoutStyle = PaintingToolbarLayoutStyle.floating,
  });

  final CanvasSettings settings;
  final VoidCallback onRequestExit;
  final bool isActive;
  final bool useRustCanvas;
  final ValueChanged<bool>? onDirtyChanged;
  final List<CanvasLayerData>? initialLayers;
  final PerspectiveGuideState? initialPerspectiveGuide;
  final VoidCallback? onUndoFallback;
  final VoidCallback? onRedoFallback;
  final bool externalCanUndo;
  final bool externalCanRedo;
  final Future<void> Function()? onResizeImage;
  final Future<void> Function()? onResizeCanvas;
  final ValueChanged<bool>? onReadyChanged;
  final PaintingToolbarLayoutStyle toolbarLayoutStyle;

  @override
  State<PaintingBoard> createState() => PaintingBoardState();
}
