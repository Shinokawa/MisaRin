part of 'controller.dart';

void _fillSetSelectionMask(BitmapCanvasController controller, Uint8List? mask) {
  if (mask != null && mask.length != controller._width * controller._height) {
    throw ArgumentError('Selection mask size mismatch');
  }
  controller._selectionMask = mask;
  controller._paintingWorkerSelectionDirty = true;
  controller._selectionMaskTiled = null;
  controller._selectionMaskBounds = null;
  controller._selectionMaskIsFull = false;
  if (mask == null) {
    return;
  }
  final bool buildTiles = controller._useTiledSurface;
  final _SelectionMaskBuildResult build = _buildTiledSelectionMask(
    mask,
    controller._width,
    controller._height,
    controller._surfaceTileSize,
    buildTiles: buildTiles,
  );
  controller._selectionMaskBounds = build.bounds;
  controller._selectionMaskIsFull = build.isFull;
  if (buildTiles && !build.isFull) {
    controller._selectionMaskTiled = build.tiledMask;
  }
}

class _SelectionMaskBuildResult {
  const _SelectionMaskBuildResult({
    required this.tiledMask,
    required this.bounds,
    required this.isFull,
  });

  final TiledSelectionMask? tiledMask;
  final RasterIntRect? bounds;
  final bool isFull;
}

_SelectionMaskBuildResult _buildTiledSelectionMask(
  Uint8List mask,
  int width,
  int height,
  int tileSize, {
  required bool buildTiles,
}) {
  if (width <= 0 || height <= 0 || mask.isEmpty) {
    return const _SelectionMaskBuildResult(
      tiledMask: null,
      bounds: null,
      isFull: false,
    );
  }
  TiledSelectionMask? tiledMask;
  bool isFull = true;
  bool hasAny = false;
  int minX = width;
  int minY = height;
  int maxX = -1;
  int maxY = -1;
  for (int i = 0; i < mask.length; i++) {
    final int value = mask[i];
    if (value == 0) {
      isFull = false;
      continue;
    }
    hasAny = true;
    final int x = i % width;
    final int y = i ~/ width;
    if (x < minX) {
      minX = x;
    }
    if (x > maxX) {
      maxX = x;
    }
    if (y < minY) {
      minY = y;
    }
    if (y > maxY) {
      maxY = y;
    }
    if (buildTiles) {
      tiledMask ??= TiledSelectionMask(tileSize: tileSize);
      final int tx = tileIndexForCoord(x, tileSize);
      final int ty = tileIndexForCoord(y, tileSize);
      final Uint8List tile = tiledMask.ensureTile(tx, ty);
      final int localX = x - tx * tileSize;
      final int localY = y - ty * tileSize;
      tile[localY * tileSize + localX] = value;
    }
  }
  RasterIntRect? bounds;
  if (isFull) {
    bounds = RasterIntRect(0, 0, width, height);
  } else if (hasAny) {
    bounds = RasterIntRect(minX, minY, maxX + 1, maxY + 1);
  }
  if (isFull) {
    tiledMask = null;
  }
  return _SelectionMaskBuildResult(
    tiledMask: tiledMask,
    bounds: bounds,
    isFull: isFull,
  );
}

BitmapLayerState? _fillFindSingleVisibleLayerForComposite(
  BitmapCanvasController controller,
) {
  final String? translatingLayerId = controller._translatingLayerIdForComposite;
  BitmapLayerState? candidate;
  for (final BitmapLayerState layer in controller._layers) {
    if (!layer.visible) {
      continue;
    }
    if (translatingLayerId != null && layer.id == translatingLayerId) {
      continue;
    }
    if (candidate != null) {
      return null;
    }
    candidate = layer;
  }
  return candidate;
}

bool _fillAllPixelsMatchColor(Uint32List pixels, int color) {
  final int length = pixels.length;
  for (int i = 0; i < length; i++) {
    if (pixels[i] != color) {
      return false;
    }
  }
  return true;
}

Uint32List _fillReadActivePixels(BitmapCanvasController controller) {
  final LayerSurface surface = controller._activeLayer.surface;
  if (!surface.isTiled) {
    return surface.bitmapSurface!.pixels;
  }
  return surface.readRect(
    RasterIntRect(0, 0, controller._width, controller._height),
  );
}

void _fillCommitActivePixels(
  BitmapCanvasController controller,
  Uint32List pixels, [
  RasterIntRect? region,
]) {
  final LayerSurface surface = controller._activeLayer.surface;
  if (!surface.isTiled) {
    surface.markDirty();
    return;
  }
  if (region == null) {
    surface.writeRect(
      RasterIntRect(0, 0, controller._width, controller._height),
      pixels,
    );
    return;
  }
  final int left = region.left.clamp(0, controller._width);
  final int top = region.top.clamp(0, controller._height);
  final int right = region.right.clamp(0, controller._width);
  final int bottom = region.bottom.clamp(0, controller._height);
  if (left >= right || top >= bottom) {
    return;
  }
  final RasterIntRect clipped = RasterIntRect(left, top, right, bottom);
  final Uint32List patch =
      _controllerCopySurfaceRegion(pixels, controller._width, clipped);
  surface.writeRect(clipped, patch);
}

