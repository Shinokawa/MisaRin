import 'dart:ui';

import 'canvas_layer.dart';

class StrokeStore {
  final List<_Layer> _layers = <_Layer>[];
  final List<_StrokeOperation> _history = <_StrokeOperation>[];
  final List<_StrokeOperation> _redo = <_StrokeOperation>[];

  CanvasStroke? _currentStroke;
  String? _currentStrokeLayerId;
  String? _activeLayerId;

  List<CanvasLayerData> get layers =>
      List<CanvasLayerData>.unmodifiable(_layers.map((layer) => layer.snapshot()));

  CanvasLayerData? get activeLayer {
    final String? id = _activeLayerId;
    if (id == null) {
      return null;
    }
    return _layerById(id)?.snapshot();
  }

  String? get activeLayerId => _activeLayerId;

  CanvasStroke? get currentStroke => _currentStroke;
  bool get canUndo => _currentStroke != null || _history.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  bool get hasStrokes =>
      _layers.any((layer) => layer.strokes.isNotEmpty);

  bool get hasVisibleContent => _layers.any(
        (layer) =>
            layer.visible && (layer.fillColor != null || layer.strokes.isNotEmpty),
      );

  void initialize(List<CanvasLayerData> initialLayers) {
    _layers
      ..clear()
      ..addAll(initialLayers.map(_Layer.fromData));
    _history.clear();
    _redo.clear();
    _currentStroke = null;
    _currentStrokeLayerId = null;
    _activeLayerId = _topLayerId();
    if (_activeLayerId == null) {
      _createDefaultStrokeLayer();
    }
  }

  List<CanvasLayerData> committedLayers() {
    return List<CanvasLayerData>.unmodifiable(_layers.map((layer) {
      final List<CanvasStroke> committed = <CanvasStroke>[];
      for (final CanvasStroke stroke in layer.strokes) {
        if (identical(stroke, _currentStroke)) {
          continue;
        }
        committed.add(stroke.clone());
      }
      return CanvasLayerData(
        id: layer.id,
        name: layer.name,
        visible: layer.visible,
        fillColor: layer.fillColor,
        strokes: committed,
      );
    }));
  }

  List<CanvasLayerData> snapshotLayers() {
    return List<CanvasLayerData>.unmodifiable(
      _layers.map((layer) => layer.snapshot()),
    );
  }

  void loadFromSnapshot(List<CanvasLayerData> layers) {
    initialize(layers);
  }

  void clear() {
    for (final _Layer layer in _layers) {
      layer.strokes.clear();
    }
    _history.clear();
    _redo.clear();
    _currentStroke = null;
    _currentStrokeLayerId = null;
  }

  bool setActiveLayer(String id) {
    final _Layer? layer = _layerById(id);
    if (layer == null) {
      return false;
    }
    _activeLayerId = id;
    return true;
  }

  CanvasLayerData addLayer({
    String? name,
    bool activate = true,
    Color? fillColor,
    String? aboveLayerId,
  }) {
    final _Layer layer = _Layer.stroke(
      id: generateLayerId(),
      name: name ?? _generateLayerName(),
      fillColor: fillColor,
    );
    if (aboveLayerId != null) {
      final int index = _layers.indexWhere((element) => element.id == aboveLayerId);
      if (index >= 0) {
        _layers.insert(index + 1, layer);
      } else {
        _layers.add(layer);
      }
    } else {
      _layers.add(layer);
    }
    if (activate) {
      _activeLayerId = layer.id;
    }
    return layer.snapshot();
  }

  bool removeLayer(String id) {
    if (_layers.length <= 1) {
      return false;
    }
    final int index = _layers.indexWhere((layer) => layer.id == id);
    if (index < 0) {
      return false;
    }
    _layers.removeAt(index);
    if (_activeLayerId == id) {
      _activeLayerId = _topLayerId();
      _currentStroke = null;
      _currentStrokeLayerId = null;
    }
    return true;
  }

  bool reorderLayer(int fromIndex, int toIndex) {
    if (fromIndex < 0 || fromIndex >= _layers.length) {
      return false;
    }
    if (toIndex < 0 || toIndex >= _layers.length) {
      return false;
    }
    if (fromIndex == toIndex) {
      return true;
    }
    final _Layer layer = _layers.removeAt(fromIndex);
    _layers.insert(toIndex, layer);
    return true;
  }

  bool updateLayerVisibility(String id, bool visible) {
    final _Layer? layer = _layerById(id);
    if (layer == null) {
      return false;
    }
    layer.visible = visible;
    return true;
  }

