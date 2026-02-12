import 'dart:ffi' as ffi;
import 'dart:io';

typedef _CpuFiltersApplyAntialiasNative =
    ffi.Uint8 Function(
      ffi.Pointer<ffi.Uint32> pixels,
      ffi.Uint64 pixelsLen,
      ffi.Uint32 width,
      ffi.Uint32 height,
      ffi.Uint32 level,
      ffi.Uint8 previewOnly,
    );

typedef _CpuFiltersApplyAntialiasDart =
    int Function(
      ffi.Pointer<ffi.Uint32> pixels,
      int pixelsLen,
      int width,
      int height,
      int level,
      int previewOnly,
    );

class CpuFiltersFfi {
  CpuFiltersFfi._() {
    try {
      _lib = _openLibrary();
      _applyAntialias = _lib.lookupFunction<
          _CpuFiltersApplyAntialiasNative,
          _CpuFiltersApplyAntialiasDart>('cpu_filters_apply_antialias');
      isSupported = true;
    } catch (_) {
      isSupported = false;
    }
  }

  static final CpuFiltersFfi instance = CpuFiltersFfi._();

  static ffi.DynamicLibrary _openLibrary() {
    if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('rust_lib_misa_rin.dll');
    }
    return ffi.DynamicLibrary.process();
  }

  late final ffi.DynamicLibrary _lib;
  late final _CpuFiltersApplyAntialiasDart _applyAntialias;

  late final bool isSupported;

  bool applyAntialias({
    required int pixelsPtr,
    required int pixelsLen,
    required int width,
    required int height,
    required int level,
    required bool previewOnly,
  }) {
    if (!isSupported || pixelsPtr == 0 || pixelsLen <= 0) {
      return false;
    }
    if (width <= 0 || height <= 0) {
      return false;
    }
    final int result = _applyAntialias(
      ffi.Pointer<ffi.Uint32>.fromAddress(pixelsPtr),
      pixelsLen,
      width,
      height,
      level,
      previewOnly ? 1 : 0,
    );
    return result != 0;
  }
}
