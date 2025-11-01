import 'dart:ui';

class StrokeStore {
  final List<List<Offset>> _strokes = <List<Offset>>[];
  List<Offset>? _currentStroke;
  final List<List<Offset>> _undone = <List<Offset>>[];

  List<List<Offset>> get strokes => List<List<Offset>>.unmodifiable(_strokes);
  bool get canUndo => _strokes.isNotEmpty;
  bool get canRedo => _undone.isNotEmpty;

  void startStroke(Offset point) {
    _undone.clear();
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
    _undone.add(_strokes.removeLast());
    return true;
  }

  bool redo() {
    if (_undone.isEmpty) {
      return false;
    }
    _strokes.add(_undone.removeLast());
    return true;
  }

  void clear() {
    _strokes.clear();
    _currentStroke = null;
    _undone.clear();
  }

  List<List<Offset>> snapshot() {
    return _strokes
        .map((stroke) => List<Offset>.from(stroke, growable: false))
        .toList(growable: false);
  }
}
