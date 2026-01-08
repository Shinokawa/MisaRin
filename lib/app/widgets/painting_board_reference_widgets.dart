part of 'painting_board.dart';

class _ResizeHandleIndicator extends StatelessWidget {
  const _ResizeHandleIndicator({
    required this.angle,
    required this.color,
    required this.outlineColor,
  });

  final double angle;
  final Color color;
  final Color outlineColor;

  static const double size = 26;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ResizeHandleIndicatorPainter(
          angle: angle,
          color: color,
          outlineColor: outlineColor,
        ),
      ),
    );
  }
}

class _ResizeHandleIndicatorPainter extends CustomPainter {
  _ResizeHandleIndicatorPainter({
    required this.angle,
    required this.color,
    required this.outlineColor,
  });

  final double angle;
  final Color color;
  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Color solidFillColor = color.withAlpha(0xFF);
    final Color solidOutlineColor = outlineColor.withAlpha(0xFF);
    final Paint outlinePaint = Paint()
      ..color = solidOutlineColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final Paint fillPaint = Paint()
      ..color = solidFillColor
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);
    final double length = math.min(size.width, size.height) * 0.75;
    final double half = length / 2;
    final double head = 5;
    void drawArrow(Paint paint) {
      canvas.drawLine(Offset(-half, 0), Offset(half, 0), paint);
      canvas.drawLine(Offset(half, 0), Offset(half - head, head), paint);
      canvas.drawLine(Offset(half, 0), Offset(half - head, -head), paint);
      canvas.drawLine(Offset(-half, 0), Offset(-half + head, head), paint);
      canvas.drawLine(Offset(-half, 0), Offset(-half + head, -head), paint);
    }

    drawArrow(outlinePaint);
    drawArrow(fillPaint);
  }

  @override
  bool shouldRepaint(covariant _ResizeHandleIndicatorPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.color != color ||
        oldDelegate.outlineColor != outlineColor;
  }
}

class _ReferenceCardBodyConstraints {
  const _ReferenceCardBodyConstraints({
    required this.minWidth,
    required this.maxWidth,
    required this.minHeight,
    required this.maxHeight,
  });

  final double minWidth;
  final double maxWidth;
  final double minHeight;
  final double maxHeight;
}

class _ReferenceImageCard extends StatefulWidget {
  const _ReferenceImageCard({
    required this.image,
    required this.bodySize,
    required this.pixelBytes,
    required this.enableEyedropperSampling,
    required this.onSamplePreview,
    required this.onSampleCommit,
    required this.onClose,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onSizeChanged,
    required this.onResizeStart,
    required this.onResize,
    required this.onResizeEnd,
  });

  final ui.Image image;
  final Size bodySize;
  final Uint8List? pixelBytes;
  final bool enableEyedropperSampling;
  final ValueChanged<Color>? onSamplePreview;
  final ValueChanged<Color>? onSampleCommit;
  final VoidCallback onClose;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final ValueChanged<Offset> onDragUpdate;
  final ValueChanged<Size> onSizeChanged;
  final VoidCallback onResizeStart;
  final _ReferenceCardResizeCallback onResize;
  final VoidCallback onResizeEnd;

  @override
  State<_ReferenceImageCard> createState() => _ReferenceImageCardState();
}

