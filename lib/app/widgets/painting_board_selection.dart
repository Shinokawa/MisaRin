part of 'painting_board.dart';

const Color _kSelectionFillColor = Color(0x338A2BE2);
const Color _kSelectionPreviewFillColor = Color(0x558A2BE2);
const Color _kSelectionStrokeColor = Color(0x668A2BE2);
const double _kPolygonCloseThreshold = 8.0;
const Duration _kPolygonDoubleTapInterval = Duration(milliseconds: 300);
const double _kSelectionDashLength = 6.0;
const double _kSelectionDashGap = 4.0;

mixin _PaintingBoardSelectionMixin on _PaintingBoardBase {
  SelectionShape _selectionShape = SelectionShape.rectangle;
  Path? _selectionPath;
  Uint8List? _selectionMask;

  Path? _selectionPreviewPath;
  bool _isSelectionDragging = false;
  Offset? _selectionDragStart;

  final List<Offset> _polygonPoints = <Offset>[];
  Offset? _polygonHoverPoint;
  Duration? _lastPolygonTapTime;
  Offset? _lastPolygonTapPosition;

  Path? _magicWandPreviewPath;
  Uint8List? _magicWandPreviewMask;
  AnimationController? _selectionDashController;
  double _selectionDashPhase = 0.0;
  double _selectionDashValue = 0.0;
  bool _selectionUndoArmed = false;

  @override
  SelectionShape get selectionShape => _selectionShape;

  @override
  Path? get selectionPath => _selectionPath;

  @override
  Path? get selectionPreviewPath => _selectionPreviewPath;

  @override
  Path? get magicWandPreviewPath => _magicWandPreviewPath;

  @override
  double get selectionDashPhase => _selectionDashPhase;

  @override
  Uint8List? get selectionMaskSnapshot => _selectionMask;

  @override
  Path? get selectionPathSnapshot => _selectionPath;

  @override
  bool isPointInsideSelection(Offset position) {
    final Uint8List? mask = _selectionMask;
    if (mask == null) {
      return true;
    }
    final int x = position.dx.floor();
    final int y = position.dy.floor();
    if (x < 0 || y < 0 || x >= _controller.width || y >= _controller.height) {
      return false;
    }
    return mask[y * _controller.width + x] != 0;
  }

  @override
  void _updateSelectionShape(SelectionShape shape) {
    if (_selectionShape == shape) {
      return;
    }
    setState(() {
      _selectionShape = shape;
      _resetSelectionPreview();
      _resetPolygonState();
    });
  }

  @override
  void _clearSelection() {
    if (_selectionPath == null &&
        _selectionMask == null &&
        _selectionPreviewPath == null &&
        _magicWandPreviewPath == null) {
      return;
    }
    _prepareSelectionUndo();
    setState(() {
      setSelectionState(path: null, mask: null);
      clearSelectionArtifacts();
    });
    _updateSelectionAnimation();
    _finishSelectionUndo();
  }

  @override
  void _handleMagicWandPointerDown(Offset position) {
    _applyMagicWandPreview(position);
  }

  @override
  void _convertMagicWandPreviewToSelection() {
    if (_magicWandPreviewMask == null || _magicWandPreviewPath == null) {
      return;
    }
    _prepareSelectionUndo();
    setState(() {
      _applySelectionPathInternal(
        _magicWandPreviewPath,
        mask: _magicWandPreviewMask,
      );
      _magicWandPreviewMask = null;
      _magicWandPreviewPath = null;
    });
    _updateSelectionAnimation();
    _finishSelectionUndo();
  }

  void _applyMagicWandPreview(Offset position) {
    final Uint8List? mask =
        _controller.computeMagicWandMask(position, sampleAllLayers: true);
    setState(() {
      if (mask == null) {
        _clearMagicWandPreview();
      } else {
        _magicWandPreviewMask = mask;
        _magicWandPreviewPath = _pathFromMask(mask, _controller.width);
      }
    });
    _updateSelectionAnimation();
  }

  @override
  void _handleSelectionPointerDown(Offset position, Duration timestamp) {
    _magicWandPreviewMask = null;
    _magicWandPreviewPath = null;
    if (_selectionShape == SelectionShape.polygon) {
      _handlePolygonPointerDown(position, timestamp);
      _updateSelectionAnimation();
      return;
    }
    _prepareSelectionUndo();
    _beginDragSelection(position);
    _updateSelectionAnimation();
  }

  @override
  void _handleSelectionPointerMove(Offset position) {
    if (_selectionShape == SelectionShape.polygon) {
      return;
    }
    if (!_isSelectionDragging || _selectionDragStart == null) {
      return;
    }
    setState(() {
      _selectionPreviewPath = _buildDragPath(position);
    });
    _updateSelectionAnimation();
  }

  @override
  void _handleSelectionPointerUp() {
    if (_selectionShape == SelectionShape.polygon) {
      return;
    }
    if (!_isSelectionDragging) {
      return;
    }
    final Path? finalizedPath = _selectionPreviewPath;
    setState(() {
      _isSelectionDragging = false;
      _selectionDragStart = null;
      _selectionPreviewPath = null;
      _applySelectionPathInternal(finalizedPath);
    });
    _updateSelectionAnimation();
    _finishSelectionUndo();
  }

  @override
  void _handleSelectionPointerCancel() {
    if (_selectionShape == SelectionShape.polygon) {
      return;
    }
    if (!_isSelectionDragging) {
      return;
    }
    setState(() {
      _isSelectionDragging = false;
      _selectionDragStart = null;
      _selectionPreviewPath = null;
    });
    _updateSelectionAnimation();
    _finishSelectionUndo();
  }

  @override
  void _handleSelectionHover(Offset position) {
    if (_selectionShape != SelectionShape.polygon) {
      return;
    }
    if (_polygonPoints.isEmpty) {
      return;
    }
    setState(() {
      _polygonHoverPoint = position;
      _selectionPreviewPath =
          _buildPolygonPath(points: _polygonPoints, hover: _polygonHoverPoint);
    });
    _updateSelectionAnimation();
  }

  @override
  void _clearSelectionHover() {
    if (_selectionShape != SelectionShape.polygon) {
      return;
    }
    if (_polygonHoverPoint == null) {
      return;
    }
    setState(() {
      _polygonHoverPoint = null;
      _selectionPreviewPath =
          _buildPolygonPath(points: _polygonPoints, hover: null);
    });
    _updateSelectionAnimation();
  }

  void _abortPolygonSelection() {
    if (_polygonPoints.isEmpty) {
      return;
    }
    setState(() {
      _polygonPoints.clear();
      _polygonHoverPoint = null;
      _selectionPreviewPath = null;
    });
    _updateSelectionAnimation();
  }

  void _beginDragSelection(Offset position) {
    setState(() {
      setSelectionState(path: null, mask: null);
      _isSelectionDragging = true;
      _selectionDragStart = position;
      _selectionPreviewPath = Path()..addRect(Rect.fromLTWH(position.dx, position.dy, 0, 0));
    });
    _updateSelectionAnimation();
  }

  Path? _buildDragPath(Offset current) {
    final Offset? start = _selectionDragStart;
    if (start == null) {
      return null;
    }
    final double left = start.dx < current.dx ? start.dx : current.dx;
    final double top = start.dy < current.dy ? start.dy : current.dy;
    final double right = start.dx > current.dx ? start.dx : current.dx;
    final double bottom = start.dy > current.dy ? start.dy : current.dy;
    double width = right - left;
    double height = bottom - top;
    if (width < 1) {
      width = 1;
    }
    if (height < 1) {
      height = 1;
    }
    final Rect rect = Rect.fromLTWH(left, top, width, height);
    if (_selectionShape == SelectionShape.rectangle) {
      return Path()..addRect(rect);
    }
    if (_selectionShape == SelectionShape.ellipse) {
      return Path()..addOval(rect);
    }
    return null;
  }

  void _handlePolygonPointerDown(Offset position, Duration timestamp) {
    final bool isDoubleTap = _isPolygonDoubleTap(position, timestamp);
    if (_polygonPoints.isEmpty) {
      _prepareSelectionUndo();
      setState(() {
        setSelectionState(path: null, mask: null);
        _polygonPoints.add(position);
        _selectionPreviewPath =
            _buildPolygonPath(points: _polygonPoints, hover: _polygonHoverPoint);
      });
      _lastPolygonTapTime = timestamp;
      _lastPolygonTapPosition = position;
      _updateSelectionAnimation();
      return;
    }

    final bool closeToFirst =
        (position - _polygonPoints.first).distance <= _kPolygonCloseThreshold;
    if ((isDoubleTap || closeToFirst) && _polygonPoints.length >= 3) {
      Path? finalizedPath;
      setState(() {
        if (!closeToFirst) {
          _polygonPoints.add(position);
        }
        finalizedPath =
            _buildPolygonPath(points: _polygonPoints, close: true);
        _selectionPreviewPath = null;
        _polygonPoints.clear();
        _polygonHoverPoint = null;
        _applySelectionPathInternal(finalizedPath);
      });
      _lastPolygonTapTime = null;
      _lastPolygonTapPosition = null;
      _updateSelectionAnimation();
      _finishSelectionUndo();
      return;
    }

    setState(() {
      _polygonPoints.add(position);
      _selectionPreviewPath =
          _buildPolygonPath(points: _polygonPoints, hover: _polygonHoverPoint);
    });
    _lastPolygonTapTime = timestamp;
    _lastPolygonTapPosition = position;
    _updateSelectionAnimation();
  }

  bool _isPolygonDoubleTap(Offset position, Duration timestamp) {
    final Duration? previous = _lastPolygonTapTime;
    final Offset? previousPosition = _lastPolygonTapPosition;
    if (previous == null || previousPosition == null) {
      return false;
    }
    final Duration delta = timestamp - previous;
    if (delta > _kPolygonDoubleTapInterval) {
      return false;
    }
    final double distance = (position - previousPosition).distance;
    return distance <= _kPolygonCloseThreshold;
  }

  @override
  void _resetSelectionPreview() {
    _isSelectionDragging = false;
    _selectionDragStart = null;
    _selectionPreviewPath = null;
  }

  @override
  void _resetPolygonState() {
    _polygonPoints.clear();
    _polygonHoverPoint = null;
    _lastPolygonTapTime = null;
    _lastPolygonTapPosition = null;
  }

  @override
  void _clearMagicWandPreview() {
    _magicWandPreviewMask = null;
    _magicWandPreviewPath = null;
  }

  bool get _hasSelectionOverlay =>
      _selectionPath != null ||
      _selectionPreviewPath != null ||
      _magicWandPreviewPath != null;

  @override
  @override
  void _updateSelectionAnimation() {
    final AnimationController? controller = _selectionDashController;
    if (controller == null) {
      return;
    }
    if (_hasSelectionOverlay) {
      if (!controller.isAnimating) {
        controller.repeat();
        _selectionDashValue = controller.value;
      }
    } else {
      if (controller.isAnimating) {
        controller.stop();
      }
      _selectionDashPhase = 0;
    }
  }

  @override
  void initializeSelectionTicker(TickerProvider provider) {
    _selectionDashController = AnimationController(
      vsync: provider,
      duration: const Duration(milliseconds: 550),
    )..addListener(() {
        final AnimationController controller = _selectionDashController!;
        final double value = controller.value;
        double delta = value - _selectionDashValue;
        if (delta < 0) {
          delta += 1.0;
        }
        _selectionDashValue = value;
        if (!_hasSelectionOverlay) {
          return;
        }
        _selectionDashPhase +=
            delta * (_kSelectionDashLength + _kSelectionDashGap);
        if (_selectionDashPhase > 1e6) {
          _selectionDashPhase =
              _selectionDashPhase % (_kSelectionDashLength + _kSelectionDashGap);
        }
        if (mounted) {
          setState(() {});
        }
      });
    _updateSelectionAnimation();
  }

  @override
  void disposeSelectionTicker() {
    _selectionDashController?.dispose();
    _selectionDashController = null;
    _selectionDashValue = 0;
  }

  Path? _buildPolygonPath({
    required List<Offset> points,
    Offset? hover,
    bool close = false,
  }) {
    if (points.isEmpty) {
      return null;
    }
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final Offset point = points[i];
      path.lineTo(point.dx, point.dy);
    }
    if (hover != null) {
      path.lineTo(hover.dx, hover.dy);
    }
    if (close || points.length >= 2) {
      path.close();
    }
    return path;
  }

  void _applySelectionPathInternal(Path? path, {Uint8List? mask}) {
    if (path == null) {
      setSelectionState(path: null, mask: null);
      return;
    }
    final Uint8List effectiveMask = mask ?? _maskFromPath(path);
    if (!_maskHasCoverage(effectiveMask)) {
      setSelectionState(path: null, mask: null);
      return;
    }
    setSelectionState(path: path, mask: effectiveMask);
  }

  void _prepareSelectionUndo() {
    if (_selectionUndoArmed) {
      return;
    }
    _pushUndoSnapshot();
    _selectionUndoArmed = true;
  }

  void _finishSelectionUndo() {
    resetSelectionUndoFlag();
  }

  @override
  void setSelectionState({SelectionShape? shape, Path? path, Uint8List? mask}) {
    if (shape != null) {
      _selectionShape = shape;
    }
    _selectionPath = path;
    _selectionMask = mask;
    _controller.setSelectionMask(mask);
  }

  @override
  void clearSelectionArtifacts() {
    _selectionPreviewPath = null;
    _clearMagicWandPreview();
    _isSelectionDragging = false;
    _selectionDragStart = null;
    _resetPolygonState();
  }

  @override
  void resetSelectionUndoFlag() {
    _selectionUndoArmed = false;
  }

  Uint8List _maskFromPath(Path path) {
    final int width = _controller.width;
    final int height = _controller.height;
    final Uint8List mask = Uint8List(width * height);
    final Rect canvasRect =
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    final Rect bounds = path
        .getBounds()
        .inflate(1)
        .intersect(canvasRect);
    if (bounds.isEmpty) {
      return mask;
    }
    final int minX = math.max(0, bounds.left.floor());
    final int maxX = math.min(width, bounds.right.ceil());
    final int minY = math.max(0, bounds.top.floor());
    final int maxY = math.min(height, bounds.bottom.ceil());
    for (int y = minY; y < maxY; y++) {
      final double py = y + 0.5;
      for (int x = minX; x < maxX; x++) {
        final double px = x + 0.5;
        if (path.contains(Offset(px, py))) {
          mask[y * width + x] = 1;
        }
      }
    }
    return mask;
  }

  bool _maskHasCoverage(Uint8List mask) {
    for (final int value in mask) {
      if (value != 0) {
        return true;
      }
    }
    return false;
  }

  Path? _pathFromMask(Uint8List mask, int width) {
    if (mask.isEmpty) {
      return null;
    }
    final int height = mask.length ~/ width;
    final Path path = Path();
    for (int y = 0; y < height; y++) {
      final int rowOffset = y * width;
      int x = 0;
      while (x < width) {
        if (mask[rowOffset + x] == 0) {
          x += 1;
          continue;
        }
        final int start = x;
        while (x < width && mask[rowOffset + x] != 0) {
          x += 1;
        }
        final Rect rect = Rect.fromLTWH(
          start.toDouble(),
          y.toDouble(),
          (x - start).toDouble(),
          1,
        );
        path.addRect(rect);
      }
    }
    return path;
  }
}

