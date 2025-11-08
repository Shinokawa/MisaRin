part of 'controller.dart';

void _translateActiveLayer(
  BitmapCanvasController controller,
  int dx,
  int dy,
) {
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
  controller.notifyListeners();
}

void _commitActiveLayerTranslation(BitmapCanvasController controller) {
  if (controller._activeLayerTranslationSnapshot == null) {
    return;
  }
  final Rect? dirtyRegion = controller._activeLayerTransformDirtyRegion;
  _applyActiveLayerTranslation(controller);
  controller._pendingActiveLayerTransformCleanup = true;
  if (dirtyRegion != null) {
    controller._markDirty(region: dirtyRegion);
  } else {
    controller._markDirty();
  }
}

void _cancelActiveLayerTranslation(BitmapCanvasController controller) {
  if (controller._activeLayerTranslationSnapshot == null) {
    return;
  }
  final Rect? dirtyRegion = controller._activeLayerTransformDirtyRegion;
  _restoreActiveLayerSnapshot(controller);
  controller._pendingActiveLayerTransformCleanup = true;
  if (dirtyRegion != null) {
    controller._markDirty(region: dirtyRegion);
  } else {
    controller._markDirty();
  }
}

Uint32List _ensureTranslationSnapshot(
  BitmapCanvasController controller,
  String layerId,
  Uint32List pixels,
) {
  final Uint32List? existing = controller._activeLayerTranslationSnapshot;
  if (existing != null && controller._activeLayerTranslationId == layerId) {
    return existing;
  }
  final Uint32List snapshot = Uint32List.fromList(pixels);
  controller._activeLayerTranslationSnapshot = snapshot;
  controller._activeLayerTranslationId = layerId;
  controller._activeLayerTranslationDx = 0;
  controller._activeLayerTranslationDy = 0;
  return snapshot;
}

void _startActiveLayerTransformSession(
  BitmapCanvasController controller,
  BitmapLayerState layer,
) {
  if (controller._pendingActiveLayerTransformCleanup) {
    return;
  }
  final Uint32List snapshot = _ensureTranslationSnapshot(
    controller,
    layer.id,
    layer.surface.pixels,
  );
  final int width = layer.surface.width;
  final int height = layer.surface.height;
  final Rect? bounds = _computePixelBounds(snapshot, width, height);
  controller._activeLayerTransformBounds = bounds;
  controller._activeLayerTransformDirtyRegion = bounds;
  layer.surface.pixels.fillRange(0, layer.surface.pixels.length, 0);
  if (bounds != null) {
    controller._markDirty(region: bounds);
  } else {
    controller._markDirty();
  }
  _prepareActiveLayerTransformPreview(controller, layer, snapshot);
}

Rect? _computePixelBounds(Uint32List pixels, int width, int height) {
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
  controller._activeLayerTransformPreparing = true;
  final Uint8List rgba = BitmapCanvasController._pixelsToRgba(snapshot);
  controller._activeLayerTransformImage?.dispose();
  ui.decodeImageFromPixels(
    rgba,
    layer.surface.width,
    layer.surface.height,
    ui.PixelFormat.rgba8888,
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
      controller.notifyListeners();
    },
  );
}

void _applyActiveLayerTranslation(BitmapCanvasController controller) {
  final Uint32List? snapshot = controller._activeLayerTranslationSnapshot;
  final String? id = controller._activeLayerTranslationId;
  if (snapshot == null || id == null) {
    return;
  }
  final BitmapLayerState target = controller._layers.firstWhere(
    (layer) => layer.id == id,
    orElse: () => controller._activeLayer,
  );
  final Uint32List pixels = target.surface.pixels;
  final int width = target.surface.width;
  final int height = target.surface.height;
  final int dx = controller._activeLayerTranslationDx;
  final int dy = controller._activeLayerTranslationDy;
  pixels.fillRange(0, pixels.length, 0);
  for (int y = 0; y < height; y++) {
    final int srcY = y - dy;
    if (srcY < 0 || srcY >= height) {
      continue;
    }
    for (int x = 0; x < width; x++) {
      final int srcX = x - dx;
      if (srcX < 0 || srcX >= width) {
        continue;
      }
      final int srcIndex = srcY * width + srcX;
      final int destIndex = y * width + x;
      pixels[destIndex] = snapshot[srcIndex];
    }
  }
  _resetActiveLayerTranslationState(controller);
}

void _restoreActiveLayerSnapshot(BitmapCanvasController controller) {
  final Uint32List? snapshot = controller._activeLayerTranslationSnapshot;
  final String? id = controller._activeLayerTranslationId;
  if (snapshot == null || id == null) {
    return;
  }
  final BitmapLayerState target = controller._layers.firstWhere(
    (layer) => layer.id == id,
    orElse: () => controller._activeLayer,
  );
  target.surface.pixels.setAll(0, snapshot);
  _resetActiveLayerTranslationState(controller);
}

void _updateActiveLayerTransformDirtyRegion(
  BitmapCanvasController controller,
) {
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
    controller._activeLayerTransformDirtyRegion = BitmapCanvasController
        ._unionRects(existing, current);
  }
}

void _resetActiveLayerTranslationState(BitmapCanvasController controller) {
  controller._activeLayerTranslationSnapshot = null;
  controller._activeLayerTranslationId = null;
  controller._activeLayerTranslationDx = 0;
  controller._activeLayerTranslationDy = 0;
  controller._activeLayerTransformPreparing = false;
  controller._activeLayerTransformBounds = null;
  controller._activeLayerTransformDirtyRegion = null;
  _disposeActiveLayerTransformImage(controller);
}

void _disposeActiveLayerTransformImage(BitmapCanvasController controller) {
  controller._activeLayerTransformImage?.dispose();
  controller._activeLayerTransformImage = null;
}
