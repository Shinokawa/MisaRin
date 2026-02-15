part of 'controller.dart';

const bool _kDebugRustWgpuBrushTiles =
    bool.fromEnvironment(
      'MISA_RIN_DEBUG_RUST_WGPU_BRUSH_TILES',
      defaultValue: false,
    ) ||
    bool.fromEnvironment(
      'MISA_RIN_DEBUG_GPU_BRUSH_TILES',
      defaultValue: false,
    );

class _RustWgpuStrokeDrawData {
  const _RustWgpuStrokeDrawData({
    required this.points,
    required this.radii,
    required this.color,
    required this.brushShape,
    required this.erase,
    required this.antialiasLevel,
    required this.hollow,
    required this.hollowRatio,
    required this.eraseOccludedParts,
  });

  final List<Offset> points;
  final List<double> radii;
  final Color color;
  final BrushShape brushShape;
  final bool erase;
  final int antialiasLevel;
  final bool hollow;
  final double hollowRatio;
  final bool eraseOccludedParts;
}

_RustWgpuStrokeDrawData? _controllerRustWgpuStrokeFromCommand(
  PaintingDrawCommand command, {
  required bool hollow,
  required double hollowRatio,
  required bool eraseOccludedParts,
}) {
  final bool erase = command.erase;
  final int antialiasLevel = command.antialiasLevel.clamp(0, 9);

  switch (command.type) {
    case PaintingDrawCommandType.brushStamp: {
      final Offset? center = command.center;
      final double? radius = command.radius;
      final int? shapeIndex = command.shapeIndex;
      if (center == null || radius == null || shapeIndex == null) {
        return null;
      }
      final int clamped = shapeIndex.clamp(0, BrushShape.values.length - 1);
      return _RustWgpuStrokeDrawData(
        points: <Offset>[center],
        radii: <double>[radius.abs()],
        color: Color(command.color),
        brushShape: BrushShape.values[clamped],
        erase: erase,
        antialiasLevel: antialiasLevel,
        hollow: hollow && !erase,
        hollowRatio: hollowRatio,
        eraseOccludedParts: hollow && !erase && eraseOccludedParts,
      );
    }
    case PaintingDrawCommandType.line: {
      final Offset? start = command.start;
      final Offset? end = command.end;
      final double? radius = command.radius;
      if (start == null || end == null || radius == null) {
        return null;
      }
      final double resolved = radius.abs();
      return _RustWgpuStrokeDrawData(
        points: <Offset>[start, end],
        radii: <double>[resolved, resolved],
        color: Color(command.color),
        brushShape: BrushShape.circle,
        erase: erase,
        antialiasLevel: antialiasLevel,
        hollow: hollow && !erase,
        hollowRatio: hollowRatio,
        eraseOccludedParts: hollow && !erase && eraseOccludedParts,
      );
    }
    case PaintingDrawCommandType.variableLine: {
      final Offset? start = command.start;
      final Offset? end = command.end;
      final double? startRadius = command.startRadius;
      final double? endRadius = command.endRadius;
      if (start == null || end == null || startRadius == null || endRadius == null) {
        return null;
      }
      return _RustWgpuStrokeDrawData(
        points: <Offset>[start, end],
        radii: <double>[startRadius.abs(), endRadius.abs()],
        color: Color(command.color),
        brushShape: BrushShape.circle,
        erase: erase,
        antialiasLevel: antialiasLevel,
        hollow: hollow && !erase,
        hollowRatio: hollowRatio,
        eraseOccludedParts: hollow && !erase && eraseOccludedParts,
      );
    }
    case PaintingDrawCommandType.stampSegment: {
      final Offset? start = command.start;
      final Offset? end = command.end;
      final double? startRadius = command.startRadius;
      final double? endRadius = command.endRadius;
      final int? shapeIndex = command.shapeIndex;
      if (start == null ||
          end == null ||
          startRadius == null ||
          endRadius == null ||
          shapeIndex == null) {
        return null;
      }
      final int clamped = shapeIndex.clamp(0, BrushShape.values.length - 1);
      return _RustWgpuStrokeDrawData(
        points: <Offset>[start, end],
        radii: <double>[startRadius.abs(), endRadius.abs()],
        color: Color(command.color),
        brushShape: BrushShape.values[clamped],
        erase: erase,
        antialiasLevel: antialiasLevel,
        hollow: hollow && !erase,
        hollowRatio: hollowRatio,
        eraseOccludedParts: hollow && !erase && eraseOccludedParts,
      );
    }
    case PaintingDrawCommandType.vectorStroke: {
      final List<Offset>? points = command.points;
      final List<double>? radii = command.radii;
      final int? shapeIndex = command.shapeIndex;
      if (points == null || radii == null || shapeIndex == null) {
        return null;
      }
      final int clamped = shapeIndex.clamp(0, BrushShape.values.length - 1);
      final bool resolvedHollow = (command.hollow ?? false) && !erase;
      final bool resolvedEraseOccludedParts =
          resolvedHollow && (command.eraseOccludedParts ?? false);
      return _RustWgpuStrokeDrawData(
        points: List<Offset>.from(points),
        radii: List<double>.from(radii),
        color: Color(command.color),
        brushShape: BrushShape.values[clamped],
        erase: erase,
        antialiasLevel: antialiasLevel,
        hollow: resolvedHollow,
        hollowRatio: resolvedHollow ? (command.hollowRatio ?? 0.0) : 0.0,
        eraseOccludedParts: resolvedEraseOccludedParts,
      );
    }
    case PaintingDrawCommandType.filledPolygon:
      return null;
  }
}

