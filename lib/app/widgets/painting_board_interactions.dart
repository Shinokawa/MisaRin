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
      (_workspaceSize.height - 2 * _toolButtonPadding)
          .clamp(0.0, double.infinity),
    );
  }

  bool _isInsideToolArea(Offset workspacePosition) {
    return _toolbarRect.contains(workspacePosition) ||
        _toolSettingsRect.contains(workspacePosition) ||
        _rightSidebarRect.contains(workspacePosition) ||
        _colorIndicatorRect.contains(workspacePosition);
  }

  void _setActiveTool(CanvasTool tool) {
    if (_activeTool == tool) {
      return;
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
      _activeTool = tool;
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

  void _handlePointerDown(PointerDownEvent event) {
    if (!_isPrimaryPointer(event)) {
      return;
    }
    if (_isScalingGesture) {
      return;
    }
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
      case CanvasTool.pen:
        _focusNode.requestFocus();
        if (!isPointInsideSelection(boardLocal)) {
          return;
        }
        _startStroke(boardLocal);
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
    switch (_effectiveActiveTool) {
      case CanvasTool.pen:
        if (_isDrawing) {
          final Offset boardLocal = _toBoardLocal(event.localPosition);
          _appendPoint(boardLocal);
        }
        break;
      case CanvasTool.bucket:
      case CanvasTool.magicWand:
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
      case CanvasTool.bucket:
      case CanvasTool.magicWand:
        break;
      case CanvasTool.selection:
        _handleSelectionPointerUp();
        break;
      case CanvasTool.hand:
        if (_isDraggingBoard) {
          _finishDragBoard();
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
    if (event.logicalKey != LogicalKeyboardKey.space) {
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
