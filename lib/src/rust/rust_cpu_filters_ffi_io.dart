import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'rust_dylib.dart';

typedef _RustCpuFiltersApplyAntialiasNative =
    ffi.Uint8 Function(
      ffi.Pointer<ffi.Uint32> pixels,
      ffi.Uint64 pixelsLen,
      ffi.Uint32 width,
      ffi.Uint32 height,
      ffi.Uint32 level,
      ffi.Uint8 previewOnly,
    );

typedef _RustCpuFiltersApplyAntialiasDart =
    int Function(
      ffi.Pointer<ffi.Uint32> pixels,
      int pixelsLen,
      int width,
      int height,
      int level,
      int previewOnly,
    );

typedef _RustCpuFiltersApplyFilterRgbaNative =
    ffi.Uint8 Function(
      ffi.Pointer<ffi.Uint8> pixels,
      ffi.Uint64 pixelsLen,
      ffi.Uint32 width,
      ffi.Uint32 height,
      ffi.Uint32 filterType,
      ffi.Float param0,
      ffi.Float param1,
      ffi.Float param2,
      ffi.Float param3,
    );

typedef _RustCpuFiltersApplyFilterRgbaDart =
    int Function(
      ffi.Pointer<ffi.Uint8> pixels,
      int pixelsLen,
      int width,
      int height,
      int filterType,
      double param0,
      double param1,
      double param2,
      double param3,
    );

class RustCpuFiltersFfi {
  RustCpuFiltersFfi._() {
    try {
      _lib = _openLibrary();
      _applyAntialias = _lib
          .lookupFunction<
            _RustCpuFiltersApplyAntialiasNative,
            _RustCpuFiltersApplyAntialiasDart
          >('cpu_filters_apply_antialias');
      isSupported = true;
    } catch (_) {
      isSupported = false;
    }
    if (isSupported) {
      try {
        _applyFilterRgba = _lib
            .lookupFunction<
              _RustCpuFiltersApplyFilterRgbaNative,
              _RustCpuFiltersApplyFilterRgbaDart
            >('cpu_filters_apply_filter_rgba');
        supportsRgbaFilters = true;
      } catch (_) {
        supportsRgbaFilters = false;
      }
    } else {
      supportsRgbaFilters = false;
    }
  }

  static final RustCpuFiltersFfi instance = RustCpuFiltersFfi._();

  static ffi.DynamicLibrary _openLibrary() {
    return RustDynamicLibrary.open();
  }

  late final ffi.DynamicLibrary _lib;
  late final _RustCpuFiltersApplyAntialiasDart _applyAntialias;
  late final _RustCpuFiltersApplyFilterRgbaDart _applyFilterRgba;

  late final bool isSupported;
  late final bool supportsRgbaFilters;

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

  Uint8List? applyFilterRgbaBytes({
    required Uint8List pixels,
    required int width,
    required int height,
    required int filterType,
    double param0 = 0,
    double param1 = 0,
    double param2 = 0,
    double param3 = 0,
  }) {
    if (!supportsRgbaFilters) {
      return null;
    }
    if (pixels.isEmpty || width <= 0 || height <= 0) {
      return null;
    }
    final int expected = width * height * 4;
    if (expected != pixels.length) {
      return null;
    }
    final ffi.Pointer<ffi.Uint8> buffer = malloc.allocate<ffi.Uint8>(
      pixels.length,
    );
    final Uint8List native = buffer.asTypedList(pixels.length);
    native.setAll(0, pixels);
    final int result = _applyFilterRgba(
      buffer,
      pixels.length,
      width,
      height,
      filterType,
      param0,
      param1,
      param2,
      param3,
    );
    Uint8List? output;
    if (result != 0) {
      output = Uint8List.fromList(native);
    }
    malloc.free(buffer);
    return output;
  }
}
