import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../canvas/canvas_layer.dart';
import 'bitmap_canvas.dart';
import 'stroke_dynamics.dart';

class BitmapLayerState {
  BitmapLayerState({
    required this.id,
    required this.name,
    required this.surface,
    this.visible = true,
    this.opacity = 1.0,
    this.locked = false,
    this.clippingMask = false,
    this.blendMode = CanvasLayerBlendMode.normal,
  });

  final String id;
  String name;
  bool visible;
  double opacity;
  bool locked;
  bool clippingMask;
  CanvasLayerBlendMode blendMode;
  final BitmapSurface surface;
}

class BitmapCanvasController extends ChangeNotifier {
  BitmapCanvasController({
    required int width,
    required int height,
    required Color backgroundColor,
    List<CanvasLayerData>? initialLayers,
  }) : _width = width,
       _height = height,
       _backgroundColor = backgroundColor {
    if (initialLayers != null && initialLayers.isNotEmpty) {
      _loadFromCanvasLayers(initialLayers, backgroundColor);
    } else {
      _initializeDefaultLayers(backgroundColor);
    }
    _scheduleCompositeRefresh();
  }

  final int _width;
  final int _height;
  Color _backgroundColor;
  final List<BitmapLayerState> _layers = <BitmapLayerState>[];
  int _activeIndex = 0;

  final List<Offset> _currentStrokePoints = <Offset>[];
  double _currentStrokeRadius = 0;
  double _currentStrokeLastRadius = 0;
  bool _currentStrokePressureEnabled = false;
  final StrokeDynamics _strokeDynamics = StrokeDynamics();
  StrokePressureProfile _strokePressureProfile =
      StrokePressureProfile.taperEnds;
  Color _currentStrokeColor = const Color(0xFF000000);

  ui.Image? _cachedImage;
  bool _compositeDirty = true;
  bool _refreshScheduled = false;
  bool _pendingFullSurface = false;
  Rect? _pendingDirtyRect;
  bool _compositeInitialized = false;
  Uint32List? _compositePixels;
  Uint8List? _compositeRgba;
  Uint8List? _selectionMask;
  Uint8List? _clipMaskBuffer;
  Uint32List? _activeLayerTranslationSnapshot;
  String? _activeLayerTranslationId;
  int _activeLayerTranslationDx = 0;
  int _activeLayerTranslationDy = 0;
  ui.Image? _activeLayerTransformImage;
  bool _activeLayerTransformPreparing = false;
  Rect? _activeLayerTransformBounds;
  Rect? _activeLayerTransformDirtyRegion;
  bool _pendingActiveLayerTransformCleanup = false;

  UnmodifiableListView<BitmapLayerState> get layers =>
      UnmodifiableListView<BitmapLayerState>(_layers);

  String? get activeLayerId =>
      _layers.isEmpty ? null : _layers[_activeIndex].id;

  ui.Image? get image => _cachedImage;
  Color get backgroundColor => _backgroundColor;
  int get width => _width;
  int get height => _height;
  Uint8List? get selectionMask => _selectionMask;
  bool get isActiveLayerTransforming => _activeLayerTranslationSnapshot != null;
  ui.Image? get activeLayerTransformImage => _activeLayerTransformImage;
  Offset get activeLayerTransformOffset => Offset(
    _activeLayerTranslationDx.toDouble(),
    _activeLayerTranslationDy.toDouble(),
  );
  double get activeLayerTransformOpacity => _activeLayer.opacity;
  CanvasLayerBlendMode get activeLayerTransformBlendMode =>
      _activeLayer.blendMode;
  bool get isActiveLayerTransformPendingCleanup =>
      _pendingActiveLayerTransformCleanup;

  bool get hasVisibleContent {
    for (int i = 0; i < _layers.length; i++) {
      final BitmapLayerState layer = _layers[i];
      if (i == 0) {
        continue;
      }
      if (layer.visible && !_isSurfaceEmpty(layer.surface)) {
        return true;
      }
    }
    return false;
  }

  void setSelectionMask(Uint8List? mask) {
    if (mask != null && mask.length != _width * _height) {
      throw ArgumentError('Selection mask size mismatch');
    }
    _selectionMask = mask;
  }

  void translateActiveLayer(int dx, int dy) {
    if (_pendingActiveLayerTransformCleanup) {
      return;
    }
    final BitmapLayerState layer = _activeLayer;
    if (layer.locked) {
      return;
    }
    if (_activeLayerTranslationSnapshot == null) {
      _startActiveLayerTransformSession(layer);
    }
    if (_activeLayerTranslationSnapshot == null) {
      return;
    }
    if (dx == _activeLayerTranslationDx && dy == _activeLayerTranslationDy) {
      return;
    }
    _activeLayerTranslationDx = dx;
    _activeLayerTranslationDy = dy;
    _updateActiveLayerTransformDirtyRegion();
    notifyListeners();
  }

  void commitActiveLayerTranslation() {
    if (_activeLayerTranslationSnapshot == null) {
      return;
    }
    final Rect? dirtyRegion = _activeLayerTransformDirtyRegion;
    _applyActiveLayerTranslation();
    _pendingActiveLayerTransformCleanup = true;
    if (dirtyRegion != null) {
      _markDirty(region: dirtyRegion);
    } else {
      _markDirty();
    }
  }

  void cancelActiveLayerTranslation() {
    if (_activeLayerTranslationSnapshot == null) {
      return;
    }
    final Rect? dirtyRegion = _activeLayerTransformDirtyRegion;
    _restoreActiveLayerSnapshot();
    _pendingActiveLayerTransformCleanup = true;
    if (dirtyRegion != null) {
      _markDirty(region: dirtyRegion);
    } else {
      _markDirty();
    }
  }

  Uint32List _ensureTranslationSnapshot(String layerId, Uint32List pixels) {
    final Uint32List? existing = _activeLayerTranslationSnapshot;
    if (existing != null && _activeLayerTranslationId == layerId) {
      return existing;
    }
    final Uint32List snapshot = Uint32List.fromList(pixels);
    _activeLayerTranslationSnapshot = snapshot;
    _activeLayerTranslationId = layerId;
    _activeLayerTranslationDx = 0;
    _activeLayerTranslationDy = 0;
    return snapshot;
  }