void _fillFloodFill(
  BitmapCanvasController controller,
  Offset position, {
  required Color color,
  bool contiguous = true,
  bool sampleAllLayers = false,
  List<Color>? swallowColors,
  int tolerance = 0,
  int fillGap = 0,
  int antialiasLevel = 0,
}) {
  if (controller._activeLayer.locked) {
    return;
  }
  final int x = position.dx.floor();
  final int y = position.dy.floor();
  if (x < 0 || x >= controller._width || y < 0 || y >= controller._height) {
    return;
  }
  if (!_fillSelectionAllowsInt(controller, x, y)) {
    return;
  }

  final int clampedTolerance = tolerance.clamp(0, 255);
  final int clampedFillGap = fillGap.clamp(0, 64);
  final int clampedAntialias = antialiasLevel.clamp(0, 9);
  final Uint8List? selectionMask = controller._selectionMaskIsFull
      ? null
      : controller._selectionMask;
  RasterIntRect? selectionBounds = selectionMask == null
      ? null
      : controller._selectionMaskBounds;
  if (selectionMask != null && selectionBounds == null) {
    selectionBounds = _controllerMaskBounds(
      selectionMask,
      controller._width,
      controller._height,
    );
  }
  final Uint32List? swallowColorsU32 =
      swallowColors != null && swallowColors.isNotEmpty
      ? Uint32List.fromList(
          swallowColors
              .map((it) => BitmapSurface.encodeColor(it))
              .toList(growable: false),
        )
      : null;
  final LayerSurface surface = controller._activeLayer.surface;
  final String layerId = controller._activeLayer.id;
  final int generation = controller._paintingWorkerGeneration;
  final int colorValue = BitmapSurface.encodeColor(color);
  BitmapLayerState? sampleLayer;
  bool needsCompositeSample = false;
  if (sampleAllLayers) {
    final BitmapLayerState? singleVisibleLayer =
        _fillFindSingleVisibleLayerForComposite(controller);
    if (singleVisibleLayer != null) {
      final double layerOpacity = BitmapCanvasController._clampUnit(
        singleVisibleLayer.opacity,
      );
      if (!singleVisibleLayer.clippingMask && layerOpacity >= 1.0) {
        if (!identical(singleVisibleLayer, controller._activeLayer)) {
          sampleLayer = singleVisibleLayer;
        }
      } else {
        needsCompositeSample = true;
      }
    } else {
      needsCompositeSample = true;
    }
  }
  Uint32List? samplePixels;
  if (sampleAllLayers && !surface.isTiled) {
    if (sampleLayer != null) {
      samplePixels = sampleLayer.surface.pixels;
    } else if (needsCompositeSample) {
      controller._updateComposite(requiresFullSurface: true, region: null);
      final Uint32List? compositePixels = controller._compositePixels;
      if (compositePixels == null ||
          compositePixels.isEmpty ||
          controller._rasterBackend.isCompositeDirty) {
        return;
      }
      samplePixels = compositePixels;
    }
  }
  if (surface.isTiled && selectionMask == null) {
    final TiledSurface tiled = surface.tiledSurface!;
    final int tileSize = tiled.tileSize;
    final int initialLeft = (x ~/ tileSize) * tileSize;
    final int initialTop = (y ~/ tileSize) * tileSize;
    RasterIntRect currentRect = RasterIntRect(
      initialLeft,
      initialTop,
      math.min(initialLeft + tileSize, controller._width),
      math.min(initialTop + tileSize, controller._height),
    );

    Uint32List? resolveSamplePixelsForRect(RasterIntRect rect) {
      if (!sampleAllLayers) {
        return null;
      }
      if (sampleLayer != null) {
        return sampleLayer!.surface.readRect(rect);
      }
      if (!needsCompositeSample) {
        return null;
      }
      controller._updateComposite(
        requiresFullSurface: false,
        region: Rect.fromLTRB(
          rect.left.toDouble(),
          rect.top.toDouble(),
          rect.right.toDouble(),
          rect.bottom.toDouble(),
        ),
      );
      if (controller._rasterBackend.isCompositeDirty) {
        return null;
      }
      return controller._rasterBackend.readCompositeRect(rect);
    }

    void scheduleFillAttempt(RasterIntRect rect) {
      final BitmapSurface tempSurface = BitmapSurface(
        width: rect.width,
        height: rect.height,
      );
      final Uint32List snapshot = surface.readRect(rect);
      if (snapshot.isNotEmpty) {
        tempSurface.pixels.setAll(0, snapshot);
      }
      final int ptrAddress = tempSurface.pointerAddress;
      if (ptrAddress == 0) {
        tempSurface.dispose();
        return;
      }
      final Uint32List? localSamplePixels =
          resolveSamplePixelsForRect(rect);
      if (sampleAllLayers &&
          (sampleLayer != null || needsCompositeSample) &&
          localSamplePixels == null) {
        tempSurface.dispose();
        return;
      }
      final int fillStartX = x - rect.left;
      final int fillStartY = y - rect.top;

      controller._enqueueWorkerPatchFuture(
        rust_bucket_fill
            .floodFillInPlace(
              ptr: BigInt.from(ptrAddress),
              width: rect.width,
              height: rect.height,
              samplePixels: localSamplePixels,
              startX: fillStartX,
              startY: fillStartY,
              colorValue: colorValue,
              targetColorValue: null,
              contiguous: contiguous,
              tolerance: clampedTolerance,
              fillGap: clampedFillGap,
              selectionMask: null,
              swallowColors: swallowColorsU32,
              antialiasLevel: clampedAntialias,
            )
            .then<PaintingWorkerPatch?>((rectResult) {
              if (generation != controller._paintingWorkerGeneration) {
                tempSurface.dispose();
                return null;
              }
              if (rectResult.width <= 0 || rectResult.height <= 0) {
                tempSurface.dispose();
                return null;
              }
              final int rectRight = rectResult.left + rectResult.width;
              final int rectBottom = rectResult.top + rectResult.height;
              final bool touchesBoundary = rectResult.left <= 0 ||
                  rectResult.top <= 0 ||
                  rectRight >= rect.width ||
                  rectBottom >= rect.height;
              final bool isFullCanvas = rect.left <= 0 &&
                  rect.top <= 0 &&
                  rect.right >= controller._width &&
                  rect.bottom >= controller._height;
              if (touchesBoundary && !isFullCanvas) {
                final int nextLeft = math.max(0, rect.left - tileSize);
                final int nextTop = math.max(0, rect.top - tileSize);
                final int nextRight =
                    math.min(controller._width, rect.right + tileSize);
                final int nextBottom =
                    math.min(controller._height, rect.bottom + tileSize);
                final RasterIntRect nextRect = RasterIntRect(
                  nextLeft,
                  nextTop,
                  nextRight,
                  nextBottom,
                );
                if (nextRect.left == rect.left &&
                    nextRect.top == rect.top &&
                    nextRect.right == rect.right &&
                    nextRect.bottom == rect.bottom) {
                  // Can't expand any further; commit what we have.
                } else {
                  tempSurface.dispose();
                  scheduleFillAttempt(nextRect);
                  return null;
                }
              }

              surface.writeRect(rect, tempSurface.pixels);
              tempSurface.dispose();
              controller._markDirty(
                region: Rect.fromLTWH(
                  (rectResult.left + rect.left).toDouble(),
                  (rectResult.top + rect.top).toDouble(),
                  rectResult.width.toDouble(),
                  rectResult.height.toDouble(),
                ),
                layerId: layerId,
                pixelsDirty: true,
              );
              return null;
            }),
      );
    }

    scheduleFillAttempt(currentRect);
    return;
  }

  BitmapSurface? tempSurface;
  int ptrAddress = surface.pointerAddress;
  int fillWidth = controller._width;
  int fillHeight = controller._height;
  int fillStartX = x;
  int fillStartY = y;
  int offsetX = 0;
  int offsetY = 0;
  RasterIntRect? writeRect;
  Uint8List? fillSelectionMask = selectionMask;
  Uint32List? fillSamplePixels = samplePixels;
  if (surface.isTiled) {
    if (selectionMask != null && selectionBounds != null) {
      final int boundLeft = selectionBounds.left.clamp(0, controller._width);
      final int boundTop = selectionBounds.top.clamp(0, controller._height);
      final int boundRight = selectionBounds.right.clamp(0, controller._width);
      final int boundBottom = selectionBounds.bottom.clamp(0, controller._height);
      final RasterIntRect bounded =
          RasterIntRect(boundLeft, boundTop, boundRight, boundBottom);
      if (bounded.isEmpty) {
        return;
      }
      if (x < bounded.left ||
          x >= bounded.right ||
          y < bounded.top ||
          y >= bounded.bottom) {
        return;
      }
      writeRect = bounded;
      offsetX = bounded.left;
      offsetY = bounded.top;
      fillWidth = bounded.width;
      fillHeight = bounded.height;
      fillStartX = x - bounded.left;
      fillStartY = y - bounded.top;
      tempSurface = BitmapSurface(width: fillWidth, height: fillHeight);
      final Uint32List snapshot = surface.readRect(bounded);
      if (snapshot.isNotEmpty) {
        tempSurface.pixels.setAll(0, snapshot);
      }
      ptrAddress = tempSurface.pointerAddress;
      fillSelectionMask = _controllerCopyMaskRegion(
        selectionMask,
        controller._width,
        bounded,
      );
      if (sampleAllLayers) {
        if (sampleLayer != null) {
          fillSamplePixels = sampleLayer.surface.readRect(bounded);
        } else if (needsCompositeSample) {
          controller._updateComposite(
            requiresFullSurface: false,
            region: Rect.fromLTRB(
              bounded.left.toDouble(),
              bounded.top.toDouble(),
              bounded.right.toDouble(),
              bounded.bottom.toDouble(),
            ),
          );
          if (controller._rasterBackend.isCompositeDirty) {
            tempSurface.dispose();
            return;
          }
          fillSamplePixels = controller._rasterBackend.readCompositeRect(
            bounded,
          );
        }
      }
    } else {
      tempSurface = BitmapSurface(
        width: controller._width,
        height: controller._height,
      );
      final Uint32List snapshot = surface.readRect(
        RasterIntRect(0, 0, controller._width, controller._height),
      );
      if (snapshot.isNotEmpty) {
        tempSurface.pixels.setAll(0, snapshot);
      }
      ptrAddress = tempSurface.pointerAddress;
    }
  }
  if (ptrAddress == 0) {
    tempSurface?.dispose();
    return;
  }
  controller._enqueueWorkerPatchFuture(
    rust_bucket_fill
        .floodFillInPlace(
          ptr: BigInt.from(ptrAddress),
          width: fillWidth,
          height: fillHeight,
          samplePixels: fillSamplePixels,
          startX: fillStartX,
          startY: fillStartY,
          colorValue: colorValue,
          targetColorValue: null,
          contiguous: contiguous,
          tolerance: clampedTolerance,
          fillGap: clampedFillGap,
          selectionMask: fillSelectionMask,
          swallowColors: swallowColorsU32,
          antialiasLevel: clampedAntialias,
        )
        .then<PaintingWorkerPatch?>((rect) {
          if (generation != controller._paintingWorkerGeneration) {
            tempSurface?.dispose();
            return null;
          }
          if (rect.width <= 0 || rect.height <= 0) {
            tempSurface?.dispose();
            return null;
          }
          if (surface.isTiled) {
            final RasterIntRect targetRect = writeRect ??
                RasterIntRect(0, 0, controller._width, controller._height);
            surface.writeRect(targetRect, tempSurface!.pixels);
            tempSurface.dispose();
          } else if (surface.isClean && (colorValue & 0xff000000) != 0) {
            surface.markDirty();
          }
          controller._markDirty(
            region: Rect.fromLTWH(
              (rect.left + offsetX).toDouble(),
              (rect.top + offsetY).toDouble(),
              rect.width.toDouble(),
              rect.height.toDouble(),
            ),
            layerId: layerId,
            pixelsDirty: true,
          );
          return null;
        }),
  );
}

