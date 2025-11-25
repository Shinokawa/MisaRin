import 'dart:typed_data';

import '../canvas/canvas_layer.dart';
import '../bitmap_canvas/bitmap_blend_utils.dart' as blend_utils;

class CompositeLayerPayload {
  const CompositeLayerPayload({
    required this.id,
    required this.visible,
    required this.opacity,
    required this.clippingMask,
    required this.blendModeIndex,
    required this.pixels,
  });

  final String id;
  final bool visible;
  final double opacity;
  final bool clippingMask;
  final int blendModeIndex;
  final Uint32List pixels;

  CanvasLayerBlendMode get blendMode =>
      CanvasLayerBlendMode.values[blendModeIndex];
}

class CompositeWorkPayload {
  const CompositeWorkPayload({
    required this.width,
    required this.height,
    required this.layers,
    this.translatingLayerId,
  });

  final int width;
  final int height;
  final List<CompositeLayerPayload> layers;
  final String? translatingLayerId;
}

Uint32List runCompositeWork(CompositeWorkPayload payload) {
  final int width = payload.width;
  final int height = payload.height;
  final int length = width * height;
  final Uint32List composite = Uint32List(length);
  final Uint8List clipMask = Uint8List(length);

  for (int y = 0; y < height; y++) {
    final int rowOffset = y * width;
    for (int x = 0; x < width; x++) {
      final int index = rowOffset + x;
      int color = 0;
      bool initialized = false;
      for (final CompositeLayerPayload layer in payload.layers) {
        if (!layer.visible) {
          continue;
        }
        if (payload.translatingLayerId != null &&
            layer.id == payload.translatingLayerId) {
          continue;
        }
        final double layerOpacity = _clampUnit(layer.opacity);
        if (layerOpacity <= 0) {
          if (!layer.clippingMask) {
            clipMask[index] = 0;
          }
          continue;
        }
        final int src = layer.pixels[index];
        final int srcA = (src >> 24) & 0xff;
        if (srcA == 0) {
          if (!layer.clippingMask) {
            clipMask[index] = 0;
          }
          continue;
        }

        double totalOpacity = layerOpacity;
        if (layer.clippingMask) {
          final int maskAlpha = clipMask[index];
          if (maskAlpha == 0) {
            continue;
          }
          totalOpacity *= maskAlpha / 255.0;
          if (totalOpacity <= 0) {
            continue;
          }
        }

        int effectiveA = (srcA * totalOpacity).round();
        if (effectiveA <= 0) {
          if (!layer.clippingMask) {
            clipMask[index] = 0;
          }
          continue;
        }
        effectiveA = effectiveA.clamp(0, 255);

        if (!layer.clippingMask) {
          clipMask[index] = effectiveA;
        }

        final int effectiveColor = (effectiveA << 24) | (src & 0x00FFFFFF);
        if (!initialized) {
          color = effectiveColor;
          initialized = true;
        } else {
          color = blend_utils.blendWithMode(
            color,
            effectiveColor,
            layer.blendMode,
            index,
          );
        }
      }

      if (!initialized) {
        composite[index] = 0;
        continue;
      }
      composite[index] = color;
    }
  }

  return composite;
}

double _clampUnit(double value) {
  if (value.isNaN) {
    return 0.0;
  }
  if (value < 0) {
    return 0.0;
  }
  if (value > 1) {
    return 1.0;
  }
  return value;
}
