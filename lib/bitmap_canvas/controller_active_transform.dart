part of 'controller.dart';

void _translateActiveLayer(BitmapCanvasController controller, int dx, int dy) {
  if (controller._pendingActiveLayerTransformCleanup) {
    return;
  }
  final BitmapLayerState layer = controller._activeLayer;
  if (layer.locked || controller._selectionMask != null) {
    return;
  }
  if (controller._activeLayerTranslationSnapshot == null) {
    _startActiveLayerTransformSession(controller, layer);
  }
  if (controller._activeLayerTranslationSnapshot == null) {
    return;
  }
  if (dx == controller._activeLayerTranslationDx &&
      dy == controller._activeLayerTranslationDy) {
    return;
  }
  controller._activeLayerTranslationDx = dx;
  controller._activeLayerTranslationDy = dy;
  _updateActiveLayerTransformDirtyRegion(controller);
  controller._notify();
}

void _commitActiveLayerTranslation(BitmapCanvasController controller) {
  if (controller._activeLayerTranslationSnapshot == null ||
      controller._pendingActiveLayerTransformCleanup) {
    return;
  }
  final Rect? dirtyRegion = controller._activeLayerTransformDirtyRegion;
  final String? layerId = controller._activeLayerTranslationId;
  _applyActiveLayerTranslation(controller);
  if (!controller._rasterOutputEnabled) {
    // No composite pass will run, so cleanup immediately.
    if (dirtyRegion != null) {
      controller._markDirty(
        region: dirtyRegion,
        layerId: layerId,
        pixelsDirty: true,
      );
    } else {
      controller._markDirty(layerId: layerId, pixelsDirty: true);
    }
    controller._pendingActiveLayerTransformCleanup = false;
    _resetActiveLayerTranslationState(controller);
    controller._notify();
    return;
  }
  controller._pendingActiveLayerTransformCleanup = true;
  if (dirtyRegion != null) {
    controller._markDirty(
      region: dirtyRegion,
      layerId: layerId,
      pixelsDirty: true,
    );
  } else {
    controller._markDirty(layerId: layerId, pixelsDirty: true);
  }
}

void _cancelActiveLayerTranslation(BitmapCanvasController controller) {
  if (controller._activeLayerTranslationSnapshot == null) {
    return;
  }
  final Rect? dirtyRegion = controller._activeLayerTransformDirtyRegion;
  final String? layerId = controller._activeLayerTranslationId;
  _restoreActiveLayerSnapshot(controller);
  if (!controller._rasterOutputEnabled) {
    if (dirtyRegion != null) {
      controller._markDirty(
        region: dirtyRegion,
        layerId: layerId,
        pixelsDirty: true,
      );
    } else {
      controller._markDirty(layerId: layerId, pixelsDirty: true);
    }
    controller._pendingActiveLayerTransformCleanup = false;
    controller._notify();
    return;
  }
  controller._pendingActiveLayerTransformCleanup = true;
  if (dirtyRegion != null) {
    controller._markDirty(
      region: dirtyRegion,
      layerId: layerId,
      pixelsDirty: true,
    );
  } else {
    controller._markDirty(layerId: layerId, pixelsDirty: true);
  }
}

void _startActiveLayerTransformSession(
  BitmapCanvasController controller,
  BitmapLayerState layer,
) {
  if (controller._pendingActiveLayerTransformCleanup) {
    return;
  }
  if (controller._clipLayerOverflow) {
    _startClippedLayerTransformSession(controller, layer);
    return;
  }
  _startOverflowLayerTransformSession(controller, layer);
}