Future<Uint8List?> _fillComputeMagicWandMask(
  BitmapCanvasController controller,
  Offset position, {
  bool sampleAllLayers = true,
  int tolerance = 0,
}) async {
  final int x = position.dx.floor();
  final int y = position.dy.floor();
  if (x < 0 || x >= controller._width || y < 0 || y >= controller._height) {
    return null;
  }
  final LayerSurface surface = controller._activeLayer.surface;
  if (surface.isTiled) {
    final TiledSurface tiled = surface.tiledSurface!;
    final int tileSize = tiled.tileSize;
    final int initialLeft = (x ~/ tileSize) * tileSize;
    final int initialTop = (y ~/ tileSize) * tileSize;
    RasterIntRect rect = RasterIntRect(
      initialLeft,
      initialTop,
      math.min(initialLeft + tileSize, controller._width),
      math.min(initialTop + tileSize, controller._height),
    );

    bool touchesBoundary(Uint8List mask, int width, int height) {
      if (mask.isEmpty || width <= 0 || height <= 0) {
        return false;
      }
      final int lastRow = (height - 1) * width;
      for (int x = 0; x < width; x++) {
        if (mask[x] != 0 || mask[lastRow + x] != 0) {
          return true;
        }
      }
      for (int y = 0; y < height; y++) {
        final int row = y * width;
        if (mask[row] != 0 || mask[row + (width - 1)] != 0) {
          return true;
        }
      }
      return false;
    }

    Uint8List? localMask;
    while (true) {
      Uint32List pixels;
      if (sampleAllLayers) {
        await _compositeUpdate(
          controller,
          requiresFullSurface: false,
          regions: <RasterIntRect>[rect],
        );
        pixels = controller._rasterBackend.readCompositeRect(rect);
      } else {
        pixels = surface.readRect(rect);
      }
      if (pixels.isEmpty) {
        return null;
      }
      localMask = await rust_bucket_fill.magicWandMask(
        width: rect.width,
        height: rect.height,
        pixels: pixels,
        startX: x - rect.left,
        startY: y - rect.top,
        tolerance: tolerance,
      );
      if (localMask == null) {
        return null;
      }
      if (!touchesBoundary(localMask, rect.width, rect.height)) {
        break;
      }
      if (rect.left <= 0 &&
          rect.top <= 0 &&
          rect.right >= controller._width &&
          rect.bottom >= controller._height) {
        break;
      }
      final int nextLeft = math.max(0, rect.left - tileSize);
      final int nextTop = math.max(0, rect.top - tileSize);
      final int nextRight =
          math.min(controller._width, rect.right + tileSize);
      final int nextBottom =
          math.min(controller._height, rect.bottom + tileSize);
      final RasterIntRect nextRect =
          RasterIntRect(nextLeft, nextTop, nextRight, nextBottom);
      if (nextRect.left == rect.left &&
          nextRect.top == rect.top &&
          nextRect.right == rect.right &&
          nextRect.bottom == rect.bottom) {
        break;
      }
      rect = nextRect;
    }

    if (localMask == null) {
      return null;
    }
    final Uint8List mask = Uint8List(controller._width * controller._height);
    final int rectWidth = rect.width;
    for (int row = 0; row < rect.height; row++) {
      final int srcRow = row * rectWidth;
      final int dstRow =
          (rect.top + row) * controller._width + rect.left;
      mask.setRange(dstRow, dstRow + rectWidth, localMask, srcRow);
    }
    return mask;
  }

  final Uint8List mask = Uint8List(controller._width * controller._height);
  if (sampleAllLayers) {
    controller._updateComposite(requiresFullSurface: true, region: null);
    final Uint32List? composite = controller._compositePixels;
    if (composite == null || composite.isEmpty) {
      return null;
    }
    if (controller.isMultithreaded) {
      final Uint32List copy = Uint32List.fromList(composite);
      return controller._executeSelectionMask(
        start: Offset(x.toDouble(), y.toDouble()),
        pixels: copy,
        tolerance: tolerance,
      );
    } else {
      final int target = composite[y * controller._width + x];
      final RasterIntRect? filledBounds = _fillFloodFillMask(
        controller,
        pixels: composite,
        targetColor: target,
        mask: mask,
        startX: x,
        startY: y,
        width: controller._width,
        height: controller._height,
        tolerance: tolerance,
      );
      if (filledBounds == null) {
        return null;
      }
      return mask;
    }
  }

  final LayerSurface surface = controller._activeLayer.surface;
  final bool tiledSurface = surface.isTiled;
  final Uint32List pixels = _fillReadActivePixels(controller);
  if (controller.isMultithreaded) {
    final Uint32List copy = Uint32List.fromList(pixels);
    return controller._executeSelectionMask(
      start: Offset(x.toDouble(), y.toDouble()),
      pixels: copy,
      tolerance: tolerance,
    );
  } else {
    final int target = pixels[y * controller._width + x];
    final RasterIntRect? filledBounds = _fillFloodFillMask(
      controller,
      pixels: pixels,
      targetColor: target,
      mask: mask,
      startX: x,
      startY: y,
      width: controller._width,
      height: controller._height,
      tolerance: tolerance,
    );
    if (filledBounds == null) {
      return null;
    }
    return mask;
  }
}

Color _fillSampleColor(
  BitmapCanvasController controller,
  Offset position, {
  bool sampleAllLayers = true,
}) {
  final int x = position.dx.floor();
  final int y = position.dy.floor();
  if (x < 0 || x >= controller._width || y < 0 || y >= controller._height) {
    return const Color(0x00000000);
  }
  if (sampleAllLayers) {
    return _fillColorAtComposite(controller, position, preferRealtime: true);
  }
  return _fillColorAtSurface(controller, controller._activeSurface, x, y);
}

bool _fillSelectionAllows(BitmapCanvasController controller, Offset position) {
  final Uint8List? mask = controller._selectionMask;
  if (mask == null || controller._selectionMaskIsFull) {
    return true;
  }
  final int x = position.dx.floor();
  final int y = position.dy.floor();
  if (x < 0 || x >= controller._width || y < 0 || y >= controller._height) {
    return false;
  }
  return mask[y * controller._width + x] != 0;
}

bool _fillSelectionAllowsInt(BitmapCanvasController controller, int x, int y) {
  final Uint8List? mask = controller._selectionMask;
  if (mask == null || controller._selectionMaskIsFull) {
    return true;
  }
  if (x < 0 || x >= controller._width || y < 0 || y >= controller._height) {
    return false;
  }
  return mask[y * controller._width + x] != 0;
}

Uint8List? _fillFloodFillAcrossLayers(
  BitmapCanvasController controller,
  int startX,
  int startY,
  Color color,
  bool contiguous, {
  bool collectMask = false,
  int tolerance = 0,
  int fillGap = 0,
}) {
  if (!_fillSelectionAllowsInt(controller, startX, startY)) {
    return null;
  }
  controller._updateComposite(requiresFullSurface: true, region: null);
  Uint32List? compositePixels = controller._compositePixels;
  if (compositePixels == null ||
      compositePixels.isEmpty ||
      controller._rasterBackend.isCompositeDirty) {
    return null;
  }
  final int index = startY * controller._width + startX;
  if (index < 0 || index >= compositePixels.length) {
    return null;
  }
  final int target = compositePixels[index];
  final int replacement = BitmapSurface.encodeColor(color);
  final LayerSurface surface = controller._activeLayer.surface;
  final Uint8List? selectionMask = controller._selectionMaskIsFull
      ? null
      : controller._selectionMask;
  RasterIntRect? selectionBounds = selectionMask == null
      ? null
      : controller._selectionMaskBounds;
  if (selectionMask != null && selectionBounds == null) {
    selectionBounds = _controllerMaskBounds(
      selectionMask,
      controller._width,
      controller._height,
    );
  }

  if (selectionMask == null &&
      compositePixels.length == controller._width * controller._height &&
      _fillAllPixelsMatchColor(compositePixels, target)) {
    if (surface.isTiled) {
      surface.fill(color);
    } else {
      final Uint32List surfacePixels = _fillReadActivePixels(controller);
      surfacePixels.fillRange(0, surfacePixels.length, replacement);
      if (surface.isClean && (replacement & 0xff000000) != 0) {
        surface.markDirty();
      }
    }
    controller._markDirty(
      region: Rect.fromLTWH(
        0,
        0,
        controller._width.toDouble(),
        controller._height.toDouble(),
      ),
      layerId: controller._activeLayer.id,
      pixelsDirty: true,
    );
    if (!collectMask) {
      return null;
    }
    final Uint8List mask = Uint8List(controller._width * controller._height);
    mask.fillRange(0, mask.length, 1);
    return mask;
  }

  if (!contiguous) {
    final bool tiledSurface = surface.isTiled;
    final RasterIntRect effectiveBounds = selectionBounds ??
        RasterIntRect(0, 0, controller._width, controller._height);
    final Uint32List surfacePixels = tiledSurface
        ? surface.readRect(effectiveBounds)
        : _fillReadActivePixels(controller);
    final int localWidth = effectiveBounds.width;
    final Uint8List? swallowMask = collectMask
        ? Uint8List(controller._width * controller._height)
        : null;
    int minX = controller._width;
    int minY = controller._height;
    int maxX = -1;
    int maxY = -1;
    bool changed = false;
    if (selectionMask != null && selectionBounds == null) {
      return null;
    }
    if (selectionBounds != null) {
      final int left = selectionBounds.left;
      final int top = selectionBounds.top;
      final int right = selectionBounds.right;
      final int bottom = selectionBounds.bottom;
      for (int y = top; y < bottom; y++) {
        final int rowOffset = y * controller._width;
        final int localRow =
            tiledSurface ? (y - effectiveBounds.top) * localWidth : rowOffset;
        for (int x = left; x < right; x++) {
          final int i = rowOffset + x;
          final int pixel = compositePixels[i];
          if (!_fillColorsWithinTolerance(pixel, target, tolerance)) {
            continue;
          }
          if (selectionMask != null && selectionMask[i] == 0) {
            continue;
          }
          final int localIndex =
              tiledSurface ? localRow + (x - effectiveBounds.left) : i;
          if (localIndex < 0 || localIndex >= surfacePixels.length) {
            continue;
          }
          if (surfacePixels[localIndex] == replacement) {
            continue;
          }
          surfacePixels[localIndex] = replacement;
          changed = true;
          if (swallowMask != null) {
            swallowMask[i] = 1;
          }
          if (x < minX) {
            minX = x;
          }
          if (y < minY) {
            minY = y;
          }
          if (x > maxX) {
            maxX = x;
          }
          if (y > maxY) {
            maxY = y;
          }
        }
      }
    } else {
      for (int i = 0; i < compositePixels.length; i++) {
        final int pixel = compositePixels[i];
        if (!_fillColorsWithinTolerance(pixel, target, tolerance)) {
          continue;
        }
        if (selectionMask != null && selectionMask[i] == 0) {
          continue;
        }
        final int px = i % controller._width;
        final int py = i ~/ controller._width;
        final int localIndex = tiledSurface
            ? (py - effectiveBounds.top) * localWidth +
                (px - effectiveBounds.left)
            : i;
        if (localIndex < 0 || localIndex >= surfacePixels.length) {
          continue;
        }
        if (surfacePixels[localIndex] == replacement) {
          continue;
        }
        surfacePixels[localIndex] = replacement;
        changed = true;
        if (swallowMask != null) {
          swallowMask[i] = 1;
        }
        if (px < minX) {
          minX = px;
        }
        if (py < minY) {
          minY = py;
        }
        if (px > maxX) {
          maxX = px;
        }
        if (py > maxY) {
          maxY = py;
        }
      }
    }
    if (changed) {
      final RasterIntRect dirtyRect =
          RasterIntRect(minX, minY, maxX + 1, maxY + 1);
      if (tiledSurface) {
        if (!dirtyRect.isEmpty) {
          if (dirtyRect.left == effectiveBounds.left &&
              dirtyRect.top == effectiveBounds.top &&
              dirtyRect.right == effectiveBounds.right &&
              dirtyRect.bottom == effectiveBounds.bottom) {
            surface.writeRect(dirtyRect, surfacePixels);
          } else {
            final RasterIntRect localRect = RasterIntRect(
              dirtyRect.left - effectiveBounds.left,
              dirtyRect.top - effectiveBounds.top,
              dirtyRect.right - effectiveBounds.left,
              dirtyRect.bottom - effectiveBounds.top,
            );
            final Uint32List patch = _controllerCopySurfaceRegion(
              surfacePixels,
              effectiveBounds.width,
              localRect,
            );
            surface.writeRect(dirtyRect, patch);
          }
        }
      } else {
        _fillCommitActivePixels(controller, surfacePixels, dirtyRect);
      }
      controller._markDirty(
        region: Rect.fromLTRB(
          minX.toDouble(),
          minY.toDouble(),
          (maxX + 1).toDouble(),
          (maxY + 1).toDouble(),
        ),
        layerId: controller._activeLayer.id,
        pixelsDirty: true,
      );
    }
    if (swallowMask != null && changed) {
      return swallowMask;
    }
    return null;
  }
  final Uint8List contiguousMask = Uint8List(
    controller._width * controller._height,
  );
  final RasterIntRect? filledBounds = _fillFloodFillMask(
    controller,
    pixels: compositePixels,
    targetColor: target,
    mask: contiguousMask,
    startX: startX,
    startY: startY,
    width: controller._width,
    height: controller._height,
    tolerance: tolerance,
    fillGap: fillGap,
  );
  if (filledBounds == null) {
    return null;
  }

  // Expand mask by 1 pixel to cover anti-aliased edges.
  // When fillGap is enabled we avoid this extra expansion to prevent bleeding
  // into line art now that the fill no longer keeps an inner safety margin.
  RasterIntRect applyBounds = filledBounds;
  Uint8List finalMask = contiguousMask;
  if (tolerance > 0 && fillGap <= 0) {
    applyBounds = _fillExpandMaskInPlaceLocal(
      contiguousMask,
      controller._width,
      controller._height,
      filledBounds,
      radius: 1,
    );
  }

  // When sampling across layers we must derive the contiguous region from
  // the composite; the active layer alone may not contain the sampled color.
  final bool tiledSurface = surface.isTiled;
  Uint32List surfacePixels;
  if (tiledSurface) {
    surfacePixels = surface.readRect(applyBounds);
  } else {
    surfacePixels = _fillReadActivePixels(controller);
  }
  final int surfaceWidth = controller._width;
  final int applyWidth = applyBounds.width;
  int minX = controller._width;
  int minY = controller._height;
  int maxX = -1;
  int maxY = -1;
  bool changed = false;
  if (tiledSurface) {
    for (int y = applyBounds.top; y < applyBounds.bottom; y++) {
      final int maskRow = y * surfaceWidth;
      final int localRow = (y - applyBounds.top) * applyWidth;
      for (int x = applyBounds.left; x < applyBounds.right; x++) {
        final int maskIndex = maskRow + x;
        if (finalMask[maskIndex] == 0) {
          continue;
        }
        final int localIndex = localRow + (x - applyBounds.left);
        if (surfacePixels[localIndex] == replacement) {
          continue;
        }
        surfacePixels[localIndex] = replacement;
        changed = true;
        if (x < minX) {
          minX = x;
        }
        if (y < minY) {
          minY = y;
        }
        if (x > maxX) {
          maxX = x;
        }
        if (y > maxY) {
          maxY = y;
        }
      }
    }
  } else {
    for (int y = applyBounds.top; y < applyBounds.bottom; y++) {
      final int rowOffset = y * surfaceWidth;
      for (int x = applyBounds.left; x < applyBounds.right; x++) {
        final int i = rowOffset + x;
        if (finalMask[i] == 0) {
          continue;
        }
        if (surfacePixels[i] == replacement) {
          continue;
        }
        surfacePixels[i] = replacement;
        changed = true;
        if (x < minX) {
          minX = x;
        }
        if (y < minY) {
          minY = y;
        }
        if (x > maxX) {
          maxX = x;
        }
        if (y > maxY) {
          maxY = y;
        }
      }
    }
  }
  if (changed) {
    final RasterIntRect dirtyRect =
        RasterIntRect(minX, minY, maxX + 1, maxY + 1);
    if (tiledSurface) {
      if (!dirtyRect.isEmpty) {
        if (dirtyRect.left == applyBounds.left &&
            dirtyRect.top == applyBounds.top &&
            dirtyRect.right == applyBounds.right &&
            dirtyRect.bottom == applyBounds.bottom) {
          surface.writeRect(dirtyRect, surfacePixels);
        } else {
          final RasterIntRect localRect = RasterIntRect(
            dirtyRect.left - applyBounds.left,
            dirtyRect.top - applyBounds.top,
            dirtyRect.right - applyBounds.left,
            dirtyRect.bottom - applyBounds.top,
          );
          final Uint32List patch =
              _controllerCopySurfaceRegion(surfacePixels, applyWidth, localRect);
          surface.writeRect(dirtyRect, patch);
        }
      }
    } else {
      _fillCommitActivePixels(controller, surfacePixels, dirtyRect);
    }
    controller._markDirty(
      region: Rect.fromLTRB(
        minX.toDouble(),
        minY.toDouble(),
        (maxX + 1).toDouble(),
        (maxY + 1).toDouble(),
      ),
      layerId: controller._activeLayer.id,
      pixelsDirty: true,
    );
  }
  return collectMask ? finalMask : null;
}

