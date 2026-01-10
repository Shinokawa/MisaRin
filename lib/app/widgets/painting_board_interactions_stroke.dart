part of 'painting_board.dart';

extension _PaintingBoardInteractionStrokeExtension on _PaintingBoardInteractionMixin {
  void _finalizeStreamlinePostProcessing({required bool commitFinalStroke}) {
    final _StreamlinePostStroke? stroke = _streamlinePostStroke;
    if (stroke == null) {
      return;
    }
    _streamlinePostController?.stop(canceled: true);
    _streamlinePostStroke = null;
    if (commitFinalStroke) {
      unawaited(
        _controller.commitVectorStroke(
          points: stroke.toPoints,
          radii: stroke.toRadii,
          color: stroke.color,
          brushShape: stroke.shape,
          applyVectorSmoothing: false,
          erase: stroke.erase,
          antialiasLevel: stroke.antialiasLevel,
          hollow: stroke.hollowStrokeEnabled,
          hollowRatio: stroke.hollowStrokeRatio,
          eraseOccludedParts: stroke.eraseOccludedParts,
          randomRotation: stroke.randomRotationEnabled,
          rotationSeed: stroke.rotationSeed,
        ),
      );
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _updateBucketSwallowColorLine(bool value) {
    if (_bucketSwallowColorLine == value) {
      return;
    }
    setState(() => _bucketSwallowColorLine = value);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.bucketSwallowColorLine = value;
    unawaited(AppPreferences.save());
  }

  void _updateBucketSwallowColorLineMode(BucketSwallowColorLineMode mode) {
    if (_bucketSwallowColorLineMode == mode) {
      return;
    }
    setState(() => _bucketSwallowColorLineMode = mode);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.bucketSwallowColorLineMode = mode;
    unawaited(AppPreferences.save());
  }

  void _updateBucketTolerance(int value) {
    final int clamped = value.clamp(0, 255).toInt();
    if (_bucketTolerance == clamped) {
      return;
    }
    setState(() => _bucketTolerance = clamped);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.bucketTolerance = clamped;
    unawaited(AppPreferences.save());
  }

  void _updateBucketFillGap(int value) {
    final int clamped = value.clamp(0, 64).toInt();
    if (_bucketFillGap == clamped) {
      return;
    }
    setState(() => _bucketFillGap = clamped);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.bucketFillGap = clamped;
    unawaited(AppPreferences.save());
  }

  void _updateMagicWandTolerance(int value) {
    final int clamped = value.clamp(0, 255).toInt();
    if (_magicWandTolerance == clamped) {
      return;
    }
    setState(() => _magicWandTolerance = clamped);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.magicWandTolerance = clamped;
    unawaited(AppPreferences.save());
  }

  void _updateBrushToolsEraserMode(bool value) {
    if (_brushToolsEraserMode == value) {
      return;
    }
    setState(() => _brushToolsEraserMode = value);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.brushToolsEraserMode = value;
    unawaited(AppPreferences.save());
  }

  void _updateLayerAdjustCropOutside(bool value) {
    if (_layerAdjustCropOutside == value) {
      return;
    }
    setState(() => _layerAdjustCropOutside = value);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.layerAdjustCropOutside = value;
    unawaited(AppPreferences.save());
    _controller.setLayerOverflowCropping(value);
  }

  bool _isStylusEvent(PointerEvent event) {
    return TabletInputBridge.instance.isTabletPointer(event);
  }

  double? _stylusPressureValue(PointerEvent? event) {
    return TabletInputBridge.instance.pressureForEvent(event);
  }

  double? _stylusPressureBound(double? bound) {
    if (bound == null || !bound.isFinite) {
      return null;
    }
    return bound;
  }

  Future<void> _startStroke(
    Offset position,
    Duration timestamp,
    PointerEvent? rawEvent,
  ) async {
    _finalizeStreamlinePostProcessing(commitFinalStroke: true);
    _resetPerspectiveLock();
    final Offset start = _sanitizeStrokePosition(
      position,
      isInitialSample: true,
      anchor: _lastStrokeBoardPosition,
    );
    _activeStrokeUsesStylus =
        rawEvent != null && _stylusPressureEnabled && _isStylusEvent(rawEvent);
    final bool combineStylusAndSimulation =
        _simulatePenPressure && _activeStrokeUsesStylus;
    final double stylusBlend = combineStylusAndSimulation
        ? _kStylusSimulationBlend
        : 1.0;
    final double? stylusPressure = _stylusPressureValue(rawEvent);
    if (_activeStrokeUsesStylus) {
      _activeStylusPressureMin = _stylusPressureBound(rawEvent?.pressureMin);
      _activeStylusPressureMax = _stylusPressureBound(rawEvent?.pressureMax);
    } else {
      _activeStylusPressureMin = null;
      _activeStylusPressureMax = null;
    }
    final bool erase = _isBrushEraserEnabled;
    final Color strokeColor = erase ? const Color(0xFFFFFFFF) : _primaryColor;
    final bool hollow = _hollowStrokeEnabled && !erase;
    _lastStrokeBoardPosition = start;
    _lastStylusDirection = null;
    _lastStylusPressureValue = stylusPressure?.clamp(0.0, 1.0);
    _lastStylusPressureValue = stylusPressure?.clamp(0.0, 1.0);
    await _pushUndoSnapshot();
    StrokeLatencyMonitor.instance.recordStrokeStart();
    _lastPenSampleTimestamp = timestamp;
    setState(() {
      _isDrawing = true;
      _controller.beginStroke(
        start,
        color: strokeColor,
        radius: _penStrokeWidth / 2,
        simulatePressure: _simulatePenPressure,
        useDevicePressure: _activeStrokeUsesStylus,
        stylusPressureBlend: stylusBlend,
        pressure: stylusPressure,
        pressureMin: _activeStylusPressureMin,
        pressureMax: _activeStylusPressureMax,
        profile: _penPressureProfile,
        timestampMillis: timestamp.inMicroseconds / 1000.0,
        antialiasLevel: _penAntialiasLevel,
        brushShape: _brushShape,
        randomRotation: _brushRandomRotationEnabled,
        rotationSeed: _brushRandomRotationPreviewSeed,
        erase: erase,
        hollow: hollow,
        hollowRatio: _hollowStrokeRatio,
        eraseOccludedParts: _hollowStrokeEraseOccludedParts,
      );
    });
    SchedulerBinding.instance.addPostFrameCallback((_) {
      StrokeLatencyMonitor.instance.recordFramePresented();
    });
    _markDirty();
  }

  void _appendPoint(
    Offset position,
    Duration timestamp,
    PointerEvent? rawEvent,
  ) {
    if (!_isDrawing) {
      return;
    }
    final double? deltaMillis = _registerPenSample(timestamp);
    final Offset clamped = _sanitizeStrokePosition(
      position,
      anchor: _lastStrokeBoardPosition,
    );
    double? stylusPressure = _stylusPressureValue(rawEvent);
    if (_activeStrokeUsesStylus &&
        rawEvent != null &&
        _isStylusEvent(rawEvent)) {
      final double? candidateMin = _stylusPressureBound(rawEvent.pressureMin);
      final double? candidateMax = _stylusPressureBound(rawEvent.pressureMax);
      if (candidateMin != null) {
        _activeStylusPressureMin = candidateMin;
      }
      if (candidateMax != null) {
        _activeStylusPressureMax = candidateMax;
      }
    }
    final Offset? previousPoint = _lastStrokeBoardPosition;
    if (previousPoint != null) {
      final Offset delta = clamped - previousPoint;
      if (delta.distanceSquared > 1e-5) {
        _lastStylusDirection = delta / delta.distance;
      }
    }
    _lastStrokeBoardPosition = clamped;
    if (stylusPressure != null && stylusPressure.isFinite) {
      _lastStylusPressureValue = stylusPressure.clamp(0.0, 1.0);
    }
    setState(() {
      _controller.extendStroke(
        clamped,
        deltaTimeMillis: deltaMillis,
        timestampMillis: timestamp.inMicroseconds / 1000.0,
        pressure: stylusPressure,
        pressureMin: _activeStylusPressureMin,
        pressureMax: _activeStylusPressureMax,
      );
    });
  }

  void _appendStylusReleaseSample(
    Offset boardLocal,
    Duration timestamp,
    double? pressure,
  ) {
    if (!_activeStrokeUsesStylus) {
      return;
    }
    double targetPressure = (pressure ?? 0.0).clamp(0.0, 1.0);
    const double kMinPressure = 0.0001;
    if ((targetPressure <= kMinPressure || !targetPressure.isFinite) &&
        (_lastStylusPressureValue ?? 0.0) > kMinPressure) {
      targetPressure = _lastStylusPressureValue!.clamp(0.0, 1.0);
    } else if (targetPressure > kMinPressure) {
      _lastStylusPressureValue = targetPressure;
    }
    final double? deltaMillis = _registerPenSample(timestamp);
    _emitReleaseSamples(
      anchor: boardLocal,
      direction: _lastStylusDirection,
      timestampMillis: timestamp.inMicroseconds / 1000.0,
      initialDeltaMillis: deltaMillis,
      pressure: targetPressure,
      enableSharpPeak: _autoSharpPeakEnabled,
    );
    _lastStylusPressureValue = 0.0;
  }

  Future<void> _commitPerspectivePenStroke(
    Offset boardLocal,
    Duration timestamp, {
    PointerEvent? rawEvent,
  }) async {
    final Offset? anchor = _perspectivePenAnchor;
    final Offset? snapped = _perspectivePenSnappedTarget;
    if (anchor == null || snapped == null) {
      return;
    }
    await _startStroke(anchor, timestamp, rawEvent);
    _appendPoint(snapped, timestamp, rawEvent);
    _finishStroke(timestamp);
    _clearPerspectivePenPreview();
  }

  void _finishStroke([Duration? timestamp]) {
    if (!_isDrawing) {
      return;
    }
    if (timestamp != null) {
      _registerPenSample(timestamp);
    }
    _controller.endStroke();
    setState(() {
      _isDrawing = false;
      if (_brushRandomRotationEnabled) {
        _brushRandomRotationPreviewSeed = _brushRotationRandom.nextInt(1 << 31);
      }
    });
    _resetPerspectiveLock();
    _lastPenSampleTimestamp = null;
    _activeStrokeUsesStylus = false;
    _activeStylusPressureMin = null;
    _activeStylusPressureMax = null;
    _lastStylusPressureValue = null;
    _lastStrokeBoardPosition = null;
    _lastStylusDirection = null;
    _strokeStabilizer.reset();
    _streamlineStabilizer.reset();
  }

  bool _shouldApplyStreamlinePostProcessingForCurrentStroke() {
    if (!_streamlineEnabled) {
      return false;
    }
    if (_streamlineStrength <= 0.0001) {
      return false;
    }
    // StreamLine 后处理需要矢量预览路径，否则笔画在绘制过程中已经被栅格化，无法“抬笔后重算”。
    if (!_vectorDrawingEnabled) {
      return false;
    }
    return _streamlinePostController != null;
  }

  void _finishStrokeWithStreamlinePostProcessing(Duration timestamp) {
    if (!_isDrawing) {
      return;
    }

    _finalizeStreamlinePostProcessing(commitFinalStroke: true);
    _registerPenSample(timestamp);

    final List<Offset> rawPoints = List<Offset>.from(
      _controller.activeStrokePoints,
    );
    final List<double> rawRadii = List<double>.from(
      _controller.activeStrokeRadii,
    );
    final Color strokeColor = _controller.activeStrokeColor;
    final BrushShape strokeShape = _controller.activeStrokeShape;
    final bool erase = _controller.activeStrokeEraseMode;
    final int antialiasLevel = _controller.activeStrokeAntialiasLevel;
    final bool hollowStrokeEnabled = _controller.activeStrokeHollowEnabled;
    final double hollowStrokeRatio = _controller.activeStrokeHollowRatio;
    final bool eraseOccludedParts = _controller.activeStrokeEraseOccludedParts;
    final bool randomRotationEnabled =
        _controller.activeStrokeRandomRotationEnabled;
    final int rotationSeed = _controller.activeStrokeRotationSeed;

    final double strength = _streamlineStrength.clamp(0.0, 1.0);
    final _StreamlinePathData target = _buildStreamlinePostProcessTarget(
      rawPoints,
      rawRadii,
      strength,
    );
    final List<double> ratios = _strokeProgressRatios(target.points);
    final _StreamlinePathData from = _resampleStrokeAtRatios(
      rawPoints,
      rawRadii,
      ratios,
    );

    final _StreamlinePostStroke stroke = _StreamlinePostStroke(
      fromPoints: from.points,
      fromRadii: from.radii,
      toPoints: target.points,
      toRadii: target.radii,
      color: strokeColor,
      shape: strokeShape,
      erase: erase,
      antialiasLevel: antialiasLevel,
      hollowStrokeEnabled: hollowStrokeEnabled,
      hollowStrokeRatio: hollowStrokeRatio,
      eraseOccludedParts: eraseOccludedParts,
      randomRotationEnabled: randomRotationEnabled,
      rotationSeed: rotationSeed,
    );

    _controller.cancelStroke();

    final bool needsAnimation =
        _streamlineMaxDelta(from.points, target.points) >= 0.45;
    if (!needsAnimation) {
      setState(() {
        _isDrawing = false;
        if (_brushRandomRotationEnabled) {
          _brushRandomRotationPreviewSeed =
              _brushRotationRandom.nextInt(1 << 31);
        }
      });
      _resetPerspectiveLock();
      _lastPenSampleTimestamp = null;
      _activeStrokeUsesStylus = false;
      _activeStylusPressureMin = null;
      _activeStylusPressureMax = null;
      _lastStylusPressureValue = null;
      _lastStrokeBoardPosition = null;
      _lastStylusDirection = null;
      _strokeStabilizer.reset();
      _streamlineStabilizer.reset();
      unawaited(
        _controller.commitVectorStroke(
          points: stroke.toPoints,
          radii: stroke.toRadii,
          color: stroke.color,
          brushShape: stroke.shape,
          applyVectorSmoothing: false,
          erase: stroke.erase,
          antialiasLevel: stroke.antialiasLevel,
          hollow: stroke.hollowStrokeEnabled,
          hollowRatio: stroke.hollowStrokeRatio,
          eraseOccludedParts: stroke.eraseOccludedParts,
          randomRotation: stroke.randomRotationEnabled,
          rotationSeed: stroke.rotationSeed,
        ),
      );
      return;
    }

    setState(() {
      _isDrawing = false;
      if (_brushRandomRotationEnabled) {
        _brushRandomRotationPreviewSeed =
            _brushRotationRandom.nextInt(1 << 31);
      }
      _streamlinePostStroke = stroke;
    });
    _resetPerspectiveLock();
    _lastPenSampleTimestamp = null;
    _activeStrokeUsesStylus = false;
    _activeStylusPressureMin = null;
    _activeStylusPressureMax = null;
    _lastStylusPressureValue = null;
    _lastStrokeBoardPosition = null;
    _lastStylusDirection = null;
    _strokeStabilizer.reset();
    _streamlineStabilizer.reset();

    final AnimationController? controller = _streamlinePostController;
    if (controller == null) {
      _streamlinePostStroke = null;
      unawaited(
        _controller.commitVectorStroke(
          points: stroke.toPoints,
          radii: stroke.toRadii,
          color: stroke.color,
          brushShape: stroke.shape,
          applyVectorSmoothing: false,
          erase: stroke.erase,
          antialiasLevel: stroke.antialiasLevel,
          hollow: stroke.hollowStrokeEnabled,
          hollowRatio: stroke.hollowStrokeRatio,
          eraseOccludedParts: stroke.eraseOccludedParts,
          randomRotation: stroke.randomRotationEnabled,
          rotationSeed: stroke.rotationSeed,
        ),
      );
      setState(() {});
      return;
    }

    controller
      ..stop(canceled: true)
      ..value = 0.0
      ..duration = _streamlinePostDurationForStrength(strength);
    unawaited(controller.forward(from: 0.0));
  }

  double _resolveSprayPressure(PointerEvent? event) {
    final double? stylusPressure = _stylusPressureValue(event);
    if (stylusPressure == null || !stylusPressure.isFinite) {
      return 1.0;
    }
    return stylusPressure.clamp(0.0, 1.0);
  }

  /// Builds a Krita-style spray configuration using the current stroke width
  /// and anti-alias settings. This mirrors Krita's spray brush defaults
  /// (`plugins/paintops/spray`) but tweaks a few constants so the Flutter
  /// rasterizer produces similar densities.
  KritaSprayEngineSettings _buildKritaSpraySettings() {
    final double clampedDiameter = _sprayStrokeWidth.clamp(
      kSprayStrokeMin,
      kSprayStrokeMax,
    );
    return KritaSprayEngineSettings(
      diameter: clampedDiameter,
      scale: 1.0,
      aspectRatio: 1.0,
      rotation: 0.0,
      jitterMovement: true,
      jitterAmount: 0.2,
      radialDistribution: KritaRadialDistributionType.gaussian,
      radialCenterBiased: true,
      gaussianSigma: 0.35,
      particleMultiplier: 1.0,
      randomSize: true,
      minParticleScale: 0.014,
      maxParticleScale: 0.086,
      baseParticleScale: 0.05,
      minParticleRadius: 0.32,
      minParticleOpacity: 1.0,
      maxParticleOpacity: 1.0,
      sampleInputColor: false,
      sampleBlend: 0.5,
      shape: BrushShape.circle,
      minAntialiasLevel: _penAntialiasLevel.clamp(0, 3),
    );
  }

  KritaSprayEngine _ensureKritaSprayEngine() {
    final KritaSprayEngine engine = _kritaSprayEngine ??= KritaSprayEngine(
      controller: _controller,
      clampToCanvas: (offset) => offset,
      random: _syntheticStrokeRandom,
    );
    engine.updateSettings(_buildKritaSpraySettings());
    return engine;
  }

  void _ensureSprayTicker() {
    if (_sprayTicker != null) {
      return;
    }
    _sprayTicker = createTicker(_handleSprayTick);
  }

  Future<void> _startSprayStroke(Offset boardLocal, PointerEvent event) async {
    if (!isPointInsideSelection(boardLocal)) {
      return;
    }
    _focusNode.requestFocus();
    await _pushUndoSnapshot();
    _sprayBoardPosition = boardLocal;
    _sprayCurrentPressure = _resolveSprayPressure(event);
    _sprayEmissionAccumulator = 0.0;
    _sprayTickerTimestamp = null;
    _activeSprayColor = _isBrushEraserEnabled
        ? const Color(0xFFFFFFFF)
        : _primaryColor;
    if (_sprayMode == SprayMode.smudge) {
      _softSprayLastPoint = boardLocal;
      _softSprayResidual = 0.0;
      _stampSoftSpray(
        boardLocal,
        _resolveSoftSprayRadius(),
        _sprayCurrentPressure,
      );
      _markDirty();
    } else {
      _ensureKritaSprayEngine();
      _ensureSprayTicker();
      _sprayTicker?.start();
    }
    setState(() {
      _isSpraying = true;
    });
  }

  void _updateSprayStroke(Offset boardLocal, PointerEvent event) {
    if (!_isSpraying) {
      return;
    }
    _sprayBoardPosition = boardLocal;
    _sprayCurrentPressure = _resolveSprayPressure(event);
    if (_sprayMode == SprayMode.smudge) {
      _extendSoftSprayStroke(boardLocal);
    }
  }

  void _finishSprayStroke() {
    if (!_isSpraying) {
      return;
    }
    _sprayTicker?.stop();
    setState(() {
      _isSpraying = false;
    });
    _sprayBoardPosition = null;
    _kritaSprayEngine = null;
    _activeSprayColor = null;
    _sprayTickerTimestamp = null;
    _sprayEmissionAccumulator = 0.0;
    _softSprayLastPoint = null;
    _softSprayResidual = 0.0;
  }
}
