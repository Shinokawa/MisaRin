part of 'controller.dart';

void _strokeConfigureStylusPressure(
  BitmapCanvasController controller, {
  required bool enabled,
  required double curve,
}) {
  controller._stylusPressureEnabled = enabled;
  controller._stylusCurve = curve.clamp(0.1, 8.0);
}

void _strokeBegin(
  BitmapCanvasController controller,
  Offset position, {
  required Color color,
  required double radius,
  bool simulatePressure = false,
  bool useDevicePressure = false,
  double? pressure,
  double? pressureMin,
  double? pressureMax,
  StrokePressureProfile profile = StrokePressureProfile.auto,
  double? timestampMillis,
  int antialiasLevel = 0,
}) {
  if (controller._activeLayer.locked) {
    return;
  }
  if (controller._selectionMask != null &&
      !controller._selectionAllows(position)) {
    return;
  }
  controller.setStrokePressureProfile(profile);
  controller._currentStrokePoints
    ..clear()
    ..add(position);
  controller._currentStrokeRadius = radius;
  controller._currentStrokeStylusPressureEnabled =
      useDevicePressure && controller._stylusPressureEnabled && !simulatePressure;
  controller._currentStylusCurve = controller._stylusCurve;
  controller._currentStylusLastPressure = null;
  controller._currentStrokeAntialiasLevel = antialiasLevel.clamp(0, 3);
  controller._currentStrokeHasMoved = false;
  final double resolvedTimestamp = timestampMillis ?? 0.0;
  final double? simulatedInitialRadius = controller._strokePressureSimulator
      .beginStroke(
    position: position,
    timestampMillis: resolvedTimestamp,
    baseRadius: radius,
    simulatePressure: simulatePressure,
    useDevicePressure: controller._currentStrokeStylusPressureEnabled,
  );
  double? stylusSeedRadius;
  if (controller._currentStrokeStylusPressureEnabled) {
    final double? normalized = _strokeNormalizeStylusPressure(
      controller,
      pressure,
      pressureMin,
      pressureMax,
    );
    if (normalized != null) {
      controller._currentStylusLastPressure = normalized;
      stylusSeedRadius =
          controller._strokePressureSimulator.seedPressureSample(normalized);
    }
  }
  if (controller._strokePressureSimulator.isSimulatingStroke) {
    controller._currentStrokeLastRadius = stylusSeedRadius ??
        simulatedInitialRadius ??
        controller._currentStrokeRadius;
  } else {
    controller._currentStrokeLastRadius = controller._currentStrokeRadius;
  }
  controller._currentStrokeColor = color;
}

void _strokeExtend(
  BitmapCanvasController controller,
  Offset position, {
  double? deltaTimeMillis,
  double? timestampMillis,
  double? pressure,
  double? pressureMin,
  double? pressureMax,
}) {
  if (controller._currentStrokePoints.isEmpty) {
    return;
  }
  if (controller._activeLayer.locked) {
    return;
  }
  final Offset last = controller._currentStrokePoints.last;
  final bool firstSegment = !controller._currentStrokeHasMoved;
  controller._currentStrokePoints.add(position);
  double? stylusPressure;
  if (controller._currentStrokeStylusPressureEnabled) {
    final double? normalized = _strokeNormalizeStylusPressure(
      controller,
      pressure,
      pressureMin,
      pressureMax,
    );
    if (normalized != null) {
      stylusPressure = normalized;
      controller._currentStylusLastPressure = normalized;
    } else {
      stylusPressure = controller._currentStylusLastPressure;
    }
  }
  if (controller._strokePressureSimulator.isSimulatingStroke) {
    final double? nextRadius = controller._strokePressureSimulator
        .sampleNextRadius(
      lastPosition: last,
      position: position,
      timestampMillis: timestampMillis,
      deltaTimeMillis: deltaTimeMillis,
      normalizedPressure: stylusPressure,
    );
    if (nextRadius == null) {
      return;
    }
    final double resolvedRadius = _strokeResolveSimulatedRadius(
      controller,
      nextRadius,
      preferImmediate: controller._strokePressureSimulator.usesDevicePressure,
    );
    final double segmentLength = (position - last).distance;
    if (_strokeSegmentShouldSnapToPoint(segmentLength, resolvedRadius)) {
      _strokeDrawPoint(controller, position, resolvedRadius);
      controller._currentStrokeHasMoved = true;
      controller._currentStrokeLastRadius = resolvedRadius;
      return;
    }
    final double previousRadius = controller._currentStrokeLastRadius.isFinite &&
            controller._currentStrokeLastRadius > 0.0
        ? controller._currentStrokeLastRadius
        : controller._currentStrokeRadius;
    final bool restartCaps = firstSegment ||
        _strokeNeedsRestartCaps(
          previousRadius,
          resolvedRadius,
        );
    final double startRadius = restartCaps ? resolvedRadius : previousRadius;
    controller._activeSurface.drawVariableLine(
      a: last,
      b: position,
      startRadius: startRadius,
      endRadius: resolvedRadius,
      color: controller._currentStrokeColor,
      mask: controller._selectionMask,
      antialiasLevel: controller._currentStrokeAntialiasLevel,
      includeStartCap: restartCaps,
    );
    assert(() {
      _strokeLogDrawnSegment(
        usesDevicePressure: controller._currentStrokeStylusPressureEnabled,
        normalizedPressure: stylusPressure,
        startRadius: startRadius,
        endRadius: resolvedRadius,
      );
      return true;
    }());
    controller._markDirty(
      region: _strokeDirtyRectForVariableLine(
        last,
        position,
        startRadius,
        nextRadius,
      ),
    );
    controller._currentStrokeHasMoved = true;
    controller._currentStrokeLastRadius = resolvedRadius;
    return;
  }

  controller._activeSurface.drawLine(
    a: last,
    b: position,
    radius: controller._currentStrokeRadius,
    color: controller._currentStrokeColor,
    mask: controller._selectionMask,
    antialiasLevel: controller._currentStrokeAntialiasLevel,
    includeStartCap: firstSegment,
  );
  assert(() {
    _strokeLogDrawnSegment(
      usesDevicePressure: false,
      normalizedPressure: null,
      startRadius: controller._currentStrokeRadius,
      endRadius: controller._currentStrokeRadius,
    );
    return true;
  }());
  controller._markDirty(
    region:
        _strokeDirtyRectForLine(last, position, controller._currentStrokeRadius),
  );
  controller._currentStrokeHasMoved = true;
}

