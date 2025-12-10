part of 'painting_board.dart';

enum _PerspectiveHandle { vp1, vp2, vp3 }

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

  void _syncPerspectiveFlags() {
    if (_perspectiveMode == PerspectiveGuideMode.off) {
      _perspectiveEnabled = false;
      _perspectiveVisible = false;
      _activePerspectiveHandle = null;
      _hoveringPerspectiveHandle = null;
      _resetPerspectiveLock();
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
      final double clampedDot = dot.clamp(-1.0, 1.0);
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
    final bool forceSnapThisStroke = _perspectiveLockedDirection == null;
    final bool allowSnap = forceSnapThisStroke ||
        tolerance >= 179.9 ||
        bestAngle <= tolerance;
    if (!allowSnap) {
      return position;
    }

    _perspectiveLockedDirection ??= bestDir;
    return _projectOntoDirection(anchor, delta, _perspectiveLockedDirection!);
  }

  List<Offset> _collectPerspectiveDirections(Offset anchor) {
    final List<Offset> directions = <Offset>[];
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
