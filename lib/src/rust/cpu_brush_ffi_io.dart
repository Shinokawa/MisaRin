import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'rust_dylib.dart';

typedef _CpuBrushDrawStampNative =
    ffi.Uint8 Function(
      ffi.Pointer<ffi.Uint32> pixels,
      ffi.Uint64 pixelsLen,
      ffi.Uint32 width,
      ffi.Uint32 height,
      ffi.Float centerX,
      ffi.Float centerY,
      ffi.Float radius,
      ffi.Uint32 colorArgb,
      ffi.Uint32 brushShape,
      ffi.Uint32 antialiasLevel,
      ffi.Float softness,
      ffi.Uint8 erase,
      ffi.Uint8 randomRotation,
      ffi.Uint32 rotationSeed,
      ffi.Float rotationJitter,
      ffi.Uint8 snapToPixel,
      ffi.Pointer<ffi.Uint8> selection,
      ffi.Uint64 selectionLen,
    );

typedef _CpuBrushDrawStampDart =
    int Function(
      ffi.Pointer<ffi.Uint32> pixels,
      int pixelsLen,
      int width,
      int height,
      double centerX,
      double centerY,
      double radius,
      int colorArgb,
      int brushShape,
      int antialiasLevel,
      double softness,
      int erase,
      int randomRotation,
      int rotationSeed,
      double rotationJitter,
      int snapToPixel,
      ffi.Pointer<ffi.Uint8> selection,
      int selectionLen,
    );

typedef _CpuBrushDrawCapsuleNative =
    ffi.Uint8 Function(
      ffi.Pointer<ffi.Uint32> pixels,
      ffi.Uint64 pixelsLen,
      ffi.Uint32 width,
      ffi.Uint32 height,
      ffi.Float ax,
      ffi.Float ay,
      ffi.Float bx,
      ffi.Float by,
      ffi.Float startRadius,
      ffi.Float endRadius,
      ffi.Uint32 colorArgb,
      ffi.Uint32 antialiasLevel,
      ffi.Uint8 includeStartCap,
      ffi.Uint8 erase,
      ffi.Pointer<ffi.Uint8> selection,
      ffi.Uint64 selectionLen,
    );

typedef _CpuBrushDrawCapsuleDart =
    int Function(
      ffi.Pointer<ffi.Uint32> pixels,
      int pixelsLen,
      int width,
      int height,
      double ax,
      double ay,
      double bx,
      double by,
      double startRadius,
      double endRadius,
      int colorArgb,
      int antialiasLevel,
      int includeStartCap,
      int erase,
      ffi.Pointer<ffi.Uint8> selection,
      int selectionLen,
    );

typedef _CpuBrushFillPolygonNative =
    ffi.Uint8 Function(
      ffi.Pointer<ffi.Uint32> pixels,
      ffi.Uint64 pixelsLen,
      ffi.Uint32 width,
      ffi.Uint32 height,
      ffi.Pointer<ffi.Float> vertices,
      ffi.Uint64 verticesLen,
      ffi.Float radius,
      ffi.Uint32 colorArgb,
      ffi.Uint32 antialiasLevel,
      ffi.Float softness,
      ffi.Uint8 erase,
      ffi.Pointer<ffi.Uint8> selection,
      ffi.Uint64 selectionLen,
    );

typedef _CpuBrushFillPolygonDart =
    int Function(
      ffi.Pointer<ffi.Uint32> pixels,
      int pixelsLen,
      int width,
      int height,
      ffi.Pointer<ffi.Float> vertices,
      int verticesLen,
      double radius,
      int colorArgb,
      int antialiasLevel,
      double softness,
      int erase,
      ffi.Pointer<ffi.Uint8> selection,
      int selectionLen,
    );

class CpuBrushFfi {
  CpuBrushFfi._() {
    try {
      _lib = _openLibrary();
      _drawStamp = _lib
          .lookupFunction<_CpuBrushDrawStampNative, _CpuBrushDrawStampDart>(
            'cpu_brush_draw_stamp',
          );
      _drawCapsule = _lib
          .lookupFunction<_CpuBrushDrawCapsuleNative, _CpuBrushDrawCapsuleDart>(
            'cpu_brush_draw_capsule_segment',
          );
      _fillPolygon = _lib
          .lookupFunction<_CpuBrushFillPolygonNative, _CpuBrushFillPolygonDart>(
            'cpu_brush_fill_polygon',
          );
      isSupported = true;
    } catch (error, stackTrace) {
      isSupported = false;
      if (!_loggedInitFailure) {
        _loggedInitFailure = true;
        print('CpuBrushFfi init failed: $error');
        print('$stackTrace');
      }
    }
  }

