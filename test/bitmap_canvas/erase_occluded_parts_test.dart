import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:misa_rin/bitmap_canvas/bitmap_canvas.dart';
import 'package:misa_rin/bitmap_canvas/controller.dart';
import 'package:misa_rin/canvas/canvas_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitForStrokeRasterization(BitmapCanvasController controller) async {
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 5));
    while (controller.committingStrokes.isNotEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Timed out waiting for stroke rasterization.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await controller.waitForPendingWorkerTasks();
  }

  BitmapCanvasController buildController() {
    final BitmapCanvasController controller = BitmapCanvasController(
      width: 21,
      height: 21,
      backgroundColor: Colors.transparent,
      creationLogic: CanvasCreationLogic.singleThread,
    );
    controller.configureSharpTips(enabled: false);
    return controller;
  }

  void fillLayerOpaque(BitmapCanvasController controller, Color color) {
    final Uint32List pixels = controller.layers.last.surface.pixels;
    pixels.fillRange(0, pixels.length, BitmapSurface.encodeColor(color));
  }

  Future<void> drawHollowStroke({
    required BitmapCanvasController controller,
    required bool eraseOccludedParts,
  }) async {
    controller.beginStroke(
      const Offset(8, 10),
      color: Colors.white,
      radius: 6,
      antialiasLevel: 1,
      hollow: true,
      hollowRatio: 0.5,
      eraseOccludedParts: eraseOccludedParts,
    );
    controller.extendStroke(const Offset(12, 10));
    controller.endStroke();
    await waitForStrokeRasterization(controller);
  }

  int alphaAt(BitmapCanvasController controller, int x, int y) {
    final Uint32List pixels = controller.layers.last.surface.pixels;
    final int color = pixels[y * controller.width + x];
    return (color >> 24) & 0xff;
  }

  test('hollow cutout keeps underlying when eraseOccludedParts is off', () async {
    final BitmapCanvasController controller = buildController();
    fillLayerOpaque(controller, const Color(0xFF000000));

    await drawHollowStroke(controller: controller, eraseOccludedParts: false);

    expect(alphaAt(controller, 10, 10), 255);
  });

  test('hollow cutout erases underlying when eraseOccludedParts is on', () async {
    final BitmapCanvasController controller = buildController();
    fillLayerOpaque(controller, const Color(0xFF000000));

    await drawHollowStroke(controller: controller, eraseOccludedParts: true);

    expect(alphaAt(controller, 10, 10), 0);
  });
}
