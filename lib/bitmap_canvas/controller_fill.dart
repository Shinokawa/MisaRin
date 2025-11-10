part of 'controller.dart';

void _fillSetSelectionMask(BitmapCanvasController controller, Uint8List? mask) {
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
  List<Color>? swallowColors,
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

  final bool shouldSwallow = swallowColors != null && swallowColors.isNotEmpty;
  final List<int>? swallowArgb = shouldSwallow
      ? swallowColors!
            .map((color) => BitmapSurface.encodeColor(color))
            .toList(growable: false)
      : null;

  Uint8List? regionMask;
  if (sampleAllLayers) {
    regionMask = _fillFloodFillAcrossLayers(
      controller,
      x,
      y,
      color,
      contiguous,
      collectMask: shouldSwallow,
    );
  } else {
    final Color baseColor = _fillColorAtSurface(
      controller,
      controller._activeSurface,
      x,
      y,
    );
    if (!shouldSwallow) {
      controller._activeSurface.floodFill(
        start: Offset(x.toDouble(), y.toDouble()),
        color: color,
        targetColor: baseColor,
        contiguous: contiguous,
        mask: controller._selectionMask,
      );
      controller._markDirty();
      return;
    }
    if (baseColor.value == color.value) {
      return;
    }
    regionMask = _fillFloodFillSingleLayerWithMask(
      controller,
      x,
      y,
      color,
      baseColor,
      contiguous,
    );
  }

  if (shouldSwallow && regionMask != null) {
    _fillSwallowColorLines(controller, regionMask, swallowArgb!, color);
  }
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

bool _fillSelectionAllows(BitmapCanvasController controller, Offset position) {
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

bool _fillSelectionAllowsInt(BitmapCanvasController controller, int x, int y) {
  final Uint8List? mask = controller._selectionMask;
  if (mask == null) {
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
}) {
  if (!_fillSelectionAllowsInt(controller, startX, startY)) {
    return null;
  }
  controller._updateComposite(requiresFullSurface: true, region: null);
  final Uint32List? compositePixels = controller._compositePixels;
  if (compositePixels == null || compositePixels.isEmpty) {
    return null;
  }
  final int index = startY * controller._width + startX;
  if (index < 0 || index >= compositePixels.length) {
    return null;
  }
  final int target = compositePixels[index];
  final int replacement = BitmapSurface.encodeColor(color);
  final Uint32List surfacePixels = controller._activeSurface.pixels;
  final Uint8List? selectionMask = controller._selectionMask;

  if (!contiguous) {
    final Uint8List? swallowMask = collectMask
        ? Uint8List(controller._width * controller._height)
        : null;
    int minX = controller._width;
    int minY = controller._height;
    int maxX = -1;
    int maxY = -1;
    bool changed = false;
    for (int i = 0; i < compositePixels.length; i++) {
      final int pixel = compositePixels[i];
      if (pixel != target) {
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
      if (swallowMask != null) {
        swallowMask[i] = 1;
      }
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
    if (swallowMask != null && changed) {
      return swallowMask;
    }
    return null;
  }
  final Uint8List contiguousMask = Uint8List(
    controller._width * controller._height,
  );
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
    return null;
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
  return collectMask ? contiguousMask : null;
}

Uint8List? _fillFloodFillSingleLayerWithMask(
  BitmapCanvasController controller,
  int startX,
  int startY,
  Color fillColor,
  Color baseColor,
  bool contiguous,
) {
  final Uint32List pixels = controller._activeSurface.pixels;
  final Uint8List? selectionMask = controller._selectionMask;
  final int width = controller._width;
  final int height = controller._height;
  final int replacement = BitmapSurface.encodeColor(fillColor);
  final int target = BitmapSurface.encodeColor(baseColor);
  final Uint8List mask = Uint8List(width * height);

  if (!contiguous) {
    int minX = width;
    int minY = height;
    int maxX = -1;
    int maxY = -1;
    bool changed = false;
    for (int i = 0; i < pixels.length; i++) {
      if (selectionMask != null && selectionMask[i] == 0) {
        continue;
      }
      if (pixels[i] != target) {
        continue;
      }
      pixels[i] = replacement;
      mask[i] = 1;
      changed = true;
      final int px = i % width;
      final int py = i ~/ width;
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
    if (!changed) {
      return null;
    }
    controller._markDirty(
      region: Rect.fromLTRB(
        minX.toDouble(),
        minY.toDouble(),
        (maxX + 1).toDouble(),
        (maxY + 1).toDouble(),
      ),
    );
    return mask;
  }

  final bool filled = _fillFloodFillMask(
    controller,
    pixels: pixels,
    targetColor: target,
    mask: mask,
    startX: startX,
    startY: startY,
    width: width,
    height: height,
  );
  if (!filled) {
    return null;
  }

  int minX = width;
  int minY = height;
  int maxX = -1;
  int maxY = -1;
  bool changed = false;
  for (int i = 0; i < mask.length; i++) {
    if (mask[i] == 0) {
      continue;
    }
    if (pixels[i] == replacement) {
      continue;
    }
    pixels[i] = replacement;
    changed = true;
    final int px = i % width;
    final int py = i ~/ width;
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
    return mask;
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
  final Uint8List? selectionMask = controller._selectionMask;
  final Uint32List pixels = controller._activeSurface.pixels;
  final int width = controller._width;
  final int height = controller._height;
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
      if (pixels[index] != targetColor) {
        continue;
      }
      if (selectionMask != null && selectionMask[index] == 0) {
        continue;
      }
      if (pixels[index] == fillArgb) {
        continue;
      }
      pixels[index] = fillArgb;
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
        if (pixels[neighborIndex] != targetColor) {
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

  int index = 0;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++, index++) {
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
        final int neighborColor = pixels[neighborIndex];
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
    if (controller._selectionMask != null &&
        controller._selectionMask![index] == 0) {
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
  return controller._rasterBackend.colorAtComposite(
    position,
    controller._layers,
    translatingLayerId: controller._translatingLayerIdForComposite,
  );
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
