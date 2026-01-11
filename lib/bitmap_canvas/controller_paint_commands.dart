part of 'controller.dart';

void _controllerFlushDeferredStrokeCommands(
  BitmapCanvasController controller,
) {
  final bool usesVectorRasterization =
      controller._vectorDrawingEnabled || controller._currentStrokeHollowEnabled;
  if (!usesVectorRasterization) {
    controller._commitDeferredStrokeCommandsAsRaster();
    return;
  }
  if (controller._currentStrokePoints.isEmpty) {
    controller._deferredStrokeCommands.clear();
    return;
  }

  List<Offset> points =
      List<Offset>.from(controller._currentStrokePoints);
  List<double> radii =
      List<double>.from(controller._currentStrokeRadii);
  final Color color = controller._currentStrokeColor;
  final BrushShape shape = controller._currentBrushShape;
  final bool erase = controller._currentStrokeEraseMode;
  final int antialiasLevel = controller._currentStrokeAntialiasLevel;
  final bool hollow = controller._currentStrokeHollowEnabled;
  final double hollowRatio = controller._currentStrokeHollowRatio;
  final bool eraseOccludedParts = controller._currentStrokeEraseOccludedParts;
  final bool randomRotation = controller._currentStrokeRandomRotationEnabled;
  final int rotationSeed = controller._currentStrokeRotationSeed;

  if (controller._vectorStrokeSmoothingEnabled && points.length >= 3) {
    final _VectorStrokePathData smoothed = _smoothVectorStrokePath(
      points,
      radii,
    );
    points = smoothed.points;
    radii = smoothed.radii;
  }

  final PaintingDrawCommand vectorCommand = PaintingDrawCommand.vectorStroke(
    points: points,
    radii: radii,
    colorValue: color.value,
    shapeIndex: shape.index,
    antialiasLevel: antialiasLevel,
    erase: erase,
    hollow: hollow,
    hollowRatio: hollowRatio,
    eraseOccludedParts: eraseOccludedParts,
    randomRotation: randomRotation,
    rotationSeed: rotationSeed,
  );
  controller._committingStrokes.add(vectorCommand);

  controller._currentStrokePoints.clear();
  controller._currentStrokeRadii.clear();
  controller._deferredStrokeCommands.clear();

  _controllerDrawVectorStrokeOnGpu(
    controller,
    layerId: controller._activeLayer.id,
    points: points,
    radii: radii,
    color: color,
    brushShape: shape,
    erase: erase,
    antialiasLevel: antialiasLevel,
    hollow: hollow && !erase,
    hollowRatio: hollowRatio,
  ).catchError((Object error, StackTrace stackTrace) {
    debugPrint('GPU笔触绘制失败: $error\n$stackTrace');
  }).whenComplete(() {
    controller._committingStrokes.remove(vectorCommand);
    controller.notifyListeners();
  });
}

Future<void> _controllerCommitVectorStroke(
  BitmapCanvasController controller, {
  required List<Offset> points,
  required List<double> radii,
  required Color color,
  required BrushShape brushShape,
  required bool applyVectorSmoothing,
  required bool erase,
  required int antialiasLevel,
  bool hollow = false,
  double hollowRatio = 0.0,
  bool eraseOccludedParts = false,
  bool randomRotation = false,
  int rotationSeed = 0,
}) async {
  if (controller._layers.isEmpty || controller._activeLayer.locked) {
    return;
  }
  if (points.isEmpty) {
    return;
  }

  List<Offset> resolvedPoints = List<Offset>.from(points);
  List<double> resolvedRadii = List<double>.from(radii);
  if (applyVectorSmoothing &&
      controller._vectorStrokeSmoothingEnabled &&
      resolvedPoints.length >= 3) {
    final _VectorStrokePathData smoothed = _smoothVectorStrokePath(
      resolvedPoints,
      resolvedRadii,
    );
    resolvedPoints = smoothed.points;
    resolvedRadii = smoothed.radii;
  }

  final bool resolvedHollow = hollow && !erase;
  final PaintingDrawCommand vectorCommand = PaintingDrawCommand.vectorStroke(
    points: resolvedPoints,
    radii: resolvedRadii,
    colorValue: color.value,
    shapeIndex: brushShape.index,
    antialiasLevel: antialiasLevel.clamp(0, 3),
    erase: erase,
    hollow: resolvedHollow,
    hollowRatio: resolvedHollow ? hollowRatio.clamp(0.0, 1.0) : 0.0,
    eraseOccludedParts: resolvedHollow && eraseOccludedParts,
    randomRotation: randomRotation,
    rotationSeed: rotationSeed,
  );

  controller._committingStrokes.add(vectorCommand);
  controller.notifyListeners();

  try {
    await _controllerDrawVectorStrokeOnGpu(
      controller,
      layerId: controller._activeLayer.id,
      points: resolvedPoints,
      radii: resolvedRadii,
      color: color,
      brushShape: brushShape,
      erase: erase,
      antialiasLevel: antialiasLevel.clamp(0, 3),
      hollow: resolvedHollow,
      hollowRatio: resolvedHollow ? hollowRatio.clamp(0.0, 1.0) : 0.0,
    );
  } catch (error, stackTrace) {
    debugPrint('GPU笔触绘制失败: $error\n$stackTrace');
  } finally {
    controller._committingStrokes.remove(vectorCommand);
    controller.notifyListeners();
  }
}

