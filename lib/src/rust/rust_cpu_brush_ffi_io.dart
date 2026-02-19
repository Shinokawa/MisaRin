import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'api/cpu_brush.dart' as rust;
import 'rust_dylib.dart';

typedef _RustCpuBrushDrawStampNative =
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
      ffi.Uint8 smoothRotation,
      ffi.Uint32 rotationSeed,
      ffi.Float rotationJitter,
      ffi.Uint8 snapToPixel,
      ffi.Pointer<ffi.Uint8> selection,
      ffi.Uint64 selectionLen,
    );

typedef _RustCpuBrushDrawStampDart =
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
      int smoothRotation,
      int rotationSeed,
      double rotationJitter,
      int snapToPixel,
      ffi.Pointer<ffi.Uint8> selection,
      int selectionLen,
    );

typedef _RustCpuBrushDrawCapsuleNative =
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

typedef _RustCpuBrushDrawCapsuleDart =
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

typedef _RustCpuBrushFillPolygonNative =
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

typedef _RustCpuBrushFillPolygonDart =
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

typedef _RustCpuBrushDrawSprayNative =
    ffi.Uint8 Function(
      ffi.Pointer<ffi.Uint32> pixels,
      ffi.Uint64 pixelsLen,
      ffi.Uint32 width,
      ffi.Uint32 height,
      ffi.Pointer<ffi.Float> points,
      ffi.Uint64 pointsLen,
      ffi.Uint32 colorArgb,
      ffi.Uint32 brushShape,
      ffi.Uint32 antialiasLevel,
      ffi.Float softness,
      ffi.Uint8 erase,
      ffi.Uint8 accumulate,
      ffi.Pointer<ffi.Uint8> selection,
      ffi.Uint64 selectionLen,
    );

typedef _RustCpuBrushDrawSprayDart =
    int Function(
      ffi.Pointer<ffi.Uint32> pixels,
      int pixelsLen,
      int width,
      int height,
      ffi.Pointer<ffi.Float> points,
      int pointsLen,
      int colorArgb,
      int brushShape,
      int antialiasLevel,
      double softness,
      int erase,
      int accumulate,
      ffi.Pointer<ffi.Uint8> selection,
      int selectionLen,
    );

typedef _RustCpuBrushApplyStreamlineNative =
    ffi.Uint8 Function(
      ffi.Pointer<ffi.Float> samples,
      ffi.Uint64 samplesLen,
      ffi.Float strength,
    );

typedef _RustCpuBrushApplyStreamlineDart =
    int Function(
      ffi.Pointer<ffi.Float> samples,
      int samplesLen,
      double strength,
    );

typedef _RustCpuBrushDrawStampSegmentNative =
    ffi.Uint8 Function(
      ffi.Pointer<ffi.Uint32> pixels,
      ffi.Uint64 pixelsLen,
      ffi.Uint32 width,
      ffi.Uint32 height,
      ffi.Float startX,
      ffi.Float startY,
      ffi.Float endX,
      ffi.Float endY,
      ffi.Float startRadius,
      ffi.Float endRadius,
      ffi.Uint32 colorArgb,
      ffi.Uint32 brushShape,
      ffi.Uint32 antialiasLevel,
      ffi.Uint8 includeStart,
      ffi.Uint8 erase,
      ffi.Uint8 randomRotation,
      ffi.Uint8 smoothRotation,
      ffi.Uint32 rotationSeed,
      ffi.Float rotationJitter,
      ffi.Float spacing,
      ffi.Float scatter,
      ffi.Float softness,
      ffi.Uint8 snapToPixel,
      ffi.Uint8 accumulate,
      ffi.Pointer<ffi.Uint8> selection,
      ffi.Uint64 selectionLen,
    );

typedef _RustCpuBrushDrawStampSegmentDart =
    int Function(
      ffi.Pointer<ffi.Uint32> pixels,
      int pixelsLen,
      int width,
      int height,
      double startX,
      double startY,
      double endX,
      double endY,
      double startRadius,
      double endRadius,
      int colorArgb,
      int brushShape,
      int antialiasLevel,
      int includeStart,
      int erase,
      int randomRotation,
      int smoothRotation,
      int rotationSeed,
      double rotationJitter,
      double spacing,
      double scatter,
      double softness,
      int snapToPixel,
      int accumulate,
      ffi.Pointer<ffi.Uint8> selection,
      int selectionLen,
    );

