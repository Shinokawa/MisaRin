part of 'controller.dart';

void _fillSetSelectionMask(
  BitmapCanvasController controller,
  Uint8List? mask,
) {
  if (mask != null && mask.length != controller._width * controller._height) {
    throw ArgumentError('Selection mask size mismatch');
  }
  controller._selectionMask = mask;
}

void _fillFloodFill(
  BitmapCanvasController controller,
  Offset position, {
  required Color color,
  bool contiguous = true,
  bool sampleAllLayers = false,
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
  Color? baseColor;
  if (sampleAllLayers) {
    _fillFloodFillAcrossLayers(controller, x, y, color, contiguous);
    return;
  } else {
    baseColor = _fillColorAtSurface(controller, controller._activeSurface, x, y);
  }
  controller._activeSurface.floodFill(
    start: Offset(x.toDouble(), y.toDouble()),
    color: color,
    targetColor: baseColor,
    contiguous: contiguous,
    mask: controller._selectionMask,
  );
  controller._markDirty();
}

Uint8List? _fillComputeMagicWandMask(
  BitmapCanvasController controller,
  Offset position, {
  bool sampleAllLayers = true,
}) {
  final int x = position.dx.floor();
  final int y = position.dy.floor();
  if (x < 0 || x >= controller._width || y < 0 || y >= controller._height) {
    return null;
  }
  final Uint8List mask = Uint8List(controller._width * controller._height);
  if (sampleAllLayers) {
    controller._updateComposite(requiresFullSurface: true, region: null);
    final Uint32List? composite = controller._compositePixels;
    if (composite == null || composite.isEmpty) {
      return null;
    }
    final int target = composite[y * controller._width + x];
    final bool filled = _fillFloodFillMask(
      controller,
      pixels: composite,
      targetColor: target,
      mask: mask,
      startX: x,
      startY: y,
      width: controller._width,
      height: controller._height,
    );
    if (!filled) {
      return null;
    }
    return mask;
  }

  final Uint32List pixels = controller._activeSurface.pixels;
  final int target = pixels[y * controller._width + x];
  final bool filled = _fillFloodFillMask(
    controller,
    pixels: pixels,
    targetColor: target,
    mask: mask,
    startX: x,
    startY: y,
    width: controller._width,
    height: controller._height,
  );
  if (!filled) {
    return null;
  }
  return mask;
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
    controller._updateComposite(requiresFullSurface: true, region: null);
    return _fillColorAtComposite(controller, position);
  }
  return _fillColorAtSurface(controller, controller._activeSurface, x, y);
}

bool _fillSelectionAllows(
  BitmapCanvasController controller,
  Offset position,
) {
  final Uint8List? mask = controller._selectionMask;
  if (mask == null) {
    return true;
  }
  final int x = position.dx.floor();
  final int y = position.dy.floor();
  if (x < 0 || x >= controller._width || y < 0 || y >= controller._height) {
    return false;
  }
  return mask[y * controller._width + x] != 0;
}

bool _fillSelectionAllowsInt(
  BitmapCanvasController controller,
  int x,
  int y,
) {
  final Uint8List? mask = controller._selectionMask;
  if (mask == null) {
    return true;
  }
  if (x < 0 || x >= controller._width || y < 0 || y >= controller._height) {
    return false;
  }
  return mask[y * controller._width + x] != 0;
}

