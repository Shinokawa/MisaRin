part of 'painting_board.dart';

const double _kStylusSimulationBlend = 0.68;
const int _kRustPointStrideBytes = 32;
const int _kRustPointFlagDown = 1;
const int _kRustPointFlagMove = 2;
const int _kRustPointFlagUp = 4;

final class _RustPointBuffer {
  _RustPointBuffer({int initialCapacityPoints = 256})
    : _bytes = Uint8List(initialCapacityPoints * _kRustPointStrideBytes) {
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
    final int base = _len * _kRustPointStrideBytes;
    _data.setFloat32(base + 0, x, Endian.little);
    _data.setFloat32(base + 4, y, Endian.little);
    _data.setFloat32(base + 8, pressure, Endian.little);
    _data.setFloat32(base + 12, 0.0, Endian.little);
    _data.setUint64(base + 16, timestampUs, Endian.little);
    _data.setUint32(base + 24, flags, Endian.little);
    _data.setUint32(base + 28, pointerId, Endian.little);
    _len++;
  }

  void _ensureCapacity(int neededPoints) {
    final int neededBytes = neededPoints * _kRustPointStrideBytes;
    if (_bytes.lengthInBytes >= neededBytes) {
      return;
    }
    int nextBytes = _bytes.lengthInBytes;
    while (nextBytes < neededBytes) {
      nextBytes = nextBytes * 2;
    }
    final Uint8List next = Uint8List(nextBytes);
    next.setRange(0, _len * _kRustPointStrideBytes, _bytes, 0);
    _bytes = next;
    _data = ByteData.view(_bytes.buffer);
  }
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
  final _RustPointBuffer _rustPoints = _RustPointBuffer();
  bool _rustFlushScheduled = false;
  int? _rustActivePointer;
  bool _rustActiveStrokeUsesPressure = true;

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
    final int clamped = value.clamp(0, 3);
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

