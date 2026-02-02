part of 'painting_board.dart';

enum _PerspectiveHandle { vp1, vp2, vp3 }

class _PerspectiveSnapPreviewResult {
  const _PerspectiveSnapPreviewResult({
    required this.snapped,
    required this.withinTolerance,
  });

  final Offset snapped;
  final bool withinTolerance;
}

mixin _PaintingBoardPerspectiveMixin on _PaintingBoardBase {
  PerspectiveGuideMode _perspectiveMode = PerspectiveGuideMode.off;
  bool _perspectiveEnabled = false;
  bool _perspectiveVisible = false;
  double _perspectiveHorizonY = 0.0;
  Offset _perspectiveVp1 = Offset.zero;
  Offset? _perspectiveVp2;
  Offset? _perspectiveVp3;
  double _perspectiveSnapAngleTolerance = 14.0;
  _PerspectiveHandle? _activePerspectiveHandle;
  _PerspectiveHandle? _hoveringPerspectiveHandle;
  Offset? _perspectiveLockedDirection;
  Offset? _perspectivePenAnchor;
  Offset? _perspectivePenPreviewTarget;
  Offset? _perspectivePenSnappedTarget;
  bool _perspectivePenPreviewValid = false;

  void _syncPerspectiveFlags() {
    if (_perspectiveMode == PerspectiveGuideMode.off) {
      _perspectiveEnabled = false;
      _perspectiveVisible = false;
      _activePerspectiveHandle = null;
      _hoveringPerspectiveHandle = null;
      _resetPerspectiveLock();
      _clearPerspectivePenPreview();
      return;
    }
    if (_perspectiveVisible && !_perspectiveEnabled) {
      _perspectiveEnabled = true;
    }
  }

  void initializePerspectiveGuide(PerspectiveGuideState? initialState) {
    final PerspectiveGuideState resolved =
        initialState ?? PerspectiveGuideState.defaults(_canvasSize);
    _applyPerspectiveState(resolved, notify: false);
  }

  void _applyPerspectiveState(
    PerspectiveGuideState state, {
    bool notify = true,
  }) {
    _perspectiveMode = state.mode;
    _perspectiveEnabled = state.enabled;
    _perspectiveVisible = state.visible;
    _perspectiveHorizonY = state.horizonY;
    _perspectiveVp1 = state.vp1;
    _perspectiveVp2 = state.vp2;
    _perspectiveVp3 = state.vp3;
    _perspectiveSnapAngleTolerance = state.snapAngleToleranceDegrees;
    _resetPerspectiveLock();
    _hoveringPerspectiveHandle = null;
    _clearPerspectivePenPreview();
    _syncPerspectiveFlags();
    if (notify) {
      setState(() {});
      _notifyViewInfoChanged();
    }
  }

  PerspectiveGuideState snapshotPerspectiveGuide() {
    return PerspectiveGuideState(
      mode: _perspectiveMode,
      enabled: _perspectiveEnabled,
      visible: _perspectiveVisible,
      horizonY: _perspectiveHorizonY,
      vp1: _perspectiveVp1,
      vp2: _perspectiveVp2,
      vp3: _perspectiveVp3,
      snapAngleToleranceDegrees: _perspectiveSnapAngleTolerance,
    );
  }

  void togglePerspectiveGuide() {
    setState(() {
      final bool next = !_perspectiveEnabled;
      _perspectiveEnabled = next;
      _perspectiveVisible = next;
      if (next && _perspectiveMode == PerspectiveGuideMode.off) {
        _perspectiveMode = PerspectiveGuideMode.onePoint;
      }
      _syncPerspectiveFlags();
    });
    _markDirty();
    _notifyViewInfoChanged();
  }

  void setPerspectiveMode(PerspectiveGuideMode mode) {
    if (_perspectiveMode == mode) {
      return;
    }
    setState(() {
      _perspectiveMode = mode;
      if (mode == PerspectiveGuideMode.off) {
        _perspectiveEnabled = false;
        _perspectiveVisible = false;
        _activePerspectiveHandle = null;
      } else {
        _perspectiveEnabled = true;
        _perspectiveVisible = true;
      }
      _syncPerspectiveFlags();
    });
    _markDirty();
    _notifyViewInfoChanged();
  }

  bool get perspectiveGuideVisible => _perspectiveVisible;
  bool get perspectiveGuideEnabled => _perspectiveEnabled;
  PerspectiveGuideMode get perspectiveGuideMode => _perspectiveMode;

  bool _handlePerspectivePointerDown(
    Offset boardLocal, {
    bool allowNearest = false,
  }) {
    if (!_perspectiveVisible || _perspectiveMode == PerspectiveGuideMode.off) {
      return false;
    }
    final _PerspectiveHandle? handle =
        _hitTestPerspectiveHandle(boardLocal) ??
        (allowNearest ? _nearestPerspectiveHandle(boardLocal) : null);
    if (handle == null) {
      return false;
    }
    setState(() {
      _activePerspectiveHandle = handle;
      _hoveringPerspectiveHandle = handle;
      if (allowNearest) {
        switch (handle) {
          case _PerspectiveHandle.vp1:
            _perspectiveVp1 = boardLocal;
            break;
          case _PerspectiveHandle.vp2:
            _perspectiveVp2 = boardLocal;
            break;
          case _PerspectiveHandle.vp3:
            _perspectiveVp3 = boardLocal;
            break;
        }
      }
    });
    if (allowNearest) {
      _markDirty();
    }
    return true;
  }

  bool get _isDraggingPerspectiveHandle => _activePerspectiveHandle != null;

  void _handlePerspectivePointerMove(Offset boardLocal) {
    final _PerspectiveHandle? handle = _activePerspectiveHandle;
    if (handle == null) {
      return;
    }
    switch (handle) {
      case _PerspectiveHandle.vp1:
        setState(() => _perspectiveVp1 = boardLocal);
        break;
      case _PerspectiveHandle.vp2:
        setState(() => _perspectiveVp2 = boardLocal);
        break;
      case _PerspectiveHandle.vp3:
        setState(() => _perspectiveVp3 = boardLocal);
        break;
    }
    _markDirty();
  }

  void _handlePerspectivePointerUp() {
    if (_activePerspectiveHandle == null) {
      return;
    }
    setState(() {
      _activePerspectiveHandle = null;
    });
    _markDirty();
  }

  _PerspectiveHandle? _hitTestPerspectiveHandle(Offset boardLocal) {
    final double radius = 18.0 / _viewport.scale;
    bool hit(Offset target) => (boardLocal - target).distance <= radius;

    if (hit(_perspectiveVp1)) {
      return _PerspectiveHandle.vp1;
    }
    if (_perspectiveMode != PerspectiveGuideMode.onePoint) {
      final Offset? vp2 = _perspectiveVp2;
      if (vp2 != null && hit(vp2)) {
        return _PerspectiveHandle.vp2;
      }
    }
    if (_perspectiveMode == PerspectiveGuideMode.threePoint) {
      final Offset? vp3 = _perspectiveVp3;
      if (vp3 != null && hit(vp3)) {
        return _PerspectiveHandle.vp3;
      }
    }
    return null;
  }

  _PerspectiveHandle? _nearestPerspectiveHandle(Offset boardLocal) {
    final double radius = 18.0 / _viewport.scale;
    final double fallbackRadius = radius * 3.5;
    _PerspectiveHandle? nearest;
    double nearestDistance = double.infinity;

    void consider(_PerspectiveHandle handle, Offset? position,
        {bool verticalOnly = false}) {
      if (position == null) {
        return;
      }
      final double distance = verticalOnly
          ? (boardLocal.dy - position.dy).abs()
          : (boardLocal - position).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = handle;
      }
    }

    consider(_PerspectiveHandle.vp1, _perspectiveVp1);
    if (_perspectiveMode != PerspectiveGuideMode.onePoint) {
      consider(_PerspectiveHandle.vp2, _perspectiveVp2 ?? _perspectiveVp1);
    }
    if (_perspectiveMode == PerspectiveGuideMode.threePoint) {
      consider(_PerspectiveHandle.vp3, _perspectiveVp3 ?? _perspectiveVp1);
    }

    if (nearestDistance > fallbackRadius) {
      return null;
    }
    return nearest;
  }

  void _resetPerspectiveLock() {
    _perspectiveLockedDirection = null;
  }

  void _clearPerspectivePenPreview() {
    if (_perspectivePenAnchor == null &&
        _perspectivePenPreviewTarget == null &&
        _perspectivePenSnappedTarget == null &&
        !_perspectivePenPreviewValid) {
      return;
    }
    setState(() {
      _perspectivePenAnchor = null;
      _perspectivePenPreviewTarget = null;
      _perspectivePenSnappedTarget = null;
      _perspectivePenPreviewValid = false;
    });
  }

  void _setPerspectivePenAnchor(Offset anchor) {
    setState(() {
      _perspectivePenAnchor = anchor;
      _perspectivePenPreviewTarget = anchor;
      _perspectivePenSnappedTarget = anchor;
      _perspectivePenPreviewValid = true;
    });
  }

  void _updatePerspectivePenPreview(Offset target) {
    final Offset? anchor = _perspectivePenAnchor;
    if (anchor == null) {
      return;
    }
    final _PerspectiveSnapPreviewResult? preview =
        _previewPerspectiveSnap(anchor, target);
    setState(() {
      _perspectivePenPreviewTarget = target;
      if (preview == null) {
        _perspectivePenSnappedTarget = target;
        _perspectivePenPreviewValid = false;
      } else {
        _perspectivePenSnappedTarget = preview.snapped;
        _perspectivePenPreviewValid = preview.withinTolerance;
      }
    });
  }

  _PerspectiveSnapPreviewResult? _previewPerspectiveSnap(
    Offset anchor,
    Offset target,
  ) {
    final List<Offset> directions = _collectPerspectiveDirections(anchor);
    if (directions.isEmpty) {
      return null;
    }
    final Offset delta = target - anchor;
    if (delta == Offset.zero) {
      return _PerspectiveSnapPreviewResult(
        snapped: anchor,
        withinTolerance: true,
      );
    }
    Offset? bestDir;
    double bestAngle = double.infinity;
    final double deltaLength = delta.distance;
    for (final Offset dir in directions) {
      final double length = dir.distance;
      if (length < 0.0001) {
        continue;
      }
      final Offset norm = dir / length;
      final double dot = (delta.dx * norm.dx + delta.dy * norm.dy) /
          deltaLength; // delta already non-zero
      // 使用绝对值让角度与方向无关，同一条直线两侧都判定为有效。
      final double clampedDot = dot.clamp(-1.0, 1.0).abs();
      final double angle = (math.acos(clampedDot) * 180.0) / math.pi;
      if (angle < bestAngle) {
        bestAngle = angle;
        bestDir = norm;
      }
    }
    if (bestDir == null) {
      return null;
    }
    final double tolerance =
        _perspectiveSnapAngleTolerance.clamp(0.0, 180.0);
    final bool withinTolerance =
        tolerance >= 179.9 ||
        bestAngle <= tolerance;
    final Offset snapped = _snapToDirectionWithDistance(anchor, delta, bestDir);
    return _PerspectiveSnapPreviewResult(
      snapped: snapped,
      withinTolerance: withinTolerance,
    );
  }

  void _updatePerspectiveHover(Offset boardLocal) {
    if (!_perspectiveVisible || _perspectiveMode == PerspectiveGuideMode.off) {
      _clearPerspectiveHover();
      return;
    }
    final _PerspectiveHandle? hit = _hitTestPerspectiveHandle(boardLocal);
    if (hit != _hoveringPerspectiveHandle) {
      setState(() => _hoveringPerspectiveHandle = hit);
    }
  }

  void _clearPerspectiveHover() {
    if (_hoveringPerspectiveHandle != null) {
      setState(() => _hoveringPerspectiveHandle = null);
    }
  }

  Offset _projectOntoDirection(
    Offset anchor,
    Offset delta,
    Offset direction,
  ) {
    final double length = direction.distance;
    if (length < 0.0001) {
      return anchor;
    }
    final Offset norm = direction / length;
    final double projectedLength = (delta.dx * norm.dx + delta.dy * norm.dy);
    return anchor + norm * projectedLength;
  }

  Offset _snapToDirectionWithDistance(
    Offset anchor,
    Offset delta,
    Offset direction,
  ) {
    final double length = direction.distance;
    if (length < 0.0001) {
      return anchor;
    }
    final Offset norm = direction / length;
    final double deltaLength = delta.distance;
    if (deltaLength < 0.0001) {
      return anchor;
    }
    final double projection = (delta.dx * norm.dx + delta.dy * norm.dy);
    final double sign = projection >= 0.0 ? 1.0 : -1.0;
    return anchor + norm * deltaLength * sign;
  }

  Offset _maybeSnapToPerspective(
    Offset position, {
    Offset? anchor,
  }) {
    final bool snapActive = _perspectiveEnabled &&
        _perspectiveVisible &&
        _perspectiveMode != PerspectiveGuideMode.off;
    if (!snapActive || anchor == null) {
      return position;
    }
    final List<Offset> directions = _collectPerspectiveDirections(anchor);
    if (directions.isEmpty) {
      return position;
    }
    final Offset delta = position - anchor;
    final Offset? lockedDir = _perspectiveLockedDirection;
    if (lockedDir != null) {
      return _projectOntoDirection(anchor, delta, lockedDir);
    }
    if (delta == Offset.zero) {
      return position;
    }
    final double deltaLength = delta.distance;

    Offset? bestDir;
    double bestAngle = double.infinity;

    for (final Offset dir in directions) {
      final double length = dir.distance;
      if (length < 0.0001) {
        continue;
      }
      final Offset norm = dir / length;
      final double dot = (delta.dx * norm.dx + delta.dy * norm.dy) /
          deltaLength; // delta already non-zero
      // 方向无关，取绝对值后再计算夹角，保证同一条线两端都能吸附。
      final double clampedDot = dot.clamp(-1.0, 1.0).abs();
      final double angle = (math.acos(clampedDot) * 180.0) / math.pi;
      if (angle < bestAngle) {
        bestAngle = angle;
        bestDir = norm;
      }
    }

    if (bestDir == null) {
      return position;
    }

    final double tolerance =
        _perspectiveSnapAngleTolerance.clamp(0.0, 180.0);
    if (tolerance < 179.9 && bestAngle > tolerance) {
      return position;
    }

    _perspectiveLockedDirection ??= bestDir;
    return _projectOntoDirection(anchor, delta, _perspectiveLockedDirection!);
  }

  List<Offset> _collectPerspectiveDirections(Offset anchor) {
    final List<Offset> directions = <Offset>[];
    // 水平与垂直方向与透视无关，也允许吸附。
    directions.add(const Offset(1.0, 0.0));
    directions.add(const Offset(0.0, 1.0));
    void add(Offset? vp) {
      if (vp == null) {
        return;
      }
      directions.add(vp - anchor);
    }

    switch (_perspectiveMode) {
      case PerspectiveGuideMode.off:
        break;
      case PerspectiveGuideMode.onePoint:
        add(_perspectiveVp1);
        break;
      case PerspectiveGuideMode.twoPoint:
        add(_perspectiveVp1);
        add(_perspectiveVp2 ?? _perspectiveVp1);
        break;
      case PerspectiveGuideMode.threePoint:
        add(_perspectiveVp1);
        add(_perspectiveVp2 ?? _perspectiveVp1);
        add(_perspectiveVp3 ?? _perspectiveVp1);
        break;
    }
    return directions;
  }
}