void _fillFloodFillAcrossLayers(
  BitmapCanvasController controller,
  int startX,
  int startY,
  Color color,
  bool contiguous,
) {
  if (!_fillSelectionAllowsInt(controller, startX, startY)) {
    return;
  }
  controller._updateComposite(requiresFullSurface: true, region: null);
  final Uint32List? compositePixels = controller._compositePixels;
  if (compositePixels == null || compositePixels.isEmpty) {
    return;
  }
  final int index = startY * controller._width + startX;
  if (index < 0 || index >= compositePixels.length) {
    return;
  }
  final int target = compositePixels[index];
  final int replacement = BitmapSurface.encodeColor(color);
  final Uint32List surfacePixels = controller._activeSurface.pixels;
  final Uint8List? selectionMask = controller._selectionMask;

  if (!contiguous) {
    int minX = controller._width;
    int minY = controller._height;
    int maxX = -1;
    int maxY = -1;
    bool changed = false;
    for (int i = 0; i < compositePixels.length; i++) {
      if (compositePixels[i] != target) {
        continue;
      }
      if (selectionMask != null && selectionMask[i] == 0) {
        continue;
      }
      if (surfacePixels[i] == replacement) {
        continue;
      }
      surfacePixels[i] = replacement;
      changed = true;
      final int px = i % controller._width;
      final int py = i ~/ controller._width;
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
    if (changed) {
      controller._markDirty(
        region: Rect.fromLTRB(
          minX.toDouble(),
          minY.toDouble(),
          (maxX + 1).toDouble(),
          (maxY + 1).toDouble(),
        ),
      );
    }
    return;
  }
  final Uint8List contiguousMask = Uint8List(controller._width * controller._height);
  final bool filled = _fillFloodFillMask(
    controller,
    pixels: compositePixels,
    targetColor: target,
    mask: contiguousMask,
    startX: startX,
    startY: startY,
    width: controller._width,
    height: controller._height,
  );
  if (!filled) {
    return;
  }

  // When sampling across layers we must derive the contiguous region from
  // the composite; the active layer alone may not contain the sampled color.
  int minX = controller._width;
  int minY = controller._height;
  int maxX = -1;
  int maxY = -1;
  bool changed = false;
  for (int i = 0; i < contiguousMask.length; i++) {
    if (contiguousMask[i] == 0) {
      continue;
    }
    if (surfacePixels[i] == replacement) {
      continue;
    }
    surfacePixels[i] = replacement;
    changed = true;
    final int px = i % controller._width;
    final int py = i ~/ controller._width;
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
  if (changed) {
    controller._markDirty(
      region: Rect.fromLTRB(
        minX.toDouble(),
        minY.toDouble(),
        (maxX + 1).toDouble(),
        (maxY + 1).toDouble(),
      ),
    );
  }
}

bool _fillFloodFillMask(
  BitmapCanvasController controller, {
  required Uint32List pixels,
  required int targetColor,
  required Uint8List mask,
  required int startX,
  required int startY,
  required int width,
  required int height,
}) {
  if (pixels.isEmpty || mask.isEmpty) {
    return false;
  }
  final Queue<int> queue = Queue<int>();
  final Set<int> visited = <int>{};
  int processed = 0;

  bool shouldInclude(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return false;
    }
    final int index = y * width + x;
    if (visited.contains(index)) {
      return false;
    }
    visited.add(index);
    if (controller._selectionMask != null && controller._selectionMask![index] == 0) {
      return false;
    }
    return pixels[index] == targetColor;
  }

  void enqueue(int x, int y) {
    if (!shouldInclude(x, y)) {
      return;
    }
    final int index = y * width + x;
    mask[index] = 1;
    queue.add(index);
  }

  enqueue(startX, startY);

  while (queue.isNotEmpty) {
    final int index = queue.removeFirst();
    processed += 1;
    final int x = index % width;
    final int y = index ~/ width;
    enqueue(x + 1, y);
    enqueue(x - 1, y);
    enqueue(x, y + 1);
    enqueue(x, y - 1);
  }

  return processed > 0;
}

Color _fillColorAtComposite(
  BitmapCanvasController controller,
  Offset position,
) {
  final int x = position.dx.floor();
  final int y = position.dy.floor();
  if (x < 0 || x >= controller._width || y < 0 || y >= controller._height) {
    return const Color(0x00000000);
  }
  final int index = y * controller._width + x;
  final Uint32List? compositePixels = controller._compositePixels;
  if (compositePixels != null && compositePixels.length > index) {
    return BitmapSurface.decodeColor(compositePixels[index]);
  }
  int? color;
  for (final BitmapLayerState layer in controller._layers) {
    if (!layer.visible) {
      continue;
    }
    if (controller._activeLayerTranslationSnapshot != null &&
        !controller._pendingActiveLayerTransformCleanup &&
        layer.id == controller._activeLayerTranslationId) {
      continue;
    }
    final int src = layer.surface.pixels[index];
    if (color == null) {
      color = src;
    } else {
      color = BitmapCanvasController._blendArgb(color, src);
    }
  }
  return BitmapSurface.decodeColor(color ?? 0);
}

Color _fillColorAtSurface(
  BitmapCanvasController controller,
  BitmapSurface surface,
  int x,
  int y,
) {
  final Uint32List pixels = surface.pixels;
  final int index = y * controller._width + x;
  if (index < 0 || index >= pixels.length) {
    return const Color(0x00000000);
  }
  return BitmapSurface.decodeColor(pixels[index]);
}
