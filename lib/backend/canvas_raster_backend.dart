import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../bitmap_canvas/bitmap_blend_utils.dart' as blend_utils;
import '../bitmap_canvas/bitmap_canvas.dart';
import '../bitmap_canvas/bitmap_layer_state.dart';
import '../bitmap_canvas/raster_int_rect.dart';

class RasterCompositeWork {
  const RasterCompositeWork._({
    required this.hasWork,
    required this.requiresFullSurface,
    this.regions,
  });

  const RasterCompositeWork.noWork()
    : this._(hasWork: false, requiresFullSurface: false);

  const RasterCompositeWork.withWork({
    required bool requiresFullSurface,
    List<RasterIntRect>? regions,
  }) : this._(
         hasWork: true,
         requiresFullSurface: requiresFullSurface,
         regions: regions,
       );

  final bool hasWork;
  final bool requiresFullSurface;
  final List<RasterIntRect>? regions;
}

class CanvasRasterBackend {
  CanvasRasterBackend({
    required int width,
    required int height,
    this.tileSize = 256,
  }) : _width = width,
       _height = height;

  int _width;
  int _height;
  final int tileSize;

  bool _compositeDirty = true;
  bool _compositeInitialized = false;
  bool _pendingFullSurface = false;
  Rect? _pendingDirtyBounds;
  final List<RasterIntRect> _pendingDirtyTiles = <RasterIntRect>[];
  final Set<int> _pendingDirtyTileKeys = <int>{};
  Uint32List? _compositePixels;
  Uint8List? _compositeRgba;
  Uint8List? _clipMaskBuffer;

  bool get isCompositeDirty => _compositeDirty;
  Uint32List? get compositePixels => _compositePixels;
  Uint8List? get compositeRgba => _compositeRgba;

  void markDirty({Rect? region}) {
    _compositeDirty = true;
    if (region == null || _pendingFullSurface) {
      _pendingDirtyBounds = null;
      _pendingDirtyTiles.clear();
      _pendingDirtyTileKeys.clear();
      _pendingFullSurface = true;
      return;
    }
    final Rect clipped = Rect.fromLTWH(
      0,
      0,
      _width.toDouble(),
      _height.toDouble(),
    ).intersect(region);
    if (clipped.isEmpty) {
      return;
    }
    if (_pendingDirtyBounds == null) {
      _pendingDirtyBounds = clipped;
    } else {
      final Rect current = _pendingDirtyBounds!;
      _pendingDirtyBounds = Rect.fromLTRB(
        math.min(current.left, clipped.left),
        math.min(current.top, clipped.top),
        math.max(current.right, clipped.right),
        math.max(current.bottom, clipped.bottom),
      );
    }
    _enqueueDirtyTiles(clipped);
  }

  RasterCompositeWork dequeueCompositeWork() {
    if (!_compositeDirty) {
      return const RasterCompositeWork.noWork();
    }
    final bool requiresFullSurface =
        !_compositeInitialized ||
        _pendingFullSurface ||
        _pendingDirtyBounds == null;
    final List<RasterIntRect>? dirtyTiles = requiresFullSurface
        ? null
        : List<RasterIntRect>.from(_pendingDirtyTiles);
    _pendingDirtyBounds = null;
    _pendingDirtyTiles.clear();
    _pendingDirtyTileKeys.clear();
    _pendingFullSurface = false;
    return RasterCompositeWork.withWork(
      requiresFullSurface: requiresFullSurface,
      regions: dirtyTiles,
    );
  }

