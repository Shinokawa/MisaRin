import 'dart:ffi' as ffi;

import 'rust_dylib.dart';

typedef _RustCpuBlendOnCanvasNative =
    ffi.Uint8 Function(
      ffi.Pointer<ffi.Uint32> src,
      ffi.Pointer<ffi.Uint32> dst,
      ffi.Uint64 pixelsLen,
      ffi.Uint32 width,
      ffi.Uint32 height,
      ffi.Int32 startX,
      ffi.Int32 endX,
      ffi.Int32 startY,
      ffi.Int32 endY,
      ffi.Float opacity,
      ffi.Uint32 blendMode,
      ffi.Pointer<ffi.Uint32> mask,
      ffi.Uint64 maskLen,
      ffi.Float maskOpacity,
    );

typedef _RustCpuBlendOnCanvasDart =
    int Function(
      ffi.Pointer<ffi.Uint32> src,
      ffi.Pointer<ffi.Uint32> dst,
      int pixelsLen,
      int width,
      int height,
      int startX,
      int endX,
      int startY,
      int endY,
      double opacity,
      int blendMode,
      ffi.Pointer<ffi.Uint32> mask,
      int maskLen,
      double maskOpacity,
    );

typedef _RustCpuBlendOverflowNative =
    ffi.Uint8 Function(
      ffi.Pointer<ffi.Uint32> canvas,
      ffi.Uint64 canvasLen,
      ffi.Uint32 width,
      ffi.Uint32 height,
      ffi.Pointer<ffi.Int32> upperX,
      ffi.Pointer<ffi.Int32> upperY,
      ffi.Pointer<ffi.Uint32> upperColor,
      ffi.Uint64 upperLen,
      ffi.Pointer<ffi.Int32> lowerX,
      ffi.Pointer<ffi.Int32> lowerY,
      ffi.Pointer<ffi.Uint32> lowerColor,
      ffi.Uint64 lowerLen,
      ffi.Float opacity,
      ffi.Uint32 blendMode,
      ffi.Pointer<ffi.Uint32> mask,
      ffi.Uint64 maskLen,
      ffi.Float maskOpacity,
      ffi.Pointer<ffi.Int32> maskOverflowX,
      ffi.Pointer<ffi.Int32> maskOverflowY,
      ffi.Pointer<ffi.Uint32> maskOverflowColor,
      ffi.Uint64 maskOverflowLen,
      ffi.Pointer<ffi.Int32> outX,
      ffi.Pointer<ffi.Int32> outY,
      ffi.Pointer<ffi.Uint32> outColor,
      ffi.Uint64 outCapacity,
      ffi.Pointer<ffi.Uint64> outCount,
    );

typedef _RustCpuBlendOverflowDart =
    int Function(
      ffi.Pointer<ffi.Uint32> canvas,
      int canvasLen,
      int width,
      int height,
      ffi.Pointer<ffi.Int32> upperX,
      ffi.Pointer<ffi.Int32> upperY,
      ffi.Pointer<ffi.Uint32> upperColor,
      int upperLen,
      ffi.Pointer<ffi.Int32> lowerX,
      ffi.Pointer<ffi.Int32> lowerY,
      ffi.Pointer<ffi.Uint32> lowerColor,
      int lowerLen,
      double opacity,
      int blendMode,
      ffi.Pointer<ffi.Uint32> mask,
      int maskLen,
      double maskOpacity,
      ffi.Pointer<ffi.Int32> maskOverflowX,
      ffi.Pointer<ffi.Int32> maskOverflowY,
      ffi.Pointer<ffi.Uint32> maskOverflowColor,
      int maskOverflowLen,
      ffi.Pointer<ffi.Int32> outX,
      ffi.Pointer<ffi.Int32> outY,
      ffi.Pointer<ffi.Uint32> outColor,
      int outCapacity,
      ffi.Pointer<ffi.Uint64> outCount,
    );

class RustCpuBlendFfi {
  RustCpuBlendFfi._() {
    try {
      _lib = _openLibrary();
      _blendOnCanvas = _lib
          .lookupFunction<
            _RustCpuBlendOnCanvasNative,
            _RustCpuBlendOnCanvasDart
          >('cpu_blend_on_canvas');
      _blendOverflow = _lib
          .lookupFunction<
            _RustCpuBlendOverflowNative,
            _RustCpuBlendOverflowDart
          >('cpu_blend_overflow');
      isSupported = true;
    } catch (_) {
      isSupported = false;
    }
  }

  static final RustCpuBlendFfi instance = RustCpuBlendFfi._();

  static ffi.DynamicLibrary _openLibrary() {
    return RustDynamicLibrary.open();
  }

  late final ffi.DynamicLibrary _lib;
  late final _RustCpuBlendOnCanvasDart _blendOnCanvas;
  late final _RustCpuBlendOverflowDart _blendOverflow;

  late final bool isSupported;

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
    if (!isSupported ||
        srcPtr == 0 ||
        dstPtr == 0 ||
        pixelsLen <= 0 ||
        width <= 0 ||
        height <= 0) {
      return false;
    }
    final int ok = _blendOnCanvas(
      ffi.Pointer<ffi.Uint32>.fromAddress(srcPtr),
      ffi.Pointer<ffi.Uint32>.fromAddress(dstPtr),
      pixelsLen,
      width,
      height,
      startX,
      endX,
      startY,
      endY,
      opacity,
      blendMode,
      ffi.Pointer<ffi.Uint32>.fromAddress(maskPtr),
      maskLen,
      maskOpacity,
    );
    return ok != 0;
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
    if (!isSupported ||
        canvasPtr == 0 ||
        canvasLen <= 0 ||
        width <= 0 ||
        height <= 0 ||
        upperLen < 0 ||
        lowerLen < 0 ||
        outCountPtr == 0) {
      return false;
    }
    final int ok = _blendOverflow(
      ffi.Pointer<ffi.Uint32>.fromAddress(canvasPtr),
      canvasLen,
      width,
      height,
      ffi.Pointer<ffi.Int32>.fromAddress(upperXPtr),
      ffi.Pointer<ffi.Int32>.fromAddress(upperYPtr),
      ffi.Pointer<ffi.Uint32>.fromAddress(upperColorPtr),
      upperLen,
      ffi.Pointer<ffi.Int32>.fromAddress(lowerXPtr),
      ffi.Pointer<ffi.Int32>.fromAddress(lowerYPtr),
      ffi.Pointer<ffi.Uint32>.fromAddress(lowerColorPtr),
      lowerLen,
      opacity,
      blendMode,
      ffi.Pointer<ffi.Uint32>.fromAddress(maskPtr),
      maskLen,
      maskOpacity,
      ffi.Pointer<ffi.Int32>.fromAddress(maskOverflowXPtr),
      ffi.Pointer<ffi.Int32>.fromAddress(maskOverflowYPtr),
      ffi.Pointer<ffi.Uint32>.fromAddress(maskOverflowColorPtr),
      maskOverflowLen,
      ffi.Pointer<ffi.Int32>.fromAddress(outXPtr),
      ffi.Pointer<ffi.Int32>.fromAddress(outYPtr),
      ffi.Pointer<ffi.Uint32>.fromAddress(outColorPtr),
      outCapacity,
      ffi.Pointer<ffi.Uint64>.fromAddress(outCountPtr),
    );
    return ok != 0;
  }
}