Uint8List? _fillFloodFillSingleLayerWithMask(
  BitmapCanvasController controller,
  int startX,
  int startY,
  Color fillColor,
  Color baseColor,
  bool contiguous, {
  int tolerance = 0,
  int fillGap = 0,
}) {
  final LayerSurface surface = controller._activeLayer.surface;
  final bool tiledSurface = surface.isTiled;
  final Uint32List pixels = _fillReadActivePixels(controller);
  final Uint8List? selectionMask = controller._selectionMaskIsFull
      ? null
      : controller._selectionMask;
  RasterIntRect? selectionBounds = selectionMask == null
      ? null
      : controller._selectionMaskBounds;
  if (selectionMask != null && selectionBounds == null) {
    selectionBounds = _controllerMaskBounds(
      selectionMask,
      controller._width,
      controller._height,
    );
  }
  final int width = controller._width;
  final int height = controller._height;
  final int replacement = BitmapSurface.encodeColor(fillColor);
  final int target = BitmapSurface.encodeColor(baseColor);
  final Uint8List mask = Uint8List(width * height);

  if (!contiguous) {
    final RasterIntRect effectiveBounds = selectionBounds ??
        RasterIntRect(0, 0, controller._width, controller._height);
    final Uint32List workingPixels = tiledSurface
        ? surface.readRect(effectiveBounds)
        : pixels;
    final int localWidth = effectiveBounds.width;
    int minX = width;
    int minY = height;
    int maxX = -1;
    int maxY = -1;
    bool changed = false;
    if (selectionMask != null && selectionBounds == null) {
      return null;
    }
    if (selectionBounds != null) {
      final int left = selectionBounds.left;
      final int top = selectionBounds.top;
      final int right = selectionBounds.right;
      final int bottom = selectionBounds.bottom;
      for (int y = top; y < bottom; y++) {
        final int rowOffset = y * width;
        final int localRow =
            tiledSurface ? (y - effectiveBounds.top) * localWidth : rowOffset;
        for (int x = left; x < right; x++) {
          final int i = rowOffset + x;
          if (selectionMask != null && selectionMask[i] == 0) {
            continue;
          }
          final int localIndex =
              tiledSurface ? localRow + (x - effectiveBounds.left) : i;
          if (localIndex < 0 || localIndex >= workingPixels.length) {
            continue;
          }
          if (!_fillColorsWithinTolerance(
                workingPixels[localIndex],
                target,
                tolerance,
              )) {
            continue;
          }
          workingPixels[localIndex] = replacement;
          mask[i] = 1;
          changed = true;
          if (x < minX) {
            minX = x;
          }
          if (y < minY) {
            minY = y;
          }
          if (x > maxX) {
            maxX = x;
          }
          if (y > maxY) {
            maxY = y;
          }
        }
      }
    } else {
      for (int i = 0; i < pixels.length; i++) {
        if (selectionMask != null && selectionMask[i] == 0) {
          continue;
        }
        final int px = i % width;
        final int py = i ~/ width;
        final int localIndex = tiledSurface
            ? (py - effectiveBounds.top) * localWidth +
                (px - effectiveBounds.left)
            : i;
        if (localIndex < 0 || localIndex >= workingPixels.length) {
          continue;
        }
        if (!_fillColorsWithinTolerance(
              workingPixels[localIndex],
              target,
              tolerance,
            )) {
          continue;
        }
        workingPixels[localIndex] = replacement;
        mask[i] = 1;
        changed = true;
        if (px < minX) {
          minX = px;
        }
        if (py < minY) {
          minY = py;
        }
        if (px > maxX) {
          maxX = px;
        }
        if (py > maxY) {
          maxY = py;
        }
      }
    }
    if (!changed) {
      return null;
    }
    final RasterIntRect dirtyRect =
        RasterIntRect(minX, minY, maxX + 1, maxY + 1);
    if (tiledSurface) {
      if (!dirtyRect.isEmpty) {
        if (dirtyRect.left == effectiveBounds.left &&
            dirtyRect.top == effectiveBounds.top &&
            dirtyRect.right == effectiveBounds.right &&
            dirtyRect.bottom == effectiveBounds.bottom) {
          surface.writeRect(dirtyRect, workingPixels);
        } else {
          final RasterIntRect localRect = RasterIntRect(
            dirtyRect.left - effectiveBounds.left,
            dirtyRect.top - effectiveBounds.top,
            dirtyRect.right - effectiveBounds.left,
            dirtyRect.bottom - effectiveBounds.top,
          );
          final Uint32List patch = _controllerCopySurfaceRegion(
            workingPixels,
            effectiveBounds.width,
            localRect,
          );
          surface.writeRect(dirtyRect, patch);
        }
      }
    } else {
      _fillCommitActivePixels(controller, pixels, dirtyRect);
    }
    controller._markDirty(
      region: Rect.fromLTRB(
        minX.toDouble(),
        minY.toDouble(),
        (maxX + 1).toDouble(),
        (maxY + 1).toDouble(),
      ),
      layerId: controller._activeLayer.id,
      pixelsDirty: true,
    );
    return mask;
  }

  final RasterIntRect? filledBounds = _fillFloodFillMask(
    controller,
    pixels: pixels,
    targetColor: target,
    mask: mask,
    startX: startX,
    startY: startY,
    width: width,
    height: height,
    tolerance: tolerance,
    fillGap: fillGap,
  );
  if (filledBounds == null) {
    return null;
  }

  // Expand mask by 1 pixel to cover anti-aliased edges.
  // When fillGap is enabled we avoid this extra expansion to prevent bleeding
  // into line art now that the fill no longer keeps an inner safety margin.
  RasterIntRect applyBounds = filledBounds;
  Uint8List finalMask = mask;
  if (tolerance > 0 && fillGap <= 0) {
    applyBounds =
        _fillExpandMaskInPlaceLocal(mask, width, height, filledBounds, radius: 1);
  }

  int minX = width;
  int minY = height;
  int maxX = -1;
  int maxY = -1;
  bool changed = false;
  for (int y = applyBounds.top; y < applyBounds.bottom; y++) {
    final int rowOffset = y * width;
    for (int x = applyBounds.left; x < applyBounds.right; x++) {
      final int i = rowOffset + x;
      if (finalMask[i] == 0) {
        continue;
      }
      if (pixels[i] == replacement) {
        continue;
      }
      pixels[i] = replacement;
      changed = true;
      if (x < minX) {
        minX = x;
      }
      if (y < minY) {
        minY = y;
      }
      if (x > maxX) {
        maxX = x;
      }
      if (y > maxY) {
        maxY = y;
      }
    }
  }
  if (changed) {
    final RasterIntRect dirtyRect =
        RasterIntRect(minX, minY, maxX + 1, maxY + 1);
    _fillCommitActivePixels(controller, pixels, dirtyRect);
    controller._markDirty(
      region: Rect.fromLTRB(
        minX.toDouble(),
        minY.toDouble(),
        (maxX + 1).toDouble(),
        (maxY + 1).toDouble(),
      ),
      layerId: controller._activeLayer.id,
      pixelsDirty: true,
    );
    return finalMask;
  }
  return null;
}

