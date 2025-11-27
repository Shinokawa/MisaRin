import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../backend/canvas_painting_worker.dart';
import '../backend/canvas_raster_backend.dart';
import '../canvas/canvas_layer.dart';
import '../canvas/canvas_settings.dart';
import '../canvas/canvas_tools.dart';
import '../performance/stroke_latency_monitor.dart';
import 'bitmap_blend_utils.dart' as blend_utils;
import 'bitmap_canvas.dart';
import 'bitmap_layer_state.dart';
import 'raster_frame.dart';
import 'raster_tile_cache.dart';
import 'raster_int_rect.dart';
import 'stroke_dynamics.dart';
import 'stroke_pressure_simulator.dart';
import '../canvas/brush_shape_geometry.dart';
import '../canvas/vector_stroke_painter.dart';

export 'bitmap_layer_state.dart';

part 'controller_active_transform.dart';
part 'controller_layer_management.dart';
part 'controller_stroke.dart';
part 'controller_fill.dart';
part 'controller_composite.dart';

class BitmapCanvasController extends ChangeNotifier {
  BitmapCanvasController({
    required int width,
    required int height,
    required Color backgroundColor,
    List<CanvasLayerData>? initialLayers,
    CanvasCreationLogic creationLogic = CanvasCreationLogic.multiThread,
  }) : _width = width,
       _height = height,
       _backgroundColor = backgroundColor,
       _isMultithreaded =
           CanvasSettings.supportsMultithreadedCanvas &&
           creationLogic == CanvasCreationLogic.multiThread,
       _rasterBackend = CanvasRasterBackend(
         width: width,
         height: height,
         multithreaded:
             CanvasSettings.supportsMultithreadedCanvas &&
             creationLogic == CanvasCreationLogic.multiThread,
       ) {
    if (creationLogic == CanvasCreationLogic.multiThread && !_isMultithreaded) {
      debugPrint('CanvasPaintingWorker 未启用：当前平台不支持多线程画布，已自动回退到单线程。');
    }
    _tileCache = RasterTileCache(
      surfaceWidth: _width,
      surfaceHeight: _height,
      tileSize: _rasterBackend.tileSize,
    );
    if (initialLayers != null && initialLayers.isNotEmpty) {
      _loadFromCanvasLayers(this, initialLayers, backgroundColor);
    } else {
      _initializeDefaultLayers(this, backgroundColor);
    }
    _scheduleCompositeRefresh();
  }

  final int _width;
  final int _height;
  Color _backgroundColor;
  final List<BitmapLayerState> _layers = <BitmapLayerState>[];
  int _activeIndex = 0;
  final bool _isMultithreaded;
  bool _synchronousRasterOverride = false;

  final List<Offset> _currentStrokePoints = <Offset>[];
  final List<double> _currentStrokeRadii = <double>[];
  final List<PaintingDrawCommand> _deferredStrokeCommands =
      <PaintingDrawCommand>[];
  final List<PaintingDrawCommand> _committingStrokes =
      <PaintingDrawCommand>[]; // Strokes being rasterized
  double _currentStrokeRadius = 0;
  double _currentStrokeLastRadius = 0;
  bool _currentStrokeStylusPressureEnabled = false;
  double _currentStylusCurve = 1.0;
  double? _currentStylusLastPressure;
  int _currentStrokeAntialiasLevel = 0;
  bool _currentStrokeHasMoved = false;
  BrushShape _currentBrushShape = BrushShape.circle;
  final StrokePressureSimulator _strokePressureSimulator =
      StrokePressureSimulator();
  Color _currentStrokeColor = const Color(0xFF000000);
  bool _currentStrokeEraseMode = false;
  bool _stylusPressureEnabled = true;
  double _stylusCurve = 0.85;
  bool _vectorDrawingEnabled = true;
  static const double _kStylusSmoothing = 0.55;
  CanvasPaintingWorker? _paintingWorker;
  _PendingWorkerDrawBatch? _pendingWorkerDrawBatch;
  bool _pendingWorkerDrawScheduled = false;
  final Map<int, PaintingWorkerPatch?> _pendingWorkerPatches =
      <int, PaintingWorkerPatch?>{};
  int _paintingWorkerNextSequence = 0;
  int _paintingWorkerNextApplySequence = 0;
  int _paintingWorkerPendingTasks = 0;
  int _paintingWorkerGeneration = 0;
  final List<Completer<void>> _paintingWorkerIdleWaiters = <Completer<void>>[];
  Completer<void>? _nextFrameCompleter;
  String? _paintingWorkerSyncedLayerId;
  int _paintingWorkerSyncedRevision = -1;
  bool _paintingWorkerSelectionDirty = true;

  static const int _kAntialiasCenterWeight = 4;
  static const List<int> _kAntialiasDx = <int>[-1, 0, 1, -1, 1, -1, 0, 1];
  static const List<int> _kAntialiasDy = <int>[-1, -1, -1, 0, 0, 1, 1, 1];
  static const List<int> _kAntialiasWeights = <int>[1, 2, 1, 2, 2, 1, 2, 1];
  static const Map<int, List<double>> _kAntialiasBlendProfiles =
      <int, List<double>>{
        0: <double>[0.25],
        1: <double>[0.35, 0.35],
        2: <double>[0.45, 0.5, 0.5],
        3: <double>[0.6, 0.65, 0.7, 0.75],
      };
  static const double _kEdgeDetectMin = 0.015;
  static const double _kEdgeDetectMax = 0.4;
  static const double _kEdgeSmoothStrength = 1.0;
  static const double _kEdgeSmoothGamma = 0.55;
  static const List<int> _kGaussianKernel5x5 = <int>[
    1,
    4,
    6,
    4,
    1,
    4,
    16,
    24,
    16,
    4,
    6,
    24,
    36,
    24,
    6,
    4,
    16,
    24,
    16,
    4,
    1,
    4,
    6,
    4,
    1,
  ];
  static const int _kGaussianKernel5x5Weight = 256;
  static const int _kMaxWorkerBatchCommands = 24;
  static const int _kMaxWorkerBatchPixels = 512 * 512;

  bool _refreshScheduled = false;
  bool _compositeProcessing = false;
  Uint8List? _selectionMask;
  final CanvasRasterBackend _rasterBackend;
  late final RasterTileCache _tileCache;
  BitmapCanvasFrame? _currentFrame;
  final List<ui.Image> _pendingTileDisposals = <ui.Image>[];
  bool _tileDisposalScheduled = false;
  Uint32List? _activeLayerTranslationSnapshot;
  String? _activeLayerTranslationId;
  int _activeLayerTranslationDx = 0;
  int _activeLayerTranslationDy = 0;
  int _activeLayerTransformSnapshotWidth = 0;
  int _activeLayerTransformSnapshotHeight = 0;
  int _activeLayerTransformOriginX = 0;
  int _activeLayerTransformOriginY = 0;
  ui.Image? _activeLayerTransformImage;
  bool _activeLayerTransformPreparing = false;
  Rect? _activeLayerTransformBounds;
  Rect? _activeLayerTransformDirtyRegion;
  bool _pendingActiveLayerTransformCleanup = false;
  bool _clipLayerOverflow = false;
  final Map<String, _LayerOverflowStore> _layerOverflowStores =
      <String, _LayerOverflowStore>{};

  Uint32List? get _compositePixels => _rasterBackend.compositePixels;

  String? get _translatingLayerIdForComposite {
    if (_activeLayerTranslationSnapshot != null &&
        !_pendingActiveLayerTransformCleanup) {
      return _activeLayerTranslationId;
    }
    return null;
  }

  UnmodifiableListView<BitmapLayerState> get layers =>
      UnmodifiableListView<BitmapLayerState>(_layers);

  bool get isMultithreaded => _isMultithreaded;