class RustCpuBrushFfi {
  RustCpuBrushFfi._() {
    try {
      _lib = _openLibrary();
      _drawStamp = _lib
          .lookupFunction<
            _RustCpuBrushDrawStampNative,
            _RustCpuBrushDrawStampDart
          >('cpu_brush_draw_stamp');
      _drawCapsule = _lib
          .lookupFunction<
            _RustCpuBrushDrawCapsuleNative,
            _RustCpuBrushDrawCapsuleDart
          >('cpu_brush_draw_capsule_segment');
      _fillPolygon = _lib
          .lookupFunction<
            _RustCpuBrushFillPolygonNative,
            _RustCpuBrushFillPolygonDart
          >('cpu_brush_fill_polygon');
      try {
        _drawSpray = _lib
            .lookupFunction<
              _RustCpuBrushDrawSprayNative,
              _RustCpuBrushDrawSprayDart
            >('cpu_brush_draw_spray');
      } catch (_) {
        _drawSpray = null;
      }
      try {
        _applyStreamline = _lib
            .lookupFunction<
              _RustCpuBrushApplyStreamlineNative,
              _RustCpuBrushApplyStreamlineDart
            >('cpu_brush_apply_streamline');
      } catch (_) {
        _applyStreamline = null;
      }
      try {
        _drawStampSegment = _lib
            .lookupFunction<
              _RustCpuBrushDrawStampSegmentNative,
              _RustCpuBrushDrawStampSegmentDart
            >('cpu_brush_draw_stamp_segment');
      } catch (_) {
        _drawStampSegment = null;
      }
      isSupported = true;
    } catch (error, stackTrace) {
      isSupported = false;
      if (!_loggedInitFailure) {
        _loggedInitFailure = true;
        print('RustCpuBrushFfi init failed: $error');
        print('$stackTrace');
      }
    }
  }

  static final RustCpuBrushFfi instance = RustCpuBrushFfi._();
  static bool _loggedInitFailure = false;
  static bool _loggedUnsupported = false;
  static bool _loggedInvalidBuffer = false;
  static bool _loggedInvalidSize = false;
  static bool _loggedCallFailed = false;

  static ffi.DynamicLibrary _openLibrary() {
    return RustDynamicLibrary.open();
  }

  late final ffi.DynamicLibrary _lib;
  late final _RustCpuBrushDrawStampDart _drawStamp;
  late final _RustCpuBrushDrawCapsuleDart _drawCapsule;
  late final _RustCpuBrushFillPolygonDart _fillPolygon;
  late final _RustCpuBrushDrawSprayDart? _drawSpray;
  late final _RustCpuBrushApplyStreamlineDart? _applyStreamline;
  late final _RustCpuBrushDrawStampSegmentDart? _drawStampSegment;

  late final bool isSupported;