void _controllerFlushDeferredStrokeCommands(
  BitmapCanvasController controller,
) {
  PaintingDrawCommand? committingOverlayCommand;
  if (controller._currentStrokePoints.isNotEmpty &&
      controller._currentStrokePoints.length ==
          controller._currentStrokeRadii.length) {
    final PaintingDrawCommand command = PaintingDrawCommand.vectorStroke(
      points: List<Offset>.from(controller._currentStrokePoints),
      radii: List<double>.from(controller._currentStrokeRadii),
      colorValue: controller._currentStrokeColor.value,
      shapeIndex: controller._currentBrushShape.index,
      antialiasLevel: controller._currentStrokeAntialiasLevel,
      erase: controller._currentStrokeEraseMode,
      hollow: controller._currentStrokeHollowEnabled,
      hollowRatio: controller._currentStrokeHollowRatio,
      eraseOccludedParts: controller._currentStrokeEraseOccludedParts,
      randomRotation: controller._currentStrokeRandomRotationEnabled,
      rotationSeed: controller._currentStrokeRotationSeed,
    );
    controller._committingStrokes.add(command);
    controller._notify();
    committingOverlayCommand = command;
  }

  final PaintingDrawCommand? overlayCommand = committingOverlayCommand;
  if (overlayCommand != null) {
    final bool hollow = (overlayCommand.hollow ?? false) &&
        !overlayCommand.erase &&
        (overlayCommand.hollowRatio ?? 0.0) > 0.0001;
    final bool eraseOccludedParts = overlayCommand.eraseOccludedParts ?? false;

    if (hollow && !eraseOccludedParts) {
      controller._deferredStrokeCommands.clear();
      controller._currentStrokePoints.clear();
      controller._currentStrokeRadii.clear();

      unawaited(() async {
        try {
          await _controllerDrawStrokeOnRustWgpu(
            controller,
            layerId: controller._activeLayer.id,
            points: overlayCommand.points ?? const <Offset>[],
            radii: overlayCommand.radii ?? const <double>[],
            color: Color(overlayCommand.color),
            brushShape: BrushShape.values[overlayCommand.shapeIndex ?? 0],
            erase: overlayCommand.erase,
            antialiasLevel: overlayCommand.antialiasLevel,
            hollow: true,
            hollowRatio: overlayCommand.hollowRatio ?? 0.0,
            eraseOccludedParts: false,
          );
        } finally {
          controller._committingStrokes.remove(overlayCommand);
          controller._notify();
        }
      }());
      return;
    }
  }

  controller._commitDeferredStrokeCommandsAsRaster();
  if (overlayCommand != null) {
    unawaited(
      controller._enqueueRustWgpuBrushTask<void>(() async {}).whenComplete(() {
        controller._committingStrokes.remove(overlayCommand);
        controller._notify();
      }),
    );
  }
}

