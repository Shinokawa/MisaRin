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
  if (controller._compositeProcessing) {
    return;
  }
  controller._compositeProcessing = true;
  unawaited(_compositeProcessPending(controller));
}

Future<void> _compositeProcessPending(BitmapCanvasController controller) async {
  try {
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

    final List<RasterIntRect> dirtyRegions = work.requiresFullSurface
        ? controller._rasterBackend.fullSurfaceTileRects()
        : (work.regions ?? const <RasterIntRect>[]);
    final BitmapCanvasFrame? frame = await controller._tileCache.updateTiles(
      backend: controller._rasterBackend,
      dirtyRegions: dirtyRegions,
      fullSurface: work.requiresFullSurface,
    );
    if (frame != null) {
      controller._currentFrame = frame;
    }
    final List<ui.Image> pendingDisposals =
        controller._tileCache.takePendingDisposals();
    if (pendingDisposals.isNotEmpty) {
      controller._pendingTileDisposals.addAll(pendingDisposals);
      controller._scheduleTileImageDisposal();
    }
    if (controller._pendingActiveLayerTransformCleanup) {
      controller._pendingActiveLayerTransformCleanup = false;
      _resetActiveLayerTranslationState(controller);
    }
    controller._rasterBackend.completeCompositePass();
    controller.notifyListeners();
  } finally {
    controller._compositeProcessing = false;
    if (controller._rasterBackend.isCompositeDirty &&
        !controller._refreshScheduled) {
      _compositeScheduleRefresh(controller);
    }
  }
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