void _fillSwallowColorLines(
  BitmapCanvasController controller,
  Uint8List regionMask,
  List<int> swallowArgb,
  Color fillColor,
) {
  if (regionMask.isEmpty || swallowArgb.isEmpty) {
    return;
  }
  final Set<int> swallowSet = swallowArgb.toSet();
  final Uint8List? selectionMask = controller._selectionMaskIsFull
      ? null
      : controller._selectionMask;
  final int width = controller._width;
  final int height = controller._height;
  RasterIntRect? selectionBounds = selectionMask == null
      ? null
      : controller._selectionMaskBounds;
  if (selectionMask != null && selectionBounds == null) {
    selectionBounds = _controllerMaskBounds(
      selectionMask,
      width,
      height,
    );
  }
  if (selectionMask != null && selectionBounds == null) {
    return;
  }
  RasterIntRect? regionBounds = _controllerMaskBounds(
    regionMask,
    width,
    height,
  );
  if (regionBounds == null || regionBounds.isEmpty) {
    return;
  }
  if (selectionBounds != null) {
    final int left = math.max(regionBounds.left, selectionBounds.left);
    final int top = math.max(regionBounds.top, selectionBounds.top);
    final int right = math.min(regionBounds.right, selectionBounds.right);
    final int bottom = math.min(regionBounds.bottom, selectionBounds.bottom);
    if (left >= right || top >= bottom) {
      return;
    }
    regionBounds = RasterIntRect(left, top, right, bottom);
  }
  final LayerSurface surface = controller._activeLayer.surface;
  final bool tiledSurface = surface.isTiled;
  final Uint32List pixels = tiledSurface
      ? surface.readRect(regionBounds)
      : _fillReadActivePixels(controller);
  final int fillArgb = BitmapSurface.encodeColor(fillColor);

  bool changed = false;
  int minX = width;
  int minY = height;
  int maxX = -1;
  int maxY = -1;
  final Uint8List visited = Uint8List(regionMask.length);

  void floodColorLine(int startIndex, int targetColor) {
    final Queue<int> queue = Queue<int>()..add(startIndex);
    visited[startIndex] = 1;
    while (queue.isNotEmpty) {
      final int index = queue.removeFirst();
      final int pixelIndex = tiledSurface
          ? ((index ~/ width) - regionBounds.top) * regionBounds.width +
                (index % width - regionBounds.left)
          : index;
      if (pixelIndex < 0 || pixelIndex >= pixels.length) {
        continue;
      }
      if (pixels[pixelIndex] != targetColor) {
        continue;
      }
      if (selectionMask != null && selectionMask[index] == 0) {
        continue;
      }
      if (pixels[pixelIndex] == fillArgb) {
        continue;
      }
      pixels[pixelIndex] = fillArgb;
      changed = true;
      final int px = index % width;
      final int py = index ~/ width;
      if (px < minX) {
        minX = px;
      }
      if (py < minY) {
        minY = py;
      }
      if (px > maxX) {
        maxX = px;
      }
      if (py > maxY) {
        maxY = py;
      }

      void enqueue(int nx, int ny) {
        if (nx < 0 || nx >= width || ny < 0 || ny >= height) {
          return;
        }
        final int neighborIndex = ny * width + nx;
        if (visited[neighborIndex] != 0) {
          return;
        }
        if (selectionMask != null && selectionMask[neighborIndex] == 0) {
          return;
        }
        final int neighborPixelIndex = tiledSurface
            ? ((neighborIndex ~/ width) - regionBounds.top) *
                    regionBounds.width +
                (neighborIndex % width - regionBounds.left)
            : neighborIndex;
        if (neighborPixelIndex < 0 ||
            neighborPixelIndex >= pixels.length) {
          return;
        }
        if (pixels[neighborPixelIndex] != targetColor) {
          return;
        }
        visited[neighborIndex] = 1;
        queue.add(neighborIndex);
      }

      enqueue(px + 1, py);
      enqueue(px - 1, py);
      enqueue(px, py + 1);
      enqueue(px, py - 1);
    }
  }

  int index = regionBounds.top * width + regionBounds.left;
  for (int y = regionBounds.top; y < regionBounds.bottom; y++) {
    index = y * width + regionBounds.left;
    for (int x = regionBounds.left; x < regionBounds.right; x++, index++) {
      if (regionMask[index] == 0) {
        continue;
      }

      void tryNeighbor(int nx, int ny) {
        if (nx < 0 || nx >= width || ny < 0 || ny >= height) {
          return;
        }
        final int neighborIndex = ny * width + nx;
        if (visited[neighborIndex] != 0) {
          return;
        }
        final int neighborPixelIndex = tiledSurface
            ? ((neighborIndex ~/ width) - regionBounds.top) *
                    regionBounds.width +
                (neighborIndex % width - regionBounds.left)
            : neighborIndex;
        if (neighborPixelIndex < 0 || neighborPixelIndex >= pixels.length) {
          return;
        }
        final int neighborColor = pixels[neighborPixelIndex];
        if (!swallowSet.contains(neighborColor) || neighborColor == fillArgb) {
          return;
        }
        floodColorLine(neighborIndex, neighborColor);
      }

      tryNeighbor(x + 1, y);
      tryNeighbor(x - 1, y);
      tryNeighbor(x, y + 1);
      tryNeighbor(x, y - 1);
    }
  }

  if (changed) {
    final RasterIntRect dirtyRect =
        RasterIntRect(minX, minY, maxX + 1, maxY + 1);
    if (tiledSurface) {
      if (!dirtyRect.isEmpty) {
        if (dirtyRect.left == regionBounds.left &&
            dirtyRect.top == regionBounds.top &&
            dirtyRect.right == regionBounds.right &&
            dirtyRect.bottom == regionBounds.bottom) {
          surface.writeRect(dirtyRect, pixels);
        } else {
          final RasterIntRect localRect = RasterIntRect(
            dirtyRect.left - regionBounds.left,
            dirtyRect.top - regionBounds.top,
            dirtyRect.right - regionBounds.left,
            dirtyRect.bottom - regionBounds.top,
          );
          final Uint32List patch = _controllerCopySurfaceRegion(
            pixels,
            regionBounds.width,
            localRect,
          );
          surface.writeRect(dirtyRect, patch);
        }
      }
    } else {
      _fillCommitActivePixels(controller, pixels, dirtyRect);
    }
    controller._markDirty(
      region: Rect.fromLTRB(
        minX.toDouble(),
        minY.toDouble(),
        (maxX + 1).toDouble(),
        (maxY + 1).toDouble(),
      ),
      layerId: controller._activeLayer.id,
      pixelsDirty: true,
    );
  }
}