  // Active stroke state for client-side prediction
  List<Offset> get activeStrokePoints =>
      UnmodifiableListView(_currentStrokePoints);
  List<double> get activeStrokeRadii =>
      UnmodifiableListView(_currentStrokeRadii);
  List<PaintingDrawCommand> get committingStrokes =>
      UnmodifiableListView(_committingStrokes);
  Color get activeStrokeColor => _currentStrokeColor;
  double get activeStrokeRadius => _currentStrokeRadius;
  BrushShape get activeStrokeShape => _currentBrushShape;
  bool get activeStrokeEraseMode => _currentStrokeEraseMode;

  String? get activeLayerId =>
      _layers.isEmpty ? null : _layers[_activeIndex].id;

  void _flushDeferredStrokeCommands() {
    if (!_vectorDrawingEnabled) {
      _commitDeferredStrokeCommandsAsRaster();
      return;
    }
    if (_currentStrokePoints.isEmpty) {
      _deferredStrokeCommands.clear();
      return;
    }

    final List<Offset> points = List<Offset>.from(_currentStrokePoints);
    final List<double> radii = List<double>.from(_currentStrokeRadii);
    final Color color = _currentStrokeColor;
    final BrushShape shape = _currentBrushShape;
    final bool erase = _currentStrokeEraseMode;
    final int antialiasLevel = _currentStrokeAntialiasLevel;

    // Create a command to persist visual state during async rasterization
    final PaintingDrawCommand vectorCommand = PaintingDrawCommand.vectorStroke(
      points: points,
      radii: radii,
      colorValue: color.value,
      shapeIndex: shape.index,
      erase: erase,
    );
    _committingStrokes.add(vectorCommand);

    // Clear active state immediately so next stroke can start
    _currentStrokePoints.clear();
    _currentStrokeRadii.clear();
    _deferredStrokeCommands.clear();

    // Calculate bounding box of the entire stroke
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    double maxRadius = 0.0;

    for (int i = 0; i < points.length; i++) {
      final Offset p = points[i];
      final double r = (i < radii.length) ? radii[i] : 1.0;
      if (r > maxRadius) maxRadius = r;

      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    // Inflate bounds by max radius + padding
    final double inflate = maxRadius + 2.0;
    final Rect dirtyRegion = Rect.fromLTRB(
      minX,
      minY,
      maxX,
      maxY,
    ).inflate(inflate);

    // Rasterize vector stroke on main thread (asynchronously) to get pixels
    _rasterizeVectorStroke(
      points,
      radii,
      color,
      shape,
      dirtyRegion,
      erase,
      antialiasLevel,
    ).then((_) {
      _committingStrokes.remove(vectorCommand);
      notifyListeners(); // Update UI to remove overlay
    });
  }

  Future<void> _rasterizeVectorStroke(
    List<Offset> points,
    List<double> radii,
    Color color,
    BrushShape shape,
    Rect bounds,
    bool erase,
    int antialiasLevel,
  ) async {
    // Create a picture recorder and canvas to draw the stroke
    // We need to crop to the bounds to avoid huge allocations
    final int width = bounds.width.ceil().clamp(1, _width);
    final int height = bounds.height.ceil().clamp(1, _height);
    final int left = bounds.left.floor().clamp(0, _width);
    final int top = bounds.top.floor().clamp(0, _height);

    // Re-clamp width/height based on clamped left/top
    final int safeWidth = math.min(width, _width - left);
    final int safeHeight = math.min(height, _height - top);

    if (safeWidth <= 0 || safeHeight <= 0) return;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(
      recorder,
      Rect.fromLTWH(0, 0, safeWidth.toDouble(), safeHeight.toDouble()),
    );

    // Translate canvas so drawing at (left, top) appears at (0, 0)
    canvas.translate(-left.toDouble(), -top.toDouble());

    VectorStrokePainter.paint(
      canvas: canvas,
      points: points,
      radii: radii,
      color: color,
      shape: shape,
      antialiasLevel: antialiasLevel,
    );

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(safeWidth, safeHeight);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );

    if (byteData == null) {
      image.dispose();
      picture.dispose();
      return;
    }

    final Uint8List pixels = byteData.buffer.asUint8List();
    final TransferableTypedData transferablePixels =
        TransferableTypedData.fromList([pixels]);

    image.dispose();
    picture.dispose();

    if (_isMultithreaded) {
      await _ensureWorkerSurfaceSynced();
      await _ensureWorkerSelectionMaskSynced();
      // Send pixel patch to worker
      final PaintingWorkerPatch? patch = await _ensurePaintingWorker()
          .mergePatch(
            PaintingMergePatchRequest(
              left: left,
              top: top,
              width: safeWidth,
              height: safeHeight,
              pixels: transferablePixels,
              erase: erase,
            ),
          );

      if (patch != null) {
        _applyWorkerPatch(patch);
        await _waitForNextFrame();
      }
    } else {
      // Fallback for main thread merge?
      // Currently merge logic is in worker. We could duplicate it here or just rely on worker.
      // Since we are fixing "Old logic is gone" and want vector quality, we should ideally support this.
      // But implementing blend logic on main thread is CPU intensive.
      // For now, if single threaded, we might fail silently or need to implement merge locally.
      // Given constraints, let's assume worker is available if isMultithreaded is true.
      // If !isMultithreaded, we haven't implemented vector rasterization fallback yet.
    }
  }

  void _flushRealtimeStrokeCommands() {
    if (_vectorDrawingEnabled) {
      return;
    }
    _commitDeferredStrokeCommandsAsRaster(keepStrokeState: true);
  }

  void _commitDeferredStrokeCommandsAsRaster({bool keepStrokeState = false}) {
    if (_deferredStrokeCommands.isEmpty) {
      if (!keepStrokeState) {
        _currentStrokePoints.clear();
        _currentStrokeRadii.clear();
      }
      return;
    }
    final List<PaintingDrawCommand> commands = List<PaintingDrawCommand>.from(
      _deferredStrokeCommands,
    );
    _deferredStrokeCommands.clear();
    if (_useWorkerForRaster) {
      for (final PaintingDrawCommand command in commands) {
        final Rect? bounds = _dirtyRectForCommand(command);
        if (bounds == null || bounds.isEmpty) {
          continue;
        }
        _enqueuePaintingWorkerCommand(region: bounds, command: command);
      }
    } else {
      Rect? region;
      for (final PaintingDrawCommand command in commands) {
        final Rect? bounds = _dirtyRectForCommand(command);
        if (bounds == null || bounds.isEmpty) {
          continue;
        }
        region = region == null
            ? bounds
            : Rect.fromLTRB(
                math.min(region.left, bounds.left),
                math.min(region.top, bounds.top),
                math.max(region.right, bounds.right),
                math.max(region.bottom, bounds.bottom),
              );
      }
      if (region != null) {
        _applyPaintingCommandsSynchronously(region, commands);
      }
    }
    if (!keepStrokeState) {
      _currentStrokePoints.clear();
      _currentStrokeRadii.clear();
    }
  }

  void _dispatchDirectPaintCommand(PaintingDrawCommand command) {
    final Rect? bounds = _dirtyRectForCommand(command);
    if (bounds == null || bounds.isEmpty) {
      return;
    }
    if (_useWorkerForRaster) {
      _enqueuePaintingWorkerCommand(region: bounds, command: command);
      return;
    }
    _applyPaintingCommandsSynchronously(bounds, <PaintingDrawCommand>[command]);
  }

  bool get _useWorkerForRaster =>
      _isMultithreaded && !_synchronousRasterOverride;

