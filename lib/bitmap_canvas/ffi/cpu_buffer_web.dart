import 'dart:typed_data';

import '../../src/rust/cpu_buffer_registry.dart';

abstract class CpuBuffer<T extends TypedData> {
  T get list;
  int get address;
  void dispose();
}

class _CpuBufferUint32 implements CpuBuffer<Uint32List> {
  _CpuBufferUint32(this._list, this._address);

  final Uint32List _list;
  final int _address;
  bool _disposed = false;

  @override
  Uint32List get list => _list;

  @override
  int get address => _address;

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    if (_address != 0) {
      CpuBufferRegistry.unregister(_address);
    }
  }
}

class _CpuBufferInt32 implements CpuBuffer<Int32List> {
  _CpuBufferInt32(this._list, this._address);

  final Int32List _list;
  final int _address;
  bool _disposed = false;

  @override
  Int32List get list => _list;

  @override
  int get address => _address;

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    if (_address != 0) {
      CpuBufferRegistry.unregister(_address);
    }
  }
}

class _CpuBufferUint64 implements CpuBuffer<Uint64List> {
  _CpuBufferUint64(this._list, this._address);

  final Uint64List _list;
  final int _address;
  bool _disposed = false;

  @override
  Uint64List get list => _list;

  @override
  int get address => _address;

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    if (_address != 0) {
      CpuBufferRegistry.unregister(_address);
    }
  }
}

CpuBuffer<Uint32List> allocateUint32(int length) {
  if (length <= 0) {
    return _CpuBufferUint32(Uint32List(0), 0);
  }
  final Uint32List list = Uint32List(length);
  final int address = CpuBufferRegistry.register(list);
  return _CpuBufferUint32(list, address);
}

CpuBuffer<Int32List> allocateInt32(int length) {
  if (length <= 0) {
    return _CpuBufferInt32(Int32List(0), 0);
  }
  final Int32List list = Int32List(length);
  final int address = CpuBufferRegistry.register(list);
  return _CpuBufferInt32(list, address);
}

CpuBuffer<Uint64List> allocateUint64(int length) {
  if (length <= 0) {
    return _CpuBufferUint64(Uint64List(0), 0);
  }
  final Uint64List list = Uint64List(length);
  final int address = CpuBufferRegistry.register(list);
  return _CpuBufferUint64(list, address);
}
