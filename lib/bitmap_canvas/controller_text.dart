part of 'controller.dart';

Future<String> _textLayerCreate(
  BitmapCanvasController controller,
  CanvasTextData data, {
  String? aboveLayerId,
  String? name,
}) async {
  final BitmapLayerState layer = BitmapLayerState(
    id: generateLayerId(),
    name: name ?? '文字 ${controller._layers.length + 1}',
    surface: BitmapSurface(
      width: controller._width,
      height: controller._height,
    ),
    text: data,
  );
  int insertIndex = controller._layers.length;
  if (aboveLayerId != null) {
    final int targetIndex = controller._layers.indexWhere(
      (candidate) => candidate.id == aboveLayerId,
    );
    if (targetIndex >= 0) {
      insertIndex = targetIndex + 1;
    }
  }
  controller._layers.insert(insertIndex, layer);
  controller._activeIndex = insertIndex;
  controller._layerOverflowStores[layer.id] = _LayerOverflowStore();
  controller._resetWorkerSurfaceSync();
  await _textLayerRender(controller, layer, data);
  controller._markDirty(layerId: layer.id, pixelsDirty: true);
  controller.notifyListeners();
  return layer.id;
}

Future<void> _textLayerUpdate(
  BitmapCanvasController controller,
  String id,
  CanvasTextData data,
) async {
  BitmapLayerState? layer;
  for (final BitmapLayerState candidate in controller._layers) {
    if (candidate.id == id) {
      layer = candidate;
      break;
    }
  }
  if (layer == null) {
    return;
  }
  await _textLayerRender(controller, layer, data);
  controller.notifyListeners();
}

Future<void> _textLayerRender(
  BitmapCanvasController controller,
  BitmapLayerState layer,
  CanvasTextData data,
) async {
  final CanvasTextRaster raster = await controller._textRenderer.rasterize(data);
  layer.surface.pixels.fillRange(0, layer.surface.pixels.length, 0);
  controller._mergeVectorPatchOnMainThread(
    rgbaPixels: raster.pixels,
    left: raster.left,
    top: raster.top,
    width: raster.width,
    height: raster.height,
    erase: false,
    eraseOccludedParts: false,
  );
  layer.surface.markDirty();
  layer.text = data;
  layer.textBounds = raster.layout.bounds;
  layer.revision += 1;
  controller._layerOverflowStores[layer.id]?.clear();
  controller._markDirty(
    region: raster.layout.bounds.inflate(2),
    layerId: layer.id,
    pixelsDirty: true,
  );
}

void _textLayerRasterize(BitmapCanvasController controller, String id) {
  BitmapLayerState? layer;
  for (final BitmapLayerState candidate in controller._layers) {
    if (candidate.id == id) {
      layer = candidate;
      break;
    }
  }
  if (layer == null) {
    return;
  }
  layer.text = null;
  layer.textBounds = null;
  controller.notifyListeners();
}

void _textLayerApplyTranslation(
  BitmapLayerState layer,
  int dx,
  int dy,
) {
  if (layer.text == null || (dx == 0 && dy == 0)) {
    return;
  }
  final ui.Offset delta = ui.Offset(dx.toDouble(), dy.toDouble());
  layer.text = layer.text!.copyWith(
    origin: layer.text!.origin + delta,
  );
  if (layer.textBounds != null) {
    layer.textBounds = layer.textBounds!.shift(delta);
  }
}