  static final CpuBrushFfi instance = CpuBrushFfi._();
  static bool _loggedInitFailure = false;
  static bool _loggedUnsupported = false;
  static bool _loggedInvalidBuffer = false;
  static bool _loggedInvalidSize = false;
  static bool _loggedCallFailed = false;

  static ffi.DynamicLibrary _openLibrary() {
    return RustDynamicLibrary.open();
  }

  late final ffi.DynamicLibrary _lib;
  late final _CpuBrushDrawStampDart _drawStamp;
  late final _CpuBrushDrawCapsuleDart _drawCapsule;
  late final _CpuBrushFillPolygonDart _fillPolygon;

  late final bool isSupported;

  static bool _logOnce(bool alreadyLogged, String message) {
    if (!alreadyLogged) {
      print(message);
      return true;
    }
    return alreadyLogged;
  }

  bool drawStamp({
    required int pixelsPtr,
    required int pixelsLen,
    required int width,
    required int height,
    required double centerX,
    required double centerY,
    required double radius,
    required int colorArgb,
    required int brushShape,
    required int antialiasLevel,
    required double softness,
    required bool erase,
    required bool randomRotation,
    required int rotationSeed,
    required double rotationJitter,
    required bool snapToPixel,
    Uint8List? selectionMask,
  }) {
    if (!isSupported || pixelsPtr == 0 || pixelsLen <= 0) {
      if (!isSupported) {
        _loggedUnsupported = _logOnce(
          _loggedUnsupported,
          'CpuBrushFfi unsupported: missing cpu_brush symbols.',
        );
      } else {
        _loggedInvalidBuffer = _logOnce(
          _loggedInvalidBuffer,
          'CpuBrushFfi drawStamp skipped: invalid pixel buffer '
          '(ptr=$pixelsPtr, len=$pixelsLen).',
        );
      }
      return false;
    }
    if (width <= 0 || height <= 0) {
      _loggedInvalidSize = _logOnce(
        _loggedInvalidSize,
        'CpuBrushFfi drawStamp skipped: invalid size ${width}x${height}.',
      );
      return false;
    }

    ffi.Pointer<ffi.Uint8> selectionPtr = ffi.nullptr;
    int selectionLen = 0;
    if (selectionMask != null && selectionMask.isNotEmpty) {
      selectionLen = selectionMask.length;
      selectionPtr = malloc.allocate<ffi.Uint8>(selectionLen);
      selectionPtr.asTypedList(selectionLen).setAll(0, selectionMask);
    }

    try {
      final int result = _drawStamp(
        ffi.Pointer<ffi.Uint32>.fromAddress(pixelsPtr),
        pixelsLen,
        width,
        height,
        centerX,
        centerY,
        radius,
        colorArgb,
        brushShape,
        antialiasLevel,
        softness,
        erase ? 1 : 0,
        randomRotation ? 1 : 0,
        rotationSeed,
        rotationJitter,
        snapToPixel ? 1 : 0,
        selectionPtr,
        selectionLen,
      );
      if (result == 0) {
        _loggedCallFailed = _logOnce(
          _loggedCallFailed,
          'CpuBrushFfi drawStamp failed: native returned 0.',
        );
      }
      return result != 0;
    } finally {
      if (selectionPtr != ffi.nullptr) {
        malloc.free(selectionPtr);
      }
    }
  }