void _strokeLogDrawnSegment({
  required bool usesDevicePressure,
  required double? normalizedPressure,
  required double startRadius,
  required double endRadius,
}) {
  final String pressureLabel = normalizedPressure != null
      ? normalizedPressure.clamp(0.0, 1.0).toStringAsFixed(3)
      : (usesDevicePressure ? 'virtual' : 'fixed');
  debugPrint(
    '[StrokeDraw] device=$usesDevicePressure pressure=$pressureLabel start=${startRadius.toStringAsFixed(3)} end=${endRadius.toStringAsFixed(3)}',
  );
}

void _strokeEnd(BitmapCanvasController controller) {
  if (controller._currentStrokePoints.isEmpty) {
    return;
  }
  final bool hasPath =
      controller._currentStrokeHasMoved &&
      controller._currentStrokePoints.length >= 2;
  final Offset tip = controller._currentStrokePoints.last;

  if (controller._strokePressureSimulator.isSimulatingStroke) {
    final Offset? previousPoint = hasPath &&
            controller._currentStrokePoints.length >= 2
        ? controller._currentStrokePoints[controller._currentStrokePoints.length - 2]
        : null;
    final SimulatedTailInstruction? tailInstruction =
        controller._strokePressureSimulator.buildTail(
      hasPath: hasPath,
      tip: tip,
      previousPoint: previousPoint,
      baseRadius: controller._currentStrokeRadius,
      lastRadius: controller._currentStrokeLastRadius,
    );
    if (tailInstruction != null) {
      if (tailInstruction.isLine) {
        final Offset start = tailInstruction.start!;
        final Offset end = tailInstruction.end!;
        final double startRadius = tailInstruction.startRadius!;
        final double endRadius = tailInstruction.endRadius!;
        controller._activeSurface.drawVariableLine(
          a: start,
          b: end,
          startRadius: startRadius,
          endRadius: endRadius,
          color: controller._currentStrokeColor,
          mask: controller._selectionMask,
          antialiasLevel: controller._currentStrokeAntialiasLevel,
          includeStartCap: true,
        );
        controller._markDirty(
          region: _strokeDirtyRectForVariableLine(
            start,
            end,
            startRadius,
            endRadius,
          ),
        );
      } else if (tailInstruction.isPoint) {
        _strokeDrawPoint(
          controller,
          tailInstruction.point!,
          tailInstruction.pointRadius!,
        );
      }
    }
  }

  if (!controller._currentStrokeStylusPressureEnabled &&
      !controller._strokePressureSimulator.isSimulatingStroke) {
    if (!hasPath) {
      _strokeDrawPoint(controller, tip, controller._currentStrokeRadius);
    }
  }

  controller._currentStrokePoints.clear();
  controller._currentStrokeRadius = 0;
  controller._currentStrokeLastRadius = 0;
  controller._currentStrokeStylusPressureEnabled = false;
  controller._currentStylusLastPressure = null;
  controller._currentStrokeAntialiasLevel = 0;
  controller._currentStrokeHasMoved = false;
  controller._strokePressureSimulator.resetTracking();
}

