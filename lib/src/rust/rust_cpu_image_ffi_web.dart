import 'dart:typed_data';

import 'api/cpu_image.dart' as rust;
import 'cpu_buffer_registry.dart';

class RustCpuImageFfi {
  RustCpuImageFfi._();

  static final RustCpuImageFfi instance = RustCpuImageFfi._();

  bool get isSupported => true;

  Int32List? computeBounds({
    required int pixelsPtr,
    required int pixelsLen,
    required int width,
    required int height,
  }) {
    if (pixelsPtr == 0 || pixelsLen <= 0) {
      return null;
    }
    final Uint32List? pixels = CpuBufferRegistry.lookup<Uint32List>(pixelsPtr);
    if (pixels == null || pixels.length < pixelsLen) {
      return null;
    }
    if (width <= 0 || height <= 0) {
      return null;
    }
    final rust.CpuImageBoundsResult result = rust.cpuImageBoundsRgba(
      pixels: pixels,
      width: width,
      height: height,
    );
    if (!result.ok || result.bounds.length < 4) {
      return null;
    }
    return Int32List.fromList(result.bounds.sublist(0, 4));
  }
}