void _fillApplyAntialiasToMask(
  BitmapCanvasController controller,
  Uint8List regionMask,
  int level,
) {
  if (regionMask.isEmpty || level <= 0) {
    return;
  }
  final List<double>? profile =
      BitmapCanvasController._kAntialiasBlendProfiles[level];
  if (profile == null || profile.isEmpty) {
    return;
  }
  final Rect? baseBounds = _fillMaskBounds(controller, regionMask);
  if (baseBounds == null || baseBounds.isEmpty) {
    return;
  }
  const int expandRadius = 1;
  final int surfaceWidth = controller._width;
  final int surfaceHeight = controller._height;
  final int expandedLeft =
      (baseBounds.left.floor() - expandRadius).clamp(0, surfaceWidth);
  final int expandedTop =
      (baseBounds.top.floor() - expandRadius).clamp(0, surfaceHeight);
  final int expandedRight =
      (baseBounds.right.ceil() + expandRadius).clamp(0, surfaceWidth);
  final int expandedBottom =
      (baseBounds.bottom.ceil() + expandRadius).clamp(0, surfaceHeight);
  final RasterIntRect expandedRect = RasterIntRect(
    expandedLeft,
    expandedTop,
    expandedRight,
    expandedBottom,
  );
  if (expandedRect.isEmpty) {
    return;
  }
  final Uint8List localMaskBase = _controllerCopyMaskRegion(
    regionMask,
    surfaceWidth,
    expandedRect,
  );
  final Uint8List expandedMask = _fillExpandMask(
    localMaskBase,
    expandedRect.width,
    expandedRect.height,
    radius: expandRadius,
  );
  final Rect? localBounds = _fillMaskBoundsLocal(
    expandedMask,
    expandedRect.width,
    expandedRect.height,
  );
  if (localBounds == null || localBounds.isEmpty) {
    return;
  }
  final RasterIntRect localRect = RasterIntRect(
    localBounds.left.floor(),
    localBounds.top.floor(),
    localBounds.right.ceil(),
    localBounds.bottom.ceil(),
  );
  if (localRect.isEmpty) {
    return;
  }
  final RasterIntRect rect = RasterIntRect(
    expandedRect.left + localRect.left,
    expandedRect.top + localRect.top,
    expandedRect.left + localRect.right,
    expandedRect.top + localRect.bottom,
  );

  final LayerSurface surface = controller._activeLayer.surface;
  Uint32List sourcePixels;
  Uint32List workingPixels;
  if (surface.isTiled) {
    workingPixels = surface.readRect(rect);
    sourcePixels = workingPixels;
  } else {
    sourcePixels = _fillReadActivePixels(controller);
    if (sourcePixels.isEmpty) {
      return;
    }
    workingPixels =
        _controllerCopySurfaceRegion(sourcePixels, controller._width, rect);
  }
  if (workingPixels.isEmpty) {
    return;
  }
  final Uint8List localMask = _controllerCopyMaskRegion(
    expandedMask,
    expandedRect.width,
    localRect,
  );
  final Uint32List temp = Uint32List(workingPixels.length);
  Uint32List src = workingPixels;
  Uint32List dest = temp;
  bool anyChange = false;
  for (final double factor in profile) {
    if (factor <= 0) {
      continue;
    }
    final bool changed = _fillRunMaskedAntialiasPass(
      controller,
      src,
      dest,
      localMask,
      rect.width,
      rect.height,
      blendFactor: factor,
    );
    if (!changed) {
      continue;
    }
    anyChange = true;
    final Uint32List swap = src;
    src = dest;
    dest = swap;
  }
  if (!anyChange) {
    return;
  }
  if (!identical(src, workingPixels)) {
    workingPixels.setAll(0, src);
  }
  if (surface.isTiled) {
    surface.writeRect(rect, workingPixels);
  } else {
    _controllerWriteSurfaceRegion(
      sourcePixels,
      controller._width,
      rect,
      workingPixels,
    );
    surface.markDirty();
  }
  controller._markDirty(
    region: Rect.fromLTRB(
      rect.left.toDouble(),
      rect.top.toDouble(),
      rect.right.toDouble(),
      rect.bottom.toDouble(),
    ),
    layerId: controller._activeLayer.id,
    pixelsDirty: true,
  );
}

bool _fillRunMaskedAntialiasPass(
  BitmapCanvasController controller,
  Uint32List src,
  Uint32List dest,
  Uint8List mask,
  int width,
  int height, {
  required double blendFactor,
}) {
  final bool changed = controller._runAntialiasPass(
    src,
    dest,
    width,
    height,
    blendFactor,
  );
  if (!changed) {
    return false;
  }
  bool maskChanged = false;
  final int limit = math.min(mask.length, src.length);
  for (int i = 0; i < limit; i++) {
    if (mask[i] == 0) {
      dest[i] = src[i];
      continue;
    }
    if (!maskChanged && dest[i] != src[i]) {
      maskChanged = true;
    }
  }
  return maskChanged;
}

Rect? _fillMaskBounds(BitmapCanvasController controller, Uint8List mask) {
  if (mask.isEmpty) {
    return null;
  }
  int minX = controller._width;
  int minY = controller._height;
  int maxX = -1;
  int maxY = -1;
  int index = 0;
  for (int y = 0; y < controller._height; y++) {
    for (int x = 0; x < controller._width; x++, index++) {
      if (index >= mask.length) {
        break;
      }
      if (mask[index] == 0) {
        continue;
      }
      if (x < minX) {
        minX = x;
      }
      if (y < minY) {
        minY = y;
      }
      if (x > maxX) {
        maxX = x;
      }
      if (y > maxY) {
        maxY = y;
      }
    }
    if (index >= mask.length) {
      break;
    }
  }
  if (maxX < minX || maxY < minY) {
    return null;
  }
  return Rect.fromLTRB(
    minX.toDouble(),
    minY.toDouble(),
    (maxX + 1).toDouble(),
    (maxY + 1).toDouble(),
  );
}

Rect? _fillMaskBoundsLocal(Uint8List mask, int width, int height) {
  if (mask.isEmpty || width <= 0 || height <= 0) {
    return null;
  }
  int minX = width;
  int minY = height;
  int maxX = -1;
  int maxY = -1;
  int index = 0;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++, index++) {
      if (index >= mask.length) {
        break;
      }
      if (mask[index] == 0) {
        continue;
      }
      if (x < minX) {
        minX = x;
      }
      if (y < minY) {
        minY = y;
      }
      if (x > maxX) {
        maxX = x;
      }
      if (y > maxY) {
        maxY = y;
      }
    }
    if (index >= mask.length) {
      break;
    }
  }
  if (maxX < minX || maxY < minY) {
    return null;
  }
  return Rect.fromLTRB(
    minX.toDouble(),
    minY.toDouble(),
    (maxX + 1).toDouble(),
    (maxY + 1).toDouble(),
  );
}

RasterIntRect _fillInflateMaskBounds(
  RasterIntRect bounds,
  int width,
  int height,
  int radius,
) {
  final int left = math.max(0, bounds.left - radius);
  final int top = math.max(0, bounds.top - radius);
  final int right = math.min(width, bounds.right + radius);
  final int bottom = math.min(height, bounds.bottom + radius);
  return RasterIntRect(left, top, right, bottom);
}

RasterIntRect _fillExpandMaskInPlaceLocal(
  Uint8List mask,
  int width,
  int height,
  RasterIntRect bounds, {
  int radius = 1,
}) {
  if (mask.isEmpty || width <= 0 || height <= 0 || radius <= 0) {
    return bounds;
  }
  final int boundLeft = bounds.left.clamp(0, width);
  final int boundTop = bounds.top.clamp(0, height);
  final int boundRight = bounds.right.clamp(0, width);
  final int boundBottom = bounds.bottom.clamp(0, height);
  if (boundLeft >= boundRight || boundTop >= boundBottom) {
    return bounds;
  }
  final RasterIntRect expanded = _fillInflateMaskBounds(
    RasterIntRect(boundLeft, boundTop, boundRight, boundBottom),
    width,
    height,
    radius,
  );
  if (expanded.isEmpty) {
    return bounds;
  }
  final int localWidth = expanded.width;
  final int localHeight = expanded.height;
  final Uint8List expandedMask = Uint8List(localWidth * localHeight);
  for (int y = boundTop; y < boundBottom; y++) {
    final int rowOffset = y * width;
    for (int x = boundLeft; x < boundRight; x++) {
      if (mask[rowOffset + x] == 0) {
        continue;
      }
      final int minX = math.max(expanded.left, x - radius);
      final int maxX = math.min(expanded.right - 1, x + radius);
      final int minY = math.max(expanded.top, y - radius);
      final int maxY = math.min(expanded.bottom - 1, y + radius);
      for (int ny = minY; ny <= maxY; ny++) {
        final int localRow = (ny - expanded.top) * localWidth;
        final int localStart = localRow + (minX - expanded.left);
        final int localEnd = localRow + (maxX - expanded.left) + 1;
        expandedMask.fillRange(localStart, localEnd, 1);
      }
    }
  }
  for (int row = 0; row < localHeight; row++) {
    final int dstRowStart = (expanded.top + row) * width + expanded.left;
    final int srcRowStart = row * localWidth;
    for (int col = 0; col < localWidth; col++) {
      if (expandedMask[srcRowStart + col] != 0) {
        mask[dstRowStart + col] = 1;
      }
    }
  }
  return expanded;
}

Uint8List _fillExpandMask(
  Uint8List mask,
  int width,
  int height, {
  int radius = 1,
}) {
  if (mask.isEmpty || width <= 0 || height <= 0 || radius <= 0) {
    return mask;
  }
  final Uint8List expanded = Uint8List(mask.length);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int index = y * width + x;
      if (index >= mask.length) {
        break;
      }
      if (mask[index] == 0) {
        continue;
      }
      final int minX = math.max(0, x - radius);
      final int maxX = math.min(width - 1, x + radius);
      final int minY = math.max(0, y - radius);
      final int maxY = math.min(height - 1, y + radius);
      for (int ny = minY; ny <= maxY; ny++) {
        for (int nx = minX; nx <= maxX; nx++) {
          final int expandedIndex = ny * width + nx;
          if (expandedIndex < expanded.length) {
            expanded[expandedIndex] = 1;
          }
        }
      }
    }
  }
  return expanded;
}

