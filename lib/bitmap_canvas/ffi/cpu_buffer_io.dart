import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

abstract class CpuBuffer<T extends TypedData> {
  T get list;
  int get address;
  void dispose();
}

class _CpuBufferUint32 implements CpuBuffer<Uint32List> {
  _CpuBufferUint32(this._ptr, this._list);

  final Pointer<Uint32> _ptr;
  final Uint32List _list;

  @override
  Uint32List get list => _list;

  @override
  int get address => _ptr.address;

  @override
  void dispose() {
    malloc.free(_ptr);
  }
}

class _CpuBufferInt32 implements CpuBuffer<Int32List> {
  _CpuBufferInt32(this._ptr, this._list);

  final Pointer<Int32> _ptr;
  final Int32List _list;

  @override
  Int32List get list => _list;

  @override
  int get address => _ptr.address;

  @override
  void dispose() {
    malloc.free(_ptr);
  }
}

class _CpuBufferUint64 implements CpuBuffer<Uint64List> {
  _CpuBufferUint64(this._ptr, this._list);

  final Pointer<Uint64> _ptr;
  final Uint64List _list;

  @override
  Uint64List get list => _list;

  @override
  int get address => _ptr.address;

  @override
  void dispose() {
    malloc.free(_ptr);
  }
}

CpuBuffer<Uint32List> allocateUint32(int length) {
  if (length <= 0) {
    return _CpuBufferUint32(Pointer<Uint32>.fromAddress(0), Uint32List(0));
  }
  final Pointer<Uint32> ptr = malloc.allocate<Uint32>(sizeOf<Uint32>() * length);
  final Uint32List list = ptr.asTypedList(length);
  return _CpuBufferUint32(ptr, list);
}

CpuBuffer<Int32List> allocateInt32(int length) {
  if (length <= 0) {
    return _CpuBufferInt32(Pointer<Int32>.fromAddress(0), Int32List(0));
  }
  final Pointer<Int32> ptr = malloc.allocate<Int32>(sizeOf<Int32>() * length);
  final Int32List list = ptr.asTypedList(length);
  return _CpuBufferInt32(ptr, list);
}

CpuBuffer<Uint64List> allocateUint64(int length) {
  if (length <= 0) {
    return _CpuBufferUint64(Pointer<Uint64>.fromAddress(0), Uint64List(0));
  }
  final Pointer<Uint64> ptr = malloc.allocate<Uint64>(sizeOf<Uint64>() * length);
  final Uint64List list = ptr.asTypedList(length);
  return _CpuBufferUint64(ptr, list);
}