  void _startActiveLayerTransformSession(BitmapLayerState layer) {
    if (_pendingActiveLayerTransformCleanup) {
      return;
    }
    final Uint32List snapshot = _ensureTranslationSnapshot(
      layer.id,
      layer.surface.pixels,
    );
    final int width = layer.surface.width;
    final int height = layer.surface.height;
    final Rect? bounds = _computePixelBounds(snapshot, width, height);
    _activeLayerTransformBounds = bounds;
    _activeLayerTransformDirtyRegion = bounds;
    layer.surface.pixels.fillRange(0, layer.surface.pixels.length, 0);
    if (bounds != null) {
      _markDirty(region: bounds);
    } else {
      _markDirty();
    }
    _prepareActiveLayerTransformPreview(layer, snapshot);
  }

  Rect? _computePixelBounds(Uint32List pixels, int width, int height) {
    int minX = width;
    int minY = height;
    int maxX = -1;
    int maxY = -1;
    for (int y = 0; y < height; y++) {
      final int rowOffset = y * width;
      for (int x = 0; x < width; x++) {
        final int argb = pixels[rowOffset + x];
        if ((argb >> 24) == 0) {
          continue;
        }
        if (x < minX) {
          minX = x;
        }
        if (x > maxX) {
          maxX = x;
        }
        if (y < minY) {
          minY = y;
        }
        if (y > maxY) {
          maxY = y;
        }
      }
    }
    if (maxX < minX || maxY < minY) {
      return null;
    }
    return Rect.fromLTRB(
      minX.toDouble(),
      minY.toDouble(),
      (maxX + 1).toDouble(),
      (maxY + 1).toDouble(),
    );
  }

  void _prepareActiveLayerTransformPreview(
    BitmapLayerState layer,
    Uint32List snapshot,
  ) {
    if (_activeLayerTransformPreparing) {
      return;
    }
    _activeLayerTransformPreparing = true;
    final Uint8List rgba = _pixelsToRgba(snapshot);
    _activeLayerTransformImage?.dispose();
    ui.decodeImageFromPixels(
      rgba,
      layer.surface.width,
      layer.surface.height,
      ui.PixelFormat.rgba8888,
      (ui.Image image) {
        if (_activeLayerTranslationSnapshot == null ||
            _activeLayerTranslationId != layer.id) {
          _activeLayerTransformPreparing = false;
          image.dispose();
          return;
        }
        _activeLayerTransformImage?.dispose();
        _activeLayerTransformImage = image;
        _activeLayerTransformPreparing = false;
        notifyListeners();
      },
    );
  }

  void _applyActiveLayerTranslation() {
    final Uint32List? snapshot = _activeLayerTranslationSnapshot;
    final String? id = _activeLayerTranslationId;
    if (snapshot == null || id == null) {
      return;
    }
    final BitmapLayerState layer = _layers.firstWhere(
      (candidate) => candidate.id == id,
      orElse: () => _activeLayer,
    );
    final BitmapSurface surface = layer.surface;
    final Uint32List target = surface.pixels;
    final int width = surface.width;
    final int height = surface.height;
    target.fillRange(0, target.length, 0);
    final int dx = _activeLayerTranslationDx;
    final int dy = _activeLayerTranslationDy;
    for (int y = 0; y < height; y++) {
      final int destY = y + dy;
      if (destY < 0 || destY >= height) {
        continue;
      }
      final int srcOffset = y * width;
      final int dstOffset = destY * width;
      for (int x = 0; x < width; x++) {
        final int destX = x + dx;
        if (destX < 0 || destX >= width) {
          continue;
        }
        target[dstOffset + destX] = snapshot[srcOffset + x];
      }
    }
  }

  void _restoreActiveLayerSnapshot() {
    final Uint32List? snapshot = _activeLayerTranslationSnapshot;
    final String? id = _activeLayerTranslationId;
    if (snapshot == null || id == null) {
      return;
    }
    final BitmapLayerState layer = _layers.firstWhere(
      (candidate) => candidate.id == id,
      orElse: () => _activeLayer,
    );
    layer.surface.pixels.setAll(0, snapshot);
  }

  void _updateActiveLayerTransformDirtyRegion() {
    final Rect? baseBounds = _activeLayerTransformBounds;
    if (baseBounds == null) {
      return;
    }
    final Rect current = baseBounds.shift(
      Offset(
        _activeLayerTranslationDx.toDouble(),
        _activeLayerTranslationDy.toDouble(),
      ),
    );
    final Rect? existing = _activeLayerTransformDirtyRegion;
    if (existing == null) {
      _activeLayerTransformDirtyRegion = current;
    } else {
      _activeLayerTransformDirtyRegion = _unionRects(existing, current);
    }
  }

  void _resetActiveLayerTranslationState() {
    _activeLayerTranslationSnapshot = null;
    _activeLayerTranslationId = null;
    _activeLayerTranslationDx = 0;
    _activeLayerTranslationDy = 0;
    _disposeActiveLayerTransformImage();
    _activeLayerTransformPreparing = false;
    _activeLayerTransformBounds = null;
    _activeLayerTransformDirtyRegion = null;
    _pendingActiveLayerTransformCleanup = false;
  }

  void _disposeActiveLayerTransformImage() {
    _activeLayerTransformImage?.dispose();
    _activeLayerTransformImage = null;
  }

  Future<void> disposeController() async {
    _cachedImage?.dispose();
    _cachedImage = null;
    _disposeActiveLayerTransformImage();
    _activeLayerTransformPreparing = false;
  }

  void setActiveLayer(String id) {
    final int index = _layers.indexWhere((layer) => layer.id == id);
    if (index < 0 || index == _activeIndex) {
      return;
    }
    _activeIndex = index;
    notifyListeners();
  }

  void updateLayerVisibility(String id, bool visible) {
    final int index = _layers.indexWhere((layer) => layer.id == id);
    if (index < 0) {
      return;
    }
    _layers[index].visible = visible;
    if (!visible && _activeIndex == index) {
      _activeIndex = _findFallbackActiveIndex(exclude: index);
    }
    _markDirty();
  }

  void setLayerOpacity(String id, double opacity) {
    final int index = _layers.indexWhere((layer) => layer.id == id);
    if (index < 0) {
      return;
    }
    final double clamped = _clampUnit(opacity);
    final BitmapLayerState layer = _layers[index];
    if ((layer.opacity - clamped).abs() < 1e-4) {
      return;
    }
    layer.opacity = clamped;
    _markDirty();
    notifyListeners();
  }