Future<void> _controllerDrawStrokeOnRustWgpu(
  BitmapCanvasController controller, {
  required String layerId,
  required List<Offset> points,
  required List<double> radii,
  required Color color,
  required BrushShape brushShape,
  required bool erase,
  required int antialiasLevel,
  bool eraseOccludedParts = false,
  bool hollow = false,
  double hollowRatio = 0.0,
}) async {
  if (points.isEmpty) {
    return;
  }
  if (points.length != radii.length) {
    throw StateError('Rust WGPU 笔触 points/radii 长度不一致');
  }

  await controller._enqueueRustWgpuBrushTask<void>(() async {
    final int layerIndex = controller._layers.indexWhere(
      (BitmapLayerState layer) => layer.id == layerId,
    );
    if (layerIndex < 0) {
      return;
    }
    final BitmapLayerState layer = controller._layers[layerIndex];
    if (layer.locked) {
      return;
    }

    final int canvasWidth = controller._width;
    final int canvasHeight = controller._height;
    final int aa = antialiasLevel.clamp(0, 9);
    final Uint8List? mask = controller._selectionMask;

    Rect computeDirtyRect() {
      if (points.isEmpty) {
        return Rect.zero;
      }
      if (points.length == 1) {
        return _strokeDirtyRectForCircle(points[0], radii[0]);
      }
      Rect dirty = _strokeDirtyRectForVariableLine(
        points[0],
        points[1],
        radii[0],
        radii[1],
      );
      for (int i = 1; i < points.length - 1; i++) {
        dirty = BitmapCanvasController._unionRects(
          dirty,
          _strokeDirtyRectForVariableLine(
            points[i],
            points[i + 1],
            radii[i],
            radii[i + 1],
          ),
        );
      }
      return dirty;
    }

    final Rect dirty = computeDirtyRect();
    if (dirty.isEmpty) {
      return;
    }
    final Rect canvasRect = Rect.fromLTWH(
      0,
      0,
      canvasWidth.toDouble(),
      canvasHeight.toDouble(),
    );
    final Rect clipped = dirty.intersect(canvasRect);
    if (clipped.isEmpty) {
      return;
    }

    final int outerLeft = clipped.left.floor().clamp(0, canvasWidth);
    final int outerTop = clipped.top.floor().clamp(0, canvasHeight);
    final int outerRight = clipped.right.ceil().clamp(0, canvasWidth);
    final int outerBottom = clipped.bottom.ceil().clamp(0, canvasHeight);
    final int copyW = outerRight - outerLeft;
    final int copyH = outerBottom - outerTop;
    if (copyW <= 0 || copyH <= 0) {
      return;
    }

    final BitmapSurface surface = layer.surface;
    final Uint32List destination = surface.pixels;

    void drawStrokeOnSurface({
      required Color strokeColor,
      required List<double> strokeRadii,
      required bool eraseMode,
    }) {
      if (points.length == 1) {
        surface.drawBrushStamp(
          center: points[0],
          radius: strokeRadii[0],
          color: strokeColor,
          shape: brushShape,
          mask: mask,
          antialiasLevel: aa,
          erase: eraseMode,
        );
        return;
      }

      for (int i = 0; i < points.length - 1; i++) {
        _controllerApplyStampSegmentFallback(
          surface: surface,
          start: points[i],
          end: points[i + 1],
          startRadius: strokeRadii[i],
          endRadius: strokeRadii[i + 1],
          includeStart: i == 0,
          shape: brushShape,
          color: strokeColor,
          mask: mask,
          antialias: aa,
          erase: eraseMode,
        );
      }
    }

    final bool resolvedHollow = hollow && !erase && hollowRatio > 0.0001;
    final bool resolvedEraseOccludedParts =
        resolvedHollow && eraseOccludedParts;

    Uint32List? before;
    if (resolvedHollow && !resolvedEraseOccludedParts) {
      before = Uint32List(copyW * copyH);
      for (int row = 0; row < copyH; row++) {
        final int srcOffset = (outerTop + row) * canvasWidth + outerLeft;
        final int dstOffset = row * copyW;
        before.setRange(dstOffset, dstOffset + copyW, destination, srcOffset);
      }
    }

    drawStrokeOnSurface(
      strokeColor: color,
      strokeRadii: radii,
      eraseMode: erase,
    );

    if (!resolvedHollow) {
      surface.markDirty();
      controller._resetWorkerSurfaceSync();
      controller._markDirty(
        region: Rect.fromLTRB(
          outerLeft.toDouble(),
          outerTop.toDouble(),
          outerRight.toDouble(),
          outerBottom.toDouble(),
        ),
        layerId: layerId,
        pixelsDirty: true,
      );
      controller._rustWgpuBrushSyncedRevisions[layerId] = layer.revision;
      return;
    }

    final List<double> scaledRadii = radii
        .map((double radius) => radius * hollowRatio.clamp(0.0, 1.0))
        .toList(growable: false);

    if (resolvedEraseOccludedParts) {
      drawStrokeOnSurface(
        strokeColor: const Color(0xFFFFFFFF),
        strokeRadii: scaledRadii,
        eraseMode: true,
      );
      surface.markDirty();
      controller._resetWorkerSurfaceSync();
      controller._markDirty(
        region: Rect.fromLTRB(
          outerLeft.toDouble(),
          outerTop.toDouble(),
          outerRight.toDouble(),
          outerBottom.toDouble(),
        ),
        layerId: layerId,
        pixelsDirty: true,
      );
      controller._rustWgpuBrushSyncedRevisions[layerId] = layer.revision;
      return;
    }

    int lerpPremultiplied(int from, int to, double t) {
      final double clamped = t.clamp(0.0, 1.0);
      if (clamped <= 0.000001) {
        return from;
      }
      if (clamped >= 0.999999) {
        return to;
      }

      final int a0 = (from >> 24) & 0xff;
      final int r0 = (from >> 16) & 0xff;
      final int g0 = (from >> 8) & 0xff;
      final int b0 = from & 0xff;
      final int a1 = (to >> 24) & 0xff;
      final int r1 = (to >> 16) & 0xff;
      final int g1 = (to >> 8) & 0xff;
      final int b1 = to & 0xff;

      final double fa0 = a0 / 255.0;
      final double fa1 = a1 / 255.0;
      final double pr0 = (r0 / 255.0) * fa0;
      final double pg0 = (g0 / 255.0) * fa0;
      final double pb0 = (b0 / 255.0) * fa0;
      final double pr1 = (r1 / 255.0) * fa1;
      final double pg1 = (g1 / 255.0) * fa1;
      final double pb1 = (b1 / 255.0) * fa1;

      final double inv = 1.0 - clamped;
      final double fa = fa0 * inv + fa1 * clamped;
      final double pr = pr0 * inv + pr1 * clamped;
      final double pg = pg0 * inv + pg1 * clamped;
      final double pb = pb0 * inv + pb1 * clamped;

      if (fa <= 0.000001) {
        return 0;
      }
      final double invA = 1.0 / fa;
      final int outA = (fa * 255.0).round().clamp(0, 255);
      final int outR = ((pr * invA) * 255.0).round().clamp(0, 255);
      final int outG = ((pg * invA) * 255.0).round().clamp(0, 255);
      final int outB = ((pb * invA) * 255.0).round().clamp(0, 255);
      return (outA << 24) | (outR << 16) | (outG << 8) | outB;
    }

    final Uint32List outerAfter = Uint32List(copyW * copyH);
    for (int row = 0; row < copyH; row++) {
      final int srcOffset = (outerTop + row) * canvasWidth + outerLeft;
      final int dstOffset = row * copyW;
      outerAfter.setRange(dstOffset, dstOffset + copyW, destination, srcOffset);
    }

    drawStrokeOnSurface(
      strokeColor: const Color(0xFFFFFFFF),
      strokeRadii: scaledRadii,
      eraseMode: true,
    );

    final Uint32List beforeResolved = before ?? Uint32List(0);
    for (int y = outerTop; y < outerBottom; y++) {
      final int outerRow = (y - outerTop) * copyW;
      final int destRow = y * canvasWidth;
      for (int x = outerLeft; x < outerRight; x++) {
        final int outerIndex = outerRow + (x - outerLeft);
        final int destIndex = destRow + x;

        final int o = outerAfter[outerIndex];
        final int oa = (o >> 24) & 0xff;
        if (oa == 0) {
          continue;
        }
        final int e = destination[destIndex];
        final int ea = (e >> 24) & 0xff;
        if (ea >= oa) {
          continue;
        }

        final double coverage = (1.0 - (ea / oa)).clamp(0.0, 1.0);
        if (coverage <= 0.000001) {
          continue;
        }
        final int b = beforeResolved[outerIndex];
        destination[destIndex] = lerpPremultiplied(o, b, coverage);
      }
    }

    surface.markDirty();
    controller._resetWorkerSurfaceSync();
    controller._markDirty(
      region: Rect.fromLTRB(
        outerLeft.toDouble(),
        outerTop.toDouble(),
        outerRight.toDouble(),
        outerBottom.toDouble(),
      ),
      layerId: layerId,
      pixelsDirty: true,
    );
    controller._rustWgpuBrushSyncedRevisions[layerId] = layer.revision;
  });
}

