import 'dart:typed_data';

class CpuBrushFfi {
  CpuBrushFfi._();

  static final CpuBrushFfi instance = CpuBrushFfi._();

  final bool isSupported = false;

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
    Uint8List? selectionMask,
  }) {
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
    return false;
  }
}
