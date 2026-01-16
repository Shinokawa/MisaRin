import 'dart:typed_data';

class CanvasEngineFfi {
  CanvasEngineFfi._();

  static final CanvasEngineFfi instance = CanvasEngineFfi._();

  bool get isSupported => false;

  void pushPointsPacked({
    required int handle,
    required Uint8List bytes,
    required int pointCount,
  }) {}

  int getInputQueueLen(int handle) => 0;

  void setBrush({
    required int handle,
    required int colorArgb,
    required double baseRadius,
    bool usePressure = true,
    bool erase = false,
    int antialiasLevel = 1,
    int brushShape = 0,
    bool randomRotation = false,
    int rotationSeed = 0,
  }) {}

  void setActiveLayer({required int handle, required int layerIndex}) {}

  void setLayerOpacity({
    required int handle,
    required int layerIndex,
    required double opacity,
  }) {}

  void setLayerVisible({
    required int handle,
    required int layerIndex,
    required bool visible,
  }) {}

  void clearLayer({required int handle, required int layerIndex}) {}

  void fillLayer({
    required int handle,
    required int layerIndex,
    required int colorArgb,
  }) {}

  void resetCanvas({required int handle, required int backgroundColorArgb}) {}

  void undo({required int handle}) {}

  void redo({required int handle}) {}
}