  bool setLayerFillColor(String id, Color color) {
    final _Layer? layer = _layerById(id);
    if (layer == null) {
      return false;
    }
    layer.fillColor = color;
    return true;
  }

  bool clearLayerFillColor(String id) {
    final _Layer? layer = _layerById(id);
    if (layer == null) {
      return false;
    }
    layer.fillColor = null;
    return true;
  }

  void startStroke(
    Offset point, {
    required Color color,
    required double width,
  }) {
    final _Layer layer = _ensureActiveStrokeLayer();
    _redo.clear();
    final CanvasStroke stroke = CanvasStroke(color: color, width: width, points: <Offset>[point]);
    layer.strokes.add(stroke);
    _currentStroke = stroke;
    _currentStrokeLayerId = layer.id;
  }

  void appendPoint(Offset point) {
    final CanvasStroke? stroke = _currentStroke;
    if (stroke == null) {
      return;
    }
    stroke.points.add(point);
  }

  void finishStroke() {
    if (_currentStroke == null || _currentStrokeLayerId == null) {
      return;
    }
    if (_currentStroke!.points.isEmpty) {
      final _Layer? layer = _layerById(_currentStrokeLayerId!);
      layer?.strokes.remove(_currentStroke);
    } else {
      _history.add(
        _StrokeOperation(
          layerId: _currentStrokeLayerId!,
          stroke: _currentStroke!,
        ),
      );
    }
    _currentStroke = null;
    _currentStrokeLayerId = null;
  }

  bool undo() {
    if (_currentStroke != null && _currentStrokeLayerId != null) {
      final _Layer? layer = _layerById(_currentStrokeLayerId!);
      if (layer == null || layer.strokes.isEmpty) {
        return false;
      }
      final CanvasStroke stroke = layer.strokes.removeLast();
      _redo.add(_StrokeOperation(layerId: layer.id, stroke: stroke));
      _currentStroke = null;
      _currentStrokeLayerId = null;
      return true;
    }
    if (_history.isEmpty) {
      return false;
    }
    final _StrokeOperation operation = _history.removeLast();
    final _Layer? layer = _layerById(operation.layerId);
    if (layer == null || layer.strokes.isEmpty) {
      return false;
    }
    layer.strokes.removeLast();
    _redo.add(operation.copy());
    return true;
  }

  bool redo() {
    if (_redo.isEmpty) {
      return false;
    }
    final _StrokeOperation operation = _redo.removeLast();
    final _Layer? layer = _layerById(operation.layerId);
    if (layer == null) {
      return false;
    }
    layer.strokes.add(operation.stroke.clone());
    _history.add(operation.copy());
    return true;
  }

  String _generateLayerName() => '图层 ${_layers.length + 1}';

  _Layer _ensureActiveStrokeLayer() {
    if (_activeLayerId != null) {
      final _Layer? layer = _layerById(_activeLayerId!);
      if (layer != null) {
        return layer;
      }
    }
    final _Layer layer = _createDefaultStrokeLayer();
    _activeLayerId = layer.id;
    return layer;
  }

  _Layer _createDefaultStrokeLayer() {
    final _Layer layer = _Layer.stroke(
      id: generateLayerId(),
      name: _generateLayerName(),
    );
    _layers.add(layer);
    return layer;
  }

  String? _topLayerId() => _layers.isEmpty ? null : _layers.last.id;

  _Layer? _layerById(String id) {
    for (final _Layer layer in _layers) {
      if (layer.id == id) {
        return layer;
      }
    }
    return null;
  }
}

class _Layer {
  _Layer.stroke({
    required this.id,
    required this.name,
    this.visible = true,
    this.fillColor,
  }) : strokes = <CanvasStroke>[];

  factory _Layer.fromData(CanvasLayerData data) {
    return _Layer.stroke(
      id: data.id,
      name: data.name,
      visible: data.visible,
      fillColor: data.fillColor,
    )..strokes.addAll(data.strokes.map((stroke) => stroke.clone()));
  }

  final String id;
  String name;
  bool visible;
  Color? fillColor;
  final List<CanvasStroke> strokes;

  CanvasLayerData snapshot() {
    return CanvasLayerData(
      id: id,
      name: name,
      visible: visible,
      fillColor: fillColor,
      strokes: strokes.map((stroke) => stroke.clone()).toList(growable: false),
    );
  }
}

class _StrokeOperation {
  _StrokeOperation({required this.layerId, required CanvasStroke stroke})
      : stroke = stroke.clone();

  final String layerId;
  final CanvasStroke stroke;

  _StrokeOperation copy() {
    return _StrokeOperation(layerId: layerId, stroke: stroke.clone());
  }
}
