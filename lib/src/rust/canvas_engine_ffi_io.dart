import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

const int _kPointStrideBytes = 32;

final class _EnginePointNative extends ffi.Struct {
  @ffi.Float()
  external double x;

  @ffi.Float()
  external double y;

  @ffi.Float()
  external double pressure;

  @ffi.Float()
  // ignore: unused_field
  external double _pad0;

  @ffi.Uint64()
  external int timestampUs;

  @ffi.Uint32()
  external int flags;

  @ffi.Uint32()
  external int pointerId;
}

typedef _EnginePushPointsNative =
    ffi.Void Function(
      ffi.Uint64 handle,
      ffi.Pointer<_EnginePointNative> points,
      ffi.UintPtr len,
    );
typedef _EnginePushPointsDart =
    void Function(int handle, ffi.Pointer<_EnginePointNative> points, int len);

typedef _EngineGetInputQueueLenNative = ffi.Uint64 Function(ffi.Uint64 handle);
typedef _EngineGetInputQueueLenDart = int Function(int handle);

typedef _EngineSetActiveLayerNative =
    ffi.Void Function(ffi.Uint64 handle, ffi.Uint32 layerIndex);
typedef _EngineSetActiveLayerDart = void Function(int handle, int layerIndex);

typedef _EngineSetLayerOpacityNative =
    ffi.Void Function(ffi.Uint64 handle, ffi.Uint32 layerIndex, ffi.Float opacity);
typedef _EngineSetLayerOpacityDart =
    void Function(int handle, int layerIndex, double opacity);

typedef _EngineSetLayerVisibleNative =
    ffi.Void Function(ffi.Uint64 handle, ffi.Uint32 layerIndex, ffi.Uint8 visible);
typedef _EngineSetLayerVisibleDart =
    void Function(int handle, int layerIndex, int visible);

typedef _EngineClearLayerNative =
    ffi.Void Function(ffi.Uint64 handle, ffi.Uint32 layerIndex);
typedef _EngineClearLayerDart = void Function(int handle, int layerIndex);

typedef _EngineUndoNative = ffi.Void Function(ffi.Uint64 handle);
typedef _EngineUndoDart = void Function(int handle);

typedef _EngineRedoNative = ffi.Void Function(ffi.Uint64 handle);
typedef _EngineRedoDart = void Function(int handle);

typedef _EngineSetBrushNative =
    ffi.Void Function(
      ffi.Uint64 handle,
      ffi.Uint32 colorArgb,
      ffi.Float baseRadius,
      ffi.Uint8 usePressure,
      ffi.Uint8 erase,
      ffi.Uint32 antialiasLevel,
    );
typedef _EngineSetBrushDart =
    void Function(
      int handle,
      int colorArgb,
      double baseRadius,
      int usePressure,
      int erase,
      int antialiasLevel,
    );

class CanvasEngineFfi {
  CanvasEngineFfi._() {
    try {
      _lib = ffi.DynamicLibrary.process();
      _pushPoints = _lib.lookupFunction<_EnginePushPointsNative, _EnginePushPointsDart>(
        'engine_push_points',
      );
      _getQueueLen = _lib.lookupFunction<_EngineGetInputQueueLenNative, _EngineGetInputQueueLenDart>(
        'engine_get_input_queue_len',
      );

      // Optional layer controls (not required for basic drawing).
      try {
        _setActiveLayer = _lib.lookupFunction<_EngineSetActiveLayerNative, _EngineSetActiveLayerDart>(
          'engine_set_active_layer',
        );
      } catch (_) {
        _setActiveLayer = null;
      }
      try {
        _setLayerOpacity =
            _lib.lookupFunction<_EngineSetLayerOpacityNative, _EngineSetLayerOpacityDart>(
          'engine_set_layer_opacity',
        );
      } catch (_) {
        _setLayerOpacity = null;
      }
      try {
        _setLayerVisible =
            _lib.lookupFunction<_EngineSetLayerVisibleNative, _EngineSetLayerVisibleDart>(
          'engine_set_layer_visible',
        );
      } catch (_) {
        _setLayerVisible = null;
      }
      try {
        _clearLayer = _lib.lookupFunction<_EngineClearLayerNative, _EngineClearLayerDart>(
          'engine_clear_layer',
        );
      } catch (_) {
        _clearLayer = null;
      }

      // Optional undo/redo (Flow 7).
      try {
        _undo = _lib.lookupFunction<_EngineUndoNative, _EngineUndoDart>('engine_undo');
      } catch (_) {
        _undo = null;
      }
      try {
        _redo = _lib.lookupFunction<_EngineRedoNative, _EngineRedoDart>('engine_redo');
      } catch (_) {
        _redo = null;
      }

      // Optional brush settings (color/size/etc).
      try {
        _setBrush = _lib.lookupFunction<_EngineSetBrushNative, _EngineSetBrushDart>(
          'engine_set_brush',
        );
      } catch (_) {
        _setBrush = null;
      }
      isSupported = true;
    } catch (_) {
      isSupported = false;
    }
  }

