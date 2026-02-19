import 'dart:ui';

import 'canvas_layer.dart';
import 'text_renderer.dart';

abstract class CanvasLayerInfo {
  String get id;
  String get name;
  bool get visible;
  double get opacity;
  bool get locked;
  bool get clippingMask;
  CanvasLayerBlendMode get blendMode;
  int get revision;
  CanvasTextData? get text;
  Rect? get textBounds;
}
