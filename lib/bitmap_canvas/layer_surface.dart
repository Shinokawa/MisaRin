import 'dart:typed_data';
import 'dart:ui';

import 'bitmap_canvas.dart';
import 'raster_int_rect.dart';
import 'tiled_surface.dart';

class LayerSurface {
  LayerSurface.bitmap(BitmapSurface surface)
      : _bitmap = surface,
        _tiled = null,
        width = surface.width,
        height = surface.height,
        tileSize = 0;

  LayerSurface.tiled({
    required this.width,
    required this.height,
    required this.tileSize,
    Color? defaultFill,
  })  : _bitmap = null,
        _tiled = TiledSurface(
          width: width,
          height: height,
          tileSize: tileSize,
          defaultFill: defaultFill,
        );

  final int width;
  final int height;
  final int tileSize;
  final BitmapSurface? _bitmap;
  final TiledSurface? _tiled;

  bool get isTiled => _tiled != null;

  int get pixelCount => width * height;

  int get pointerAddress => _bitmap?.pointerAddress ?? 0;

  bool get isClean => _bitmap?.isClean ?? _tiled!.isEmpty;

  BitmapSurface? get bitmapSurface => _bitmap;

  TiledSurface? get tiledSurface => _tiled;

  Uint32List get pixels =>
      _bitmap?.pixels ?? readRect(RasterIntRect(0, 0, width, height));

  void markDirty() {
    _bitmap?.markDirty();
  }

  void dispose() {
    _bitmap?.dispose();
    _tiled?.dispose();
  }

  Uint32List readRect(RasterIntRect rect) {
    if (_bitmap != null) {
      return _readRectFromBitmap(rect);
    }
    return _tiled!.readRect(rect);
  }

  int pixelAt(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) {
      return 0;
    }
    if (_bitmap != null) {
      return _bitmap!.pixels[y * width + x];
    }
    return _tiled!.pixelAt(x, y);
  }

  void writeRect(RasterIntRect rect, Uint32List pixels) {
    if (_bitmap != null) {
      _writeRectToBitmap(rect, pixels);
      return;
    }
    _tiled!.writeRect(rect, pixels);
  }

  void fill(Color color) {
    if (_bitmap != null) {
      _bitmap!.fill(color);
      return;
    }
    _tiled!.defaultFill = color;
    _tiled!.clear();
  }

  void fillRect(RasterIntRect rect, int argb) {
    if (_bitmap != null) {
      final int left = rect.left.clamp(0, width);
      final int top = rect.top.clamp(0, height);
      final int right = rect.right.clamp(0, width);
      final int bottom = rect.bottom.clamp(0, height);
      if (left >= right || top >= bottom) {
        return;
      }
      final Uint32List pixels = _bitmap!.pixels;
      final int surfaceWidth = _bitmap!.width;
      final int rowWidth = right - left;
      for (int y = top; y < bottom; y++) {
        final int rowStart = y * surfaceWidth + left;
        pixels.fillRange(rowStart, rowStart + rowWidth, argb);
      }
      if (argb != 0) {
        _bitmap!.markDirty();
      }
      return;
    }
    _tiled!.fillRect(rect, argb);
  }

  T withBitmapSurface<T>({
    required bool writeBack,
    required T Function(BitmapSurface surface) action,
  }) {
    final BitmapSurface? base = _bitmap;
    if (base != null) {
      return action(base);
    }
    final BitmapSurface temp = BitmapSurface(width: width, height: height);
    final Uint32List snapshot = readRect(RasterIntRect(0, 0, width, height));
    if (snapshot.isNotEmpty) {
      temp.pixels.setAll(0, snapshot);
    }
    final T result = action(temp);
    if (writeBack) {
      writeRect(RasterIntRect(0, 0, width, height), temp.pixels);
    }
    temp.dispose();
    return result;
  }

  Uint32List _readRectFromBitmap(RasterIntRect rect) {
    if (rect.isEmpty) {
      return Uint32List(0);
    }
    final int rectWidth = rect.width;
    final int rectHeight = rect.height;
    final Uint32List buffer = Uint32List(rectWidth * rectHeight);
    final int left = rect.left.clamp(0, width);
    final int top = rect.top.clamp(0, height);
    final int right = rect.right.clamp(0, width);
    final int bottom = rect.bottom.clamp(0, height);
    if (left >= right || top >= bottom) {
      return buffer;
    }
    final Uint32List source = _bitmap!.pixels;
    final int surfaceWidth = _bitmap!.width;
    for (int row = top; row < bottom; row++) {
      final int srcRow = row * surfaceWidth + left;
      final int dstRow = (row - rect.top) * rectWidth + (left - rect.left);
      buffer.setRange(dstRow, dstRow + (right - left), source, srcRow);
    }
    return buffer;
  }

  void _writeRectToBitmap(RasterIntRect rect, Uint32List pixels) {
    if (rect.isEmpty) {
      return;
    }
    final int rectWidth = rect.width;
    final int rectHeight = rect.height;
    if (pixels.length != rectWidth * rectHeight) {
      throw ArgumentError('Pixel data size mismatch for writeRect');
    }
    final int left = rect.left.clamp(0, width);
    final int top = rect.top.clamp(0, height);
    final int right = rect.right.clamp(0, width);
    final int bottom = rect.bottom.clamp(0, height);
    if (left >= right || top >= bottom) {
      return;
    }
    final Uint32List destination = _bitmap!.pixels;
    final int surfaceWidth = _bitmap!.width;
    final int copyWidth = right - left;
    for (int row = top; row < bottom; row++) {
      final int srcRow = (row - rect.top) * rectWidth + (left - rect.left);
      final int dstRow = row * surfaceWidth + left;
      destination.setRange(dstRow, dstRow + copyWidth, pixels, srcRow);
    }
    _bitmap!.markDirty();
  }
}