void _controllerFlushRealtimeStrokeCommands(
  BitmapCanvasController controller,
) {
  if (controller._currentStrokeDeferRaster) {
    return;
  }
  if (controller._currentStrokeHollowEnabled &&
      !controller._currentStrokeEraseOccludedParts) {
    return;
  }
  controller._commitDeferredStrokeCommandsAsRaster(keepStrokeState: true);
}

void _controllerCommitDeferredStrokeCommandsAsRaster(
  BitmapCanvasController controller, {
  bool keepStrokeState = false,
}) {
  if (controller._deferredStrokeCommands.isEmpty) {
    if (!keepStrokeState) {
      controller._currentStrokePoints.clear();
      controller._currentStrokeRadii.clear();
    }
    return;
  }
  final List<PaintingDrawCommand> commands = List<PaintingDrawCommand>.from(
    controller._deferredStrokeCommands,
  );
  controller._deferredStrokeCommands.clear();
  final bool hollow = controller._currentStrokeHollowEnabled;
  final double hollowRatio = controller._currentStrokeHollowRatio;
  final bool eraseOccludedParts = controller._currentStrokeEraseOccludedParts;

  for (final PaintingDrawCommand command in commands) {
    final _RustWgpuStrokeDrawData? stroke = _controllerRustWgpuStrokeFromCommand(
      command,
      hollow: hollow,
      hollowRatio: hollowRatio,
      eraseOccludedParts: eraseOccludedParts,
    );
    if (stroke == null) {
      final Rect? bounds = controller._dirtyRectForCommand(command);
      if (bounds == null || bounds.isEmpty) {
        continue;
      }
      controller._applyPaintingCommandsSynchronously(
        bounds,
        <PaintingDrawCommand>[command],
      );
      continue;
    }
    unawaited(
      _controllerDrawStrokeOnRustWgpu(
        controller,
        layerId: controller._activeLayer.id,
        points: stroke.points,
        radii: stroke.radii,
        color: stroke.color,
        brushShape: stroke.brushShape,
        erase: stroke.erase,
        antialiasLevel: stroke.antialiasLevel,
        hollow: stroke.hollow,
        hollowRatio: stroke.hollowRatio,
        eraseOccludedParts: stroke.eraseOccludedParts,
      ),
    );
  }
  if (!keepStrokeState) {
    controller._currentStrokePoints.clear();
    controller._currentStrokeRadii.clear();
  }
}

