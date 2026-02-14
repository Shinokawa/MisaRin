enum CanvasBackend {
  gpu,
  cpu,
}

enum CanvasFilterType {
  hueSaturation,
  brightnessContrast,
  blackWhite,
  binarize,
  gaussianBlur,
  leakRemoval,
  lineNarrow,
  fillExpand,
  scanPaperDrawing,
  invert,
}

class CanvasBackendCapabilities {
  const CanvasBackendCapabilities({
    required this.isGpuSupported,
    required this.isReady,
    this.supportedFilters = const <CanvasFilterType>{},
    this.supportsLayerTransformPreview = false,
    this.supportsLayerTranslate = false,
    this.supportsAntialias = false,
  });

  final bool isGpuSupported;
  final bool isReady;
  final Set<CanvasFilterType> supportedFilters;
  final bool supportsLayerTransformPreview;
  final bool supportsLayerTranslate;
  final bool supportsAntialias;

  bool get canUseGpu => isGpuSupported && isReady;

  bool supportsFilter(CanvasFilterType type) => supportedFilters.contains(type);
}

abstract class CanvasBackendInterface {
  CanvasBackendCapabilities get capabilities;
}

extension CanvasBackendId on CanvasBackend {
  int get id => index;

  static CanvasBackend fromId(int id) {
    if (id == CanvasBackend.cpu.index) {
      return CanvasBackend.cpu;
    }
    return CanvasBackend.gpu;
  }
}
