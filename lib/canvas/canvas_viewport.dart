import 'dart:ui';

class CanvasViewport {
  CanvasViewport({double scale = 1.0, Offset offset = Offset.zero})
    : _scale = scale,
      _offset = offset;

  static const double minScale = 0.25;
  static const double maxScale = 4.0;

  double _scale;
  Offset _offset;

  double get scale => _scale;
  Offset get offset => _offset;

  void translate(Offset delta) {
    _offset += delta;
  }

  void setScale(double value) {
    _scale = value.clamp(minScale, maxScale);
  }

  void setOffset(Offset value) {
    _offset = value;
  }

  void reset() {
    _scale = 1.0;
    _offset = Offset.zero;
  }
}
