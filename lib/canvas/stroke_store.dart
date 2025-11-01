import 'dart:ui';

class StrokeStore {
  final List<List<Offset>> _strokes = <List<Offset>>[];
  List<Offset>? _currentStroke;

  List<List<Offset>> get strokes => List<List<Offset>>.unmodifiable(_strokes);

  void startStroke(Offset point) {
    _currentStroke = <Offset>[point];
    _strokes.add(_currentStroke!);
  }

  void appendPoint(Offset point) {
    final stroke = _currentStroke;
    if (stroke == null) {
      return;
    }
    stroke.add(point);
  }

  void finishStroke() {
    _currentStroke = null;
  }

  bool undo() {
    if (_strokes.isEmpty) {
      return false;
    }
    if (_currentStroke != null) {
      _currentStroke = null;
    }
    _strokes.removeLast();
    return true;
  }

  void clear() {
    _strokes.clear();
    _currentStroke = null;
  }

  List<List<Offset>> snapshot() {
    return _strokes
        .map((stroke) => List<Offset>.from(stroke, growable: false))
        .toList(growable: false);
  }
}
