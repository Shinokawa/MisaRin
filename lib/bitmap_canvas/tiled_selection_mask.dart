import 'dart:collection';
import 'dart:typed_data';

import 'raster_int_rect.dart';
import 'tile_math.dart';

class SelectionTileKey {
  const SelectionTileKey(this.tx, this.ty);

  final int tx;
  final int ty;

  @override
  bool operator ==(Object other) {
    return other is SelectionTileKey && other.tx == tx && other.ty == ty;
  }

  @override
  int get hashCode => Object.hash(tx, ty);
}

class TiledSelectionMask {
  TiledSelectionMask({required this.tileSize});

  final int tileSize;
  final Map<SelectionTileKey, Uint8List> _tiles =
      HashMap<SelectionTileKey, Uint8List>();

  bool get isEmpty => _tiles.isEmpty;

  Uint8List? tile(int tx, int ty) => _tiles[SelectionTileKey(tx, ty)];

  Uint8List ensureTile(int tx, int ty) {
    final SelectionTileKey key = SelectionTileKey(tx, ty);
    Uint8List? tile = _tiles[key];
    if (tile != null) {
      return tile;
    }
    tile = Uint8List(tileSize * tileSize);
    _tiles[key] = tile;
    return tile;
  }

  int valueAt(int x, int y) {
    final int tx = tileIndexForCoord(x, tileSize);
    final int ty = tileIndexForCoord(y, tileSize);
    final Uint8List? tile = this.tile(tx, ty);
    if (tile == null) {
      return 0;
    }
    final int localX = x - tx * tileSize;
    final int localY = y - ty * tileSize;
    if (localX < 0 || localX >= tileSize || localY < 0 || localY >= tileSize) {
      return 0;
    }
    return tile[localY * tileSize + localX];
  }

  void setValue(int x, int y, int value) {
    final int tx = tileIndexForCoord(x, tileSize);
    final int ty = tileIndexForCoord(y, tileSize);
    final Uint8List tile = ensureTile(tx, ty);
    final int localX = x - tx * tileSize;
    final int localY = y - ty * tileSize;
    if (localX < 0 || localX >= tileSize || localY < 0 || localY >= tileSize) {
      return;
    }
    tile[localY * tileSize + localX] = value;
  }

  Uint8List extractRect(RasterIntRect rect) {
    if (rect.isEmpty) {
      return Uint8List(0);
    }
    final int width = rect.width;
    final int height = rect.height;
    final Uint8List buffer = Uint8List(width * height);

    final int startTx = tileIndexForCoord(rect.left, tileSize);
    final int endTx = tileIndexForCoord(rect.right - 1, tileSize);
    final int startTy = tileIndexForCoord(rect.top, tileSize);
    final int endTy = tileIndexForCoord(rect.bottom - 1, tileSize);

    for (int ty = startTy; ty <= endTy; ty++) {
      for (int tx = startTx; tx <= endTx; tx++) {
        final Uint8List? tile = this.tile(tx, ty);
        if (tile == null) {
          continue;
        }
        final int tileLeft = tx * tileSize;
        final int tileTop = ty * tileSize;
        final int left = rect.left > tileLeft ? rect.left : tileLeft;
        final int top = rect.top > tileTop ? rect.top : tileTop;
        final int right =
            rect.right < tileLeft + tileSize ? rect.right : tileLeft + tileSize;
        final int bottom = rect.bottom < tileTop + tileSize
            ? rect.bottom
            : tileTop + tileSize;
        if (left >= right || top >= bottom) {
          continue;
        }
        final int localLeft = left - tileLeft;
        final int localTop = top - tileTop;
        final int copyWidth = right - left;
        final int copyHeight = bottom - top;
        for (int row = 0; row < copyHeight; row++) {
          final int srcRow = (localTop + row) * tileSize + localLeft;
          final int dstRow = (top - rect.top + row) * width + (left - rect.left);
          buffer.setRange(dstRow, dstRow + copyWidth, tile, srcRow);
        }
      }
    }

    return buffer;
  }

  void clear() {
    _tiles.clear();
  }
}
