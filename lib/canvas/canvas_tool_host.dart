import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'canvas_tools.dart';

abstract class CanvasToolHost {
  void runSynchronousRasterization(VoidCallback action);

  void drawBrushStamp({
    required Offset center,
    required double radius,
    required Color color,
    BrushShape brushShape = BrushShape.circle,
    int antialiasLevel = 0,
    bool erase = false,
    double softness = 0.0,
  });

  Color sampleColor(Offset position, {bool sampleAllLayers = true});
}