  Rect? _dirtyRectForCommand(PaintingDrawCommand command) {
    switch (command.type) {
      case PaintingDrawCommandType.brushStamp:
        final Offset? center = command.center;
        final double? radius = command.radius;
        if (center == null || radius == null) {
          return null;
        }
        return _strokeDirtyRectForCircle(center, radius);
      case PaintingDrawCommandType.line:
        final Offset? start = command.start;
        final Offset? end = command.end;
        final double? radius = command.radius;
        if (start == null || end == null || radius == null) {
          return null;
        }
        return _strokeDirtyRectForLine(start, end, radius);
      case PaintingDrawCommandType.variableLine:
        final Offset? start = command.start;
        final Offset? end = command.end;
        final double? startRadius = command.startRadius;
        final double? endRadius = command.endRadius;
        if (start == null ||
            end == null ||
            startRadius == null ||
            endRadius == null) {
          return null;
        }
        return _strokeDirtyRectForVariableLine(
          start,
          end,
          startRadius,
          endRadius,
        );
      case PaintingDrawCommandType.stampSegment:
        final Offset? start = command.start;
        final Offset? end = command.end;
        final double? startRadius = command.startRadius;
        final double? endRadius = command.endRadius;
        if (start == null ||
            end == null ||
            startRadius == null ||
            endRadius == null) {
          return null;
        }
        return _strokeDirtyRectForVariableLine(
          start,
          end,
          startRadius,
          endRadius,
        );
      case PaintingDrawCommandType.vectorStroke:
        return null;
      case PaintingDrawCommandType.filledPolygon:
        final List<Offset>? polygon = command.points;
        if (polygon == null || polygon.length < 3) {
          return null;
        }
        double minX = polygon.first.dx;
        double maxX = polygon.first.dx;
        double minY = polygon.first.dy;
        double maxY = polygon.first.dy;
        for (final Offset point in polygon) {
          if (point.dx < minX) {
            minX = point.dx;
          }
          if (point.dx > maxX) {
            maxX = point.dx;
          }
          if (point.dy < minY) {
            minY = point.dy;
          }
          if (point.dy > maxY) {
            maxY = point.dy;
          }
        }
        final double padding = 2.0 + command.antialiasLevel.clamp(0, 3) * 1.2;
        return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(padding);
    }
  }

  BitmapCanvasFrame? get frame => _currentFrame;
  Color get backgroundColor => _backgroundColor;
  int get width => _width;
  int get height => _height;
  Uint8List? get selectionMask => _selectionMask;
  bool get isActiveLayerTransforming => _activeLayerTranslationSnapshot != null;
  ui.Image? get activeLayerTransformImage => _activeLayerTransformImage;
  Offset get activeLayerTransformOffset => Offset(
    (_activeLayerTransformOriginX + _activeLayerTranslationDx).toDouble(),
    (_activeLayerTransformOriginY + _activeLayerTranslationDy).toDouble(),
  );
  Offset get activeLayerTransformOrigin => Offset(
    _activeLayerTransformOriginX.toDouble(),
    _activeLayerTransformOriginY.toDouble(),
  );
  Rect? get activeLayerTransformBounds => _activeLayerTransformBounds;
  double get activeLayerTransformOpacity => _activeLayer.opacity;
  CanvasLayerBlendMode get activeLayerTransformBlendMode =>
      _activeLayer.blendMode;
  bool get isActiveLayerTransformPendingCleanup =>
      _pendingActiveLayerTransformCleanup;

  bool get clipLayerOverflow => _clipLayerOverflow;

  void setLayerOverflowCropping(bool enabled) {
    if (_clipLayerOverflow == enabled) {
      return;
    }
    _clipLayerOverflow = enabled;
  }

  bool get hasVisibleContent {
    for (int i = 0; i < _layers.length; i++) {
      final BitmapLayerState layer = _layers[i];
      if (i == 0) {
        continue;
      }
      if (layer.visible && !_isSurfaceEmpty(layer.surface)) {
        return true;
      }
    }
    return false;
  }

  bool get vectorDrawingEnabled => _vectorDrawingEnabled;

  void runSynchronousRasterization(VoidCallback action) {
    final bool previous = _synchronousRasterOverride;
    _synchronousRasterOverride = true;
    try {
      action();
    } finally {
      _synchronousRasterOverride = previous;
    }
  }

  void setVectorDrawingEnabled(bool enabled) {
    if (_vectorDrawingEnabled == enabled) {
      return;
    }
    _vectorDrawingEnabled = enabled;
    if (!_vectorDrawingEnabled && _deferredStrokeCommands.isNotEmpty) {
      _commitDeferredStrokeCommandsAsRaster(keepStrokeState: true);
    }
  }

  void configureStylusPressure({
    required bool enabled,
    required double curve,
  }) => _strokeConfigureStylusPressure(this, enabled: enabled, curve: curve);

  void configureSharpTips({required bool enabled}) =>
      _strokeConfigureSharpTips(this, enabled: enabled);

  void setSelectionMask(Uint8List? mask) => _fillSetSelectionMask(this, mask);

  bool _runAntialiasPass(
    Uint32List src,
    Uint32List dest,
    int width,
    int height,
    double blendFactor,
  ) {
    dest.setAll(0, src);
    if (blendFactor <= 0) {
      return false;
    }
    final double factor = blendFactor.clamp(0.0, 1.0);
    bool modified = false;
    for (int y = 0; y < height; y++) {
      final int rowOffset = y * width;
      for (int x = 0; x < width; x++) {
        final int index = rowOffset + x;
        final int center = src[index];
        final int alpha = (center >> 24) & 0xff;
        final int centerR = (center >> 16) & 0xff;
        final int centerG = (center >> 8) & 0xff;
        final int centerB = center & 0xff;

        int totalWeight = _kAntialiasCenterWeight;
        int weightedAlpha = alpha * _kAntialiasCenterWeight;
        int weightedPremulR = centerR * alpha * _kAntialiasCenterWeight;
        int weightedPremulG = centerG * alpha * _kAntialiasCenterWeight;
        int weightedPremulB = centerB * alpha * _kAntialiasCenterWeight;

        for (int i = 0; i < _kAntialiasDx.length; i++) {
          final int nx = x + _kAntialiasDx[i];
          final int ny = y + _kAntialiasDy[i];
          if (nx < 0 || nx >= width || ny < 0 || ny >= height) {
            continue;
          }
          final int neighbor = src[ny * width + nx];
          final int neighborAlpha = (neighbor >> 24) & 0xff;
          final int weight = _kAntialiasWeights[i];
          totalWeight += weight;
          if (neighborAlpha == 0) {
            continue;
          }
          weightedAlpha += neighborAlpha * weight;
          weightedPremulR += ((neighbor >> 16) & 0xff) * neighborAlpha * weight;
          weightedPremulG += ((neighbor >> 8) & 0xff) * neighborAlpha * weight;
          weightedPremulB += (neighbor & 0xff) * neighborAlpha * weight;
        }

        if (totalWeight <= 0) {
          continue;
        }

        final int candidateAlpha = (weightedAlpha ~/ totalWeight).clamp(0, 255);
        final int deltaAlpha = candidateAlpha - alpha;
        if (deltaAlpha == 0) {
          continue;
        }

        final int newAlpha = (alpha + (deltaAlpha * factor).round()).clamp(
          0,
          255,
        );
        if (newAlpha == alpha) {
          continue;
        }

        int newR = centerR;
        int newG = centerG;
        int newB = centerB;
        if (deltaAlpha > 0) {
          final int boundedWeightedAlpha = math.max(weightedAlpha, 1);
          newR = (weightedPremulR ~/ boundedWeightedAlpha).clamp(0, 255);
          newG = (weightedPremulG ~/ boundedWeightedAlpha).clamp(0, 255);
          newB = (weightedPremulB ~/ boundedWeightedAlpha).clamp(0, 255);
        }

        dest[index] = (newAlpha << 24) | (newR << 16) | (newG << 8) | newB;
        modified = true;
      }
    }
    return modified;
  }