  void setLayerLocked(String id, bool locked) {
    final int index = _layers.indexWhere((layer) => layer.id == id);
    if (index < 0) {
      return;
    }
    final BitmapLayerState layer = _layers[index];
    if (layer.locked == locked) {
      return;
    }
    layer.locked = locked;
    notifyListeners();
  }

  void setLayerClippingMask(String id, bool clippingMask) {
    final int index = _layers.indexWhere((layer) => layer.id == id);
    if (index < 0) {
      return;
    }
    final BitmapLayerState layer = _layers[index];
    if (layer.clippingMask == clippingMask) {
      return;
    }
    layer.clippingMask = clippingMask;
    _markDirty();
    notifyListeners();
  }

  void setLayerBlendMode(String id, CanvasLayerBlendMode mode) {
    final int index = _layers.indexWhere((layer) => layer.id == id);
    if (index < 0) {
      return;
    }
    final BitmapLayerState layer = _layers[index];
    if (layer.blendMode == mode) {
      return;
    }
    layer.blendMode = mode;
    _markDirty();
    notifyListeners();
  }

  void renameLayer(String id, String name) {
    final int index = _layers.indexWhere((layer) => layer.id == id);
    if (index < 0) {
      return;
    }
    _layers[index].name = name;
    notifyListeners();
  }

  void addLayer({String? aboveLayerId, String? name}) {
    final BitmapLayerState layer = BitmapLayerState(
      id: generateLayerId(),
      name: name ?? '图层 ${_layers.length + 1}',
      surface: BitmapSurface(width: _width, height: _height),
    );
    int insertIndex = _layers.length;
    if (aboveLayerId != null) {
      final int index = _layers.indexWhere(
        (element) => element.id == aboveLayerId,
      );
      if (index >= 0) {
        insertIndex = index + 1;
      }
    }
    _layers.insert(insertIndex, layer);
    _activeIndex = insertIndex;
    _markDirty();
  }

  void removeLayer(String id) {
    if (_layers.length <= 1) {
      return;
    }
    final int index = _layers.indexWhere((layer) => layer.id == id);
    if (index < 0) {
      return;
    }
    _layers.removeAt(index);
    if (_activeIndex >= _layers.length) {
      _activeIndex = _layers.length - 1;
    }
    _markDirty();
  }

  void reorderLayer(int fromIndex, int toIndex) {
    if (fromIndex < 0 || fromIndex >= _layers.length) {
      return;
    }
    int target = toIndex;
    if (target > fromIndex) {
      target -= 1;
    }
    target = target.clamp(0, _layers.length - 1);
    final BitmapLayerState layer = _layers.removeAt(fromIndex);
    _layers.insert(target, layer);
    if (_activeIndex == fromIndex) {
      _activeIndex = target;
    } else if (fromIndex < _activeIndex && target >= _activeIndex) {
      _activeIndex -= 1;
    } else if (fromIndex > _activeIndex && target <= _activeIndex) {
      _activeIndex += 1;
    }
    _markDirty();
  }

  void clear() {
    for (int i = 0; i < _layers.length; i++) {
      final BitmapLayerState layer = _layers[i];
      if (layer.locked) {
        continue;
      }
      if (i == 0) {
        layer.surface.fill(_backgroundColor);
      } else {
        layer.surface.fill(const Color(0x00000000));
      }
    }
    _markDirty();
  }

  void beginStroke(
    Offset position, {
    required Color color,
    required double radius,
    bool simulatePressure = false,
    StrokePressureProfile profile = StrokePressureProfile.taperEnds,
  }) {
    if (_activeLayer.locked) {
      return;
    }
    if (_selectionMask != null && !_selectionAllows(position)) {
      return;
    }
    setStrokePressureProfile(profile);
    _currentStrokePoints
      ..clear()
      ..add(position);
    _currentStrokeRadius = radius;
    _currentStrokePressureEnabled = simulatePressure;
    if (_currentStrokePressureEnabled) {
      _strokeDynamics.start(radius, profile: _strokePressureProfile);
      _currentStrokeLastRadius = _strokeDynamics.initialRadius();
    } else {
      _currentStrokeLastRadius = _currentStrokeRadius;
    }
    _currentStrokeColor = color;
    _drawPoint(position, _currentStrokeLastRadius);
  }

  void extendStroke(Offset position, {double? deltaTimeMillis}) {
    if (_currentStrokePoints.isEmpty) {
      return;
    }
    if (_activeLayer.locked) {
      return;
    }
    final Offset last = _currentStrokePoints.last;
    _currentStrokePoints.add(position);
    if (_currentStrokePressureEnabled) {
      final double delta = (position - last).distance;
      final double nextRadius = _strokeDynamics.sample(
        distance: delta,
        deltaTimeMillis: deltaTimeMillis,
      );
      _activeSurface.drawVariableLine(
        a: last,
        b: position,
        startRadius: _currentStrokeLastRadius,
        endRadius: nextRadius,
        color: _currentStrokeColor,
        mask: _selectionMask,
      );
      _markDirty(
        region: _dirtyRectForVariableLine(
          last,
          position,
          _currentStrokeLastRadius,
          nextRadius,
        ),
      );
      _currentStrokeLastRadius = nextRadius;
    } else {
      _activeSurface.drawLine(
        a: last,
        b: position,
        radius: _currentStrokeRadius,
        color: _currentStrokeColor,
        mask: _selectionMask,
      );
      _markDirty(
        region: _dirtyRectForLine(last, position, _currentStrokeRadius),
      );
    }
  }

