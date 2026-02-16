import 'dart:typed_data';

abstract class CpuBuffer<T extends TypedData> {
  T get list;
  int get address;
  void dispose();
}

class _EmptyCpuBuffer<T extends TypedData> implements CpuBuffer<T> {
  _EmptyCpuBuffer(this._list);

  final T _list;

  @override
  T get list => _list;

  @override
  int get address => 0;

  @override
  void dispose() {}
}

int _safeLength(int length) => length <= 0 ? 0 : length;

CpuBuffer<Uint32List> allocateUint32(int length) =>
    _EmptyCpuBuffer<Uint32List>(Uint32List(_safeLength(length)));

CpuBuffer<Int32List> allocateInt32(int length) =>
    _EmptyCpuBuffer<Int32List>(Int32List(_safeLength(length)));

CpuBuffer<Uint64List> allocateUint64(int length) =>
    _EmptyCpuBuffer<Uint64List>(Uint64List(_safeLength(length)));
