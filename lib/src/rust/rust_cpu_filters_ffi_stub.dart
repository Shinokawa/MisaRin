import 'dart:typed_data';

class RustCpuFiltersFfi {
  RustCpuFiltersFfi._();

  static final RustCpuFiltersFfi instance = RustCpuFiltersFfi._();

  bool get isSupported => false;
  bool get supportsRgbaFilters => false;

  bool applyAntialias({
    required int pixelsPtr,
    required int pixelsLen,
    required int width,
    required int height,
    required int level,
    required bool previewOnly,
  }) {
    return false;
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
    return null;
  }
}
