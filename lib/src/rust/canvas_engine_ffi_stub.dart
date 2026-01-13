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
}
