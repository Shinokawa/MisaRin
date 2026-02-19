import 'dart:collection';
import 'dart:ui' as ui;

import 'canvas_tile.dart';

abstract class CanvasFrame {
  UnmodifiableListView<CanvasTile> get tiles;
  int get surfaceWidth;
  int get surfaceHeight;
  int get generation;
  ui.Size get size;
}
