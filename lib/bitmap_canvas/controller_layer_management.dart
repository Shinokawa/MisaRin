part of 'controller.dart';

void _layerManagerSetActiveLayer(BitmapCanvasController controller, String id) {
  final int index = controller._layers.indexWhere((layer) => layer.id == id);
  if (index < 0 || index == controller._activeIndex) {
    return;
  }
  controller._activeIndex = index;
  controller._resetWorkerSurfaceSync();
  controller._notify();
}

void _layerManagerUpdateVisibility(
  BitmapCanvasController controller,
  String id,
  bool visible,
) {
  final int index = controller._layers.indexWhere((layer) => layer.id == id);
  if (index < 0) {
    return;
  }
  controller._layers[index].visible = visible;
  if (!visible && controller._activeIndex == index) {
    controller._activeIndex = _findFallbackActiveIndex(
      controller,
      exclude: index,
    );
  }
  controller._markDirty(pixelsDirty: false);
}

void _layerManagerSetOpacity(
  BitmapCanvasController controller,
  String id,
  double opacity,
) {
  final int index = controller._layers.indexWhere((layer) => layer.id == id);
  if (index < 0) {
    return;
  }
  final double clamped = BitmapCanvasController._clampUnit(opacity);
  final BitmapLayerState layer = controller._layers[index];
  if ((layer.opacity - clamped).abs() < 1e-4) {
    return;
  }
  layer.opacity = clamped;
  controller._markDirty(pixelsDirty: false);
  controller._notify();
}

void _layerManagerSetLocked(
  BitmapCanvasController controller,
  String id,
  bool locked,
) {
  final int index = controller._layers.indexWhere((layer) => layer.id == id);
  if (index < 0) {
    return;
  }
  final BitmapLayerState layer = controller._layers[index];
  if (layer.locked == locked) {
    return;
  }
  layer.locked = locked;
  controller._notify();
}

void _layerManagerSetClippingMask(
  BitmapCanvasController controller,
  String id,
  bool clippingMask,
) {
  final int index = controller._layers.indexWhere((layer) => layer.id == id);
  if (index < 0) {
    return;
  }
  final BitmapLayerState layer = controller._layers[index];
  if (layer.clippingMask == clippingMask) {
    return;
  }
  layer.clippingMask = clippingMask;
  controller._markDirty(pixelsDirty: false);
  controller._notify();
}

void _layerManagerSetBlendMode(
  BitmapCanvasController controller,
  String id,
  CanvasLayerBlendMode mode,
) {
  final int index = controller._layers.indexWhere((layer) => layer.id == id);
  if (index < 0) {
    return;
  }
  final BitmapLayerState layer = controller._layers[index];
  if (layer.blendMode == mode) {
    return;
  }
  layer.blendMode = mode;
  controller._markDirty(pixelsDirty: false);
  controller._notify();
}

void _layerManagerRenameLayer(
  BitmapCanvasController controller,
  String id,
  String name,
) {
  final int index = controller._layers.indexWhere((layer) => layer.id == id);
  if (index < 0) {
    return;
  }
  controller._layers[index].name = name;
  controller._notify();
}

void _layerManagerAddLayer(
  BitmapCanvasController controller, {
  String? aboveLayerId,
  String? name,
}) {
  final BitmapLayerState layer = BitmapLayerState(
    id: generateLayerId(),
    name: name ?? '图层 ${controller._layers.length + 1}',
    surface: controller._createLayerSurface(),
  );
  int insertIndex = controller._layers.length;
  if (aboveLayerId != null) {
    final int index = controller._layers.indexWhere(
      (candidate) => candidate.id == aboveLayerId,
    );
    if (index >= 0) {
      insertIndex = index + 1;
    }
  }
  controller._layers.insert(insertIndex, layer);
  controller._activeIndex = insertIndex;
  controller._resetWorkerSurfaceSync();
  controller._layerOverflowStores[layer.id] = _LayerOverflowStore();
  controller._markDirty(pixelsDirty: false);
}

void _layerManagerRemoveLayer(BitmapCanvasController controller, String id) {
  if (controller._layers.length <= 1) {
    return;
  }
  final int index = controller._layers.indexWhere((layer) => layer.id == id);
  if (index < 0) {
    return;
  }
  controller._layers.removeAt(index);
  controller._layerOverflowStores.remove(id);
  controller._rustWgpuBrushSyncedRevisions.remove(id);
  unawaited(() async {
    try {
      await ensureRustInitialized();
      rust_wgpu_brush.rustWgpuRemoveLayer(layerId: id);
    } catch (_) {}
  }());
  if (controller._activeIndex >= controller._layers.length) {
    controller._activeIndex = controller._layers.length - 1;
  }
  controller._resetWorkerSurfaceSync();
  controller._markDirty(pixelsDirty: false);
}

void _layerManagerReorderLayer(
  BitmapCanvasController controller,
  int fromIndex,
  int toIndex,
) {
  if (fromIndex < 0 || fromIndex >= controller._layers.length) {
    return;
  }
  int target = toIndex;
  if (target > fromIndex) {
    target -= 1;
  }
  target = target.clamp(0, controller._layers.length - 1);
  final BitmapLayerState layer = controller._layers.removeAt(fromIndex);
  controller._layers.insert(target, layer);
  if (controller._activeIndex == fromIndex) {
    controller._activeIndex = target;
  } else if (fromIndex < controller._activeIndex &&
      target >= controller._activeIndex) {
    controller._activeIndex -= 1;
  } else if (fromIndex > controller._activeIndex &&
      target <= controller._activeIndex) {
    controller._activeIndex += 1;
  }
  controller._resetWorkerSurfaceSync();
  controller._markDirty(pixelsDirty: false);
}

