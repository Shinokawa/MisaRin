part of 'controller.dart';

void _layerManagerSetActiveLayer(
  BitmapCanvasController controller,
  String id,
) {
  final int index = controller._layers.indexWhere((layer) => layer.id == id);
  if (index < 0 || index == controller._activeIndex) {
    return;
  }
  controller._activeIndex = index;
  controller.notifyListeners();
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
    controller._activeIndex =
        _findFallbackActiveIndex(controller, exclude: index);
  }
  controller._markDirty();
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
  controller._markDirty();
  controller.notifyListeners();
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
  controller.notifyListeners();
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
  controller._markDirty();
  controller.notifyListeners();
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
  controller._markDirty();
  controller.notifyListeners();
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
  controller.notifyListeners();
}

void _layerManagerAddLayer(
  BitmapCanvasController controller, {
  String? aboveLayerId,
  String? name,
}) {
  final BitmapLayerState layer = BitmapLayerState(
    id: generateLayerId(),
    name: name ?? '图层 ${controller._layers.length + 1}',
    surface: BitmapSurface(width: controller._width, height: controller._height),
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
  controller._markDirty();
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
  if (controller._activeIndex >= controller._layers.length) {
    controller._activeIndex = controller._layers.length - 1;
  }
  controller._markDirty();
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
  controller._markDirty();
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
  controller._markDirty();
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
  return math.max(0, math.min(controller._layers.length - 1, controller._activeIndex));
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
    for (int i = 0; i < pixels.length; i++) {
      pixels[i] = replacement;
    }
    controller._markDirty();
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
  );
}

String _layerManagerInsertFromData(
  BitmapCanvasController controller,
  CanvasLayerData data, {
  String? aboveLayerId,
}) {
  final BitmapSurface surface =
      BitmapSurface(width: controller._width, height: controller._height);
  if (data.bitmap != null &&
      data.bitmapWidth == controller._width &&
      data.bitmapHeight == controller._height) {
    BitmapCanvasController._writeRgbaToSurface(surface, data.bitmap!);
  } else if (data.fillColor != null) {
    surface.fill(data.fillColor!);
  } else {
    surface.fill(const Color(0x00000000));
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
  controller._markDirty();
  return layer.id;
}

void _layerManagerLoadLayers(
  BitmapCanvasController controller,
  List<CanvasLayerData> layers,
  Color backgroundColor,
) {
  controller._layers.clear();
  controller._clipMaskBuffer = null;
  _loadFromCanvasLayers(controller, layers, backgroundColor);
  controller._markDirty();
}

List<CanvasLayerData> _layerManagerSnapshotLayers(
  BitmapCanvasController controller,
) {
  final List<CanvasLayerData> result = <CanvasLayerData>[];
  for (int i = 0; i < controller._layers.length; i++) {
    final BitmapLayerState layer = controller._layers[i];
    Uint8List? bitmap;
    if (!BitmapCanvasController._isSurfaceEmpty(layer.surface)) {
      bitmap = BitmapCanvasController._surfaceToRgba(layer.surface);
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
        bitmap: bitmap,
        bitmapWidth: bitmap != null ? controller._width : null,
        bitmapHeight: bitmap != null ? controller._height : null,
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
  final Uint8List bitmap = effectiveMask == null
      ? BitmapCanvasController._surfaceToRgba(layer.surface)
      : BitmapCanvasController._surfaceToMaskedRgba(
          layer.surface,
          effectiveMask,
        );
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
    bitmapWidth: controller._width,
    bitmapHeight: controller._height,
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
      BitmapLayerState(
        id: generateLayerId(),
        name: '背景',
        surface: background,
      ),
    )
    ..add(
      BitmapLayerState(
        id: generateLayerId(),
        name: '图层 2',
        surface: paintSurface,
      ),
    );
  controller._activeIndex = controller._layers.length - 1;
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
    if (layer.bitmap != null &&
        layer.bitmapWidth == controller._width &&
        layer.bitmapHeight == controller._height) {
      BitmapCanvasController._writeRgbaToSurface(surface, layer.bitmap!);
    } else if (layer.fillColor != null) {
      surface.fill(layer.fillColor!);
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
      ),
    );
    if (layer == layers.first && layer.fillColor != null) {
      controller._backgroundColor = layer.fillColor!;
    }
  }
  controller._activeIndex = controller._layers.length - 1;
}