void _startClippedLayerTransformSession(
  BitmapCanvasController controller,
  BitmapLayerState layer,
) {
  final Uint32List sourcePixels = layer.surface.pixels;
  final int canvasWidth = layer.surface.width;
  final int canvasHeight = layer.surface.height;
  final Rect? pixelBounds = _computePixelBounds(
    sourcePixels,
    canvasWidth,
    canvasHeight,
    pixelsPtr: layer.surface.pointerAddress,
  );
  int originX = 0;
  int originY = 0;
  int snapshotWidth = 1;
  int snapshotHeight = 1;
  Uint32List snapshotPixels = Uint32List(1);
  if (pixelBounds != null && !pixelBounds.isEmpty) {
    originX = pixelBounds.left.toInt();
    originY = pixelBounds.top.toInt();
    snapshotWidth = pixelBounds.width.toInt();
    snapshotHeight = pixelBounds.height.toInt();
    snapshotPixels = Uint32List(snapshotWidth * snapshotHeight);
    for (int sy = 0; sy < snapshotHeight; sy++) {
      final int srcOffset = (originY + sy) * canvasWidth + originX;
      final int destOffset = sy * snapshotWidth;
      snapshotPixels.setRange(
        destOffset,
        destOffset + snapshotWidth,
        sourcePixels,
        srcOffset,
      );
    }
  }
  controller._activeLayerTranslationSnapshot = snapshotPixels;
  controller._activeLayerTranslationId = layer.id;
  controller._activeLayerTranslationDx = 0;
  controller._activeLayerTranslationDy = 0;
  controller._activeLayerTransformSnapshotWidth = snapshotWidth;
  controller._activeLayerTransformSnapshotHeight = snapshotHeight;
  controller._activeLayerTransformOriginX = originX;
  controller._activeLayerTransformOriginY = originY;
  controller._activeLayerTransformBounds =
      pixelBounds ??
      Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble());
  controller._activeLayerTransformDirtyRegion = pixelBounds;
  _prepareActiveLayerTransformPreview(controller, layer, snapshotPixels);
}

void _startOverflowLayerTransformSession(
  BitmapCanvasController controller,
  BitmapLayerState layer,
) {
  final _LayerOverflowStore overflowStore =
      controller._layerOverflowStores[layer.id] ?? _LayerOverflowStore();
  final Rect? canvasBounds = _computePixelBounds(
    layer.surface.pixels,
    controller._width,
    controller._height,
    pixelsPtr: layer.surface.pointerAddress,
  );
  int minX = 0;
  int minY = 0;
  int maxX = 0;
  int maxY = 0;
  bool hasBounds = false;
  if (canvasBounds != null && !canvasBounds.isEmpty) {
    minX = canvasBounds.left.toInt();
    minY = canvasBounds.top.toInt();
    maxX = canvasBounds.right.toInt();
    maxY = canvasBounds.bottom.toInt();
    hasBounds = true;
  }
  if (!overflowStore.isEmpty) {
    if (!hasBounds) {
      minX = overflowStore.minX;
      minY = overflowStore.minY;
      maxX = overflowStore.maxX;
      maxY = overflowStore.maxY;
      hasBounds = true;
    } else {
      minX = math.min(minX, overflowStore.minX);
      minY = math.min(minY, overflowStore.minY);
      maxX = math.max(maxX, overflowStore.maxX);
      maxY = math.max(maxY, overflowStore.maxY);
    }
  }
  if (!hasBounds) {
    minX = 0;
    minY = 0;
    maxX = 1;
    maxY = 1;
  }
  final _LayerTransformSnapshot snapshot = _buildOverflowTransformSnapshot(
    controller,
    layer,
    overflowStore,
    minX: minX,
    minY: minY,
    maxX: maxX,
    maxY: maxY,
  );
  controller._activeLayerTranslationSnapshot = snapshot.pixels;
  controller._activeLayerTranslationId = layer.id;
  controller._activeLayerTranslationDx = 0;
  controller._activeLayerTranslationDy = 0;
  controller._activeLayerTransformSnapshotWidth = snapshot.width;
  controller._activeLayerTransformSnapshotHeight = snapshot.height;
  controller._activeLayerTransformOriginX = snapshot.originX;
  controller._activeLayerTransformOriginY = snapshot.originY;
  final Rect transformBounds = Rect.fromLTRB(
    minX.toDouble(),
    minY.toDouble(),
    maxX.toDouble(),
    maxY.toDouble(),
  );
  controller._activeLayerTransformBounds = transformBounds;
  controller._activeLayerTransformDirtyRegion = transformBounds;
  _prepareActiveLayerTransformPreview(controller, layer, snapshot.pixels);
}

