part of 'painting_board.dart';

abstract class _PaintingBoardBaseCore extends State<PaintingBoard> {
  late BitmapCanvasController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _boardReadyNotified = false;

  CanvasTool _activeTool = CanvasTool.pen;
  bool _isDrawing = false;
  bool _isDraggingBoard = false;
  bool _isRotatingBoard = false;
  bool _isDirty = false;
  bool _isScalingGesture = false;
  bool _pixelGridVisible = false;
  bool _viewBlackWhiteOverlay = false;
  bool _viewMirrorOverlay = false;
  double _scaleGestureInitialScale = 1.0;
  double _penStrokeWidth = _defaultPenStrokeWidth;
  double _sprayStrokeWidth = _defaultSprayStrokeWidth;
  SprayMode _sprayMode = AppPreferences.defaultSprayMode;
  double _strokeStabilizerStrength =
      AppPreferences.defaultStrokeStabilizerStrength;
  bool _streamlineEnabled = AppPreferences.defaultStreamlineEnabled;
  double _streamlineStrength = AppPreferences.defaultStreamlineStrength;
  bool _simulatePenPressure = false;
  int _penAntialiasLevel = AppPreferences.defaultPenAntialiasLevel;
  int _bucketAntialiasLevel = AppPreferences.defaultBucketAntialiasLevel;
  bool _stylusPressureEnabled = AppPreferences.defaultStylusPressureEnabled;
  double _stylusCurve = AppPreferences.defaultStylusCurve;
  bool _autoSharpPeakEnabled = AppPreferences.defaultAutoSharpPeakEnabled;
  bool _vectorDrawingEnabled = AppPreferences.defaultVectorDrawingEnabled;
  BrushShape _brushShape = AppPreferences.defaultBrushShape;
  bool _brushRandomRotationEnabled =
      AppPreferences.defaultBrushRandomRotationEnabled;
  final math.Random _brushRotationRandom = math.Random();
  int _brushRandomRotationPreviewSeed = 0;
  bool _hollowStrokeEnabled = AppPreferences.defaultHollowStrokeEnabled;
  double _hollowStrokeRatio = AppPreferences.defaultHollowStrokeRatio;
  bool _hollowStrokeEraseOccludedParts =
      AppPreferences.defaultHollowStrokeEraseOccludedParts;
  PenStrokeSliderRange _penStrokeSliderRange =
      AppPreferences.defaultPenStrokeSliderRange;
  bool _bucketSampleAllLayers = false;
  bool _bucketContiguous = true;
  bool _bucketSwallowColorLine = AppPreferences.defaultBucketSwallowColorLine;
  BucketSwallowColorLineMode _bucketSwallowColorLineMode =
      AppPreferences.defaultBucketSwallowColorLineMode;
  int _bucketTolerance = AppPreferences.defaultBucketTolerance;
  int _bucketFillGap = AppPreferences.defaultBucketFillGap;
  int _magicWandTolerance = AppPreferences.defaultMagicWandTolerance;
  bool _brushToolsEraserMode = AppPreferences.defaultBrushToolsEraserMode;
  bool _shapeFillEnabled = AppPreferences.defaultShapeToolFillEnabled;
  bool _layerAdjustCropOutside = false;
  bool _layerOpacityGestureActive = false;
  String? _layerOpacityGestureLayerId;
  double? _layerOpacityUndoOriginalValue;
  String? _layerOpacityPreviewLayerId;
  double? _layerOpacityPreviewValue;
  bool _layerOpacityPreviewActive = false;
  int _layerOpacityPreviewRequestId = 0;
  int? _layerOpacityPreviewAwaitedGeneration;
  int? _layerOpacityPreviewCapturedSignature;
  bool _layerOpacityPreviewHasVisibleLowerLayers = false;
  ui.Image? _layerOpacityPreviewBackground;
  ui.Image? _layerOpacityPreviewActiveLayerImage;
  ui.Image? _layerOpacityPreviewForeground;
  final Map<String, _LayerPreviewCacheEntry> _layerPreviewCache =
      <String, _LayerPreviewCacheEntry>{};
  int _layerPreviewRequestSerial = 0;
  bool _spacePanOverrideActive = false;
  bool _isLayerDragging = false;
  Future<void>? _layerAdjustFinalizeTask;
  Offset? _layerDragStart;
  int _layerDragAppliedDx = 0;
  int _layerDragAppliedDy = 0;
  final math.Random _syntheticStrokeRandom = math.Random();
  Offset? _curveAnchor;
  Offset? _curvePendingEnd;
  Offset? _curveDragOrigin;
  Offset _curveDragDelta = Offset.zero;
  bool _isCurvePlacingSegment = false;
  Path? _curvePreviewPath;
  CanvasLayerData? _curveRasterPreviewSnapshot;
  bool _curveUndoCapturedForPreview = false;
  Rect? _curvePreviewDirtyRect;
  Uint32List? _curveRasterPreviewPixels;
  bool _isEyedropperSampling = false;
  bool _eyedropperOverrideActive = false;
  Offset? _lastEyedropperSample;
  Offset? _toolCursorPosition;
  Offset? _lastWorkspacePointer;
  Offset? _penCursorWorkspacePosition;
  Duration? _lastPenSampleTimestamp;
  bool _activeStrokeUsesStylus = false;
  double? _activeStylusPressureMin;
  double? _activeStylusPressureMax;
  double? _lastStylusPressureValue;
  Offset? _lastStrokeBoardPosition;
  Offset? _lastStylusDirection;
  final _StrokeStabilizer _strokeStabilizer = _StrokeStabilizer();
  final _StreamlineStabilizer _streamlineStabilizer = _StreamlineStabilizer();
  bool _isSpraying = false;
  Offset? _sprayBoardPosition;
  Ticker? _sprayTicker;
  Duration? _sprayTickerTimestamp;
  double _sprayEmissionAccumulator = 0.0;
  double _sprayCurrentPressure = 1.0;
  KritaSprayEngine? _kritaSprayEngine;
  Color? _activeSprayColor;
  Offset? _softSprayLastPoint;
  double _softSprayResidual = 0.0;
  Size _toolSettingsCardSize = const Size(320, _toolbarButtonSize);
  CanvasToolbarLayout _toolbarLayout = const CanvasToolbarLayout(
    columns: 1,
    rows: CanvasToolbar.buttonCount,
    width: CanvasToolbar.buttonSize,
    height:
        CanvasToolbar.buttonSize * CanvasToolbar.buttonCount +
        CanvasToolbar.spacing * (CanvasToolbar.buttonCount - 1),
  );
  List<Rect> _toolbarHitRegions = const <Rect>[];
  BoardLayoutWorker? _layoutWorker;
  BoardLayoutMetrics? _layoutMetrics;
  Future<BoardLayoutMetrics>? _pendingLayoutTask;

