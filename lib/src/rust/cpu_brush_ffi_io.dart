import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _CpuBrushDrawStampNative =
    ffi.Uint8 Function(
      ffi.Pointer<ffi.Uint32> pixels,
      ffi.Uint64 pixelsLen,
      ffi.Uint32 width,
      ffi.Uint32 height,
      ffi.Float centerX,
      ffi.Float centerY,
      ffi.Float radius,
      ffi.Uint32 colorArgb,
      ffi.Uint32 brushShape,
      ffi.Uint32 antialiasLevel,
      ffi.Float softness,
      ffi.Uint8 erase,
      ffi.Uint8 randomRotation,
      ffi.Uint32 rotationSeed,
      ffi.Float rotationJitter,
      ffi.Uint8 snapToPixel,
      ffi.Pointer<ffi.Uint8> selection,
      ffi.Uint64 selectionLen,
    );

typedef _CpuBrushDrawStampDart =
    int Function(
      ffi.Pointer<ffi.Uint32> pixels,
      int pixelsLen,
      int width,
      int height,
      double centerX,
      double centerY,
      double radius,
      int colorArgb,
      int brushShape,
      int antialiasLevel,
      double softness,
      int erase,
      int randomRotation,
      int rotationSeed,
      double rotationJitter,
      int snapToPixel,
      ffi.Pointer<ffi.Uint8> selection,
      int selectionLen,
    );

class CpuBrushFfi {
  CpuBrushFfi._() {
    try {
      _lib = _openLibrary();
      _drawStamp = _lib
          .lookupFunction<_CpuBrushDrawStampNative, _CpuBrushDrawStampDart>(
            'cpu_brush_draw_stamp',
          );
      isSupported = true;
    } catch (_) {
      isSupported = false;
    }
  }

  static final CpuBrushFfi instance = CpuBrushFfi._();

  static ffi.DynamicLibrary _openLibrary() {
    if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('rust_lib_misa_rin.dll');
    }
    return ffi.DynamicLibrary.process();
  }

  late final ffi.DynamicLibrary _lib;
  late final _CpuBrushDrawStampDart _drawStamp;

  late final bool isSupported;

  bool drawStamp({
    required int pixelsPtr,
    required int pixelsLen,
    required int width,
    required int height,
    required double centerX,
    required double centerY,
    required double radius,
    required int colorArgb,
    required int brushShape,
    required int antialiasLevel,
    required double softness,
    required bool erase,
    required bool randomRotation,
    required int rotationSeed,
    required double rotationJitter,
    required bool snapToPixel,
    Uint8List? selectionMask,
  }) {
    if (!isSupported || pixelsPtr == 0 || pixelsLen <= 0) {
      return false;
    }
    if (width <= 0 || height <= 0) {
      return false;
    }

    ffi.Pointer<ffi.Uint8> selectionPtr = ffi.nullptr;
    int selectionLen = 0;
    if (selectionMask != null && selectionMask.isNotEmpty) {
      selectionLen = selectionMask.length;
      selectionPtr = malloc.allocate<ffi.Uint8>(selectionLen);
      selectionPtr.asTypedList(selectionLen).setAll(0, selectionMask);
    }

    try {
      final int result = _drawStamp(
        ffi.Pointer<ffi.Uint32>.fromAddress(pixelsPtr),
        pixelsLen,
        width,
        height,
        centerX,
        centerY,
        radius,
        colorArgb,
        brushShape,
        antialiasLevel,
        softness,
        erase ? 1 : 0,
        randomRotation ? 1 : 0,
        rotationSeed,
        rotationJitter,
        snapToPixel ? 1 : 0,
        selectionPtr,
        selectionLen,
      );
      return result != 0;
    } finally {
      if (selectionPtr != ffi.nullptr) {
        malloc.free(selectionPtr);
      }
    }
  }
}
