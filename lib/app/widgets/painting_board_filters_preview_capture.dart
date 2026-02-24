part of 'painting_board.dart';

class _LayerPreviewImages {
  const _LayerPreviewImages({this.background, this.active, this.foreground});

  final ui.Image? background;
  final ui.Image? active;
  final ui.Image? foreground;

  void dispose() {
    background?.dispose();
    active?.dispose();
    foreground?.dispose();
  }
}

const int _kPreviewTiledCompositeMinPixels = 4096 * 4096;

int _resolvePreviewTileSize(int width, int height) {
  final int maxDim = math.max(width, height);
  if (maxDim >= 8192) {
    return 1024;
  }
  if (maxDim >= 4096) {
    return 512;
  }
  return 256;
}

Future<_LayerPreviewImages> _captureLayerPreviewImages({
  required CanvasFacade controller,
  required List<CanvasCompositeLayer> layers,
  required String activeLayerId,
  required bool useBackendCanvas,
  bool captureActiveLayerAtFullOpacity = false,
}) async {
  final int width = controller.width;
  final int height = controller.height;
  final CanvasBackend rasterBackend =
      CanvasBackendState.resolveRasterBackend(useBackendCanvas: useBackendCanvas);
  final bool useTiledComposite =
      width * height >= _kPreviewTiledCompositeMinPixels;
  final CanvasRasterBackend tempBackend = CanvasRasterBackend(
    width: width,
    height: height,
    tileSize: _resolvePreviewTileSize(width, height),
    backend: rasterBackend,
    useTiledComposite: useTiledComposite,
  );
  ui.Image? background;
  ui.Image? active;
  ui.Image? foreground;
  try {
    final int activeIndex = layers.indexWhere(
      (layer) => layer.id == activeLayerId,
    );
    if (activeIndex < 0) {
      return const _LayerPreviewImages();
    }
    final List<CanvasCompositeLayer> below = layers.sublist(0, activeIndex);
    final List<CanvasCompositeLayer> above = layers.sublist(activeIndex + 1);
    final CanvasCompositeLayer rawActiveLayer = layers[activeIndex];
    final bool forceFullOpacity =
        captureActiveLayerAtFullOpacity && rawActiveLayer.opacity < 0.999;
    final CanvasCompositeLayer activeLayer = forceFullOpacity
        ? _CompositeLayerOpacityOverride(
            rawActiveLayer,
            opacity: 1.0,
          )
        : rawActiveLayer;
    if (below.isNotEmpty) {
      await tempBackend.composite(layers: below, requiresFullSurface: true);
      final Uint8List rgba = tempBackend.copySurfaceRgba();
      background = await _decodeImage(rgba, width, height);
    }
    tempBackend.resetClipMask();
    Uint32List? compositePixels;
    if (!useTiledComposite) {
      compositePixels = tempBackend.ensureCompositePixels();
      compositePixels.fillRange(0, compositePixels.length, 0);
    }
    await tempBackend.composite(
      layers: <CanvasCompositeLayer>[activeLayer],
      requiresFullSurface: true,
    );
    final Uint8List activeRgba = tempBackend.copySurfaceRgba();
    active = await _decodeImage(activeRgba, width, height);
    if (above.isNotEmpty) {
      if (compositePixels != null) {
        compositePixels.fillRange(0, compositePixels.length, 0);
      }
      await tempBackend.composite(layers: above, requiresFullSurface: true);
      final Uint8List aboveRgba = tempBackend.copySurfaceRgba();
      foreground = await _decodeImage(aboveRgba, width, height);
    }
  } finally {
    await tempBackend.dispose();
  }
  return _LayerPreviewImages(
    background: background,
    active: active,
    foreground: foreground,
  );
}

class _CompositeLayerOpacityOverride implements CanvasCompositeLayer {
  const _CompositeLayerOpacityOverride(this._base, {required this.opacity});

  final CanvasCompositeLayer _base;

  @override
  final double opacity;

  @override
  String get id => _base.id;

  @override
  int get width => _base.width;

  @override
  int get height => _base.height;

  @override
  Uint32List get pixels => _base.pixels;

  @override
  CanvasLayerBlendMode get blendMode => _base.blendMode;

  @override
  bool get visible => _base.visible;

  @override
  bool get clippingMask => _base.clippingMask;

  @override
  int get revision => _base.revision;

  @override
  Uint32List readRect(RasterIntRect rect) => _base.readRect(rect);
}

Future<ui.Image> _decodeImage(Uint8List pixels, int width, int height) {
  final Completer<ui.Image> completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

int _filterRoundChannel(double value) {
  final int rounded = value.round();
  if (rounded < 0) {
    return 0;
  }
  if (rounded > 255) {
    return 255;
  }
  return rounded;
}

int _filterClampIndex(int value, int maxExclusive) {
  if (maxExclusive <= 1) {
    return 0;
  }
  if (value < 0) {
    return 0;
  }
  if (value >= maxExclusive) {
    return maxExclusive - 1;
  }
  return value;
}
