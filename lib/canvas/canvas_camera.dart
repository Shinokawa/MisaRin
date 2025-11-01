import 'dart:ui';

class CanvasCamera {
  CanvasCamera({Offset offset = Offset.zero}) : _offset = offset;

  Offset _offset;

  Offset get offset => _offset;

  void translate(Offset delta) {
    _offset += delta;
  }

  void reset() {
    _offset = Offset.zero;
  }
}
