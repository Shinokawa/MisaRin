import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui';

import 'bitmap_canvas.dart';
import 'raster_int_rect.dart';
import 'tile_math.dart';

class TileKey {
  const TileKey(this.tx, this.ty);

  final int tx;
  final int ty;

  @override
  bool operator ==(Object other) {
    return other is TileKey && other.tx == tx && other.ty == ty;
  }

  @override
  int get hashCode => Object.hash(tx, ty);
}

class TileEntry {
  TileEntry({
    required this.key,
    required this.surface,
    required this.globalRect,
    required this.localRect,
  });

  final TileKey key;
  final BitmapSurface surface;
  final RasterIntRect globalRect;
  final RasterIntRect localRect;
}

class TiledSurface {
  TiledSurface({
    required this.width,
    required this.height,
    required this.tileSize,
    Color? defaultFill,
  }) : _defaultFill = defaultFill;

  final int width;
  final int height;
  final int tileSize;
  Color? _defaultFill;

  Color? get defaultFill => _defaultFill;

  set defaultFill(Color? value) {
    _defaultFill = value;
  }
  final Map<TileKey, BitmapSurface> _tiles = HashMap<TileKey, BitmapSurface>();

  UnmodifiableMapView<TileKey, BitmapSurface> get tiles =>
      UnmodifiableMapView<TileKey, BitmapSurface>(_tiles);

  BitmapSurface? getTile(int tx, int ty) => _tiles[TileKey(tx, ty)];

  BitmapSurface ensureTile(int tx, int ty) {
    final TileKey key = TileKey(tx, ty);
    BitmapSurface? surface = _tiles[key];
    if (surface != null) {
      return surface;
    }
    surface = BitmapSurface(
      width: tileSize,
      height: tileSize,
      fillColor: _defaultFill,
    );
    _tiles[key] = surface;
    return surface;
  }

  bool get isEmpty {
    if (_tiles.isEmpty) {
      if (_defaultFill == null) {
        return true;
      }
      return BitmapSurface.encodeColor(_defaultFill!) == 0;
    }
    for (final BitmapSurface surface in _tiles.values) {
      if (!surface.isClean) {
        return false;
      }
    }
    return true;
  }

  RasterIntRect? contentBounds() {
    if (_defaultFill != null &&
        BitmapSurface.encodeColor(_defaultFill!) != 0) {
      return RasterIntRect(0, 0, width, height);
    }
    RasterIntRect? bounds;
    for (final MapEntry<TileKey, BitmapSurface> entry in _tiles.entries) {
      if (entry.value.isClean) {
        continue;
      }
      if (!_tileHasContent(entry.value)) {
        continue;
      }
      final RasterIntRect rect = tileBounds(entry.key.tx, entry.key.ty, tileSize);
      if (bounds == null) {
        bounds = rect;
      } else {
        bounds = RasterIntRect(
          rect.left < bounds.left ? rect.left : bounds.left,
          rect.top < bounds.top ? rect.top : bounds.top,
          rect.right > bounds.right ? rect.right : bounds.right,
          rect.bottom > bounds.bottom ? rect.bottom : bounds.bottom,
        );
      }
    }
    return bounds;
  }

  Iterable<TileEntry> tilesInRect(
    RasterIntRect rect, {
    bool createMissing = false,
  }) sync* {
    if (rect.isEmpty) {
      return;
    }
    final int startTx = tileIndexForCoord(rect.left, tileSize);
    final int endTx = tileIndexForCoord(rect.right - 1, tileSize);
    final int startTy = tileIndexForCoord(rect.top, tileSize);
    final int endTy = tileIndexForCoord(rect.bottom - 1, tileSize);

    for (int ty = startTy; ty <= endTy; ty++) {
      for (int tx = startTx; tx <= endTx; tx++) {
        final RasterIntRect tileRect = tileBounds(tx, ty, tileSize);
        final int left = rect.left > tileRect.left ? rect.left : tileRect.left;
        final int top = rect.top > tileRect.top ? rect.top : tileRect.top;
        final int right = rect.right < tileRect.right ? rect.right : tileRect.right;
        final int bottom =
            rect.bottom < tileRect.bottom ? rect.bottom : tileRect.bottom;
        if (left >= right || top >= bottom) {
          continue;
        }
        final RasterIntRect localRect = RasterIntRect(
          left - tileRect.left,
          top - tileRect.top,
          right - tileRect.left,
          bottom - tileRect.top,
        );
        final BitmapSurface? surface = createMissing
            ? ensureTile(tx, ty)
            : getTile(tx, ty);
        if (surface == null) {
          continue;
        }
        yield TileEntry(
          key: TileKey(tx, ty),
          surface: surface,
          globalRect: RasterIntRect(left, top, right, bottom),
          localRect: localRect,
        );
      }
    }
  }

  Uint32List readRect(RasterIntRect rect) {
    if (rect.isEmpty) {
      return Uint32List(0);
    }
    final int width = rect.width;
    final int height = rect.height;
    final Uint32List buffer = Uint32List(width * height);
    if (_defaultFill != null) {
      final int argb = BitmapSurface.encodeColor(_defaultFill!);
      if (argb != 0) {
        buffer.fillRange(0, buffer.length, argb);
      }
    }
    for (final TileEntry entry in tilesInRect(rect)) {
      final Uint32List pixels = entry.surface.pixels;
      final RasterIntRect local = entry.localRect;
      final RasterIntRect global = entry.globalRect;
      for (int row = 0; row < local.height; row++) {
        final int srcRow = (local.top + row) * tileSize + local.left;
        final int dstRow = (global.top - rect.top + row) * width +
            (global.left - rect.left);
        buffer.setRange(
          dstRow,
          dstRow + local.width,
          pixels,
          srcRow,
        );
      }
    }
    return buffer;
  }