  final CanvasViewport _viewport = CanvasViewport();
  bool _viewportInitialized = false;
  Size _workspaceSize = Size.zero;
  Offset _layoutBaseOffset = Offset.zero;
  bool _workspaceMeasurementScheduled = false;
  final ScrollController _layerScrollController = ScrollController();
  late final ValueNotifier<CanvasViewInfo> _viewInfoNotifier;
  bool _viewInfoNotificationScheduled = false;
  CanvasViewInfo? _pendingViewInfo;
  Color _primaryColor = AppPreferences.defaultPrimaryColor;
  late HSVColor _primaryHsv;

  /// 颜色更新后由颜色面板调用的钩子，子类/混入可以覆写以响应颜色变化。
  @protected
  void _handlePrimaryColorChanged() {}
  @protected
  void _handleTextStrokeColorChanged(Color color) {}
  final List<Color> _recentColors = <Color>[];
  Color _colorLineColor = AppPreferences.defaultColorLineColor;
  final List<_CanvasHistoryEntry> _undoStack = <_CanvasHistoryEntry>[];
  final List<_CanvasHistoryEntry> _redoStack = <_CanvasHistoryEntry>[];
  bool _historyLocked = false;
  int _historyLimit = AppPreferences.instance.historyLimit;
  final List<_PaletteCardEntry> _paletteCards = <_PaletteCardEntry>[];
  int _paletteCardSerial = 0;
  bool _referenceCardResizeInProgress = false;
  double? _floatingColorPanelHeight;
  double? _floatingColorPanelMeasuredHeight;
  double? _sai2ColorPanelHeight;
  double? _sai2ColorPanelMeasuredHeight;
  double _sai2ToolSectionRatio = AppPreferences.defaultSai2ToolPanelSplit;
  double _sai2LayerPanelWidthRatio = AppPreferences.defaultSai2LayerPanelSplit;

