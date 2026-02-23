import 'raster_int_rect.dart';

int floorDivInt(int value, int divisor) {
  if (divisor == 0) {
    throw ArgumentError('divisor must be non-zero');
  }
  if (value >= 0) {
    return value ~/ divisor;
  }
  return -(((-value) + divisor - 1) ~/ divisor);
}

int tileIndexForCoord(int coord, int tileSize) {
  return floorDivInt(coord, tileSize);
}

RasterIntRect tileBounds(int tx, int ty, int tileSize) {
  final int left = tx * tileSize;
  final int top = ty * tileSize;
  return RasterIntRect(left, top, left + tileSize, top + tileSize);
}
