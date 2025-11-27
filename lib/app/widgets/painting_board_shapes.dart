part of 'painting_board.dart';

const int _kEllipseSegments = 64;
const double _kEquilateralHeightFactor = 0.8660254037844386; // sqrt(3) / 2

mixin _PaintingBoardShapeMixin on _PaintingBoardBase {
  ShapeToolVariant _shapeToolVariant = ShapeToolVariant.rectangle;
  Offset? _shapeDragStart;
  Offset? _shapeDragCurrent;
  Path? _shapePreviewPath;
  List<Offset> _shapeStrokePoints = <Offset>[];
  CanvasLayerData? _shapeRasterPreviewSnapshot;
  bool _shapeUndoCapturedForPreview = false;

  ShapeToolVariant get shapeToolVariant => _shapeToolVariant;

  Path? get shapePreviewPath => _shapePreviewPath;

  void _updateShapeToolVariant(ShapeToolVariant variant) {
    if (_shapeToolVariant == variant) {
      return;
    }
    setState(() {
      _shapeToolVariant = variant;
    });
  }

  void _resetShapeDrawingState() {
    _shapeDragStart = null;
    _shapeDragCurrent = null;
    _shapePreviewPath = null;
    _shapeStrokePoints = <Offset>[];
  }

  Future<void> _beginShapeDrawing(Offset boardLocal) async {
    if (!isPointInsideSelection(boardLocal)) {
      return;
    }
    if (!_vectorDrawingEnabled) {
      await _prepareShapeRasterPreview();
    }
    final Offset clamped = _clampToCanvas(boardLocal);
    setState(() {
      _shapeDragStart = clamped;
      _shapeDragCurrent = clamped;
      _shapeStrokePoints = <Offset>[];
      _shapePreviewPath = _buildShapePreviewPath(
        start: clamped,
        current: clamped,
        variant: _shapeToolVariant,
      );
    });
  }

  void _updateShapeDrawing(Offset boardLocal) {
    final Offset? start = _shapeDragStart;
    if (start == null) {
      return;
    }
    final Offset rawCurrent = _clampToCanvas(boardLocal);
    Offset current = rawCurrent;
    if (_isShapeShiftPressed) {
      current = _applyShiftConstraint(
        start: start,
        current: rawCurrent,
        variant: _shapeToolVariant,
      );
      current = _clampToCanvas(current);
    }

    if (_shapeDragCurrent != null &&
        (_shapeDragCurrent! - current).distanceSquared < 0.25) {
      return;
    }
    _shapeDragCurrent = current;
    final List<Offset> strokePoints = _buildShapeStrokePoints(
      start: start,
      current: current,
      variant: _shapeToolVariant,
    );
    final Path preview = _buildShapePreviewPath(
      start: start,
      current: current,
      variant: _shapeToolVariant,
    );
    setState(() {
      _shapeStrokePoints = strokePoints;
      _shapePreviewPath = preview;
    });
    if (!_vectorDrawingEnabled) {
      _refreshShapeRasterPreview(strokePoints);
    }
  }

  Future<void> _finishShapeDrawing() async {
    final List<Offset> strokePoints = _shapeStrokePoints;
    _shapeDragCurrent = null;
    if (strokePoints.length < 2) {
      _disposeShapeRasterPreview(restoreLayer: true);
      _resetShapeDrawingState();
      return;
    }

    if (!_shapeUndoCapturedForPreview) {
      await _pushUndoSnapshot();
    }
    const double initialTimestamp = 0.0;
    if (_shapeRasterPreviewSnapshot != null) {
      _restoreShapeRasterPreview();
    }
    _paintShapeStroke(strokePoints, initialTimestamp);
    _disposeShapeRasterPreview(restoreLayer: false);

    setState(_resetShapeDrawingState);
  }

  void _cancelShapeDrawing() {
    if (_shapeDragStart == null) {
      return;
    }
    _disposeShapeRasterPreview(restoreLayer: true);
    setState(_resetShapeDrawingState);
  }

  Offset _clampToCanvas(Offset value) {
    final Size size = _canvasSize;
    final double dx = value.dx.clamp(0.0, size.width);
    final double dy = value.dy.clamp(0.0, size.height);
    return Offset(dx, dy);
  }

  bool get _isShapeShiftPressed {
    final Set<LogicalKeyboardKey> keys =
        HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight) ||
        keys.contains(LogicalKeyboardKey.shift);
  }

  List<Offset> _buildShapeStrokePoints({
    required Offset start,
    required Offset current,
    required ShapeToolVariant variant,
  }) {
    final Rect bounds = Rect.fromPoints(start, current);
    switch (variant) {
      case ShapeToolVariant.rectangle:
        if (bounds.width.abs() < 0.5 || bounds.height.abs() < 0.5) {
          return <Offset>[];
        }
        return <Offset>[
          bounds.topLeft,
          bounds.topRight,
          bounds.bottomRight,
          bounds.bottomLeft,
          bounds.topLeft,
        ];
      case ShapeToolVariant.ellipse:
        if (bounds.width.abs() < 0.5 || bounds.height.abs() < 0.5) {
          return <Offset>[];
        }
        final List<Offset> points = <Offset>[];
        final Offset center = bounds.center;
        final double radiusX = bounds.width / 2;
        final double radiusY = bounds.height / 2;
        for (int i = 0; i <= _kEllipseSegments; i++) {
          final double t = (i / _kEllipseSegments) * 2 * math.pi;
          points.add(
            Offset(
              center.dx + radiusX * math.cos(t),
              center.dy + radiusY * math.sin(t),
            ),
          );
        }
        return points;
      case ShapeToolVariant.triangle:
        if (bounds.width.abs() < 0.5 || bounds.height.abs() < 0.5) {
          return <Offset>[];
        }
        final Offset top = Offset(bounds.center.dx, bounds.top);
        final Offset bottomLeft = Offset(bounds.left, bounds.bottom);
        final Offset bottomRight = Offset(bounds.right, bounds.bottom);
        return <Offset>[top, bottomRight, bottomLeft, top];
      case ShapeToolVariant.line:
        if ((start - current).distance < 0.5) {
          return <Offset>[];
        }
        return <Offset>[start, current];
    }
  }

  Path _buildShapePreviewPath({
    required Offset start,
    required Offset current,
    required ShapeToolVariant variant,
  }) {
    final Rect bounds = Rect.fromPoints(start, current);
    switch (variant) {
      case ShapeToolVariant.rectangle:
        return Path()..addRect(bounds);
      case ShapeToolVariant.ellipse:
        return Path()..addOval(bounds);
      case ShapeToolVariant.triangle:
        final Path path = Path();
        path.moveTo(bounds.center.dx, bounds.top);
        path.lineTo(bounds.right, bounds.bottom);
        path.lineTo(bounds.left, bounds.bottom);
        path.close();
        return path;
      case ShapeToolVariant.line:
        final Path path = Path();
        path.moveTo(start.dx, start.dy);
        path.lineTo(current.dx, current.dy);
        return path;
    }
  }

  Offset _applyShiftConstraint({
    required Offset start,
    required Offset current,
    required ShapeToolVariant variant,
  }) {
    switch (variant) {
      case ShapeToolVariant.rectangle:
      case ShapeToolVariant.ellipse:
        return _constrainToSquare(start, current);
      case ShapeToolVariant.triangle:
        return _constrainToEquilateralTriangle(start, current);
      case ShapeToolVariant.line:
        return _constrainLineAngle(start, current);
    }
  }

  Offset _constrainToSquare(Offset start, Offset current) {
    final double dx = current.dx - start.dx;
    final double dy = current.dy - start.dy;
    final double length = math.max(dx.abs(), dy.abs());
    if (length == 0) {
      return current;
    }
    final double signX = dx >= 0 ? 1 : -1;
    final double signY = dy >= 0 ? 1 : -1;
    return Offset(start.dx + length * signX, start.dy + length * signY);
  }

  Offset _constrainToEquilateralTriangle(Offset start, Offset current) {
    final double dx = current.dx - start.dx;
    final double dy = current.dy - start.dy;
    double width = dx.abs();
    double height = dy.abs();
    if (width == 0 && height == 0) {
      return current;
    }

    if (width == 0) {
      width = height / _kEquilateralHeightFactor;
    } else if (height == 0) {
      height = width * _kEquilateralHeightFactor;
    } else if (height > width * _kEquilateralHeightFactor) {
      width = height / _kEquilateralHeightFactor;
    } else {
      height = width * _kEquilateralHeightFactor;
    }

    final double signX = dx >= 0 ? 1 : -1;
    final double signY = dy >= 0 ? 1 : -1;
    return Offset(start.dx + width * signX, start.dy + height * signY);
  }

  Offset _constrainLineAngle(Offset start, Offset current) {
    final double dx = current.dx - start.dx;
    final double dy = current.dy - start.dy;
    final double distance = math.sqrt(dx * dx + dy * dy);
    if (distance == 0) {
      return current;
    }
    const double step = math.pi / 4;
    final double angle = math.atan2(dy, dx);
    final double snappedAngle = (angle / step).round() * step;
    return Offset(
      start.dx + math.cos(snappedAngle) * distance,
      start.dy + math.sin(snappedAngle) * distance,
    );
  }

  Future<void> _prepareShapeRasterPreview() async {
    if (_shapeUndoCapturedForPreview) {
      return;
    }
    await _pushUndoSnapshot();
    _shapeUndoCapturedForPreview = true;
    final String? activeLayerId = _controller.activeLayerId;
    if (activeLayerId == null) {
      return;
    }
    _shapeRasterPreviewSnapshot = _controller.buildClipboardLayer(
      activeLayerId,
    );
  }

  void _refreshShapeRasterPreview(List<Offset> strokePoints) {
    final CanvasLayerData? snapshot = _shapeRasterPreviewSnapshot;
    if (snapshot == null || strokePoints.length < 2) {
      return;
    }
    _controller.replaceLayer(snapshot.id, snapshot);
    _paintShapeStroke(strokePoints, 0.0);
  }

  void _disposeShapeRasterPreview({required bool restoreLayer}) {
    final CanvasLayerData? snapshot = _shapeRasterPreviewSnapshot;
    if (snapshot != null && restoreLayer) {
      _controller.replaceLayer(snapshot.id, snapshot);
      _markDirty();
    }
    _shapeRasterPreviewSnapshot = null;
    _shapeUndoCapturedForPreview = false;
  }

  void _restoreShapeRasterPreview() {
    final CanvasLayerData? snapshot = _shapeRasterPreviewSnapshot;
    if (snapshot == null) {
      return;
    }
    _controller.replaceLayer(snapshot.id, snapshot);
  }

  void _paintShapeStroke(List<Offset> strokePoints, double initialTimestamp) {
    final bool simulatePressure = _simulatePenPressure;
    final List<Offset> effectivePoints = simulatePressure
        ? _densifyStrokePolyline(strokePoints)
        : strokePoints;
    if (effectivePoints.length < 2) {
      return;
    }
    final Offset strokeStart = effectivePoints.first;
    final bool erase = _brushToolsEraserMode;
    final Color strokeColor = erase ? const Color(0xFFFFFFFF) : _primaryColor;
    _controller.beginStroke(
      strokeStart,
      color: strokeColor,
      radius: _penStrokeWidth / 2,
      simulatePressure: simulatePressure,
      profile: _penPressureProfile,
      timestampMillis: initialTimestamp,
      antialiasLevel: _penAntialiasLevel,
      brushShape: _brushShape,
      erase: erase,
    );
    if (simulatePressure) {
      final List<Offset> samplePoints = effectivePoints.length > 1
          ? effectivePoints.sublist(1)
          : const <Offset>[];
      final List<_SyntheticStrokeSample> samples = _buildSyntheticStrokeSamples(
        samplePoints,
        strokeStart,
      );
      final double totalDistance = _syntheticStrokeTotalDistance(samples);
      _simulateStrokeWithSyntheticTimeline(
        samples,
        totalDistance: totalDistance,
        initialTimestamp: initialTimestamp,
      );
    } else {
      for (int i = 1; i < effectivePoints.length; i++) {
        _controller.extendStroke(effectivePoints[i]);
      }
    }
    _controller.endStroke();
    _markDirty();
  }
}