void _controllerDispatchDirectPaintCommand(
  BitmapCanvasController controller,
  PaintingDrawCommand command,
) {
  final Rect? bounds = controller._dirtyRectForCommand(command);
  if (bounds == null || bounds.isEmpty) {
    return;
  }
  final _RustWgpuStrokeDrawData? stroke = _controllerRustWgpuStrokeFromCommand(
    command,
    hollow: false,
    hollowRatio: 0.0,
    eraseOccludedParts: false,
  );
  if (stroke == null) {
    controller._applyPaintingCommandsSynchronously(
      bounds,
      <PaintingDrawCommand>[command],
    );
    return;
  }
  unawaited(
    _controllerDrawStrokeOnRustWgpu(
      controller,
      layerId: controller._activeLayer.id,
      points: stroke.points,
      radii: stroke.radii,
      color: stroke.color,
      brushShape: stroke.brushShape,
      erase: stroke.erase,
      antialiasLevel: stroke.antialiasLevel,
      eraseOccludedParts: stroke.eraseOccludedParts,
      hollow: false,
      hollowRatio: 0.0,
    ),
  );
}

Rect? _controllerDirtyRectForCommand(
  BitmapCanvasController controller,
  PaintingDrawCommand command,
) {
  switch (command.type) {
    case PaintingDrawCommandType.brushStamp:
      final Offset? center = command.center;
      final double? radius = command.radius;
      if (center == null || radius == null) {
        return null;
      }
      final double softness = (command.softness ?? 0.0).clamp(0.0, 1.0);
      final double expandedRadius = softness > 0
          ? radius + radius * softBrushExtentMultiplier(softness)
          : radius;
      return _strokeDirtyRectForCircle(center, expandedRadius);
    case PaintingDrawCommandType.line:
      final Offset? start = command.start;
      final Offset? end = command.end;
      final double? radius = command.radius;
      if (start == null || end == null || radius == null) {
        return null;
      }
      return _strokeDirtyRectForLine(start, end, radius);
    case PaintingDrawCommandType.variableLine:
      final Offset? start = command.start;
      final Offset? end = command.end;
      final double? startRadius = command.startRadius;
      final double? endRadius = command.endRadius;
      if (start == null ||
          end == null ||
          startRadius == null ||
          endRadius == null) {
        return null;
      }
      return _strokeDirtyRectForVariableLine(
        start,
        end,
        startRadius,
        endRadius,
      );
    case PaintingDrawCommandType.stampSegment:
      final Offset? start = command.start;
      final Offset? end = command.end;
      final double? startRadius = command.startRadius;
      final double? endRadius = command.endRadius;
      if (start == null ||
          end == null ||
          startRadius == null ||
          endRadius == null) {
        return null;
      }
      return _strokeDirtyRectForVariableLine(
        start,
        end,
        startRadius,
        endRadius,
      );
    case PaintingDrawCommandType.vectorStroke:
      return null;
    case PaintingDrawCommandType.filledPolygon:
      final List<Offset>? polygon = command.points;
      if (polygon == null || polygon.length < 3) {
        return null;
      }
      double minX = polygon.first.dx;
      double maxX = polygon.first.dx;
      double minY = polygon.first.dy;
      double maxY = polygon.first.dy;
      for (final Offset point in polygon) {
        if (point.dx < minX) minX = point.dx;
        if (point.dx > maxX) maxX = point.dx;
        if (point.dy < minY) minY = point.dy;
        if (point.dy > maxY) maxY = point.dy;
      }
      final double padding = 2.0 + command.antialiasLevel.clamp(0, 9) * 1.2;
      return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(padding);
  }
}