Future<void> _controllerDrawVectorStrokeOnGpu(
  BitmapCanvasController controller, {
  required String layerId,
  required List<Offset> points,
  required List<double> radii,
  required Color color,
  required BrushShape brushShape,
  required bool erase,
  required int antialiasLevel,
  bool hollow = false,
  double hollowRatio = 0.0,
}) async {
  if (points.isEmpty) {
    return;
  }
  if (points.length != radii.length) {
    throw StateError('GPU笔触 points/radii 长度不一致');
  }

  await ensureRustInitialized();
  rust_gpu_brush.gpuBrushInit();

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

  final int currentRevision = layer.revision;
  final int? syncedRevision = controller._gpuBrushSyncedRevisions[layerId];
  if (syncedRevision != currentRevision) {
    await rust_gpu_brush.gpuUploadLayer(
      layerId: layerId,
      pixels: layer.surface.pixels,
      width: controller._width,
      height: controller._height,
    );
    controller._gpuBrushSyncedRevisions[layerId] = currentRevision;
  }

  final List<rust_gpu_brush.GpuPoint2D> gpuPoints = points
      .map(
        (Offset p) => rust_gpu_brush.GpuPoint2D(x: p.dx, y: p.dy),
      )
      .toList(growable: false);

  final rust_gpu_brush.GpuStrokeResult result = await rust_gpu_brush.gpuDrawStroke(
    layerId: layerId,
    points: gpuPoints,
    radii: radii,
    color: color.value,
    brushShape: brushShape.index,
    erase: erase,
    antialiasLevel: antialiasLevel.clamp(0, 3),
  );
  _controllerApplyGpuStrokeResult(controller, layerId: layerId, result: result);

  if (hollow && !erase && hollowRatio > 0.0001) {
    final List<double> scaledRadii = radii
        .map((double radius) => radius * hollowRatio)
        .toList(growable: false);
    final rust_gpu_brush.GpuStrokeResult cutout = await rust_gpu_brush.gpuDrawStroke(
      layerId: layerId,
      points: gpuPoints,
      radii: scaledRadii,
      color: const Color(0xFFFFFFFF).value,
      brushShape: brushShape.index,
      erase: true,
      antialiasLevel: antialiasLevel.clamp(0, 3),
    );
    _controllerApplyGpuStrokeResult(controller, layerId: layerId, result: cutout);
  }
}

