part of 'controller.dart';

const double _kStylusAbsoluteMinRadius = 0.005;
const double _kSimulatedAbsoluteMinRadius = 0.01;
const double _kAbsoluteMaxStrokeRadius = 512.0;

void _strokeConfigureStylusPressure(
  BitmapCanvasController controller, {
  required bool enabled,
  required double curve,
}) {
  controller._stylusPressureEnabled = enabled;
  controller._stylusCurve = curve.clamp(0.1, 8.0);
}

void _strokeConfigureSharpTips(
  BitmapCanvasController controller, {
  required bool enabled,
}) {
  controller._strokePressureSimulator.setSharpTipsEnabled(enabled);
}

void _strokeBegin(
  BitmapCanvasController controller,
  Offset position, {
  required Color color,
  required double radius,
  bool simulatePressure = false,
  bool useDevicePressure = false,
  double stylusPressureBlend = 1.0,
  double? pressure,
  double? pressureMin,
  double? pressureMax,
  StrokePressureProfile profile = StrokePressureProfile.auto,
  double? timestampMillis,
  int antialiasLevel = 0,
  BrushShape brushShape = BrushShape.circle,
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
  final double effectiveStylusBlend =
      controller._currentStrokeStylusPressureEnabled
      ? stylusPressureBlend.clamp(0.0, 1.0)
      : 0.0;
  controller._currentStrokeStylusPressureEnabled =
      useDevicePressure && controller._stylusPressureEnabled;
  controller._currentStylusCurve = controller._stylusCurve;
  controller._currentStylusLastPressure = null;
  controller._currentStrokeAntialiasLevel = antialiasLevel.clamp(0, 3);
  controller._currentStrokeHasMoved = false;
  controller._currentBrushShape = brushShape;
  final double resolvedTimestamp = timestampMillis ?? 0.0;
  final double? simulatedInitialRadius = controller._strokePressureSimulator
      .beginStroke(
        position: position,
        timestampMillis: resolvedTimestamp,
        baseRadius: radius,
        simulatePressure: simulatePressure,
        useDevicePressure: controller._currentStrokeStylusPressureEnabled,
        stylusPressureBlend: effectiveStylusBlend,
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
      stylusSeedRadius = controller._strokePressureSimulator.seedPressureSample(
        normalized,
      );
    }
  }
  if (controller._strokePressureSimulator.isSimulatingStroke) {
    controller._currentStrokeLastRadius =
        stylusSeedRadius ??
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
  final bool useCircularBrush =
      controller._currentBrushShape == BrushShape.circle;
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
    final double previousRadius =
        controller._currentStrokeLastRadius.isFinite &&
            controller._currentStrokeLastRadius > 0.0
        ? controller._currentStrokeLastRadius
        : controller._currentStrokeRadius;
    final bool restartCaps =
        firstSegment || _strokeNeedsRestartCaps(previousRadius, resolvedRadius);
    final double startRadius = restartCaps ? resolvedRadius : previousRadius;
    if (useCircularBrush) {
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
    } else {
      _strokeStampSegment(
        controller,
        last,
        position,
        startRadius: startRadius,
        endRadius: resolvedRadius,
        includeStart: restartCaps,
      );
    }
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

  if (useCircularBrush) {
    controller._activeSurface.drawLine(
      a: last,
      b: position,
      radius: controller._currentStrokeRadius,
      color: controller._currentStrokeColor,
      mask: controller._selectionMask,
      antialiasLevel: controller._currentStrokeAntialiasLevel,
      includeStartCap: firstSegment,
    );
  } else {
    _strokeStampSegment(
      controller,
      last,
      position,
      startRadius: controller._currentStrokeRadius,
      endRadius: controller._currentStrokeRadius,
      includeStart: firstSegment,
    );
  }
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
    region: _strokeDirtyRectForLine(
      last,
      position,
      controller._currentStrokeRadius,
    ),
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
    final Offset? previousPoint =
        hasPath && controller._currentStrokePoints.length >= 2
        ? controller
              ._currentStrokePoints[controller._currentStrokePoints.length - 2]
        : null;
    final SimulatedTailInstruction? tailInstruction = controller
        ._strokePressureSimulator
        .buildTail(
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
  final double curved = math
      .pow(normalized.clamp(0.0, 1.0), controller._currentStylusCurve)
      .toDouble();
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
  final bool stylusActive = controller._currentStrokeStylusPressureEnabled;
  final double baseRadius = controller._currentStrokeRadius.isFinite
      ? controller._currentStrokeRadius.abs()
      : 0.0;
  final double minFactor = stylusActive ? 0.01 : 0.12;
  final double minClamp = stylusActive
      ? _kStylusAbsoluteMinRadius
      : _kSimulatedAbsoluteMinRadius;
  final double minimum = math.max(baseRadius * minFactor, minClamp);
  final double maxFactor = stylusActive ? 5.0 : 4.5;
  final double maximum = math.min(
    math.max(baseRadius * maxFactor, minimum + 0.005),
    _kAbsoluteMaxStrokeRadius,
  );
  double sanitized = candidate.isFinite ? candidate.abs() : baseRadius;
  sanitized = sanitized.clamp(minimum, maximum);
  final double previous = controller._currentStrokeLastRadius;
  if (previous.isFinite && previous > 0.0) {
    final double smoothing = preferImmediate
        ? 1.0
        : BitmapCanvasController._kStylusSmoothing;
    final double smoothed = previous + (sanitized - previous) * smoothing;
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
  final double resolvedRadius = math.max(radius.abs(), 0.01);
  final BrushShape brushShape = controller._currentBrushShape;
  if (brushShape == BrushShape.circle) {
    controller._activeSurface.drawCircle(
      center: position,
      radius: resolvedRadius,
      color: controller._currentStrokeColor,
      mask: controller._selectionMask,
      antialiasLevel: controller._currentStrokeAntialiasLevel,
    );
  } else {
    controller._activeSurface.drawBrushStamp(
      center: position,
      radius: resolvedRadius,
      color: controller._currentStrokeColor,
      shape: brushShape,
      mask: controller._selectionMask,
      antialiasLevel: controller._currentStrokeAntialiasLevel,
    );
  }
  controller._markDirty(
    region: _strokeDirtyRectForCircle(position, resolvedRadius),
  );
}

void _strokeStampSegment(
  BitmapCanvasController controller,
  Offset start,
  Offset end, {
  required double startRadius,
  required double endRadius,
  required bool includeStart,
}) {
  final double distance = (end - start).distance;
  if (!distance.isFinite || distance <= 0.0001) {
    _strokeDrawPoint(controller, end, endRadius);
    return;
  }
  final double maxRadius = math.max(
    math.max(startRadius.abs(), endRadius.abs()),
    0.01,
  );
  final double spacing = _strokeStampSpacing(maxRadius);
  final int samples = math.max(1, (distance / spacing).ceil());
  final int startIndex = includeStart ? 0 : 1;
  for (int i = startIndex; i <= samples; i++) {
    final double t = samples == 0 ? 1.0 : (i / samples);
    final double lerpRadius =
        ui.lerpDouble(startRadius, endRadius, t) ?? endRadius;
    final double sampleX = ui.lerpDouble(start.dx, end.dx, t) ?? end.dx;
    final double sampleY = ui.lerpDouble(start.dy, end.dy, t) ?? end.dy;
    _strokeDrawPoint(controller, Offset(sampleX, sampleY), lerpRadius);
  }
}

double _strokeStampSpacing(double radius) {
  if (!radius.isFinite) {
    return 0.5;
  }
  return math.max(0.5, radius * 0.55);
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
