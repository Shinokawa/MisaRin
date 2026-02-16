import 'dart:typed_data';

import 'api/cpu_blend.dart' as rust;
import 'cpu_buffer_registry.dart';

class RustCpuBlendFfi {
  RustCpuBlendFfi._();

  static final RustCpuBlendFfi instance = RustCpuBlendFfi._();

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

  bool blendOnCanvas({
    required int srcPtr,
    required int dstPtr,
    required int pixelsLen,
    required int width,
    required int height,
    required int startX,
    required int endX,
    required int startY,
    required int endY,
    required double opacity,
    required int blendMode,
    int maskPtr = 0,
    int maskLen = 0,
    double maskOpacity = 0,
  }) {
    final Uint32List? src = _lookupPixels(srcPtr, pixelsLen);
    final Uint32List? dst = _lookupPixels(dstPtr, pixelsLen);
    if (src == null || dst == null) {
      return false;
    }
    if (width <= 0 || height <= 0) {
      return false;
    }
    final Uint32List? mask =
        maskPtr == 0 ? null : _lookupPixels(maskPtr, maskLen);
    if (maskPtr != 0 && mask == null) {
      return false;
    }
    final rust.CpuBlendResult result = rust.cpuBlendOnCanvasRgba(
      src: src,
      dst: dst,
      width: width,
      height: height,
      startX: startX,
      endX: endX,
      startY: startY,
      endY: endY,
      opacity: opacity,
      blendMode: blendMode,
      mask: mask,
      maskOpacity: maskOpacity,
    );
    if (!result.ok) {
      return false;
    }
    if (result.canvas.length == dst.length) {
      dst.setAll(0, result.canvas);
    } else {
      final int count =
          result.canvas.length < dst.length ? result.canvas.length : dst.length;
      if (count > 0) {
        dst.setAll(0, result.canvas.sublist(0, count));
      }
    }
    return true;
  }

