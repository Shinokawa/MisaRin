import 'dart:typed_data';
import 'dart:math' as math;
import 'bitmap_canvas.dart';
import 'soft_brush_profile.dart';

/// Caches pre-computed alpha masks for soft circular brushes to avoid
/// expensive per-pixel coverage calculations (sqrt, pow) during painting.
class BrushTipCache {
  // Simple LRU-like cache or just a single slot for the current brush might be enough
  // since the user typically paints with one size/softness for a while.
  // Let's keep a small cache of recent tips.
  static final Map<String, BrushTip> _cache = <String, BrushTip>{};
  static const int _maxCacheSize = 5;

  static BrushTip getIfPresent(double radius, double softness) {
    final String key = _key(radius, softness);
    return _cache[key] ?? _generateAndCache(radius, softness);
  }
  
  static String _key(double radius, double softness) {
    // Round to manageable precision to increase hit rate
    return '${radius.toStringAsFixed(1)}_${softness.toStringAsFixed(2)}';
  }

  static BrushTip _generateAndCache(double radius, double softness) {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    
    final BrushTip tip = _generateTip(radius, softness);
    _cache[_key(radius, softness)] = tip;
    return tip;
  }

  static BrushTip _generateTip(double radius, double softness) {
    // Using the logic from BitmapSurface.drawCircle to determine extent
    final double softnessClamped = softness.clamp(0.0, 1.0);
    final double softnessRadius = softnessClamped > 0
        ? radius * softBrushExtentMultiplier(softnessClamped)
        : 0.0;
    final double extent = radius + softnessRadius + 1.5;
    final int size = (extent * 2).ceil();
    final int width = size;
    final int height = size;
    final Uint8List alpha = Uint8List(width * height);
    
    final double centerX = width / 2.0;
    final double centerY = height / 2.0;

    // Precompute constants
    final double innerRadius =
        radius * softBrushInnerRadiusFraction(softnessClamped);
    final double outerRadius =
        radius + radius * softBrushExtentMultiplier(softnessClamped);
    final double falloffExponent = softBrushFalloffExponent(softnessClamped);
    final double invRange = 1.0 / (outerRadius - innerRadius);

    for (int y = 0; y < height; y++) {
      final double dy = y + 0.5 - centerY;
      for (int x = 0; x < width; x++) {
        final double dx = x + 0.5 - centerX;
        final double distance = math.sqrt(dx * dx + dy * dy);
        
        double coverage = 0.0;
        
        if (distance <= innerRadius) {
          coverage = 1.0;
        } else if (distance >= outerRadius) {
          coverage = 0.0;
        } else {
          final double normalized = (distance - innerRadius) * invRange;
          // normalized is already clamped effectively by logic above
          final double eased = 1.0 - normalized.clamp(0.0, 1.0);
          coverage = math.pow(eased, falloffExponent).toDouble();
        }
        
        alpha[y * width + x] = (coverage * 255).round().clamp(0, 255);
      }
    }
    
    return BrushTip(width, height, alpha, extent);
  }
}

class BrushTip {
  BrushTip(this.width, this.height, this.alpha, this.extent);
  final int width;
  final int height;
  final Uint8List alpha;
  final double extent;
}
