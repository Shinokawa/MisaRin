import 'dart:ffi' as ffi;
import 'dart:io';

typedef _CpuTransformTranslateNative =
    ffi.Uint8 Function(
      ffi.Pointer<ffi.Uint32> canvas,
      ffi.Uint64 canvasLen,
      ffi.Uint32 canvasWidth,
      ffi.Uint32 canvasHeight,
      ffi.Pointer<ffi.Uint32> snapshot,
      ffi.Uint64 snapshotLen,
      ffi.Uint32 snapshotWidth,
      ffi.Uint32 snapshotHeight,
      ffi.Int32 originX,
      ffi.Int32 originY,
      ffi.Int32 dx,
      ffi.Int32 dy,
      ffi.Pointer<ffi.Int32> outX,
      ffi.Pointer<ffi.Int32> outY,
      ffi.Pointer<ffi.Uint32> outColor,
      ffi.Uint64 outCapacity,
      ffi.Pointer<ffi.Uint64> outCount,
    );

typedef _CpuTransformTranslateDart =
    int Function(
      ffi.Pointer<ffi.Uint32> canvas,
      int canvasLen,
      int canvasWidth,
      int canvasHeight,
      ffi.Pointer<ffi.Uint32> snapshot,
      int snapshotLen,
      int snapshotWidth,
      int snapshotHeight,
      int originX,
      int originY,
      int dx,
      int dy,
      ffi.Pointer<ffi.Int32> outX,
      ffi.Pointer<ffi.Int32> outY,
      ffi.Pointer<ffi.Uint32> outColor,
      int outCapacity,
      ffi.Pointer<ffi.Uint64> outCount,
    );

class CpuTransformFfi {
  CpuTransformFfi._() {
    try {
      _lib = _openLibrary();
      _translate = _lib.lookupFunction<
          _CpuTransformTranslateNative,
          _CpuTransformTranslateDart>('cpu_layer_translate');
      isSupported = true;
    } catch (_) {
      isSupported = false;
    }
  }

  static final CpuTransformFfi instance = CpuTransformFfi._();

  static ffi.DynamicLibrary _openLibrary() {
    if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('rust_lib_misa_rin.dll');
    }
    return ffi.DynamicLibrary.process();
  }

  late final ffi.DynamicLibrary _lib;
  late final _CpuTransformTranslateDart _translate;

  late final bool isSupported;

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
    if (!isSupported ||
        canvasPtr == 0 ||
        snapshotPtr == 0 ||
        canvasLen <= 0 ||
        snapshotLen <= 0) {
      return false;
    }
    if (canvasWidth <= 0 ||
        canvasHeight <= 0 ||
        snapshotWidth <= 0 ||
        snapshotHeight <= 0) {
      return false;
    }
    final int result = _translate(
      ffi.Pointer<ffi.Uint32>.fromAddress(canvasPtr),
      canvasLen,
      canvasWidth,
      canvasHeight,
      ffi.Pointer<ffi.Uint32>.fromAddress(snapshotPtr),
      snapshotLen,
      snapshotWidth,
      snapshotHeight,
      originX,
      originY,
      dx,
      dy,
      ffi.Pointer<ffi.Int32>.fromAddress(overflowXPtr),
      ffi.Pointer<ffi.Int32>.fromAddress(overflowYPtr),
      ffi.Pointer<ffi.Uint32>.fromAddress(overflowColorPtr),
      overflowCapacity,
      ffi.Pointer<ffi.Uint64>.fromAddress(overflowCountPtr),
    );
    return result != 0;
  }
}
