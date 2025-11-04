import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// A lightweight bitmap surface that stores pixels in ARGB8888 format
/// and exposes basic drawing primitives for future integration.
class BitmapSurface {
  BitmapSurface({
    required this.width,
    required this.height,
    Color? fillColor,
  }) : pixels = Uint32List(width * height) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Surface dimensions must be positive');
    }
    if (fillColor != null) {
      fill(fillColor);
    }
  }

  final int width;
  final int height;
  final Uint32List pixels;

  /// Clears the entire surface with [color].
  void fill(Color color) {
    final int encoded = encodeColor(color);
    for (int i = 0; i < pixels.length; i++) {
      pixels[i] = encoded;
    }
  }

  /// Returns the color at the given integer pixel position.
  Color pixelAt(int x, int y) {
    if (!_inBounds(x, y)) {
      throw RangeError('Pixel coordinates out of bounds: ($x, $y)');
    }
    return decodeColor(pixels[y * width + x]);
  }

  /// Draws a filled circle centered at [center] with radius [radius].
  void drawCircle({
    required Offset center,
    required double radius,
    required Color color,
    Uint8List? mask,
  }) {
    if (radius <= 0) {
      return;
    }
    final int minX = math.max(0, (center.dx - radius - 1).floor());
    final int maxX = math.min(width - 1, (center.dx + radius + 1).ceil());
    final int minY = math.max(0, (center.dy - radius - 1).floor());
    final int maxY = math.min(height - 1, (center.dy + radius + 1).ceil());
    final double radiusSq = radius * radius;

    for (int y = minY; y <= maxY; y++) {
      final double dy = y + 0.5 - center.dy;
      for (int x = minX; x <= maxX; x++) {
        final double dx = x + 0.5 - center.dx;
        if (dx * dx + dy * dy <= radiusSq) {
          if (mask == null || mask[y * width + x] != 0) {
            blendPixel(x, y, color);
          }
        }
      }
    }
  }

  /// Draws a line between [a] and [b] with a circular brush of [radius].
  void drawLine({
    required Offset a,
    required Offset b,
    required double radius,
    required Color color,
    Uint8List? mask,
  }) {
    final double distance = (b - a).distance;
    if (distance == 0) {
      drawCircle(center: a, radius: radius, color: color);
      return;
    }
    final double spacing = math.max(0.5, radius * 0.25);
    final int steps = math.max(1, (distance / spacing).ceil());
    final double stepX = (b.dx - a.dx) / steps;
    final double stepY = (b.dy - a.dy) / steps;
    Offset current = a;
    for (int i = 0; i <= steps; i++) {
      drawCircle(center: current, radius: radius, color: color, mask: mask);
      current = current.translate(stepX, stepY);
    }
  }

  /// Draws a stroke made of consecutive [points].
  void drawStroke({
    required List<Offset> points,
    required double radius,
    required Color color,
    Uint8List? mask,
  }) {
    if (points.isEmpty) {
      return;
    }
    if (points.length == 1) {
      drawCircle(center: points.first, radius: radius, color: color);
      return;
    }
    for (int i = 0; i < points.length - 1; i++) {
      drawLine(
        a: points[i],
        b: points[i + 1],
        radius: radius,
        color: color,
        mask: mask,
      );
    }
  }

  /// Performs a flood fill starting at [start] with [color].
  /// When [targetColor] is provided it will be used as the expected
  /// original color; otherwise the pixel at [start] decides the target.
  /// If [contiguous] is false, the entire surface matching the target color
  /// will be filled.
  void floodFill({
    required Offset start,
    required Color color,
    Color? targetColor,
    bool contiguous = true,
    Uint8List? mask,
  }) {
    final int sx = start.dx.floor();
    final int sy = start.dy.floor();
    if (!_inBounds(sx, sy)) {
      return;
    }
    if (mask != null && mask[sy * width + sx] == 0) {
      return;
    }
    final int replacement = encodeColor(color);
    final int baseColor = targetColor != null
        ? encodeColor(targetColor)
        : pixels[sy * width + sx];
    if (replacement == baseColor) {
      return;
    }

    if (!contiguous) {
      for (int i = 0; i < pixels.length; i++) {
        if (pixels[i] == baseColor && (mask == null || mask[i] != 0)) {
          pixels[i] = replacement;
        }
      }
      return;
    }

    final Queue<math.Point<int>> queue = Queue<math.Point<int>>();
    queue.add(math.Point<int>(sx, sy));
    while (queue.isNotEmpty) {
      final math.Point<int> current = queue.removeFirst();
      final int x = current.x;
      final int y = current.y;
      if (!_inBounds(x, y)) {
        continue;
      }
      final int index = y * width + x;
      if (pixels[index] != baseColor) {
        continue;
      }
      if (mask != null && mask[index] == 0) {
        continue;
      }
      pixels[index] = replacement;

      queue.add(math.Point<int>(x + 1, y));
      queue.add(math.Point<int>(x - 1, y));
      queue.add(math.Point<int>(x, y + 1));
      queue.add(math.Point<int>(x, y - 1));
    }
  }

  bool _inBounds(int x, int y) => x >= 0 && x < width && y >= 0 && y < height;

  void blendPixel(int x, int y, Color color) {
    if (!_inBounds(x, y)) {
      return;
    }
    final int index = y * width + x;
    final int dst = pixels[index];
    final int src = encodeColor(color);

    final int srcA = (src >> 24) & 0xff;
    if (srcA == 0) {
      return;
    }
    final int srcR = (src >> 16) & 0xff;
    final int srcG = (src >> 8) & 0xff;
    final int srcB = src & 0xff;

    final int dstA = (dst >> 24) & 0xff;
    final int dstR = (dst >> 16) & 0xff;
    final int dstG = (dst >> 8) & 0xff;
    final int dstB = dst & 0xff;

    final double srcAlpha = srcA / 255.0;
    final double dstAlpha = dstA / 255.0;
    final double outAlpha = srcAlpha + dstAlpha * (1 - srcAlpha);

    int outA;
    int outR;
    int outG;
    int outB;
    if (outAlpha == 0) {
      outA = outR = outG = outB = 0;
    } else {
      outA = (outAlpha * 255.0).round().clamp(0, 255);
      outR = ((srcR * srcAlpha + dstR * dstAlpha * (1 - srcAlpha)) / outAlpha)
          .round()
          .clamp(0, 255);
      outG = ((srcG * srcAlpha + dstG * dstAlpha * (1 - srcAlpha)) / outAlpha)
          .round()
          .clamp(0, 255);
      outB = ((srcB * srcAlpha + dstB * dstAlpha * (1 - srcAlpha)) / outAlpha)
          .round()
          .clamp(0, 255);
    }

    pixels[index] = (outA << 24) | (outR << 16) | (outG << 8) | outB;
  }

  static int encodeColor(Color color) {
    return (color.alpha << 24) |
        (color.red << 16) |
        (color.green << 8) |
        color.blue;
  }

  static Color decodeColor(int value) {
    final int a = (value >> 24) & 0xff;
    final int r = (value >> 16) & 0xff;
    final int g = (value >> 8) & 0xff;
    final int b = value & 0xff;
    return Color.fromARGB(a, r, g, b);
  }
}

