import 'dart:typed_data';

/// Pre-rasterized brush shape mask.
///
/// [alpha] and [softAlpha] store coverage values in 0..255.
class BrushShapeRaster {
  BrushShapeRaster({
    required this.id,
    required this.width,
    required this.height,
    required Uint8List alpha,
    required Uint8List softAlpha,
  })  : alpha = Uint8List.fromList(alpha),
        softAlpha = Uint8List.fromList(softAlpha);

  final String id;
  final int width;
  final int height;
  final Uint8List alpha;
  final Uint8List softAlpha;
}