  void endStroke() {
    if (_currentStrokePressureEnabled && _currentStrokePoints.isNotEmpty) {
      final Offset tip = _currentStrokePoints.last;
      if (_currentStrokePoints.length >= 2) {
        final Offset prev =
            _currentStrokePoints[_currentStrokePoints.length - 2];
        final Offset direction = tip - prev;
        final double length = direction.distance;
        if (length > 0.001) {
          final Offset unit = direction / length;
          final double base = math.max(_currentStrokeRadius, 0.1);
          final double taperLength = math.min(base * 6.5, length * 2.4 + 2.0);
          final Offset extension = tip + unit * taperLength;
          final double tipRadius = _strokeDynamics.tipRadius();
          final bool taperEnds =
              _strokePressureProfile == StrokePressureProfile.taperEnds;
          final double startRadius = taperEnds
              ? math.max(_currentStrokeLastRadius, _currentStrokeRadius)
              : math.min(_currentStrokeLastRadius, _currentStrokeRadius);
          _activeSurface.drawVariableLine(
            a: tip,
            b: extension,
            startRadius: startRadius,
            endRadius: tipRadius,
            color: _currentStrokeColor,
            mask: _selectionMask,
          );
          _markDirty(
            region: _dirtyRectForVariableLine(
              tip,
              extension,
              startRadius,
              tipRadius,
            ),
          );
        } else {
          _drawPoint(tip, _strokeDynamics.tipRadius());
        }
      } else {
        _drawPoint(tip, _strokeDynamics.tipRadius());
      }
    }

    _currentStrokePoints.clear();
    _currentStrokeRadius = 0;
    _currentStrokeLastRadius = 0;
    _currentStrokePressureEnabled = false;
  }

  void setStrokePressureProfile(StrokePressureProfile profile) {
    if (_strokePressureProfile == profile) {
      return;
    }
    _strokePressureProfile = profile;
    _strokeDynamics.configure(profile: profile);
  }

  bool _selectionAllows(Offset position) {
    final Uint8List? mask = _selectionMask;
    if (mask == null) {
      return true;
    }
    final int x = position.dx.floor();
    final int y = position.dy.floor();
    if (x < 0 || x >= _width || y < 0 || y >= _height) {
      return false;
    }
    return mask[y * _width + x] != 0;
  }

  bool _selectionAllowsInt(int x, int y) {
    final Uint8List? mask = _selectionMask;
    if (mask == null) {
      return true;
    }
    if (x < 0 || x >= _width || y < 0 || y >= _height) {
      return false;
    }
    return mask[y * _width + x] != 0;
  }

  void floodFill(
    Offset position, {
    required Color color,
    bool contiguous = true,
    bool sampleAllLayers = false,
  }) {
    if (_activeLayer.locked) {
      return;
    }
    final int x = position.dx.floor();
    final int y = position.dy.floor();
    if (x < 0 || x >= _width || y < 0 || y >= _height) {
      return;
    }
    if (!_selectionAllowsInt(x, y)) {
      return;
    }
    Color? baseColor;
    if (sampleAllLayers) {
      _floodFillAcrossLayers(x, y, color, contiguous);
      return;
    } else {
      baseColor = _colorAtSurface(_activeSurface, x, y);
    }
    _activeSurface.floodFill(
      start: Offset(x.toDouble(), y.toDouble()),
      color: color,
      targetColor: baseColor,
      contiguous: contiguous,
      mask: _selectionMask,
    );
    _markDirty();
  }

  Uint8List? computeMagicWandMask(
    Offset position, {
    bool sampleAllLayers = true,
  }) {
    final int x = position.dx.floor();
    final int y = position.dy.floor();
    if (x < 0 || x >= _width || y < 0 || y >= _height) {
      return null;
    }
    final Uint8List mask = Uint8List(_width * _height);
    if (sampleAllLayers) {
      _updateComposite(requiresFullSurface: true, region: null);
      final Uint32List? composite = _compositePixels;
      if (composite == null || composite.isEmpty) {
        return null;
      }
      final int target = composite[y * _width + x];
      final bool filled = _floodFillMask(
        pixels: composite,
        targetColor: target,
        mask: mask,
        startX: x,
        startY: y,
      );
      if (!filled) {
        return null;
      }
      return mask;
    }

    final Uint32List pixels = _activeSurface.pixels;
    final int target = pixels[y * _width + x];
    final bool filled = _floodFillMask(
      pixels: pixels,
      targetColor: target,
      mask: mask,
      startX: x,
      startY: y,
    );
    if (!filled) {
      return null;
    }
    return mask;
  }

  List<CanvasLayerData> snapshotLayers() {
    final List<CanvasLayerData> result = <CanvasLayerData>[];
    for (int i = 0; i < _layers.length; i++) {
      final BitmapLayerState layer = _layers[i];
      Uint8List? bitmap;
      if (!_isSurfaceEmpty(layer.surface)) {
        bitmap = _surfaceToRgba(layer.surface);
      }
      result.add(
        CanvasLayerData(
          id: layer.id,
          name: layer.name,
          visible: layer.visible,
          opacity: layer.opacity,
          locked: layer.locked,
          clippingMask: layer.clippingMask,
          blendMode: layer.blendMode,
          fillColor: i == 0 ? _backgroundColor : null,
          bitmap: bitmap,
          bitmapWidth: bitmap != null ? _width : null,
          bitmapHeight: bitmap != null ? _height : null,
        ),
      );
    }
    return result;
  }

  CanvasLayerData? buildClipboardLayer(String id, {Uint8List? mask}) {
    final int index = _layers.indexWhere((layer) => layer.id == id);
    if (index < 0) {
      return null;
    }
    final BitmapLayerState layer = _layers[index];
    Uint8List? effectiveMask;
    if (mask != null) {
      if (mask.length != _width * _height) {
        throw ArgumentError('Selection mask size mismatch');
      }
      if (!_maskHasCoverage(mask)) {
        return null;
      }
      effectiveMask = Uint8List.fromList(mask);
    }
    final Uint8List bitmap = effectiveMask == null
        ? _surfaceToRgba(layer.surface)
        : _surfaceToMaskedRgba(layer.surface, effectiveMask);
    return CanvasLayerData(
      id: layer.id,
      name: layer.name,
      visible: true,
      opacity: layer.opacity,
      locked: false,
      clippingMask: false,
      blendMode: layer.blendMode,
      fillColor: null,
      bitmap: bitmap,
      bitmapWidth: _width,
      bitmapHeight: _height,
    );
  }