  Future<bool> insertImageLayerFromBytes(Uint8List bytes, {String? name});

  bool get _includeHistoryOnToolbar => false;

  int get _toolbarButtonCount =>
      CanvasToolbar.buttonCount +
      (_includeHistoryOnToolbar ? CanvasToolbar.historyButtonCount : 0);

  bool _isInsidePaletteCardArea(Offset workspacePosition) {
    for (final _PaletteCardEntry entry in _paletteCards) {
      final Size size = entry.size ?? const Size(_paletteCardWidth, 180.0);
      final Rect rect = Rect.fromLTWH(
        entry.offset.dx,
        entry.offset.dy,
        size.width,
        size.height,
      );
      if (rect.contains(workspacePosition)) {
        return true;
      }
    }
    return false;
  }

  bool _isInsideReferenceCardArea(Offset workspacePosition);

  bool _isInsideReferenceModelCardArea(Offset workspacePosition);

  bool _isInsideAntialiasCardArea(Offset workspacePosition);

  bool _isInsideColorRangeCardArea(Offset workspacePosition);

  bool _isInsideWorkspacePanelArea(Offset workspacePosition) {
    return _isInsidePaletteCardArea(workspacePosition) ||
        _isInsideReferenceCardArea(workspacePosition) ||
        _isInsideReferenceModelCardArea(workspacePosition) ||
        _isInsideAntialiasCardArea(workspacePosition) ||
        _isInsideColorRangeCardArea(workspacePosition);
  }

  // 透视辅助线相关成员由 _PaintingBoardPerspectiveMixin 提供。
  PerspectiveGuideMode get _perspectiveMode;
  bool get _perspectiveEnabled;
  bool get _perspectiveVisible;
  double get _perspectiveHorizonY;
  Offset get _perspectiveVp1;
  Offset? get _perspectiveVp2;
  Offset? get _perspectiveVp3;
  double get _perspectiveSnapAngleTolerance;
  _PerspectiveHandle? get _activePerspectiveHandle;
  _PerspectiveHandle? get _hoveringPerspectiveHandle;
  void togglePerspectiveGuide();
  void setPerspectiveMode(PerspectiveGuideMode mode);
  void _resetPerspectiveLock();
  void _updatePerspectiveHover(Offset boardLocal);
  void _clearPerspectiveHover();
  Offset _maybeSnapToPerspective(Offset position, {Offset? anchor});
  bool _handlePerspectivePointerDown(
    Offset boardLocal, {
    bool allowNearest = false,
  });
  bool get _isDraggingPerspectiveHandle;
  void _handlePerspectivePointerMove(Offset boardLocal);
  void _handlePerspectivePointerUp();

  void _clearLayerTransformCursorIndicator() {}

  Size get _canvasSize => widget.settings.size;

  Size get _scaledBoardSize => Size(
    _canvasSize.width * _viewport.scale,
    _canvasSize.height * _viewport.scale,
  );

