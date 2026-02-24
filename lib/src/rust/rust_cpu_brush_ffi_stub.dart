import 'dart:typed_data';

class RustCpuBrushFfi {
  RustCpuBrushFfi._();

  static final RustCpuBrushFfi instance = RustCpuBrushFfi._();

  static bool _loggedUnsupported = false;

  final bool isSupported = false;
  bool get supportsSpray => false;
  bool get supportsStreamline => false;

  static void _logUnsupportedOnce() {
    if (_loggedUnsupported) {
      return;
    }
    _loggedUnsupported = true;
    print(
      'RustCpuBrushFfi unsupported: dart:ffi not available (stub implementation).',
    );
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
    bool screentoneEnabled = false,
    double screentoneSpacing = 10.0,
    double screentoneDotSize = 0.6,
    double screentoneRotation = 45.0,
    double screentoneSoftness = 0.0,
    required bool snapToPixel,
    Uint8List? selectionMask,
  }) {
    _logUnsupportedOnce();
    return false;
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
    bool screentoneEnabled = false,
    double screentoneSpacing = 10.0,
    double screentoneDotSize = 0.6,
    double screentoneRotation = 45.0,
    double screentoneSoftness = 0.0,
    Uint8List? selectionMask,
  }) {
    _logUnsupportedOnce();
    return false;
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
    _logUnsupportedOnce();
    return false;
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
    bool screentoneEnabled = false,
    double screentoneSpacing = 10.0,
    double screentoneDotSize = 0.6,
    double screentoneRotation = 45.0,
    double screentoneSoftness = 0.0,
    required double spacing,
    required double scatter,
    required double softness,
    required bool snapToPixel,
    required bool accumulate,
    Uint8List? selectionMask,
  }) {
    _logUnsupportedOnce();
    return false;
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
    _logUnsupportedOnce();
    return false;
  }

  bool applyStreamline({
    required Float32List samples,
    required double strength,
  }) {
    _logUnsupportedOnce();
    return false;
  }
}
