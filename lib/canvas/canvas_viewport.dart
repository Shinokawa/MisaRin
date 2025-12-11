import 'dart:ui';

class CanvasViewport {
  CanvasViewport({
    double scale = 1.0,
    Offset offset = Offset.zero,
    double rotation = 0.0,
  })  : _scale = scale,
        _offset = offset,
        _rotation = rotation;

  static const double minScale = 0.01;
  static const double maxScale = 512.0;

  double _scale;
  Offset _offset;
  double _rotation;

  double get scale => _scale;
  Offset get offset => _offset;
  double get rotation => _rotation;

  double clampScale(double value) {
    if (value.isNaN) {
      return _scale;
    }
    if (value.isInfinite) {
      return value.isNegative ? minScale : maxScale;
    }
    if (value < minScale) {
      return minScale;
    }
    if (value > maxScale) {
      return maxScale;
    }
    return value;
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

  void setRotation(double value) {
    if (value.isNaN || value.isInfinite) {
      return;
    }
    _rotation = _normalizeAngle(value);
  }

  void rotateBy(double delta) {
    setRotation(_rotation + delta);
  }

  void reset() {
    _scale = 1.0;
    _offset = Offset.zero;
    _rotation = 0.0;
  }

  double _normalizeAngle(double radians) {
    double value = radians % (2 * 3.1415926535897932);
    if (value > 3.1415926535897932) {
      value -= 2 * 3.1415926535897932;
    } else if (value < -3.1415926535897932) {
      value += 2 * 3.1415926535897932;
    }
    return value;
  }
}