void _controllerFlushRealtimeStrokeCommands(
  BitmapCanvasController controller,
) {
  if (controller._vectorDrawingEnabled || controller._currentStrokeHollowEnabled) {
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
  if (controller._useWorkerForRaster) {
    for (final PaintingDrawCommand command in commands) {
      final Rect? bounds = controller._dirtyRectForCommand(command);
      if (bounds == null || bounds.isEmpty) {
        continue;
      }
      controller._enqueuePaintingWorkerCommand(
        region: bounds,
        command: command,
      );
    }
  } else {
    Rect? region;
    for (final PaintingDrawCommand command in commands) {
      final Rect? bounds = controller._dirtyRectForCommand(command);
      if (bounds == null || bounds.isEmpty) {
        continue;
      }
      region = region == null
          ? bounds
          : Rect.fromLTRB(
              math.min(region.left, bounds.left),
              math.min(region.top, bounds.top),
              math.max(region.right, bounds.right),
              math.max(region.bottom, bounds.bottom),
            );
    }
    if (region != null) {
      controller._applyPaintingCommandsSynchronously(region, commands);
    }
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
  if (controller._useWorkerForRaster) {
    controller._enqueuePaintingWorkerCommand(region: bounds, command: command);
    return;
  }
  controller._applyPaintingCommandsSynchronously(
    bounds,
    <PaintingDrawCommand>[command],
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
      final double padding = 2.0 + command.antialiasLevel.clamp(0, 3) * 1.2;
      return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(padding);
  }
}

void _controllerApplyGpuStrokeResult(
  BitmapCanvasController controller, {
  required String layerId,
  required rust_gpu_brush.GpuStrokeResult result,
}) {
  final int width = result.dirtyWidth;
  final int height = result.dirtyHeight;
  if (width <= 0 || height <= 0) {
    return;
  }
  final int expectedLen = width * height;
  if (result.pixels.length < expectedLen) {
    return;
  }

  final int layerIndex = controller._layers.indexWhere(
    (BitmapLayerState layer) => layer.id == layerId,
  );
  if (layerIndex < 0) {
    return;
  }
  final BitmapLayerState layer = controller._layers[layerIndex];
  final BitmapSurface surface = layer.surface;

  final int effectiveLeft = math.max(0, math.min(result.dirtyLeft, controller._width));
  final int effectiveTop = math.max(0, math.min(result.dirtyTop, controller._height));
  final int maxRight = math.min(effectiveLeft + width, controller._width);
  final int maxBottom = math.min(effectiveTop + height, controller._height);
  if (maxRight <= effectiveLeft || maxBottom <= effectiveTop) {
    return;
  }

  final Uint32List destination = surface.pixels;
  final bool checkCoverage = surface.isClean;
  bool wroteCoverage = false;
  final int copyWidth = maxRight - effectiveLeft;
  final int copyHeight = maxBottom - effectiveTop;
  final int srcLeftOffset = effectiveLeft - result.dirtyLeft;
  final int srcTopOffset = effectiveTop - result.dirtyTop;

  for (int row = 0; row < copyHeight; row++) {
    final int srcRow = srcTopOffset + row;
    final int destY = effectiveTop + row;
    final int srcOffset = srcRow * width + srcLeftOffset;
    final int destOffset = destY * controller._width + effectiveLeft;
    if (checkCoverage && !wroteCoverage) {
      final int rowEnd = srcOffset + copyWidth;
      for (int i = srcOffset; i < rowEnd; i++) {
        if ((result.pixels[i] & 0xff000000) != 0) {
          wroteCoverage = true;
          break;
        }
      }
    }
    destination.setRange(destOffset, destOffset + copyWidth, result.pixels, srcOffset);
  }

  if (wroteCoverage) {
    surface.markDirty();
  }

  controller._resetWorkerSurfaceSync();
  final Rect dirtyRegion = Rect.fromLTWH(
    effectiveLeft.toDouble(),
    effectiveTop.toDouble(),
    copyWidth.toDouble(),
    copyHeight.toDouble(),
  );
  controller._markDirty(region: dirtyRegion, layerId: layerId, pixelsDirty: true);
  controller._gpuBrushSyncedRevisions[layerId] = layer.revision;
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
}) {
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
      randomRotation: randomRotation,
      rotationSeed: rotationSeed,
    );
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
    final double radius = ui.lerpDouble(startRadius, endRadius, t) ?? endRadius;
    final double sampleX = ui.lerpDouble(start.dx, end.dx, t) ?? end.dx;
    final double sampleY = ui.lerpDouble(start.dy, end.dy, t) ?? end.dy;
    surface.drawBrushStamp(
      center: Offset(sampleX, sampleY),
      radius: radius,
      color: color,
      shape: shape,
      mask: mask,
      antialiasLevel: antialias,
      erase: erase,
      randomRotation: randomRotation,
      rotationSeed: rotationSeed,
    );
  }
}

