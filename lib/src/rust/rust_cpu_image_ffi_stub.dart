import 'dart:typed_data';

class RustCpuImageFfi {
  RustCpuImageFfi._();

  static final RustCpuImageFfi instance = RustCpuImageFfi._();

  bool get isSupported => false;

  Int32List? computeBounds({
    required int pixelsPtr,
    required int pixelsLen,
    required int width,
    required int height,
  }) {
    return null;
  }
}