void _strokeSetPressureProfile(
  BitmapCanvasController controller,
  StrokePressureProfile profile,
) {
  controller._strokePressureSimulator.setProfile(profile);
}

double? _strokeNormalizeStylusPressure(
  BitmapCanvasController controller,
  double? pressure,
  double? pressureMin,
  double? pressureMax,
) {
  if (pressure == null || !pressure.isFinite) {
    return null;
  }
  double lower = pressureMin ?? 0.0;
  double upper = pressureMax ?? 1.0;
  if (!lower.isFinite) {
    lower = 0.0;
  }
  if (!upper.isFinite || upper <= lower) {
    upper = lower + 1.0;
  }
  final double normalized = (pressure - lower) / (upper - lower);
  if (!normalized.isFinite) {
    return null;
  }
  final double curved = math.pow(
    normalized.clamp(0.0, 1.0),
    controller._currentStylusCurve,
  ).toDouble();
  return curved.clamp(0.0, 1.0);
}

bool _strokeNeedsRestartCaps(double previousRadius, double nextRadius) {
  if (!previousRadius.isFinite || !nextRadius.isFinite) {
    return false;
  }
  if (nextRadius <= previousRadius) {
    return false;
  }
  const double kMinimalCoverage = 0.18;
  const double kGrowthRatioThreshold = 1.5;
  if (previousRadius <= kMinimalCoverage) {
    return (nextRadius - previousRadius) > 0.04;
  }
  return nextRadius >= previousRadius * kGrowthRatioThreshold;
}

double _strokeResolveSimulatedRadius(
  BitmapCanvasController controller,
  double candidate, {
  bool preferImmediate = false,
}) {
  final double base = math.max(controller._currentStrokeRadius, 0.05);
  final bool stylusActive = controller._currentStrokeStylusPressureEnabled;
  final double minFactor = stylusActive ? 0.025 : 0.12;
  final double minClamp = stylusActive ? 0.02 : 0.06;
  final double minimum = math.max(base * minFactor, minClamp);
  final double maximum = math.max(base * 4.0, minimum + 0.01);
  double sanitized = candidate.isFinite ? candidate.abs() : base;
  sanitized = sanitized.clamp(minimum, maximum);
  final double previous = controller._currentStrokeLastRadius;
  if (previous.isFinite && previous > 0.0) {
    final double smoothing = preferImmediate
        ? 1.0
        : BitmapCanvasController._kStylusSmoothing;
    final double smoothed = previous +
        (sanitized - previous) * smoothing;
    return smoothed.clamp(minimum, maximum);
  }
  return sanitized;
}

bool _strokeSegmentShouldSnapToPoint(double length, double radius) {
  if (!length.isFinite || !radius.isFinite) {
    return false;
  }
  if (length <= 1e-4) {
    return true;
  }
  const double kShortSegmentRatio = 0.35;
  return length <= radius * kShortSegmentRatio;
}

void _strokeDrawPoint(
  BitmapCanvasController controller,
  Offset position,
  double radius,
) {
  if (controller._activeLayer.locked) {
    return;
  }
  controller._activeSurface.drawCircle(
    center: position,
    radius: radius,
    color: controller._currentStrokeColor,
    mask: controller._selectionMask,
    antialiasLevel: controller._currentStrokeAntialiasLevel,
  );
  controller._markDirty(
    region: _strokeDirtyRectForCircle(position, radius),
  );
}

Rect _strokeDirtyRectForVariableLine(
  Offset a,
  Offset b,
  double startRadius,
  double endRadius,
) {
  final double maxRadius = math.max(math.max(startRadius, endRadius), 0.5);
  return Rect.fromPoints(a, b).inflate(maxRadius + 1.5);
}

Rect _strokeDirtyRectForCircle(Offset center, double radius) {
  final double effectiveRadius = math.max(radius, 0.5);
  return Rect.fromCircle(center: center, radius: effectiveRadius + 1.5);
}

Rect _strokeDirtyRectForLine(Offset a, Offset b, double radius) {
  final double inflate = math.max(radius, 0.5) + 1.5;
  return Rect.fromPoints(a, b).inflate(inflate);
}
