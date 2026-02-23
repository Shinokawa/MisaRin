import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../canvas/canvas_composite_layer.dart';
import '../canvas/canvas_layer.dart';
import '../canvas/canvas_layer_info.dart';
import '../canvas/text_renderer.dart';
import 'raster_int_rect.dart';
import 'layer_surface.dart';

/// 在画布控制器与渲染后端之间共享的图层状态模型。
class BitmapLayerState implements CanvasLayerInfo, CanvasCompositeLayer {
  BitmapLayerState({
    required this.id,
    required this.name,
    required this.surface,
    this.visible = true,
    this.opacity = 1.0,
    this.locked = false,
    this.clippingMask = false,
    this.blendMode = CanvasLayerBlendMode.normal,
    this.text,
    this.textBounds,
  });

  final String id;
  String name;
  bool visible;
  double opacity;
  bool locked;
  bool clippingMask;
  CanvasLayerBlendMode blendMode;
  final LayerSurface surface;
  int revision = 0;
  CanvasTextData? text;
  Rect? textBounds;

  @override
  Uint32List get pixels => surface.pixels;

  @override
  int get width => surface.width;

  @override
  int get height => surface.height;

  @override
  Uint32List readRect(RasterIntRect rect) => surface.readRect(rect);
}