  void clearLayerRegion(String id, {Uint8List? mask}) {
    final int index = _layers.indexWhere((layer) => layer.id == id);
    if (index < 0) {
      return;
    }
    final BitmapLayerState layer = _layers[index];
    final Uint32List pixels = layer.surface.pixels;
    final int replacement = index == 0
        ? BitmapSurface.encodeColor(_backgroundColor)
        : 0;
    if (mask == null) {
      for (int i = 0; i < pixels.length; i++) {
        pixels[i] = replacement;
      }
      _markDirty();
      return;
    }
    if (mask.length != _width * _height) {
      throw ArgumentError('Selection mask size mismatch');
    }
    int minX = _width;
    int minY = _height;
    int maxX = -1;
    int maxY = -1;
    for (int y = 0; y < _height; y++) {
      final int rowOffset = y * _width;
      for (int x = 0; x < _width; x++) {
        final int indexInMask = rowOffset + x;
        if (mask[indexInMask] == 0) {
          continue;
        }
        pixels[indexInMask] = replacement;
        if (x < minX) {
          minX = x;
        }
        if (x > maxX) {
          maxX = x;
        }
        if (y < minY) {
          minY = y;
        }
        if (y > maxY) {
          maxY = y;
        }
      }
    }
    if (maxX < minX || maxY < minY) {
      return;
    }
    _markDirty(
      region: Rect.fromLTRB(
        minX.toDouble(),
        minY.toDouble(),
        (maxX + 1).toDouble(),
        (maxY + 1).toDouble(),
      ),
    );
  }

  String insertLayerFromData(CanvasLayerData data, {String? aboveLayerId}) {
    final BitmapSurface surface = BitmapSurface(width: _width, height: _height);
    if (data.bitmap != null &&
        data.bitmapWidth == _width &&
        data.bitmapHeight == _height) {
      _writeRgbaToSurface(surface, data.bitmap!);
    } else if (data.fillColor != null) {
      surface.fill(data.fillColor!);
    } else {
      surface.fill(const Color(0x00000000));
    }
    final BitmapLayerState layer = BitmapLayerState(
      id: data.id,
      name: data.name,
      surface: surface,
      visible: true,
      opacity: data.opacity,
      locked: false,
      clippingMask: false,
      blendMode: data.blendMode,
    );
    int insertIndex = _layers.length;
    if (aboveLayerId != null) {
      final int index = _layers.indexWhere(
        (candidate) => candidate.id == aboveLayerId,
      );
      if (index >= 0) {
        insertIndex = index + 1;
      }
    }
    _layers.insert(insertIndex, layer);
    _activeIndex = insertIndex;
    _markDirty();
    return layer.id;
  }

  void loadLayers(List<CanvasLayerData> layers, Color backgroundColor) {
    _layers.clear();
    _clipMaskBuffer = null;
    _loadFromCanvasLayers(layers, backgroundColor);
    _markDirty();
  }

  void _updateComposite({required bool requiresFullSurface, Rect? region}) {
    _ensureCompositeBuffers();
    final _IntRect area = requiresFullSurface
        ? _IntRect(0, 0, _width, _height)
        : _clipRectToSurface(region!);
    if (area.isEmpty) {
      return;
    }

    final Uint32List composite = _compositePixels!;
    final Uint8List rgba = _compositeRgba!;
    final List<BitmapLayerState> layers = _layers;
    final int width = _width;
    final Uint8List clipMask = _ensureClipMask();
    clipMask.fillRange(0, clipMask.length, 0);

    final String? translatingLayerId =
        _activeLayerTranslationSnapshot != null &&
            !_pendingActiveLayerTransformCleanup
        ? _activeLayerTranslationId
        : null;

    for (int y = area.top; y < area.bottom; y++) {
      final int rowOffset = y * width;
      for (int x = area.left; x < area.right; x++) {
        final int index = rowOffset + x;
        int color = 0;
        bool initialized = false;
        for (final BitmapLayerState layer in layers) {
          if (!layer.visible) {
            continue;
          }
          if (translatingLayerId != null && layer.id == translatingLayerId) {
            continue;
          }
          final double rawOpacity = layer.opacity;
          final double layerOpacity = _clampUnit(rawOpacity);
          if (layerOpacity <= 0) {
            if (!layer.clippingMask) {
              clipMask[index] = 0;
            }
            continue;
          }
          final int src = layer.surface.pixels[index];
          final int srcA = (src >> 24) & 0xff;
          if (!layer.clippingMask && (srcA == 0)) {
            clipMask[index] = 0;
          }
          if (srcA == 0) {
            continue;
          }

          double totalOpacity = layerOpacity;
          if (layer.clippingMask) {
            final int maskAlpha = clipMask[index];
            if (maskAlpha == 0) {
              continue;
            }
            totalOpacity *= maskAlpha / 255.0;
            if (totalOpacity <= 0) {
              continue;
            }
          }

          int effectiveA = (srcA * totalOpacity).round();
          if (effectiveA <= 0) {
            if (!layer.clippingMask) {
              clipMask[index] = 0;
            }
            continue;
          }
          effectiveA = effectiveA.clamp(0, 255);

          if (!layer.clippingMask) {
            clipMask[index] = effectiveA;
          }

          final int effectiveColor = (effectiveA << 24) | (src & 0x00FFFFFF);
          if (!initialized) {
            color = effectiveColor;
            initialized = true;
          } else {
            color = _blendWithMode(color, effectiveColor, layer.blendMode);
          }
        }

        if (!initialized) {
          composite[index] = 0;
          final int rgbaOffset = index * 4;
          rgba[rgbaOffset] = 0;
          rgba[rgbaOffset + 1] = 0;
          rgba[rgbaOffset + 2] = 0;
          rgba[rgbaOffset + 3] = 0;
          continue;
        }

        composite[index] = color;
        final int rgbaOffset = index * 4;
        rgba[rgbaOffset] = (color >> 16) & 0xff;
        rgba[rgbaOffset + 1] = (color >> 8) & 0xff;
        rgba[rgbaOffset + 2] = color & 0xff;
        rgba[rgbaOffset + 3] = (color >> 24) & 0xff;
      }
    }

    if (requiresFullSurface) {
      _compositeInitialized = true;
    }
  }

  void _initializeDefaultLayers(Color backgroundColor) {
    final BitmapSurface background = BitmapSurface(
      width: _width,
      height: _height,
      fillColor: backgroundColor,
    );
    final BitmapSurface paintSurface = BitmapSurface(
      width: _width,
      height: _height,
    );
    _layers
      ..add(
        BitmapLayerState(
          id: generateLayerId(),
          name: '背景',
          surface: background,
        ),
      )
      ..add(
        BitmapLayerState(
          id: generateLayerId(),
          name: '图层 2',
          surface: paintSurface,
        ),
      );
    _activeIndex = _layers.length - 1;
  }