  void writeRect(RasterIntRect rect, Uint32List pixels) {
    if (rect.isEmpty) {
      return;
    }
    final int width = rect.width;
    final int height = rect.height;
    if (pixels.length != width * height) {
      throw ArgumentError('Pixel data size mismatch for writeRect');
    }
    for (final TileEntry entry in tilesInRect(rect, createMissing: true)) {
      final Uint32List dstPixels = entry.surface.pixels;
      final RasterIntRect local = entry.localRect;
      final RasterIntRect global = entry.globalRect;
      for (int row = 0; row < local.height; row++) {
        final int srcRow = (global.top - rect.top + row) * width +
            (global.left - rect.left);
        final int dstRow = (local.top + row) * tileSize + local.left;
        dstPixels.setRange(
          dstRow,
          dstRow + local.width,
          pixels,
          srcRow,
        );
      }
      entry.surface.markDirty();
    }
  }

  void fillRect(RasterIntRect rect, int argb) {
    if (rect.isEmpty) {
      return;
    }
    final int defaultArgb =
        _defaultFill == null ? 0 : BitmapSurface.encodeColor(_defaultFill!);
    final bool isDefault = argb == defaultArgb;
    final int startTx = tileIndexForCoord(rect.left, tileSize);
    final int endTx = tileIndexForCoord(rect.right - 1, tileSize);
    final int startTy = tileIndexForCoord(rect.top, tileSize);
    final int endTy = tileIndexForCoord(rect.bottom - 1, tileSize);

    for (int ty = startTy; ty <= endTy; ty++) {
      for (int tx = startTx; tx <= endTx; tx++) {
        final RasterIntRect tileRect = tileBounds(tx, ty, tileSize);
        final int left = rect.left > tileRect.left ? rect.left : tileRect.left;
        final int top = rect.top > tileRect.top ? rect.top : tileRect.top;
        final int right = rect.right < tileRect.right
            ? rect.right
            : tileRect.right;
        final int bottom = rect.bottom < tileRect.bottom
            ? rect.bottom
            : tileRect.bottom;
        if (left >= right || top >= bottom) {
          continue;
        }
        final TileKey key = TileKey(tx, ty);
        final BitmapSurface? existing = _tiles[key];
        if (isDefault) {
          if (existing == null) {
            continue;
          }
          final RasterIntRect surfaceRect = _tileSurfaceRect(tileRect);
          if (left <= surfaceRect.left &&
              top <= surfaceRect.top &&
              right >= surfaceRect.right &&
              bottom >= surfaceRect.bottom) {
            existing.dispose();
            _tiles.remove(key);
            continue;
          }
        }
        final BitmapSurface surface = existing ?? ensureTile(tx, ty);
        final Uint32List dstPixels = surface.pixels;
        final int localLeft = left - tileRect.left;
        final int localTop = top - tileRect.top;
        final int localWidth = right - left;
        final int localHeight = bottom - top;
        for (int row = 0; row < localHeight; row++) {
          final int dstRow = (localTop + row) * tileSize + localLeft;
          dstPixels.fillRange(dstRow, dstRow + localWidth, argb);
        }
        surface.markDirty();
      }
    }
  }

  int pixelAt(int x, int y) {
    final int tx = tileIndexForCoord(x, tileSize);
    final int ty = tileIndexForCoord(y, tileSize);
    final BitmapSurface? surface = getTile(tx, ty);
    if (surface == null) {
      if (_defaultFill == null) {
        return 0;
      }
      return BitmapSurface.encodeColor(_defaultFill!);
    }
    final RasterIntRect tileRect = tileBounds(tx, ty, tileSize);
    final int localX = x - tileRect.left;
    final int localY = y - tileRect.top;
    if (localX < 0 || localX >= tileSize || localY < 0 || localY >= tileSize) {
      return 0;
    }
    return surface.pixels[localY * tileSize + localX];
  }

  void setPixel(int x, int y, int argb) {
    final int tx = tileIndexForCoord(x, tileSize);
    final int ty = tileIndexForCoord(y, tileSize);
    final BitmapSurface surface = ensureTile(tx, ty);
    final RasterIntRect tileRect = tileBounds(tx, ty, tileSize);
    final int localX = x - tileRect.left;
    final int localY = y - tileRect.top;
    if (localX < 0 || localX >= tileSize || localY < 0 || localY >= tileSize) {
      return;
    }
    surface.pixels[localY * tileSize + localX] = argb;
    surface.markDirty();
  }

  RasterIntRect _tileSurfaceRect(RasterIntRect tileRect) {
    final int left = tileRect.left.clamp(0, width);
    final int top = tileRect.top.clamp(0, height);
    final int right = tileRect.right.clamp(0, width);
    final int bottom = tileRect.bottom.clamp(0, height);
    if (left >= right || top >= bottom) {
      return const RasterIntRect(0, 0, 0, 0);
    }
    return RasterIntRect(left, top, right, bottom);
  }

  bool _tileHasContent(BitmapSurface surface) {
    final Uint32List pixels = surface.pixels;
    for (final int pixel in pixels) {
      if ((pixel >> 24) != 0) {
        return true;
      }
    }
    return false;
  }

  void clear() {
    if (_tiles.isEmpty) {
      return;
    }
    for (final BitmapSurface surface in _tiles.values) {
      surface.dispose();
    }
    _tiles.clear();
  }

  void dispose() {
    for (final BitmapSurface surface in _tiles.values) {
      surface.dispose();
    }
    _tiles.clear();
  }
}