Rect? _computePixelBounds(
  Uint32List pixels,
  int width,
  int height, {
  int? pixelsPtr,
}) {
  if (pixelsPtr != null &&
      pixelsPtr != 0 &&
      CpuImageFfi.instance.isSupported) {
    final Int32List? bounds = CpuImageFfi.instance.computeBounds(
      pixelsPtr: pixelsPtr,
      pixelsLen: pixels.length,
      width: width,
      height: height,
    );
    if (bounds != null && bounds.length >= 4) {
      return Rect.fromLTRB(
        bounds[0].toDouble(),
        bounds[1].toDouble(),
        bounds[2].toDouble(),
        bounds[3].toDouble(),
      );
    }
  }
  int minX = width;
  int minY = height;
  int maxX = -1;
  int maxY = -1;
  for (int y = 0; y < height; y++) {
    final int rowOffset = y * width;
    for (int x = 0; x < width; x++) {
      final int argb = pixels[rowOffset + x];
      if ((argb >> 24) == 0) {
        continue;
      }
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

void _prepareActiveLayerTransformPreview(
  BitmapCanvasController controller,
  BitmapLayerState layer,
  Uint32List snapshot,
) {
  if (controller._activeLayerTransformPreparing) {
    return;
  }
  final int snapshotWidth = controller._activeLayerTransformSnapshotWidth;
  final int snapshotHeight = controller._activeLayerTransformSnapshotHeight;
  if (snapshotWidth <= 0 || snapshotHeight <= 0) {
    return;
  }
  controller._activeLayerTransformPreparing = true;
  Uint8List bytes;
  ui.PixelFormat format = ui.PixelFormat.rgba8888;
  if (!kIsWeb && Endian.host == Endian.little) {
    final Uint8List view = Uint8List.view(
      snapshot.buffer,
      snapshot.offsetInBytes,
      snapshot.lengthInBytes,
    );
    bytes = Uint8List.fromList(view);
    premultiplyBgraInPlace(bytes);
    format = ui.PixelFormat.bgra8888;
  } else {
    bytes = BitmapCanvasController._pixelsToRgba(snapshot);
    premultiplyRgbaInPlace(bytes);
  }
  _disposeActiveLayerTransformImage(controller);
  ui.decodeImageFromPixels(
    bytes,
    snapshotWidth,
    snapshotHeight,
    format,
    (ui.Image image) {
      if (controller._activeLayerTranslationSnapshot == null ||
          controller._activeLayerTranslationId != layer.id) {
        controller._activeLayerTransformPreparing = false;
        image.dispose();
        return;
      }
      controller._activeLayerTransformImage?.dispose();
      controller._activeLayerTransformImage = image;
      controller._activeLayerTransformPreparing = false;
      final Rect? dirtyRegion = controller._activeLayerTransformDirtyRegion ??
          controller._activeLayerTransformBounds;
      if (dirtyRegion != null) {
        controller._markDirty(region: dirtyRegion, pixelsDirty: false);
      } else {
        controller._markDirty(pixelsDirty: false);
      }
    },
  );
}

void _applyActiveLayerTranslation(BitmapCanvasController controller) {
  final Uint32List? snapshot = controller._activeLayerTranslationSnapshot;
  final String? id = controller._activeLayerTranslationId;
  if (snapshot == null || id == null) {
    return;
  }
  if (controller._clipLayerOverflow) {
    _applyClippedLayerTranslation(controller, snapshot, id);
  } else {
    _applyOverflowLayerTranslation(controller, snapshot, id);
  }
}

void _applyClippedLayerTranslation(
  BitmapCanvasController controller,
  Uint32List snapshot,
  String layerId,
) {
  final BitmapLayerState target = controller._layers.firstWhere(
    (layer) => layer.id == layerId,
    orElse: () => controller._activeLayer,
  );
  final Uint32List pixels = target.surface.pixels;
  final int canvasWidth = controller._width;
  final int canvasHeight = controller._height;
  final int snapshotWidth = controller._activeLayerTransformSnapshotWidth;
  final int snapshotHeight = controller._activeLayerTransformSnapshotHeight;
  final int originX = controller._activeLayerTransformOriginX;
  final int originY = controller._activeLayerTransformOriginY;
  final int dx = controller._activeLayerTranslationDx;
  final int dy = controller._activeLayerTranslationDy;
  pixels.fillRange(0, pixels.length, 0);
  for (int sy = 0; sy < snapshotHeight; sy++) {
    final int canvasY = originY + sy + dy;
    if (canvasY < 0 || canvasY >= canvasHeight) {
      continue;
    }
    final int rowOffset = sy * snapshotWidth;
    final int destRowOffset = canvasY * canvasWidth;
    for (int sx = 0; sx < snapshotWidth; sx++) {
      final int color = snapshot[rowOffset + sx];
      if ((color >> 24) == 0) {
        continue;
      }
      final int canvasX = originX + sx + dx;
      if (canvasX < 0 || canvasX >= canvasWidth) {
        continue;
      }
      pixels[destRowOffset + canvasX] = color;
    }
  }
  controller._layerOverflowStores[layerId]?.clear();
  _textLayerApplyTranslation(target, dx, dy);
}

void _applyOverflowLayerTranslation(
  BitmapCanvasController controller,
  Uint32List snapshot,
  String layerId,
) {
  final BitmapLayerState target = controller._layers.firstWhere(
    (layer) => layer.id == layerId,
    orElse: () => controller._activeLayer,
  );
  final int snapshotWidth = controller._activeLayerTransformSnapshotWidth;
  final int snapshotHeight = controller._activeLayerTransformSnapshotHeight;
  if (snapshotWidth <= 0 || snapshotHeight <= 0) {
    _resetActiveLayerTranslationState(controller);
    return;
  }
  final int originX = controller._activeLayerTransformOriginX;
  final int originY = controller._activeLayerTransformOriginY;
  final int dx = controller._activeLayerTranslationDx;
  final int dy = controller._activeLayerTranslationDy;
  final int canvasWidth = controller._width;
  final int canvasHeight = controller._height;
  final Uint32List pixels = target.surface.pixels;
  pixels.fillRange(0, pixels.length, 0);
  final _LayerOverflowBuilder overflowBuilder = _LayerOverflowBuilder();
  for (int sy = 0; sy < snapshotHeight; sy++) {
    final int canvasY = originY + sy + dy;
    final bool insideY = canvasY >= 0 && canvasY < canvasHeight;
    final int rowOffset = sy * snapshotWidth;
    for (int sx = 0; sx < snapshotWidth; sx++) {
      final int color = snapshot[rowOffset + sx];
      if ((color >> 24) == 0) {
        continue;
      }
      final int canvasX = originX + sx + dx;
      if (insideY && canvasX >= 0 && canvasX < canvasWidth) {
        final int destIndex = canvasY * canvasWidth + canvasX;
        pixels[destIndex] = color;
      } else {
        overflowBuilder.addPixel(canvasX, canvasY, color);
      }
    }
  }
  final _LayerOverflowStore overflowStore = overflowBuilder.build();
  if (!overflowStore.isEmpty) {
    controller._layerOverflowStores[layerId] = overflowStore;
  } else if (controller._layerOverflowStores.containsKey(layerId)) {
    controller._layerOverflowStores[layerId]!.clear();
  }
  _textLayerApplyTranslation(target, dx, dy);
}

void _restoreOverflowLayerSnapshot(
  BitmapCanvasController controller,
  Uint32List snapshot,
  String layerId,
) {
  final BitmapLayerState target = controller._layers.firstWhere(
    (layer) => layer.id == layerId,
    orElse: () => controller._activeLayer,
  );
  final int snapshotWidth = controller._activeLayerTransformSnapshotWidth;
  final int snapshotHeight = controller._activeLayerTransformSnapshotHeight;
  if (snapshotWidth <= 0 || snapshotHeight <= 0) {
    _resetActiveLayerTranslationState(controller);
    return;
  }
  final int originX = controller._activeLayerTransformOriginX;
  final int originY = controller._activeLayerTransformOriginY;
  final int canvasWidth = controller._width;
  final int canvasHeight = controller._height;
  final Uint32List pixels = target.surface.pixels;
  pixels.fillRange(0, pixels.length, 0);
  for (int sy = 0; sy < snapshotHeight; sy++) {
    final int canvasY = originY + sy;
    if (canvasY < 0 || canvasY >= canvasHeight) {
      continue;
    }
    final int rowOffset = sy * snapshotWidth;
    for (int sx = 0; sx < snapshotWidth; sx++) {
      final int canvasX = originX + sx;
      if (canvasX < 0 || canvasX >= canvasWidth) {
        continue;
      }
      final int color = snapshot[rowOffset + sx];
      if ((color >> 24) == 0) {
        continue;
      }
      final int destIndex = canvasY * canvasWidth + canvasX;
      pixels[destIndex] = color;
    }
  }
  _resetActiveLayerTranslationState(controller);
}

void _restoreClippedLayerSnapshot(
  BitmapCanvasController controller,
  Uint32List snapshot,
  String layerId,
) {
  final BitmapLayerState target = controller._layers.firstWhere(
    (layer) => layer.id == layerId,
    orElse: () => controller._activeLayer,
  );
  final int snapshotWidth = controller._activeLayerTransformSnapshotWidth;
  final int snapshotHeight = controller._activeLayerTransformSnapshotHeight;
  if (snapshotWidth <= 0 || snapshotHeight <= 0) {
    _resetActiveLayerTranslationState(controller);
    return;
  }
  final int originX = controller._activeLayerTransformOriginX;
  final int originY = controller._activeLayerTransformOriginY;
  final int canvasWidth = controller._width;
  final int canvasHeight = controller._height;
  final Uint32List pixels = target.surface.pixels;
  pixels.fillRange(0, pixels.length, 0);
  for (int sy = 0; sy < snapshotHeight; sy++) {
    final int canvasY = originY + sy;
    if (canvasY < 0 || canvasY >= canvasHeight) {
      continue;
    }
    final int rowOffset = sy * snapshotWidth;
    final int destRowOffset = canvasY * canvasWidth;
    for (int sx = 0; sx < snapshotWidth; sx++) {
      final int canvasX = originX + sx;
      if (canvasX < 0 || canvasX >= canvasWidth) {
        continue;
      }
      final int color = snapshot[rowOffset + sx];
      if ((color >> 24) == 0) {
        continue;
      }
      pixels[destRowOffset + canvasX] = color;
    }
  }
  _resetActiveLayerTranslationState(controller);
}

_LayerTransformSnapshot _buildOverflowTransformSnapshot(
  BitmapCanvasController controller,
  BitmapLayerState layer,
  _LayerOverflowStore store, {
  int? minX,
  int? minY,
  int? maxX,
  int? maxY,
}) {
  int resolvedMinX;
  int resolvedMinY;
  int resolvedMaxX;
  int resolvedMaxY;
  if (minX == null && minY == null && maxX == null && maxY == null) {
    resolvedMinX = 0;
    resolvedMinY = 0;
    resolvedMaxX = controller._width;
    resolvedMaxY = controller._height;
    if (!store.isEmpty) {
      resolvedMinX = math.min(resolvedMinX, store.minX);
      resolvedMinY = math.min(resolvedMinY, store.minY);
      resolvedMaxX = math.max(resolvedMaxX, store.maxX);
      resolvedMaxY = math.max(resolvedMaxY, store.maxY);
    }
  } else {
    resolvedMinX = minX ?? 0;
    resolvedMinY = minY ?? 0;
    resolvedMaxX = maxX ?? controller._width;
    resolvedMaxY = maxY ?? controller._height;
  }
  final int snapshotWidth = math.max(1, resolvedMaxX - resolvedMinX);
  final int snapshotHeight = math.max(1, resolvedMaxY - resolvedMinY);
  final Uint32List pixels = Uint32List(snapshotWidth * snapshotHeight);
  final int overlapLeft = math.max(0, resolvedMinX);
  final int overlapRight = math.min(controller._width, resolvedMaxX);
  final int overlapTop = math.max(0, resolvedMinY);
  final int overlapBottom = math.min(controller._height, resolvedMaxY);
  final Uint32List srcPixels = layer.surface.pixels;
  for (int y = overlapTop; y < overlapBottom; y++) {
    final int sy = y - resolvedMinY;
    final int destinationOffset = sy * snapshotWidth;
    final int startX = overlapLeft - resolvedMinX;
    final int srcOffset = y * controller._width + overlapLeft;
    final int length = overlapRight - overlapLeft;
    pixels.setRange(
      destinationOffset + startX,
      destinationOffset + startX + length,
      srcPixels,
      srcOffset,
    );
  }
  store.forEachSegment((int rowY, _LayerOverflowSegment segment) {
    final int sy = rowY - resolvedMinY;
    if (sy < 0 || sy >= snapshotHeight) {
      return;
    }
    final int rowOffset = sy * snapshotWidth;
    final int segmentStart = segment.startX - resolvedMinX;
    final int segmentEnd = segmentStart + segment.length;
    if (segmentEnd <= 0 || segmentStart >= snapshotWidth) {
      return;
    }
    final int copyStart = math.max(0, segmentStart);
    final int skip = copyStart - segmentStart;
    final int copyEnd = math.min(snapshotWidth, segmentEnd);
    final int copyLength = copyEnd - copyStart;
    if (copyLength <= 0) {
      return;
    }
    pixels.setRange(
      rowOffset + copyStart,
      rowOffset + copyStart + copyLength,
      segment.pixels,
      skip,
    );
  });
  return _LayerTransformSnapshot(
    pixels: pixels,
    width: snapshotWidth,
    height: snapshotHeight,
    originX: resolvedMinX,
    originY: resolvedMinY,
  );
}

class _LayerTransformSnapshot {
  const _LayerTransformSnapshot({
    required this.pixels,
    required this.width,
    required this.height,
    required this.originX,
    required this.originY,
  });

  final Uint32List pixels;
  final int width;
  final int height;
  final int originX;
  final int originY;
}

class _LayerOverflowSegment {
  _LayerOverflowSegment(this.startX, this.pixels);

  final int startX;
  final Uint32List pixels;

  int get length => pixels.length;
}

class _LayerOverflowStore {
  final SplayTreeMap<int, List<_LayerOverflowSegment>> _rows =
      SplayTreeMap<int, List<_LayerOverflowSegment>>();
  bool _hasBounds = false;
  int minX = 0;
  int maxX = 0;
  int minY = 0;
  int maxY = 0;

  bool get isEmpty => _rows.isEmpty;

  void addRow(int y, List<_LayerOverflowSegment> segments) {
    if (segments.isEmpty) {
      _rows.remove(y);
      return;
    }
    _rows[y] = segments;
    if (!_hasBounds) {
      minX = segments.first.startX;
      maxX = segments.first.startX + segments.first.length;
      minY = y;
      maxY = y + 1;
      _hasBounds = true;
    } else {
      minY = math.min(minY, y);
      maxY = math.max(maxY, y + 1);
    }
    for (final _LayerOverflowSegment segment in segments) {
      if (!_hasBounds) {
        minX = segment.startX;
        maxX = segment.startX + segment.length;
        _hasBounds = true;
      } else {
        minX = math.min(minX, segment.startX);
        maxX = math.max(maxX, segment.startX + segment.length);
      }
    }
  }

  void clear() {
    _rows.clear();
    _hasBounds = false;
    minX = 0;
    maxX = 0;
    minY = 0;
    maxY = 0;
  }

  void forEachSegment(
    void Function(int rowY, _LayerOverflowSegment segment) visitor,
  ) {
    _rows.forEach((int y, List<_LayerOverflowSegment> segments) {
      for (final _LayerOverflowSegment segment in segments) {
        visitor(y, segment);
      }
    });
  }
}

class _LayerOverflowBuilder {
  final Map<int, _OverflowRowBuilder> _rows = <int, _OverflowRowBuilder>{};

  void addPixel(int x, int y, int color) {
    if ((color >> 24) == 0) {
      return;
    }
    final _OverflowRowBuilder builder = _rows.putIfAbsent(
      y,
      () => _OverflowRowBuilder(),
    );
    builder.addPixel(x, color);
  }

  _LayerOverflowStore build() {
    if (_rows.isEmpty) {
      return _LayerOverflowStore();
    }
    final _LayerOverflowStore store = _LayerOverflowStore();
    final List<int> rowKeys = _rows.keys.toList()..sort();
    for (final int y in rowKeys) {
      final _OverflowRowBuilder builder = _rows[y]!;
      final List<_LayerOverflowSegment> segments = builder.build();
      if (segments.isEmpty) {
        continue;
      }
      store.addRow(y, segments);
    }
    return store;
  }
}

class _OverflowRowBuilder {
  final List<_LayerOverflowSegment> _segments = <_LayerOverflowSegment>[];
  int? _currentStart;
  final List<int> _buffer = <int>[];

  void addPixel(int x, int color) {
    if (_currentStart == null) {
      _currentStart = x;
      _buffer.add(color);
      return;
    }
    final int expected = _currentStart! + _buffer.length;
    if (x == expected) {
      _buffer.add(color);
      return;
    }
    _flush();
    _currentStart = x;
    _buffer.add(color);
  }

  List<_LayerOverflowSegment> build() {
    _flush();
    return _segments;
  }

  void _flush() {
    if (_currentStart == null || _buffer.isEmpty) {
      _buffer.clear();
      _currentStart = null;
      return;
    }
    _segments.add(
      _LayerOverflowSegment(_currentStart!, Uint32List.fromList(_buffer)),
    );
    _buffer.clear();
    _currentStart = null;
  }
}

void _restoreActiveLayerSnapshot(BitmapCanvasController controller) {
  final Uint32List? snapshot = controller._activeLayerTranslationSnapshot;
  final String? id = controller._activeLayerTranslationId;
  if (snapshot == null || id == null) {
    return;
  }
  if (controller._clipLayerOverflow) {
    _restoreClippedLayerSnapshot(controller, snapshot, id);
    return;
  }
  _restoreOverflowLayerSnapshot(controller, snapshot, id);
}

void _disposeActiveLayerTransformSession(BitmapCanvasController controller) {
  if (controller._activeLayerTranslationSnapshot == null) {
    return;
  }
  if (!controller._rasterOutputEnabled) {
    final String? layerId = controller._activeLayerTranslationId;
    _resetActiveLayerTranslationState(controller);
    if (layerId != null) {
      controller._markDirty(layerId: layerId, pixelsDirty: true);
    } else {
      controller._markDirty(pixelsDirty: true);
    }
    controller._pendingActiveLayerTransformCleanup = false;
    controller._notify();
    return;
  }
  controller._pendingActiveLayerTransformCleanup = true;
  controller._markDirty(
    layerId: controller._activeLayerTranslationId,
    pixelsDirty: true,
  );
}

void _updateActiveLayerTransformDirtyRegion(BitmapCanvasController controller) {
  final Rect? baseBounds = controller._activeLayerTransformBounds;
  if (baseBounds == null) {
    return;
  }
  final Rect current = baseBounds.shift(
    Offset(
      controller._activeLayerTranslationDx.toDouble(),
      controller._activeLayerTranslationDy.toDouble(),
    ),
  );
  final Rect? existing = controller._activeLayerTransformDirtyRegion;
  if (existing == null) {
    controller._activeLayerTransformDirtyRegion = current;
  } else {
    controller._activeLayerTransformDirtyRegion =
        BitmapCanvasController._unionRects(existing, current);
  }
}

void _resetActiveLayerTranslationState(BitmapCanvasController controller) {
  controller._activeLayerTranslationSnapshot = null;
  controller._activeLayerTranslationId = null;
  controller._activeLayerTranslationDx = 0;
  controller._activeLayerTranslationDy = 0;
  controller._activeLayerTransformSnapshotWidth = 0;
  controller._activeLayerTransformSnapshotHeight = 0;
  controller._activeLayerTransformOriginX = 0;
  controller._activeLayerTransformOriginY = 0;
  controller._activeLayerTransformPreparing = false;
  controller._activeLayerTransformBounds = null;
  controller._activeLayerTransformDirtyRegion = null;
  _disposeActiveLayerTransformImage(controller);
}

void _disposeActiveLayerTransformImage(BitmapCanvasController controller) {
  controller._activeLayerTransformImage?.dispose();
  controller._activeLayerTransformImage = null;
}