  bool get supportsSpray => isSupported && _drawSpray != null;
  bool get supportsStreamline => isSupported && _applyStreamline != null;

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
    required bool smoothRotation,
    required int rotationSeed,
    required double rotationJitter,
    required bool snapToPixel,
    Uint8List? selectionMask,
  }) {
    if (!isSupported || pixelsPtr == 0 || pixelsLen <= 0) {
      if (!isSupported) {
        _loggedUnsupported = _logOnce(
          _loggedUnsupported,
          'RustCpuBrushFfi unsupported: missing cpu_brush symbols.',
        );
      } else {
        _loggedInvalidBuffer = _logOnce(
          _loggedInvalidBuffer,
          'RustCpuBrushFfi drawStamp skipped: invalid pixel buffer '
          '(ptr=$pixelsPtr, len=$pixelsLen).',
        );
      }
      return false;
    }
    if (width <= 0 || height <= 0) {
      _loggedInvalidSize = _logOnce(
        _loggedInvalidSize,
        'RustCpuBrushFfi drawStamp skipped: invalid size ${width}x$height.',
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
        smoothRotation ? 1 : 0,
        rotationSeed,
        rotationJitter,
        snapToPixel ? 1 : 0,
        selectionPtr,
        selectionLen,
      );
      if (result == 0) {
        _loggedCallFailed = _logOnce(
          _loggedCallFailed,
          'RustCpuBrushFfi drawStamp failed: native returned 0.',
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
          'RustCpuBrushFfi unsupported: missing cpu_brush symbols.',
        );
      } else {
        _loggedInvalidBuffer = _logOnce(
          _loggedInvalidBuffer,
          'RustCpuBrushFfi drawCapsuleSegment skipped: invalid pixel buffer '
          '(ptr=$pixelsPtr, len=$pixelsLen).',
        );
      }
      return false;
    }
    if (width <= 0 || height <= 0) {
      _loggedInvalidSize = _logOnce(
        _loggedInvalidSize,
        'RustCpuBrushFfi drawCapsuleSegment skipped: invalid size ${width}x$height.',
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
          'RustCpuBrushFfi drawCapsuleSegment failed: native returned 0.',
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
          'RustCpuBrushFfi unsupported: missing cpu_brush symbols.',
        );
      } else {
        _loggedInvalidBuffer = _logOnce(
          _loggedInvalidBuffer,
          'RustCpuBrushFfi fillPolygon skipped: invalid pixel buffer '
          '(ptr=$pixelsPtr, len=$pixelsLen).',
        );
      }
      return false;
    }
    if (width <= 0 || height <= 0) {
      _loggedInvalidSize = _logOnce(
        _loggedInvalidSize,
        'RustCpuBrushFfi fillPolygon skipped: invalid size ${width}x$height.',
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
          'RustCpuBrushFfi fillPolygon failed: native returned 0.',
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

  bool drawStampSegment({
    required int pixelsPtr,
    required int pixelsLen,
    required int width,
    required int height,
    required double startX,
    required double startY,
    required double endX,
    required double endY,
    required double startRadius,
    required double endRadius,
    required int colorArgb,
    required int brushShape,
    required int antialiasLevel,
    required bool includeStart,
    required bool erase,
    required bool randomRotation,
    required bool smoothRotation,
    required int rotationSeed,
    required double rotationJitter,
    required double spacing,
    required double scatter,
    required double softness,
    required bool snapToPixel,
    required bool accumulate,
    Uint8List? selectionMask,
  }) {
    final _RustCpuBrushDrawStampSegmentDart? fn = _drawStampSegment;
    if (!isSupported || fn == null || pixelsPtr == 0 || pixelsLen <= 0) {
      if (!isSupported || fn == null) {
        _loggedUnsupported = _logOnce(
          _loggedUnsupported,
          'RustCpuBrushFfi unsupported: missing cpu_brush_draw_stamp_segment symbol.',
        );
      } else {
        _loggedInvalidBuffer = _logOnce(
          _loggedInvalidBuffer,
          'RustCpuBrushFfi drawStampSegment skipped: invalid pixel buffer '
          '(ptr=$pixelsPtr, len=$pixelsLen).',
        );
      }
      return false;
    }
    if (width <= 0 || height <= 0) {
      _loggedInvalidSize = _logOnce(
        _loggedInvalidSize,
        'RustCpuBrushFfi drawStampSegment skipped: invalid size ${width}x$height.',
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
      final int result = fn(
        ffi.Pointer<ffi.Uint32>.fromAddress(pixelsPtr),
        pixelsLen,
        width,
        height,
        startX,
        startY,
        endX,
        endY,
        startRadius,
        endRadius,
        colorArgb,
        brushShape,
        antialiasLevel,
        includeStart ? 1 : 0,
        erase ? 1 : 0,
        randomRotation ? 1 : 0,
        smoothRotation ? 1 : 0,
        rotationSeed,
        rotationJitter,
        spacing,
        scatter,
        softness,
        snapToPixel ? 1 : 0,
        accumulate ? 1 : 0,
        selectionPtr,
        selectionLen,
      );
      if (result == 0) {
        _loggedCallFailed = _logOnce(
          _loggedCallFailed,
          'RustCpuBrushFfi drawStampSegment failed: native returned 0.',
        );
        return false;
      }
      return true;
    } finally {
      if (selectionPtr != ffi.nullptr) {
        malloc.free(selectionPtr);
      }
    }
  }

  bool drawSpray({
    required int pixelsPtr,
    required int pixelsLen,
    required int width,
    required int height,
    required Float32List points,
    required int pointCount,
    required int colorArgb,
    required int brushShape,
    required int antialiasLevel,
    required double softness,
    required bool erase,
    required bool accumulate,
    Uint8List? selectionMask,
  }) {
    final _RustCpuBrushDrawSprayDart? fn = _drawSpray;
    if (!isSupported || fn == null || pixelsPtr == 0 || pixelsLen <= 0) {
      if (!isSupported || fn == null) {
        _loggedUnsupported = _logOnce(
          _loggedUnsupported,
          'RustCpuBrushFfi unsupported: missing cpu_brush_draw_spray symbol.',
        );
      } else {
        _loggedInvalidBuffer = _logOnce(
          _loggedInvalidBuffer,
          'RustCpuBrushFfi drawSpray skipped: invalid pixel buffer '
          '(ptr=$pixelsPtr, len=$pixelsLen).',
        );
      }
      return false;
    }
    if (width <= 0 || height <= 0) {
      _loggedInvalidSize = _logOnce(
        _loggedInvalidSize,
        'RustCpuBrushFfi drawSpray skipped: invalid size ${width}x$height.',
      );
      return false;
    }
    if (points.isEmpty || pointCount <= 0) {
      return false;
    }

    final int needed = pointCount * 4;
    if (points.length < needed) {
      _loggedInvalidBuffer = _logOnce(
        _loggedInvalidBuffer,
        'RustCpuBrushFfi drawSpray skipped: points length ${points.length} '
        'smaller than expected $needed.',
      );
      return false;
    }

    final ffi.Pointer<ffi.Float> pointsPtr = malloc.allocate<ffi.Float>(
      needed * ffi.sizeOf<ffi.Float>(),
    );
    pointsPtr.asTypedList(needed).setAll(0, points.sublist(0, needed));

    ffi.Pointer<ffi.Uint8> selectionPtr = ffi.nullptr;
    int selectionLen = 0;
    if (selectionMask != null && selectionMask.isNotEmpty) {
      selectionLen = selectionMask.length;
      selectionPtr = malloc.allocate<ffi.Uint8>(selectionLen);
      selectionPtr.asTypedList(selectionLen).setAll(0, selectionMask);
    }

    try {
      final int result = fn(
        ffi.Pointer<ffi.Uint32>.fromAddress(pixelsPtr),
        pixelsLen,
        width,
        height,
        pointsPtr,
        needed,
        colorArgb,
        brushShape,
        antialiasLevel,
        softness,
        erase ? 1 : 0,
        accumulate ? 1 : 0,
        selectionPtr,
        selectionLen,
      );
      if (result == 0) {
        _loggedCallFailed = _logOnce(
          _loggedCallFailed,
          'RustCpuBrushFfi drawSpray failed: native returned 0.',
        );
        return false;
      }
      return true;
    } finally {
      malloc.free(pointsPtr);
      if (selectionPtr != ffi.nullptr) {
        malloc.free(selectionPtr);
      }
    }
  }

  bool applyStreamline({
    required Float32List samples,
    required double strength,
  }) {
    final _RustCpuBrushApplyStreamlineDart? fn = _applyStreamline;
    if (!isSupported || fn == null) {
      if (!isSupported || fn == null) {
        _loggedUnsupported = _logOnce(
          _loggedUnsupported,
          'RustCpuBrushFfi unsupported: missing cpu_brush_apply_streamline symbol.',
        );
      }
      return false;
    }
    if (samples.length < 6 || samples.length % 3 != 0) {
      return false;
    }

    final int len = samples.length;
    final ffi.Pointer<ffi.Float> samplesPtr = malloc.allocate<ffi.Float>(
      len * ffi.sizeOf<ffi.Float>(),
    );
    samplesPtr.asTypedList(len).setAll(0, samples);

    try {
      final int result = fn(samplesPtr, len, strength);
      if (result == 0) {
        _loggedCallFailed = _logOnce(
          _loggedCallFailed,
          'RustCpuBrushFfi applyStreamline failed: native returned 0.',
        );
        return false;
      }
      samples.setAll(0, samplesPtr.asTypedList(len));
      return true;
    } finally {
      malloc.free(samplesPtr);
    }
  }

  bool applyCommands({
    required Uint32List pixels,
    required int width,
    required int height,
    required List<rust.CpuBrushCommand> commands,
    Uint8List? selectionMask,
  }) {
    return false;
  }
}