void _controllerApplyRustWgpuStrokeResult(
  BitmapCanvasController controller, {
  required String layerId,
  required rust_wgpu_brush.RustWgpuStrokeResult result,
}) {
  // Deprecated: Rust WGPU brush no longer returns pixel patches (Flow 5 hard ban).
  // Keep the symbol to avoid large refactors; call sites have been removed.
  // ignore: unused_local_variable
  final _ = result;
}

int _controllerUnpremultiplyChannel(int value, int alpha) {
  if (alpha <= 0) {
    return 0;
  }
  if (alpha >= 255) {
    return value;
  }
  final int result = ((value * 255) + (alpha >> 1)) ~/ alpha;
  if (result < 0) {
    return 0;
  }
  if (result > 255) {
    return 255;
  }
  return result;
}

bool _controllerMergeVectorPatchOnMainThread(
  BitmapCanvasController controller, {
  required Uint8List rgbaPixels,
  required int left,
  required int top,
  required int width,
  required int height,
  required bool erase,
  required bool eraseOccludedParts,
}) {
  if (width <= 0 || height <= 0 || rgbaPixels.isEmpty) {
    return false;
  }
  final int clampedLeft = math.max(0, math.min(left, controller._width));
  final int clampedTop = math.max(0, math.min(top, controller._height));
  final int clampedRight =
      math.max(0, math.min(left + width, controller._width));
  final int clampedBottom =
      math.max(0, math.min(top + height, controller._height));
  if (clampedRight <= clampedLeft || clampedBottom <= clampedTop) {
    return false;
  }

  final Uint32List destination = controller._activeSurface.pixels;
  final Uint8List? mask = controller._selectionMask;
  bool anyChange = false;

  for (int y = 0; y < height; y++) {
    final int surfaceY = top + y;
    if (surfaceY < 0 || surfaceY >= controller._height) {
      continue;
    }
    final int surfaceRowOffset = surfaceY * controller._width;
    final int rgbaRowOffset = y * width * 4;

    for (int x = 0; x < width; x++) {
      final int surfaceX = left + x;
      if (surfaceX < 0 || surfaceX >= controller._width) {
        continue;
      }
      if (mask != null && mask[surfaceRowOffset + surfaceX] == 0) {
        continue;
      }

      final int rgbaIndex = rgbaRowOffset + x * 4;
      if (rgbaIndex + 3 >= rgbaPixels.length) {
        continue;
      }
      final int a = rgbaPixels[rgbaIndex + 3];
      if (a == 0) {
        continue;
      }

      final int r = rgbaPixels[rgbaIndex];
      final int g = rgbaPixels[rgbaIndex + 1];
      final int b = rgbaPixels[rgbaIndex + 2];
      final int destIndex = surfaceRowOffset + surfaceX;
      final int dstColor = destination[destIndex];
      final int dstA = (dstColor >> 24) & 0xff;
      final int dstR = (dstColor >> 16) & 0xff;
      final int dstG = (dstColor >> 8) & 0xff;
      final int dstB = dstColor & 0xff;

      if (erase) {
        final double alphaFactor = 1.0 - (a / 255.0);
        final int outA = (dstA * alphaFactor).round();
        destination[destIndex] =
            (outA << 24) | (dstR << 16) | (dstG << 8) | dstB;
        anyChange = true;
        continue;
      }

      final int srcR = _controllerUnpremultiplyChannel(r, a);
      final int srcG = _controllerUnpremultiplyChannel(g, a);
      final int srcB = _controllerUnpremultiplyChannel(b, a);

      if (eraseOccludedParts) {
        destination[destIndex] =
            (a << 24) |
            (srcR.clamp(0, 255) << 16) |
            (srcG.clamp(0, 255) << 8) |
            srcB.clamp(0, 255);
        anyChange = true;
        continue;
      }

      final double srcAlpha = a / 255.0;
      final double dstAlpha = dstA / 255.0;
      final double invSrcAlpha = 1.0 - srcAlpha;
      final double outAlphaDouble = srcAlpha + dstAlpha * invSrcAlpha;
      if (outAlphaDouble <= 0.001) {
        continue;
      }
      final int outA = (outAlphaDouble * 255.0).round();
      final double outR =
          (srcR * srcAlpha + dstR * dstAlpha * invSrcAlpha) / outAlphaDouble;
      final double outG =
          (srcG * srcAlpha + dstG * dstAlpha * invSrcAlpha) / outAlphaDouble;
      final double outB =
          (srcB * srcAlpha + dstB * dstAlpha * invSrcAlpha) / outAlphaDouble;

      destination[destIndex] =
          (outA.clamp(0, 255) << 24) |
          (outR.round().clamp(0, 255) << 16) |
          (outG.round().clamp(0, 255) << 8) |
          outB.round().clamp(0, 255);
      anyChange = true;
    }
  }

  if (!anyChange) {
    return false;
  }

  controller._resetWorkerSurfaceSync();
  final Rect dirtyRegion = Rect.fromLTRB(
    clampedLeft.toDouble(),
    clampedTop.toDouble(),
    clampedRight.toDouble(),
    clampedBottom.toDouble(),
  );
  controller._markDirty(
    region: dirtyRegion,
    layerId: controller._activeLayer.id,
    pixelsDirty: true,
  );
  return true;
}