  void _loadFromCanvasLayers(
    List<CanvasLayerData> layers,
    Color backgroundColor,
  ) {
    _backgroundColor = backgroundColor;
    if (layers.isEmpty) {
      _initializeDefaultLayers(backgroundColor);
      return;
    }
    for (final CanvasLayerData layer in layers) {
      final BitmapSurface surface = BitmapSurface(
        width: _width,
        height: _height,
      );
      if (layer.bitmap != null &&
          layer.bitmapWidth == _width &&
          layer.bitmapHeight == _height) {
        _writeRgbaToSurface(surface, layer.bitmap!);
      } else if (layer.fillColor != null) {
        surface.fill(layer.fillColor!);
      }
      _layers.add(
        BitmapLayerState(
          id: layer.id,
          name: layer.name,
          visible: layer.visible,
          opacity: layer.opacity,
          locked: layer.locked,
          clippingMask: layer.clippingMask,
          blendMode: layer.blendMode,
          surface: surface,
        ),
      );
      if (layer == layers.first && layer.fillColor != null) {
        _backgroundColor = layer.fillColor!;
      }
    }
    _activeIndex = _layers.length - 1;
  }

  void _drawPoint(Offset position, double radius) {
    if (_activeLayer.locked) {
      return;
    }
    _activeSurface.drawCircle(
      center: position,
      radius: radius,
      color: _currentStrokeColor,
      mask: _selectionMask,
    );
    _markDirty(region: _dirtyRectForCircle(position, radius));
  }

  Rect _dirtyRectForVariableLine(
    Offset a,
    Offset b,
    double startRadius,
    double endRadius,
  ) {
    final double maxRadius = math.max(math.max(startRadius, endRadius), 0.5);
    return Rect.fromPoints(a, b).inflate(maxRadius + 1.5);
  }

  void _markDirty({Rect? region}) {
    _compositeDirty = true;
    if (region == null || _pendingFullSurface) {
      _pendingDirtyRect = null;
      _pendingFullSurface = true;
    } else if (_pendingDirtyRect == null) {
      _pendingDirtyRect = region;
    } else {
      final Rect current = _pendingDirtyRect!;
      _pendingDirtyRect = Rect.fromLTRB(
        math.min(current.left, region.left),
        math.min(current.top, region.top),
        math.max(current.right, region.right),
        math.max(current.bottom, region.bottom),
      );
    }
    _scheduleCompositeRefresh();
  }

  void _scheduleCompositeRefresh() {
    if (_refreshScheduled) {
      return;
    }
    _refreshScheduled = true;
    scheduleMicrotask(() {
      _refreshScheduled = false;
      if (!_compositeDirty) {
        return;
      }
      final Rect? dirtyRect = _pendingDirtyRect;
      final bool requiresFullSurface =
          !_compositeInitialized || _pendingFullSurface || dirtyRect == null;

      _pendingDirtyRect = null;
      _pendingFullSurface = false;

      _updateComposite(
        requiresFullSurface: requiresFullSurface,
        region: requiresFullSurface ? null : dirtyRect,
      );

      final Uint8List rgba = _compositeRgba ?? Uint8List(_width * _height * 4);
      ui.decodeImageFromPixels(rgba, _width, _height, ui.PixelFormat.rgba8888, (
        ui.Image image,
      ) {
        _cachedImage?.dispose();
        _cachedImage = image;
        if (_pendingActiveLayerTransformCleanup) {
          _pendingActiveLayerTransformCleanup = false;
          _resetActiveLayerTranslationState();
        }
        _compositeDirty = _pendingFullSurface || _pendingDirtyRect != null;
        notifyListeners();
        if (_compositeDirty && !_refreshScheduled) {
          _scheduleCompositeRefresh();
        }
      });
    });
    notifyListeners();
  }

  int _findFallbackActiveIndex({int? exclude}) {
    for (int i = _layers.length - 1; i >= 0; i--) {
      if (i == exclude) {
        continue;
      }
      if (_layers[i].visible) {
        return i;
      }
    }
    return math.max(0, math.min(_layers.length - 1, _activeIndex));
  }

  BitmapLayerState get _activeLayer => _layers[_activeIndex];

  BitmapSurface get _activeSurface => _activeLayer.surface;

  static bool _isSurfaceEmpty(BitmapSurface surface) {
    for (final int pixel in surface.pixels) {
      if ((pixel >> 24) != 0) {
        return false;
      }
    }
    return true;
  }

  Color _colorAtComposite(Offset position) {
    final int x = position.dx.floor();
    final int y = position.dy.floor();
    if (x < 0 || x >= _width || y < 0 || y >= _height) {
      return const Color(0x00000000);
    }
    final int index = y * _width + x;
    int? color;
    for (final BitmapLayerState layer in _layers) {
      if (!layer.visible) {
        continue;
      }
      if (_activeLayerTranslationSnapshot != null &&
          !_pendingActiveLayerTransformCleanup &&
          layer.id == _activeLayerTranslationId) {
        continue;
      }
      final int src = layer.surface.pixels[index];
      if (color == null) {
        color = src;
      } else {
        color = _blendArgb(color, src);
      }
    }
    return BitmapSurface.decodeColor(color ?? 0);
  }

  Color sampleColor(Offset position, {bool sampleAllLayers = true}) {
    final int x = position.dx.floor();
    final int y = position.dy.floor();
    if (x < 0 || x >= _width || y < 0 || y >= _height) {
      return const Color(0x00000000);
    }
    if (sampleAllLayers) {
      _updateComposite(requiresFullSurface: true, region: null);
      return _colorAtComposite(position);
    }
    return _colorAtSurface(_activeSurface, x, y);
  }

