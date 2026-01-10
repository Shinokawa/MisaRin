part of 'painting_board.dart';

mixin _PaintingBoardLayerTransformMixin on _PaintingBoardBase {
  bool _layerTransformModeActive = false;
  _LayerTransformStateModel? _layerTransformState;
  _LayerTransformHandle? _activeLayerTransformHandle;
  _LayerTransformHandle? _hoverLayerTransformHandle;
  Offset? _layerTransformPointerStartBoard;
  Offset? _layerTransformInitialTranslation;
  double _layerTransformInitialRotation = 0.0;
  double _layerTransformInitialScaleX = 1.0;
  double _layerTransformInitialScaleY = 1.0;
  Matrix4? _layerTransformPointerStartInverse;
  Offset? _layerTransformHandleAnchorLocal;
  Offset? _layerTransformHandleFixedLocal;
  Offset? _layerTransformHandleFixedBoard;
  Offset _layerTransformPanelOffset = Offset.zero;
  Size _layerTransformPanelSize = const Size(
    _kLayerTransformPanelWidth,
    _kLayerTransformPanelMinHeight,
  );
  bool _layerTransformApplying = false;
  int _layerTransformRevision = 0;
  Offset? _layerTransformCursorWorkspacePosition;
  _LayerTransformHandle? _layerTransformCursorHandle;

  bool get _isLayerFreeTransformActive =>
      _layerTransformModeActive && _layerTransformState != null;

  bool get _layerTransformCursorVisible =>
      _isLayerFreeTransformActive &&
      _layerTransformCursorWorkspacePosition != null &&
      _layerTransformCursorHandle != null;

  bool get _shouldHideCursorForLayerTransform => _layerTransformCursorVisible;

  _LayerTransformHandle? _layerTransformOppositeHandle(
    _LayerTransformHandle handle,
  ) {
    switch (handle) {
      case _LayerTransformHandle.topLeft:
        return _LayerTransformHandle.bottomRight;
      case _LayerTransformHandle.top:
        return _LayerTransformHandle.bottom;
      case _LayerTransformHandle.topRight:
        return _LayerTransformHandle.bottomLeft;
      case _LayerTransformHandle.right:
        return _LayerTransformHandle.left;
      case _LayerTransformHandle.bottomRight:
        return _LayerTransformHandle.topLeft;
      case _LayerTransformHandle.bottom:
        return _LayerTransformHandle.top;
      case _LayerTransformHandle.bottomLeft:
        return _LayerTransformHandle.topRight;
      case _LayerTransformHandle.left:
        return _LayerTransformHandle.right;
      case _LayerTransformHandle.translate:
      case _LayerTransformHandle.rotation:
        return null;
    }
  }

  void toggleLayerFreeTransform() {
    if (_layerTransformModeActive) {
      _cancelLayerFreeTransform();
    } else {
      _startLayerFreeTransform();
    }
  }

  bool _maybeInitializeLayerTransformStateFromController() {
    if (!_layerTransformModeActive || _layerTransformState != null) {
      return false;
    }
    final ui.Image? image = _controller.activeLayerTransformImage;
    final Rect? bounds = _controller.activeLayerTransformBounds;
    final Offset origin = _controller.activeLayerTransformOrigin;
    if (image == null || bounds == null || bounds.isEmpty) {
      return false;
    }
    setState(() {
      _layerTransformState = _LayerTransformStateModel(
        image: image,
        bounds: bounds,
        imageOrigin: origin,
      );
    });
    return true;
  }

  BitmapLayerState? _activeLayerSnapshot() {
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

  bool _guardTransformInProgress({String? message}) {
    if (!_layerTransformModeActive) {
      return false;
    }
    if (message != null) {
      AppNotifications.show(
        context,
        message: message,
        severity: InfoBarSeverity.warning,
      );
    }
    return true;
  }

  void _startLayerFreeTransform() {
    if (_layerTransformModeActive ||
        _controller.isActiveLayerTransformPendingCleanup) {
      return;
    }
    final BitmapLayerState? activeLayer = _activeLayerSnapshot();
    if (activeLayer == null) {
      AppNotifications.show(
        context,
        message: context.l10n.cannotLocateLayer,
        severity: InfoBarSeverity.warning,
      );
      return;
    }
    if (activeLayer.locked) {
      AppNotifications.show(
        context,
        message: context.l10n.layerLockedCannotTransform,
        severity: InfoBarSeverity.warning,
      );
      return;
    }
    if (!_controller.isActiveLayerTransforming) {
      _controller.translateActiveLayer(0, 0);
    }
    if (!_controller.isActiveLayerTransforming) {
      AppNotifications.show(
        context,
        message: context.l10n.cannotEnterTransformMode,
        severity: InfoBarSeverity.warning,
      );
      return;
    }
    setState(() {
      _layerTransformModeActive = true;
      _layerTransformState = null;
      _activeLayerTransformHandle = null;
      _hoverLayerTransformHandle = null;
      _layerTransformPointerStartBoard = null;
      _layerTransformInitialTranslation = null;
      _layerTransformInitialRotation = 0.0;
      _layerTransformInitialScaleX = 1.0;
      _layerTransformInitialScaleY = 1.0;
      _layerTransformPointerStartInverse = null;
      _layerTransformHandleAnchorLocal = null;
      _layerTransformHandleFixedLocal = null;
      _layerTransformHandleFixedBoard = null;
      _layerTransformApplying = false;
      _layerTransformRevision = 0;
      _layerTransformCursorWorkspacePosition = null;
      _layerTransformCursorHandle = null;
      _layerTransformPanelOffset = _workspacePanelSpawnOffset(
        this,
        panelWidth: _kLayerTransformPanelWidth,
        panelHeight: _kLayerTransformPanelMinHeight,
        additionalDy: 12,
      );
    });
    _toolCursorPosition = null;
    _penCursorWorkspacePosition = null;
    _maybeInitializeLayerTransformStateFromController();
  }

  void _cancelLayerFreeTransform() {
    if (!_layerTransformModeActive || _layerTransformApplying) {
      return;
    }
    _controller.cancelActiveLayerTranslation();
    setState(() {
      _layerTransformModeActive = false;
      _layerTransformState = null;
      _activeLayerTransformHandle = null;
      _hoverLayerTransformHandle = null;
      _layerTransformApplying = false;
      _layerTransformPointerStartInverse = null;
      _layerTransformHandleAnchorLocal = null;
      _layerTransformHandleFixedLocal = null;
      _layerTransformHandleFixedBoard = null;
      _layerTransformRevision = 0;
      _layerTransformCursorWorkspacePosition = null;
      _layerTransformCursorHandle = null;
    });
  }

  Future<void> _confirmLayerFreeTransform() async {
    if (!_isLayerFreeTransformActive || _layerTransformApplying) {
      return;
    }
    final BitmapLayerState? activeLayer = _activeLayerSnapshot();
    final _LayerTransformStateModel? state = _layerTransformState;
    if (activeLayer == null || state == null) {
      return;
    }
    setState(() => _layerTransformApplying = true);
    try {
      final _LayerTransformRenderResult result =
          await _renderLayerTransformResult(state);
      final _CanvasHistoryEntry? undoEntry =
          await _buildLayerTransformUndoEntry(state);
      await _pushUndoSnapshot(entry: undoEntry);
      final CanvasLayerData data = CanvasLayerData(
        id: activeLayer.id,
        name: activeLayer.name,
        visible: activeLayer.visible,
        opacity: activeLayer.opacity,
        locked: activeLayer.locked,
        clippingMask: activeLayer.clippingMask,
        blendMode: activeLayer.blendMode,
        bitmap: result.rgba,
        bitmapWidth: result.width,
        bitmapHeight: result.height,
        bitmapLeft: result.left,
        bitmapTop: result.top,
        cloneBitmap: false,
      );
      _controller.replaceLayer(activeLayer.id, data);
      _controller.disposeActiveLayerTransformSession();
      await _waitForLayerTransformComposite();
      if (!mounted) {
        return;
      }
      setState(() {
        _layerTransformModeActive = false;
        _layerTransformState = null;
        _activeLayerTransformHandle = null;
        _hoverLayerTransformHandle = null;
        _layerTransformApplying = false;
        _layerTransformPointerStartInverse = null;
        _layerTransformHandleAnchorLocal = null;
        _layerTransformHandleFixedLocal = null;
        _layerTransformHandleFixedBoard = null;
        _layerTransformRevision = 0;
        _layerTransformCursorWorkspacePosition = null;
        _layerTransformCursorHandle = null;
      });
      _markDirty();
    } catch (error, stackTrace) {
      debugPrint('Failed to apply transform: $error\n$stackTrace');
      setState(() => _layerTransformApplying = false);
      AppNotifications.show(
        context,
        message: context.l10n.applyTransformFailed,
        severity: InfoBarSeverity.error,
      );
    }
  }

  // 捕获自由变换前的图层内容，确保撤销记录包含原始像素。
  Future<_CanvasHistoryEntry?> _buildLayerTransformUndoEntry(
    _LayerTransformStateModel state,
  ) async {
    final BitmapLayerState? activeLayer = _activeLayerSnapshot();
    if (activeLayer == null) {
      return null;
    }
    final _CanvasHistoryEntry entry = await _createHistoryEntry();
    final String? activeLayerId = entry.activeLayerId;
    if (activeLayerId == null) {
      return entry;
    }
    final int index = entry.layers.indexWhere(
      (CanvasLayerData layer) => layer.id == activeLayerId,
    );
    if (index < 0) {
      return entry;
    }
    final ByteData? byteData = await state.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) {
      return entry;
    }
    final Uint8List rgba = Uint8List.fromList(
      byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
    );
    entry.layers[index] = CanvasLayerData(
      id: activeLayer.id,
      name: activeLayer.name,
      visible: activeLayer.visible,
      opacity: activeLayer.opacity,
      locked: activeLayer.locked,
      clippingMask: activeLayer.clippingMask,
      blendMode: activeLayer.blendMode,
      bitmap: rgba,
      bitmapWidth: state.image.width,
      bitmapHeight: state.image.height,
      bitmapLeft: state.imageOrigin.dx.round(),
      bitmapTop: state.imageOrigin.dy.round(),
      cloneBitmap: false,
    );
    return entry;
  }

  Future<void> _waitForLayerTransformComposite() async {
    final Completer<void> completer = Completer<void>();
    bool completed = false;
    void listener() {
      if (completed) {
        return;
      }
      completed = true;
      _controller.removeListener(listener);
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    _controller.addListener(listener);
    try {
      await completer.future.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {
          if (!completed) {
            completed = true;
            _controller.removeListener(listener);
          }
        },
      );
    } finally {
      if (!completed) {
        _controller.removeListener(listener);
      }
    }

    final SchedulerBinding? scheduler = SchedulerBinding.instance;
    if (scheduler != null) {
      await scheduler.endOfFrame;
    } else {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<_LayerTransformRenderResult> _renderLayerTransformResult(
    _LayerTransformStateModel state,
  ) async {
    final Rect bounds = state.boundingBox;
    final int left = bounds.left.floor();
    final int top = bounds.top.floor();
    final int right = bounds.right.ceil();
    final int bottom = bounds.bottom.ceil();
    final int width = math.max(1, right - left);
    final int height = math.max(1, bottom - top);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Matrix4 drawMatrix = Matrix4.translationValues(
      -left.toDouble(),
      -top.toDouble(),
      0.0,
    )..multiply(state.matrix);
    canvas.transform(drawMatrix.storage);
    final Paint paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = false;
    final Rect localBounds = Rect.fromLTWH(
      0.0,
      0.0,
      state.imageSize.width,
      state.imageSize.height,
    );
    canvas.save();
    canvas.clipRect(localBounds);
    canvas.translate(-state.clipOffset.dx, -state.clipOffset.dy);
    canvas.drawImage(state.image, Offset.zero, paint);
    canvas.restore();
    final ui.Picture picture = recorder.endRecording();
    final ui.Image rendered = await picture.toImage(width, height);
    picture.dispose();
    final ByteData? byteData = await rendered.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    rendered.dispose();
    if (byteData == null) {
      throw StateError(context.l10n.failedToExportTransform);
    }
    final Uint8List rgba = byteData.buffer.asUint8List();
    return _LayerTransformRenderResult(
      left: left,
      top: top,
      width: width,
      height: height,
      rgba: rgba,
    );
  }

  void _handleLayerTransformPointerDown(Offset boardLocal) {
    if (!_isLayerFreeTransformActive) {
      return;
    }
    final _LayerTransformStateModel? state = _layerTransformState;
    if (state == null) {
      return;
    }
    final _LayerTransformHandle? handle = _hitTestLayerTransformHandles(
      boardLocal,
    );
    if (handle == null) {
      _activeLayerTransformHandle = null;
      return;
    }
    final Matrix4? inverse = state.inverseMatrix;
    _activeLayerTransformHandle = handle;
    _layerTransformPointerStartBoard = boardLocal;
    _layerTransformInitialTranslation = state.translation;
    _layerTransformInitialRotation = state.rotation;
    _layerTransformInitialScaleX = state.scaleX;
    _layerTransformInitialScaleY = state.scaleY;
    _layerTransformPointerStartInverse = inverse;
    _layerTransformHandleAnchorLocal = state.localHandlePosition(handle);
    final _LayerTransformHandle? fixedHandle = _layerTransformOppositeHandle(
      handle,
    );
    if (fixedHandle == null) {
      _layerTransformHandleFixedLocal = null;
      _layerTransformHandleFixedBoard = null;
    } else {
      final Offset fixedLocal = state.localHandlePosition(fixedHandle);
      _layerTransformHandleFixedLocal = fixedLocal;
      _layerTransformHandleFixedBoard = state.transformPoint(fixedLocal);
    }
    _updateLayerTransformCursor(boardLocal, handle);
  }

  void _handleLayerTransformPointerMove(Offset boardLocal) {
    if (!_isLayerFreeTransformActive) {
      return;
    }
    final _LayerTransformStateModel? state = _layerTransformState;
    final _LayerTransformHandle? handle = _activeLayerTransformHandle;
    if (state == null) {
      return;
    }
    if (handle == null) {
      _updateLayerTransformHover(boardLocal);
      return;
    }
    _updateLayerTransformCursor(boardLocal, handle);
    switch (handle) {
      case _LayerTransformHandle.translate:
        final Offset? start = _layerTransformPointerStartBoard;
        final Offset? initial = _layerTransformInitialTranslation;
        if (start == null || initial == null) {
          return;
        }
        final Offset delta = boardLocal - start;
        setState(() {
          state.translation = initial + delta;
          _layerTransformRevision++;
        });
        break;
      case _LayerTransformHandle.rotation:
        final Offset pivot = state.translation + state.pivotLocal;
        final Offset? start = _layerTransformPointerStartBoard;
        if (start == null) {
          return;
        }
        double startAngle = math.atan2(
          start.dy - pivot.dy,
          start.dx - pivot.dx,
        );
        double currentAngle = math.atan2(
          boardLocal.dy - pivot.dy,
          boardLocal.dx - pivot.dx,
        );
        double delta = currentAngle - startAngle;
        if (_isShiftModifierPressed()) {
          const double step = math.pi / 12;
          delta = (delta / step).round() * step;
        }
        setState(() {
          state.rotation = _layerTransformInitialRotation + delta;
          _layerTransformRevision++;
        });
        break;
      default:
        final Matrix4? inverse = _layerTransformPointerStartInverse;
        final Offset? anchorLocal = _layerTransformHandleAnchorLocal;
        final Offset? fixedLocal = _layerTransformHandleFixedLocal;
        final Offset? fixedBoard = _layerTransformHandleFixedBoard;
        if (inverse == null ||
            anchorLocal == null ||
            fixedLocal == null ||
            fixedBoard == null) {
          return;
        }
        final Offset localPoint = MatrixUtils.transformPoint(
          inverse,
          boardLocal,
        );
        double nextScaleX = state.scaleX;
        double nextScaleY = state.scaleY;
        bool affectX = false;
        bool affectY = false;
        Offset handleLocal = anchorLocal;
        switch (handle) {
          case _LayerTransformHandle.top:
          case _LayerTransformHandle.bottom:
            affectY = true;
            break;
          case _LayerTransformHandle.left:
          case _LayerTransformHandle.right:
            affectX = true;
            break;
          default:
            affectX = true;
            affectY = true;
            break;
        }
        final double baseDx = handleLocal.dx - fixedLocal.dx;
        final double baseDy = handleLocal.dy - fixedLocal.dy;
        if (affectX && baseDx.abs() > 0.0001) {
          final double currentDx = localPoint.dx - fixedLocal.dx;
          nextScaleX = (currentDx / baseDx) * _layerTransformInitialScaleX;
        }
        if (affectY && baseDy.abs() > 0.0001) {
          final double currentDy = localPoint.dy - fixedLocal.dy;
          nextScaleY = (currentDy / baseDy) * _layerTransformInitialScaleY;
        }
        if (_isShiftModifierPressed()) {
          final double uniform = affectX && affectY
              ? (nextScaleX + nextScaleY) / 2
              : affectX
              ? nextScaleX
              : nextScaleY;
          if (affectX) {
            nextScaleX = uniform;
          }
          if (affectY) {
            nextScaleY = uniform;
          }
        }
        nextScaleX = nextScaleX.clamp(
          _kLayerTransformMinScale,
          _kLayerTransformMaxScale,
        );
        nextScaleY = nextScaleY.clamp(
          _kLayerTransformMinScale,
          _kLayerTransformMaxScale,
        );
        final Matrix4 transformWithoutTranslation = Matrix4.identity()
          ..translate(state.pivotLocal.dx, state.pivotLocal.dy)
          ..rotateZ(_layerTransformInitialRotation)
          ..scale(nextScaleX, nextScaleY)
          ..translate(-state.pivotLocal.dx, -state.pivotLocal.dy);
        final Offset fixedTransformed = MatrixUtils.transformPoint(
          transformWithoutTranslation,
          fixedLocal,
        );
        final Offset nextTranslation = fixedBoard - fixedTransformed;
        setState(() {
          state.translation = nextTranslation;
          state.scaleX = nextScaleX;
          state.scaleY = nextScaleY;
          _layerTransformRevision++;
        });
        break;
    }
  }

  void _handleLayerTransformPointerUp() {
    _activeLayerTransformHandle = null;
    _layerTransformPointerStartInverse = null;
    _layerTransformHandleAnchorLocal = null;
    _layerTransformHandleFixedLocal = null;
    _layerTransformHandleFixedBoard = null;
  }

  void _handleLayerTransformPointerCancel() {
    _activeLayerTransformHandle = null;
    _layerTransformPointerStartInverse = null;
    _layerTransformHandleAnchorLocal = null;
    _layerTransformHandleFixedLocal = null;
    _layerTransformHandleFixedBoard = null;
    _updateLayerTransformCursor(null, null);
  }

  void _updateLayerTransformHover(Offset boardLocal) {
    final _LayerTransformHandle? handle = _hitTestLayerTransformHandles(
      boardLocal,
    );
    if (handle == _hoverLayerTransformHandle) {
      _updateLayerTransformCursor(boardLocal, handle);
      return;
    }
    setState(() {
      _hoverLayerTransformHandle = handle;
    });
    _updateLayerTransformCursor(boardLocal, handle);
  }

  void _updateLayerTransformCursor(
    Offset? boardLocal,
    _LayerTransformHandle? handle,
  ) {
    final bool shouldShow =
        _isLayerFreeTransformActive &&
        boardLocal != null &&
        handle != null &&
        handle != _LayerTransformHandle.translate;
    final Offset? nextPosition = shouldShow
        ? _boardRect.topLeft +
              Offset(
                boardLocal!.dx * _viewport.scale,
                boardLocal.dy * _viewport.scale,
              )
        : null;
    final _LayerTransformHandle? nextHandle = shouldShow ? handle : null;
    if (_layerTransformCursorHandle == nextHandle &&
        _offsetEquals(_layerTransformCursorWorkspacePosition, nextPosition)) {
      return;
    }
    setState(() {
      _layerTransformCursorWorkspacePosition = nextPosition;
      _layerTransformCursorHandle = nextHandle;
    });
  }

  bool _offsetEquals(Offset? a, Offset? b) {
    if (identical(a, b)) {
      return true;
    }
    if (a == null || b == null) {
      return a == b;
    }
    return (a - b).distanceSquared < 0.25;
  }

  @override
  void _clearLayerTransformCursorIndicator() {
    if (_layerTransformCursorWorkspacePosition == null &&
        _layerTransformCursorHandle == null) {
      return;
    }
    setState(() {
      _layerTransformCursorWorkspacePosition = null;
      _layerTransformCursorHandle = null;
    });
  }

  _LayerTransformHandle? _hitTestLayerTransformHandles(Offset boardLocal) {
    final _LayerTransformStateModel? state = _layerTransformState;
    if (state == null) {
      return null;
    }
    final double hitRadius = (_kLayerTransformHandleHitSize / _viewport.scale)
        .clamp(8.0, 48.0);
    final List<Offset> corners = state.corners;
    _LayerTransformHandle? pickHandle(_LayerTransformHandle handle) {
      if (handle == _LayerTransformHandle.translate) {
        return null;
      }
      if (handle == _LayerTransformHandle.rotation) {
        final Offset position = state.handlePosition(handle);
        if ((boardLocal - position).distance <= hitRadius) {
          return handle;
        }
        return null;
      }
      final Offset position = state.handlePosition(handle);
      if ((boardLocal - position).distance <= hitRadius) {
        return handle;
      }
      return null;
    }

    for (final _LayerTransformHandle handle in <_LayerTransformHandle>[
      _LayerTransformHandle.topLeft,
      _LayerTransformHandle.top,
      _LayerTransformHandle.topRight,
      _LayerTransformHandle.right,
      _LayerTransformHandle.bottomRight,
      _LayerTransformHandle.bottom,
      _LayerTransformHandle.bottomLeft,
      _LayerTransformHandle.left,
      _LayerTransformHandle.rotation,
    ]) {
      final _LayerTransformHandle? result = pickHandle(handle);
      if (result != null) {
        return result;
      }
    }

    final Path polygon = Path()..addPolygon(corners, true);
    if (polygon.contains(boardLocal)) {
      return _LayerTransformHandle.translate;
    }
    final double distance = _distanceToPolygon(boardLocal, corners);
    final double baseRadius = math.max(
      _kLayerTransformHandleHitSize * 2.4,
      _kLayerTransformRotationHandleDistance * 1.1,
    );
    final double rotationHitRadius = (baseRadius / _viewport.scale).clamp(
      24.0,
      96.0,
    );
    if (distance <= rotationHitRadius) {
      return _LayerTransformHandle.rotation;
    }
    return null;
  }

  double _distanceToPolygon(Offset point, List<Offset> polygon) {
    double minDistance = double.infinity;
    for (int i = 0; i < polygon.length; i++) {
      final Offset a = polygon[i];
      final Offset b = polygon[(i + 1) % polygon.length];
      final double distance = _distanceToSegment(point, a, b);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    return minDistance;
  }

  double _distanceToSegment(Offset point, Offset a, Offset b) {
    final Offset ab = b - a;
    final double lengthSquared = ab.distanceSquared;
    if (lengthSquared <= 1e-6) {
      return (point - a).distance;
    }
    double t =
        ((point.dx - a.dx) * ab.dx + (point.dy - a.dy) * ab.dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);
    final Offset projection = a + ab * t;
    return (point - projection).distance;
  }

  bool _isShiftModifierPressed() {
    final Set<LogicalKeyboardKey> keys =
        HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight) ||
        keys.contains(LogicalKeyboardKey.shift);
  }

  Widget? buildLayerTransformImageOverlay() {
    if (!_isLayerFreeTransformActive) {
      return null;
    }
    final _LayerTransformStateModel? state = _layerTransformState;
    if (state == null) {
      return null;
    }
    final double opacity = _controller.activeLayerTransformOpacity;
    final ui.BlendMode? blendMode = _flutterBlendMode(
      _controller.activeLayerTransformBlendMode,
    );
    Widget content = RawImage(
      image: state.image,
      filterQuality: FilterQuality.high,
      fit: BoxFit.none,
      alignment: Alignment.topLeft,
      colorBlendMode: blendMode,
      color: blendMode != null ? Colors.white : null,
    );
    if (opacity < 0.999) {
      content = Opacity(opacity: opacity.clamp(0.0, 1.0), child: content);
    }
    content = SizedBox(
      width: state.imageSize.width,
      height: state.imageSize.height,
      child: ClipRect(
        child: Transform.translate(
          offset: -state.clipOffset,
          child: SizedBox(
            width: state.fullImageSize.width,
            height: state.fullImageSize.height,
            child: content,
          ),
        ),
      ),
    );
    return IgnorePointer(
      ignoring: true,
      child: Transform(
        alignment: Alignment.topLeft,
        transform: state.matrix,
        child: SizedBox(
          width: state.imageSize.width,
          height: state.imageSize.height,
          child: content,
        ),
      ),
    );
  }

  Widget? buildLayerTransformHandlesOverlay(FluentThemeData theme) {
    if (!_isLayerFreeTransformActive) {
      return null;
    }
    final _LayerTransformStateModel? state = _layerTransformState;
    if (state == null) {
      return null;
    }
    const Color lineColor = _kLayerTransformOverlayColor;
    const Color highlightColor = _kLayerTransformOverlayHighlightColor;
    return IgnorePointer(
      ignoring: true,
      child: CustomPaint(
        size: _canvasSize,
        painter: _LayerTransformOverlayPainter(
          state: state,
          boardScale: _viewport.scale,
          lineColor: lineColor,
          highlightColor: highlightColor,
          revision: _layerTransformRevision,
          activeHandle: _activeLayerTransformHandle,
          hoverHandle: _hoverLayerTransformHandle,
        ),
      ),
    );
  }

  Widget? buildLayerTransformCursorOverlay(FluentThemeData theme) {
    if (!_layerTransformCursorVisible) {
      return null;
    }
    final Offset? position = _layerTransformCursorWorkspacePosition;
    final _LayerTransformHandle? handle = _layerTransformCursorHandle;
    if (position == null || handle == null) {
      return null;
    }
    final bool isActive = _activeLayerTransformHandle == handle;
    final bool isHover =
        _activeLayerTransformHandle == null &&
        _hoverLayerTransformHandle == handle;
    final Color color = (isActive || isHover)
        ? theme.resources.textFillColorPrimary
        : theme.resources.textFillColorSecondary;
    final Color outlineColor = theme.brightness.isDark
        ? Colors.black
        : Colors.white;
    if (handle == _LayerTransformHandle.rotation) {
      const double indicatorSize = 20;
      return Positioned(
        left: position.dx - indicatorSize / 2,
        top: position.dy - indicatorSize / 2,
        child: IgnorePointer(
          ignoring: true,
          child: ToolCursorStyles.buildOutlinedIcon(
            icon: FluentIcons.sync,
            size: indicatorSize,
            outlineColor: outlineColor,
            fillColor: color,
          ),
        ),
      );
    }
    final double? angle = _layerTransformCursorAngle(handle);
    if (angle == null) {
      return null;
    }
    const double indicatorSize = _ResizeHandleIndicator.size;
    return Positioned(
      left: position.dx - indicatorSize / 2,
      top: position.dy - indicatorSize / 2,
      child: IgnorePointer(
        ignoring: true,
        child: _ResizeHandleIndicator(
          angle: angle,
          color: color,
          outlineColor: outlineColor,
        ),
      ),
    );
  }

  double? _layerTransformCursorAngle(_LayerTransformHandle handle) {
    switch (handle) {
      case _LayerTransformHandle.top:
        return -math.pi / 2;
      case _LayerTransformHandle.bottom:
        return math.pi / 2;
      case _LayerTransformHandle.left:
        return math.pi;
      case _LayerTransformHandle.right:
        return 0;
      case _LayerTransformHandle.topLeft:
        return -3 * math.pi / 4;
      case _LayerTransformHandle.topRight:
        return -math.pi / 4;
      case _LayerTransformHandle.bottomRight:
        return math.pi / 4;
      case _LayerTransformHandle.bottomLeft:
        return 3 * math.pi / 4;
      default:
        return null;
    }
  }

  Widget? buildLayerTransformPanel() {
    return _buildLayerTransformPanelBody();
  }

  void _updateLayerTransformPanelOffset(Offset delta) {
    setState(() {
      final Offset next = _layerTransformPanelOffset + delta;
      final double maxX = math.max(
        16,
        _workspaceSize.width - _layerTransformPanelSize.width - 16,
      );
      final double maxY = math.max(
        16,
        _workspaceSize.height - _layerTransformPanelSize.height - 16,
      );
      _layerTransformPanelOffset = Offset(
        next.dx.clamp(16.0, maxX),
        next.dy.clamp(16.0, maxY),
      );
    });
  }

  void _handleLayerTransformPanelSizeChanged(Size size) {
    if (size.isEmpty) {
      return;
    }
    setState(() {
      _layerTransformPanelSize = size;
    });
  }
}
