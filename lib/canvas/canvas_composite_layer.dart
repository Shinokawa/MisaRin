import 'dart:typed_data';

import '../bitmap_canvas/raster_int_rect.dart';
import 'canvas_layer.dart';

abstract class CanvasCompositeLayer {
  String get id;
  int get width;
  int get height;
  Uint32List get pixels;
  double get opacity;
  CanvasLayerBlendMode get blendMode;
  bool get visible;
  bool get clippingMask;
  int get revision;

  Uint32List readRect(RasterIntRect rect) {
    if (rect.isEmpty) {
      return Uint32List(0);
    }
    final int width = rect.width;
    final int height = rect.height;
    final Uint32List buffer = Uint32List(width * height);
    final Uint32List source = pixels;
    final int surfaceWidth = this.width;
    final int surfaceHeight = this.height;
    if (surfaceWidth <= 0 || surfaceHeight <= 0) {
      return buffer;
    }
    final int left = rect.left.clamp(0, surfaceWidth);
    final int top = rect.top.clamp(0, surfaceHeight);
    final int right = rect.right.clamp(0, surfaceWidth);
    final int bottom = rect.bottom.clamp(0, surfaceHeight);
    if (left >= right || top >= bottom) {
      return buffer;
    }
    for (int row = top; row < bottom; row++) {
      final int srcRow = row * surfaceWidth + left;
      final int dstRow = (row - rect.top) * width + (left - rect.left);
      buffer.setRange(dstRow, dstRow + (right - left), source, srcRow);
    }
    return buffer;
  }
}