void _controllerApplyPaintingCommandsSynchronously(
  BitmapCanvasController controller,
  Rect region,
  List<PaintingDrawCommand> commands,
) {
  if (commands.isEmpty) {
    return;
  }
  final BitmapSurface surface = controller._activeSurface;
  final Uint8List? mask = controller._selectionMask;
  bool anyChange = false;
  for (final PaintingDrawCommand command in commands) {
    final Color color = Color(command.color);
    final bool erase = command.erase;
    switch (command.type) {
      case PaintingDrawCommandType.brushStamp:
        final Offset? center = command.center;
        final double? radius = command.radius;
        final int? shapeIndex = command.shapeIndex;
        if (center == null || radius == null || shapeIndex == null) {
          continue;
        }
        final int clampedShape = shapeIndex.clamp(
          0,
          BrushShape.values.length - 1,
        );
        surface.drawBrushStamp(
          center: center,
          radius: radius,
          color: color,
          shape: BrushShape.values[clampedShape],
          mask: mask,
          antialiasLevel: command.antialiasLevel,
          erase: erase,
          softness: command.softness ?? 0.0,
          randomRotation: command.randomRotation ?? false,
          rotationSeed: command.rotationSeed ?? 0,
          rotationJitter: command.rotationJitter ?? 1.0,
          snapToPixel: command.snapToPixel ?? false,
        );
        anyChange = true;
        break;
      case PaintingDrawCommandType.line:
        final Offset? start = command.start;
        final Offset? end = command.end;
        final double? radius = command.radius;
        if (start == null || end == null || radius == null) {
          continue;
        }
        surface.drawLine(
          a: start,
          b: end,
          radius: radius,
          color: color,
          mask: mask,
          antialiasLevel: command.antialiasLevel,
          includeStartCap: command.includeStartCap ?? true,
          erase: erase,
        );
        anyChange = true;
        break;
      case PaintingDrawCommandType.variableLine:
        final Offset? start = command.start;
        final Offset? end = command.end;
        final double? startRadius = command.startRadius;
        final double? endRadius = command.endRadius;
        if (start == null ||
            end == null ||
            startRadius == null ||
            endRadius == null) {
          continue;
        }
        surface.drawVariableLine(
          a: start,
          b: end,
          startRadius: startRadius,
          endRadius: endRadius,
          color: color,
          mask: mask,
          antialiasLevel: command.antialiasLevel,
          includeStartCap: command.includeStartCap ?? true,
          erase: erase,
        );
        anyChange = true;
        break;
      case PaintingDrawCommandType.stampSegment:
        final Offset? start = command.start;
        final Offset? end = command.end;
        final double? startRadius = command.startRadius;
        final double? endRadius = command.endRadius;
        final int? shapeIndex = command.shapeIndex;
        if (start == null ||
            end == null ||
            startRadius == null ||
            endRadius == null ||
            shapeIndex == null) {
          continue;
        }
        final int clampedShape = shapeIndex.clamp(
          0,
          BrushShape.values.length - 1,
        );
        _controllerApplyStampSegmentFallback(
          surface: surface,
          start: start,
          end: end,
          startRadius: startRadius,
          endRadius: endRadius,
          includeStart: command.includeStartCap ?? true,
          shape: BrushShape.values[clampedShape],
          color: color,
          mask: mask,
          antialias: command.antialiasLevel,
          erase: erase,
          randomRotation: command.randomRotation ?? false,
          rotationSeed: command.rotationSeed ?? 0,
          rotationJitter: command.rotationJitter ?? 1.0,
          spacing: command.spacing ?? 0.15,
          scatter: command.scatter ?? 0.0,
          softness: command.softness ?? 0.0,
          snapToPixel: command.snapToPixel ?? false,
        );
        anyChange = true;
        break;
      case PaintingDrawCommandType.vectorStroke:
        break;
      case PaintingDrawCommandType.filledPolygon:
        final List<Offset>? points = command.points;
        if (points == null || points.length < 3) {
          continue;
        }
        surface.drawFilledPolygon(
          vertices: points,
          color: color,
          mask: mask,
          antialiasLevel: command.antialiasLevel,
          erase: erase,
        );
        anyChange = true;
        break;
    }
  }
  if (!anyChange) {
    return;
  }
  controller._resetWorkerSurfaceSync();
  controller._markDirty(
    region: region,
    layerId: controller._activeLayer.id,
    pixelsDirty: true,
  );
}

