part of 'painting_board.dart';

mixin _PaintingBoardInteractionMixin on _PaintingBoardBase {
  void clear() {
    _pushUndoSnapshot();
    _controller.clear();
    _emitClean();
    setState(() {
      // No-op placeholder for repaint
    });
  }

  bool _isPrimaryPointer(PointerEvent event) {
    return event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kPrimaryMouseButton) != 0;
  }

  Rect get _toolbarRect => Rect.fromLTWH(
    _toolButtonPadding,
    _toolButtonPadding,
    _toolbarButtonSize,
    _toolbarButtonSize * CanvasToolbar.buttonCount +
        _toolbarSpacing * (CanvasToolbar.buttonCount - 1),
  );

  Rect get _toolSettingsRect => Rect.fromLTWH(
    _toolButtonPadding + _toolbarButtonSize + _toolSettingsSpacing,
    _toolButtonPadding,
    _toolSettingsCardWidth,
    _toolSettingsCardHeight,
  );

  Rect get _colorIndicatorRect {
    final double top =
        (_workspaceSize.height - _toolButtonPadding - _colorIndicatorSize)
            .clamp(0.0, double.infinity);
    return Rect.fromLTWH(
      _toolButtonPadding,
      top,
      _colorIndicatorSize,
      _colorIndicatorSize,
    );
  }

  Rect get _rightSidebarRect {
    final double left =
        (_workspaceSize.width - _sidePanelWidth - _toolButtonPadding)
            .clamp(0.0, double.infinity)
            .toDouble();
    return Rect.fromLTWH(
      left,
      _toolButtonPadding,
      _sidePanelWidth,
      (_workspaceSize.height - 2 * _toolButtonPadding).clamp(
        0.0,
        double.infinity,
      ),
    );
  }

  bool _isInsideToolArea(Offset workspacePosition) {
    return _toolbarRect.contains(workspacePosition) ||
        _toolSettingsRect.contains(workspacePosition) ||
        _rightSidebarRect.contains(workspacePosition) ||
        _colorIndicatorRect.contains(workspacePosition);
  }

  bool _isWithinCanvas(Offset boardLocal) {
    return boardLocal.dx >= 0 &&
        boardLocal.dy >= 0 &&
        boardLocal.dx < _canvasSize.width &&
        boardLocal.dy < _canvasSize.height;
  }

  void _setActiveTool(CanvasTool tool) {
    if (_activeTool == tool) {
      return;
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
    setState(() {
      if (_activeTool == CanvasTool.magicWand) {
        _convertMagicWandPreviewToSelection();
      }
      if (tool != CanvasTool.magicWand) {
        _clearMagicWandPreview();
      }
      if (tool != CanvasTool.selection) {
        _resetSelectionPreview();
        _resetPolygonState();
      }
      if (tool != CanvasTool.curvePen) {
        _curvePreviewPath = null;
      }
      if (_activeTool == CanvasTool.eyedropper) {
        _isEyedropperSampling = false;
        _lastEyedropperSample = null;
      }
      _activeTool = tool;
      if (_activeTool == CanvasTool.eyedropper) {
        final Offset? pointer = _lastWorkspacePointer;
        if (pointer != null) {
          _eyedropperCursorPosition = pointer;
        }
      } else {
        _eyedropperCursorPosition = null;
      }
    });
    _updateSelectionAnimation();
  }

  void _updatePenStrokeWidth(double value) {
    final double clamped = value.clamp(1.0, 60.0);
    if ((_penStrokeWidth - clamped).abs() < 0.01) {
      return;
    }
    setState(() => _penStrokeWidth = clamped);
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

  void _startStroke(Offset position) {
    _pushUndoSnapshot();
    setState(() {
      _isDrawing = true;
      _controller.beginStroke(
        position,
        color: _primaryColor,
        radius: _penStrokeWidth / 2,
      );
    });
    _markDirty();
  }

  void _appendPoint(Offset position) {
    if (!_isDrawing) {
      return;
    }
    setState(() {
      _controller.extendStroke(position);
    });
  }

  void _finishStroke() {
    if (!_isDrawing) {
      return;
    }
    _controller.endStroke();
    setState(() {
      _isDrawing = false;
    });
  }

  void _beginDragBoard() {
    setState(() => _isDraggingBoard = true);
  }

  void _updateDragBoard(Offset delta) {
    if (!_isDraggingBoard) {
      return;
    }
    setState(() {
      _viewport.translate(delta);
    });
  }

  void _finishDragBoard() {
    if (!_isDraggingBoard) {
      return;
    }
    setState(() => _isDraggingBoard = false);
  }

  void _beginEyedropperSample(Offset boardLocal) {
    if (!_isWithinCanvas(boardLocal)) {
      return;
    }
    setState(() {
      _isEyedropperSampling = true;
      _lastEyedropperSample = boardLocal;
    });
    _applyEyedropperSample(boardLocal, remember: false);
  }

  void _updateEyedropperSample(Offset boardLocal) {
    if (!_isEyedropperSampling || !_isWithinCanvas(boardLocal)) {
      return;
    }
    final Offset? previous = _lastEyedropperSample;
    if (previous != null && (previous - boardLocal).distanceSquared < 1.0) {
      return;
    }
    _lastEyedropperSample = boardLocal;
    _applyEyedropperSample(boardLocal, remember: false);
  }

  void _finishEyedropperSample() {
    if (!_isEyedropperSampling) {
      return;
    }
    final Offset? sample = _lastEyedropperSample;
    if (sample != null) {
      _applyEyedropperSample(sample);
    }
    setState(() {
      _isEyedropperSampling = false;
      _lastEyedropperSample = null;
    });
  }

  void _cancelEyedropperSample() {
    if (!_isEyedropperSampling) {
      return;
    }
    setState(() {
      _isEyedropperSampling = false;
      _lastEyedropperSample = null;
    });
  }

  void _applyEyedropperSample(Offset boardLocal, {bool remember = true}) {
    final Color color = _controller.sampleColor(
      boardLocal,
      sampleAllLayers: true,
    );
    _setPrimaryColor(color, remember: remember);
  }

  void _updateEyedropperCursor(Offset workspacePosition) {
    if (_effectiveActiveTool != CanvasTool.eyedropper) {
      return;
    }
    final Offset? current = _eyedropperCursorPosition;
    if (current != null &&
        (current - workspacePosition).distanceSquared < 0.25) {
      return;
    }
    setState(() => _eyedropperCursorPosition = workspacePosition);
  }

  void _clearEyedropperCursor() {
    if (_eyedropperCursorPosition == null) {
      return;
    }
    setState(() => _eyedropperCursorPosition = null);
  }

  void _recordWorkspacePointer(Offset workspacePosition) {
    _lastWorkspacePointer = workspacePosition;
  }

  @override
  void _handleWorkspacePointerExit() {
    if (_effectiveActiveTool == CanvasTool.selection) {
      _clearSelectionHover();
    }
    _clearEyedropperCursor();
    _lastWorkspacePointer = null;
  }

  BitmapLayerState? _activeLayerForAdjustment() {
    final String? activeId = _controller.activeLayerId;
    if (activeId == null) {
      return null;
    }
    for (final BitmapLayerState layer in _controller.layers) {
      if (layer.id == activeId) {
        return layer;
      }
    }
    return null;
  }

  bool _isCurveCancelModifierPressed() {
    final Set<LogicalKeyboardKey> keys =
        HardwareKeyboard.instance.logicalKeysPressed;
    final TargetPlatform platform = defaultTargetPlatform;
    if (platform == TargetPlatform.macOS) {
      return keys.contains(LogicalKeyboardKey.metaLeft) ||
          keys.contains(LogicalKeyboardKey.metaRight);
    }
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight);
  }

  bool _isAltKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.alt;
  }

  void _interruptForEyedropperOverride() {
    if (_isDrawing) {
      _finishStroke();
    }
    if (_isLayerDragging) {
      _finishLayerAdjustDrag();
    }
    if (_activeTool == CanvasTool.curvePen) {
      _resetCurvePenState();
    }
  }

  void _beginLayerAdjustDrag(Offset boardLocal) {
    final BitmapLayerState? layer = _activeLayerForAdjustment();
    if (layer == null || layer.locked) {
      return;
    }
    _focusNode.requestFocus();
    _pushUndoSnapshot();
    _isLayerDragging = true;
    _layerDragStart = boardLocal;
    _layerDragAppliedDx = 0;
    _layerDragAppliedDy = 0;
  }

  void _updateLayerAdjustDrag(Offset boardLocal) {
    if (!_isLayerDragging) {
      return;
    }
    final Offset? start = _layerDragStart;
    if (start == null) {
      return;
    }
    final double dx = boardLocal.dx - start.dx;
    final double dy = boardLocal.dy - start.dy;
    final int moveX = dx.round();
    final int moveY = dy.round();
    if (moveX == _layerDragAppliedDx && moveY == _layerDragAppliedDy) {
      return;
    }
    _layerDragAppliedDx = moveX;
    _layerDragAppliedDy = moveY;
    _controller.translateActiveLayer(moveX, moveY);
    _markDirty();
  }

  void _finishLayerAdjustDrag() {
    if (!_isLayerDragging) {
      return;
    }
    _controller.commitActiveLayerTranslation();
    _isLayerDragging = false;
    _layerDragStart = null;
    _layerDragAppliedDx = 0;
    _layerDragAppliedDy = 0;
  }

  void _handleCurvePenPointerDown(Offset boardLocal) {
    _focusNode.requestFocus();
    if (_curveAnchor == null) {
      if (!isPointInsideSelection(boardLocal)) {
        return;
      }
      _pushUndoSnapshot();
      _controller.beginStroke(
        boardLocal,
        color: _primaryColor,
        radius: _penStrokeWidth / 2,
      );
      _controller.endStroke();
      _markDirty();
      setState(() {
        _curveAnchor = boardLocal;
        _curvePreviewPath = null;
      });
      return;
    }
    if (!isPointInsideSelection(boardLocal) || _isCurvePlacingSegment) {
      return;
    }
    setState(() {
      _curvePendingEnd = boardLocal;
      _curveDragOrigin = boardLocal;
      _curveDragDelta = Offset.zero;
      _isCurvePlacingSegment = true;
      _curvePreviewPath = _buildCurvePreviewPath();
    });
  }

  void _handleCurvePenPointerMove(Offset boardLocal) {
    if (!_isCurvePlacingSegment || _curveDragOrigin == null) {
      return;
    }
    setState(() {
      _curveDragDelta = boardLocal - _curveDragOrigin!;
      _curvePreviewPath = _buildCurvePreviewPath();
    });
  }

  void _handleCurvePenPointerUp() {
    if (!_isCurvePlacingSegment) {
      return;
    }
    final Offset? start = _curveAnchor;
    final Offset? end = _curvePendingEnd;
    if (start == null || end == null) {
      _cancelCurvePenSegment();
      return;
    }
    _pushUndoSnapshot();
    final Offset control = _computeCurveControlPoint(
      start,
      end,
      _curveDragDelta,
    );
    _drawQuadraticCurve(start, control, end);
    setState(() {
      _curveAnchor = end;
      _curvePendingEnd = null;
      _curveDragOrigin = null;
      _curveDragDelta = Offset.zero;
      _curvePreviewPath = null;
      _isCurvePlacingSegment = false;
    });
  }

  void _cancelCurvePenSegment() {
    if (!_isCurvePlacingSegment) {
      return;
    }
    setState(() {
      _curvePendingEnd = null;
      _curveDragOrigin = null;
      _curveDragDelta = Offset.zero;
      _curvePreviewPath = null;
      _isCurvePlacingSegment = false;
    });
  }

  void _resetCurvePenState({bool notify = true}) {
    void apply() {
      _curveAnchor = null;
      _curvePendingEnd = null;
      _curveDragOrigin = null;
      _curveDragDelta = Offset.zero;
      _curvePreviewPath = null;
      _isCurvePlacingSegment = false;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  Path? _buildCurvePreviewPath() {
    final Offset? start = _curveAnchor;
    final Offset? end = _curvePendingEnd;
    if (start == null || end == null) {
      return null;
    }
    final Offset control = _computeCurveControlPoint(
      start,
      end,
      _curveDragDelta,
    );
    final Path path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    return path;
  }

  Offset _computeCurveControlPoint(Offset start, Offset end, Offset dragDelta) {
    if (dragDelta.distanceSquared < 1e-6) {
      return Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    }
    return end - dragDelta;
  }

  void _drawQuadraticCurve(Offset start, Offset control, Offset end) {
    _controller.beginStroke(
      start,
      color: _primaryColor,
      radius: _penStrokeWidth / 2,
    );
    final double estimatedLength =
        (start - control).distance + (control - end).distance;
    final int steps = math.max(12, estimatedLength.ceil());
    for (int i = 1; i <= steps; i++) {
      final double t = i / steps;
      final double invT = 1 - t;
      final double x =
          invT * invT * start.dx + 2 * invT * t * control.dx + t * t * end.dx;
      final double y =
          invT * invT * start.dy + 2 * invT * t * control.dy + t * t * end.dy;
      _controller.extendStroke(Offset(x, y));
    }
    _controller.endStroke();
    _markDirty();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_isPrimaryPointer(event)) {
      return;
    }
    if (_isScalingGesture) {
      return;
    }
    _recordWorkspacePointer(event.localPosition);
    _updateEyedropperCursor(event.localPosition);
    final Offset pointer = event.localPosition;
    if (_isInsideToolArea(pointer)) {
      return;
    }
    final Rect boardRect = _boardRect;
    if (!boardRect.contains(pointer)) {
      return;
    }
    final Offset boardLocal = _toBoardLocal(pointer);
    final CanvasTool tool = _effectiveActiveTool;
    switch (tool) {
      case CanvasTool.layerAdjust:
        _beginLayerAdjustDrag(boardLocal);
        break;
      case CanvasTool.pen:
        _focusNode.requestFocus();
        if (!isPointInsideSelection(boardLocal)) {
          return;
        }
        _startStroke(boardLocal);
        break;
      case CanvasTool.curvePen:
        if (_isCurveCancelModifierPressed() &&
            (_curveAnchor != null || _isCurvePlacingSegment)) {
          _resetCurvePenState();
          return;
        }
        _handleCurvePenPointerDown(boardLocal);
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
      case CanvasTool.hand:
        _beginDragBoard();
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
    _recordWorkspacePointer(event.localPosition);
    _updateEyedropperCursor(event.localPosition);
    switch (_effectiveActiveTool) {
      case CanvasTool.pen:
        if (_isDrawing) {
          final Offset boardLocal = _toBoardLocal(event.localPosition);
          _appendPoint(boardLocal);
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
      case CanvasTool.bucket:
      case CanvasTool.magicWand:
        break;
      case CanvasTool.eyedropper:
        _updateEyedropperSample(_toBoardLocal(event.localPosition));
        break;
      case CanvasTool.selection:
        final Offset boardLocal = _toBoardLocal(event.localPosition);
        _handleSelectionPointerMove(boardLocal);
        break;
      case CanvasTool.hand:
        if (_isDraggingBoard) {
          _updateDragBoard(event.delta);
        }
        break;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    switch (_effectiveActiveTool) {
      case CanvasTool.pen:
        if (_isDrawing) {
          _finishStroke();
        }
        break;
      case CanvasTool.layerAdjust:
        if (_isLayerDragging) {
          _finishLayerAdjustDrag();
        }
        break;
      case CanvasTool.curvePen:
        _handleCurvePenPointerUp();
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
      case CanvasTool.hand:
        if (_isDraggingBoard) {
          _finishDragBoard();
        }
        break;
      case CanvasTool.curvePen:
        _handleCurvePenPointerUp();
        break;
      case CanvasTool.layerAdjust:
        if (_isLayerDragging) {
          _finishLayerAdjustDrag();
        }
        break;
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    switch (_effectiveActiveTool) {
      case CanvasTool.pen:
        if (_isDrawing) {
          _finishStroke();
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
      case CanvasTool.selection:
        _handleSelectionPointerCancel();
        break;
      case CanvasTool.hand:
        if (_isDraggingBoard) {
          _finishDragBoard();
        }
        break;
      case CanvasTool.bucket:
      case CanvasTool.magicWand:
        break;
    }
  }

  void _handlePointerHover(PointerHoverEvent event) {
    _recordWorkspacePointer(event.localPosition);
    _updateEyedropperCursor(event.localPosition);
    if (_effectiveActiveTool != CanvasTool.selection) {
      return;
    }
    final Rect boardRect = _boardRect;
    if (!boardRect.contains(event.localPosition)) {
      _clearSelectionHover();
      return;
    }
    final Offset boardLocal = _toBoardLocal(event.localPosition);
    _handleSelectionHover(boardLocal);
  }

  @override
  KeyEventResult _handleWorkspaceKeyEvent(FocusNode node, KeyEvent event) {
    final LogicalKeyboardKey key = event.logicalKey;
    if (_isAltKey(key) && _activeTool != CanvasTool.eyedropper) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        if (_eyedropperOverrideActive) {
          return KeyEventResult.handled;
        }
        _interruptForEyedropperOverride();
        final Offset? pointer = _lastWorkspacePointer;
        setState(() {
          _eyedropperOverrideActive = true;
          if (pointer != null) {
            _eyedropperCursorPosition = pointer;
          }
        });
        return KeyEventResult.handled;
      }
      if (event is KeyUpEvent) {
        if (!_eyedropperOverrideActive) {
          return KeyEventResult.handled;
        }
        _finishEyedropperSample();
        setState(() {
          _eyedropperOverrideActive = false;
          _eyedropperCursorPosition = null;
        });
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
      setState(() => _spacePanOverrideActive = true);
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
    undo();
  }

  void _handleRedo() {
    redo();
  }

  bool undo() {
    _refreshHistoryLimit();
    if (_undoStack.isEmpty) {
      return false;
    }
    final _CanvasHistoryEntry previous = _undoStack.removeLast();
    _redoStack.add(_createHistoryEntry());
    _trimHistoryStacks();
    _applyHistoryEntry(previous);
    return true;
  }

  bool redo() {
    _refreshHistoryLimit();
    if (_redoStack.isEmpty) {
      return false;
    }
    final _CanvasHistoryEntry next = _redoStack.removeLast();
    _undoStack.add(_createHistoryEntry());
    _trimHistoryStacks();
    _applyHistoryEntry(next);
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
