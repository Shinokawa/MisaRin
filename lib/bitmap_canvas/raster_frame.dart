import 'dart:collection';
import 'dart:ui' as ui;

import '../canvas/canvas_frame.dart';
import '../canvas/canvas_tile.dart';
import 'raster_int_rect.dart';

/// Immutable description of a raster tile that can be painted independently.
class BitmapCanvasTile implements CanvasTile {
  const BitmapCanvasTile({
    required this.rect,
    required this.image,
  });

  @override
  final RasterIntRect rect;
  @override
  final ui.Image image;

  @override
  ui.Rect get destinationRect => ui.Rect.fromLTWH(
        rect.left.toDouble(),
        rect.top.toDouble(),
        rect.width.toDouble(),
        rect.height.toDouble(),
      );

  @override
  ui.Rect get sourceRect => ui.Rect.fromLTWH(
        0,
        0,
        rect.width.toDouble(),
        rect.height.toDouble(),
      );
}

/// Aggregates all tiles required to render a full bitmap surface.
class BitmapCanvasFrame implements CanvasFrame {
  BitmapCanvasFrame({
    required this.tiles,
    required this.surfaceWidth,
    required this.surfaceHeight,
    required this.generation,
  });

  @override
  final UnmodifiableListView<BitmapCanvasTile> tiles;
  @override
  final int surfaceWidth;
  @override
  final int surfaceHeight;
  @override
  final int generation;

  @override
  ui.Size get size => ui.Size(
        surfaceWidth.toDouble(),
        surfaceHeight.toDouble(),
      );
}