void _controllerApplyStampSegmentFallback({
  required BitmapSurface surface,
  required Offset start,
  required Offset end,
  required double startRadius,
  required double endRadius,
  required bool includeStart,
  required BrushShape shape,
  required Color color,
  required Uint8List? mask,
  required int antialias,
  required bool erase,
  bool randomRotation = false,
  int rotationSeed = 0,
  double rotationJitter = 1.0,
  double spacing = 0.15,
  double scatter = 0.0,
  double softness = 0.0,
  bool snapToPixel = false,
}) {
  if (RustCpuBrushFfi.instance.drawStampSegment(
    pixelsPtr: surface.pointerAddress,
    pixelsLen: surface.pixels.length,
    width: surface.width,
    height: surface.height,
    startX: start.dx,
    startY: start.dy,
    endX: end.dx,
    endY: end.dy,
    startRadius: startRadius,
    endRadius: endRadius,
    colorArgb: color.value,
    brushShape: shape.index,
    antialiasLevel: antialias,
    includeStart: includeStart,
    erase: erase,
    randomRotation: randomRotation,
    rotationSeed: rotationSeed,
    rotationJitter: rotationJitter,
    spacing: spacing,
    scatter: scatter,
    softness: softness,
    snapToPixel: snapToPixel,
    accumulate: true,
    selectionMask: mask,
  )) {
    surface.markDirty();
    return;
  }
  final double distance = (end - start).distance;
  if (!distance.isFinite || distance <= 0.0001) {
    surface.drawBrushStamp(
      center: end,
      radius: endRadius,
      color: color,
      shape: shape,
      mask: mask,
      antialiasLevel: antialias,
      erase: erase,
      softness: softness,
      randomRotation: randomRotation,
      rotationSeed: rotationSeed,
      rotationJitter: rotationJitter,
      snapToPixel: snapToPixel,
    );
    return;
  }
  final double maxRadius = math.max(
    math.max(startRadius.abs(), endRadius.abs()),
    0.01,
  );
  final double step = _strokeStampSpacing(maxRadius, spacing);
  final int samples = math.max(1, (distance / step).ceil());
  final int startIndex = includeStart ? 0 : 1;
  for (int i = startIndex; i <= samples; i++) {
    final double t = samples == 0 ? 1.0 : (i / samples);
    final double radius = ui.lerpDouble(startRadius, endRadius, t) ?? endRadius;
    final double sampleX = ui.lerpDouble(start.dx, end.dx, t) ?? end.dx;
    final double sampleY = ui.lerpDouble(start.dy, end.dy, t) ?? end.dy;
    final Offset baseCenter = Offset(sampleX, sampleY);
    final double scatterRadius = maxRadius * scatter.clamp(0.0, 1.0) * 2.0;
    final Offset jitter = scatterRadius > 0
        ? brushScatterOffset(
            center: baseCenter,
            seed: rotationSeed,
            radius: scatterRadius,
            salt: i,
          )
        : Offset.zero;
    surface.drawBrushStamp(
      center: baseCenter + jitter,
      radius: radius,
      color: color,
      shape: shape,
      mask: mask,
      antialiasLevel: antialias,
      erase: erase,
      softness: softness,
      randomRotation: randomRotation,
      rotationSeed: rotationSeed,
      rotationJitter: rotationJitter,
      snapToPixel: snapToPixel,
    );
  }
}
