part of 'painting_board.dart';

const double _kStylusSimulationBlend = 0.68;
const int _kBackendPointStrideBytes = 32;
const int _kBackendPointFlagDown = 1;
const int _kBackendPointFlagMove = 2;
const int _kBackendPointFlagUp = 4;
const double _kBackendPressureMinFactor = 0.09;
const double _kBackendPressureMaxFactor = 1.0;
final bool _kDebugBackendCanvasInput =
    bool.fromEnvironment(
      'MISA_RIN_DEBUG_RUST_CANVAS_INPUT',
      defaultValue: false,
    );

final class _BackendPointBuffer {
  _BackendPointBuffer({int initialCapacityPoints = 256})
    : _bytes = Uint8List(initialCapacityPoints * _kBackendPointStrideBytes) {
    _data = ByteData.view(_bytes.buffer);
  }

  Uint8List _bytes;
  late ByteData _data;
  int _len = 0;

  int get length => _len;

  Uint8List get bytes => _bytes;

  void clear() => _len = 0;

  void add({
    required double x,
    required double y,
    required double pressure,
    required int timestampUs,
    required int flags,
    required int pointerId,
  }) {
    _ensureCapacity(_len + 1);
    final int base = _len * _kBackendPointStrideBytes;
    _data.setFloat32(base + 0, x, Endian.little);
    _data.setFloat32(base + 4, y, Endian.little);
    _data.setFloat32(base + 8, pressure, Endian.little);
    _data.setFloat32(base + 12, 0.0, Endian.little);
    _data.setUint64(base + 16, timestampUs, Endian.little);
    _data.setUint32(base + 24, flags, Endian.little);
    _data.setUint32(base + 28, pointerId, Endian.little);
    _len++;
  }

  void updateAt(
    int index, {
    double? x,
    double? y,
    double? pressure,
  }) {
    if (index < 0 || index >= _len) {
      return;
    }
    final int base = index * _kBackendPointStrideBytes;
    if (x != null) {
      _data.setFloat32(base + 0, x, Endian.little);
    }
    if (y != null) {
      _data.setFloat32(base + 4, y, Endian.little);
    }
    if (pressure != null) {
      _data.setFloat32(base + 8, pressure, Endian.little);
    }
  }

  void _ensureCapacity(int neededPoints) {
    final int neededBytes = neededPoints * _kBackendPointStrideBytes;
    if (_bytes.lengthInBytes >= neededBytes) {
      return;
    }
    int nextBytes = _bytes.lengthInBytes;
    while (nextBytes < neededBytes) {
      nextBytes = nextBytes * 2;
    }
    final Uint8List next = Uint8List(nextBytes);
    next.setRange(0, _len * _kBackendPointStrideBytes, _bytes, 0);
    _bytes = next;
    _data = ByteData.view(_bytes.buffer);
  }
}

final class _BackendPressureSimulator {
  _BackendPressureSimulator()
    : _strokeDynamics = StrokeDynamics(
        profile: StrokePressureProfile.auto,
        minRadiusFactor: _kBackendPressureMinFactor,
        maxRadiusFactor: _kBackendPressureMaxFactor,
      );

  final StrokeDynamics _strokeDynamics;
  final StrokeSampleSeries _strokeSamples = StrokeSampleSeries();
  final VelocitySmoother _velocitySmoother = VelocitySmoother();

  StrokePressureProfile _profile = StrokePressureProfile.auto;
  bool _simulatingStroke = false;
  bool _dynamicsEnabled = false;
  bool _usesDevicePressure = false;
  bool _sharpTipsEnabled = true;
  double _stylusPressureBlend = 1.0;

  bool get isSimulatingStroke => _simulatingStroke;

  void setSharpTipsEnabled(bool enabled) {
    _sharpTipsEnabled = enabled;
  }

  void resetTracking() {
    _strokeSamples.clear();
    _velocitySmoother.reset();
    _simulatingStroke = false;
    _dynamicsEnabled = false;
    _usesDevicePressure = false;
    _stylusPressureBlend = 1.0;
  }

  void setProfile(StrokePressureProfile profile) {
    if (_profile == profile) {
      return;
    }
    _profile = profile;
    _strokeDynamics.configure(profile: profile);
  }

