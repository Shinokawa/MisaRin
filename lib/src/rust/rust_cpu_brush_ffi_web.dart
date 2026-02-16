import 'dart:typed_data';

import 'api/cpu_brush.dart' as rust;
import 'cpu_buffer_registry.dart';

class RustCpuBrushFfi {
  RustCpuBrushFfi._();

  static final RustCpuBrushFfi instance = RustCpuBrushFfi._();

  static bool _loggedInvalidBuffer = false;
  static bool _loggedInvalidSize = false;
  static bool _loggedCallFailed = false;

  final bool isSupported = true;

  bool get supportsSpray => true;
  bool get supportsStreamline => true;

  static bool _logOnce(bool alreadyLogged, String message) {
    if (!alreadyLogged) {
      print(message);
      return true;
    }
    return alreadyLogged;
  }

  void _copyPixels(Uint32List target, Uint32List source) {
    if (source.length == target.length) {
      target.setAll(0, source);
      return;
    }
    if (source.isEmpty || target.isEmpty) {
      return;
    }
    final int count = source.length < target.length
        ? source.length
        : target.length;
    target.setAll(0, source.sublist(0, count));
  }

  Uint32List? _lookupPixels(int pixelsPtr, int pixelsLen) {
    if (pixelsPtr == 0 || pixelsLen <= 0) {
      _loggedInvalidBuffer = _logOnce(
        _loggedInvalidBuffer,
        'RustCpuBrushFfi (web) skipped: invalid pixel buffer '
        '(ptr=$pixelsPtr, len=$pixelsLen).',
      );
      return null;
    }
    final Uint32List? pixels = CpuBufferRegistry.lookup<Uint32List>(pixelsPtr);
    if (pixels == null || pixels.length < pixelsLen) {
      _loggedInvalidBuffer = _logOnce(
        _loggedInvalidBuffer,
        'RustCpuBrushFfi (web) skipped: pixel buffer not found '
        'or length mismatch (ptr=$pixelsPtr).',
      );
      return null;
    }
    return pixels;
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
    final Uint32List? pixels = _lookupPixels(pixelsPtr, pixelsLen);
    if (pixels == null) {
      return false;
    }
    if (width <= 0 || height <= 0) {
      _loggedInvalidSize = _logOnce(
        _loggedInvalidSize,
        'RustCpuBrushFfi (web) drawStamp skipped: invalid size ${width}x$height.',
      );
      return false;
    }
    final rust.CpuBrushResult result = rust.cpuBrushDrawStampRgba(
      pixels: pixels,
      width: width,
      height: height,
      centerX: centerX,
      centerY: centerY,
      radius: radius,
      colorArgb: colorArgb,
      brushShape: brushShape,
      antialiasLevel: antialiasLevel,
      softness: softness,
      erase: erase,
      randomRotation: randomRotation,
      rotationSeed: rotationSeed,
      rotationJitter: rotationJitter,
      snapToPixel: snapToPixel,
      selection: selectionMask,
    );
    if (!result.ok) {
      _loggedCallFailed = _logOnce(
        _loggedCallFailed,
        'RustCpuBrushFfi (web) drawStamp failed: native returned false.',
      );
      return false;
    }
    _copyPixels(pixels, result.pixels);
    return true;
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
    final Uint32List? pixels = _lookupPixels(pixelsPtr, pixelsLen);
    if (pixels == null) {
      return false;
    }
    if (width <= 0 || height <= 0) {
      _loggedInvalidSize = _logOnce(
        _loggedInvalidSize,
        'RustCpuBrushFfi (web) drawCapsuleSegment skipped: invalid size ${width}x$height.',
      );
      return false;
    }
    final rust.CpuBrushResult result = rust.cpuBrushDrawCapsuleSegmentRgba(
      pixels: pixels,
      width: width,
      height: height,
      ax: ax,
      ay: ay,
      bx: bx,
      by: by,
      startRadius: startRadius,
      endRadius: endRadius,
      colorArgb: colorArgb,
      antialiasLevel: antialiasLevel,
      includeStartCap: includeStartCap,
      erase: erase,
      selection: selectionMask,
    );
    if (!result.ok) {
      _loggedCallFailed = _logOnce(
        _loggedCallFailed,
        'RustCpuBrushFfi (web) drawCapsuleSegment failed: native returned false.',
      );
      return false;
    }
    _copyPixels(pixels, result.pixels);
    return true;
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
    final Uint32List? pixels = _lookupPixels(pixelsPtr, pixelsLen);
    if (pixels == null) {
      return false;
    }
    if (width <= 0 || height <= 0) {
      _loggedInvalidSize = _logOnce(
        _loggedInvalidSize,
        'RustCpuBrushFfi (web) fillPolygon skipped: invalid size ${width}x$height.',
      );
      return false;
    }
    if (vertices.length < 6) {
      return false;
    }
    final rust.CpuBrushResult result = rust.cpuBrushFillPolygonRgba(
      pixels: pixels,
      width: width,
      height: height,
      vertices: vertices,
      radius: radius,
      colorArgb: colorArgb,
      antialiasLevel: antialiasLevel,
      softness: softness,
      erase: erase,
      selection: selectionMask,
    );
    if (!result.ok) {
      _loggedCallFailed = _logOnce(
        _loggedCallFailed,
        'RustCpuBrushFfi (web) fillPolygon failed: native returned false.',
      );
      return false;
    }
    _copyPixels(pixels, result.pixels);
    return true;
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
    required int rotationSeed,
    required double rotationJitter,
    required double spacing,
    required double scatter,
    required double softness,
    required bool snapToPixel,
    required bool accumulate,
    Uint8List? selectionMask,
  }) {
    final Uint32List? pixels = _lookupPixels(pixelsPtr, pixelsLen);
    if (pixels == null) {
      return false;
    }
    if (width <= 0 || height <= 0) {
      _loggedInvalidSize = _logOnce(
        _loggedInvalidSize,
        'RustCpuBrushFfi (web) drawStampSegment skipped: invalid size ${width}x$height.',
      );
      return false;
    }
    final rust.CpuBrushResult result = rust.cpuBrushDrawStampSegmentRgba(
      pixels: pixels,
      width: width,
      height: height,
      startX: startX,
      startY: startY,
      endX: endX,
      endY: endY,
      startRadius: startRadius,
      endRadius: endRadius,
      colorArgb: colorArgb,
      brushShape: brushShape,
      antialiasLevel: antialiasLevel,
      includeStart: includeStart,
      erase: erase,
      randomRotation: randomRotation,
      rotationSeed: rotationSeed,
      rotationJitter: rotationJitter,
      spacing: spacing,
      scatter: scatter,
      softness: softness,
      snapToPixel: snapToPixel,
      accumulate: accumulate,
      selection: selectionMask,
    );
    if (!result.ok) {
      _loggedCallFailed = _logOnce(
        _loggedCallFailed,
        'RustCpuBrushFfi (web) drawStampSegment failed: native returned false.',
      );
      return false;
    }
    _copyPixels(pixels, result.pixels);
    return true;
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
    final Uint32List? pixels = _lookupPixels(pixelsPtr, pixelsLen);
    if (pixels == null) {
      return false;
    }
    if (width <= 0 || height <= 0) {
      _loggedInvalidSize = _logOnce(
        _loggedInvalidSize,
        'RustCpuBrushFfi (web) drawSpray skipped: invalid size ${width}x$height.',
      );
      return false;
    }
    if (pointCount <= 0 || points.isEmpty) {
      return false;
    }
    final int needed = pointCount * 4;
    if (points.length < needed) {
      return false;
    }
    final rust.CpuBrushResult result = rust.cpuBrushDrawSprayRgba(
      pixels: pixels,
      width: width,
      height: height,
      points: points,
      colorArgb: colorArgb,
      brushShape: brushShape,
      antialiasLevel: antialiasLevel,
      softness: softness,
      erase: erase,
      accumulate: accumulate,
      selection: selectionMask,
    );
    if (!result.ok) {
      _loggedCallFailed = _logOnce(
        _loggedCallFailed,
        'RustCpuBrushFfi (web) drawSpray failed: native returned false.',
      );
      return false;
    }
    _copyPixels(pixels, result.pixels);
    return true;
  }

  bool applyStreamline({
    required Float32List samples,
    required double strength,
  }) {
    if (samples.isEmpty) {
      return false;
    }
    final rust.CpuStreamlineResult result = rust.cpuBrushApplyStreamlineSamples(
      samples: samples,
      strength: strength,
    );
    if (!result.ok) {
      _loggedCallFailed = _logOnce(
        _loggedCallFailed,
        'RustCpuBrushFfi (web) applyStreamline failed: native returned false.',
      );
      return false;
    }
    if (result.samples.length == samples.length) {
      samples.setAll(0, result.samples);
    } else if (result.samples.isNotEmpty) {
      final int count = result.samples.length < samples.length
          ? result.samples.length
          : samples.length;
      samples.setAll(0, result.samples.sublist(0, count));
    }
    return true;
  }

  bool applyCommands({
    required Uint32List pixels,
    required int width,
    required int height,
    required List<rust.CpuBrushCommand> commands,
    Uint8List? selectionMask,
  }) {
    if (pixels.isEmpty || width <= 0 || height <= 0) {
      return false;
    }
    if (commands.isEmpty) {
      return true;
    }
    final rust.CpuBrushResult result = rust.cpuBrushApplyCommandsRgba(
      pixels: pixels,
      width: width,
      height: height,
      commands: commands,
      selection: selectionMask,
    );
    if (!result.ok) {
      _loggedCallFailed = _logOnce(
        _loggedCallFailed,
        'RustCpuBrushFfi (web) applyCommands failed: native returned false.',
      );
      return false;
    }
    _copyPixels(pixels, result.pixels);
    return true;
  }
}
