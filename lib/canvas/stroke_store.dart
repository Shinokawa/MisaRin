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

  bool get hasStrokes {
    for (final _Layer layer in _layers) {
      if (layer.type == CanvasLayerType.strokes && layer.strokes.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  bool get hasVisibleContent {
    for (final _Layer layer in _layers) {
      if (!layer.visible) {
        continue;
      }
      if (layer.type == CanvasLayerType.color) {
        return true;
      }
      if (layer.strokes.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  void initialize(List<CanvasLayerData> initialLayers) {
    _layers
      ..clear()
      ..addAll(initialLayers.map(_Layer.fromData));
    _history.clear();
    _redo.clear();
    _currentStroke = null;
    _currentStrokeLayerId = null;
    _activeLayerId = _firstDrawableLayerId();
    if (_activeLayerId == null) {
      _createDefaultStrokeLayer();
    }
  }

  List<CanvasLayerData> committedLayers() {
    return List<CanvasLayerData>.unmodifiable(_layers.map((layer) {
      if (layer.type != CanvasLayerType.strokes) {
        return layer.snapshot();
      }
      final List<CanvasStroke> committed = <CanvasStroke>[];
      for (final CanvasStroke stroke in layer.strokes) {
        if (identical(stroke, _currentStroke)) {
          continue;
        }
        committed.add(stroke.clone());
      }
      return CanvasLayerData.strokes(
        id: layer.id,
        name: layer.name,
        visible: layer.visible,
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
      if (layer.type == CanvasLayerType.strokes) {
        layer.strokes.clear();
      }
    }
    _history.clear();
    _redo.clear();
    _currentStroke = null;
    _currentStrokeLayerId = null;
  }

  bool setActiveLayer(String id) {
    final _Layer? layer = _layerById(id);
    if (layer == null || layer.type != CanvasLayerType.strokes) {
      return false;
    }
    _activeLayerId = id;
    return true;
  }

  CanvasLayerData addStrokeLayer({String? name, bool activate = true}) {
    final _Layer layer = _Layer.stroke(
      id: generateLayerId(),
      name: name ?? _generateLayerName(),
    );
    _layers.add(layer);
    if (activate) {
      _activeLayerId = layer.id;
    }
    return layer.snapshot();
  }

  CanvasLayerData addColorLayer({
    String? name,
    Color color = const Color(0xFFFFFFFF),
    String? aboveLayerId,
  }) {
    final _Layer layer = _Layer.color(
      id: generateLayerId(),
      name: name ?? '颜色填充',
      color: color,
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
    final _Layer layer = _layers[index];
    if (layer.type == CanvasLayerType.color) {
      return false;
    }
    _layers.removeAt(index);
    if (_activeLayerId == id) {
      _activeLayerId = _firstDrawableLayerId();
      _currentStroke = null;
      _currentStrokeLayerId = null;
    }
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

  bool updateColorLayer(String id, Color color) {
    final _Layer? layer = _layerById(id);
    if (layer == null || layer.type != CanvasLayerType.color) {
      return false;
    }
    layer.color = color;
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

  String _generateLayerName() {
    final int count =
        _layers.where((layer) => layer.type == CanvasLayerType.strokes).length + 1;
    return '图层 $count';
  }

  _Layer _ensureActiveStrokeLayer() {
    if (_activeLayerId != null) {
      final _Layer? layer = _layerById(_activeLayerId!);
      if (layer != null && layer.type == CanvasLayerType.strokes) {
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

  String? _firstDrawableLayerId() {
    for (final _Layer layer in _layers) {
      if (layer.type == CanvasLayerType.strokes) {
        return layer.id;
      }
    }
    return null;
  }

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
  })  : type = CanvasLayerType.strokes,
        color = null,
        strokes = <CanvasStroke>[];

  _Layer.color({
    required this.id,
    required this.name,
    required this.color,
    this.visible = true,
  })  : type = CanvasLayerType.color,
        strokes = <CanvasStroke>[];

  factory _Layer.fromData(CanvasLayerData data) {
    switch (data.type) {
      case CanvasLayerType.color:
        return _Layer.color(
          id: data.id,
          name: data.name,
          color: data.color ?? const Color(0xFFFFFFFF),
          visible: data.visible,
        );
      case CanvasLayerType.strokes:
        return _Layer.stroke(
          id: data.id,
          name: data.name,
          visible: data.visible,
        )
          ..strokes.addAll(data.strokes.map((stroke) => stroke.clone()));
    }
  }

  final String id;
  String name;
  final CanvasLayerType type;
  bool visible;
  Color? color;
  final List<CanvasStroke> strokes;

  CanvasLayerData snapshot() {
    if (type == CanvasLayerType.color) {
      return CanvasLayerData.color(
        id: id,
        name: name,
        color: color ?? const Color(0xFFFFFFFF),
        visible: visible,
      );
    }
    return CanvasLayerData.strokes(
      id: id,
      name: name,
      visible: visible,
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