  static final CanvasEngineFfi instance = CanvasEngineFfi._();

  late final ffi.DynamicLibrary _lib;
  late final _EnginePushPointsDart _pushPoints;
  late final _EngineGetInputQueueLenDart _getQueueLen;
  late final _EngineSetActiveLayerDart? _setActiveLayer;
  late final _EngineSetLayerOpacityDart? _setLayerOpacity;
  late final _EngineSetLayerVisibleDart? _setLayerVisible;
  late final _EngineClearLayerDart? _clearLayer;
  late final _EngineUndoDart? _undo;
  late final _EngineRedoDart? _redo;
  late final _EngineSetBrushDart? _setBrush;

  ffi.Pointer<ffi.Uint8>? _staging;
  int _stagingCapacityBytes = 0;

  late final bool isSupported;

  void pushPointsPacked({
    required int handle,
    required Uint8List bytes,
    required int pointCount,
  }) {
    if (!isSupported || handle == 0 || pointCount <= 0) {
      return;
    }
    final int requiredBytes = pointCount * _kPointStrideBytes;
    if (bytes.length < requiredBytes) {
      throw RangeError.range(bytes.length, requiredBytes, null, 'bytes.length');
    }

    final ffi.Pointer<ffi.Uint8> ptr = _ensureStaging(requiredBytes);
    ptr.asTypedList(requiredBytes).setRange(0, requiredBytes, bytes, 0);
    _pushPoints(handle, ptr.cast<_EnginePointNative>(), pointCount);
  }

  int getInputQueueLen(int handle) {
    if (!isSupported || handle == 0) {
      return 0;
    }
    return _getQueueLen(handle);
  }

  void setActiveLayer({required int handle, required int layerIndex}) {
    final fn = _setActiveLayer;
    if (!isSupported || fn == null || handle == 0) {
      return;
    }
    fn(handle, layerIndex);
  }

  void setLayerOpacity({
    required int handle,
    required int layerIndex,
    required double opacity,
  }) {
    final fn = _setLayerOpacity;
    if (!isSupported || fn == null || handle == 0) {
      return;
    }
    fn(handle, layerIndex, opacity);
  }

  void setLayerVisible({
    required int handle,
    required int layerIndex,
    required bool visible,
  }) {
    final fn = _setLayerVisible;
    if (!isSupported || fn == null || handle == 0) {
      return;
    }
    fn(handle, layerIndex, visible ? 1 : 0);
  }

  void clearLayer({required int handle, required int layerIndex}) {
    final fn = _clearLayer;
    if (!isSupported || fn == null || handle == 0) {
      return;
    }
    fn(handle, layerIndex);
  }

  void undo({required int handle}) {
    final fn = _undo;
    if (!isSupported || fn == null || handle == 0) {
      return;
    }
    fn(handle);
  }

  void redo({required int handle}) {
    final fn = _redo;
    if (!isSupported || fn == null || handle == 0) {
      return;
    }
    fn(handle);
  }

  void setBrush({
    required int handle,
    required int colorArgb,
    required double baseRadius,
    bool usePressure = true,
    bool erase = false,
    int antialiasLevel = 1,
  }) {
    final fn = _setBrush;
    if (!isSupported || fn == null || handle == 0) {
      return;
    }
    double radius = baseRadius;
    if (!radius.isFinite) {
      radius = 0.0;
    }
    if (radius < 0.0) {
      radius = 0.0;
    }
    fn(
      handle,
      colorArgb,
      radius,
      usePressure ? 1 : 0,
      erase ? 1 : 0,
      antialiasLevel.clamp(0, 3),
    );
  }

  ffi.Pointer<ffi.Uint8> _ensureStaging(int requiredBytes) {
    final ffi.Pointer<ffi.Uint8>? existing = _staging;
    if (existing != null && _stagingCapacityBytes >= requiredBytes) {
      return existing;
    }
    if (existing != null) {
      malloc.free(existing);
      _staging = null;
      _stagingCapacityBytes = 0;
    }
    final ffi.Pointer<ffi.Uint8> next = malloc.allocate<ffi.Uint8>(requiredBytes);
    _staging = next;
    _stagingCapacityBytes = requiredBytes;
    return next;
  }
}