  bool _runEdgeAwareColorSmoothPass(
    Uint32List src,
    Uint32List dest,
    Uint32List blurBuffer,
    int width,
    int height,
  ) {
    _computeGaussianBlur(src, blurBuffer, width, height);
    bool modified = false;
    for (int y = 0; y < height; y++) {
      final int rowOffset = y * width;
      for (int x = 0; x < width; x++) {
        final int index = rowOffset + x;
        final int baseColor = src[index];
        final int alpha = (baseColor >> 24) & 0xff;
        if (alpha == 0) {
          dest[index] = baseColor;
          continue;
        }

        final double gradient = _computeEdgeGradient(src, width, height, x, y);
        final double weight = _edgeSmoothWeight(gradient);
        if (weight <= 0) {
          dest[index] = baseColor;
          continue;
        }
        final int blurred = blurBuffer[index];
        final int newColor = _lerpArgb(baseColor, blurred, weight);
        dest[index] = newColor;
        if (newColor != baseColor) {
          modified = true;
        }
      }
    }
    return modified;
  }

  double _computeEdgeGradient(
    Uint32List src,
    int width,
    int height,
    int x,
    int y,
  ) {
    final int index = y * width + x;
    final int center = src[index];
    final int alpha = (center >> 24) & 0xff;
    if (alpha == 0) {
      return 0;
    }
    final double centerLuma = _computeLuma(center);
    double maxDiff = 0;

    void accumulate(int nx, int ny) {
      if (nx < 0 || nx >= width || ny < 0 || ny >= height) {
        return;
      }
      final int neighbor = src[ny * width + nx];
      final int neighborAlpha = (neighbor >> 24) & 0xff;
      if (neighborAlpha == 0) {
        return;
      }
      final double diff = (centerLuma - _computeLuma(neighbor)).abs();
      if (diff > maxDiff) {
        maxDiff = diff;
      }
    }

    accumulate(x - 1, y);
    accumulate(x + 1, y);
    accumulate(x, y - 1);
    accumulate(x, y + 1);
    accumulate(x - 1, y - 1);
    accumulate(x + 1, y - 1);
    accumulate(x - 1, y + 1);
    accumulate(x + 1, y + 1);
    return maxDiff;
  }

  double _edgeSmoothWeight(double gradient) {
    if (gradient <= _kEdgeDetectMin) {
      return 0;
    }
    final double normalized =
        ((gradient - _kEdgeDetectMin) / (_kEdgeDetectMax - _kEdgeDetectMin))
            .clamp(0.0, 1.0);
    return math.pow(normalized, _kEdgeSmoothGamma) * _kEdgeSmoothStrength;
  }

