import 'dart:typed_data';

class NativeMemoryManager {
  static PixelBufferHandle allocate(int size) {
    if (size <= 0) {
      throw ArgumentError.value(size, 'size', 'Must be positive');
    }
    return PixelBufferHandle._(
      address: 0,
      size: size,
      pixels: Uint32List(size),
    );
  }
}

class PixelBufferHandle {
  PixelBufferHandle._({
    required this.address,
    required this.size,
    required this.pixels,
  });

  final int address;
  final int size;
  final Uint32List pixels;

  void dispose() {}
}