  void _floodFillAcrossLayers(
    int startX,
    int startY,
    Color color,
    bool contiguous,
  ) {
    if (!_selectionAllowsInt(startX, startY)) {
      return;
    }
    _updateComposite(requiresFullSurface: true, region: null);
    final Uint32List? compositePixels = _compositePixels;
    if (compositePixels == null || compositePixels.isEmpty) {
      return;
    }
    final int index = startY * _width + startX;
    if (index < 0 || index >= compositePixels.length) {
      return;
    }
    final int target = compositePixels[index];
    final int replacement = BitmapSurface.encodeColor(color);
    final Uint32List surfacePixels = _activeSurface.pixels;
    final Uint8List? mask = _selectionMask;

    if (!contiguous) {
      int minX = _width;
      int minY = _height;
      int maxX = -1;
      int maxY = -1;
      bool changed = false;
      for (int i = 0; i < compositePixels.length; i++) {
        if (compositePixels[i] != target) {
          continue;
        }
        if (mask != null && mask[i] == 0) {
          continue;
        }
        if (surfacePixels[i] == replacement) {
          continue;
        }
        surfacePixels[i] = replacement;
        changed = true;
        final int px = i % _width;
        final int py = i ~/ _width;
        if (px < minX) {
          minX = px;
        }
        if (py < minY) {
          minY = py;
        }
        if (px > maxX) {
          maxX = px;
        }
        if (py > maxY) {
          maxY = py;
        }
      }
      if (changed) {
        _markDirty(
          region: Rect.fromLTRB(
            minX.toDouble(),
            minY.toDouble(),
            (maxX + 1).toDouble(),
            (maxY + 1).toDouble(),
          ),
        );
      }
      return;
    }

    final Uint8List visited = Uint8List(compositePixels.length);
    final List<int> stack = <int>[index];
    visited[index] = 1;
    int minX = startX;
    int maxX = startX;
    int minY = startY;
    int maxY = startY;
    bool changed = false;

    while (stack.isNotEmpty) {
      final int current = stack.removeLast();
      if (compositePixels[current] != target) {
        continue;
      }
      if (mask != null && mask[current] == 0) {
        continue;
      }
      if (surfacePixels[current] != replacement) {
        surfacePixels[current] = replacement;
        changed = true;
      }
      final int cx = current % _width;
      final int cy = current ~/ _width;
      if (cx < minX) {
        minX = cx;
      }
      if (cx > maxX) {
        maxX = cx;
      }
      if (cy < minY) {
        minY = cy;
      }
      if (cy > maxY) {
        maxY = cy;
      }

      // left
      if (cx > 0) {
        final int leftIndex = current - 1;
        if (visited[leftIndex] == 0 && compositePixels[leftIndex] == target) {
          if (mask == null || mask[leftIndex] != 0) {
            visited[leftIndex] = 1;
            stack.add(leftIndex);
          }
        }
      }
      // right
      if (cx < _width - 1) {
        final int rightIndex = current + 1;
        if (visited[rightIndex] == 0 && compositePixels[rightIndex] == target) {
          if (mask == null || mask[rightIndex] != 0) {
            visited[rightIndex] = 1;
            stack.add(rightIndex);
          }
        }
      }
      // up
      if (cy > 0) {
        final int upIndex = current - _width;
        if (visited[upIndex] == 0 && compositePixels[upIndex] == target) {
          if (mask == null || mask[upIndex] != 0) {
            visited[upIndex] = 1;
            stack.add(upIndex);
          }
        }
      }
      // down
      if (cy < _height - 1) {
        final int downIndex = current + _width;
        if (visited[downIndex] == 0 && compositePixels[downIndex] == target) {
          if (mask == null || mask[downIndex] != 0) {
            visited[downIndex] = 1;
            stack.add(downIndex);
          }
        }
      }
    }

    if (changed) {
      _markDirty(
        region: Rect.fromLTRB(
          minX.toDouble(),
          minY.toDouble(),
          (maxX + 1).toDouble(),
          (maxY + 1).toDouble(),
        ),
      );
    }
  }

  Color _colorAtSurface(BitmapSurface surface, int x, int y) {
    return BitmapSurface.decodeColor(surface.pixels[y * _width + x]);
  }

  static Uint8List _surfaceToRgba(BitmapSurface surface) {
    final Uint8List rgba = Uint8List(surface.pixels.length * 4);
    for (int i = 0; i < surface.pixels.length; i++) {
      final int argb = surface.pixels[i];
      final int offset = i * 4;
      rgba[offset] = (argb >> 16) & 0xff;
      rgba[offset + 1] = (argb >> 8) & 0xff;
      rgba[offset + 2] = argb & 0xff;
      rgba[offset + 3] = (argb >> 24) & 0xff;
    }
    return rgba;
  }

  static Uint8List _pixelsToRgba(Uint32List pixels) {
    final Uint8List rgba = Uint8List(pixels.length * 4);
    for (int i = 0; i < pixels.length; i++) {
      final int argb = pixels[i];
      final int offset = i * 4;
      rgba[offset] = (argb >> 16) & 0xff;
      rgba[offset + 1] = (argb >> 8) & 0xff;
      rgba[offset + 2] = argb & 0xff;
      rgba[offset + 3] = (argb >> 24) & 0xff;
    }
    return rgba;
  }

  static Rect _unionRects(Rect a, Rect b) {
    return Rect.fromLTRB(
      math.min(a.left, b.left),
      math.min(a.top, b.top),
      math.max(a.right, b.right),
      math.max(a.bottom, b.bottom),
    );
  }

  static Uint8List _surfaceToMaskedRgba(BitmapSurface surface, Uint8List mask) {
    final Uint32List pixels = surface.pixels;
    final Uint8List rgba = Uint8List(pixels.length * 4);
    for (int i = 0; i < pixels.length; i++) {
      if (mask[i] == 0) {
        continue;
      }
      final int argb = pixels[i];
      final int offset = i * 4;
      rgba[offset] = (argb >> 16) & 0xff;
      rgba[offset + 1] = (argb >> 8) & 0xff;
      rgba[offset + 2] = argb & 0xff;
      rgba[offset + 3] = (argb >> 24) & 0xff;
    }
    return rgba;
  }

  static bool _maskHasCoverage(Uint8List mask) {
    for (final int value in mask) {
      if (value != 0) {
        return true;
      }
    }
    return false;
  }

  static void _writeRgbaToSurface(BitmapSurface surface, Uint8List rgba) {
    final Uint32List pixels = surface.pixels;
    for (int i = 0; i < pixels.length; i++) {
      final int offset = i * 4;
      final int r = rgba[offset];
      final int g = rgba[offset + 1];
      final int b = rgba[offset + 2];
      final int a = rgba[offset + 3];
      pixels[i] = (a << 24) | (r << 16) | (g << 8) | b;
    }
  }