  bool _isRustDrawingPointer(PointerEvent event) {
    if (event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus) {
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
    for (final BitmapLayerState layer in _controller.layers) {
      if (layer.id == activeId) {
        return layer.locked;
      }
    }
    return false;
  }

  bool _canStartRustStroke({required bool pointerInsideBoard}) {
    if (!widget.useRustCanvas) {
      return false;
    }
    if (!pointerInsideBoard) {
      return false;
    }
    if (!_canUseRustCanvasEngine()) {
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

  Offset _rustToEngineSpace(Offset boardLocal) {
    final Size engineSize = _rustCanvasEngineSize ?? _canvasSize;
    if (engineSize == _canvasSize ||
        _canvasSize.width <= 0 ||
        _canvasSize.height <= 0) {
      return boardLocal;
    }
    final double sx = engineSize.width / _canvasSize.width;
    final double sy = engineSize.height / _canvasSize.height;
    return Offset(boardLocal.dx * sx, boardLocal.dy * sy);
  }

  Offset _sanitizeRustStrokePosition(
    Offset boardLocal, {
    required bool isInitialSample,
  }) {
    final Offset sanitized = _sanitizeStrokePosition(
      boardLocal,
      isInitialSample: isInitialSample,
      anchor: _lastStrokeBoardPosition,
    );
    _lastStrokeBoardPosition = sanitized;
    return sanitized;
  }

  void _enqueueRustPoint(
    PointerEvent event,
    int flags, {
    bool isInitialSample = false,
  }) {
    final int? handle = _rustCanvasEngineHandle;
    if (!_canUseRustCanvasEngine() || handle == null) {
      return;
    }
    final Offset boardLocal = _toBoardLocal(event.localPosition);
    final Offset sanitized = _sanitizeRustStrokePosition(
      boardLocal,
      isInitialSample: isInitialSample,
    );
    final Offset enginePos = _rustToEngineSpace(sanitized);
    final double pressure =
        !_rustActiveStrokeUsesPressure
            ? 1.0
            : (event.pressure.isFinite
                ? event.pressure.clamp(0.0, 1.0)
                : 1.0);
    final int timestampUs = event.timeStamp.inMicroseconds;
    _rustPoints.add(
      x: enginePos.dx,
      y: enginePos.dy,
      pressure: pressure,
      timestampUs: timestampUs,
      flags: flags,
      pointerId: event.pointer,
    );
    _scheduleRustFlush();
  }

  void _scheduleRustFlush() {
    if (_rustFlushScheduled) {
      return;
    }
    _rustFlushScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _rustFlushScheduled = false;
      if (!mounted) {
        _rustPoints.clear();
        return;
      }
      final int? handle = _rustCanvasEngineHandle;
      if (!_canUseRustCanvasEngine() || handle == null) {
        _rustPoints.clear();
        return;
      }
      _flushRustPoints(handle);
    });
  }

  void _flushRustPoints(int handle) {
    final int count = _rustPoints.length;
    if (count == 0) {
      return;
    }
    CanvasEngineFfi.instance.pushPointsPacked(
      handle: handle,
      bytes: _rustPoints.bytes,
      pointCount: count,
    );
    _rustPoints.clear();
  }

  void _beginRustStroke(PointerDownEvent event) {
    if (!_isRustDrawingPointer(event)) {
      return;
    }
    _resetPerspectiveLock();
    _lastStrokeBoardPosition = null;
    final bool supportsPressure =
        event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;
    _rustActiveStrokeUsesPressure = _stylusPressureEnabled && supportsPressure;
    _rustActivePointer = event.pointer;
    _enqueueRustPoint(event, _kRustPointFlagDown, isInitialSample: true);
    _markDirty();
  }

  void _endRustStroke(PointerEvent event) {
    _enqueueRustPoint(event, _kRustPointFlagUp);
    _rustActivePointer = null;
    _rustActiveStrokeUsesPressure = true;
    _lastStrokeBoardPosition = null;
    _strokeStabilizer.reset();
    _resetPerspectiveLock();
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
    final bool preferNearestPerspectiveHandle =
        _perspectiveVisible &&
        _perspectiveMode != PerspectiveGuideMode.off &&
        tool == CanvasTool.hand &&
        (pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
            pressedKeys.contains(LogicalKeyboardKey.shiftRight) ||
            pressedKeys.contains(LogicalKeyboardKey.shift));
    if (_handlePerspectivePointerDown(
      boardLocal,
      allowNearest: preferNearestPerspectiveHandle,
    )) {
      return;
    }
    final bool pointerInsideBoard = boardRect.contains(pointer);
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
        if (widget.useRustCanvas) {
          if (!_canStartRustStroke(pointerInsideBoard: pointerInsideBoard)) {
            return;
          }
          _beginRustStroke(event);
          break;
        }
        if (!isPointInsideSelection(boardLocal)) {
          return;
        }
        _refreshStylusPreferencesIfNeeded();
        await _startStroke(boardLocal, event.timeStamp, event);
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
        final BitmapLayerState? targetLayer = _hitTestTextLayer(boardLocal);
        if (targetLayer != null) {
          _beginEditExistingTextLayer(targetLayer);
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
        if (widget.useRustCanvas && _rustActivePointer == event.pointer) {
          final dynamic dyn = event;
          try {
            final List<dynamic>? coalesced =
                dyn.coalescedEvents as List<dynamic>?;
            if (coalesced != null && coalesced.isNotEmpty) {
              for (final dynamic e in coalesced) {
                if (e is PointerEvent) {
                  _enqueueRustPoint(e, _kRustPointFlagMove);
                }
              }
              break;
            }
          } catch (_) {}
          _enqueueRustPoint(event, _kRustPointFlagMove);
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
        if (widget.useRustCanvas && _rustActivePointer == event.pointer) {
          _endRustStroke(event);
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
        if (widget.useRustCanvas && _rustActivePointer == event.pointer) {
          _endRustStroke(event);
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
    if (_undoStack.isEmpty) {
      return false;
    }
    final _CanvasHistoryEntry previous = _undoStack.removeLast();
    _redoStack.add(await _createHistoryEntry());
    _trimHistoryStacks();
    await _applyHistoryEntry(previous);
    return true;
  }

  Future<bool> redo() async {
    _refreshHistoryLimit();
    if (_redoStack.isEmpty) {
      return false;
    }
    final _CanvasHistoryEntry next = _redoStack.removeLast();
    _undoStack.add(await _createHistoryEntry());
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
