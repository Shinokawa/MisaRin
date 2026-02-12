import 'dart:typed_data';

class CpuImageFfi {
  CpuImageFfi._();

  static final CpuImageFfi instance = CpuImageFfi._();

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