bool _layerManagerMergeLayerDown(BitmapCanvasController controller, String id) {
  final List<BitmapLayerState> layers = controller._layers;
  final int index = layers.indexWhere((layer) => layer.id == id);
  if (index <= 0) {
    return false;
  }
  final BitmapLayerState upper = layers[index];
  if (upper.locked) {
    return false;
  }
  final BitmapLayerState lower = layers[index - 1];
  if (lower.locked) {
    return false;
  }
  final double opacity = upper.visible
      ? BitmapCanvasController._clampUnit(upper.opacity)
      : 0.0;
  final bool hasSurfaceContent = !BitmapCanvasController._isSurfaceEmpty(
    upper.surface,
  );
  final _LayerOverflowStore upperOverflow =
      controller._layerOverflowStores[upper.id] ?? _LayerOverflowStore();
  final bool hasOverflowContent = !upperOverflow.isEmpty;

  if (opacity > 0 && (hasSurfaceContent || hasOverflowContent)) {
    final _LayerOverflowStore lowerOverflow =
        controller._layerOverflowStores[lower.id] ?? _LayerOverflowStore();
    _mergeLayerIntoLower(
      controller,
      upper,
      lower,
      index,
      opacity,
      lowerOverflow,
      upperOverflow,
    );
    lower.surface.markDirty();
  }

  layers.removeAt(index);
  controller._layerOverflowStores.remove(upper.id);
  if (controller._activeIndex >= index) {
    if (controller._activeIndex == index) {
      controller._activeIndex = index - 1;
    } else {
      controller._activeIndex -= 1;
    }
  }
  controller._markDirty(layerId: lower.id, pixelsDirty: true);
  return true;
}

void _layerManagerClearAll(BitmapCanvasController controller) {
  for (int i = 0; i < controller._layers.length; i++) {
    final BitmapLayerState layer = controller._layers[i];
    if (layer.locked) {
      continue;
    }
    if (i == 0) {
      layer.surface.fill(controller._backgroundColor);
    } else {
      layer.surface.fill(const Color(0x00000000));
    }
  }
  controller._markDirty(pixelsDirty: true);
}

void _mergeLayerIntoLower(
  BitmapCanvasController controller,
  BitmapLayerState upper,
  BitmapLayerState lower,
  int upperIndex,
  double opacity,
  _LayerOverflowStore lowerOverflow,
  _LayerOverflowStore upperOverflow,
) {
  final bool hasClipping = upper.clippingMask;
  final _ClippingMaskInfo? clippingInfo = hasClipping
      ? _resolveClippingMaskInfo(controller, upperIndex)
      : null;
  if (hasClipping && clippingInfo == null) {
    return;
  }
  final bool needsBitmap =
      upper.surface.isTiled || lower.surface.isTiled;
  if (needsBitmap) {
    if (clippingInfo != null && clippingInfo.layer.surface.isTiled) {
      clippingInfo.layer.surface.withBitmapSurface(
        writeBack: false,
        action: (BitmapSurface maskSurface) {
          upper.surface.withBitmapSurface(
            writeBack: false,
            action: (BitmapSurface upperSurface) {
              lower.surface.withBitmapSurface(
                writeBack: true,
                action: (BitmapSurface lowerSurface) {
                  _blendOnCanvasPixels(
                    controller,
                    upperSurface.pixels,
                    lowerSurface.pixels,
                    opacity,
                    upper.blendMode,
                    clippingInfo,
                    srcPixelsPtr: upperSurface.pointerAddress,
                    dstPixelsPtr: lowerSurface.pointerAddress,
                    maskPtrOverride: maskSurface.pointerAddress,
                    maskLenOverride: maskSurface.pixels.length,
                    maskOpacityOverride: clippingInfo.opacity,
                  );
                  if (!upperOverflow.isEmpty) {
                    _blendOverflowPixels(
                      controller,
                      upperOverflow,
                      lower,
                      lowerOverflow,
                      opacity,
                      upper.blendMode,
                      clippingInfo,
                      canvasPtrOverride: lowerSurface.pointerAddress,
                      canvasLenOverride: lowerSurface.pixels.length,
                      maskPtrOverride: maskSurface.pointerAddress,
                      maskLenOverride: maskSurface.pixels.length,
                      maskOpacityOverride: clippingInfo.opacity,
                    );
                  }
                },
              );
            },
          );
        },
      );
    } else {
      upper.surface.withBitmapSurface(
        writeBack: false,
        action: (BitmapSurface upperSurface) {
          lower.surface.withBitmapSurface(
            writeBack: true,
            action: (BitmapSurface lowerSurface) {
              _blendOnCanvasPixels(
                controller,
                upperSurface.pixels,
                lowerSurface.pixels,
                opacity,
                upper.blendMode,
                clippingInfo,
                srcPixelsPtr: upperSurface.pointerAddress,
                dstPixelsPtr: lowerSurface.pointerAddress,
              );
              if (!upperOverflow.isEmpty) {
                _blendOverflowPixels(
                  controller,
                  upperOverflow,
                  lower,
                  lowerOverflow,
                  opacity,
                  upper.blendMode,
                  clippingInfo,
                  canvasPtrOverride: lowerSurface.pointerAddress,
                  canvasLenOverride: lowerSurface.pixels.length,
                );
              }
            },
          );
        },
      );
    }
    return;
  }

  _blendOnCanvasPixels(
    controller,
    upper.surface.pixels,
    lower.surface.pixels,
    opacity,
    upper.blendMode,
    clippingInfo,
    srcPixelsPtr: upper.surface.pointerAddress,
    dstPixelsPtr: lower.surface.pointerAddress,
  );
  if (!upperOverflow.isEmpty) {
    _blendOverflowPixels(
      controller,
      upperOverflow,
      lower,
      lowerOverflow,
      opacity,
      upper.blendMode,
      clippingInfo,
    );
  }
}