  bool drawCapsuleSegment({
    required int pixelsPtr,
    required int pixelsLen,
    required int width,
    required int height,
    required double ax,
    required double ay,
    required double bx,
    required double by,
    required double startRadius,
    required double endRadius,
    required int colorArgb,
    required int antialiasLevel,
    required bool includeStartCap,
    required bool erase,
    Uint8List? selectionMask,
  }) {
    if (!isSupported || pixelsPtr == 0 || pixelsLen <= 0) {
      if (!isSupported) {
        _loggedUnsupported = _logOnce(
          _loggedUnsupported,
          'CpuBrushFfi unsupported: missing cpu_brush symbols.',
        );
      } else {
        _loggedInvalidBuffer = _logOnce(
          _loggedInvalidBuffer,
          'CpuBrushFfi drawCapsuleSegment skipped: invalid pixel buffer '
          '(ptr=$pixelsPtr, len=$pixelsLen).',
        );
      }
      return false;
    }
    if (width <= 0 || height <= 0) {
      _loggedInvalidSize = _logOnce(
        _loggedInvalidSize,
        'CpuBrushFfi drawCapsuleSegment skipped: invalid size ${width}x${height}.',
      );
      return false;
    }

    ffi.Pointer<ffi.Uint8> selectionPtr = ffi.nullptr;
    int selectionLen = 0;
    if (selectionMask != null && selectionMask.isNotEmpty) {
      selectionLen = selectionMask.length;
      selectionPtr = malloc.allocate<ffi.Uint8>(selectionLen);
      selectionPtr.asTypedList(selectionLen).setAll(0, selectionMask);
    }

    try {
      final int result = _drawCapsule(
        ffi.Pointer<ffi.Uint32>.fromAddress(pixelsPtr),
        pixelsLen,
        width,
        height,
        ax,
        ay,
        bx,
        by,
        startRadius,
        endRadius,
        colorArgb,
        antialiasLevel,
        includeStartCap ? 1 : 0,
        erase ? 1 : 0,
        selectionPtr,
        selectionLen,
      );
      if (result == 0) {
        _loggedCallFailed = _logOnce(
          _loggedCallFailed,
          'CpuBrushFfi drawCapsuleSegment failed: native returned 0.',
        );
      }
      return result != 0;
    } finally {
      if (selectionPtr != ffi.nullptr) {
        malloc.free(selectionPtr);
      }
    }
  }

  bool fillPolygon({
    required int pixelsPtr,
    required int pixelsLen,
    required int width,
    required int height,
    required Float32List vertices,
    required double radius,
    required int colorArgb,
    required int antialiasLevel,
    required double softness,
    required bool erase,
    Uint8List? selectionMask,
  }) {
    if (!isSupported || pixelsPtr == 0 || pixelsLen <= 0) {
      if (!isSupported) {
        _loggedUnsupported = _logOnce(
          _loggedUnsupported,
          'CpuBrushFfi unsupported: missing cpu_brush symbols.',
        );
      } else {
        _loggedInvalidBuffer = _logOnce(
          _loggedInvalidBuffer,
          'CpuBrushFfi fillPolygon skipped: invalid pixel buffer '
          '(ptr=$pixelsPtr, len=$pixelsLen).',
        );
      }
      return false;
    }
    if (width <= 0 || height <= 0) {
      _loggedInvalidSize = _logOnce(
        _loggedInvalidSize,
        'CpuBrushFfi fillPolygon skipped: invalid size ${width}x${height}.',
      );
      return false;
    }
    if (vertices.length < 6) {
      return false;
    }

    final ffi.Pointer<ffi.Float> vertsPtr = malloc.allocate<ffi.Float>(
      vertices.length * ffi.sizeOf<ffi.Float>(),
    );
    vertsPtr.asTypedList(vertices.length).setAll(0, vertices);

    ffi.Pointer<ffi.Uint8> selectionPtr = ffi.nullptr;
    int selectionLen = 0;
    if (selectionMask != null && selectionMask.isNotEmpty) {
      selectionLen = selectionMask.length;
      selectionPtr = malloc.allocate<ffi.Uint8>(selectionLen);
      selectionPtr.asTypedList(selectionLen).setAll(0, selectionMask);
    }

    try {
      final int result = _fillPolygon(
        ffi.Pointer<ffi.Uint32>.fromAddress(pixelsPtr),
        pixelsLen,
        width,
        height,
        vertsPtr,
        vertices.length,
        radius,
        colorArgb,
        antialiasLevel,
        softness,
        erase ? 1 : 0,
        selectionPtr,
        selectionLen,
      );
      if (result == 0) {
        _loggedCallFailed = _logOnce(
          _loggedCallFailed,
          'CpuBrushFfi fillPolygon failed: native returned 0.',
        );
      }
      return result != 0;
    } finally {
      malloc.free(vertsPtr);
      if (selectionPtr != ffi.nullptr) {
        malloc.free(selectionPtr);
      }
    }
  }
}