  void _computeGaussianBlur(
    Uint32List src,
    Uint32List dest,
    int width,
    int height,
  ) {
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        double weightedAlpha = 0;
        double weightedR = 0;
        double weightedG = 0;
        double weightedB = 0;
        double totalWeight = 0;
        int kernelIndex = 0;
        for (int ky = -2; ky <= 2; ky++) {
          final int ny = (y + ky).clamp(0, height - 1);
          final int rowOffset = ny * width;
          for (int kx = -2; kx <= 2; kx++) {
            final int nx = (x + kx).clamp(0, width - 1);
            final int weight = _kGaussianKernel5x5[kernelIndex++];
            final int sample = src[rowOffset + nx];
            final int alpha = (sample >> 24) & 0xff;
            if (alpha == 0) {
              continue;
            }
            totalWeight += weight;
            weightedAlpha += alpha * weight;
            weightedR += ((sample >> 16) & 0xff) * alpha * weight;
            weightedG += ((sample >> 8) & 0xff) * alpha * weight;
            weightedB += (sample & 0xff) * alpha * weight;
          }
        }
        if (totalWeight == 0) {
          dest[y * width + x] = src[y * width + x];
          continue;
        }
        final double normalizedAlpha = weightedAlpha / totalWeight;
        final double premulAlpha = math.max(weightedAlpha, 1.0);
        final int outAlpha = normalizedAlpha.round().clamp(0, 255);
        final int outR = (weightedR / premulAlpha).round().clamp(0, 255);
        final int outG = (weightedG / premulAlpha).round().clamp(0, 255);
        final int outB = (weightedB / premulAlpha).round().clamp(0, 255);
        dest[y * width + x] =
            (outAlpha << 24) | (outR << 16) | (outG << 8) | outB;
      }
    }
  }

  static double _computeLuma(int color) {
    final int alpha = (color >> 24) & 0xff;
    if (alpha == 0) {
      return 0;
    }
    final int r = (color >> 16) & 0xff;
    final int g = (color >> 8) & 0xff;
    final int b = color & 0xff;
    // ITU-R BT.709 perceptual weights normalized to 0-1 luma.
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
  }

  static int _lerpArgb(int a, int b, double t) {
    final double clampedT = t.clamp(0.0, 1.0);
    int _lerpChannel(int ca, int cb) =>
        (ca + ((cb - ca) * clampedT).round()).clamp(0, 255);

    final int aA = (a >> 24) & 0xff;
    final int aR = (a >> 16) & 0xff;
    final int aG = (a >> 8) & 0xff;
    final int aB = a & 0xff;

    final int bA = (b >> 24) & 0xff;
    final int bR = (b >> 16) & 0xff;
    final int bG = (b >> 8) & 0xff;
    final int bB = b & 0xff;

    final int outA = _lerpChannel(aA, bA);
    final int outR = _lerpChannel(aR, bR);
    final int outG = _lerpChannel(aG, bG);
    final int outB = _lerpChannel(aB, bB);
    return (outA << 24) | (outR << 16) | (outG << 8) | outB;
  }

  void translateActiveLayer(int dx, int dy) =>
      _translateActiveLayer(this, dx, dy);

  void commitActiveLayerTranslation() => _commitActiveLayerTranslation(this);

  void cancelActiveLayerTranslation() => _cancelActiveLayerTranslation(this);

  void disposeActiveLayerTransformSession() =>
      _disposeActiveLayerTransformSession(this);

  Future<ui.Image> snapshotImage() async {
    await _rasterBackend.composite(
      layers: _layers,
      requiresFullSurface: true,
      regions: null,
      translatingLayerId: _translatingLayerIdForComposite,
    );
    final Uint8List rgba = _rasterBackend.copySurfaceRgba();
    return _decodeRgbaImage(rgba, _width, _height);
  }

  Future<void> disposeController() async {
    _tileCache.dispose();
    await _rasterBackend.dispose();
    await _paintingWorker?.dispose();
    _paintingWorker = null;
    _disposePendingTileImages();
    _disposeActiveLayerTransformImage(this);
    _activeLayerTransformPreparing = false;
  }

  void setActiveLayer(String id) => _layerManagerSetActiveLayer(this, id);

  void updateLayerVisibility(String id, bool visible) =>
      _layerManagerUpdateVisibility(this, id, visible);

  void setLayerOpacity(String id, double opacity) =>
      _layerManagerSetOpacity(this, id, opacity);

  void setLayerLocked(String id, bool locked) =>
      _layerManagerSetLocked(this, id, locked);

  void setLayerClippingMask(String id, bool clippingMask) =>
      _layerManagerSetClippingMask(this, id, clippingMask);

  void setLayerBlendMode(String id, CanvasLayerBlendMode mode) =>
      _layerManagerSetBlendMode(this, id, mode);

  void renameLayer(String id, String name) =>
      _layerManagerRenameLayer(this, id, name);

  void addLayer({String? aboveLayerId, String? name}) =>
      _layerManagerAddLayer(this, aboveLayerId: aboveLayerId, name: name);

  void removeLayer(String id) => _layerManagerRemoveLayer(this, id);

  void reorderLayer(int fromIndex, int toIndex) =>
      _layerManagerReorderLayer(this, fromIndex, toIndex);

  bool mergeLayerDown(String id) => _layerManagerMergeLayerDown(this, id);

  void clear() => _layerManagerClearAll(this);

  void beginStroke(
    Offset position, {
    required Color color,
    required double radius,
    bool simulatePressure = false,
    bool useDevicePressure = false,
    double stylusPressureBlend = 1.0,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
    StrokePressureProfile profile = StrokePressureProfile.auto,
    double? timestampMillis,
    int antialiasLevel = 0,
    BrushShape brushShape = BrushShape.circle,
    bool enableNeedleTips = false,
    bool erase = false,
  }) => _strokeBegin(
    this,
    position,
    color: color,
    radius: radius,
    simulatePressure: simulatePressure,
    useDevicePressure: useDevicePressure,
    stylusPressureBlend: stylusPressureBlend,
    pressure: pressure,
    pressureMin: pressureMin,
    pressureMax: pressureMax,
    profile: profile,
    timestampMillis: timestampMillis,
    antialiasLevel: antialiasLevel,
    brushShape: brushShape,
    enableNeedleTips: enableNeedleTips,
    erase: erase,
  );

  void extendStroke(
    Offset position, {
    double? deltaTimeMillis,
    double? timestampMillis,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
  }) => _strokeExtend(
    this,
    position,
    deltaTimeMillis: deltaTimeMillis,
    timestampMillis: timestampMillis,
    pressure: pressure,
    pressureMin: pressureMin,
    pressureMax: pressureMax,
  );

  void endStroke() => _strokeEnd(this);

  void drawFilledPolygon({
    required List<Offset> points,
    required Color color,
    int antialiasLevel = 0,
    bool erase = false,
  }) {
    if (_layers.isEmpty || _activeLayer.locked) {
      return;
    }
    if (points.length < 3) {
      return;
    }
    final PaintingDrawCommand command = PaintingDrawCommand.filledPolygon(
      points: List<Offset>.from(points),
      colorValue: color.value,
      antialiasLevel: antialiasLevel.clamp(0, 3),
      erase: erase,
    );
    _dispatchDirectPaintCommand(command);
  }

  bool applyAntialiasToActiveLayer(int level, {bool previewOnly = false}) {
    if (_layers.isEmpty) {
      return false;
    }
    final BitmapLayerState layer = _activeLayer;
    if (layer.locked) {
      return false;
    }
    final List<double> profile = List<double>.from(
      _kAntialiasBlendProfiles[level.clamp(0, 3)] ?? const <double>[0.25],
    );
    if (profile.isEmpty) {
      return false;
    }
    final Uint32List pixels = layer.surface.pixels;
    if (pixels.isEmpty) {
      return false;
    }
    final Uint32List temp = Uint32List(pixels.length);
    Uint32List src = pixels;
    Uint32List dest = temp;
    bool anyChange = false;
    for (final double factor in profile) {
      if (factor <= 0) {
        continue;
      }
      final bool alphaChanged = _runAntialiasPass(
        src,
        dest,
        _width,
        _height,
        factor,
      );
      if (!alphaChanged) {
        continue;
      }
      if (previewOnly) {
        return true;
      }
      anyChange = true;
      final Uint32List swap = src;
      src = dest;
      dest = swap;
    }

    final Uint32List blurBuffer = Uint32List(pixels.length);
    final bool colorChanged = _runEdgeAwareColorSmoothPass(
      src,
      dest,
      blurBuffer,
      _width,
      _height,
    );
    if (colorChanged) {
      if (previewOnly) {
        return true;
      }
      anyChange = true;
      final Uint32List swap = src;
      src = dest;
      dest = swap;
    }
    if (!anyChange) {
      return false;
    }
    if (previewOnly) {
      return true;
    }
    if (!identical(src, pixels)) {
      pixels.setAll(0, src);
    }
    layer.surface.markDirty();
    _markDirty(layerId: layer.id, pixelsDirty: true);
    notifyListeners();
    return true;
  }

  void setStrokePressureProfile(StrokePressureProfile profile) =>
      _strokeSetPressureProfile(this, profile);

  double? _normalizeStylusPressure(
    double? pressure,
    double? pressureMin,
    double? pressureMax,
  ) => _strokeNormalizeStylusPressure(this, pressure, pressureMin, pressureMax);

  bool _selectionAllows(Offset position) =>
      _fillSelectionAllows(this, position);

  bool _selectionAllowsInt(int x, int y) => _fillSelectionAllowsInt(this, x, y);

  void floodFill(
    Offset position, {
    required Color color,
    bool contiguous = true,
    bool sampleAllLayers = false,
    List<Color>? swallowColors,
    int tolerance = 0,
    int antialiasLevel = 0,
  }) => _fillFloodFill(
    this,
    position,
    color: color,
    contiguous: contiguous,
    sampleAllLayers: sampleAllLayers,
    swallowColors: swallowColors,
    tolerance: tolerance,
    antialiasLevel: antialiasLevel,
  );

  Future<Uint8List?> computeMagicWandMask(
    Offset position, {
    bool sampleAllLayers = true,
    int tolerance = 0,
  }) => _fillComputeMagicWandMask(
    this,
    position,
    sampleAllLayers: sampleAllLayers,
    tolerance: tolerance,
  );

  List<CanvasLayerData> snapshotLayers() => _layerManagerSnapshotLayers(this);
  Future<void> waitForPendingWorkerTasks() => _waitForPendingWorkerTasks();

  CanvasLayerData? buildClipboardLayer(String id, {Uint8List? mask}) =>
      _layerManagerBuildClipboardLayer(this, id, mask: mask);

  void clearLayerRegion(String id, {Uint8List? mask}) =>
      _layerManagerClearRegion(this, id, mask: mask);

  String insertLayerFromData(CanvasLayerData data, {String? aboveLayerId}) =>
      _layerManagerInsertFromData(this, data, aboveLayerId: aboveLayerId);

  void replaceLayer(String id, CanvasLayerData data) =>
      _layerManagerReplaceLayer(this, id, data);

  Rect? restoreLayerRegion(
    CanvasLayerData snapshot,
    Rect region, {
    Uint32List? pixelCache,
    bool markDirty = true,
  }) {
    final int index = _layers.indexWhere((layer) => layer.id == snapshot.id);
    if (index < 0 || region.isEmpty) {
      return null;
    }
    final Rect canvasRect = Rect.fromLTWH(
      0,
      0,
      _width.toDouble(),
      _height.toDouble(),
    );
    Rect target = region.intersect(canvasRect);
    if (target.isEmpty) {
      return null;
    }
    final BitmapLayerState layer = _layers[index];
    final BitmapSurface surface = layer.surface;

    if (snapshot.bitmap == null ||
        snapshot.bitmapWidth == null ||
        snapshot.bitmapHeight == null) {
      final Color fill = snapshot.fillColor ?? const Color(0x00000000);
      _fillSurfaceRegion(surface, target, fill);
      surface.markDirty();
      if (markDirty) {
        _markDirty(region: target, layerId: layer.id, pixelsDirty: true);
      }
      return target;
    }

    final int srcWidth = snapshot.bitmapWidth!;
    final int srcHeight = snapshot.bitmapHeight!;
    final int offsetX = snapshot.bitmapLeft ?? 0;
    final int offsetY = snapshot.bitmapTop ?? 0;
    final Rect snapshotRect = Rect.fromLTWH(
      offsetX.toDouble(),
      offsetY.toDouble(),
      srcWidth.toDouble(),
      srcHeight.toDouble(),
    );
    target = target.intersect(snapshotRect);
    if (target.isEmpty) {
      return null;
    }

    final Uint32List srcPixels =
        pixelCache ?? rgbaToPixels(snapshot.bitmap!, srcWidth, srcHeight);

    final int startX = math.max(0, math.max(target.left.floor(), offsetX));
    final int startY = math.max(0, math.max(target.top.floor(), offsetY));
    final int endX = math.min(
      _width,
      math.min(target.right.ceil(), offsetX + srcWidth),
    );
    final int endY = math.min(
      _height,
      math.min(target.bottom.ceil(), offsetY + srcHeight),
    );
    if (startX >= endX || startY >= endY) {
      return null;
    }

    final Uint32List destPixels = surface.pixels;
    final int copyWidth = endX - startX;
    final int copyHeight = endY - startY;
    Uint32List? workerPatch = _isMultithreaded
        ? Uint32List(copyWidth * copyHeight)
        : null;
    int workerOffset = 0;
    for (int y = startY; y < endY; y++) {
      final int srcY = y - offsetY;
      if (srcY < 0 || srcY >= srcHeight) {
        continue;
      }
      final int destOffset = y * _width + startX;
      final int srcOffset = srcY * srcWidth + (startX - offsetX);
      destPixels.setRange(
        destOffset,
        destOffset + copyWidth,
        srcPixels,
        srcOffset,
      );
      if (workerPatch != null) {
        workerPatch.setRange(
          workerOffset,
          workerOffset + copyWidth,
          srcPixels,
          srcOffset,
        );
        workerOffset += copyWidth;
      }
    }
    surface.markDirty();
    final Rect dirtyRegion = Rect.fromLTRB(
      startX.toDouble(),
      startY.toDouble(),
      endX.toDouble(),
      endY.toDouble(),
    );
    if (markDirty) {
      _markDirty(region: dirtyRegion, layerId: layer.id, pixelsDirty: true);
    }
    if (workerPatch != null) {
      unawaited(
        _ensurePaintingWorker().syncSurfacePatch(
          left: startX,
          top: startY,
          width: copyWidth,
          height: copyHeight,
          pixels: workerPatch,
        ),
      );
    }
    return dirtyRegion;
  }

  void _fillSurfaceRegion(BitmapSurface surface, Rect region, Color color) {
    final int startX = math.max(0, region.left.floor());
    final int startY = math.max(0, region.top.floor());
    final int endX = math.min(_width, region.right.ceil());
    final int endY = math.min(_height, region.bottom.ceil());
    if (startX >= endX || startY >= endY) {
      return;
    }
    final int encoded = BitmapSurface.encodeColor(color);
    final Uint32List pixels = surface.pixels;
    for (int y = startY; y < endY; y++) {
      final int offset = y * _width + startX;
      pixels.fillRange(offset, offset + (endX - startX), encoded);
    }
  }

  void loadLayers(List<CanvasLayerData> layers, Color backgroundColor) =>
      _layerManagerLoadLayers(this, layers, backgroundColor);

  void markLayerRegionDirty(String id, Rect region) {
    if (region.isEmpty) {
      return;
    }
    _markDirty(region: region, layerId: id, pixelsDirty: true);
  }

  void _updateComposite({required bool requiresFullSurface, Rect? region}) {
    _compositeUpdate(
      this,
      requiresFullSurface: requiresFullSurface,
      regions: requiresFullSurface || region == null
          ? null
          : <RasterIntRect>[_rasterBackend.clipRectToSurface(region)],
    );
  }

  void _markDirty({Rect? region, String? layerId, bool pixelsDirty = true}) =>
      _compositeMarkDirty(
        this,
        region: region,
        layerId: layerId,
        pixelsDirty: pixelsDirty,
      );

  void _scheduleCompositeRefresh() => _compositeScheduleRefresh(this);

  Future<void> _waitForNextFrame() {
    if (_nextFrameCompleter == null || _nextFrameCompleter!.isCompleted) {
      _nextFrameCompleter = Completer<void>();
    }
    return _nextFrameCompleter!.future;
  }

  void _enqueuePaintingWorkerCommand({
    required Rect region,
    required PaintingDrawCommand command,
  }) {
    if (region.isEmpty) {
      return;
    }
    final _PendingWorkerDrawBatch batch = _pendingWorkerDrawBatch ??=
        _PendingWorkerDrawBatch(region);
    batch.add(region, command);
    final bool exceededCommandLimit =
        batch.commands.length >= _kMaxWorkerBatchCommands;
    final double batchArea = batch.region.width * batch.region.height;
    final bool exceededAreaLimit =
        !batchArea.isFinite || batchArea >= _kMaxWorkerBatchPixels;
    if (exceededCommandLimit || exceededAreaLimit) {
      _scheduleWorkerDrawFlush(forceImmediate: true);
    } else {
      _scheduleWorkerDrawFlush();
    }
  }

  void _scheduleWorkerDrawFlush({bool forceImmediate = false}) {
    if (forceImmediate) {
      _pendingWorkerDrawScheduled = false;
      _processPendingWorkerDrawCommands();
      return;
    }
    if (_pendingWorkerDrawScheduled) {
      return;
    }
    _pendingWorkerDrawScheduled = true;
    scheduleMicrotask(_processPendingWorkerDrawCommands);
  }

  void _processPendingWorkerDrawCommands() {
    _pendingWorkerDrawScheduled = false;
    final _PendingWorkerDrawBatch? batch = _pendingWorkerDrawBatch;
    if (batch == null || batch.commands.isEmpty) {
      _pendingWorkerDrawBatch = null;
      return;
    }
    _pendingWorkerDrawBatch = null;
    final Rect region = batch.region;
    final List<PaintingDrawCommand> commands = List<PaintingDrawCommand>.from(
      batch.commands,
    );
    _enqueueWorkerPatchFuture(
      _executeWorkerDraw(region: region, commands: commands),
      onError: () => _applyPaintingCommandsSynchronously(region, commands),
    );
  }

  void _flushPendingPaintingCommands() {
    if (_pendingWorkerDrawBatch == null ||
        _pendingWorkerDrawBatch!.commands.isEmpty) {
      _pendingWorkerDrawBatch = null;
      _pendingWorkerDrawScheduled = false;
      return;
    }
    _processPendingWorkerDrawCommands();
  }

  Future<void> _waitForPendingWorkerTasks() {
    if (!_isMultithreaded) {
      return Future<void>.value();
    }
    _flushPendingPaintingCommands();
    if (_paintingWorkerPendingTasks == 0) {
      return Future<void>.value();
    }
    final Completer<void> completer = Completer<void>();
    _paintingWorkerIdleWaiters.add(completer);
    return completer.future;
  }

  void _notifyWorkerIdle() {
    if (_paintingWorkerPendingTasks > 0) {
      return;
    }
    if (_pendingWorkerDrawBatch != null &&
        _pendingWorkerDrawBatch!.commands.isNotEmpty) {
      return;
    }
    if (_pendingWorkerDrawScheduled) {
      return;
    }
    if (_paintingWorkerIdleWaiters.isEmpty) {
      return;
    }
    for (final Completer<void> completer in _paintingWorkerIdleWaiters) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _paintingWorkerIdleWaiters.clear();
  }

  void _cancelPendingWorkerTasks() {
    if (!_isMultithreaded) {
      return;
    }
    _pendingWorkerDrawBatch = null;
    _pendingWorkerDrawScheduled = false;
    _pendingWorkerPatches.clear();
    _paintingWorkerNextApplySequence = _paintingWorkerNextSequence;
    _paintingWorkerPendingTasks = 0;
    _paintingWorkerGeneration++;
    _notifyWorkerIdle();
  }

  CanvasPaintingWorker _ensurePaintingWorker() {
    return _paintingWorker ??= CanvasPaintingWorker();
  }

  Future<void> _ensureWorkerSurfaceSynced() async {
    if (!_isMultithreaded) {
      return;
    }
    final CanvasPaintingWorker worker = _ensurePaintingWorker();
    final BitmapLayerState layer = _activeLayer;
    if (_paintingWorkerSyncedLayerId == layer.id &&
        _paintingWorkerSyncedRevision == layer.revision) {
      return;
    }
    final Uint32List snapshot = Uint32List.fromList(layer.surface.pixels);
    await worker.setSurface(width: _width, height: _height, pixels: snapshot);
    _paintingWorkerSyncedLayerId = layer.id;
    _paintingWorkerSyncedRevision = layer.revision;
  }

  Future<void> _ensureWorkerSelectionMaskSynced() async {
    if (!_isMultithreaded || !_paintingWorkerSelectionDirty) {
      return;
    }
    final CanvasPaintingWorker worker = _ensurePaintingWorker();
    await worker.updateSelectionMask(_selectionMask);
    _paintingWorkerSelectionDirty = false;
  }

  void _resetWorkerSurfaceSync() {
    _paintingWorkerSyncedLayerId = null;
    _paintingWorkerSyncedRevision = -1;
    _paintingWorkerSelectionDirty = true;
  }

  void _enqueueWorkerPatchFuture(
    Future<PaintingWorkerPatch?> future, {
    VoidCallback? onError,
  }) {
    final int sequence = _paintingWorkerNextSequence++;
    final int generation = _paintingWorkerGeneration;
    _paintingWorkerPendingTasks++;
    future
        .then((PaintingWorkerPatch? patch) {
          if (generation != _paintingWorkerGeneration ||
              sequence < _paintingWorkerNextApplySequence) {
            return;
          }
          if (patch == null) {
            onError?.call();
          }
          _pendingWorkerPatches[sequence] = patch;
          _processPendingWorkerPatches();
        })
        .catchError((Object error, StackTrace stackTrace) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'CanvasPaintingWorker',
              context: ErrorDescription('while running painting task'),
            ),
          );
          if (generation != _paintingWorkerGeneration ||
              sequence < _paintingWorkerNextApplySequence) {
            return;
          }
          onError?.call();
          _pendingWorkerPatches[sequence] = null;
          _processPendingWorkerPatches();
        })
        .whenComplete(() {
          if (generation == _paintingWorkerGeneration &&
              _paintingWorkerPendingTasks > 0) {
            _paintingWorkerPendingTasks--;
          }
          _notifyWorkerIdle();
        });
  }

  void _processPendingWorkerPatches() {
    while (_pendingWorkerPatches.containsKey(
      _paintingWorkerNextApplySequence,
    )) {
      final PaintingWorkerPatch? patch = _pendingWorkerPatches.remove(
        _paintingWorkerNextApplySequence,
      );
      if (patch != null) {
        _applyWorkerPatch(patch);
      }
      _paintingWorkerNextApplySequence++;
    }
  }

  void _applyWorkerPatch(PaintingWorkerPatch patch) {
    if (patch.width <= 0 || patch.height <= 0 || patch.pixels.isEmpty) {
      return;
    }
    final int effectiveLeft = math.max(0, math.min(patch.left, _width));
    final int effectiveTop = math.max(0, math.min(patch.top, _height));
    final int maxRight = math.min(effectiveLeft + patch.width, _width);
    final int maxBottom = math.min(effectiveTop + patch.height, _height);
    if (maxRight <= effectiveLeft || maxBottom <= effectiveTop) {
      return;
    }
    final Uint32List destination = _activeSurface.pixels;
    final int copyWidth = maxRight - effectiveLeft;
    final int copyHeight = maxBottom - effectiveTop;
    final int srcLeftOffset = effectiveLeft - patch.left;
    final int srcTopOffset = effectiveTop - patch.top;
    for (int row = 0; row < copyHeight; row++) {
      final int srcRow = srcTopOffset + row;
      final int destY = effectiveTop + row;
      final int srcOffset = srcRow * patch.width + srcLeftOffset;
      final int destOffset = destY * _width + effectiveLeft;
      destination.setRange(
        destOffset,
        destOffset + copyWidth,
        patch.pixels,
        srcOffset,
      );
    }
    _activeLayer.revision += 1;
    _paintingWorkerSyncedLayerId = _activeLayer.id;
    _paintingWorkerSyncedRevision = _activeLayer.revision;
    final Rect dirtyRegion = Rect.fromLTWH(
      effectiveLeft.toDouble(),
      effectiveTop.toDouble(),
      copyWidth.toDouble(),
      copyHeight.toDouble(),
    );
    _markDirty(
      region: dirtyRegion,
      layerId: _activeLayer.id,
      pixelsDirty: true,
    );
  }

  void _scheduleTileImageDisposal() {
    if (_pendingTileDisposals.isEmpty || _tileDisposalScheduled) {
      return;
    }
    _tileDisposalScheduled = true;
    final SchedulerBinding? scheduler = SchedulerBinding.instance;
    if (scheduler == null) {
      scheduleMicrotask(_flushTileImageDisposals);
    } else {
      scheduler.addPostFrameCallback((_) => _flushTileImageDisposals());
    }
  }

  void _flushTileImageDisposals() {
    for (final ui.Image image in _pendingTileDisposals) {
      image.dispose();
    }
    _pendingTileDisposals.clear();
    _tileDisposalScheduled = false;
  }

  void _disposePendingTileImages() {
    for (final ui.Image image in _pendingTileDisposals) {
      image.dispose();
    }
    _pendingTileDisposals.clear();
    _tileDisposalScheduled = false;
  }

  BitmapLayerState get _activeLayer => _layers[_activeIndex];

  BitmapSurface get _activeSurface => _activeLayer.surface;

  static bool _isSurfaceEmpty(BitmapSurface surface) {
    for (final int pixel in surface.pixels) {
      if ((pixel >> 24) != 0) {
        return false;
      }
    }
    return true;
  }

  Color sampleColor(Offset position, {bool sampleAllLayers = true}) =>
      _fillSampleColor(this, position, sampleAllLayers: sampleAllLayers);

  static Uint8List _surfaceToRgba(BitmapSurface surface) {
    final Uint8List rgba = Uint8List(surface.pixels.length * 4);
    for (int i = 0; i < surface.pixels.length; i++) {
      final int argb = surface.pixels[i];
      final int offset = i * 4;
      rgba[offset] = (argb >> 16) & 0xff;
      rgba[offset + 1] = (argb >> 8) & 0xff;
      rgba[offset + 2] = argb & 0xff;
      rgba[offset + 3] = (argb >> 24) & 0xff;
    }
    return rgba;
  }

  static Uint32List rgbaToPixels(Uint8List rgba, int width, int height) {
    final int length = width * height;
    final Uint32List pixels = Uint32List(length);
    for (int i = 0; i < length; i++) {
      final int offset = i * 4;
      final int r = rgba[offset];
      final int g = rgba[offset + 1];
      final int b = rgba[offset + 2];
      final int a = rgba[offset + 3];
      pixels[i] = (a << 24) | (r << 16) | (g << 8) | b;
    }
    return pixels;
  }

  static Uint8List _pixelsToRgba(Uint32List pixels) {
    final Uint8List rgba = Uint8List(pixels.length * 4);
    for (int i = 0; i < pixels.length; i++) {
      final int argb = pixels[i];
      final int offset = i * 4;
      rgba[offset] = (argb >> 16) & 0xff;
      rgba[offset + 1] = (argb >> 8) & 0xff;
      rgba[offset + 2] = argb & 0xff;
      rgba[offset + 3] = (argb >> 24) & 0xff;
    }
    return rgba;
  }

  static Rect _unionRects(Rect a, Rect b) {
    return Rect.fromLTRB(
      math.min(a.left, b.left),
      math.min(a.top, b.top),
      math.max(a.right, b.right),
      math.max(a.bottom, b.bottom),
    );
  }

  static Uint8List _surfaceToMaskedRgba(BitmapSurface surface, Uint8List mask) {
    final Uint32List pixels = surface.pixels;
    final Uint8List rgba = Uint8List(pixels.length * 4);
    for (int i = 0; i < pixels.length; i++) {
      if (mask[i] == 0) {
        continue;
      }
      final int argb = pixels[i];
      final int offset = i * 4;
      rgba[offset] = (argb >> 16) & 0xff;
      rgba[offset + 1] = (argb >> 8) & 0xff;
      rgba[offset + 2] = argb & 0xff;
      rgba[offset + 3] = (argb >> 24) & 0xff;
    }
    return rgba;
  }

  static bool _maskHasCoverage(Uint8List mask) {
    for (final int value in mask) {
      if (value != 0) {
        return true;
      }
    }
    return false;
  }

  static double _clampUnit(double value) {
    if (value <= 0) {
      return 0;
    }
    if (value >= 1) {
      return 1;
    }
    return value;
  }

  Future<ui.Image> _decodeRgbaImage(Uint8List bytes, int width, int height) {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bytes,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  RasterIntRect _clipRectToSurface(Rect rect) =>
      _rasterBackend.clipRectToSurface(rect);

  Future<PaintingWorkerPatch?> _executeWorkerDraw({
    required Rect region,
    required List<PaintingDrawCommand> commands,
  }) async {
    if (commands.isEmpty) {
      return null;
    }
    final RasterIntRect bounds = _clipRectToSurface(region);
    if (bounds.isEmpty) {
      return null;
    }
    await _ensureWorkerSurfaceSynced();
    await _ensureWorkerSelectionMaskSynced();
    final PaintingWorkerPatch patch = await _ensurePaintingWorker().drawPatch(
      PaintingDrawRequest(
        left: bounds.left,
        top: bounds.top,
        width: bounds.width,
        height: bounds.height,
        commands: commands,
      ),
    );
    return patch;
  }

  void _applyPaintingCommandsSynchronously(
    Rect region,
    List<PaintingDrawCommand> commands,
  ) {
    if (commands.isEmpty) {
      return;
    }
    final BitmapSurface surface = _activeSurface;
    final Uint8List? mask = _selectionMask;
    bool anyChange = false;
    for (final PaintingDrawCommand command in commands) {
      final Color color = Color(command.color);
      final bool erase = command.erase;
      switch (command.type) {
        case PaintingDrawCommandType.brushStamp:
          final Offset? center = command.center;
          final double? radius = command.radius;
          final int? shapeIndex = command.shapeIndex;
          if (center == null || radius == null || shapeIndex == null) {
            continue;
          }
          final int clampedShape = shapeIndex.clamp(
            0,
            BrushShape.values.length - 1,
          );
          surface.drawBrushStamp(
            center: center,
            radius: radius,
            color: color,
            shape: BrushShape.values[clampedShape],
            mask: mask,
            antialiasLevel: command.antialiasLevel,
            erase: erase,
          );
          anyChange = true;
          break;
        case PaintingDrawCommandType.line:
          final Offset? start = command.start;
          final Offset? end = command.end;
          final double? radius = command.radius;
          if (start == null || end == null || radius == null) {
            continue;
          }
          surface.drawLine(
            a: start,
            b: end,
            radius: radius,
            color: color,
            mask: mask,
            antialiasLevel: command.antialiasLevel,
            includeStartCap: command.includeStartCap ?? true,
            erase: erase,
          );
          anyChange = true;
          break;
        case PaintingDrawCommandType.variableLine:
          final Offset? start = command.start;
          final Offset? end = command.end;
          final double? startRadius = command.startRadius;
          final double? endRadius = command.endRadius;
          if (start == null ||
              end == null ||
              startRadius == null ||
              endRadius == null) {
            continue;
          }
          surface.drawVariableLine(
            a: start,
            b: end,
            startRadius: startRadius,
            endRadius: endRadius,
            color: color,
            mask: mask,
            antialiasLevel: command.antialiasLevel,
            includeStartCap: command.includeStartCap ?? true,
            erase: erase,
          );
          anyChange = true;
          break;
        case PaintingDrawCommandType.stampSegment:
          final Offset? start = command.start;
          final Offset? end = command.end;
          final double? startRadius = command.startRadius;
          final double? endRadius = command.endRadius;
          final int? shapeIndex = command.shapeIndex;
          if (start == null ||
              end == null ||
              startRadius == null ||
              endRadius == null ||
              shapeIndex == null) {
            continue;
          }
          final int clampedShape = shapeIndex.clamp(
            0,
            BrushShape.values.length - 1,
          );
          _applyStampSegmentFallback(
            surface: surface,
            start: start,
            end: end,
            startRadius: startRadius,
            endRadius: endRadius,
            includeStart: command.includeStartCap ?? true,
            shape: BrushShape.values[clampedShape],
            color: color,
            mask: mask,
            antialias: command.antialiasLevel,
            erase: erase,
          );
          anyChange = true;
          break;
        case PaintingDrawCommandType.vectorStroke:
          // Synchronous fallback for vector stroke is not implemented on BitmapSurface.
          // This case should only be reached if the worker fails.
          break;
        case PaintingDrawCommandType.filledPolygon:
          final List<Offset>? points = command.points;
          if (points == null || points.length < 3) {
            continue;
          }
          surface.drawFilledPolygon(
            vertices: points,
            color: color,
            mask: mask,
            antialiasLevel: command.antialiasLevel,
            erase: erase,
          );
          anyChange = true;
          break;
      }
    }
    if (!anyChange) {
      return;
    }
    _resetWorkerSurfaceSync();
    _activeLayer.revision += 1;
    _markDirty(region: region, layerId: _activeLayer.id, pixelsDirty: true);
  }

  void _applyStampSegmentFallback({
    required BitmapSurface surface,
    required Offset start,
    required Offset end,
    required double startRadius,
    required double endRadius,
    required bool includeStart,
    required BrushShape shape,
    required Color color,
    required Uint8List? mask,
    required int antialias,
    required bool erase,
  }) {
    final double distance = (end - start).distance;
    if (!distance.isFinite || distance <= 0.0001) {
      surface.drawBrushStamp(
        center: end,
        radius: endRadius,
        color: color,
        shape: shape,
        mask: mask,
        antialiasLevel: antialias,
        erase: erase,
      );
      return;
    }
    final double maxRadius = math.max(
      math.max(startRadius.abs(), endRadius.abs()),
      0.01,
    );
    final double spacing = _strokeStampSpacing(maxRadius);
    final int samples = math.max(1, (distance / spacing).ceil());
    final int startIndex = includeStart ? 0 : 1;
    for (int i = startIndex; i <= samples; i++) {
      final double t = samples == 0 ? 1.0 : (i / samples);
      final double radius =
          ui.lerpDouble(startRadius, endRadius, t) ?? endRadius;
      final double sampleX = ui.lerpDouble(start.dx, end.dx, t) ?? end.dx;
      final double sampleY = ui.lerpDouble(start.dy, end.dy, t) ?? end.dy;
      surface.drawBrushStamp(
        center: Offset(sampleX, sampleY),
        radius: radius,
        color: color,
        shape: shape,
        mask: mask,
        antialiasLevel: antialias,
        erase: erase,
      );
    }
  }

  Future<PaintingWorkerPatch?> _executeFloodFill({
    required Offset start,
    required Color color,
    Color? targetColor,
    bool contiguous = true,
    int tolerance = 0,
  }) async {
    await _ensureWorkerSurfaceSynced();
    await _ensureWorkerSelectionMaskSynced();
    final PaintingWorkerPatch patch = await _ensurePaintingWorker().floodFill(
      PaintingFloodFillRequest(
        width: _width,
        height: _height,
        pixels: null,
        startX: start.dx.floor(),
        startY: start.dy.floor(),
        colorValue: color.value,
        targetColorValue: targetColor?.value,
        contiguous: contiguous,
        mask: null,
        tolerance: tolerance,
      ),
    );
    return patch;
  }

  Future<Uint8List?> _executeSelectionMask({
    required Offset start,
    required Uint32List pixels,
    int tolerance = 0,
  }) async {
    final TransferableTypedData pixelData = TransferableTypedData.fromList(
      <Uint8List>[Uint8List.view(pixels.buffer)],
    );
    final Uint8List mask = await _ensurePaintingWorker().computeSelectionMask(
      PaintingSelectionMaskRequest(
        width: _width,
        height: _height,
        pixels: pixelData,
        startX: start.dx.floor(),
        startY: start.dy.floor(),
        tolerance: tolerance,
      ),
    );
    return mask;
  }
}

class _PendingWorkerDrawBatch {
  _PendingWorkerDrawBatch(Rect region) : region = region;

  Rect region;
  final List<PaintingDrawCommand> commands = <PaintingDrawCommand>[];

  void add(Rect rect, PaintingDrawCommand command) {
    commands.add(command);
    region = Rect.fromLTRB(
      math.min(region.left, rect.left),
      math.min(region.top, rect.top),
      math.max(region.right, rect.right),
      math.max(region.bottom, rect.bottom),
    );
  }
}
