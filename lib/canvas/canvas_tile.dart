import 'dart:ui' as ui;

import '../bitmap_canvas/raster_int_rect.dart';

abstract class CanvasTile {
  RasterIntRect get rect;
  ui.Image get image;
  ui.Rect get destinationRect;
  ui.Rect get sourceRect;
}