  Color get _pixelGridColor => const ui.Color.fromARGB(255, 133, 133, 133);

  bool _isWithinCanvasBounds(Offset position) {
    final Size size = _canvasSize;
    return position.dx >= 0 &&
        position.dy >= 0 &&
        position.dx <= size.width &&
        position.dy <= size.height;
  }

  Offset _clampToCanvas(Offset value) {
    final Size size = _canvasSize;
    final double dx = value.dx.clamp(0.0, size.width);
    final double dy = value.dy.clamp(0.0, size.height);
    return Offset(dx, dy);
  }

  void _applyStylusSettingsToController() {
    _controller.configureStylusPressure(
      enabled: _stylusPressureEnabled,
      curve: _stylusCurve,
    );
    _controller.configureSharpTips(enabled: _autoSharpPeakEnabled);
  }

  List<_SyntheticStrokeSample> _buildSyntheticStrokeSamples(
    List<Offset> points,
    Offset initialPoint,
  ) {
    if (points.isEmpty) {
      return const <_SyntheticStrokeSample>[];
    }
    final List<_SyntheticStrokeSample> pending = <_SyntheticStrokeSample>[];
    double totalDistance = 0.0;
    Offset previous = initialPoint;
    for (final Offset point in points) {
      final double distance = (point - previous).distance;
      if (distance < 0.001) {
        previous = point;
        continue;
      }
      pending.add(
        _SyntheticStrokeSample(point: point, distance: distance, progress: 0.0),
      );
      totalDistance += distance;
      previous = point;
    }
    if (pending.isEmpty) {
      return const <_SyntheticStrokeSample>[];
    }
    if (totalDistance <= 0.0001) {
      final int count = pending.length;
      for (int i = 0; i < count; i++) {
        final _SyntheticStrokeSample sample = pending[i];
        pending[i] = _SyntheticStrokeSample(
          point: sample.point,
          distance: sample.distance,
          progress: (i + 1) / count,
        );
      }
      return pending;
    }
    double cumulative = 0.0;
    for (int i = 0; i < pending.length; i++) {
      final _SyntheticStrokeSample sample = pending[i];
      cumulative += sample.distance;
      pending[i] = _SyntheticStrokeSample(
        point: sample.point,
        distance: sample.distance,
        progress: (cumulative / totalDistance).clamp(0.0, 1.0),
      );
    }
    return pending;
  }

  void _simulateStrokeWithSyntheticTimeline(
    List<_SyntheticStrokeSample> samples, {
    required double totalDistance,
    required double initialTimestamp,
    _SyntheticStrokeTimelineStyle style = _SyntheticStrokeTimelineStyle.natural,
  }) {
    if (samples.isEmpty) {
      return;
    }
    final bool useFastCurveStyle =
        style == _SyntheticStrokeTimelineStyle.fastCurve;
    final double effectiveDistance = totalDistance > 0.0001
        ? totalDistance
        : samples.length.toDouble();
    double targetDuration = _syntheticStrokeTargetDuration(
      effectiveDistance,
    ).clamp(160.0, 720.0);
    if (useFastCurveStyle) {
      targetDuration *= 0.62;
    }
    final double durationJitter =
        ui.lerpDouble(0.85, 1.25, _syntheticStrokeRandom.nextDouble()) ?? 1.0;
    targetDuration *= durationJitter;
    final double minimumTimeline = samples.length * _syntheticStrokeMinDeltaMs;
    final double resolvedDuration = math.max(targetDuration, minimumTimeline);
    final List<double> weights = <double>[];
    double totalWeight = 0.0;
    for (final _SyntheticStrokeSample sample in samples) {
      final double baseSpeed = _syntheticStrokeSpeedFactor(
        sample.progress,
        _penPressureProfile,
      );
      final double styleScale = _syntheticTimelineSpeedScale(
        sample.progress,
        style,
      );
      final double speed = math.max(baseSpeed * styleScale, 0.05);
      final double jitter =
          ui.lerpDouble(0.82, 1.24, _syntheticStrokeRandom.nextDouble()) ?? 1.0;
      final double normalizedDistance = math.max(sample.distance, 0.02) / speed;
      final double weight = math.max(0.001, normalizedDistance * jitter);
      weights.add(weight);
      totalWeight += weight;
    }
    if (totalWeight <= 0.0001) {
      totalWeight = samples.length.toDouble();
      for (int i = 0; i < weights.length; i++) {
        weights[i] = 1.0;
      }
    }
    final double scale = resolvedDuration / totalWeight;
    double timestamp = initialTimestamp;
    for (int i = 0; i < samples.length; i++) {
      final double deltaTime = math.max(
        _syntheticStrokeMinDeltaMs,
        weights[i] * scale,
      );
      timestamp += deltaTime;
      _controller.extendStroke(
        samples[i].point,
        deltaTimeMillis: deltaTime,
        timestampMillis: timestamp,
      );
    }
  }