  void _ensureCompositeBuffers() {
    _compositePixels ??= Uint32List(_width * _height);
    _compositeRgba ??= Uint8List(_width * _height * 4);
  }

  Uint8List _ensureClipMask() {
    return _clipMaskBuffer ??= Uint8List(_width * _height);
  }

  static double _clampUnit(double value) {
    if (value <= 0) {
      return 0;
    }
    if (value >= 1) {
      return 1;
    }
    return value;
  }

  bool _floodFillMask({
    required Uint32List pixels,
    required int targetColor,
    required Uint8List mask,
    required int startX,
    required int startY,
  }) {
    final int width = _width;
    final int height = _height;
    final Queue<int> queue = Queue<int>();
    final int startIndex = startY * width + startX;
    mask[startIndex] = 1;
    queue.add(startIndex);
    int processed = 0;

    bool shouldInclude(int x, int y) {
      if (x < 0 || x >= width || y < 0 || y >= height) {
        return false;
      }
      final int index = y * width + x;
      if (mask[index] != 0) {
        return false;
      }
      return pixels[index] == targetColor;
    }

    void enqueue(int x, int y) {
      if (!shouldInclude(x, y)) {
        return;
      }
      final int index = y * width + x;
      mask[index] = 1;
      queue.add(index);
    }

    while (queue.isNotEmpty) {
      final int index = queue.removeFirst();
      processed += 1;
      final int x = index % width;
      final int y = index ~/ width;
      enqueue(x + 1, y);
      enqueue(x - 1, y);
      enqueue(x, y + 1);
      enqueue(x, y - 1);
    }

    return processed > 0;
  }

  _IntRect _clipRectToSurface(Rect rect) {
    final double effectiveLeft = rect.left;
    final double effectiveTop = rect.top;
    final double effectiveRight = rect.right;
    final double effectiveBottom = rect.bottom;
    final int left = math.max(0, effectiveLeft.floor());
    final int top = math.max(0, effectiveTop.floor());
    final int right = math.min(_width, effectiveRight.ceil());
    final int bottom = math.min(_height, effectiveBottom.ceil());
    if (left >= right || top >= bottom) {
      return const _IntRect(0, 0, 0, 0);
    }
    return _IntRect(left, top, right, bottom);
  }

  Rect _dirtyRectForCircle(Offset center, double radius) {
    final double effectiveRadius = math.max(radius, 0.5);
    return Rect.fromCircle(center: center, radius: effectiveRadius + 1.5);
  }

  Rect _dirtyRectForLine(Offset a, Offset b, double radius) {
    final double inflate = math.max(radius, 0.5) + 1.5;
    return Rect.fromPoints(a, b).inflate(inflate);
  }

  static int _blendArgb(int dst, int src) {
    final int srcA = (src >> 24) & 0xff;
    if (srcA == 0) {
      return dst;
    }
    if (srcA == 255) {
      return src;
    }

    final int dstA = (dst >> 24) & 0xff;
    final int invSrcA = 255 - srcA;
    final int outA = srcA + _mul255(dstA, invSrcA);
    if (outA == 0) {
      return 0;
    }

    final int srcR = (src >> 16) & 0xff;
    final int srcG = (src >> 8) & 0xff;
    final int srcB = src & 0xff;
    final int dstR = (dst >> 16) & 0xff;
    final int dstG = (dst >> 8) & 0xff;
    final int dstB = dst & 0xff;

    final int srcPremR = _mul255(srcR, srcA);
    final int srcPremG = _mul255(srcG, srcA);
    final int srcPremB = _mul255(srcB, srcA);
    final int dstPremR = _mul255(dstR, dstA);
    final int dstPremG = _mul255(dstG, dstA);
    final int dstPremB = _mul255(dstB, dstA);

    final int outPremR = srcPremR + _mul255(dstPremR, invSrcA);
    final int outPremG = srcPremG + _mul255(dstPremG, invSrcA);
    final int outPremB = srcPremB + _mul255(dstPremB, invSrcA);

    final int outR = _clampToByte(((outPremR * 255) + (outA >> 1)) ~/ outA);
    final int outG = _clampToByte(((outPremG * 255) + (outA >> 1)) ~/ outA);
    final int outB = _clampToByte(((outPremB * 255) + (outA >> 1)) ~/ outA);

    return (outA << 24) | (outR << 16) | (outG << 8) | outB;
  }

  static int _blendWithMode(int dst, int src, CanvasLayerBlendMode mode) {
    switch (mode) {
      case CanvasLayerBlendMode.normal:
        return _blendArgb(dst, src);
      case CanvasLayerBlendMode.multiply:
        return _blendMultiply(dst, src);
    }
  }

  static int _blendMultiply(int dst, int src) {
    final int srcA = (src >> 24) & 0xff;
    if (srcA == 0) {
      return dst;
    }

    final int dstA = (dst >> 24) & 0xff;
    final double sa = srcA / 255.0;
    final double da = dstA / 255.0;
    final double outA = sa + da * (1 - sa);

    final int srcR = (src >> 16) & 0xff;
    final int srcG = (src >> 8) & 0xff;
    final int srcB = src & 0xff;
    final int dstR = (dst >> 16) & 0xff;
    final int dstG = (dst >> 8) & 0xff;
    final int dstB = dst & 0xff;

    double blendComponent(int sr, int dr) {
      final double srcNorm = sr / 255.0;
      final double dstNorm = dr / 255.0;
      return dstNorm * (1 - sa) + dstNorm * srcNorm * sa;
    }

    final int outR = _clampToByte((blendComponent(srcR, dstR) * 255).round());
    final int outG = _clampToByte((blendComponent(srcG, dstG) * 255).round());
    final int outB = _clampToByte((blendComponent(srcB, dstB) * 255).round());
    final int outAlpha = _clampToByte((outA * 255).round());

    return (outAlpha << 24) | (outR << 16) | (outG << 8) | outB;
  }

  static int _mul255(int channel, int alpha) {
    return (channel * alpha + 127) ~/ 255;
  }

  static int _clampToByte(int value) {
    if (value <= 0) {
      return 0;
    }
    if (value >= 255) {
      return 255;
    }
    return value;
  }
}

class _IntRect {
  const _IntRect(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  bool get isEmpty => left >= right || top >= bottom;
}
