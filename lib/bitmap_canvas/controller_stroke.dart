part of 'controller.dart';

void _strokeConfigureStylusPressure(
  BitmapCanvasController controller, {
  required bool enabled,
  required double minFactor,
  required double maxFactor,
  required double curve,
}) {
  controller._stylusPressureEnabled = enabled;
  final double clampedMin = minFactor.clamp(0.0, maxFactor);
  final double clampedMax = math.max(maxFactor, clampedMin + 0.01);
  final double clampedCurve = curve.clamp(0.1, 8.0);
  controller._stylusMinFactor = clampedMin;
  controller._stylusMaxFactor = clampedMax;
  controller._stylusCurve = clampedCurve;
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
  controller._currentStylusMinFactor = controller._stylusMinFactor;
  controller._currentStylusMaxFactor =
      math.max(controller._stylusMaxFactor, controller._stylusMinFactor);
  controller._currentStylusCurve = controller._stylusCurve;
  controller._currentStylusSmoothedPressure = null;
  controller._currentStrokeAntialiasLevel = antialiasLevel.clamp(0, 3);
  controller._currentStrokeHasMoved = false;
  final double resolvedTimestamp = timestampMillis ?? 0.0;
  final double? simulatedInitialRadius = controller._strokePressureSimulator
      .beginStroke(
    position: position,
    timestampMillis: resolvedTimestamp,
    baseRadius: radius,
    simulatePressure: simulatePressure,
  );
  if (controller._strokePressureSimulator.isSimulatingStroke) {
    controller._currentStrokeLastRadius =
        simulatedInitialRadius ?? controller._currentStrokeRadius;
  } else if (controller._currentStrokeStylusPressureEnabled) {
    final double? normalized = _strokeNormalizeStylusPressure(
      controller,
      pressure,
      pressureMin,
      pressureMax,
    );
    if (normalized != null) {
      controller._currentStylusSmoothedPressure = normalized.clamp(0.0, 1.0);
      controller._currentStrokeLastRadius = _strokeRadiusFromNormalized(
        controller,
        controller._currentStylusSmoothedPressure!,
      );
    } else {
      controller._currentStrokeLastRadius = controller._currentStrokeRadius;
    }
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
  if (controller._strokePressureSimulator.isSimulatingStroke) {
    final double? nextRadius = controller._strokePressureSimulator
        .sampleNextRadius(
      lastPosition: last,
      position: position,
      timestampMillis: timestampMillis,
      deltaTimeMillis: deltaTimeMillis,
    );
    if (nextRadius == null) {
      return;
    }
    final double resolvedRadius = _strokeResolveSimulatedRadius(
      controller,
      nextRadius,
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

  if (controller._currentStrokeStylusPressureEnabled) {
    final double sampleTimestamp = controller._strokePressureSimulator
        .resolveSampleTimestamp(
      timestampMillis,
      deltaTimeMillis,
    );
    controller._strokePressureSimulator.recordSample(position, sampleTimestamp);
    controller._strokePressureSimulator.recordVelocitySample(
      position,
      sampleTimestamp,
    );

    final double? normalized = _strokeNormalizeStylusPressure(
      controller,
      pressure,
      pressureMin,
      pressureMax,
    );
    double nextRadius = controller._currentStrokeRadius;
    if (normalized != null) {
      final double candidate = normalized.clamp(0.0, 1.0);
      final double smoothed = controller._currentStylusSmoothedPressure == null
          ? candidate
          : controller._currentStylusSmoothedPressure! +
              (candidate - controller._currentStylusSmoothedPressure!) *
                  BitmapCanvasController._kStylusSmoothing;
      controller._currentStylusSmoothedPressure = smoothed;
      nextRadius = _strokeRadiusFromNormalized(controller, smoothed);
    }
    final bool restartCaps = firstSegment ||
        _strokeNeedsRestartCaps(
          controller._currentStrokeLastRadius,
          nextRadius,
        );
    double startRadius = controller._currentStrokeLastRadius;
    if (restartCaps) {
      startRadius = nextRadius;
    }
    controller._activeSurface.drawVariableLine(
      a: last,
      b: position,
      startRadius: startRadius,
      endRadius: nextRadius,
      color: controller._currentStrokeColor,
      mask: controller._selectionMask,
      antialiasLevel: controller._currentStrokeAntialiasLevel,
      includeStartCap: restartCaps,
    );
    controller._markDirty(
      region: _strokeDirtyRectForVariableLine(
        last,
        position,
        startRadius,
        nextRadius,
      ),
    );
    controller._currentStrokeHasMoved = true;
    controller._currentStrokeLastRadius = nextRadius;
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
  controller._markDirty(
    region:
        _strokeDirtyRectForLine(last, position, controller._currentStrokeRadius),
  );
  controller._currentStrokeHasMoved = true;
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

  if (controller._currentStrokeStylusPressureEnabled) {
    final double tipRadius = _strokeRadiusFromNormalized(controller, 0.0);
    if (hasPath) {
      final Offset prev =
          controller._currentStrokePoints[controller._currentStrokePoints.length - 2];
      final Offset direction = tip - prev;
      final double length = direction.distance;
      if (length > 0.001) {
        final Offset unit = direction / length;
        final double base = math.max(controller._currentStrokeRadius, 0.1);
        final double taperLength = math.min(base * 4.0, length * 2.0 + 1.5);
        final Offset extension = tip + unit * taperLength;
        final double startRadius = math.max(
          controller._currentStrokeLastRadius,
          tipRadius,
        );
        controller._activeSurface.drawVariableLine(
          a: tip,
          b: extension,
          startRadius: startRadius,
          endRadius: tipRadius,
          color: controller._currentStrokeColor,
          mask: controller._selectionMask,
          antialiasLevel: controller._currentStrokeAntialiasLevel,
          includeStartCap: true,
        );
        controller._markDirty(
          region: _strokeDirtyRectForVariableLine(
            tip,
            extension,
            startRadius,
            tipRadius,
          ),
        );
      } else {
        _strokeDrawPoint(controller, tip, tipRadius);
      }
    } else {
      _strokeDrawPoint(controller, tip, tipRadius);
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
  controller._currentStylusSmoothedPressure = null;
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
  return normalized.clamp(0.0, 1.0);
}

double _strokeRadiusFromNormalized(
  BitmapCanvasController controller,
  double normalized,
) {
  final double clamped = normalized.clamp(0.0, 1.0);
  final double curved = math.pow(clamped, controller._currentStylusCurve).toDouble();
  final double minFactor = controller._currentStylusMinFactor.clamp(0.0, 10.0);
  final double maxFactor = math.max(
    controller._currentStylusMaxFactor,
    minFactor + 0.01,
  );
  final double? lerped = ui.lerpDouble(minFactor, maxFactor, curved);
  final double factor = (lerped ?? maxFactor).clamp(0.0, 20.0);
  final double radius = controller._currentStrokeRadius * factor;
  final double minimum = math.max(controller._currentStrokeRadius * 0.02, 0.08);
  final double maximum = math.max(controller._currentStrokeRadius * 4.0, minimum);
  return radius.clamp(minimum, maximum);
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
  double candidate,
) {
  final double base = math.max(controller._currentStrokeRadius, 0.05);
  final double minimum = math.max(base * 0.12, 0.06);
  final double maximum = math.max(base * 4.0, minimum + 0.01);
  double sanitized = candidate.isFinite ? candidate.abs() : base;
  sanitized = sanitized.clamp(minimum, maximum);
  final double previous = controller._currentStrokeLastRadius;
  if (previous.isFinite && previous > 0.0) {
    final double smoothed = previous +
        (sanitized - previous) * BitmapCanvasController._kStylusSmoothing;
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
