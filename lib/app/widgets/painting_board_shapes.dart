part of 'painting_board.dart';

const int _kEllipseSegments = 64;

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
    final Offset current = _clampToCanvas(boardLocal);
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
    _controller.beginStroke(
      strokePoints.first,
      color: _primaryColor,
      radius: _penStrokeWidth / 2,
    );
    for (int i = 1; i < strokePoints.length; i++) {
      _controller.extendStroke(strokePoints[i]);
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
}
