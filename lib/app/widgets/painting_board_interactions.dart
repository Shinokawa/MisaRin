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

  bool _isBackendDrawingPointer(PointerEvent event) {
    if (_isStylusEvent(event)) {
      return true;
    }
    if (event.kind == PointerDeviceKind.touch) {
      return true;
    }
    if (event.kind == PointerDeviceKind.mouse) {
      return (event.buttons & kPrimaryMouseButton) != 0;
    }
    return false;
  }

  bool _isActiveLayerLocked() {
    final String? activeId = _controller.activeLayerId;
    if (activeId == null) {
      return false;
    }
    for (final CanvasLayerInfo layer in _controller.layers) {
      if (layer.id == activeId) {
        return layer.locked;
      }
    }
    return false;
  }

  bool _canStartBackendStroke({required bool pointerInsideBoard}) {
    if (!pointerInsideBoard) {
      return false;
    }
    if (!_backend.supportsStrokeStream) {
      return false;
    }
    if (_layerTransformModeActive ||
        _isLayerFreeTransformActive ||
        _controller.isActiveLayerTransforming) {
      return false;
    }
    if (_isActiveLayerLocked()) {
      return false;
    }
    return true;
  }

  bool _canStartBitmapStroke({required bool pointerInsideBoard}) {
    if (!pointerInsideBoard) {
      return false;
    }
    if (_layerTransformModeActive ||
        _isLayerFreeTransformActive ||
        _controller.isActiveLayerTransforming) {
      return false;
    }
    if (_isActiveLayerLocked()) {
      return false;
    }
    return true;
  }

  bool get _useCpuStrokeQueue =>
      !_backend.isSupported || !_brushShapeSupportsBackend;

  void _enqueueCpuStrokeEvent({
    required _CpuStrokeEventType type,
    required Offset boardLocal,
    required Duration timestamp,
    required PointerEvent? event,
  }) {
    _cpuStrokeQueue.add(
      _CpuStrokeEvent(
        type: type,
        position: boardLocal,
        timestamp: timestamp,
        event: event,
      ),
    );
    _scheduleCpuStrokeFlush();
  }

  void _scheduleCpuStrokeFlush() {
    if (_cpuStrokeFlushScheduled) {
      return;
    }
    _cpuStrokeFlushScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _cpuStrokeFlushScheduled = false;
      if (!mounted) {
        _cpuStrokeQueue.clear();
        return;
      }
      unawaited(_flushCpuStrokeQueue());
    });
  }

  Future<void> _flushCpuStrokeQueue() async {
    if (_cpuStrokeProcessing) {
      return;
    }
    _cpuStrokeProcessing = true;
    try {
      while (_cpuStrokeQueue.isNotEmpty) {
        final List<_CpuStrokeEvent> batch =
            List<_CpuStrokeEvent>.from(_cpuStrokeQueue);
        _cpuStrokeQueue.clear();
        for (final _CpuStrokeEvent item in batch) {
          await _processCpuStrokeEvent(item);
        }
      }
    } finally {
      _cpuStrokeProcessing = false;
    }
  }

  Future<void> _processCpuStrokeEvent(_CpuStrokeEvent event) async {
    switch (event.type) {
      case _CpuStrokeEventType.down:
        await _startStroke(event.position, event.timestamp, event.event);
        break;
      case _CpuStrokeEventType.move:
        if (_isDrawing) {
          _appendPoint(event.position, event.timestamp, event.event);
        }
        break;
      case _CpuStrokeEventType.up:
        if (_isDrawing) {
          final double? releasePressure = _stylusPressureValue(event.event);
          if (_activeStrokeUsesStylus) {
            _appendStylusReleaseSample(
              event.position,
              event.timestamp,
              releasePressure,
            );
          }
          if (_activeStrokeUsesStylus) {
            _finishStroke();
          } else {
            _finishStroke(event.timestamp);
          }
        }
        break;
      case _CpuStrokeEventType.cancel:
        if (_isDrawing) {
          _finishStroke(event.timestamp);
        }
        break;
    }
  }

  Offset _backendToEngineSpace(Offset boardLocal) {
    final Size engineSize = _backendCanvasEngineSize ?? _canvasSize;
    if (engineSize == _canvasSize ||
        _canvasSize.width <= 0 ||
        _canvasSize.height <= 0) {
      return boardLocal;
    }
    final double sx = engineSize.width / _canvasSize.width;
    final double sy = engineSize.height / _canvasSize.height;
    return Offset(boardLocal.dx * sx, boardLocal.dy * sy);
  }

  Offset _sanitizeBackendStrokePosition(
    Offset boardLocal, {
    required bool isInitialSample,
  }) {
    final Offset sanitized = _sanitizeStrokePosition(
      boardLocal,
      isInitialSample: isInitialSample,
      anchor: _lastStrokeBoardPosition,
      clampToCanvas: false,
    );
    _lastStrokeBoardPosition = sanitized;
    return sanitized;
  }

  double? _normalizePointerPressure(PointerEvent event) {
    final double? pressure = _stylusPressureValue(event);
    if (pressure == null || !pressure.isFinite) {
      return null;
    }
    double lower = event.pressureMin;
    double upper = event.pressureMax;
    if (!lower.isFinite) {
      lower = 0.0;
    }
    if (!upper.isFinite || upper <= lower) {
      upper = lower + 1.0;
    }
    final double normalized = (pressure - lower) / (upper - lower);
    if (!normalized.isFinite) {
      return null;
    }
    final double curve = _stylusCurve.isFinite ? _stylusCurve : 1.0;
    final double curved =
        math.pow(normalized.clamp(0.0, 1.0), curve).toDouble();
    return curved.clamp(0.0, 1.0);
  }

  double _resolveBackendPressure({
    required PointerEvent event,
    required Offset enginePos,
    required bool isInitialSample,
  }) {
    if (!_backendActiveStrokeUsesPressure) {
      return 1.0;
    }
    final bool isUpEvent = event is PointerUpEvent || event is PointerCancelEvent;
    double? stylusPressure =
        _backendUseStylusPressure ? _normalizePointerPressure(event) : null;
    if (_backendUseStylusPressure) {
      if (!isUpEvent && stylusPressure != null) {
        _backendLastStylusPressure = stylusPressure;
      } else if (isUpEvent) {
        stylusPressure = _backendLastStylusPressure ?? stylusPressure;
      }
    }
    final bool shouldSimulate = _backendSimulatePressure || _autoSharpPeakEnabled;
    if (!shouldSimulate) {
      return stylusPressure ?? 1.0;
    }
    final double timestampMillis = event.timeStamp.inMicroseconds / 1000.0;
    if (isInitialSample) {
      _backendPressureSimulator.setProfile(_penPressureProfile);
      _backendPressureSimulator.setSharpTipsEnabled(_autoSharpPeakEnabled);
      final double stylusBlend =
          _backendUseStylusPressure && _backendSimulatePressure
              ? _kStylusSimulationBlend
              : 1.0;
      final double? initialPressure = _backendPressureSimulator.beginStroke(
        position: enginePos,
        timestampMillis: timestampMillis,
        simulatePressure: _backendSimulatePressure,
        useDevicePressure: _backendUseStylusPressure,
        stylusPressureBlend: stylusBlend,
        stylusPressure: stylusPressure,
      );
      return initialPressure ?? stylusPressure ?? 1.0;
    }
    final double? simulated = _backendPressureSimulator.samplePressure(
      position: enginePos,
      timestampMillis: timestampMillis,
      stylusPressure: stylusPressure,
    );
    return simulated ?? stylusPressure ?? 1.0;
  }

  void _appendBackendPoint({
    required Offset enginePos,
    required double pressure,
    required int timestampUs,
    required int flags,
    required int pointerId,
  }) {
    final Offset? previous = _backendLastEnginePoint;
    if (previous != null) {
      final Offset delta = enginePos - previous;
      final double distance = delta.distance;
      if (distance.isFinite && distance > 0.001) {
        _backendLastMovementUnit = delta / distance;
        _backendLastMovementDistance = distance;
      }
    }
    _backendLastResolvedPressure = pressure;
    _backendLastEnginePoint = enginePos;
    _backendPoints.add(
      x: enginePos.dx,
      y: enginePos.dy,
      pressure: pressure,
      timestampUs: timestampUs,
      flags: flags,
      pointerId: pointerId,
    );
  }

  double _backendRadiusFromPressure(double pressure, double baseRadius) {
    final double base = baseRadius.isFinite ? math.max(baseRadius, 0.0) : 0.0;
    if (base <= 0.0) {
      return 0.0;
    }
    final double clamped =
        pressure.isFinite ? pressure.clamp(0.0, 1.0) : 0.0;
    return base *
        (_kBackendPressureMinFactor +
            (1.0 - _kBackendPressureMinFactor) * clamped);
  }

  Offset? _computeBackendSharpTail({
    required Offset tip,
    required Offset? previousPoint,
    required double baseRadius,
  }) {
    Offset? unit;
    double length = 0.0;
    if (previousPoint != null) {
      final Offset direction = tip - previousPoint;
      length = direction.distance;
      if (length.isFinite && length > 0.001) {
        unit = direction / length;
      }
    }
    unit ??= _backendLastMovementUnit;
    if (unit == null) {
      return null;
    }
    final double base = math.max(baseRadius, 0.1);
    final double movement =
        length > 0.001 ? length : _backendLastMovementDistance;
    final double taperMax = base * 6.5;
    final double taperDynamic = movement * 2.4 + 2.0;
    final double taperLength = math.min(taperMax, taperDynamic);
    return tip + unit * taperLength;
  }

  void _maybeEmitBackendSharpStart({
    required Offset currentPos,
    required double currentPressure,
    required int timestampUs,
    required int pointerId,
  }) {
    if (!_backendWaitingForFirstMove) {
      return;
    }
    _backendWaitingForFirstMove = false;
    if (!_autoSharpPeakEnabled || !_backendPressureSimulator.isSimulatingStroke) {
      return;
    }
    final Offset? startPos = _backendStrokeStartPoint;
    if (startPos == null) {
      return;
    }
    final double baseRadius =
        (_penStrokeWidth / 2).clamp(0.0, 4096.0).toDouble();
    final Offset deltaToCurrent = currentPos - startPos;
    final double distToCurrent = deltaToCurrent.distance;
    if (!distToCurrent.isFinite || distToCurrent <= 0.001) {
      return;
    }
    final double startPressure = _backendStrokeStartPressure.clamp(0.0, 1.0);
    final double r0 = _backendRadiusFromPressure(startPressure, baseRadius);
    final double r1 =
        _backendRadiusFromPressure(currentPressure.clamp(0.0, 1.0), baseRadius);
    if (distToCurrent + r0 >= r1) {
      return;
    }
    final Offset? headPoint = _computeBackendSharpTail(
      tip: startPos,
      previousPoint: currentPos,
      baseRadius: baseRadius,
    );
    if (headPoint == null || _backendStrokeStartIndex >= _backendPoints.length) {
      return;
    }
    _backendPoints.updateAt(
      _backendStrokeStartIndex,
      x: headPoint.dx,
      y: headPoint.dy,
      pressure: 0.0,
    );
    _backendLastEnginePoint = headPoint;
    _backendLastResolvedPressure = 0.0;
    final Offset delta = startPos - headPoint;
    final double dist = delta.distance;
    if (dist.isFinite && dist > 0.5 && startPressure > 0.001) {
      final double spacing = math.max(baseRadius * 0.35, 0.75);
      final int segments =
          math.max(2, (dist / spacing).ceil()).clamp(2, 10).toInt();
      for (int i = 1; i < segments; i++) {
        final double t = i / segments;
        final double eased = math.pow(t, 1.6).toDouble();
        final double midPressure = (startPressure * eased).clamp(0.0, 1.0);
        if (midPressure <= 0.001) {
          continue;
        }
        final Offset midPoint = headPoint + delta * t;
        _appendBackendPoint(
          enginePos: midPoint,
          pressure: midPressure,
          timestampUs: timestampUs,
          flags: _kBackendPointFlagMove,
          pointerId: pointerId,
        );
      }
    }
    _appendBackendPoint(
      enginePos: startPos,
      pressure: startPressure,
      timestampUs: timestampUs,
      flags: _kBackendPointFlagMove,
      pointerId: pointerId,
    );
  }

  void _enqueueBackendPoint(
    PointerEvent event,
    int flags, {
    bool isInitialSample = false,
  }) {
    final int? handle = _backendCanvasEngineHandle;
    if (!_backend.supportsInputQueue || handle == null) {
      return;
    }
    final Offset boardLocal = _toBoardLocal(event.localPosition);
    final Offset sanitized = _sanitizeBackendStrokePosition(
      boardLocal,
      isInitialSample: isInitialSample,
    );
    final Offset enginePos = _backendToEngineSpace(sanitized);
    final double pressure = _resolveBackendPressure(
      event: event,
      enginePos: enginePos,
      isInitialSample: isInitialSample,
    );
    final int timestampUs = event.timeStamp.inMicroseconds;
    if (flags == _kBackendPointFlagMove) {
      _maybeEmitBackendSharpStart(
        currentPos: enginePos,
        currentPressure: pressure,
        timestampUs: timestampUs,
        pointerId: event.pointer,
      );
    }
    if (flags == _kBackendPointFlagDown) {
      _backendStrokeStartPoint = enginePos;
      _backendStrokeStartPressure = pressure;
      _backendStrokeStartIndex = _backendPoints.length;
    }
    _appendBackendPoint(
      enginePos: enginePos,
      pressure: pressure,
      timestampUs: timestampUs,
      flags: flags,
      pointerId: event.pointer,
    );
    if (_kDebugBackendCanvasInput &&
        (flags == _kBackendPointFlagDown || flags == _kBackendPointFlagUp)) {
      final int queued = _backend.getInputQueueLen(handle: handle) ?? 0;
      debugPrint(
        '[backend_canvas] enqueue flags=$flags points=${_backendPoints.length} '
        'queued=$queued streamline=${_streamlineStrength.toStringAsFixed(3)}',
      );
    }
    _scheduleBackendFlush();
  }

  void _scheduleBackendFlush() {
    if (_backendWaitingForFirstMove && _backendPoints.length <= 1) {
      if (_kDebugBackendCanvasInput && _backendPoints.length == 1) {
        debugPrint(
          '[backend_canvas] flush skipped: waiting first move '
          'streamline=${_streamlineStrength.toStringAsFixed(3)}',
        );
      }
      return;
    }
    if (_backendFlushScheduled) {
      return;
    }
    _backendFlushScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _backendFlushScheduled = false;
      if (!mounted) {
        _backendPoints.clear();
        return;
      }
      final int? handle = _backendCanvasEngineHandle;
      if (!_backend.supportsInputQueue || handle == null) {
        _backendPoints.clear();
        return;
      }
      _flushBackendPoints(handle);
    });
  }

  void _flushBackendPoints(int handle) {
    final int count = _backendPoints.length;
    if (count == 0) {
      return;
    }
    if (_kDebugBackendCanvasInput) {
      final int queued = _backend.getInputQueueLen(handle: handle) ?? 0;
      debugPrint(
        '[backend_canvas] flush points=$count queued_before=$queued '
        'streamline=${_streamlineStrength.toStringAsFixed(3)}',
      );
    }
    final bool pushed = _backend.pushPointsPacked(
      bytes: _backendPoints.bytes,
      pointCount: count,
    );
    _backendPoints.clear();
    if (_kDebugBackendCanvasInput) {
      final int queuedAfter = _backend.getInputQueueLen(handle: handle) ?? 0;
      debugPrint(
        '[backend_canvas] flush done pushed=$pushed queued_after=$queuedAfter '
        'streamline=${_streamlineStrength.toStringAsFixed(3)}',
      );
    }
  }

  void _beginBackendStroke(PointerDownEvent event) {
    if (!_isBackendDrawingPointer(event)) {
      return;
    }
    if (_kDebugBackendCanvasInput) {
      debugPrint(
        '[backend_canvas] begin backend stroke '
        'id=${event.pointer} kind=${event.kind} down=${event.down} '
        'buttons=${event.buttons} pos=${event.localPosition} '
        'pressure=${event.pressure} handle=$_backendCanvasEngineHandle '
        'inputQueue=${_backend.supportsInputQueue}',
      );
    }
    _resetPerspectiveLock();
    _lastStrokeBoardPosition = null;
    _backendLastEnginePoint = null;
    _backendLastMovementUnit = null;
    _backendLastMovementDistance = 0.0;
    _backendLastStylusPressure = null;
    _backendLastResolvedPressure = 1.0;
    _backendWaitingForFirstMove = _autoSharpPeakEnabled;
    _backendStrokeStartPoint = null;
    _backendStrokeStartPressure = 1.0;
    _backendStrokeStartIndex = 0;
    final bool supportsPressure = _isStylusEvent(event);
    _backendPressureSimulator.resetTracking();
    _backendSimulatePressure = _simulatePenPressure;
    _backendUseStylusPressure = _stylusPressureEnabled && supportsPressure;
    _backendActiveStrokeUsesPressure =
        _backendUseStylusPressure || _backendSimulatePressure || _autoSharpPeakEnabled;
    _backendPressureSimulator.setSharpTipsEnabled(_autoSharpPeakEnabled);
    _backendActivePointer = event.pointer;
    _enqueueBackendPoint(event, _kBackendPointFlagDown, isInitialSample: true);
    _markDirty();
  }

  void _endBackendStroke(PointerEvent event) {
    if (_kDebugBackendCanvasInput) {
      debugPrint(
        '[backend_canvas] end backend stroke '
        'id=${event.pointer} kind=${event.kind} down=${event.down} '
        'buttons=${event.buttons} pos=${event.localPosition} '
        'pressure=${event.pressure} handle=$_backendCanvasEngineHandle',
      );
    }
    final bool hadActiveStroke = _backendActivePointer != null;
    final int? handle = _backendCanvasEngineHandle;
    final bool canRecordHistory =
        hadActiveStroke && _backend.supportsStrokeStream;
    if (_backend.supportsInputQueue && handle != null) {
      _backendWaitingForFirstMove = false;
      final Offset boardLocal = _toBoardLocal(event.localPosition);
      final Offset sanitized = _sanitizeBackendStrokePosition(
        boardLocal,
        isInitialSample: false,
      );
      _lastBrushLineAnchor = sanitized;
      final Offset enginePos = _backendToEngineSpace(sanitized);
      final double pressure = _resolveBackendPressure(
        event: event,
        enginePos: enginePos,
        isInitialSample: false,
      );
      final int timestampUs = event.timeStamp.inMicroseconds;
      final double startPressure = _backendLastResolvedPressure.isFinite
          ? _backendLastResolvedPressure
          : pressure;
      final bool wantsSharpTail =
          _autoSharpPeakEnabled && _backendPressureSimulator.isSimulatingStroke;
      if (wantsSharpTail) {
        final Offset? previousPoint = _backendLastEnginePoint;
        final double baseRadius =
            (_penStrokeWidth / 2).clamp(0.0, 4096.0).toDouble();
        Offset? tailPoint = _computeBackendSharpTail(
          tip: enginePos,
          previousPoint: previousPoint,
          baseRadius: baseRadius,
        );
        final double lastRadius =
            _backendRadiusFromPressure(startPressure, baseRadius);
        final double endRadius = _backendRadiusFromPressure(0.0, baseRadius);
        if (tailPoint == null &&
            _backendLastMovementUnit != null &&
            lastRadius > endRadius) {
          final double targetDist = lastRadius - endRadius + 1.5;
          tailPoint = enginePos + _backendLastMovementUnit! * targetDist;
        } else if (tailPoint != null && lastRadius > endRadius) {
          final Offset delta = tailPoint - enginePos;
          final double dist = delta.distance;
          if (dist.isFinite && dist > 0.001 && dist + endRadius < lastRadius) {
            final double targetDist = lastRadius - endRadius + 1.5;
            tailPoint = enginePos + (delta / dist) * targetDist;
          }
        }
        if (tailPoint != null) {
          final double tailPressure = startPressure.clamp(0.0, 1.0);
          _appendBackendPoint(
            enginePos: enginePos,
            pressure: tailPressure,
            timestampUs: timestampUs,
            flags: _kBackendPointFlagMove,
            pointerId: event.pointer,
          );
          final Offset delta = tailPoint - enginePos;
          final double dist = delta.distance;
          if (dist.isFinite && dist > 0.5 && tailPressure > 0.001) {
            final double spacing = math.max(baseRadius * 0.35, 0.75);
            final int segments =
                math.max(2, (dist / spacing).ceil()).clamp(2, 10).toInt();
            for (int i = 1; i < segments; i++) {
              final double t = i / segments;
              final double eased = math.pow(1.0 - t, 1.6).toDouble();
              final double midPressure =
                  (tailPressure * eased).clamp(0.0, 1.0);
              if (midPressure <= 0.001) {
                continue;
              }
              final Offset midPoint = enginePos + delta * t;
              _appendBackendPoint(
                enginePos: midPoint,
                pressure: midPressure,
                timestampUs: timestampUs,
                flags: _kBackendPointFlagMove,
                pointerId: event.pointer,
              );
            }
          }
          _appendBackendPoint(
            enginePos: tailPoint,
            pressure: 0.0,
            timestampUs: timestampUs,
            flags: _kBackendPointFlagUp,
            pointerId: event.pointer,
          );
        } else {
          _appendBackendPoint(
            enginePos: enginePos,
            pressure: 0.0,
            timestampUs: timestampUs,
            flags: _kBackendPointFlagUp,
            pointerId: event.pointer,
          );
        }
      } else {
        _appendBackendPoint(
          enginePos: enginePos,
          pressure: pressure,
          timestampUs: timestampUs,
          flags: _kBackendPointFlagUp,
          pointerId: event.pointer,
        );
      }
      _scheduleBackendFlush();
      if (canRecordHistory) {
        _recordBackendHistoryAction(
          layerId: _activeLayerId,
          deferPreview: true,
        );
        if (mounted) {
          setState(() {});
        }
      }
    }
    _backendActivePointer = null;
    _backendActiveStrokeUsesPressure = true;
    _backendSimulatePressure = false;
    _backendUseStylusPressure = false;
    _backendPressureSimulator.resetTracking();
    _backendLastEnginePoint = null;
    _backendLastMovementUnit = null;
    _backendLastMovementDistance = 0.0;
    _backendLastStylusPressure = null;
    _backendLastResolvedPressure = 1.0;
    _backendWaitingForFirstMove = false;
    _backendStrokeStartPoint = null;
    _backendStrokeStartPressure = 1.0;
    _backendStrokeStartIndex = 0;
    _lastStrokeBoardPosition = null;
    _strokeStabilizer.reset();
    _resetPerspectiveLock();
  }

  bool _drawBackendStraightLine({
    required Offset start,
    required Offset end,
    required PointerDownEvent event,
  }) {
    final int? handle = _backendCanvasEngineHandle;
    if (!_backend.supportsInputQueue || handle == null) {
      return false;
    }
    final Offset startClamped = _clampToCanvas(start);
    final Offset endClamped = _clampToCanvas(end);
    final Offset startEngine = _backendToEngineSpace(startClamped);
    final Offset endEngine = _backendToEngineSpace(endClamped);
    final int startTimestampUs = event.timeStamp.inMicroseconds;
    final int endTimestampUs = startTimestampUs + 1000;
    final double pressure =
        (_normalizePointerPressure(event) ?? 1.0).clamp(0.0, 1.0);

    _backendLastEnginePoint = null;
    _backendLastMovementUnit = null;
    _backendLastMovementDistance = 0.0;
    _backendLastStylusPressure = null;
    _backendLastResolvedPressure = 1.0;
    _backendWaitingForFirstMove = false;
    _backendStrokeStartPoint = null;
    _backendStrokeStartPressure = 1.0;
    _backendStrokeStartIndex = 0;

    _appendBackendPoint(
      enginePos: startEngine,
      pressure: pressure,
      timestampUs: startTimestampUs,
      flags: _kBackendPointFlagDown,
      pointerId: event.pointer,
    );
    _appendBackendPoint(
      enginePos: endEngine,
      pressure: pressure,
      timestampUs: endTimestampUs,
      flags: _kBackendPointFlagUp,
      pointerId: event.pointer,
    );
    _scheduleBackendFlush();
    _recordBackendHistoryAction(
      layerId: _activeLayerId,
      deferPreview: true,
    );
    if (mounted) {
      setState(() {});
    }
    _markDirty();
    _resetPerspectiveLock();
    return true;
  }

  void _handlePointerDown(PointerDownEvent event) async {
    if (!_isPrimaryPointer(event)) {
      return;
    }
    if (_isScalingGesture) {
      return;
    }
    if (_layerTransformApplying) {
      return;
    }
    _recordWorkspacePointer(event.localPosition);
    _updateToolCursorOverlay(event.localPosition);
    final Offset pointer = event.localPosition;
    if (_isInsideToolArea(pointer) || _isInsideWorkspacePanelArea(pointer)) {
      return;
    }
    final CanvasTool tool = _effectiveActiveTool;
    final Rect boardRect = _boardRect;
    final Offset boardLocal = _toBoardLocal(pointer);
    final Set<LogicalKeyboardKey> pressedKeys =
        HardwareKeyboard.instance.logicalKeysPressed;
    final bool shiftPressed =
        pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
        pressedKeys.contains(LogicalKeyboardKey.shiftRight) ||
        pressedKeys.contains(LogicalKeyboardKey.shift);
    final bool preferNearestPerspectiveHandle =
        _perspectiveVisible &&
        _perspectiveMode != PerspectiveGuideMode.off &&
        tool == CanvasTool.hand &&
        shiftPressed;
    if (_handlePerspectivePointerDown(
      boardLocal,
      allowNearest: preferNearestPerspectiveHandle,
    )) {
      return;
    }
    final bool pointerInsideBoard = boardRect.contains(pointer);
    if (_kDebugBackendCanvasInput &&
        (tool == CanvasTool.pen || tool == CanvasTool.eraser)) {
      debugPrint(
        '[backend_canvas] down id=${event.pointer} kind=${event.kind} '
        'down=${event.down} buttons=${event.buttons} '
        'pos=${event.localPosition} pressure=${event.pressure}',
      );
      debugPrint(
        '[backend_canvas] pen/eraser down tool=$tool '
        'pointerInsideBoard=$pointerInsideBoard '
        'backendSupported=${_backend.isSupported} '
        'backendReady=${_backend.isReady} '
        'handle=$_backendCanvasEngineHandle '
        'inputQueue=${_backend.supportsInputQueue} '
        'strokeStream=${_backend.supportsStrokeStream}',
      );
    }
    final bool toolCanStartOutsideCanvas =
        tool == CanvasTool.curvePen ||
        tool == CanvasTool.selection ||
        tool == CanvasTool.selectionPen ||
        tool == CanvasTool.spray ||
        tool == CanvasTool.pen ||
        tool == CanvasTool.eraser ||
        tool == CanvasTool.perspectivePen;
    if (!pointerInsideBoard && !toolCanStartOutsideCanvas) {
      return;
    }
    if (_shouldBlockToolOnTextLayer(tool)) {
      _showTextToolConflictWarning();
      return;
    }
    if (_isTextEditingActive) {
      return;
    }
    if (_layerTransformModeActive) {
      if (pointerInsideBoard) {
        _handleLayerTransformPointerDown(boardLocal);
      }
      return;
    }
    switch (tool) {
      case CanvasTool.layerAdjust:
        await _beginLayerAdjustDrag(boardLocal);
        break;
      case CanvasTool.pen:
      case CanvasTool.eraser:
        _focusNode.requestFocus();
        final bool useBackendCanvas =
            _backend.isSupported && _brushShapeSupportsBackend;
        if (!useBackendCanvas) {
          if (!_canStartBitmapStroke(pointerInsideBoard: pointerInsideBoard)) {
            return;
          }
          if (!isPointInsideSelection(boardLocal)) {
            return;
          }
          if (shiftPressed) {
            final Offset? anchor = _lastBrushLineAnchor;
            if (anchor != null) {
              if (_useCpuStrokeQueue) {
                _enqueueCpuStrokeEvent(
                  type: _CpuStrokeEventType.down,
                  boardLocal: anchor,
                  timestamp: event.timeStamp,
                  event: event,
                );
                _enqueueCpuStrokeEvent(
                  type: _CpuStrokeEventType.move,
                  boardLocal: boardLocal,
                  timestamp: event.timeStamp,
                  event: event,
                );
                _enqueueCpuStrokeEvent(
                  type: _CpuStrokeEventType.up,
                  boardLocal: boardLocal,
                  timestamp: event.timeStamp,
                  event: event,
                );
                return;
              }
              await _startStroke(anchor, event.timeStamp, event);
              _appendPoint(boardLocal, event.timeStamp, event);
              _finishStroke(event.timeStamp);
              return;
            }
          }
          if (_useCpuStrokeQueue) {
            _enqueueCpuStrokeEvent(
              type: _CpuStrokeEventType.down,
              boardLocal: boardLocal,
              timestamp: event.timeStamp,
              event: event,
            );
            return;
          }
          await _startStroke(boardLocal, event.timeStamp, event);
          return;
        }
        if (!_canStartBackendStroke(pointerInsideBoard: pointerInsideBoard)) {
          _showBackendCanvasMessage('画布后端尚未准备好。');
          return;
        }
        if (!isPointInsideSelection(boardLocal)) {
          return;
        }
        if (shiftPressed) {
          final Offset? anchor = _lastBrushLineAnchor;
          if (anchor != null &&
              _drawBackendStraightLine(
                start: anchor,
                end: boardLocal,
                event: event,
              )) {
            _lastBrushLineAnchor = _clampToCanvas(boardLocal);
            return;
          }
        }
        _beginBackendStroke(event);
        break;
      case CanvasTool.perspectivePen:
        _focusNode.requestFocus();
        if (_perspectiveMode == PerspectiveGuideMode.off ||
            !_perspectiveVisible) {
          AppNotifications.show(
            context,
            message: context.l10n.enablePerspectiveGuideFirst,
            severity: InfoBarSeverity.warning,
          );
          _clearPerspectivePenPreview();
          return;
        }
        if (!isPointInsideSelection(boardLocal)) {
          return;
        }
        if (_perspectivePenAnchor == null) {
          _setPerspectivePenAnchor(boardLocal);
          return;
        }
        _updatePerspectivePenPreview(boardLocal);
        if (!_perspectivePenPreviewValid) {
          AppNotifications.show(
            context,
            message: context.l10n.lineNotAlignedWithPerspective,
            severity: InfoBarSeverity.warning,
          );
          return;
        }
        await _commitPerspectivePenStroke(
          boardLocal,
          event.timeStamp,
          rawEvent: event,
        );
        break;
      case CanvasTool.curvePen:
        if (_isCurveCancelModifierPressed() &&
            (_curveAnchor != null || _isCurvePlacingSegment)) {
          _resetCurvePenState();
          return;
        }
        await _handleCurvePenPointerDown(boardLocal);
        break;
      case CanvasTool.shape:
        _focusNode.requestFocus();
        await _beginShapeDrawing(boardLocal);
        break;
      case CanvasTool.spray:
        _focusNode.requestFocus();
        if (!isPointInsideSelection(boardLocal)) {
          return;
        }
        await _startSprayStroke(boardLocal, event);
        break;
      case CanvasTool.bucket:
        _focusNode.requestFocus();
        if (!isPointInsideSelection(boardLocal)) {
          return;
        }
        unawaited(_applyPaintBucket(boardLocal));
        break;
      case CanvasTool.magicWand:
        _focusNode.requestFocus();
        _handleMagicWandPointerDown(boardLocal);
        break;
      case CanvasTool.eyedropper:
        _focusNode.requestFocus();
        _beginEyedropperSample(boardLocal);
        break;
      case CanvasTool.selection:
        _focusNode.requestFocus();
        _handleSelectionPointerDown(boardLocal, event.timeStamp);
        break;
      case CanvasTool.selectionPen:
        _focusNode.requestFocus();
        _handleSelectionPenPointerDown(boardLocal);
        break;
      case CanvasTool.text:
        _focusNode.requestFocus();
        if (!pointerInsideBoard) {
          return;
        }
        final CanvasLayerInfo? targetLayer = _hitTestTextLayer(boardLocal);
        if (targetLayer != null) {
          await _beginEditExistingTextLayer(targetLayer);
        } else {
          _beginNewTextSession(boardLocal);
        }
        break;
      case CanvasTool.hand:
        _beginDragBoard();
        break;
      case CanvasTool.rotate:
        _beginRotateBoard();
        break;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final bool backendStrokeActive = _backendActivePointer == event.pointer;
    if (!_isPrimaryPointer(event) && !backendStrokeActive) {
      return;
    }
    if (_isScalingGesture) {
      return;
    }
    if (_layerTransformApplying) {
      return;
    }
    _recordWorkspacePointer(event.localPosition);
    _updateToolCursorOverlay(event.localPosition);
    if (_isDraggingPerspectiveHandle) {
      final Offset boardLocal = _toBoardLocal(event.localPosition);
      _handlePerspectivePointerMove(boardLocal);
      return;
    }
    if (_layerTransformModeActive) {
      final Offset boardLocal = _toBoardLocal(event.localPosition);
      _handleLayerTransformPointerMove(boardLocal);
      return;
    }
    switch (_effectiveActiveTool) {
      case CanvasTool.pen:
      case CanvasTool.eraser:
        if (backendStrokeActive) {
          final dynamic dyn = event;
          try {
            final List<dynamic>? coalesced =
                dyn.coalescedEvents as List<dynamic>?;
            if (coalesced != null && coalesced.isNotEmpty) {
              for (final dynamic e in coalesced) {
                if (e is PointerEvent) {
                  _enqueueBackendPoint(e, _kBackendPointFlagMove);
                }
              }
              break;
            }
          } catch (_) {}
          _enqueueBackendPoint(event, _kBackendPointFlagMove);
          break;
        }
        if (_useCpuStrokeQueue) {
          final dynamic dyn = event;
          try {
            final List<dynamic>? coalesced =
                dyn.coalescedEvents as List<dynamic>?;
            if (coalesced != null && coalesced.isNotEmpty) {
              for (final dynamic e in coalesced) {
                if (e is PointerEvent) {
                  if (!e.down && !_isDrawing && _cpuStrokeQueue.isEmpty) {
                    continue;
                  }
                  final Offset boardLocal = _toBoardLocal(e.localPosition);
                  _enqueueCpuStrokeEvent(
                    type: _CpuStrokeEventType.move,
                    boardLocal: boardLocal,
                    timestamp: e.timeStamp,
                    event: e,
                  );
                }
              }
              break;
            }
          } catch (_) {}
          if (event.down || _isDrawing || _cpuStrokeQueue.isNotEmpty) {
            final Offset boardLocal = _toBoardLocal(event.localPosition);
            _enqueueCpuStrokeEvent(
              type: _CpuStrokeEventType.move,
              boardLocal: boardLocal,
              timestamp: event.timeStamp,
              event: event,
            );
          }
          break;
        }
        if (_isDrawing) {
          final Offset boardLocal = _toBoardLocal(event.localPosition);
          _appendPoint(boardLocal, event.timeStamp, event);
        }
        break;
      case CanvasTool.perspectivePen:
        if (_perspectivePenAnchor != null) {
          final Offset boardLocal = _toBoardLocal(event.localPosition);
          _updatePerspectivePenPreview(boardLocal);
        }
        break;
      case CanvasTool.layerAdjust:
        final Offset boardLocal = _toBoardLocal(event.localPosition);
        _updateLayerAdjustDrag(boardLocal);
        break;
      case CanvasTool.curvePen:
        final Offset boardLocal = _toBoardLocal(event.localPosition);
        _handleCurvePenPointerMove(boardLocal);
        break;
      case CanvasTool.shape:
        if (_shapeDragStart != null) {
          final Offset boardLocal = _toBoardLocal(event.localPosition);
          _updateShapeDrawing(boardLocal);
        }
        break;
      case CanvasTool.bucket:
      case CanvasTool.magicWand:
        break;
      case CanvasTool.eyedropper:
        final Offset boardLocal = _toBoardLocal(event.localPosition);
        _updateEyedropperSample(boardLocal);
        break;
      case CanvasTool.selection:
        final Offset boardLocal = _toBoardLocal(event.localPosition);
        _handleSelectionPointerMove(boardLocal);
        break;
      case CanvasTool.selectionPen:
        final Offset boardLocal = _toBoardLocal(event.localPosition);
        _handleSelectionPenPointerMove(boardLocal);
        break;
      case CanvasTool.hand:
        if (_isDraggingBoard) {
          _updateDragBoard(event.delta);
        }
        break;
      case CanvasTool.rotate:
        if (_isRotatingBoard) {
          _updateRotateBoard(event.delta);
        }
        break;
      case CanvasTool.spray:
        if (_isSpraying) {
          final Offset boardLocal = _toBoardLocal(event.localPosition);
          _updateSprayStroke(boardLocal, event);
        }
        break;
      case CanvasTool.text:
        break;
    }
  }

  void _handlePointerUp(PointerUpEvent event) async {
    if (_layerTransformModeActive) {
      _handleLayerTransformPointerUp();
      return;
    }
    if (_isDraggingPerspectiveHandle) {
      _handlePerspectivePointerUp();
      return;
    }
    switch (_effectiveActiveTool) {
      case CanvasTool.pen:
      case CanvasTool.eraser:
        if (_backendActivePointer == event.pointer) {
          _endBackendStroke(event);
          break;
        }
        if (_useCpuStrokeQueue) {
          final Offset boardLocal = _toBoardLocal(event.localPosition);
          _enqueueCpuStrokeEvent(
            type: _CpuStrokeEventType.up,
            boardLocal: boardLocal,
            timestamp: event.timeStamp,
            event: event,
          );
          break;
        }
        if (_isDrawing) {
          final Offset boardLocal = _toBoardLocal(event.localPosition);
          final double? releasePressure = _stylusPressureValue(event);
          if (_activeStrokeUsesStylus) {
            _appendStylusReleaseSample(
              boardLocal,
              event.timeStamp,
              releasePressure,
            );
          }
          if (_activeStrokeUsesStylus) {
            _finishStroke();
          } else {
            _finishStroke(event.timeStamp);
          }
        }
        break;
      case CanvasTool.layerAdjust:
        if (_isLayerDragging) {
          _finishLayerAdjustDrag();
        }
        break;
      case CanvasTool.curvePen:
        await _handleCurvePenPointerUp();
        break;
      case CanvasTool.shape:
        await _finishShapeDrawing();
        break;
      case CanvasTool.bucket:
      case CanvasTool.magicWand:
        break;
      case CanvasTool.eyedropper:
        _finishEyedropperSample();
        break;
      case CanvasTool.selection:
        _handleSelectionPointerUp();
        break;
      case CanvasTool.selectionPen:
        _handleSelectionPenPointerUp();
        break;
      case CanvasTool.hand:
        if (_isDraggingBoard) {
          _finishDragBoard();
        }
        break;
      case CanvasTool.rotate:
        if (_isRotatingBoard) {
          _finishRotateBoard();
        }
        break;
      case CanvasTool.spray:
        if (_isSpraying) {
          _finishSprayStroke();
        }
        break;
      case CanvasTool.text:
        break;
      case CanvasTool.perspectivePen:
        break;
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_layerTransformModeActive) {
      _handleLayerTransformPointerCancel();
      return;
    }
    if (_isDraggingPerspectiveHandle) {
      _handlePerspectivePointerUp();
      return;
    }
    switch (_effectiveActiveTool) {
      case CanvasTool.pen:
      case CanvasTool.eraser:
        if (_backendActivePointer == event.pointer) {
          _endBackendStroke(event);
          break;
        }
        if (_useCpuStrokeQueue) {
          final Offset boardLocal = _toBoardLocal(event.localPosition);
          _enqueueCpuStrokeEvent(
            type: _CpuStrokeEventType.cancel,
            boardLocal: boardLocal,
            timestamp: event.timeStamp,
            event: event,
          );
          break;
        }
        if (_isDrawing) {
          _finishStroke(event.timeStamp);
        }
        break;
      case CanvasTool.layerAdjust:
        if (_isLayerDragging) {
          _finishLayerAdjustDrag();
        }
        break;
      case CanvasTool.eyedropper:
        _cancelEyedropperSample();
        break;
      case CanvasTool.curvePen:
        _cancelCurvePenSegment();
        break;
      case CanvasTool.shape:
        _cancelShapeDrawing();
        break;
      case CanvasTool.selection:
        _handleSelectionPointerCancel();
        break;
      case CanvasTool.selectionPen:
        _handleSelectionPenPointerCancel();
        break;
      case CanvasTool.hand:
        if (_isDraggingBoard) {
          _finishDragBoard();
        }
        break;
      case CanvasTool.rotate:
        if (_isRotatingBoard) {
          _finishRotateBoard();
        }
        break;
      case CanvasTool.spray:
        if (_isSpraying) {
          _finishSprayStroke();
        }
        break;
      case CanvasTool.bucket:
      case CanvasTool.magicWand:
        break;
      case CanvasTool.text:
        break;
      case CanvasTool.perspectivePen:
        _clearPerspectivePenPreview();
        break;
    }
  }

  void _handlePointerHover(PointerHoverEvent event) {
    _recordWorkspacePointer(event.localPosition);
    _updateToolCursorOverlay(event.localPosition);
    final Offset boardLocal = _toBoardLocal(event.localPosition);
    _updatePerspectiveHover(boardLocal);
    if (_layerTransformModeActive) {
      _updateLayerTransformHover(boardLocal);
      return;
    }
    final CanvasTool tool = _effectiveActiveTool;
    if (tool == CanvasTool.perspectivePen) {
      if (_perspectivePenAnchor != null) {
        _updatePerspectivePenPreview(boardLocal);
      }
      _clearTextHoverHighlight();
      return;
    }
    if (tool == CanvasTool.selection) {
      _handleSelectionHover(boardLocal);
      return;
    }
    if (tool == CanvasTool.text) {
      if (_isTextEditingActive) {
        _clearTextHoverHighlight();
        return;
      }
      final Rect boardRect = _boardRect;
      if (!boardRect.contains(event.localPosition)) {
        _clearTextHoverHighlight();
        return;
      }
      final Offset boardLocal = _toBoardLocal(event.localPosition);
      _handleTextHover(boardLocal);
      return;
    }
    _clearTextHoverHighlight();
  }

  @override
  KeyEventResult _handleWorkspaceKeyEvent(FocusNode node, KeyEvent event) {
    if (_isTextEditingActive) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (_layerTransformModeActive) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        if (key == LogicalKeyboardKey.escape) {
          _cancelLayerFreeTransform();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) {
          unawaited(_confirmLayerFreeTransform());
          return KeyEventResult.handled;
        }
      }
    }
    if (_isAltKey(key) && _activeTool != CanvasTool.eyedropper) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        if (_eyedropperOverrideActive) {
          return KeyEventResult.handled;
        }
        _interruptForEyedropperOverride();
        final Offset? pointer = _lastWorkspacePointer;
        setState(() {
          _eyedropperOverrideActive = true;
          if (pointer != null && _boardRect.contains(pointer)) {
            _toolCursorPosition = pointer;
          }
          _penCursorWorkspacePosition = null;
        });
        _scheduleWorkspaceCardsOverlaySync();
        return KeyEventResult.handled;
      }
      if (event is KeyUpEvent) {
        if (!_eyedropperOverrideActive) {
          return KeyEventResult.handled;
        }
        _finishEyedropperSample();
        setState(() {
          _eyedropperOverrideActive = false;
          _toolCursorPosition = null;
          _penCursorWorkspacePosition = null;
        });
        final Offset? pointer = _lastWorkspacePointer;
        if (pointer != null && _boardRect.contains(pointer)) {
          _updateToolCursorOverlay(pointer);
        }
        _scheduleWorkspaceCardsOverlaySync();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (key != LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (_spacePanOverrideActive) {
        return KeyEventResult.handled;
      }
      setState(() {
        _spacePanOverrideActive = true;
        _penCursorWorkspacePosition = null;
      });
      _scheduleWorkspaceCardsOverlaySync();
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      if (!_spacePanOverrideActive) {
        return KeyEventResult.handled;
      }
      if (_isDraggingBoard) {
        _finishDragBoard();
      }
      setState(() => _spacePanOverrideActive = false);
      final Offset? pointer = _lastWorkspacePointer;
      if (pointer != null && _boardRect.contains(pointer)) {
        _updateToolCursorOverlay(pointer);
      }
      _scheduleWorkspaceCardsOverlaySync();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _applyZoom(double targetScale, Offset workspaceFocalPoint) {
    if (_workspaceSize.isEmpty) {
      return;
    }
    final double currentScale = _viewport.scale;
    final double clamped = _viewport.clampScale(targetScale);
    if ((clamped - currentScale).abs() < 0.0005) {
      return;
    }
    final Offset currentBase = _baseOffsetForScale(currentScale);
    final Offset currentOrigin = currentBase + _viewport.offset;
    final Offset boardLocal =
        (workspaceFocalPoint - currentOrigin) / currentScale;

    final Offset newBase = _baseOffsetForScale(clamped);
    final Offset newOrigin = workspaceFocalPoint - boardLocal * clamped;
    final Offset newOffset = newOrigin - newBase;

    setState(() {
      _viewport.setScale(clamped);
      _viewport.setOffset(newOffset);
    });
    _notifyViewInfoChanged();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final double scrollDelta = event.scrollDelta.dy;
    if (scrollDelta == 0) {
      return;
    }
    final Offset focalPoint = box.globalToLocal(event.position);
    const double sensitivity = 0.0015;
    final double targetScale =
        _viewport.scale * (1 - scrollDelta * sensitivity);
    _applyZoom(targetScale, focalPoint);
  }

  void _handleScaleStart(ScaleStartDetails details) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final bool shouldScale =
        details.pointerCount == 0 || details.pointerCount > 1;
    _isScalingGesture = shouldScale;
    if (!shouldScale) {
      return;
    }
    _scaleGestureInitialScale = _viewport.scale;
    final Offset focalPoint = box.globalToLocal(details.focalPoint);
    _applyZoom(_viewport.scale, focalPoint);
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (!_isScalingGesture) {
      return;
    }
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final Offset focalPoint = box.globalToLocal(details.focalPoint);
    final double targetScale = _scaleGestureInitialScale * details.scale;
    _applyZoom(targetScale, focalPoint);
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _isScalingGesture = false;
  }

  void _handleUndo() {
    if (_isTextEditingActive) {
      unawaited(_cancelTextEditingSession());
    }
    unawaited(_performUndo());
  }

  Future<void> _performUndo() async {
    if (!await undo()) {
      widget.onUndoFallback?.call();
    }
  }

  void _handleRedo() {
    if (_isTextEditingActive) {
      unawaited(_cancelTextEditingSession());
    }
    unawaited(_performRedo());
  }

  Future<void> _performRedo() async {
    if (!await redo()) {
      widget.onRedoFallback?.call();
    }
  }

  Future<bool> undo() async {
    _refreshHistoryLimit();
    if (_useCombinedHistory) {
      final _HistoryActionKind? action = _peekHistoryUndoAction();
      if (action == _HistoryActionKind.backend) {
        if (!_backend.undo()) {
          return false;
        }
        _commitHistoryUndoAction();
        _markDirty();
        setState(() {});
        return true;
      }
      if (action == _HistoryActionKind.dart) {
        if (_undoStack.isEmpty) {
          return false;
        }
        final _CanvasHistoryEntry previous = _undoStack.removeLast();
        _redoStack.add(
          await _createHistoryEntry(
            backendPixelsSynced: previous.backendPixelsSynced,
          ),
        );
        _commitHistoryUndoAction();
        _trimHistoryStacks();
        await _applyHistoryEntry(previous);
        return true;
      }
    }
    if (_undoStack.isEmpty) {
      return false;
    }
    final _CanvasHistoryEntry previous = _undoStack.removeLast();
    _redoStack.add(
      await _createHistoryEntry(backendPixelsSynced: previous.backendPixelsSynced),
    );
    _trimHistoryStacks();
    await _applyHistoryEntry(previous);
    return true;
  }

  Future<bool> redo() async {
    _refreshHistoryLimit();
    if (_useCombinedHistory) {
      final _HistoryActionKind? action = _peekHistoryRedoAction();
      if (action == _HistoryActionKind.backend) {
        if (!_backend.redo()) {
          return false;
        }
        _commitHistoryRedoAction();
        _markDirty();
        setState(() {});
        return true;
      }
      if (action == _HistoryActionKind.dart) {
        if (_redoStack.isEmpty) {
          return false;
        }
        final _CanvasHistoryEntry next = _redoStack.removeLast();
        _undoStack.add(
          await _createHistoryEntry(backendPixelsSynced: next.backendPixelsSynced),
        );
        _commitHistoryRedoAction();
        _trimHistoryStacks();
        await _applyHistoryEntry(next);
        return true;
      }
    }
    if (_redoStack.isEmpty) {
      return false;
    }
    final _CanvasHistoryEntry next = _redoStack.removeLast();
    _undoStack.add(
      await _createHistoryEntry(backendPixelsSynced: next.backendPixelsSynced),
    );
    _trimHistoryStacks();
    await _applyHistoryEntry(next);
    return true;
  }

  bool zoomIn() {
    return _zoomByFactor(_zoomStep);
  }

  bool zoomOut() {
    return _zoomByFactor(1 / _zoomStep);
  }

  bool _zoomByFactor(double factor) {
    if (_workspaceSize.isEmpty) {
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        return false;
      }
      _workspaceSize = box.size;
    }
    final Offset focalPoint = _boardRect.center;
    _applyZoom(_viewport.scale * factor, focalPoint);
    return true;
  }
}
