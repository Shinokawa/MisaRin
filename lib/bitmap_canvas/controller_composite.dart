part of 'controller.dart';

void _compositeMarkDirty(BitmapCanvasController controller, {Rect? region}) {
  controller._rasterBackend.markDirty(region: region);
  _compositeScheduleRefresh(controller);
}

void _compositeScheduleRefresh(BitmapCanvasController controller) {
  if (controller._refreshScheduled) {
    return;
  }
  controller._refreshScheduled = true;
  final SchedulerBinding? scheduler = SchedulerBinding.instance;
  if (scheduler == null) {
    scheduleMicrotask(() => _compositeProcessScheduled(controller));
  } else {
    scheduler.ensureVisualUpdate();
    scheduler.scheduleFrameCallback((_) {
      _compositeProcessScheduled(controller);
    });
  }
  controller.notifyListeners();
}

void _compositeProcessScheduled(BitmapCanvasController controller) {
  controller._refreshScheduled = false;
  _compositeProcessPending(controller);
}

void _compositeProcessPending(BitmapCanvasController controller) {
  final RasterCompositeWork work = controller._rasterBackend
      .dequeueCompositeWork();
  if (!work.hasWork) {
    return;
  }

  _compositeUpdate(
    controller,
    requiresFullSurface: work.requiresFullSurface,
    regions: work.regions,
  );

  final Uint8List rgba = controller._rasterBackend.ensureRgbaBuffer();
  ui.decodeImageFromPixels(
    rgba,
    controller._width,
    controller._height,
    ui.PixelFormat.rgba8888,
    (ui.Image image) {
      controller._cachedImage?.dispose();
      controller._cachedImage = image;
      if (controller._pendingActiveLayerTransformCleanup) {
        controller._pendingActiveLayerTransformCleanup = false;
        _resetActiveLayerTranslationState(controller);
      }
      controller._rasterBackend.completeCompositePass();
      controller.notifyListeners();
      if (controller._rasterBackend.isCompositeDirty &&
          !controller._refreshScheduled) {
        _compositeScheduleRefresh(controller);
      }
    },
  );
}

void _compositeUpdate(
  BitmapCanvasController controller, {
  required bool requiresFullSurface,
  List<RasterIntRect>? regions,
}) {
  controller._rasterBackend.composite(
    layers: controller._layers,
    requiresFullSurface: requiresFullSurface,
    regions: regions,
    translatingLayerId: controller._translatingLayerIdForComposite,
  );
}
