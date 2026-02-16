import 'dart:typed_data';

class CpuBufferRegistry {
  static int _nextId = 1;
  static final Map<int, TypedData> _buffers = <int, TypedData>{};

  static int register(TypedData buffer) {
    final int id = _nextId++;
    _buffers[id] = buffer;
    return id;
  }

  static T? lookup<T extends TypedData>(int id) {
    final TypedData? buffer = _buffers[id];
    if (buffer is T) {
      return buffer;
    }
    return null;
  }

  static void unregister(int id) {
    _buffers.remove(id);
  }
}