  void composite({
    required List<BitmapLayerState> layers,
    required bool requiresFullSurface,
    List<RasterIntRect>? regions,
    String? translatingLayerId,
  }) {
    _ensureBuffers();
    final List<RasterIntRect> areas;
    if (requiresFullSurface) {
      areas = <RasterIntRect>[RasterIntRect(0, 0, _width, _height)];
    } else {
      if (regions == null || regions.isEmpty) {
        return;
      }
      areas = regions;
    }
    if (areas.isEmpty) {
      return;
    }

    final Uint32List composite = _compositePixels!;
    final Uint8List rgba = _compositeRgba!;
    final Uint8List clipMask = _ensureClipMask();
    clipMask.fillRange(0, clipMask.length, 0);

    for (final RasterIntRect area in areas) {
      if (area.isEmpty) {
        continue;
      }
      for (int y = area.top; y < area.bottom; y++) {
        final int rowOffset = y * _width;
        for (int x = area.left; x < area.right; x++) {
          final int index = rowOffset + x;
          int color = 0;
          bool initialized = false;
          for (final BitmapLayerState layer in layers) {
            if (!layer.visible) {
              continue;
            }
            if (translatingLayerId != null && layer.id == translatingLayerId) {
              continue;
            }
            final double layerOpacity = _clampUnit(layer.opacity);
            if (layerOpacity <= 0) {
              if (!layer.clippingMask) {
                clipMask[index] = 0;
              }
              continue;
            }
            final int src = layer.surface.pixels[index];
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
            final int rgbaOffset = index * 4;
            rgba[rgbaOffset] = 0;
            rgba[rgbaOffset + 1] = 0;
            rgba[rgbaOffset + 2] = 0;
            rgba[rgbaOffset + 3] = 0;
            continue;
          }

          composite[index] = color;
          final int rgbaOffset = index * 4;
          final int alpha = (color >> 24) & 0xff;
          if (alpha == 0) {
            rgba[rgbaOffset] = 0;
            rgba[rgbaOffset + 1] = 0;
            rgba[rgbaOffset + 2] = 0;
            rgba[rgbaOffset + 3] = 0;
          } else if (alpha == 255) {
            rgba[rgbaOffset] = (color >> 16) & 0xff;
            rgba[rgbaOffset + 1] = (color >> 8) & 0xff;
            rgba[rgbaOffset + 2] = color & 0xff;
            rgba[rgbaOffset + 3] = 255;
          } else {
            final int red = (color >> 16) & 0xff;
            final int green = (color >> 8) & 0xff;
            final int blue = color & 0xff;
            rgba[rgbaOffset] = blend_utils.premultiplyChannel(red, alpha);
            rgba[rgbaOffset + 1] = blend_utils.premultiplyChannel(green, alpha);
            rgba[rgbaOffset + 2] = blend_utils.premultiplyChannel(blue, alpha);
            rgba[rgbaOffset + 3] = alpha;
          }
        }
      }
    }

    if (requiresFullSurface) {
      _compositeInitialized = true;
    }
  }

  void completeCompositePass() {
    _compositeDirty = _pendingFullSurface || _pendingDirtyBounds != null;
  }

  Uint8List ensureRgbaBuffer() {
    _ensureBuffers();
    return _compositeRgba!;
  }

  Uint32List ensureCompositePixels() {
    _ensureBuffers();
    return _compositePixels!;
  }

  Uint8List _ensureClipMask() {
    return _clipMaskBuffer ??= Uint8List(_width * _height);
  }

  void resetClipMask() {
    _clipMaskBuffer = null;
  }

  RasterIntRect clipRectToSurface(Rect rect) {
    final double effectiveLeft = rect.left;
    final double effectiveTop = rect.top;
    final double effectiveRight = rect.right;
    final double effectiveBottom = rect.bottom;
    final int left = math.max(0, effectiveLeft.floor());
    final int top = math.max(0, effectiveTop.floor());
    final int right = math.min(_width, effectiveRight.ceil());
    final int bottom = math.min(_height, effectiveBottom.ceil());
    if (left >= right || top >= bottom) {
      return const RasterIntRect(0, 0, 0, 0);
    }
    return RasterIntRect(left, top, right, bottom);
  }

  Color colorAtComposite(
    Offset position,
    List<BitmapLayerState> layers, {
    String? translatingLayerId,
  }) {
    final int x = position.dx.floor();
    final int y = position.dy.floor();
    if (x < 0 || x >= _width || y < 0 || y >= _height) {
      return const Color(0x00000000);
    }
    final int index = y * _width + x;
    final Uint32List? pixels = _compositePixels;
    if (pixels != null && pixels.length > index) {
      return BitmapSurface.decodeColor(pixels[index]);
    }
    int? color;
    for (final BitmapLayerState layer in layers) {
      if (!layer.visible) {
        continue;
      }
      if (translatingLayerId != null && layer.id == translatingLayerId) {
        continue;
      }
      final int src = layer.surface.pixels[index];
      if (color == null) {
        color = src;
      } else {
        color = blend_utils.blendArgb(color, src);
      }
    }
    return BitmapSurface.decodeColor(color ?? 0);
  }

  void _ensureBuffers() {
    _compositePixels ??= Uint32List(_width * _height);
    _compositeRgba ??= Uint8List(_width * _height * 4);
  }

  void _enqueueDirtyTiles(Rect region) {
    final RasterIntRect clipped = clipRectToSurface(region);
    if (clipped.isEmpty) {
      return;
    }
    final int leftTile = clipped.left ~/ tileSize;
    final int rightTile = (clipped.right - 1) ~/ tileSize;
    final int topTile = clipped.top ~/ tileSize;
    final int bottomTile = (clipped.bottom - 1) ~/ tileSize;

    for (int ty = topTile; ty <= bottomTile; ty++) {
      for (int tx = leftTile; tx <= rightTile; tx++) {
        final int key = (ty << 20) | tx;
        if (!_pendingDirtyTileKeys.add(key)) {
          continue;
        }
        final int tileLeft = tx * tileSize;
        final int tileTop = ty * tileSize;
        final int tileRight = math.min(tileLeft + tileSize, _width);
        final int tileBottom = math.min(tileTop + tileSize, _height);
        _pendingDirtyTiles.add(
          RasterIntRect(tileLeft, tileTop, tileRight, tileBottom),
        );
      }
    }
  }

  static double _clampUnit(double value) {
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
}
