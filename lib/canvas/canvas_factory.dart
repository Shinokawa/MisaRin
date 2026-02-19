import 'package:flutter/material.dart';

import '../bitmap_canvas/controller.dart';
import '../canvas/canvas_backend.dart';
import '../canvas/canvas_facade.dart';
import '../canvas/canvas_layer.dart';
import '../canvas/canvas_settings.dart';

CanvasFacade createCanvasFacade({
  required int width,
  required int height,
  required Color backgroundColor,
  List<CanvasLayerData>? initialLayers,
  CanvasCreationLogic creationLogic = CanvasCreationLogic.multiThread,
  bool enableRasterOutput = true,
  CanvasBackend backend = CanvasBackend.rustWgpu,
}) {
  return BitmapCanvasController(
    width: width,
    height: height,
    backgroundColor: backgroundColor,
    initialLayers: initialLayers,
    creationLogic: creationLogic,
    enableRasterOutput: enableRasterOutput,
    backend: backend,
  );
}