class _ReferenceImageCardState extends State<_ReferenceImageCard> {
  late final TransformationController _transformController;
  bool _samplingActive = false;
  Offset? _cursorPosition;
  Size? _panelSize;
  _ReferenceCardResizeEdge? _hoveredResizeEdge;
  _ReferenceCardResizeEdge? _activeResizeEdge;
  Offset? _lastResizePointer;
  Offset? _resizeCursorPosition;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
  }

  @override
  void didUpdateWidget(covariant _ReferenceImageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool previouslyCouldSample =
        oldWidget.enableEyedropperSampling && oldWidget.pixelBytes != null;
    if (previouslyCouldSample && !_canSampleColor && _cursorPosition != null) {
      setState(() => _cursorPosition = null);
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  bool get _canSampleColor =>
      widget.enableEyedropperSampling && widget.pixelBytes != null;

  bool get _interactionLocked => widget.enableEyedropperSampling;

  bool get _isResizing => _activeResizeEdge != null;

  MouseCursor get _currentResizeCursor {
    if (_activeResizeEdge != null || _hoveredResizeEdge != null) {
      return SystemMouseCursors.none;
    }
    return MouseCursor.defer;
  }

  double get _currentScale {
    final Matrix4 matrix = _transformController.value;
    final double scaleX = matrix.storage[0].abs();
    final double scaleY = matrix.storage[5].abs();
    return math.max(scaleX, scaleY);
  }

  void _resetView() {
    if (_interactionLocked) {
      return;
    }
    _transformController.value = Matrix4.identity();
  }

  void _zoomByFactor(double factor) {
    if (_interactionLocked) {
      return;
    }
    final double target = (_currentScale * factor).clamp(
      _referenceCardMinScale,
      _referenceCardMaxScale,
    );
    _updateScale(target, _viewportCenter());
  }

  Offset _viewportCenter() {
    return Offset(widget.bodySize.width / 2, widget.bodySize.height / 2);
  }

  void _updateScale(double targetScale, Offset focalPoint) {
    final double clamped = targetScale.clamp(
      _referenceCardMinScale,
      _referenceCardMaxScale,
    );
    final Offset scenePoint = _transformController.toScene(focalPoint);
    final Offset translation = Offset(
      focalPoint.dx - scenePoint.dx * clamped,
      focalPoint.dy - scenePoint.dy * clamped,
    );
    _transformController.value = Matrix4.identity()
      ..translate(translation.dx, translation.dy)
      ..scale(clamped);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _interactionLocked) {
      return;
    }
    if (event.scrollDelta.dy == 0) {
      return;
    }
    final double target = (_currentScale * (1 - event.scrollDelta.dy * 0.0015))
        .clamp(_referenceCardMinScale, _referenceCardMaxScale);
    _updateScale(target, event.localPosition);
  }

  Size _panelSizeOrDefault() {
    final Size? measured = _panelSize;
    if (measured != null && !measured.isEmpty) {
      return measured;
    }
    return Size(
      widget.bodySize.width + _referenceCardBodyHorizontalPadding,
      widget.bodySize.height + _referenceCardPanelChromeHeight,
    );
  }

  _ReferenceCardResizeEdge? _resolveResizeEdge(Offset position) {
    if (_interactionLocked) {
      return null;
    }
    final Size panelSize = _panelSizeOrDefault();
    if (panelSize.width <= 0 || panelSize.height <= 0) {
      return null;
    }
    final Rect panelRect = Rect.fromLTWH(
      0,
      0,
      panelSize.width,
      panelSize.height,
    );
    final double edgeTolerance = _referenceCardResizeEdgeHitExtent;
    final double cornerTolerance = _referenceCardResizeCornerHitExtent;
    final bool withinVerticalBounds =
        position.dy >= panelRect.top - edgeTolerance &&
        position.dy <= panelRect.bottom + edgeTolerance;
    final bool withinHorizontalBounds =
        position.dx >= panelRect.left - edgeTolerance &&
        position.dx <= panelRect.right + edgeTolerance;
    final bool nearLeft =
        withinVerticalBounds &&
        (position.dx - panelRect.left).abs() <= edgeTolerance;
    final bool nearRight =
        withinVerticalBounds &&
        (position.dx - panelRect.right).abs() <= edgeTolerance;
    final bool nearBottom =
        withinHorizontalBounds &&
        (position.dy - panelRect.bottom).abs() <= edgeTolerance;

    final bool nearBottomLeft =
        (position - panelRect.bottomLeft).distance <= cornerTolerance;
    final bool nearBottomRight =
        (position - panelRect.bottomRight).distance <= cornerTolerance;

    if (nearBottomLeft) {
      return _ReferenceCardResizeEdge.bottomLeft;
    }
    if (nearBottomRight) {
      return _ReferenceCardResizeEdge.bottomRight;
    }
    if (nearLeft) {
      return _ReferenceCardResizeEdge.left;
    }
    if (nearRight) {
      return _ReferenceCardResizeEdge.right;
    }
    if (nearBottom) {
      return _ReferenceCardResizeEdge.bottom;
    }
    return null;
  }

  void _handleResizeHover(PointerHoverEvent event) {
    if (_activeResizeEdge != null || _interactionLocked) {
      return;
    }
    final _ReferenceCardResizeEdge? edge = _resolveResizeEdge(
      event.localPosition,
    );
    if (edge == null) {
      if (_hoveredResizeEdge == null) {
        return;
      }
      setState(() {
        _hoveredResizeEdge = null;
        _resizeCursorPosition = null;
      });
      return;
    }
    setState(() {
      _hoveredResizeEdge = edge;
      _resizeCursorPosition = event.localPosition;
    });
  }

  void _handleResizeHoverExit() {
    if (_activeResizeEdge != null || _hoveredResizeEdge == null) {
      return;
    }
    setState(() {
      _hoveredResizeEdge = null;
      _resizeCursorPosition = null;
    });
  }

  void _handleResizePointerDown(PointerDownEvent event) {
    if (_interactionLocked || event.buttons == 0) {
      return;
    }
    final _ReferenceCardResizeEdge? edge = _resolveResizeEdge(
      event.localPosition,
    );
    if (edge == null) {
      return;
    }
    setState(() {
      _activeResizeEdge = edge;
      _hoveredResizeEdge = edge;
    });
    _lastResizePointer = event.localPosition;
    _resizeCursorPosition = event.localPosition;
    widget.onResizeStart();
  }

  void _handleResizePointerMove(PointerMoveEvent event) {
    final _ReferenceCardResizeEdge? edge = _activeResizeEdge;
    if (edge == null) {
      return;
    }
    final Offset previous = _lastResizePointer ?? event.localPosition;
    final Offset delta = event.localPosition - previous;
    if (delta == Offset.zero) {
      return;
    }
    _lastResizePointer = event.localPosition;
    _resizeCursorPosition = event.localPosition;
    widget.onResize(edge, delta);
  }

  void _handleResizePointerUp(PointerUpEvent event) {
    _finishResize();
  }

  void _handleResizePointerCancel(PointerCancelEvent event) {
    _finishResize();
  }

  void _finishResize() {
    if (_activeResizeEdge == null) {
      return;
    }
    widget.onResizeEnd();
    setState(() {
      _activeResizeEdge = null;
      _hoveredResizeEdge = null;
    });
    _lastResizePointer = null;
    _resizeCursorPosition = null;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_isResizing) {
      return;
    }
    _updateCursorOverlay(event.localPosition);
    if (!_shouldHandleSample(event)) {
      return;
    }
    _samplingActive = _emitSample(event.localPosition, commit: false);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_isResizing) {
      return;
    }
    _updateCursorOverlay(event.localPosition);
    if (!_samplingActive) {
      return;
    }
    _emitSample(event.localPosition, commit: false);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_isResizing) {
      return;
    }
    if (!_samplingActive) {
      return;
    }
    _emitSample(event.localPosition, commit: true);
    _samplingActive = false;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_isResizing) {
      return;
    }
    if (!_samplingActive) {
      return;
    }
    _samplingActive = false;
  }

  void _handleHover(PointerHoverEvent event) {
    if (_isResizing) {
      return;
    }
    _updateCursorOverlay(event.localPosition);
  }

  bool _shouldHandleSample(PointerEvent event) {
    if (!_canSampleColor) {
      return false;
    }
    if (event.kind == PointerDeviceKind.mouse) {
      return (event.buttons & kPrimaryMouseButton) != 0;
    }
    return true;
  }

  bool _emitSample(Offset localPosition, {required bool commit}) {
    final Color? color = _sampleColor(localPosition);
    if (color == null) {
      return false;
    }
    if (commit) {
      widget.onSampleCommit?.call(color);
    } else {
      widget.onSamplePreview?.call(color);
    }
    return true;
  }

  Color? _sampleColor(Offset localPosition) {
    if (!_canSampleColor) {
      return null;
    }
    final Offset scenePoint = _transformController.toScene(localPosition);
    if (scenePoint.dx < 0 ||
        scenePoint.dy < 0 ||
        scenePoint.dx > widget.bodySize.width ||
        scenePoint.dy > widget.bodySize.height) {
      return null;
    }
    final double relativeX = scenePoint.dx / widget.bodySize.width;
    final double relativeY = scenePoint.dy / widget.bodySize.height;
    final int pixelWidth = widget.image.width;
    final int pixelHeight = widget.image.height;
    if (pixelWidth <= 0 || pixelHeight <= 0) {
      return null;
    }
    final int pixelX = (relativeX * (pixelWidth - 1)).round().clamp(
      0,
      pixelWidth - 1,
    );
    final int pixelY = (relativeY * (pixelHeight - 1)).round().clamp(
      0,
      pixelHeight - 1,
    );
    final Uint8List? pixels = widget.pixelBytes;
    if (pixels == null || pixels.isEmpty) {
      return null;
    }
    final int index = (pixelY * pixelWidth + pixelX) * 4;
    if (index < 0 || index + 3 >= pixels.length) {
      return null;
    }
    final int r = pixels[index];
    final int g = pixels[index + 1];
    final int b = pixels[index + 2];
    final int a = pixels[index + 3];
    return Color.fromARGB(a, r, g, b);
  }

  void _updateCursorOverlay(Offset localPosition) {
    if (!_canSampleColor) {
      return;
    }
    final Offset? current = _cursorPosition;
    if (current != null && (current - localPosition).distanceSquared < 0.25) {
      return;
    }
    setState(() => _cursorPosition = localPosition);
  }

  void _clearCursorOverlay() {
    if (_cursorPosition == null) {
      return;
    }
    setState(() => _cursorPosition = null);
  }

  List<Widget> _buildHeaderActions() {
    final bool disabled = _interactionLocked;
    return [
      Tooltip(
        message: '缩小',
        child: IconButton(
          icon: const Icon(FluentIcons.calculator_subtract),
          iconButtonMode: IconButtonMode.small,
          onPressed: disabled ? null : () => _zoomByFactor(0.9),
        ),
      ),
      Tooltip(
        message: '放大',
        child: IconButton(
          icon: const Icon(FluentIcons.add),
          iconButtonMode: IconButtonMode.small,
          onPressed: disabled ? null : () => _zoomByFactor(1.1),
        ),
      ),
      Tooltip(
        message: '重置视图',
        child: IconButton(
          icon: const Icon(FluentIcons.refresh),
          iconButtonMode: IconButtonMode.small,
          onPressed: disabled ? null : _resetView,
        ),
      ),
    ];
  }

  List<Widget> _buildCursorOverlayWidgets() {
    if (!_canSampleColor) {
      return const <Widget>[];
    }
    final Offset? position = _cursorPosition;
    if (position == null) {
      return const <Widget>[];
    }
    final List<Widget> overlays = <Widget>[];
    final ToolCursorStyle? style = ToolCursorStyles.styleFor(
      CanvasTool.eyedropper,
    );
    if (style != null) {
      overlays.add(
        Positioned(
          left: position.dx - style.anchor.dx + style.iconOffset.dx,
          top: position.dy - style.anchor.dy + style.iconOffset.dy,
          child: IgnorePointer(
            ignoring: true,
            child: ToolCursorStyles.iconFor(
              CanvasTool.eyedropper,
              isDragging: false,
            ),
          ),
        ),
      );
    }
    overlays.add(
      Positioned(
        left: position.dx - ToolCursorStyles.crosshairSize / 2,
        top: position.dy - ToolCursorStyles.crosshairSize / 2,
        child: const IgnorePointer(
          ignoring: true,
          child: ToolCursorCrosshair(),
        ),
      ),
    );
    return overlays;
  }

  List<Widget> _buildResizeHandleIndicators(FluentThemeData theme) {
    final _ReferenceCardResizeEdge? edge =
        _activeResizeEdge ?? _hoveredResizeEdge;
    final Offset? position = _resizeCursorPosition;
    if (edge == null || position == null) {
      return const <Widget>[];
    }
    final double angle = switch (edge) {
      _ReferenceCardResizeEdge.left => 0,
      _ReferenceCardResizeEdge.right => 0,
      _ReferenceCardResizeEdge.bottom => math.pi / 2,
      _ReferenceCardResizeEdge.bottomLeft => -math.pi / 4,
      _ReferenceCardResizeEdge.bottomRight => math.pi / 4,
    };
    final Color color = _activeResizeEdge != null
        ? theme.resources.textFillColorPrimary
        : theme.resources.textFillColorSecondary;
    final Color outlineColor = theme.brightness.isDark
        ? Colors.black
        : Colors.white;
    const double indicatorSize = _ResizeHandleIndicator.size;
    return <Widget>[
      Positioned(
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
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final Size bodySize = widget.bodySize;
    final double panelWidth =
        bodySize.width + _referenceCardBodyHorizontalPadding;
    final FluentThemeData theme = FluentTheme.of(context);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handleResizePointerDown,
      onPointerMove: _handleResizePointerMove,
      onPointerUp: _handleResizePointerUp,
      onPointerCancel: _handleResizePointerCancel,
      onPointerHover: _handleResizeHover,
      child: MouseRegion(
        cursor: _currentResizeCursor,
        onExit: (_) => _handleResizeHoverExit(),
        child: IgnorePointer(
          ignoring: _isResizing,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              MeasuredSize(
                onChanged: (size) {
                  _panelSize = size;
                  widget.onSizeChanged(size);
                },
                child: WorkspaceFloatingPanel(
                  title: '参考图像',
                  width: panelWidth,
                  onClose: widget.onClose,
                  onDragStart: widget.onDragStart,
                  onDragEnd: widget.onDragEnd,
                  onDragUpdate: widget.onDragUpdate,
                  headerPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  bodyPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  bodySpacing: 10,
                  headerActions: _buildHeaderActions(),
                  child: _buildBody(),
                ),
              ),
              ..._buildResizeHandleIndicators(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final Decoration decoration = BoxDecoration(
      color: Colors.black.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
    );
    return DecoratedBox(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          onPointerSignal: _handlePointerSignal,
          child: MouseRegion(
            cursor: _canSampleColor
                ? SystemMouseCursors.none
                : MouseCursor.defer,
            onHover: _handleHover,
            onExit: (_) => _clearCursorOverlay(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: widget.bodySize.width,
                  height: widget.bodySize.height,
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    minScale: _referenceCardMinScale,
                    maxScale: _referenceCardMaxScale,
                    panEnabled: !_interactionLocked,
                    scaleEnabled: !_interactionLocked,
                    boundaryMargin: const EdgeInsets.all(240),
                    clipBehavior: Clip.hardEdge,
                    alignment: Alignment.topLeft,
                    child: RawImage(
                      image: widget.image,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                ..._buildCursorOverlayWidgets(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
