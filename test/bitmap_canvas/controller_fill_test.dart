import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:misa_rin/bitmap_canvas/bitmap_canvas.dart';
import 'package:misa_rin/bitmap_canvas/controller.dart';
import 'package:misa_rin/canvas/canvas_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bucket fill uses composite colors for contiguous cross-layer fills', () async {
    final BitmapCanvasController controller = BitmapCanvasController(
      width: 3,
      height: 1,
      backgroundColor: Colors.white,
      creationLogic: CanvasCreationLogic.singleThread,
    );
    final BitmapLayerState backgroundLayer = controller.layers.first;
    final Uint32List pixels = backgroundLayer.surface.pixels;
    pixels[0] = BitmapSurface.encodeColor(const Color(0xFFFF0000));
    pixels[1] = BitmapSurface.encodeColor(const Color(0xFF0000FF));
    pixels[2] = BitmapSurface.encodeColor(const Color(0xFFFF0000));

    controller.floodFill(
      const Offset(0, 0),
      color: const Color(0xFF00FF00),
      contiguous: true,
      sampleAllLayers: true,
    );
    await controller.waitForPendingWorkerTasks();

    final BitmapLayerState activeLayer = controller.layers.last;
    expect(activeLayer.surface.pixelAt(0, 0), const Color(0xFF00FF00));
    expect(activeLayer.surface.pixelAt(1, 0), const Color(0x00000000));
    expect(activeLayer.surface.pixelAt(2, 0), const Color(0x00000000));
  });

  test('bucket fill fillGap prevents leaking through small gaps', () async {
    BitmapLayerState buildLeakyLayer(BitmapCanvasController controller) {
      final BitmapLayerState layer = controller.layers.last;
      controller.setActiveLayer(layer.id);
      final Uint32List pixels = layer.surface.pixels;
      const int w = 7;
      const int h = 7;
      final int black = BitmapSurface.encodeColor(const Color(0xFF000000));
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final bool isBorder =
              (x == 1 || x == 5) && y >= 1 && y <= 5 ||
              (y == 1 || y == 5) && x >= 1 && x <= 5;
          if (!isBorder) {
            continue;
          }
          if (x == 3 && y == 1) {
            continue; // Gap on the top edge.
          }
          pixels[y * w + x] = black;
        }
      }
      layer.surface.markDirty();
      layer.revision += 1;
      return layer;
    }

    final BitmapCanvasController controllerLeak = BitmapCanvasController(
      width: 7,
      height: 7,
      backgroundColor: Colors.white,
      creationLogic: CanvasCreationLogic.singleThread,
    );
    final BitmapLayerState leakyLayer = buildLeakyLayer(controllerLeak);
    controllerLeak.floodFill(
      const Offset(3, 3),
      color: const Color(0xFFFF0000),
      contiguous: true,
      fillGap: 0,
    );
    await controllerLeak.waitForPendingWorkerTasks();
    expect(leakyLayer.surface.pixelAt(3, 3), const Color(0xFFFF0000));
    expect(leakyLayer.surface.pixelAt(0, 0), const Color(0xFFFF0000));

    final BitmapCanvasController controllerSafe = BitmapCanvasController(
      width: 7,
      height: 7,
      backgroundColor: Colors.white,
      creationLogic: CanvasCreationLogic.singleThread,
    );
    final BitmapLayerState safeLayer = buildLeakyLayer(controllerSafe);
    controllerSafe.floodFill(
      const Offset(3, 3),
      color: const Color(0xFFFF0000),
      contiguous: true,
      fillGap: 1,
    );
    await controllerSafe.waitForPendingWorkerTasks();
    expect(safeLayer.surface.pixelAt(0, 0), const Color(0x00000000));
    expect(safeLayer.surface.pixelAt(3, 3), const Color(0xFFFF0000));
  });

  test('bucket fill fillGap does not create an inner margin', () async {
    BitmapLayerState buildClosedBoxLayer(BitmapCanvasController controller) {
      final BitmapLayerState layer = controller.layers.last;
      controller.setActiveLayer(layer.id);
      final Uint32List pixels = layer.surface.pixels;
      const int w = 11;
      const int h = 11;
      const int left = 2;
      const int right = 8;
      const int top = 2;
      const int bottom = 8;
      final int black = BitmapSurface.encodeColor(const Color(0xFF000000));
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final bool isBorder =
              (x == left || x == right) && y >= top && y <= bottom ||
              (y == top || y == bottom) && x >= left && x <= right;
          if (!isBorder) {
            continue;
          }
          pixels[y * w + x] = black;
        }
      }
      layer.surface.markDirty();
      layer.revision += 1;
      return layer;
    }

    final BitmapCanvasController controller = BitmapCanvasController(
      width: 11,
      height: 11,
      backgroundColor: Colors.white,
      creationLogic: CanvasCreationLogic.singleThread,
    );
    final BitmapLayerState layer = buildClosedBoxLayer(controller);
    controller.floodFill(
      const Offset(5, 5),
      color: const Color(0xFFFF0000),
      contiguous: true,
      fillGap: 2,
    );
    await controller.waitForPendingWorkerTasks();
    expect(layer.surface.pixelAt(0, 0), const Color(0x00000000));
    expect(layer.surface.pixelAt(3, 3), const Color(0xFFFF0000));
    expect(layer.surface.pixelAt(2, 2), const Color(0xFF000000));
  });

  test('bucket fill fillGap does not create margin with mask fill', () async {
    BitmapLayerState buildClosedBoxLayer(BitmapCanvasController controller) {
      final BitmapLayerState layer = controller.layers.last;
      controller.setActiveLayer(layer.id);
      final Uint32List pixels = layer.surface.pixels;
      const int w = 11;
      const int h = 11;
      const int left = 2;
      const int right = 8;
      const int top = 2;
      const int bottom = 8;
      final int black = BitmapSurface.encodeColor(const Color(0xFF000000));
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final bool isBorder =
              (x == left || x == right) && y >= top && y <= bottom ||
              (y == top || y == bottom) && x >= left && x <= right;
          if (!isBorder) {
            continue;
          }
          pixels[y * w + x] = black;
        }
      }
      layer.surface.markDirty();
      layer.revision += 1;
      return layer;
    }

    final BitmapCanvasController controller = BitmapCanvasController(
      width: 11,
      height: 11,
      backgroundColor: Colors.white,
      creationLogic: CanvasCreationLogic.singleThread,
    );
    final BitmapLayerState layer = buildClosedBoxLayer(controller);
    controller.floodFill(
      const Offset(5, 5),
      color: const Color(0xFFFF0000),
      contiguous: true,
      fillGap: 2,
      swallowColors: const <Color>[Color(0xFF00FF00)],
    );
    await controller.waitForPendingWorkerTasks();
    expect(layer.surface.pixelAt(0, 0), const Color(0x00000000));
    expect(layer.surface.pixelAt(3, 3), const Color(0xFFFF0000));
    expect(layer.surface.pixelAt(2, 2), const Color(0xFF000000));
  });

  test('bucket fill fillGap preserves curved regions', () async {
    BitmapLayerState buildCircleLayer(BitmapCanvasController controller) {
      final BitmapLayerState layer = controller.layers.last;
      controller.setActiveLayer(layer.id);
      final Uint32List pixels = layer.surface.pixels;
      const int w = 25;
      const int h = 25;
      const int cx = 12;
      const int cy = 12;
      const int r = 9;
      final int black = BitmapSurface.encodeColor(const Color(0xFF000000));
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final int dx = x - cx;
          final int dy = y - cy;
          final int distSq = dx * dx + dy * dy;
          if (distSq >= r * r && distSq <= (r + 2) * (r + 2)) {
            pixels[y * w + x] = black;
          }
        }
      }
      layer.surface.markDirty();
      layer.revision += 1;
      return layer;
    }

    const int w = 25;
    const int h = 25;
    const int cx = 12;
    const int cy = 12;
    const int r = 9;

    final BitmapCanvasController controller = BitmapCanvasController(
      width: w,
      height: h,
      backgroundColor: Colors.white,
      creationLogic: CanvasCreationLogic.singleThread,
    );
    final BitmapLayerState layer = buildCircleLayer(controller);
    controller.floodFill(
      Offset(cx.toDouble(), cy.toDouble()),
      color: const Color(0xFFFF0000),
      contiguous: true,
      fillGap: 3,
    );
    await controller.waitForPendingWorkerTasks();
    expect(layer.surface.pixelAt(0, 0), const Color(0x00000000));
    expect(layer.surface.pixelAt(cx + r, cy), const Color(0xFF000000));
    expect(layer.surface.pixelAt(cx + r - 1, cy), const Color(0xFFFF0000));
    expect(layer.surface.pixelAt(cx, cy + r - 1), const Color(0xFFFF0000));
  });

  test('bucket fill fillGap does not drop thin curved bands', () async {
    BitmapLayerState buildRingLayer(BitmapCanvasController controller) {
      final BitmapLayerState layer = controller.layers.last;
      controller.setActiveLayer(layer.id);
      final Uint32List pixels = layer.surface.pixels;
      const int w = 25;
      const int h = 25;
      const int cx = 12;
      const int cy = 12;
      const int innerR = 7;
      const int outerR = 9;
      final int black = BitmapSurface.encodeColor(const Color(0xFF000000));
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final int dx = x - cx;
          final int dy = y - cy;
          final int distSq = dx * dx + dy * dy;
          if (distSq <= innerR * innerR || distSq >= outerR * outerR) {
            pixels[y * w + x] = black;
          }
        }
      }
      layer.surface.markDirty();
      layer.revision += 1;
      return layer;
    }

    const int w = 25;
    const int h = 25;
    const int cx = 12;
    const int cy = 12;
    const int innerR = 7;
    const int outerR = 9;

    final BitmapCanvasController controller = BitmapCanvasController(
      width: w,
      height: h,
      backgroundColor: Colors.white,
      creationLogic: CanvasCreationLogic.singleThread,
    );
    final BitmapLayerState layer = buildRingLayer(controller);
    controller.floodFill(
      Offset((cx + innerR + 1).toDouble(), cy.toDouble()),
      color: const Color(0xFFFF0000),
      contiguous: true,
      fillGap: 3,
    );
    await controller.waitForPendingWorkerTasks();
    expect(layer.surface.pixelAt(0, 0), const Color(0xFF000000));
    expect(layer.surface.pixelAt(cx + innerR + 1, cy), const Color(0xFFFF0000));
    expect(layer.surface.pixelAt(cx + outerR + 1, cy), const Color(0xFF000000));
  });
}
