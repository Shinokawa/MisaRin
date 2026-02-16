import 'dart:typed_data';

import 'api/cpu_filters.dart' as rust;
import 'cpu_buffer_registry.dart';

class RustCpuFiltersFfi {
  RustCpuFiltersFfi._();

  static final RustCpuFiltersFfi instance = RustCpuFiltersFfi._();

  bool get isSupported => true;
  bool get supportsRgbaFilters => true;

  Uint32List? _lookupPixels(int pixelsPtr, int pixelsLen) {
    if (pixelsPtr == 0 || pixelsLen <= 0) {
      return null;
    }
    final Uint32List? pixels = CpuBufferRegistry.lookup<Uint32List>(pixelsPtr);
    if (pixels == null || pixels.length < pixelsLen) {
      return null;
    }
    return pixels;
  }

  bool applyAntialias({
    required int pixelsPtr,
    required int pixelsLen,
    required int width,
    required int height,
    required int level,
    required bool previewOnly,
  }) {
    final Uint32List? pixels = _lookupPixels(pixelsPtr, pixelsLen);
    if (pixels == null) {
      return false;
    }
    if (width <= 0 || height <= 0) {
      return false;
    }
    final rust.CpuFiltersResult result = rust.cpuFiltersApplyAntialiasRgba(
      pixels: pixels,
      width: width,
      height: height,
      level: level,
      previewOnly: previewOnly,
    );
    if (!result.ok) {
      return false;
    }
    if (!previewOnly) {
      pixels.setAll(0, result.pixels);
    }
    return true;
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
    if (pixels.isEmpty || width <= 0 || height <= 0) {
      return null;
    }
    final int expected = width * height * 4;
    if (expected != pixels.length) {
      return null;
    }
    final rust.CpuFiltersBytesResult result = rust.cpuFiltersApplyFilterRgbaBytes(
      pixels: pixels,
      width: width,
      height: height,
      filterType: filterType,
      param0: param0,
      param1: param1,
      param2: param2,
      param3: param3,
    );
    if (!result.ok) {
      return null;
    }
    return Uint8List.fromList(result.pixels);
  }
}