  double _syntheticStrokeTotalDistance(List<_SyntheticStrokeSample> samples) {
    double total = 0.0;
    for (final _SyntheticStrokeSample sample in samples) {
      total += sample.distance;
    }
    return total;
  }

  /// Adds an optional speed bias so synthetic strokes can mimic a faster
  /// flick, which emphasises the contrast between slow and fast segments.
  double _syntheticTimelineSpeedScale(
    double progress,
    _SyntheticStrokeTimelineStyle style,
  ) {
    if (style == _SyntheticStrokeTimelineStyle.natural) {
      return 1.0;
    }
    final double normalized = progress.clamp(0.0, 1.0);
    final double sine = math.sin(normalized * math.pi).abs();
    final double eased = math.pow(sine, 0.78).toDouble().clamp(0.0, 1.0);
    final double scale = ui.lerpDouble(0.24, 4.25, eased) ?? 1.0;
    return scale.clamp(0.24, 4.25);
  }

  double _syntheticStrokeTargetDuration(double totalDistance) {
    final double normalized = (totalDistance / 320.0).clamp(0.0, 1.0);
    return ui.lerpDouble(200.0, 500.0, normalized) ?? 320.0;
  }

  double _syntheticStrokeSpeedFactor(
    double progress,
    StrokePressureProfile profile,
  ) {
    final double normalized = progress.clamp(0.0, 1.0);
    final double fromCenter = (normalized - 0.5).abs() * 2.0;
    switch (profile) {
      case StrokePressureProfile.taperEnds:
        return ui.lerpDouble(2.8, 0.38, fromCenter) ?? 1.0;
      case StrokePressureProfile.taperCenter:
        return ui.lerpDouble(0.42, 2.6, fromCenter) ?? 1.0;
      case StrokePressureProfile.auto:
        final double sine = math.sin(normalized * math.pi).abs();
        final double blend = ui.lerpDouble(1.8, 0.55, sine) ?? 1.0;
        final double edgeBias = ui.lerpDouble(1.1, 0.75, fromCenter) ?? 1.0;
        return blend * edgeBias;
    }
  }

  List<Offset> _densifyStrokePolyline(
    List<Offset> points, {
    double maxSegmentLength = 6.0,
  }) {
    if (points.length < 2) {
      return List<Offset>.from(points);
    }
    final double spacing = maxSegmentLength.clamp(0.8, 24.0);
    final List<Offset> dense = <Offset>[points.first];
    for (int i = 1; i < points.length; i++) {
      final Offset from = dense.last;
      final Offset to = points[i];
      final double segmentLength = (to - from).distance;
      if (segmentLength <= spacing + 1e-3) {
        dense.add(to);
        continue;
      }
      final int segments = math.max(1, (segmentLength / spacing).ceil());
      for (int s = 1; s <= segments; s++) {
        final double t = s / segments;
        final double x = ui.lerpDouble(from.dx, to.dx, t) ?? to.dx;
        final double y = ui.lerpDouble(from.dy, to.dy, t) ?? to.dy;
        dense.add(Offset(x, y));
      }
    }
    return dense;
  }