  double? beginStroke({
    required Offset position,
    required double timestampMillis,
    required bool simulatePressure,
    required bool useDevicePressure,
    required double stylusPressureBlend,
    double? stylusPressure,
  }) {
    _strokeSamples.clear();
    _velocitySmoother.reset();
    _strokeSamples.add(position, timestampMillis);
    _velocitySmoother.addSample(position, timestampMillis);

    _dynamicsEnabled = simulatePressure;
    _usesDevicePressure = useDevicePressure;
    _stylusPressureBlend = stylusPressureBlend.clamp(0.0, 1.0);
    _simulatingStroke = _dynamicsEnabled || _sharpTipsEnabled;

    if (!_simulatingStroke) {
      return null;
    }

    _strokeDynamics.start(1.0, profile: _profile);

    if (!_dynamicsEnabled) {
      final double base = _normalizePressure(stylusPressure) ?? 1.0;
      final double initialPressure = _sharpTipsEnabled ? 0.0 : base;
      return initialPressure;
    }

    double initialPressure = _radiusToPressure(_strokeDynamics.initialRadius());
    if (_usesDevicePressure && stylusPressure != null) {
      final double? seeded = _seedPressureSample(stylusPressure);
      if (seeded != null) {
        initialPressure = seeded;
      }
    }
    return initialPressure;
  }

  double? samplePressure({
    required Offset position,
    required double timestampMillis,
    double? stylusPressure,
  }) {
    if (!_simulatingStroke) {
      return null;
    }
    final StrokeSample sample = _strokeSamples.add(position, timestampMillis);
    final double normalizedSpeed =
        _velocitySmoother.addSample(position, timestampMillis);

    if (!_dynamicsEnabled) {
      final double base = _normalizePressure(stylusPressure) ?? 1.0;
      double pressure = base;
      if (_sharpTipsEnabled) {
        const int rampSamples = 5;
        final int index = _strokeSamples.length - 1;
        if (index < rampSamples) {
          final double t = index / rampSamples;
          pressure = base * t;
        }
      }
      return pressure.clamp(0.0, 1.0);
    }

    final StrokeSampleMetrics? metrics =
        _profile == StrokePressureProfile.auto
            ? StrokeSampleMetrics(
                sampleIndex: _strokeSamples.length - 1,
                normalizedSpeed: normalizedSpeed,
                stationaryDuration: sample.stationaryDuration,
                totalDistance: _strokeSamples.totalDistance,
                totalTime: _strokeSamples.totalTime,
              )
            : null;
    final double? intensityOverride =
        _usesDevicePressure ? _stylusPressureToIntensity(stylusPressure) : null;
    final double effectiveBlend =
        intensityOverride != null ? _stylusPressureBlend : 0.0;
    final double radius = _strokeDynamics.sample(
      distance: sample.distance,
      deltaTimeMillis: sample.deltaTime,
      metrics: metrics,
      intensityOverride: intensityOverride,
      speedSignal: normalizedSpeed,
      intensityBlend: effectiveBlend,
    );
    return _radiusToPressure(radius);
  }

  double _radiusToPressure(double radius) {
    final double minRadius = _strokeDynamics.minRadius;
    final double maxRadius = _strokeDynamics.maxRadius;
    final double span = maxRadius - minRadius;
    if (span <= 0.0001) {
      return 1.0;
    }
    return ((radius - minRadius) / span).clamp(0.0, 1.0);
  }

  double? _seedPressureSample(double pressure) {
    final double? intensity = _stylusPressureToIntensity(pressure);
    if (intensity == null) {
      return null;
    }
    final double radius = _strokeDynamics.sample(
      distance: 0.0,
      intensityOverride: intensity,
      speedSignal: 0.0,
      intensityBlend: _stylusPressureBlend,
    );
    return _radiusToPressure(radius);
  }

  double? _stylusPressureToIntensity(double? pressure) {
    if (pressure == null || !pressure.isFinite) {
      return null;
    }
    return (1.0 - pressure.clamp(0.0, 1.0)).clamp(0.0, 1.0);
  }

  double? _normalizePressure(double? pressure) {
    if (pressure == null || !pressure.isFinite) {
      return null;
    }
    return pressure.clamp(0.0, 1.0);
  }
}

enum _CpuStrokeEventType { down, move, up, cancel }

class _CpuStrokeEvent {
  const _CpuStrokeEvent({
    required this.type,
    required this.position,
    required this.timestamp,
    required this.event,
  });

  final _CpuStrokeEventType type;
  final Offset position;
  final Duration timestamp;
  final PointerEvent? event;
}

