import 'dart:ui';

import 'canvas_layer.dart';

class StrokeStore {
  final List<_Layer> _layers = <_Layer>[];
  final List<_Operation> _history = <_Operation>[];
  final List<_Operation> _redo = <_Operation>[];

  CanvasStroke? _currentStroke;
  String? _currentStrokeLayerId;
  String? _activeLayerId;

  List<CanvasLayerData> get layers => List<CanvasLayerData>.unmodifiable(
    _layers.map((layer) => layer.snapshot()),
  );

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

  bool get hasStrokes => _layers.any((layer) => layer.strokes.isNotEmpty);

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
    return List<CanvasLayerData>.unmodifiable(
      _layers.map((layer) {
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
      }),
    );
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
    final String? previousActive = _activeLayerId;
    final _Layer layer = _Layer.stroke(
      id: generateLayerId(),
      name: name ?? _generateLayerName(),
      fillColor: fillColor,
    );
    int insertIndex;
    if (aboveLayerId != null) {
      final int index = _layers.indexWhere(
        (element) => element.id == aboveLayerId,
      );
      if (index >= 0) {
        insertIndex = index + 1;
        _layers.insert(insertIndex, layer);
      } else {
        insertIndex = _layers.length;
        _layers.add(layer);
      }
    } else {
      insertIndex = _layers.length;
      _layers.add(layer);
    }
    if (activate) {
      _activeLayerId = layer.id;
    }
    final CanvasLayerData snapshot = layer.snapshot();
    _history.add(
      _LayerAddOperation(
        layerData: snapshot,
        insertionIndex: insertIndex,
        previousActiveLayerId: previousActive,
        nextActiveLayerId: _activeLayerId,
      ),
    );
    _redo.clear();
    return snapshot;
  }

  bool removeLayer(String id) {
    if (_layers.length <= 1) {
      return false;
    }
    final int index = _layers.indexWhere((layer) => layer.id == id);
    if (index < 0) {
      return false;
    }
    final _Layer removed = _layers.removeAt(index);
    final String? previousActive = _activeLayerId;
    if (_activeLayerId == id) {
      _activeLayerId = _findFallbackActiveLayer(exclude: id);
      _currentStroke = null;
      _currentStrokeLayerId = null;
    }
    final String? nextActive = _activeLayerId;
    _history.add(
      _LayerRemoveOperation(
        layerData: removed.snapshot(),
        removalIndex: index,
        previousActiveLayerId: previousActive,
        nextActiveLayerId: nextActive,
      ),
    );
    _redo.clear();
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
    _history.add(
      _LayerReorderOperation(
        layerId: layer.id,
        fromIndex: fromIndex,
        toIndex: toIndex,
      ),
    );
    _redo.clear();
    return true;
  }

  bool updateLayerVisibility(String id, bool visible) {
    final _Layer? layer = _layerById(id);
    if (layer == null) {
      return false;
    }
    final bool previousVisible = layer.visible;
    if (previousVisible == visible) {
      return false;
    }
    final String? previousActive = _activeLayerId;
    layer.visible = visible;
    if (!visible && _activeLayerId == id) {
      _activeLayerId = _findFallbackActiveLayer(exclude: id);
    } else if (visible && _activeLayerId == null) {
      _activeLayerId = id;
    }
    if (!visible && _currentStrokeLayerId == id) {
      _currentStroke = null;
      _currentStrokeLayerId = null;
    }
    final String? nextActive = _activeLayerId;
    _history.add(
      _LayerVisibilityOperation(
        layerId: id,
        previousVisible: previousVisible,
        nextVisible: visible,
        previousActiveLayerId: previousActive,
        nextActiveLayerId: nextActive,
      ),
    );
    _redo.clear();
    return true;
  }

  bool setLayerFillColor(String id, Color color) {
    final _Layer? layer = _layerById(id);
    if (layer == null) {
      return false;
    }
    final Color? previousColor = layer.fillColor;
    if (previousColor == color) {
      return false;
    }
    layer.fillColor = color;
    _history.add(
      _LayerFillOperation(
        layerId: id,
        previousColor: previousColor,
        nextColor: color,
      ),
    );
    _redo.clear();
    return true;
  }

  bool clearLayerFillColor(String id) {
    final _Layer? layer = _layerById(id);
    if (layer == null) {
      return false;
    }
    if (layer.fillColor == null) {
      return false;
    }
    final Color? previousColor = layer.fillColor;
    layer.fillColor = null;
    _history.add(
      _LayerFillOperation(
        layerId: id,
        previousColor: previousColor,
        nextColor: null,
      ),
    );
    _redo.clear();
    return true;
  }

  void startStroke(
    Offset point, {
    required Color color,
    required double width,
  }) {
    final _Layer layer = _ensureActiveStrokeLayer();
    _redo.clear();
    final CanvasStroke stroke = CanvasStroke(
      color: color,
      width: width,
      points: <Offset>[point],
    );
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
      final _Layer? layer = _layerById(_currentStrokeLayerId!);
      if (layer != null) {
        final int index = layer.strokes.length - 1;
        _history.add(
          _StrokeDrawOperation(
            layerId: _currentStrokeLayerId!,
            stroke: _currentStroke!,
            index: index,
          ),
        );
        _redo.clear();
      }
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
      _redo.add(
        _StrokeDrawOperation(
          layerId: layer.id,
          stroke: stroke,
          index: layer.strokes.length,
        ),
      );
      _currentStroke = null;
      _currentStrokeLayerId = null;
      return true;
    }
    if (_history.isEmpty) {
      return false;
    }
    final _Operation operation = _history.removeLast();
    if (!operation.undo(this)) {
      _history.add(operation);
      return false;
    }
    _redo.add(operation);
    return true;
  }

  bool redo() {
    if (_redo.isEmpty) {
      return false;
    }
    final _Operation operation = _redo.removeLast();
    if (!operation.redo(this)) {
      _redo.add(operation);
      return false;
    }
    _history.add(operation);
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

  bool _moveLayer(String layerId, int fromIndex, int toIndex) {
    final int currentIndex = _layers.indexWhere((layer) => layer.id == layerId);
    if (currentIndex < 0) {
      return false;
    }
    final _Layer layer = _layers.removeAt(currentIndex);
    final int clampedIndex = toIndex.clamp(0, _layers.length).toInt();
    _layers.insert(clampedIndex, layer);
    return true;
  }

  String? _findFallbackActiveLayer({String? exclude}) {
    for (final _Layer layer in _layers.reversed) {
      if (layer.id == exclude) {
        continue;
      }
      if (layer.visible) {
        return layer.id;
      }
    }
    for (final _Layer layer in _layers.reversed) {
      if (layer.id == exclude) {
        continue;
      }
      return layer.id;
    }
    return _layers.isEmpty ? null : _layers.last.id;
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

abstract class _Operation {
  bool undo(StrokeStore store);
  bool redo(StrokeStore store);
}

class _StrokeDrawOperation extends _Operation {
  _StrokeDrawOperation({
    required this.layerId,
    required CanvasStroke stroke,
    required this.index,
  }) : stroke = stroke.clone();

  final String layerId;
  final CanvasStroke stroke;
  final int index;

  @override
  bool undo(StrokeStore store) {
    final _Layer? layer = store._layerById(layerId);
    if (layer == null || layer.strokes.isEmpty) {
      return false;
    }
    final int targetIndex = index.clamp(0, layer.strokes.length - 1).toInt();
    if (targetIndex >= 0 && targetIndex < layer.strokes.length) {
      layer.strokes.removeAt(targetIndex);
      return true;
    }
    return false;
  }

  @override
  bool redo(StrokeStore store) {
    final _Layer? layer = store._layerById(layerId);
    if (layer == null) {
      return false;
    }
    final int insertIndex = index.clamp(0, layer.strokes.length).toInt();
    layer.strokes.insert(insertIndex, stroke.clone());
    return true;
  }
}

class _LayerAddOperation extends _Operation {
  _LayerAddOperation({
    required this.layerData,
    required this.insertionIndex,
    required this.previousActiveLayerId,
    required this.nextActiveLayerId,
  });

  final CanvasLayerData layerData;
  final int insertionIndex;
  final String? previousActiveLayerId;
  final String? nextActiveLayerId;

  @override
  bool undo(StrokeStore store) {
    final int index = store._layers.indexWhere(
      (layer) => layer.id == layerData.id,
    );
    if (index < 0) {
      return false;
    }
    store._layers.removeAt(index);
    store._activeLayerId = previousActiveLayerId;
    if (store._activeLayerId == null && store._layers.isNotEmpty) {
      store._activeLayerId = store._layers.last.id;
    }
    if (store._currentStrokeLayerId == layerData.id) {
      store._currentStroke = null;
      store._currentStrokeLayerId = null;
    }
    return true;
  }

  @override
  bool redo(StrokeStore store) {
    final int existingIndex = store._layers.indexWhere(
      (layer) => layer.id == layerData.id,
    );
    if (existingIndex >= 0) {
      store._layers.removeAt(existingIndex);
    }
    final int index = insertionIndex.clamp(0, store._layers.length).toInt();
    store._layers.insert(index, _Layer.fromData(layerData));
    store._activeLayerId = nextActiveLayerId ?? store._activeLayerId;
    return true;
  }
}

class _LayerRemoveOperation extends _Operation {
  _LayerRemoveOperation({
    required this.layerData,
    required this.removalIndex,
    required this.previousActiveLayerId,
    required this.nextActiveLayerId,
  });

  final CanvasLayerData layerData;
  final int removalIndex;
  final String? previousActiveLayerId;
  final String? nextActiveLayerId;

  @override
  bool undo(StrokeStore store) {
    if (store._layers.any((layer) => layer.id == layerData.id)) {
      return false;
    }
    final int index = removalIndex.clamp(0, store._layers.length).toInt();
    store._layers.insert(index, _Layer.fromData(layerData));
    store._activeLayerId = previousActiveLayerId ?? store._activeLayerId;
    if (store._activeLayerId == null) {
      store._activeLayerId = layerData.id;
    }
    return true;
  }

  @override
  bool redo(StrokeStore store) {
    final int index = store._layers.indexWhere(
      (layer) => layer.id == layerData.id,
    );
    if (index < 0 || store._layers.length <= 1) {
      return false;
    }
    store._layers.removeAt(index);
    store._activeLayerId =
        nextActiveLayerId ??
        store._findFallbackActiveLayer(exclude: layerData.id);
    if (store._currentStrokeLayerId == layerData.id) {
      store._currentStroke = null;
      store._currentStrokeLayerId = null;
    }
    return true;
  }
}

class _LayerReorderOperation extends _Operation {
  _LayerReorderOperation({
    required this.layerId,
    required this.fromIndex,
    required this.toIndex,
  });

  final String layerId;
  final int fromIndex;
  final int toIndex;

  @override
  bool undo(StrokeStore store) {
    return store._moveLayer(layerId, toIndex, fromIndex);
  }

  @override
  bool redo(StrokeStore store) {
    return store._moveLayer(layerId, fromIndex, toIndex);
  }
}

class _LayerVisibilityOperation extends _Operation {
  _LayerVisibilityOperation({
    required this.layerId,
    required this.previousVisible,
    required this.nextVisible,
    required this.previousActiveLayerId,
    required this.nextActiveLayerId,
  });

  final String layerId;
  final bool previousVisible;
  final bool nextVisible;
  final String? previousActiveLayerId;
  final String? nextActiveLayerId;

  @override
  bool undo(StrokeStore store) {
    final _Layer? layer = store._layerById(layerId);
    if (layer == null) {
      return false;
    }
    layer.visible = previousVisible;
    store._activeLayerId = previousActiveLayerId;
    if (store._activeLayerId == null) {
      store._activeLayerId = store._findFallbackActiveLayer();
    }
    if (!previousVisible && store._currentStrokeLayerId == layerId) {
      store._currentStroke = null;
      store._currentStrokeLayerId = null;
    }
    return true;
  }

  @override
  bool redo(StrokeStore store) {
    final _Layer? layer = store._layerById(layerId);
    if (layer == null) {
      return false;
    }
    layer.visible = nextVisible;
    store._activeLayerId = nextActiveLayerId ?? store._activeLayerId;
    if (!nextVisible && store._activeLayerId == layerId) {
      store._activeLayerId = store._findFallbackActiveLayer(exclude: layerId);
    }
    if (!nextVisible && store._currentStrokeLayerId == layerId) {
      store._currentStroke = null;
      store._currentStrokeLayerId = null;
    }
    return true;
  }
}

class _LayerFillOperation extends _Operation {
  _LayerFillOperation({
    required this.layerId,
    required this.previousColor,
    required this.nextColor,
  });

  final String layerId;
  final Color? previousColor;
  final Color? nextColor;

  @override
  bool undo(StrokeStore store) {
    final _Layer? layer = store._layerById(layerId);
    if (layer == null) {
      return false;
    }
    layer.fillColor = previousColor;
    return true;
  }

  @override
  bool redo(StrokeStore store) {
    final _Layer? layer = store._layerById(layerId);
    if (layer == null) {
      return false;
    }
    layer.fillColor = nextColor;
    return true;
  }
}