void _blendOnCanvasPixels(
  BitmapCanvasController controller,
  Uint32List srcPixels,
  Uint32List dstPixels,
  double opacity,
  CanvasLayerBlendMode blendMode,
  _ClippingMaskInfo? clippingInfo, {
  int? srcPixelsPtr,
  int? dstPixelsPtr,
  int? maskPtrOverride,
  int? maskLenOverride,
  double? maskOpacityOverride,
}) {
  final int srcPtr = srcPixelsPtr ?? 0;
  final int dstPtr = dstPixelsPtr ?? 0;
  if (srcPtr == 0 || dstPtr == 0 || !RustCpuBlendFfi.instance.isSupported) {
    return;
  }
  final Rect? bounds = _computePixelBounds(
    srcPixels,
    controller._width,
    controller._height,
    pixelsPtr: srcPtr,
  );
  if (bounds == null) {
    return;
  }
  final int startX = math.max(0, bounds.left.floor());
  final int endX = math.min(controller._width, bounds.right.ceil());
  final int startY = math.max(0, bounds.top.floor());
  final int endY = math.min(controller._height, bounds.bottom.ceil());
  if (startX >= endX || startY >= endY) {
    return;
  }
  int maskPtr = 0;
  int maskLen = 0;
  double maskOpacity = 0;
  if (clippingInfo != null) {
    maskPtr = clippingInfo.layer.surface.pointerAddress;
    if (maskPtr != 0) {
      maskLen = clippingInfo.layer.surface.pixelCount;
      maskOpacity = clippingInfo.opacity;
    }
  }
  if (maskPtrOverride != null) {
    maskPtr = maskPtrOverride;
    maskLen = maskLenOverride ?? maskLen;
    maskOpacity = maskOpacityOverride ?? maskOpacity;
  }
  if (clippingInfo != null && maskPtr == 0) {
    return;
  }
  RustCpuBlendFfi.instance.blendOnCanvas(
    srcPtr: srcPtr,
    dstPtr: dstPtr,
    pixelsLen: srcPixels.length,
    width: controller._width,
    height: controller._height,
    startX: startX,
    endX: endX,
    startY: startY,
    endY: endY,
    opacity: opacity,
    blendMode: blendMode.index,
    maskPtr: maskPtr,
    maskLen: maskLen,
    maskOpacity: maskOpacity,
  );
  return;
}