  bool blendOverflow({
    required int canvasPtr,
    required int canvasLen,
    required int width,
    required int height,
    required int upperXPtr,
    required int upperYPtr,
    required int upperColorPtr,
    required int upperLen,
    required int lowerXPtr,
    required int lowerYPtr,
    required int lowerColorPtr,
    required int lowerLen,
    required double opacity,
    required int blendMode,
    int maskPtr = 0,
    int maskLen = 0,
    double maskOpacity = 0,
    int maskOverflowXPtr = 0,
    int maskOverflowYPtr = 0,
    int maskOverflowColorPtr = 0,
    int maskOverflowLen = 0,
    int outXPtr = 0,
    int outYPtr = 0,
    int outColorPtr = 0,
    int outCapacity = 0,
    int outCountPtr = 0,
  }) {
    final Uint32List? canvas = _lookupPixels(canvasPtr, canvasLen);
    if (canvas == null) {
      return false;
    }
    if (width <= 0 || height <= 0) {
      return false;
    }
    final Int32List? upperX = CpuBufferRegistry.lookup<Int32List>(upperXPtr);
    final Int32List? upperY = CpuBufferRegistry.lookup<Int32List>(upperYPtr);
    final Uint32List? upperColor =
        CpuBufferRegistry.lookup<Uint32List>(upperColorPtr);
    if (upperX == null || upperY == null || upperColor == null) {
      return false;
    }
    if (upperLen > 0 &&
        (upperX.length < upperLen ||
            upperY.length < upperLen ||
            upperColor.length < upperLen)) {
      return false;
    }

    final Int32List lowerX = lowerXPtr == 0
        ? Int32List(0)
        : (CpuBufferRegistry.lookup<Int32List>(lowerXPtr) ?? Int32List(0));
    final Int32List lowerY = lowerYPtr == 0
        ? Int32List(0)
        : (CpuBufferRegistry.lookup<Int32List>(lowerYPtr) ?? Int32List(0));
    final Uint32List lowerColor = lowerColorPtr == 0
        ? Uint32List(0)
        : (CpuBufferRegistry.lookup<Uint32List>(lowerColorPtr) ?? Uint32List(0));
    if (lowerLen > 0 &&
        (lowerX.length < lowerLen ||
            lowerY.length < lowerLen ||
            lowerColor.length < lowerLen)) {
      return false;
    }

    final Uint32List? mask =
        maskPtr == 0 ? null : _lookupPixels(maskPtr, maskLen);
    if (maskPtr != 0 && mask == null) {
      return false;
    }

    final Int32List maskOverflowX = maskOverflowXPtr == 0
        ? Int32List(0)
        : (CpuBufferRegistry.lookup<Int32List>(maskOverflowXPtr) ?? Int32List(0));
    final Int32List maskOverflowY = maskOverflowYPtr == 0
        ? Int32List(0)
        : (CpuBufferRegistry.lookup<Int32List>(maskOverflowYPtr) ?? Int32List(0));
    final Uint32List maskOverflowColor = maskOverflowColorPtr == 0
        ? Uint32List(0)
        : (CpuBufferRegistry.lookup<Uint32List>(maskOverflowColorPtr) ?? Uint32List(0));
    if (maskOverflowLen > 0 &&
        (maskOverflowX.length < maskOverflowLen ||
            maskOverflowY.length < maskOverflowLen ||
            maskOverflowColor.length < maskOverflowLen)) {
      return false;
    }

    final rust.CpuBlendOverflowResult result = rust.cpuBlendOverflowRgba(
      canvas: canvas,
      width: width,
      height: height,
      upperX: upperX.sublist(0, upperLen),
      upperY: upperY.sublist(0, upperLen),
      upperColor: upperColor.sublist(0, upperLen),
      lowerX: lowerLen > 0 ? lowerX.sublist(0, lowerLen) : const <int>[],
      lowerY: lowerLen > 0 ? lowerY.sublist(0, lowerLen) : const <int>[],
      lowerColor: lowerLen > 0 ? lowerColor.sublist(0, lowerLen) : const <int>[],
      opacity: opacity,
      blendMode: blendMode,
      mask: mask,
      maskOpacity: maskOpacity,
      maskOverflowX:
          maskOverflowLen > 0 ? maskOverflowX.sublist(0, maskOverflowLen) : const <int>[],
      maskOverflowY:
          maskOverflowLen > 0 ? maskOverflowY.sublist(0, maskOverflowLen) : const <int>[],
      maskOverflowColor:
          maskOverflowLen > 0 ? maskOverflowColor.sublist(0, maskOverflowLen) : const <int>[],
      outCapacity: BigInt.from(outCapacity),
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
      if (count > 0) {
        canvas.setAll(0, result.canvas.sublist(0, count));
      }
    }

    if (outXPtr != 0 &&
        outYPtr != 0 &&
        outColorPtr != 0 &&
        outCountPtr != 0 &&
        outCapacity > 0) {
      final Int32List? outX = CpuBufferRegistry.lookup<Int32List>(outXPtr);
      final Int32List? outY = CpuBufferRegistry.lookup<Int32List>(outYPtr);
      final Uint32List? outColor =
          CpuBufferRegistry.lookup<Uint32List>(outColorPtr);
      final Uint64List? outCount =
          CpuBufferRegistry.lookup<Uint64List>(outCountPtr);
      if (outX != null && outY != null && outColor != null && outCount != null) {
        final int maxCount = [
          outCapacity,
          outX.length,
          outY.length,
          outColor.length,
          result.outX.length,
          result.outY.length,
          result.outColor.length,
        ].reduce((value, element) => value < element ? value : element);
        for (int i = 0; i < maxCount; i++) {
          outX[i] = result.outX[i];
          outY[i] = result.outY[i];
          outColor[i] = result.outColor[i];
        }
        if (outCount.isNotEmpty) {
          outCount[0] = maxCount;
        }
      }
    }
    return true;
  }
}