RasterIntRect? _fillFloodFillMask(
  BitmapCanvasController controller, {
  required Uint32List pixels,
  required int targetColor,
  required Uint8List mask,
  required int startX,
  required int startY,
  required int width,
  required int height,
  int tolerance = 0,
  int fillGap = 0,
}) {
  if (pixels.isEmpty || mask.isEmpty || width <= 0 || height <= 0) {
    return null;
  }
  final int startIndex = startY * width + startX;
  if (startX < 0 ||
      startX >= width ||
      startY < 0 ||
      startY >= height ||
      startIndex < 0 ||
      startIndex >= pixels.length) {
    return null;
  }

  final Uint8List? selectionMask = controller._selectionMaskIsFull
      ? null
      : controller._selectionMask;
  RasterIntRect? selectionBounds = selectionMask == null
      ? null
      : controller._selectionMaskBounds;
  if (selectionMask != null && selectionBounds == null) {
    selectionBounds = _controllerMaskBounds(
      selectionMask,
      controller._width,
      controller._height,
    );
  }
  if (selectionMask != null && selectionMask[startIndex] == 0) {
    return null;
  }

  int minX = width;
  int minY = height;
  int maxX = -1;
  int maxY = -1;
  void markFilled(int index) {
    if (mask[index] == 0) {
      mask[index] = 1;
    }
    final int x = index % width;
    final int y = index ~/ width;
    if (x < minX) {
      minX = x;
    }
    if (x > maxX) {
      maxX = x;
    }
    if (y < minY) {
      minY = y;
    }
    if (y > maxY) {
      maxY = y;
    }
  }

  RasterIntRect? buildBounds() {
    if (maxX < minX || maxY < minY) {
      return null;
    }
    return RasterIntRect(minX, minY, maxX + 1, maxY + 1);
  }

  final int clampedFillGap = fillGap.clamp(0, 64);
  if (clampedFillGap > 0) {
    final Uint8List targetMask = Uint8List(pixels.length);
    if (selectionMask != null && selectionBounds == null) {
      return null;
    }
    if (selectionBounds != null) {
      final int left = selectionBounds.left;
      final int top = selectionBounds.top;
      final int right = selectionBounds.right;
      final int bottom = selectionBounds.bottom;
      for (int y = top; y < bottom; y++) {
        final int rowOffset = y * width;
        for (int x = left; x < right; x++) {
          final int i = rowOffset + x;
          if (selectionMask != null && selectionMask[i] == 0) {
            continue;
          }
          if (_fillColorsWithinTolerance(pixels[i], targetColor, tolerance)) {
            targetMask[i] = 1;
          }
        }
      }
    } else {
      for (int i = 0; i < pixels.length; i++) {
        if (selectionMask != null && selectionMask[i] == 0) {
          continue;
        }
        if (_fillColorsWithinTolerance(pixels[i], targetColor, tolerance)) {
          targetMask[i] = 1;
        }
      }
    }
    if (targetMask[startIndex] == 0) {
      return null;
    }

    // "Fill gap" should only prevent leaking through small openings.
    // Using the opened mask directly can delete thin enclosed regions (e.g. narrow curved bands),
    // so we:
    // 1) Compute an opened mask to sever narrow leak paths,
    // 2) Find the "outside" region on the opened mask (border-connected),
    // 3) Reconstruct the fill inside the original target mask while forbidding entry into "outside".

    final Uint8List openedTarget = _fillOpenMask8(
      Uint8List.fromList(targetMask),
      width,
      height,
      radius: clampedFillGap,
    );

    final List<int> outsideSeeds = <int>[];
    for (int x = 0; x < width; x++) {
      final int topIndex = x;
      if (topIndex < openedTarget.length && openedTarget[topIndex] == 1) {
        outsideSeeds.add(topIndex);
      }
      final int bottomIndex = (height - 1) * width + x;
      if (bottomIndex >= 0 &&
          bottomIndex < openedTarget.length &&
          openedTarget[bottomIndex] == 1) {
        outsideSeeds.add(bottomIndex);
      }
    }
    for (int y = 1; y < height - 1; y++) {
      final int leftIndex = y * width;
      if (leftIndex < openedTarget.length && openedTarget[leftIndex] == 1) {
        outsideSeeds.add(leftIndex);
      }
      final int rightIndex = y * width + (width - 1);
      if (rightIndex >= 0 &&
          rightIndex < openedTarget.length &&
          openedTarget[rightIndex] == 1) {
        outsideSeeds.add(rightIndex);
      }
    }

    // No border-connected target region → there is no "outside" to leak into.
    if (outsideSeeds.isEmpty) {
      final List<int> queue = <int>[startIndex];
      int head = 0;
      markFilled(startIndex);
      final Uint8List visited = Uint8List(pixels.length);
      visited[startIndex] = 1;
      while (head < queue.length) {
        final int index = queue[head++];
        final int x = index % width;
        final int y = index ~/ width;
        if (x > 0) {
          final int neighbor = index - 1;
          if (visited[neighbor] == 0 && targetMask[neighbor] == 1) {
            visited[neighbor] = 1;
            markFilled(neighbor);
            queue.add(neighbor);
          }
        }
        if (x < width - 1) {
          final int neighbor = index + 1;
          if (visited[neighbor] == 0 && targetMask[neighbor] == 1) {
            visited[neighbor] = 1;
            markFilled(neighbor);
            queue.add(neighbor);
          }
        }
        if (y > 0) {
          final int neighbor = index - width;
          if (visited[neighbor] == 0 && targetMask[neighbor] == 1) {
            visited[neighbor] = 1;
            markFilled(neighbor);
            queue.add(neighbor);
          }
        }
        if (y < height - 1) {
          final int neighbor = index + width;
          if (visited[neighbor] == 0 && targetMask[neighbor] == 1) {
            visited[neighbor] = 1;
            markFilled(neighbor);
            queue.add(neighbor);
          }
        }
      }
      return buildBounds();
    }

    final Uint8List outsideOpen = Uint8List(pixels.length);
    final List<int> outsideQueue = List<int>.from(outsideSeeds);
    int outsideHead = 0;
    for (final int seed in outsideSeeds) {
      outsideOpen[seed] = 1;
    }
    while (outsideHead < outsideQueue.length) {
      final int index = outsideQueue[outsideHead++];
      final int x = index % width;
      final int y = index ~/ width;
      if (x > 0) {
        final int neighbor = index - 1;
        if (outsideOpen[neighbor] == 0 && openedTarget[neighbor] == 1) {
          outsideOpen[neighbor] = 1;
          outsideQueue.add(neighbor);
        }
      }
      if (x < width - 1) {
        final int neighbor = index + 1;
        if (outsideOpen[neighbor] == 0 && openedTarget[neighbor] == 1) {
          outsideOpen[neighbor] = 1;
          outsideQueue.add(neighbor);
        }
      }
      if (y > 0) {
        final int neighbor = index - width;
        if (outsideOpen[neighbor] == 0 && openedTarget[neighbor] == 1) {
          outsideOpen[neighbor] = 1;
          outsideQueue.add(neighbor);
        }
      }
      if (y < height - 1) {
        final int neighbor = index + width;
        if (outsideOpen[neighbor] == 0 && openedTarget[neighbor] == 1) {
          outsideOpen[neighbor] = 1;
          outsideQueue.add(neighbor);
        }
      }
    }

    int effectiveStart = startIndex;
    if (openedTarget[effectiveStart] == 0) {
      final int? snapped = _fillFindNearestFillableStartIndex(
        startIndex: startIndex,
        fillable: openedTarget,
        pixels: pixels,
        targetColor: targetColor,
        width: width,
        height: height,
        tolerance: tolerance,
        selectionMask: selectionMask,
        maxDepth: clampedFillGap + 1,
      );
      if (snapped == null) {
        // Opening removed the whole local region; no gap closing can be applied safely.
        final List<int> queue = <int>[startIndex];
        int head = 0;
        markFilled(startIndex);
        final Uint8List visited = Uint8List(pixels.length);
        visited[startIndex] = 1;
        while (head < queue.length) {
          final int index = queue[head++];
          final int x = index % width;
          final int y = index ~/ width;
          if (x > 0) {
            final int neighbor = index - 1;
            if (visited[neighbor] == 0 && targetMask[neighbor] == 1) {
              visited[neighbor] = 1;
              markFilled(neighbor);
              queue.add(neighbor);
            }
          }
          if (x < width - 1) {
            final int neighbor = index + 1;
            if (visited[neighbor] == 0 && targetMask[neighbor] == 1) {
              visited[neighbor] = 1;
              markFilled(neighbor);
              queue.add(neighbor);
            }
          }
          if (y > 0) {
            final int neighbor = index - width;
            if (visited[neighbor] == 0 && targetMask[neighbor] == 1) {
              visited[neighbor] = 1;
              markFilled(neighbor);
              queue.add(neighbor);
            }
          }
          if (y < height - 1) {
            final int neighbor = index + width;
            if (visited[neighbor] == 0 && targetMask[neighbor] == 1) {
              visited[neighbor] = 1;
              markFilled(neighbor);
              queue.add(neighbor);
            }
          }
        }
        return buildBounds();
      }
      effectiveStart = snapped;
    }

    final Uint8List seedVisited = Uint8List(pixels.length);
    final List<int> seedQueue = <int>[effectiveStart];
    seedVisited[effectiveStart] = 1;
    int seedHead = 0;
    bool touchesOutside = outsideOpen[effectiveStart] == 1;
    while (seedHead < seedQueue.length) {
      final int index = seedQueue[seedHead++];
      if (outsideOpen[index] == 1) {
        touchesOutside = true;
        break;
      }
      final int x = index % width;
      final int y = index ~/ width;
      if (x > 0) {
        final int neighbor = index - 1;
        if (seedVisited[neighbor] == 0 && openedTarget[neighbor] == 1) {
          seedVisited[neighbor] = 1;
          seedQueue.add(neighbor);
        }
      }
      if (x < width - 1) {
        final int neighbor = index + 1;
        if (seedVisited[neighbor] == 0 && openedTarget[neighbor] == 1) {
          seedVisited[neighbor] = 1;
          seedQueue.add(neighbor);
        }
      }
      if (y > 0) {
        final int neighbor = index - width;
        if (seedVisited[neighbor] == 0 && openedTarget[neighbor] == 1) {
          seedVisited[neighbor] = 1;
          seedQueue.add(neighbor);
        }
      }
      if (y < height - 1) {
        final int neighbor = index + width;
        if (seedVisited[neighbor] == 0 && openedTarget[neighbor] == 1) {
          seedVisited[neighbor] = 1;
          seedQueue.add(neighbor);
        }
      }
    }

    if (touchesOutside) {
      // Gap is larger than the chosen radius; fall back to standard flood fill.
      final List<int> queue = <int>[startIndex];
      int head = 0;
      markFilled(startIndex);
      final Uint8List visited = Uint8List(pixels.length);
      visited[startIndex] = 1;
      while (head < queue.length) {
        final int index = queue[head++];
        final int x = index % width;
        final int y = index ~/ width;
        if (x > 0) {
          final int neighbor = index - 1;
          if (visited[neighbor] == 0 && targetMask[neighbor] == 1) {
            visited[neighbor] = 1;
            markFilled(neighbor);
            queue.add(neighbor);
          }
        }
        if (x < width - 1) {
          final int neighbor = index + 1;
          if (visited[neighbor] == 0 && targetMask[neighbor] == 1) {
            visited[neighbor] = 1;
            markFilled(neighbor);
            queue.add(neighbor);
          }
        }
        if (y > 0) {
          final int neighbor = index - width;
          if (visited[neighbor] == 0 && targetMask[neighbor] == 1) {
            visited[neighbor] = 1;
            markFilled(neighbor);
            queue.add(neighbor);
          }
        }
        if (y < height - 1) {
          final int neighbor = index + width;
          if (visited[neighbor] == 0 && targetMask[neighbor] == 1) {
            visited[neighbor] = 1;
            markFilled(neighbor);
            queue.add(neighbor);
          }
        }
      }
      return buildBounds();
    }

    final List<int> queue = List<int>.from(seedQueue);
    int head = 0;
    for (final int index in queue) {
      if (targetMask[index] == 1 &&
          outsideOpen[index] == 0 &&
          mask[index] == 0) {
        markFilled(index);
      }
    }
    while (head < queue.length) {
      final int index = queue[head++];
      final int x = index % width;
      final int y = index ~/ width;
      if (x > 0) {
        final int neighbor = index - 1;
        if (mask[neighbor] == 0 &&
            targetMask[neighbor] == 1 &&
            outsideOpen[neighbor] == 0) {
          markFilled(neighbor);
          queue.add(neighbor);
        }
      }
      if (x < width - 1) {
        final int neighbor = index + 1;
        if (mask[neighbor] == 0 &&
            targetMask[neighbor] == 1 &&
            outsideOpen[neighbor] == 0) {
          markFilled(neighbor);
          queue.add(neighbor);
        }
      }
      if (y > 0) {
        final int neighbor = index - width;
        if (mask[neighbor] == 0 &&
            targetMask[neighbor] == 1 &&
            outsideOpen[neighbor] == 0) {
          markFilled(neighbor);
          queue.add(neighbor);
        }
      }
      if (y < height - 1) {
        final int neighbor = index + width;
        if (mask[neighbor] == 0 &&
            targetMask[neighbor] == 1 &&
            outsideOpen[neighbor] == 0) {
          markFilled(neighbor);
          queue.add(neighbor);
        }
      }
    }
    return buildBounds();
  }

  final Uint8List visited = Uint8List(pixels.length);
  final List<int> queue = <int>[];
  int head = 0;

  void enqueueIndex(int index) {
    if (index < 0 || index >= pixels.length) {
      return;
    }
    if (visited[index] != 0) {
      return;
    }
    visited[index] = 1;
    if (selectionMask != null && selectionMask[index] == 0) {
      return;
    }
    if (!_fillColorsWithinTolerance(pixels[index], targetColor, tolerance)) {
      return;
    }
    markFilled(index);
    queue.add(index);
  }

  enqueueIndex(startIndex);

  while (head < queue.length) {
    final int index = queue[head++];
    final int x = index % width;
    final int y = index ~/ width;
    if (x > 0) {
      enqueueIndex(index - 1);
    }
    if (x < width - 1) {
      enqueueIndex(index + 1);
    }
    if (y > 0) {
      enqueueIndex(index - width);
    }
    if (y < height - 1) {
      enqueueIndex(index + width);
    }
  }

  return buildBounds();
}