void _blendOverflowPixels(
  BitmapCanvasController controller,
  _LayerOverflowStore upperOverflow,
  BitmapLayerState lower,
  _LayerOverflowStore lowerOverflow,
  double opacity,
  CanvasLayerBlendMode blendMode,
  _ClippingMaskInfo? clippingInfo, {
  int? canvasPtrOverride,
  int? canvasLenOverride,
  int? maskPtrOverride,
  int? maskLenOverride,
  double? maskOpacityOverride,
}) {
  if (upperOverflow.isEmpty) {
    return;
  }
  final int canvasPtr = canvasPtrOverride ?? lower.surface.pointerAddress;
  final int maskPtr = maskPtrOverride ??
      (clippingInfo == null ? 0 : clippingInfo.layer.surface.pointerAddress);
  if (canvasPtr == 0 ||
      !RustCpuBlendFfi.instance.isSupported ||
      (clippingInfo != null && maskPtr == 0)) {
    return;
  }
  final int upperCount = _countOverflowPixels(upperOverflow);
  if (upperCount <= 0) {
    return;
  }
  CpuBuffer<Int32List>? upperX;
  CpuBuffer<Int32List>? upperY;
  CpuBuffer<Uint32List>? upperColor;
  CpuBuffer<Int32List>? lowerX;
  CpuBuffer<Int32List>? lowerY;
  CpuBuffer<Uint32List>? lowerColor;
  CpuBuffer<Int32List>? maskOverflowX;
  CpuBuffer<Int32List>? maskOverflowY;
  CpuBuffer<Uint32List>? maskOverflowColor;
  CpuBuffer<Int32List>? outX;
  CpuBuffer<Int32List>? outY;
  CpuBuffer<Uint32List>? outColor;
  CpuBuffer<Uint64List>? outCountPtr;
  try {
    upperX = allocateInt32(upperCount);
    upperY = allocateInt32(upperCount);
    upperColor = allocateUint32(upperCount);
    _fillOverflowArrays(
      upperOverflow,
      upperX.list,
      upperY.list,
      upperColor.list,
    );
    final int lowerCount = _countOverflowPixels(lowerOverflow);
    if (lowerCount > 0) {
      lowerX = allocateInt32(lowerCount);
      lowerY = allocateInt32(lowerCount);
      lowerColor = allocateUint32(lowerCount);
      _fillOverflowArrays(
        lowerOverflow,
        lowerX.list,
        lowerY.list,
        lowerColor.list,
      );
    }
    int maskLen = 0;
    double maskOpacity = 0;
    int maskOverflowCount = 0;
    if (clippingInfo != null) {
      maskLen = maskLenOverride ?? clippingInfo.layer.surface.pixelCount;
      maskOpacity = maskOpacityOverride ?? clippingInfo.opacity;
      maskOverflowCount = _countOverflowPixels(clippingInfo.overflow);
      if (maskOverflowCount > 0) {
        maskOverflowX = allocateInt32(maskOverflowCount);
        maskOverflowY = allocateInt32(maskOverflowCount);
        maskOverflowColor = allocateUint32(maskOverflowCount);
        _fillOverflowArrays(
          clippingInfo.overflow,
          maskOverflowX.list,
          maskOverflowY.list,
          maskOverflowColor.list,
        );
      }
    }
    final int outCapacity = upperCount + lowerCount;
    outX = allocateInt32(outCapacity);
    outY = allocateInt32(outCapacity);
    outColor = allocateUint32(outCapacity);
    outCountPtr = allocateUint64(1);
    final bool ok = RustCpuBlendFfi.instance.blendOverflow(
      canvasPtr: canvasPtr,
      canvasLen: canvasLenOverride ?? lower.surface.pixelCount,
      width: controller._width,
      height: controller._height,
      upperXPtr: upperX.address,
      upperYPtr: upperY.address,
      upperColorPtr: upperColor.address,
      upperLen: upperCount,
      lowerXPtr: lowerX?.address ?? 0,
      lowerYPtr: lowerY?.address ?? 0,
      lowerColorPtr: lowerColor?.address ?? 0,
      lowerLen: lowerCount,
      opacity: opacity,
      blendMode: blendMode.index,
      maskPtr: maskPtr,
      maskLen: maskLen,
      maskOpacity: maskOpacity,
      maskOverflowXPtr: maskOverflowX?.address ?? 0,
      maskOverflowYPtr: maskOverflowY?.address ?? 0,
      maskOverflowColorPtr: maskOverflowColor?.address ?? 0,
      maskOverflowLen: maskOverflowCount,
      outXPtr: outX.address,
      outYPtr: outY.address,
      outColorPtr: outColor.address,
      outCapacity: outCapacity,
      outCountPtr: outCountPtr.address,
    );
    if (ok) {
      final int count =
          outCountPtr.list.isNotEmpty ? outCountPtr.list[0] : 0;
      final _LayerOverflowBuilder overflowBuilder = _LayerOverflowBuilder();
      if (count > 0) {
        final Int32List xs = outX.list;
        final Int32List ys = outY.list;
        final Uint32List colors = outColor.list;
        for (int i = 0; i < count; i++) {
          overflowBuilder.addPixel(xs[i], ys[i], colors[i]);
        }
      }
      final _LayerOverflowStore mergedStore = overflowBuilder.build();
      if (mergedStore.isEmpty) {
        controller._layerOverflowStores.remove(lower.id);
      } else {
        controller._layerOverflowStores[lower.id] = mergedStore;
      }
    }
  } finally {
    upperX?.dispose();
    upperY?.dispose();
    upperColor?.dispose();
    lowerX?.dispose();
    lowerY?.dispose();
    lowerColor?.dispose();
    maskOverflowX?.dispose();
    maskOverflowY?.dispose();
    maskOverflowColor?.dispose();
    outX?.dispose();
    outY?.dispose();
    outColor?.dispose();
    outCountPtr?.dispose();
  }
  return;
}

class _ClippingMaskInfo {
  _ClippingMaskInfo({
    required this.layer,
    required this.opacity,
    required this.overflow,
  });

  final BitmapLayerState layer;
  final double opacity;
  final _LayerOverflowStore overflow;
}

_ClippingMaskInfo? _resolveClippingMaskInfo(
  BitmapCanvasController controller,
  int startIndex,
) {
  for (int i = startIndex - 1; i >= 0; i--) {
    final BitmapLayerState candidate = controller._layers[i];
    if (candidate.clippingMask) {
      continue;
    }
    if (!candidate.visible) {
      return null;
    }
    final double opacity = BitmapCanvasController._clampUnit(candidate.opacity);
    if (opacity <= 0) {
      return null;
    }
    final _LayerOverflowStore overflow =
        controller._layerOverflowStores[candidate.id] ?? _LayerOverflowStore();
    return _ClippingMaskInfo(
      layer: candidate,
      opacity: opacity,
      overflow: overflow,
    );
  }
  return null;
}

int _findFallbackActiveIndex(
  BitmapCanvasController controller, {
  int? exclude,
}) {
  for (int i = controller._layers.length - 1; i >= 0; i--) {
    if (i == exclude) {
      continue;
    }
    if (controller._layers[i].visible) {
      return i;
    }
  }
  return math.max(
    0,
    math.min(controller._layers.length - 1, controller._activeIndex),
  );
}