mixin _PaintingBoardInteractionMixin
    on
        _PaintingBoardBase,
        _PaintingBoardLayerTransformMixin,
        _PaintingBoardShapeMixin,
        _PaintingBoardReferenceMixin,
        _PaintingBoardPerspectiveMixin,
        _PaintingBoardTextMixin,
        TickerProvider {
  final _BackendPointBuffer _backendPoints = _BackendPointBuffer();
  final _BackendPressureSimulator _backendPressureSimulator =
      _BackendPressureSimulator();
  bool _backendFlushScheduled = false;
  int? _backendActivePointer;
  bool _backendActiveStrokeUsesPressure = true;
  bool _backendSimulatePressure = false;
  bool _backendUseStylusPressure = false;
  Offset? _backendLastEnginePoint;
  Offset? _backendLastMovementUnit;
  double _backendLastMovementDistance = 0.0;
  double? _backendLastStylusPressure;
  double _backendLastResolvedPressure = 1.0;
  bool _backendWaitingForFirstMove = false;
  Offset? _backendStrokeStartPoint;
  double _backendStrokeStartPressure = 1.0;
  int _backendStrokeStartIndex = 0;

  final List<_CpuStrokeEvent> _cpuStrokeQueue = <_CpuStrokeEvent>[];
  bool _cpuStrokeFlushScheduled = false;
  bool _cpuStrokeProcessing = false;

  void clear() async {
    if (_isTextEditingActive) {
      await _cancelTextEditingSession();
    }
    await _pushUndoSnapshot();
    _controller.clear();
    _emitClean();
    setState(() {
      // No-op placeholder for repaint
    });
  }

  void _setActiveTool(CanvasTool tool) {
    final bool shouldCommitText =
        tool != CanvasTool.text && _isTextEditingActive;
    if (_guardTransformInProgress(message: context.l10n.completeTransformFirst)) {
      return;
    }
    if (shouldCommitText) {
      unawaited(_commitTextEditingSession());
    }
    if (_activeTool == tool) {
      return;
    }
    if (_activeTool == CanvasTool.spray && _isSpraying) {
      _finishSprayStroke();
    }
    if (_activeTool == CanvasTool.curvePen) {
      _resetCurvePenState(notify: false);
    }
    if (_activeTool == CanvasTool.layerAdjust && _isLayerDragging) {
      _finishLayerAdjustDrag();
    }
    if (_activeTool == CanvasTool.eyedropper && _isEyedropperSampling) {
      _finishEyedropperSample();
    }
    if (_activeTool == CanvasTool.selectionPen) {
      _handleSelectionPenPointerCancel();
    }
    if (tool != CanvasTool.text) {
      _clearTextHoverHighlight();
    }
    if (tool != CanvasTool.perspectivePen) {
      _clearPerspectivePenPreview();
    }
    setState(() {
      if (_activeTool == CanvasTool.magicWand) {
        _convertMagicWandPreviewToSelection();
      } else if (tool != CanvasTool.magicWand) {
        _clearMagicWandPreview();
      }
      if (tool == CanvasTool.magicWand) {
        _convertSelectionToMagicWandPreview();
      }
      final bool nextIsSelectionTool =
          tool == CanvasTool.selection || tool == CanvasTool.selectionPen;
      final bool currentIsSelectionTool =
          _activeTool == CanvasTool.selection ||
          _activeTool == CanvasTool.selectionPen;
      if (!nextIsSelectionTool || currentIsSelectionTool) {
        _resetSelectionPreview();
        _resetPolygonState();
      }
      if (tool != CanvasTool.curvePen) {
        _curvePreviewPath = null;
      }
      if (tool != CanvasTool.shape) {
        _disposeShapeRasterPreview(restoreLayer: true);
        _resetShapeDrawingState();
      }
      if (_activeTool == CanvasTool.eyedropper) {
        _isEyedropperSampling = false;
        _lastEyedropperSample = null;
      }
      _activeTool = tool;
      if (_cursorRequiresOverlay) {
        final Offset? pointer = _lastWorkspacePointer;
        if (pointer != null && _boardRect.contains(pointer)) {
          _toolCursorPosition = pointer;
        } else {
          _toolCursorPosition = null;
        }
      } else if (_penRequiresOverlay) {
        _toolCursorPosition = null;
        final Offset? pointer = _lastWorkspacePointer;
        if (pointer != null && _boardRect.contains(pointer)) {
          _penCursorWorkspacePosition = pointer;
        } else {
          _penCursorWorkspacePosition = null;
        }
      } else {
        _toolCursorPosition = null;
        _penCursorWorkspacePosition = null;
      }
    });
    _updateSelectionAnimation();
    _scheduleWorkspaceCardsOverlaySync();
  }

  void _updatePenStrokeWidth(double value) {
    final double clamped = _penStrokeSliderRange.clamp(value);
    if ((_penStrokeWidth - clamped).abs() < 0.0005) {
      return;
    }
    setState(() => _penStrokeWidth = clamped);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.penStrokeWidth = clamped;
    unawaited(AppPreferences.save());
  }

  void _updateSprayStrokeWidth(double value) {
    final double clamped = value.clamp(kSprayStrokeMin, kSprayStrokeMax);
    if ((_sprayStrokeWidth - clamped).abs() < 0.0005) {
      return;
    }
    setState(() => _sprayStrokeWidth = clamped);
    if (_sprayMode == SprayMode.splatter) {
      _kritaSprayEngine?.updateSettings(_buildKritaSpraySettings());
    }
    final AppPreferences prefs = AppPreferences.instance;
    prefs.sprayStrokeWidth = clamped;
    unawaited(AppPreferences.save());
  }


  @override
  void _updatePenPressureSimulation(bool value) {
    if (_simulatePenPressure == value) {
      return;
    }
    setState(() => _simulatePenPressure = value);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.simulatePenPressure = value;
    unawaited(AppPreferences.save());
  }


  @override
  void _updatePenPressureProfile(StrokePressureProfile profile) {
    if (_penPressureProfile == profile) {
      return;
    }
    setState(() => _penPressureProfile = profile);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.penPressureProfile = profile;
    unawaited(AppPreferences.save());
  }

  @override
  void _updatePenAntialiasLevel(int value) {
    final int clamped = value.clamp(0, 9);
    if (_penAntialiasLevel == clamped) {
      return;
    }
    setState(() => _penAntialiasLevel = clamped);
    if (_sprayMode == SprayMode.splatter) {
      _kritaSprayEngine?.updateSettings(_buildKritaSpraySettings());
    }
    final AppPreferences prefs = AppPreferences.instance;
    prefs.penAntialiasLevel = clamped;
    unawaited(AppPreferences.save());
  }


  @override
  void _updateAutoSharpPeakEnabled(bool value) {
    if (_autoSharpPeakEnabled == value) {
      return;
    }
    setState(() => _autoSharpPeakEnabled = value);
    _backendPressureSimulator.setSharpTipsEnabled(value);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.autoSharpPeakEnabled = value;
    unawaited(AppPreferences.save());
    _applyStylusSettingsToController();
  }


  void _updateBucketSampleAllLayers(bool value) {
    if (_bucketSampleAllLayers == value) {
      return;
    }
    setState(() => _bucketSampleAllLayers = value);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.bucketSampleAllLayers = value;
    unawaited(AppPreferences.save());
  }

  void _updateBucketContiguous(bool value) {
    if (_bucketContiguous == value) {
      return;
    }
    setState(() => _bucketContiguous = value);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.bucketContiguous = value;
    unawaited(AppPreferences.save());
  }



  @override
  void _handleWorkspacePointerExit() {
    if (_effectiveActiveTool == CanvasTool.selection) {
      _clearSelectionHover();
    }
    _clearTextHoverHighlight();
    if (_effectiveActiveTool != CanvasTool.perspectivePen) {
      _clearPerspectivePenPreview();
    }
    _clearToolCursorOverlay();
    _clearLayerTransformCursorIndicator();
    _clearPerspectiveHover();
    if (_lastWorkspacePointer != null) {
      _lastWorkspacePointer = null;
      _notifyViewInfoChanged();
    }
  }


  bool _isActiveLayerLocked() => _isActiveLayerLockedImpl();

  Offset _backendToEngineSpace(Offset boardLocal) =>
      _backendToEngineSpaceImpl(boardLocal);

  void _handlePointerDown(PointerDownEvent event) async {
    await _handlePointerDownImpl(event);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    _handlePointerMoveImpl(event);
  }

  void _handlePointerUp(PointerUpEvent event) async {
    await _handlePointerUpImpl(event);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _handlePointerCancelImpl(event);
  }

  void _handlePointerHover(PointerHoverEvent event) {
    _handlePointerHoverImpl(event);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    _handlePointerSignalImpl(event);
  }

  @override
  KeyEventResult _handleWorkspaceKeyEvent(FocusNode node, KeyEvent event) {
    return _handleWorkspaceKeyEventImpl(node, event);
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _handleScaleStartImpl(details);
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    _handleScaleUpdateImpl(details);
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _handleScaleEndImpl(details);
  }

  void _handleUndo() {
    _handleUndoImpl();
  }

  void _handleRedo() {
    _handleRedoImpl();
  }
}