const double _kVectorStrokeSmoothSampleSpacing = 4.0;
const double _kVectorStrokeSmoothMinSegment = 0.5;
const int _kVectorStrokeSmoothMaxSamplesPerSegment = 48;

class _VectorStrokePathData {
  const _VectorStrokePathData({
    required this.points,
    required this.radii,
  });

  final List<Offset> points;
  final List<double> radii;
}

_VectorStrokePathData _smoothVectorStrokePath(
  List<Offset> points,
  List<double> radii,
) {
  if (points.length < 3) {
    return _VectorStrokePathData(points: points, radii: radii);
  }

  final List<Offset> smoothedPoints = <Offset>[points.first];
  final List<double> smoothedRadii = <double>[
    _strokeRadiusAtIndex(radii, 0),
  ];

  for (int i = 0; i < points.length - 1; i++) {
    final Offset p0 = i == 0 ? points[i] : points[i - 1];
    final Offset p1 = points[i];
    final Offset p2 = points[i + 1];
    final Offset p3 = (i + 2 < points.length) ? points[i + 2] : points[i + 1];
    final double r0 = i == 0
        ? _strokeRadiusAtIndex(radii, i)
        : _strokeRadiusAtIndex(radii, i - 1);
    final double r1 = _strokeRadiusAtIndex(radii, i);
    final double r2 = _strokeRadiusAtIndex(radii, i + 1);
    final double r3 = (i + 2 < points.length)
        ? _strokeRadiusAtIndex(radii, i + 2)
        : _strokeRadiusAtIndex(radii, i + 1);

    final double segmentLength = (p2 - p1).distance;
    if (segmentLength < _kVectorStrokeSmoothMinSegment) {
      continue;
    }

    final int samples = math.max(
      2,
      math.min(
        _kVectorStrokeSmoothMaxSamplesPerSegment,
        (segmentLength / _kVectorStrokeSmoothSampleSpacing).ceil() + 1,
      ),
    );

    for (int s = 1; s < samples; s++) {
      final double t = s / (samples - 1);
      final Offset smoothedPoint = _catmullRomOffset(p0, p1, p2, p3, t);
      final double smoothedRadius =
          _catmullRomScalar(r0, r1, r2, r3, t).clamp(0.0, double.infinity);
      smoothedPoints.add(smoothedPoint);
      smoothedRadii.add(smoothedRadius);
    }
  }

  if (smoothedPoints.length == 1) {
    smoothedPoints.add(points.last);
    smoothedRadii.add(_strokeRadiusAtIndex(radii, points.length - 1));
  } else {
    smoothedPoints[smoothedPoints.length - 1] = points.last;
    smoothedRadii[smoothedRadii.length - 1] =
        _strokeRadiusAtIndex(radii, points.length - 1);
  }

  return _VectorStrokePathData(points: smoothedPoints, radii: smoothedRadii);
}

double _strokeRadiusAtIndex(List<double> radii, int index) {
  if (radii.isEmpty) {
    return 1.0;
  }
  if (index < 0) {
    return radii.first;
  }
  if (index >= radii.length) {
    return radii.last;
  }
  final double value = radii[index];
  if (value.isFinite && value >= 0) {
    return value;
  }
  return radii.last >= 0 ? radii.last : 1.0;
}

Offset _catmullRomOffset(
  Offset p0,
  Offset p1,
  Offset p2,
  Offset p3,
  double t,
) {
  return Offset(
    _catmullRomScalar(p0.dx, p1.dx, p2.dx, p3.dx, t),
    _catmullRomScalar(p0.dy, p1.dy, p2.dy, p3.dy, t),
  );
}

double _catmullRomScalar(
  double p0,
  double p1,
  double p2,
  double p3,
  double t,
) {
  final double t2 = t * t;
  final double t3 = t2 * t;
  return 0.5 *
      ((2 * p1) +
          (-p0 + p2) * t +
          (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
          (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
}
