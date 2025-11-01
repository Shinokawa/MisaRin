import 'dart:ui';

class CanvasViewport {
  CanvasViewport({double scale = 1.0, Offset offset = Offset.zero})
    : _scale = scale,
      _offset = offset;

  static const double minScale = 0.01;

  double _scale;
  Offset _offset;

  double get scale => _scale;
  Offset get offset => _offset;

  double clampScale(double value) {
    if (value.isNaN || value.isInfinite) {
      return value.isInfinite && value.isNegative ? minScale : _scale;
    }
    return value < minScale ? minScale : value;
  }

  void translate(Offset delta) {
    _offset += delta;
  }

  void setScale(double value) {
    _scale = clampScale(value);
  }

  void setOffset(Offset value) {
    _offset = value;
  }

  void reset() {
    _scale = 1.0;
    _offset = Offset.zero;
  }
}