class _PerspectiveGuidePainter extends CustomPainter {
  _PerspectiveGuidePainter({
    required this.canvasSize,
    required this.vp1,
    required this.vp2,
    required this.vp3,
    required this.mode,
    required this.activeHandle,
  });

  final Size canvasSize;
  final Offset vp1;
  final Offset? vp2;
  final Offset? vp3;
  final PerspectiveGuideMode mode;
  final _PerspectiveHandle? activeHandle;

  static final Paint _linePaint = Paint()
    ..color = const Color(0xFF6BA6FF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  static final Paint _handlePaint = Paint()
    ..color = const Color(0xFF0F6FFF)
    ..style = PaintingStyle.fill;
  static final Paint _handleActivePaint = Paint()
    ..color = const Color(0xFF7CC4FF)
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    _drawGuide(canvas, vp1, size);
    if (mode != PerspectiveGuideMode.onePoint && vp2 != null) {
      _drawGuide(canvas, vp2!, size);
    }
    if (mode == PerspectiveGuideMode.threePoint && vp3 != null) {
      _drawGuide(canvas, vp3!, size);
    }
  }

  void _drawGuide(Canvas canvas, Offset vp, Size size) {
    final List<Offset> targets = <Offset>[
      Offset.zero,
      Offset(size.width, 0),
      Offset(size.width, size.height),
      Offset(0, size.height),
      Offset(size.width * 0.5, size.height * 0.5),
    ];
    final double extent =
        (math.max(size.width, size.height) * 4.0).clamp(1024.0, 16000.0);
    for (final Offset target in targets) {
      final Offset dir = target - vp;
      final double length = dir.distance;
      if (length < 0.0001) {
        continue;
      }
      final Offset norm = dir / length;
      final Offset start = vp - norm * extent;
      final Offset end = vp + norm * extent;
      canvas.drawLine(start, end, _linePaint);
    }
    final bool isActive = _isHandleActive(vp);
    final Paint outline = Paint()
      ..color = isActive ? _handlePaint.color : _handleActivePaint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(vp, 5, isActive ? _handleActivePaint : _handlePaint);
    canvas.drawCircle(vp, 8, outline);
  }