  void _refreshStylusPreferencesIfNeeded() {
    final AppPreferences prefs = AppPreferences.instance;
    const double epsilon = 0.0001;
    final bool needsUpdate =
        _stylusPressureEnabled != prefs.stylusPressureEnabled ||
        (_stylusCurve - prefs.stylusPressureCurve).abs() > epsilon;
    if (!needsUpdate) {
      return;
    }
    _stylusPressureEnabled = prefs.stylusPressureEnabled;
    _stylusCurve = prefs.stylusPressureCurve;
    if (mounted) {
      _applyStylusSettingsToController();
    }
  }

  Offset _baseOffsetForScale(double scale) {
    final Size workspace = _workspaceSize;
    if (workspace.width <= 0 ||
        workspace.height <= 0 ||
        !workspace.width.isFinite ||
        !workspace.height.isFinite) {
      return Offset.zero;
    }

    final double scaledWidth = _canvasSize.width * scale;
    final double scaledHeight = _canvasSize.height * scale;

    final double rawLeft = (workspace.width - scaledWidth) / 2;
    final double rawTop = (workspace.height - scaledHeight) / 2;

    final double left = rawLeft.isFinite ? rawLeft : 0.0;
    final double top = rawTop.isFinite ? rawTop : 0.0;

    return Offset(left, top);
  }

  void _updateToolSettingsCardSize(Size size) {
    final double width = size.width.isFinite && size.width > 0
        ? size.width
        : _toolSettingsCardSize.width;
    final double height = size.height.isFinite && size.height > 0
        ? size.height
        : _toolSettingsCardSize.height;
    if ((width - _toolSettingsCardSize.width).abs() < 0.5 &&
        (height - _toolSettingsCardSize.height).abs() < 0.5) {
      return;
    }
    _toolSettingsCardSize = Size(width, height);
  }

