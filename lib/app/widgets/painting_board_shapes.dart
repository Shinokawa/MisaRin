part of 'painting_board.dart';

const int _kEllipseSegments = 64;
const double _kEquilateralHeightFactor = 0.8660254037844386; // sqrt(3) / 2

mixin _PaintingBoardShapeMixin on _PaintingBoardBase {
  ShapeToolVariant _shapeToolVariant = ShapeToolVariant.rectangle;
  Offset? _shapeDragStart;
  Offset? _shapeDragCurrent;
  Path? _shapePreviewPath;
  List<Offset> _shapeStrokePoints = <Offset>[];

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

  void _beginShapeDrawing(Offset boardLocal) {
    if (!isPointInsideSelection(boardLocal)) {
      return;
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
  }

  void _finishShapeDrawing() {
    final List<Offset> strokePoints = _shapeStrokePoints;
    _shapeDragCurrent = null;
    if (strokePoints.length < 2) {
      _resetShapeDrawingState();
      return;
    }

    _pushUndoSnapshot();
    final bool simulatePressure = _simulatePenPressure;
    const double fastDeltaMs = 3.5;
    const double slowDeltaMs = 22.0;
    double accumulatedTime = 0.0;
    _controller.beginStroke(
      strokePoints.first,
      color: _primaryColor,
      radius: _penStrokeWidth / 2,
      simulatePressure: simulatePressure,
      profile: _penPressureProfile,
      timestampMillis: accumulatedTime,
      antialiasLevel: _penAntialiasLevel,
    );
    for (int i = 1; i < strokePoints.length; i++) {
      final Offset point = strokePoints[i];
      if (simulatePressure) {
        final Offset previous = strokePoints[i - 1];
        final double distance = (point - previous).distance;
        final double normalized = (distance / 18.0).clamp(0.0, 1.0);
        final double deltaTime =
            ui.lerpDouble(fastDeltaMs, slowDeltaMs, normalized) ?? fastDeltaMs;
        accumulatedTime += deltaTime;
        _controller.extendStroke(
          point,
          deltaTimeMillis: deltaTime,
          timestampMillis: accumulatedTime,
        );
      } else {
        _controller.extendStroke(point);
      }
    }
    _controller.endStroke();
    _markDirty();

    setState(_resetShapeDrawingState);
  }

  void _cancelShapeDrawing() {
    if (_shapeDragStart == null) {
      return;
    }
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
}