  bool _isHandleActive(Offset vp) {
    switch (activeHandle) {
      case _PerspectiveHandle.vp1:
        return vp == vp1;
      case _PerspectiveHandle.vp2:
        return vp2 != null && vp == vp2;
      case _PerspectiveHandle.vp3:
        return vp3 != null && vp == vp3;
      default:
        return false;
    }
  }

  @override
  bool shouldRepaint(covariant _PerspectiveGuidePainter oldDelegate) {
    return oldDelegate.canvasSize != canvasSize ||
        oldDelegate.vp1 != vp1 ||
        oldDelegate.vp2 != vp2 ||
        oldDelegate.vp3 != vp3 ||
        oldDelegate.mode != mode ||
        oldDelegate.activeHandle != activeHandle;
  }
}

class _PerspectivePenPreviewPainter extends CustomPainter {
  _PerspectivePenPreviewPainter({
    required this.anchor,
    required this.target,
    required this.snapped,
    required this.isValid,
    required this.viewportScale,
  });

  final Offset anchor;
  final Offset target;
  final Offset snapped;
  final bool isValid;
  final double viewportScale;

  static const Color _validColor = Color(0xFF2ECC71);
  static const Color _invalidColor = Color(0xFFE74C3C);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = (isValid ? _validColor : _invalidColor).withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.0 / viewportScale).clamp(1.0, 3.0);
    final Paint anchorPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final Paint anchorOutline = Paint()
      ..color = (isValid ? _validColor : _invalidColor)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.5 / viewportScale).clamp(1.0, 2.0);

    final Offset end = isValid ? snapped : target;
    canvas.drawLine(anchor, end, linePaint);

    final double r = (4.0 / viewportScale).clamp(3.0, 6.0);
    canvas.drawCircle(anchor, r, anchorPaint);
    canvas.drawCircle(anchor, r + 1.0 / viewportScale, anchorOutline);
    canvas.drawCircle(end, r, anchorPaint);
    canvas.drawCircle(end, r + 1.0 / viewportScale, anchorOutline);
  }

  @override
  bool shouldRepaint(covariant _PerspectivePenPreviewPainter oldDelegate) {
    return oldDelegate.anchor != anchor ||
        oldDelegate.target != target ||
        oldDelegate.snapped != snapped ||
        oldDelegate.isValid != isValid ||
        oldDelegate.viewportScale != viewportScale;
  }
}