  void _scheduleWorkspaceMeasurement(BuildContext context) {
    if (_workspaceMeasurementScheduled) {
      return;
    }
    _workspaceMeasurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _workspaceMeasurementScheduled = false;
      if (!mounted) {
        return;
      }
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        return;
      }
      final Size size = box.size;
      if (size.width <= 0 ||
          size.height <= 0 ||
          !size.width.isFinite ||
          !size.height.isFinite) {
        return;
      }
      final bool widthChanged = (size.width - _workspaceSize.width).abs() > 0.5;
      final bool heightChanged =
          (size.height - _workspaceSize.height).abs() > 0.5;
      if (!widthChanged && !heightChanged) {
        return;
      }
      setState(() {
        _workspaceSize = size;
        final double reservedColorSpace =
            _colorIndicatorSize + CanvasToolbar.spacing;
        _toolbarLayout = CanvasToolbar.layoutForAvailableHeight(
          _workspaceSize.height - _toolButtonPadding * 2 - reservedColorSpace,
          toolCount: _toolbarButtonCount,
        );
        _layoutMetrics = null;
        if (!_viewportInitialized) {
          // 仍需初始化视口，下一帧会根据新尺寸完成初始化
        }
        _scheduleLayoutMetricsUpdate();
      });
    });
  }

  BoardLayoutWorker _layoutWorkerInstance() {
    return _layoutWorker ??= BoardLayoutWorker();
  }

  void _scheduleLayoutMetricsUpdate() {
    if (!mounted) {
      return;
    }
    final BoardLayoutInput input = BoardLayoutInput(
      workspaceWidth: _workspaceSize.width,
      workspaceHeight: _workspaceSize.height,
      toolButtonPadding: _toolButtonPadding,
      toolSettingsSpacing: _toolSettingsSpacing,
      sidePanelWidth: _sidePanelWidth,
      colorIndicatorSize: _colorIndicatorSize,
      toolbarButtonCount: _toolbarButtonCount,
    );
    final Future<BoardLayoutMetrics> task = _layoutWorkerInstance().compute(
      input,
    );
    _pendingLayoutTask = task;
    task
        .then((BoardLayoutMetrics metrics) {
          if (!mounted || _pendingLayoutTask != task) {
            return;
          }
          setState(() {
            _layoutMetrics = metrics;
            _toolbarLayout = metrics.layout;
          });
        })
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('Layout worker failed: $error');
        });
  }

  void _applyToolbarLayout(CanvasToolbarLayout layout) {
    if (_toolbarLayout.columns == layout.columns &&
        (_toolbarLayout.height - layout.height).abs() < 0.5 &&
        (_toolbarLayout.width - layout.width).abs() < 0.5) {
      return;
    }
    setState(() {
      _toolbarLayout = layout;
      _layoutMetrics = null;
      _scheduleLayoutMetricsUpdate();
    });
  }

  void _ensureToolbarDoesNotOverlapColorIndicator() {
    if (_toolbarHitRegions.length < 3) {
      return;
    }
    final Rect toolbarRect = _toolbarHitRegions[0];
    final Rect colorRect = _toolbarHitRegions[2];
    final double gap = colorRect.top - toolbarRect.bottom;
    final double fullAvailableHeight =
        _workspaceSize.height - _toolButtonPadding * 2 - _colorIndicatorSize;
    final double safeAvailableHeight =
        fullAvailableHeight - CanvasToolbar.spacing;
    if (!safeAvailableHeight.isFinite || safeAvailableHeight <= 0) {
      return;
    }
    if (gap >= CanvasToolbar.spacing) {
      if (_toolbarLayout.isMultiColumn) {
        final CanvasToolbarLayout candidate =
            CanvasToolbar.layoutForAvailableHeight(
              safeAvailableHeight,
              toolCount: _toolbarButtonCount,
            );
        if (candidate.columns == 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            _applyToolbarLayout(candidate);
          });
        }
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final CanvasToolbarLayout wrappedLayout =
          CanvasToolbar.layoutForAvailableHeight(
            safeAvailableHeight,
            toolCount: _toolbarButtonCount,
          );
      _applyToolbarLayout(wrappedLayout);
    });
  }

  CanvasToolbarLayout _resolveToolbarLayoutForStyle(
    PaintingToolbarLayoutStyle style,
    CanvasToolbarLayout base, {
    required bool includeHistoryButtons,
  }) {
    if (style != PaintingToolbarLayoutStyle.sai2) {
      return base;
    }
    const int targetColumns = 4;
    final double availableWidth = math.max(0, _sidePanelWidth - 32);
    final double totalSpacing = CanvasToolbar.spacing * (targetColumns - 1);
    final double maxExtent = targetColumns > 0
        ? (availableWidth - totalSpacing) / targetColumns
        : CanvasToolbar.buttonSize;
    final double buttonExtent = maxExtent.isFinite && maxExtent > 0
        ? maxExtent.clamp(36.0, CanvasToolbar.buttonSize)
        : CanvasToolbar.buttonSize;
    final int toolCount =
        CanvasToolbar.buttonCount +
        (includeHistoryButtons ? CanvasToolbar.historyButtonCount : 0);
    final int rows = math.max(1, (toolCount / targetColumns).ceil());
    final double width = targetColumns * buttonExtent + totalSpacing;
    final double height =
        rows * buttonExtent + (rows - 1) * CanvasToolbar.spacing;
    return CanvasToolbarLayout(
      columns: targetColumns,
      rows: rows,
      width: width,
      height: height,
      buttonExtent: buttonExtent,
      horizontalFlow: true,
      flowDirection: Axis.horizontal,
    );
  }

  Rect get _boardRect {
    final Offset position = _layoutBaseOffset + _viewport.offset;
    final Size size = _scaledBoardSize;
    return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
  }

  Offset _toBoardLocal(Offset workspacePosition) {
    final Rect boardRect = _boardRect;
    final double rotation = _viewport.rotation;
    Offset relative = workspacePosition - boardRect.topLeft;

    if (rotation != 0) {
      final Offset center = boardRect.size.center(Offset.zero);
      final double dx = relative.dx - center.dx;
      final double dy = relative.dy - center.dy;
      final double cosA = math.cos(-rotation);
      final double sinA = math.sin(-rotation);

      final double rotatedDx = dx * cosA - dy * sinA;
      final double rotatedDy = dx * sinA + dy * cosA;

      relative = Offset(rotatedDx + center.dx, rotatedDy + center.dy);
    }
    return relative / _viewport.scale;
  }

  Offset? _boardCursorPosition() {
    final Offset? workspacePointer = _lastWorkspacePointer;
    if (workspacePointer == null) {
      return null;
    }
    final Rect boardRect = _boardRect;
    if (!boardRect.contains(workspacePointer)) {
      return null;
    }
    return _toBoardLocal(workspacePointer);
  }

  CanvasViewInfo _buildViewInfo() {
    return CanvasViewInfo(
      canvasSize: _canvasSize,
      scale: _viewport.scale,
      cursorPosition: _boardCursorPosition(),
      pixelGridVisible: _pixelGridVisible,
      viewBlackWhiteEnabled: _viewBlackWhiteOverlay,
      viewMirrorEnabled: _viewMirrorOverlay,
      perspectiveMode: _perspectiveMode,
      perspectiveEnabled: _perspectiveEnabled,
      perspectiveVisible: _perspectiveVisible,
    );
  }

  void _notifyViewInfoChanged() {
    final CanvasViewInfo next = _buildViewInfo();
    if (_viewInfoNotifier.value == next) {
      return;
    }
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    final bool safeToUpdateNow =
        phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks;
    if (safeToUpdateNow) {
      _viewInfoNotifier.value = next;
      _pendingViewInfo = null;
      return;
    }
    _pendingViewInfo = next;
    if (_viewInfoNotificationScheduled) {
      return;
    }
    _viewInfoNotificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewInfoNotificationScheduled = false;
      if (!mounted) {
        _pendingViewInfo = null;
        return;
      }
      final CanvasViewInfo? pending = _pendingViewInfo;
      _pendingViewInfo = null;
      if (pending != null && _viewInfoNotifier.value != pending) {
        _viewInfoNotifier.value = pending;
      }
    });
  }

  ValueListenable<CanvasViewInfo> get viewInfoListenable => _viewInfoNotifier;

  CanvasTool get activeTool => _activeTool;
  CanvasTool get _effectiveActiveTool {
    if (_eyedropperOverrideActive) {
      return CanvasTool.eyedropper;
    }
    if (_spacePanOverrideActive) {
      return CanvasTool.hand;
    }
    return _activeTool;
  }

  bool get _isReferenceCardResizing => _referenceCardResizeInProgress;

  bool get _cursorRequiresOverlay =>
      ToolCursorStyles.hasOverlay(_effectiveActiveTool);

  bool get _penRequiresOverlay =>
      _effectiveActiveTool == CanvasTool.pen ||
      _effectiveActiveTool == CanvasTool.spray ||
      _effectiveActiveTool == CanvasTool.curvePen ||
      _effectiveActiveTool == CanvasTool.shape ||
      _effectiveActiveTool == CanvasTool.eraser ||
      _effectiveActiveTool == CanvasTool.selectionPen;

  bool get _isBrushEraserEnabled =>
      _brushToolsEraserMode || _activeTool == CanvasTool.eraser;

  bool get hasContent => _controller.hasVisibleContent;
  bool get isDirty => _isDirty;
}