class _SelectionOverlayPainter extends CustomPainter {
  const _SelectionOverlayPainter({
    this.selectionPath,
    this.selectionPreviewPath,
    this.magicPreviewPath,
    required this.dashPhase,
  });

  final Path? selectionPath;
  final Path? selectionPreviewPath;
  final Path? magicPreviewPath;
  final double dashPhase;

  static final Paint _previewFillPaint = Paint()
    ..color = _kSelectionPreviewFillColor
    ..style = PaintingStyle.fill;
  static final _MarchingAntsStroke _selectionStroke = _MarchingAntsStroke(
    dashLength: _kSelectionDashLength,
    dashGap: _kSelectionDashGap,
    strokeWidth: 1.0,
    lightColor: const Color(0xE6FFFFFF),
    darkColor: const Color(0xFF2B2B2B),
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (magicPreviewPath != null) {
      canvas.drawPath(magicPreviewPath!, _previewFillPaint);
      _selectionStroke.paint(canvas, magicPreviewPath!, dashPhase);
    }
    if (selectionPreviewPath != null) {
      canvas.drawPath(selectionPreviewPath!, _previewFillPaint);
      _selectionStroke.paint(canvas, selectionPreviewPath!, dashPhase);
    }
    if (selectionPath != null) {
      _selectionStroke.paint(canvas, selectionPath!, dashPhase);
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionOverlayPainter oldDelegate) {
    return oldDelegate.selectionPath != selectionPath ||
        oldDelegate.selectionPreviewPath != selectionPreviewPath ||
        oldDelegate.magicPreviewPath != magicPreviewPath ||
        oldDelegate.dashPhase != dashPhase;
  }
}