void _layerManagerClearRegion(
  BitmapCanvasController controller,
  String id, {
  Uint8List? mask,
}) {
  final int index = controller._layers.indexWhere((layer) => layer.id == id);
  if (index < 0) {
    return;
  }
  final BitmapLayerState layer = controller._layers[index];
  final int replacement = index == 0
      ? BitmapSurface.encodeColor(controller._backgroundColor)
      : 0;
  final bool isFullSelection =
      mask != null &&
      identical(mask, controller._selectionMask) &&
      controller._selectionMaskIsFull;
  if (mask == null || isFullSelection) {
    layer.surface.fill(BitmapSurface.decodeColor(replacement));
    controller._markDirty(layerId: id, pixelsDirty: true);
    return;
  }
  if (mask.length != controller._width * controller._height) {
    throw ArgumentError('Selection mask size mismatch');
  }
  RasterIntRect? maskBounds;
  if (identical(mask, controller._selectionMask)) {
    maskBounds = controller._selectionMaskBounds;
  }
  maskBounds ??= _controllerMaskBounds(
    mask,
    controller._width,
    controller._height,
  );
  if (maskBounds == null || maskBounds.isEmpty) {
    return;
  }
  int minX = controller._width;
  int minY = controller._height;
  int maxX = -1;
  int maxY = -1;
  void applyMask(BitmapSurface surface) {
    final Uint32List pixels = surface.pixels;
    for (int y = maskBounds!.top; y < maskBounds.bottom; y++) {
      final int rowOffset = y * controller._width;
      for (int x = maskBounds.left; x < maskBounds.right; x++) {
        final int indexInMask = rowOffset + x;
        if (mask[indexInMask] == 0) {
          continue;
        }
        pixels[indexInMask] = replacement;
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
    }
    if (replacement != 0) {
      surface.markDirty();
    }
  }

  if (layer.surface.isTiled) {
    final TiledSurface tiled = layer.surface.tiledSurface!;
    final int defaultArgb = tiled.defaultFill == null
        ? 0
        : BitmapSurface.encodeColor(tiled.defaultFill!);
    final bool createMissing = replacement != defaultArgb;
    bool anyChange = false;
    for (final TileEntry entry
        in tiled.tilesInRect(maskBounds, createMissing: createMissing)) {
      final Uint32List pixels = entry.surface.pixels;
      final RasterIntRect local = entry.localRect;
      final RasterIntRect global = entry.globalRect;
      bool tileChanged = false;
      for (int row = 0; row < local.height; row++) {
        final int globalY = global.top + row;
        final int maskRowOffset = globalY * controller._width + global.left;
        final int tileRowOffset =
            (local.top + row) * tiled.tileSize + local.left;
        for (int col = 0; col < local.width; col++) {
          final int maskIndex = maskRowOffset + col;
          if (mask[maskIndex] == 0) {
            continue;
          }
          final int pixelIndex = tileRowOffset + col;
          if (pixels[pixelIndex] == replacement) {
            continue;
          }
          pixels[pixelIndex] = replacement;
          tileChanged = true;
          anyChange = true;
          final int globalX = global.left + col;
          if (globalX < minX) {
            minX = globalX;
          }
          if (globalX > maxX) {
            maxX = globalX;
          }
          if (globalY < minY) {
            minY = globalY;
          }
          if (globalY > maxY) {
            maxY = globalY;
          }
        }
      }
      if (tileChanged && replacement != 0) {
        entry.surface.markDirty();
      }
    }
    if (!anyChange) {
      return;
    }
  } else {
    applyMask(layer.surface.bitmapSurface!);
  }
  if (maxX < minX || maxY < minY) {
    return;
  }
  controller._markDirty(
    region: Rect.fromLTRB(
      minX.toDouble(),
      minY.toDouble(),
      (maxX + 1).toDouble(),
      (maxY + 1).toDouble(),
    ),
    layerId: id,
    pixelsDirty: true,
  );
}

String _layerManagerInsertFromData(
  BitmapCanvasController controller,
  CanvasLayerData data, {
  String? aboveLayerId,
}) {
  final LayerSurface surface = controller._createLayerSurface();
  _LayerOverflowStore overflowStore = _LayerOverflowStore();
  if (data.rawPixels != null || data.bitmap != null) {
    overflowStore = _applyBitmapToSurface(controller, surface, data);
  } else if (data.fillColor != null) {
    surface.fill(data.fillColor!);
  } else {
    surface.fill(const Color(0x00000000));
  }
  CanvasTextData? textData = data.text;
  Rect? textBounds;
  if (textData != null) {
    textData = _alignTextDataToBitmap(
      textData,
      bitmapLeft: data.bitmapLeft,
      bitmapTop: data.bitmapTop,
    );
    textBounds = controller._textRenderer.layout(textData).bounds;
  }
  final BitmapLayerState layer = BitmapLayerState(
    id: data.id,
    name: data.name,
    surface: surface,
    visible: true,
    opacity: data.opacity,
    locked: false,
    clippingMask: false,
    blendMode: data.blendMode,
    text: textData,
    textBounds: textBounds,
  );
  int insertIndex = controller._layers.length;
  if (aboveLayerId != null) {
    final int index = controller._layers.indexWhere(
      (candidate) => candidate.id == aboveLayerId,
    );
    if (index >= 0) {
      insertIndex = index + 1;
    }
  }
  controller._layers.insert(insertIndex, layer);
  controller._activeIndex = insertIndex;
  controller._layerOverflowStores[layer.id] = overflowStore;
  controller._markDirty(pixelsDirty: false);
  return layer.id;
}

void _layerManagerReplaceLayer(
  BitmapCanvasController controller,
  String id,
  CanvasLayerData data,
) {
  final int index = controller._layers.indexWhere((layer) => layer.id == id);
  if (index < 0) {
    return;
  }
  final BitmapLayerState layer = controller._layers[index];
  layer
    ..name = data.name
    ..visible = data.visible
    ..opacity = data.opacity
    ..locked = data.locked
    ..clippingMask = data.clippingMask
    ..blendMode = data.blendMode;
  layer.surface.fill(const Color(0x00000000));
  _LayerOverflowStore overflowStore = _LayerOverflowStore();
  if (data.rawPixels != null || data.bitmap != null) {
    overflowStore = _applyBitmapToSurface(controller, layer.surface, data);
  } else if (data.fillColor != null) {
    layer.surface.fill(data.fillColor!);
    if (index == 0) {
      controller._backgroundColor = data.fillColor!;
    }
  } else {
    layer.surface.fill(const Color(0x00000000));
  }
  CanvasTextData? textData = data.text;
  Rect? textBounds;
  if (textData != null) {
    textData = _alignTextDataToBitmap(
      textData,
      bitmapLeft: data.bitmapLeft,
      bitmapTop: data.bitmapTop,
    );
    textBounds = controller._textRenderer.layout(textData).bounds;
  }
  layer.text = textData;
  layer.textBounds = textBounds;
  controller._layerOverflowStores[layer.id] = overflowStore;
  controller._resetWorkerSurfaceSync();
  controller._markDirty(layerId: id, pixelsDirty: true);
}

void _layerManagerLoadLayers(
  BitmapCanvasController controller,
  List<CanvasLayerData> layers,
  Color backgroundColor,
) {
  controller._cancelPendingWorkerTasks();
  controller._layers.clear();
  controller._rasterBackend.resetClipMask();
  _loadFromCanvasLayers(controller, layers, backgroundColor);
  controller._resetWorkerSurfaceSync();
  controller._markDirty(pixelsDirty: true);
}

RasterIntRect? _surfaceContentBounds(
  BitmapCanvasController controller,
  LayerSurface surface,
) {
  if (surface.isTiled) {
    final RasterIntRect? bounds = surface.tiledSurface?.contentBounds();
    if (bounds == null || bounds.isEmpty) {
      return null;
    }
    final int left = math.max(0, bounds.left);
    final int top = math.max(0, bounds.top);
    final int right = math.min(controller._width, bounds.right);
    final int bottom = math.min(controller._height, bounds.bottom);
    if (left >= right || top >= bottom) {
      return null;
    }
    return RasterIntRect(left, top, right, bottom);
  }
  final Rect? pixelBounds = _computePixelBounds(
    surface.pixels,
    controller._width,
    controller._height,
    pixelsPtr: surface.pointerAddress,
  );
  if (pixelBounds == null) {
    return null;
  }
  final int left = math.max(0, pixelBounds.left.floor());
  final int top = math.max(0, pixelBounds.top.floor());
  final int right = math.min(controller._width, pixelBounds.right.ceil());
  final int bottom = math.min(controller._height, pixelBounds.bottom.ceil());
  if (left >= right || top >= bottom) {
    return null;
  }
  return RasterIntRect(left, top, right, bottom);
}

List<CanvasLayerData> _layerManagerSnapshotLayers(
  BitmapCanvasController controller,
) {
  final List<CanvasLayerData> result = <CanvasLayerData>[];
  for (int i = 0; i < controller._layers.length; i++) {
    final BitmapLayerState layer = controller._layers[i];
    final _LayerOverflowStore overflowStore =
        controller._layerOverflowStores[layer.id] ?? _LayerOverflowStore();
    final bool hasOverflow = !overflowStore.isEmpty;
    Uint32List? rawPixels;
    int? bitmapWidth;
    int? bitmapHeight;
    int? bitmapLeft;
    int? bitmapTop;
    RasterIntRect? surfaceBounds;
    if (!hasOverflow) {
      surfaceBounds = _surfaceContentBounds(controller, layer.surface);
    }
    final bool hasSurface = surfaceBounds != null;
    if (hasSurface || hasOverflow) {
      if (!hasOverflow) {
        final RasterIntRect bounds = surfaceBounds!;
        rawPixels = layer.surface.readRect(bounds);
        bitmapWidth = bounds.width;
        bitmapHeight = bounds.height;
        bitmapLeft = bounds.left;
        bitmapTop = bounds.top;
      } else {
        final _LayerTransformSnapshot snapshot = _buildOverflowTransformSnapshot(
          controller,
          layer,
          overflowStore,
        );
        rawPixels = snapshot.pixels;
        bitmapWidth = snapshot.width;
        bitmapHeight = snapshot.height;
        bitmapLeft = snapshot.originX;
        bitmapTop = snapshot.originY;
      }
    }
    result.add(
      CanvasLayerData(
        id: layer.id,
        name: layer.name,
        visible: layer.visible,
        opacity: layer.opacity,
        locked: layer.locked,
        clippingMask: layer.clippingMask,
        blendMode: layer.blendMode,
        fillColor: i == 0 ? controller._backgroundColor : null,
        bitmap: null,
        rawPixels: rawPixels,
        bitmapWidth: bitmapWidth,
        bitmapHeight: bitmapHeight,
        bitmapLeft: bitmapLeft,
        bitmapTop: bitmapTop,
        text: layer.text,
        cloneRawPixels: false,
      ),
    );
  }
  return result;
}

CanvasLayerData? _layerManagerBuildClipboardLayer(
  BitmapCanvasController controller,
  String id, {
  Uint8List? mask,
}) {
  final int index = controller._layers.indexWhere((layer) => layer.id == id);
  if (index < 0) {
    return null;
  }
  final BitmapLayerState layer = controller._layers[index];
  Uint8List? effectiveMask;
  RasterIntRect? maskBounds;
  Uint8List? resolvedMask = mask;
  if (resolvedMask != null &&
      identical(resolvedMask, controller._selectionMask) &&
      controller._selectionMaskIsFull) {
    resolvedMask = null;
  }
  if (resolvedMask != null) {
    if (resolvedMask.length != controller._width * controller._height) {
      throw ArgumentError('Selection mask size mismatch');
    }
    if (identical(resolvedMask, controller._selectionMask)) {
      maskBounds = controller._selectionMaskBounds;
    }
    maskBounds ??= _controllerMaskBounds(
      resolvedMask,
      controller._width,
      controller._height,
    );
    if (maskBounds == null || maskBounds.isEmpty) {
      return null;
    }
    effectiveMask = Uint8List.fromList(resolvedMask);
  }
  Uint8List? bitmap;
  int bitmapWidth = controller._width;
  int bitmapHeight = controller._height;
  int bitmapLeft = 0;
  int bitmapTop = 0;
  if (effectiveMask == null) {
    final _LayerOverflowStore overflowStore =
        controller._layerOverflowStores[layer.id] ?? _LayerOverflowStore();
    if (!overflowStore.isEmpty) {
      final _LayerTransformSnapshot snapshot = _buildOverflowTransformSnapshot(
        controller,
        layer,
        overflowStore,
      );
      bitmap = BitmapCanvasController._pixelsToRgba(snapshot.pixels);
      bitmapWidth = snapshot.width;
      bitmapHeight = snapshot.height;
      bitmapLeft = snapshot.originX;
      bitmapTop = snapshot.originY;
    } else {
      final RasterIntRect? bounds =
          _surfaceContentBounds(controller, layer.surface);
      if (bounds != null) {
        final Uint32List pixels = layer.surface.readRect(bounds);
        bitmap = BitmapCanvasController._pixelsToRgba(pixels);
        bitmapWidth = bounds.width;
        bitmapHeight = bounds.height;
        bitmapLeft = bounds.left;
        bitmapTop = bounds.top;
      }
    }
  } else {
    final RasterIntRect bounds = maskBounds!;
    final int boundsWidth = maskBounds.width;
    final int boundsHeight = maskBounds.height;
    final Uint32List pixels = layer.surface.readRect(maskBounds);
    final Uint8List rgba = Uint8List(boundsWidth * boundsHeight * 4);
    for (int row = 0; row < boundsHeight; row++) {
      final int globalY = maskBounds.top + row;
      final int maskRowOffset = globalY * controller._width + maskBounds.left;
      final int srcRowOffset = row * boundsWidth;
      for (int col = 0; col < boundsWidth; col++) {
        if (effectiveMask[maskRowOffset + col] == 0) {
          continue;
        }
        final int argb = pixels[srcRowOffset + col];
        final int offset = (srcRowOffset + col) * 4;
        rgba[offset] = (argb >> 16) & 0xff;
        rgba[offset + 1] = (argb >> 8) & 0xff;
        rgba[offset + 2] = argb & 0xff;
        rgba[offset + 3] = (argb >> 24) & 0xff;
      }
    }
    bitmap = rgba;
    bitmapWidth = boundsWidth;
    bitmapHeight = boundsHeight;
    bitmapLeft = maskBounds.left;
    bitmapTop = maskBounds.top;
  }
  if (bitmap == null && layer.text == null) {
    return null;
  }
  return CanvasLayerData(
    id: layer.id,
    name: layer.name,
    visible: true,
    opacity: layer.opacity,
    locked: false,
    clippingMask: false,
    blendMode: layer.blendMode,
    fillColor: null,
    bitmap: bitmap,
    bitmapWidth: bitmapWidth,
    bitmapHeight: bitmapHeight,
    bitmapLeft: bitmapLeft,
    bitmapTop: bitmapTop,
    text: effectiveMask == null ? layer.text : null,
  );
}

void _initializeDefaultLayers(
  BitmapCanvasController controller,
  Color backgroundColor,
) {
  final LayerSurface background =
      controller._createLayerSurface(fillColor: backgroundColor);
  final LayerSurface paintSurface = controller._createLayerSurface();
  controller._layers
    ..add(
      BitmapLayerState(id: generateLayerId(), name: '背景', surface: background),
    )
    ..add(
      BitmapLayerState(
        id: generateLayerId(),
        name: '图层 2',
        surface: paintSurface,
      ),
    );
  for (final BitmapLayerState layer in controller._layers) {
    controller._layerOverflowStores[layer.id] = _LayerOverflowStore();
  }
  controller._activeIndex = controller._layers.length - 1;
}

CanvasTextData _alignTextDataToBitmap(
  CanvasTextData data, {
  int? bitmapLeft,
  int? bitmapTop,
}) {
  if (bitmapLeft == null || bitmapTop == null) {
    return data;
  }
  final bool needsUpdate =
      data.origin.dx != bitmapLeft.toDouble() ||
      data.origin.dy != bitmapTop.toDouble();
  if (!needsUpdate) {
    return data;
  }
  return data.copyWith(
    origin: Offset(bitmapLeft.toDouble(), bitmapTop.toDouble()),
  );
}

void _loadFromCanvasLayers(
  BitmapCanvasController controller,
  List<CanvasLayerData> layers,
  Color backgroundColor,
) {
  controller._backgroundColor = backgroundColor;
  if (layers.isEmpty) {
    _initializeDefaultLayers(controller, backgroundColor);
    return;
  }
  for (final CanvasLayerData layer in layers) {
    final LayerSurface surface = controller._createLayerSurface();
    _LayerOverflowStore overflowStore = _LayerOverflowStore();
    if (layer.rawPixels != null || layer.bitmap != null) {
      overflowStore = _applyBitmapToSurface(controller, surface, layer);
    } else if (layer.fillColor != null) {
      surface.fill(layer.fillColor!);
    }
    CanvasTextData? textData = layer.text;
    Rect? textBounds;
    if (textData != null) {
      textData = _alignTextDataToBitmap(
        textData,
        bitmapLeft: layer.bitmapLeft,
        bitmapTop: layer.bitmapTop,
      );
      textBounds = controller._textRenderer.layout(textData).bounds;
    }
    controller._layers.add(
      BitmapLayerState(
        id: layer.id,
        name: layer.name,
        visible: layer.visible,
        opacity: layer.opacity,
        locked: layer.locked,
        clippingMask: layer.clippingMask,
        blendMode: layer.blendMode,
        surface: surface,
        text: textData,
        textBounds: textBounds,
      ),
    );
    controller._layerOverflowStores[layer.id] = overflowStore;
    if (layer == layers.first && layer.fillColor != null) {
      controller._backgroundColor = layer.fillColor!;
    }
  }
  controller._activeIndex = controller._layers.length - 1;
}

_LayerOverflowStore _applyBitmapToSurface(
  BitmapCanvasController controller,
  LayerSurface surface,
  CanvasLayerData data,
) {
  return surface.withBitmapSurface(
    writeBack: true,
    action: (BitmapSurface bitmapSurface) {
      final Uint32List? rawPixels = data.rawPixels;
      if (rawPixels != null) {
        final int canvasWidth = controller._width;
        final int canvasHeight = controller._height;
        final int srcWidth = data.bitmapWidth ?? canvasWidth;
        final int srcHeight = data.bitmapHeight ?? canvasHeight;
        final int offsetX = data.bitmapLeft ?? 0;
        final int offsetY = data.bitmapTop ?? 0;
        if (offsetX == 0 &&
            offsetY == 0 &&
            srcWidth == canvasWidth &&
            srcHeight == canvasHeight &&
            rawPixels.length == canvasWidth * canvasHeight) {
          bitmapSurface.pixels.setAll(0, rawPixels);
          bitmapSurface.markDirty();
          return _LayerOverflowStore();
        }

        final _LayerOverflowBuilder builder = _LayerOverflowBuilder();
        for (int y = 0; y < srcHeight; y++) {
          final int canvasY = offsetY + y;
          final bool insideY = canvasY >= 0 && canvasY < canvasHeight;
          final int rowOffset = y * srcWidth;
          if (rowOffset >= rawPixels.length) {
            break;
          }
          final int rowEnd = rowOffset + srcWidth;
          final int safeRowEnd = math.min(rowEnd, rawPixels.length);
          for (int x = 0; x < safeRowEnd - rowOffset; x++) {
            final int canvasX = offsetX + x;
            final int color = rawPixels[rowOffset + x];
            if ((color >> 24) == 0) {
              continue;
            }
            if (insideY && canvasX >= 0 && canvasX < canvasWidth) {
              final int destIndex = canvasY * canvasWidth + canvasX;
              bitmapSurface.pixels[destIndex] = color;
            } else {
              builder.addPixel(canvasX, canvasY, color);
            }
          }
        }
        bitmapSurface.markDirty();
        return builder.build();
      }

      final Uint8List bitmap = data.bitmap!;
      final int srcWidth = data.bitmapWidth ?? controller._width;
      final int srcHeight = data.bitmapHeight ?? controller._height;
      final int offsetX = data.bitmapLeft ?? 0;
      final int offsetY = data.bitmapTop ?? 0;
      final _LayerOverflowBuilder builder = _LayerOverflowBuilder();
      final int canvasWidth = controller._width;
      final int canvasHeight = controller._height;
      for (int y = 0; y < srcHeight; y++) {
        final int canvasY = offsetY + y;
        final bool insideY = canvasY >= 0 && canvasY < canvasHeight;
        final int rowOffset = y * srcWidth;
        for (int x = 0; x < srcWidth; x++) {
          final int canvasX = offsetX + x;
          final int rgbaIndex = (rowOffset + x) * 4;
          final int alpha = bitmap[rgbaIndex + 3];
          if (alpha == 0) {
            continue;
          }
          final int color =
              (alpha << 24) |
              (bitmap[rgbaIndex] << 16) |
              (bitmap[rgbaIndex + 1] << 8) |
              bitmap[rgbaIndex + 2];
          if (insideY && canvasX >= 0 && canvasX < canvasWidth) {
            final int destIndex = canvasY * canvasWidth + canvasX;
            bitmapSurface.pixels[destIndex] = color;
          } else {
            builder.addPixel(canvasX, canvasY, color);
          }
        }
      }
      bitmapSurface.markDirty();
      return builder.build();
    },
  );
}
