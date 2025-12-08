import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
class CanvasViewInfo {
  const CanvasViewInfo({
    required this.canvasSize,
    required this.scale,
    required this.cursorPosition,
    required this.pixelGridVisible,
    required this.viewBlackWhiteEnabled,
    required this.viewMirrorEnabled,
  });

  final Size canvasSize;
  final double scale;
  final Offset? cursorPosition;
  final bool pixelGridVisible;
  final bool viewBlackWhiteEnabled;
  final bool viewMirrorEnabled;

  @override
  bool operator ==(Object other) {
    return other is CanvasViewInfo &&
        _sizeEquals(other.canvasSize, canvasSize) &&
        _doubleEquals(other.scale, scale) &&
        _offsetEquals(other.cursorPosition, cursorPosition) &&
        other.pixelGridVisible == pixelGridVisible &&
        other.viewBlackWhiteEnabled == viewBlackWhiteEnabled &&
        other.viewMirrorEnabled == viewMirrorEnabled;
  }

  @override
  int get hashCode => Object.hash(
        _rounded(canvasSize.width),
        _rounded(canvasSize.height),
        _rounded(scale),
        cursorPosition == null
            ? null
            : Object.hash(
                _rounded(cursorPosition!.dx),
                _rounded(cursorPosition!.dy),
              ),
        pixelGridVisible,
        viewBlackWhiteEnabled,
        viewMirrorEnabled,
      );
}

bool _doubleEquals(double a, double b, {double epsilon = 1e-6}) {
  return (a - b).abs() < epsilon;
}

bool _offsetEquals(Offset? a, Offset? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a == null || b == null) {
    return a == b;
  }
  return _doubleEquals(a.dx, b.dx) && _doubleEquals(a.dy, b.dy);
}

bool _sizeEquals(Size a, Size b) {
  return _doubleEquals(a.width, b.width) && _doubleEquals(a.height, b.height);
}

double _rounded(double value, {int fractionDigits = 6}) {
  final num factor = math.pow(10, fractionDigits);
  return (value * factor).round() / factor;
}
