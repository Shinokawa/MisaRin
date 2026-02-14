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
    surface: BitmapSurface(
      width: controller._width,
      height: controller._height,
    ),
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
      maskLen = clippingInfo.layer.surface.pixels.length;
      maskOpacity = clippingInfo.opacity;
    }
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
  _ClippingMaskInfo? clippingInfo,
) {
  if (upperOverflow.isEmpty) {
    return;
  }
  final int canvasPtr = lower.surface.pointerAddress;
  final int maskPtr =
      clippingInfo == null ? 0 : clippingInfo.layer.surface.pointerAddress;
  if (canvasPtr == 0 ||
      !RustCpuBlendFfi.instance.isSupported ||
      (clippingInfo != null && maskPtr == 0)) {
    return;
  }
  final int upperCount = _countOverflowPixels(upperOverflow);
  if (upperCount <= 0) {
    return;
  }
  Pointer<Int32>? upperX;
  Pointer<Int32>? upperY;
  Pointer<Uint32>? upperColor;
  Pointer<Int32>? lowerX;
  Pointer<Int32>? lowerY;
  Pointer<Uint32>? lowerColor;
  Pointer<Int32>? maskOverflowX;
  Pointer<Int32>? maskOverflowY;
  Pointer<Uint32>? maskOverflowColor;
  Pointer<Int32>? outX;
  Pointer<Int32>? outY;
  Pointer<Uint32>? outColor;
  Pointer<Uint64>? outCountPtr;
  try {
    upperX = malloc.allocate<Int32>(sizeOf<Int32>() * upperCount);
    upperY = malloc.allocate<Int32>(sizeOf<Int32>() * upperCount);
    upperColor = malloc.allocate<Uint32>(sizeOf<Uint32>() * upperCount);
    _fillOverflowArrays(
      upperOverflow,
      upperX.asTypedList(upperCount),
      upperY.asTypedList(upperCount),
      upperColor.asTypedList(upperCount),
    );
    final int lowerCount = _countOverflowPixels(lowerOverflow);
    if (lowerCount > 0) {
      lowerX = malloc.allocate<Int32>(sizeOf<Int32>() * lowerCount);
      lowerY = malloc.allocate<Int32>(sizeOf<Int32>() * lowerCount);
      lowerColor = malloc.allocate<Uint32>(sizeOf<Uint32>() * lowerCount);
      _fillOverflowArrays(
        lowerOverflow,
        lowerX.asTypedList(lowerCount),
        lowerY.asTypedList(lowerCount),
        lowerColor.asTypedList(lowerCount),
      );
    }
    int maskLen = 0;
    double maskOpacity = 0;
    int maskOverflowCount = 0;
    if (clippingInfo != null) {
      maskLen = clippingInfo.layer.surface.pixels.length;
      maskOpacity = clippingInfo.opacity;
      maskOverflowCount = _countOverflowPixels(clippingInfo.overflow);
      if (maskOverflowCount > 0) {
        maskOverflowX = malloc.allocate<Int32>(
          sizeOf<Int32>() * maskOverflowCount,
        );
        maskOverflowY = malloc.allocate<Int32>(
          sizeOf<Int32>() * maskOverflowCount,
        );
        maskOverflowColor = malloc.allocate<Uint32>(
          sizeOf<Uint32>() * maskOverflowCount,
        );
        _fillOverflowArrays(
          clippingInfo.overflow,
          maskOverflowX.asTypedList(maskOverflowCount),
          maskOverflowY.asTypedList(maskOverflowCount),
          maskOverflowColor.asTypedList(maskOverflowCount),
        );
      }
    }
    final int outCapacity = upperCount + lowerCount;
    outX = malloc.allocate<Int32>(sizeOf<Int32>() * outCapacity);
    outY = malloc.allocate<Int32>(sizeOf<Int32>() * outCapacity);
    outColor = malloc.allocate<Uint32>(sizeOf<Uint32>() * outCapacity);
    outCountPtr = malloc.allocate<Uint64>(sizeOf<Uint64>());
    final bool ok = RustCpuBlendFfi.instance.blendOverflow(
      canvasPtr: canvasPtr,
      canvasLen: lower.surface.pixels.length,
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
      final int count = outCountPtr.value;
      final _LayerOverflowBuilder overflowBuilder = _LayerOverflowBuilder();
      if (count > 0) {
        final Int32List xs = outX.asTypedList(count);
        final Int32List ys = outY.asTypedList(count);
        final Uint32List colors = outColor.asTypedList(count);
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
    if (upperX != null) {
      malloc.free(upperX);
    }
    if (upperY != null) {
      malloc.free(upperY);
    }
    if (upperColor != null) {
      malloc.free(upperColor);
    }
    if (lowerX != null) {
      malloc.free(lowerX);
    }
    if (lowerY != null) {
      malloc.free(lowerY);
    }
    if (lowerColor != null) {
      malloc.free(lowerColor);
    }
    if (maskOverflowX != null) {
      malloc.free(maskOverflowX);
    }
    if (maskOverflowY != null) {
      malloc.free(maskOverflowY);
    }
    if (maskOverflowColor != null) {
      malloc.free(maskOverflowColor);
    }
    if (outX != null) {
      malloc.free(outX);
    }
    if (outY != null) {
      malloc.free(outY);
    }
    if (outColor != null) {
      malloc.free(outColor);
    }
    if (outCountPtr != null) {
      malloc.free(outCountPtr);
    }
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
  final Uint32List pixels = layer.surface.pixels;
  final int replacement = index == 0
      ? BitmapSurface.encodeColor(controller._backgroundColor)
      : 0;
  if (mask == null) {
    layer.surface.fill(BitmapSurface.decodeColor(replacement));
    controller._markDirty(layerId: id, pixelsDirty: true);
    return;
  }
  if (mask.length != controller._width * controller._height) {
    throw ArgumentError('Selection mask size mismatch');
  }
  int minX = controller._width;
  int minY = controller._height;
  int maxX = -1;
  int maxY = -1;
  for (int y = 0; y < controller._height; y++) {
    final int rowOffset = y * controller._width;
    for (int x = 0; x < controller._width; x++) {
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
    layer.surface.markDirty();
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
  final BitmapSurface surface = BitmapSurface(
    width: controller._width,
    height: controller._height,
  );
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
  layer.surface.pixels.fillRange(0, layer.surface.pixels.length, 0);
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

List<CanvasLayerData> _layerManagerSnapshotLayers(
  BitmapCanvasController controller,
) {
  final List<CanvasLayerData> result = <CanvasLayerData>[];
  for (int i = 0; i < controller._layers.length; i++) {
    final BitmapLayerState layer = controller._layers[i];
    final _LayerOverflowStore overflowStore =
        controller._layerOverflowStores[layer.id] ?? _LayerOverflowStore();
    final bool hasSurface = !BitmapCanvasController._isSurfaceEmpty(
      layer.surface,
    );
    final bool hasOverflow = !overflowStore.isEmpty;
    Uint32List? rawPixels;
    int? bitmapWidth;
    int? bitmapHeight;
    int? bitmapLeft;
    int? bitmapTop;
    if (hasSurface || hasOverflow) {
      if (!hasOverflow) {
        rawPixels = Uint32List.fromList(layer.surface.pixels);
        bitmapWidth = controller._width;
        bitmapHeight = controller._height;
        bitmapLeft = 0;
        bitmapTop = 0;
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
  if (mask != null) {
    if (mask.length != controller._width * controller._height) {
      throw ArgumentError('Selection mask size mismatch');
    }
    if (!BitmapCanvasController._maskHasCoverage(mask)) {
      return null;
    }
    effectiveMask = Uint8List.fromList(mask);
  }
  Uint8List bitmap;
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
      bitmap = BitmapCanvasController._surfaceToRgba(layer.surface);
    }
  } else {
    bitmap = BitmapCanvasController._surfaceToMaskedRgba(
      layer.surface,
      effectiveMask,
    );
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
  final BitmapSurface background = BitmapSurface(
    width: controller._width,
    height: controller._height,
    fillColor: backgroundColor,
  );
  final BitmapSurface paintSurface = BitmapSurface(
    width: controller._width,
    height: controller._height,
  );
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
    final BitmapSurface surface = BitmapSurface(
      width: controller._width,
      height: controller._height,
    );
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
  BitmapSurface surface,
  CanvasLayerData data,
) {
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
      surface.pixels.setAll(0, rawPixels);
      surface.markDirty();
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
          surface.pixels[destIndex] = color;
        } else {
          builder.addPixel(canvasX, canvasY, color);
        }
      }
    }
    surface.markDirty();
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
        surface.pixels[destIndex] = color;
      } else {
        builder.addPixel(canvasX, canvasY, color);
      }
    }
  }
  surface.markDirty();
  return builder.build();
}
