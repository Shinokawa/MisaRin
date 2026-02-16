import 'dart:typed_data';

import '../../src/rust/cpu_buffer_registry.dart';

class NativeMemoryManager {
  static PixelBufferHandle allocate(int size) {
    if (size <= 0) {
      throw ArgumentError.value(size, 'size', 'Must be positive');
    }
    final Uint32List pixels = Uint32List(size);
    final int address = CpuBufferRegistry.register(pixels);
    return PixelBufferHandle._(address: address, size: size, pixels: pixels);
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

  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (address != 0) {
      CpuBufferRegistry.unregister(address);
    }
  }
}
