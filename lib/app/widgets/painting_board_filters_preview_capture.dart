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

Future<_LayerPreviewImages> _captureLayerPreviewImages({
  required CanvasFacade controller,
  required List<CanvasCompositeLayer> layers,
  required String activeLayerId,
  required bool useGpuCanvas,
  bool captureActiveLayerAtFullOpacity = false,
}) async {
  final int width = controller.width;
  final int height = controller.height;
  final CanvasBackend rasterBackend =
      useGpuCanvas ? CanvasBackend.gpu : CanvasBackend.cpu;
  final CanvasRasterBackend tempBackend = CanvasRasterBackend(
    width: width,
    height: height,
    backend: rasterBackend,
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
    final Uint32List pixels = tempBackend.ensureCompositePixels();
    pixels.fillRange(0, pixels.length, 0);
    await tempBackend.composite(
      layers: <CanvasCompositeLayer>[activeLayer],
      requiresFullSurface: true,
    );
    final Uint8List activeRgba = tempBackend.copySurfaceRgba();
    active = await _decodeImage(activeRgba, width, height);
    if (above.isNotEmpty) {
      pixels.fillRange(0, pixels.length, 0);
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
  Uint32List get pixels => _base.pixels;

  @override
  CanvasLayerBlendMode get blendMode => _base.blendMode;

  @override
  bool get visible => _base.visible;

  @override
  bool get clippingMask => _base.clippingMask;

  @override
  int get revision => _base.revision;
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
