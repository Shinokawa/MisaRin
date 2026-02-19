import 'dart:typed_data';

import 'canvas_layer.dart';

abstract class CanvasCompositeLayer {
  String get id;
  Uint32List get pixels;
  double get opacity;
  CanvasLayerBlendMode get blendMode;
  bool get visible;
  bool get clippingMask;
  int get revision;
}
