import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _CpuImageBoundsNative =
    ffi.Uint8 Function(
      ffi.Pointer<ffi.Uint32> pixels,
      ffi.Uint64 pixelsLen,
      ffi.Uint32 width,
      ffi.Uint32 height,
      ffi.Pointer<ffi.Int32> outBounds,
    );

typedef _CpuImageBoundsDart =
    int Function(
      ffi.Pointer<ffi.Uint32> pixels,
      int pixelsLen,
      int width,
      int height,
      ffi.Pointer<ffi.Int32> outBounds,
    );

class CpuImageFfi {
  CpuImageFfi._() {
    try {
      _lib = _openLibrary();
      _bounds = _lib
          .lookupFunction<_CpuImageBoundsNative, _CpuImageBoundsDart>(
            'cpu_image_bounds',
          );
      isSupported = true;
    } catch (_) {
      isSupported = false;
    }
  }

  static final CpuImageFfi instance = CpuImageFfi._();

  static ffi.DynamicLibrary _openLibrary() {
    if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('rust_lib_misa_rin.dll');
    }
    return ffi.DynamicLibrary.process();
  }

  late final ffi.DynamicLibrary _lib;
  late final _CpuImageBoundsDart _bounds;

  late final bool isSupported;

  Int32List? computeBounds({
    required int pixelsPtr,
    required int pixelsLen,
    required int width,
    required int height,
  }) {
    if (!isSupported || pixelsPtr == 0 || pixelsLen <= 0) {
      return null;
    }
    if (width <= 0 || height <= 0) {
      return null;
    }
    final ffi.Pointer<ffi.Int32> outBounds = malloc.allocate<ffi.Int32>(
      ffi.sizeOf<ffi.Int32>() * 4,
    );
    try {
      final int ok = _bounds(
        ffi.Pointer<ffi.Uint32>.fromAddress(pixelsPtr),
        pixelsLen,
        width,
        height,
        outBounds,
      );
      if (ok == 0) {
        return null;
      }
      final Int32List view = outBounds.asTypedList(4);
      final Int32List result = Int32List(4);
      result.setAll(0, view);
      return result;
    } finally {
      malloc.free(outBounds);
    }
  }
}