Uint8List _fillOpenMask8(
  Uint8List mask,
  int width,
  int height, {
  required int radius,
}) {
  if (mask.isEmpty || width <= 0 || height <= 0 || radius <= 0) {
    return mask;
  }
  final int length = mask.length;
  final Uint8List buffer = Uint8List(length);
  final List<int> queue = <int>[];

  void dilateFromMaskValue(Uint8List source, Uint8List out, int seedValue) {
    queue.clear();
    out.fillRange(0, out.length, 0);
    for (int i = 0; i < source.length; i++) {
      if (source[i] != seedValue) {
        continue;
      }
      out[i] = 1;
      queue.add(i);
    }
    if (queue.isEmpty) {
      return;
    }
    int head = 0;
    final int lastRowStart = (height - 1) * width;
    for (int step = 0; step < radius; step++) {
      final int levelEnd = queue.length;
      while (head < levelEnd) {
        final int index = queue[head++];
        final int x = index % width;
        final bool hasLeft = x > 0;
        final bool hasRight = x < width - 1;
        final bool hasUp = index >= width;
        final bool hasDown = index < lastRowStart;

        void tryAdd(int neighbor) {
          if (neighbor < 0 || neighbor >= out.length) {
            return;
          }
          if (out[neighbor] != 0) {
            return;
          }
          out[neighbor] = 1;
          queue.add(neighbor);
        }

        if (hasLeft) {
          tryAdd(index - 1);
        }
        if (hasRight) {
          tryAdd(index + 1);
        }
        if (hasUp) {
          tryAdd(index - width);
          if (hasLeft) {
            tryAdd(index - width - 1);
          }
          if (hasRight) {
            tryAdd(index - width + 1);
          }
        }
        if (hasDown) {
          tryAdd(index + width);
          if (hasLeft) {
            tryAdd(index + width - 1);
          }
          if (hasRight) {
            tryAdd(index + width + 1);
          }
        }
      }
    }
  }

  // Phase 1 (Erosion): erode by dilating the inverse and then inverting.
  dilateFromMaskValue(mask, buffer, 0);
  for (int i = 0; i < length; i++) {
    mask[i] = buffer[i] == 0 ? 1 : 0;
  }

  // Phase 2 (Dilation): dilate eroded mask.
  dilateFromMaskValue(mask, buffer, 1);
  return buffer;
}

int? _fillFindNearestFillableStartIndex({
  required int startIndex,
  required Uint8List fillable,
  required Uint32List pixels,
  required int targetColor,
  required int width,
  required int height,
  required int tolerance,
  required Uint8List? selectionMask,
  required int maxDepth,
}) {
  if (startIndex < 0 || startIndex >= fillable.length) {
    return null;
  }
  if (fillable[startIndex] == 1) {
    return startIndex;
  }

  final Set<int> visited = <int>{startIndex};
  final List<int> queue = <int>[startIndex];
  int head = 0;

  for (int depth = 0; depth <= maxDepth; depth++) {
    final int levelEnd = queue.length;
    while (head < levelEnd) {
      final int index = queue[head++];
      if (fillable[index] == 1) {
        return index;
      }

      final int x = index % width;
      final int y = index ~/ width;

      void tryNeighbor(int nx, int ny) {
        if (nx < 0 || nx >= width || ny < 0 || ny >= height) {
          return;
        }
        final int neighbor = ny * width + nx;
        if (!visited.add(neighbor)) {
          return;
        }
        if (selectionMask != null && selectionMask[neighbor] == 0) {
          return;
        }
        if (!_fillColorsWithinTolerance(
          pixels[neighbor],
          targetColor,
          tolerance,
        )) {
          return;
        }
        queue.add(neighbor);
      }

      tryNeighbor(x - 1, y);
      tryNeighbor(x + 1, y);
      tryNeighbor(x, y - 1);
      tryNeighbor(x, y + 1);
    }
    if (head >= queue.length) {
      break;
    }
  }
  return null;
}

bool _fillColorsWithinTolerance(int candidate, int target, int tolerance) {
  if (tolerance <= 0) {
    return candidate == target;
  }
  final int ca = (candidate >> 24) & 0xff;
  final int cr = (candidate >> 16) & 0xff;
  final int cg = (candidate >> 8) & 0xff;
  final int cb = candidate & 0xff;
  final int ta = (target >> 24) & 0xff;
  final int tr = (target >> 16) & 0xff;
  final int tg = (target >> 8) & 0xff;
  final int tb = target & 0xff;
  final int diffA = (ca - ta).abs();
  final int diffR = (cr - tr).abs();
  final int diffG = (cg - tg).abs();
  final int diffB = (cb - tb).abs();
  final int maxRgb = math.max(math.max(diffR, diffG), diffB);
  final int maxDiff = math.max(maxRgb, diffA);
  return maxDiff <= tolerance;
}

Color _fillColorAtComposite(
  BitmapCanvasController controller,
  Offset position, {
  bool preferRealtime = false,
}) {
  return controller._rasterBackend.colorAtComposite(
    position,
    controller._layers.cast<CanvasCompositeLayer>(),
    translatingLayerId: controller._translatingLayerIdForComposite,
    preferRealtime: preferRealtime,
  );
}

Color _fillColorAtSurface(
  BitmapCanvasController controller,
  LayerSurface surface,
  int x,
  int y,
) {
  final int argb = surface.pixelAt(x, y);
  return BitmapSurface.decodeColor(argb);
}