/// High-level helper that orchestrates bitmap painting actions.
class BitmapPainter {
  BitmapPainter(this.surface);

  final BitmapSurface surface;

  void drawStroke({
    required List<Offset> points,
    required double radius,
    required Color color,
  }) {
    surface.drawStroke(points: points, radius: radius, color: color);
  }

  void floodFill({
    required Offset start,
    required Color color,
    bool contiguous = true,
  }) {
    surface.floodFill(start: start, color: color, contiguous: contiguous);
  }
}

/// Lightweight bitmap layer container for future layer stacking.
class BitmapLayer {
  BitmapLayer({
    required this.surface,
    this.visible = true,
    this.name = '图层',
  });

  final BitmapSurface surface;
  bool visible;
  String name;
}

/// Simple document structure holding multiple bitmap layers.
class BitmapDocument {
  BitmapDocument({required List<BitmapLayer> layers})
      : layers = List<BitmapLayer>.from(layers);

  final List<BitmapLayer> layers;

  BitmapSurface composite() {
    if (layers.isEmpty) {
      throw StateError('No layers available to composite');
    }
    final BitmapSurface baseSurface = BitmapSurface(
      width: layers.first.surface.width,
      height: layers.first.surface.height,
    );
    for (final BitmapLayer layer in layers) {
      if (!layer.visible) {
        continue;
      }
      final Uint32List src = layer.surface.pixels;
      final Uint32List dst = baseSurface.pixels;
      for (int i = 0; i < dst.length; i++) {
        final int color = src[i];
        if ((color >> 24) == 0) {
          continue;
        }
        final int x = i % baseSurface.width;
        final int y = i ~/ baseSurface.width;
        baseSurface.blendPixel(x, y, BitmapSurface.decodeColor(color));
      }
    }
    return baseSurface;
  }
}
