import 'dart:typed_data';

import 'api/cpu_transform.dart' as rust;
import 'cpu_buffer_registry.dart';

class RustCpuTransformFfi {
  RustCpuTransformFfi._();

  static final RustCpuTransformFfi instance = RustCpuTransformFfi._();

  bool get isSupported => true;

  Uint32List? _lookupPixels(int ptr, int len) {
    if (ptr == 0 || len <= 0) {
      return null;
    }
    final Uint32List? pixels = CpuBufferRegistry.lookup<Uint32List>(ptr);
    if (pixels == null || pixels.length < len) {
      return null;
    }
    return pixels;
  }

  bool translateLayer({
    required int canvasPtr,
    required int canvasLen,
    required int canvasWidth,
    required int canvasHeight,
    required int snapshotPtr,
    required int snapshotLen,
    required int snapshotWidth,
    required int snapshotHeight,
    required int originX,
    required int originY,
    required int dx,
    required int dy,
    int overflowXPtr = 0,
    int overflowYPtr = 0,
    int overflowColorPtr = 0,
    int overflowCapacity = 0,
    int overflowCountPtr = 0,
  }) {
    final Uint32List? canvas = _lookupPixels(canvasPtr, canvasLen);
    final Uint32List? snapshot = _lookupPixels(snapshotPtr, snapshotLen);
    if (canvas == null || snapshot == null) {
      return false;
    }
    if (canvasWidth <= 0 ||
        canvasHeight <= 0 ||
        snapshotWidth <= 0 ||
        snapshotHeight <= 0) {
      return false;
    }
    final rust.CpuTransformTranslateResult result = rust
        .cpuTransformTranslateLayer(
          canvas: canvas,
          canvasWidth: canvasWidth,
          canvasHeight: canvasHeight,
          snapshot: snapshot,
          snapshotWidth: snapshotWidth,
          snapshotHeight: snapshotHeight,
          originX: originX,
          originY: originY,
          dx: dx,
          dy: dy,
          overflowCapacity: BigInt.from(overflowCapacity),
        );
    if (!result.ok) {
      return false;
    }
    if (result.canvas.length == canvas.length) {
      canvas.setAll(0, result.canvas);
    } else {
      final int count = result.canvas.length < canvas.length
          ? result.canvas.length
          : canvas.length;
      canvas.setAll(0, result.canvas.sublist(0, count));
    }

    if (overflowXPtr != 0 &&
        overflowYPtr != 0 &&
        overflowColorPtr != 0 &&
        overflowCountPtr != 0 &&
        overflowCapacity > 0) {
      final Int32List? outX = CpuBufferRegistry.lookup<Int32List>(overflowXPtr);
      final Int32List? outY = CpuBufferRegistry.lookup<Int32List>(overflowYPtr);
      final Uint32List? outColor = CpuBufferRegistry.lookup<Uint32List>(
        overflowColorPtr,
      );
      final Uint64List? outCount = CpuBufferRegistry.lookup<Uint64List>(
        overflowCountPtr,
      );
      if (outX != null &&
          outY != null &&
          outColor != null &&
          outCount != null) {
        final int maxCount = [
          overflowCapacity,
          outX.length,
          outY.length,
          outColor.length,
          result.overflowX.length,
          result.overflowY.length,
          result.overflowColor.length,
        ].reduce((value, element) => value < element ? value : element);
        for (int i = 0; i < maxCount; i++) {
          outX[i] = result.overflowX[i];
          outY[i] = result.overflowY[i];
          outColor[i] = result.overflowColor[i];
        }
        if (outCount.isNotEmpty) {
          outCount[0] = maxCount;
        }
      }
    }
    return true;
  }

  bool buildOverflowSnapshot({
    required int canvasPtr,
    required int canvasLen,
    required int canvasWidth,
    required int canvasHeight,
    required int snapshotPtr,
    required int snapshotLen,
    required int snapshotWidth,
    required int snapshotHeight,
    required int originX,
    required int originY,
    int overflowXPtr = 0,
    int overflowYPtr = 0,
    int overflowColorPtr = 0,
    int overflowLen = 0,
  }) {
    final Uint32List? canvas = _lookupPixels(canvasPtr, canvasLen);
    final Uint32List? snapshot = _lookupPixels(snapshotPtr, snapshotLen);
    if (canvas == null || snapshot == null) {
      return false;
    }
    if (canvasWidth <= 0 ||
        canvasHeight <= 0 ||
        snapshotWidth <= 0 ||
        snapshotHeight <= 0) {
      return false;
    }
    final Int32List overflowX = overflowXPtr == 0
        ? Int32List(0)
        : (CpuBufferRegistry.lookup<Int32List>(overflowXPtr) ?? Int32List(0));
    final Int32List overflowY = overflowYPtr == 0
        ? Int32List(0)
        : (CpuBufferRegistry.lookup<Int32List>(overflowYPtr) ?? Int32List(0));
    final Uint32List overflowColor = overflowColorPtr == 0
        ? Uint32List(0)
        : (CpuBufferRegistry.lookup<Uint32List>(overflowColorPtr) ??
              Uint32List(0));
    final int actualOverflowLen = overflowLen > 0 ? overflowLen : 0;
    final rust.CpuTransformSnapshotResult result = rust
        .cpuTransformBuildOverflowSnapshot(
          canvas: canvas,
          canvasWidth: canvasWidth,
          canvasHeight: canvasHeight,
          snapshotWidth: snapshotWidth,
          snapshotHeight: snapshotHeight,
          originX: originX,
          originY: originY,
          overflowX: overflowX.length >= actualOverflowLen
              ? overflowX.sublist(0, actualOverflowLen)
              : overflowX,
          overflowY: overflowY.length >= actualOverflowLen
              ? overflowY.sublist(0, actualOverflowLen)
              : overflowY,
          overflowColor: overflowColor.length >= actualOverflowLen
              ? overflowColor.sublist(0, actualOverflowLen)
              : overflowColor,
        );
    if (!result.ok) {
      return false;
    }
    if (result.snapshot.length == snapshot.length) {
      snapshot.setAll(0, result.snapshot);
    } else {
      final int count = result.snapshot.length < snapshot.length
          ? result.snapshot.length
          : snapshot.length;
      snapshot.setAll(0, result.snapshot.sublist(0, count));
    }
    return true;
  }
}
