import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../canvas/canvas_layer.dart';
import 'bitmap_canvas.dart';

class BitmapLayerState {
  BitmapLayerState({
    required this.id,
    required this.name,
    required this.surface,
    this.visible = true,
  });

  final String id;
  String name;
  bool visible;
  final BitmapSurface surface;
}

class BitmapCanvasController extends ChangeNotifier {
  BitmapCanvasController({
    required int width,
    required int height,
    required Color backgroundColor,
    List<CanvasLayerData>? initialLayers,
  })  : _width = width,
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
  Color _currentStrokeColor = const Color(0xFF000000);

  ui.Image? _cachedImage;
  bool _compositeDirty = true;
  bool _refreshScheduled = false;

  UnmodifiableListView<BitmapLayerState> get layers =>
      UnmodifiableListView<BitmapLayerState>(_layers);

  String? get activeLayerId =>
      _layers.isEmpty ? null : _layers[_activeIndex].id;

  ui.Image? get image => _cachedImage;

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

  Future<void> disposeController() async {
    _cachedImage?.dispose();
    _cachedImage = null;
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
      final int index = _layers.indexWhere((element) => element.id == aboveLayerId);
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
      if (i == 0) {
        layer.surface.fill(_backgroundColor);
      } else {
        layer.surface.fill(const Color(0x00000000));
      }
    }
    _markDirty();
  }

  void beginStroke(Offset position, {
    required Color color,
    required double radius,
  }) {
    _currentStrokePoints
      ..clear()
      ..add(position);
    _currentStrokeRadius = radius;
    _currentStrokeColor = color;
    _drawPoint(position);
  }

  void extendStroke(Offset position) {
    if (_currentStrokePoints.isEmpty) {
      return;
    }
    final Offset last = _currentStrokePoints.last;
    _currentStrokePoints.add(position);
    _activeSurface.drawLine(
      a: last,
      b: position,
      radius: _currentStrokeRadius,
      color: _currentStrokeColor,
    );
    _markDirty();
  }

  void endStroke() {
    _currentStrokePoints.clear();
    _currentStrokeRadius = 0;
  }

  void floodFill(
    Offset position, {
    required Color color,
    bool contiguous = true,
    bool sampleAllLayers = false,
  }) {
    final int x = position.dx.floor();
    final int y = position.dy.floor();
    if (x < 0 || x >= _width || y < 0 || y >= _height) {
      return;
    }
    Color? baseColor;
    if (sampleAllLayers) {
      baseColor = _colorAtComposite(position);
    } else {
      baseColor = _colorAtSurface(_activeSurface, x, y);
    }
    _activeSurface.floodFill(
      start: Offset(x.toDouble(), y.toDouble()),
      color: color,
      targetColor: baseColor,
      contiguous: contiguous,
    );
    _markDirty();
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
          fillColor: i == 0 ? _backgroundColor : null,
          bitmap: bitmap,
          bitmapWidth: bitmap != null ? _width : null,
          bitmapHeight: bitmap != null ? _height : null,
        ),
      );
    }
    return result;
  }

  void loadLayers(List<CanvasLayerData> layers, Color backgroundColor) {
    _layers.clear();
    _loadFromCanvasLayers(layers, backgroundColor);
    _markDirty();
  }

  BitmapSurface _buildCompositeSurface() {
    BitmapSurface? base;
    for (final BitmapLayerState layer in _layers) {
      if (!layer.visible) {
        continue;
      }
      base ??= BitmapSurface(width: _width, height: _height);
      _blendSurface(base, layer.surface);
    }
    base ??= BitmapSurface(width: _width, height: _height);
    return base;
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
          surface: surface,
        ),
      );
      if (layer == layers.first && layer.fillColor != null) {
        _backgroundColor = layer.fillColor!;
      }
    }
    _activeIndex = _layers.length - 1;
  }

  void _drawPoint(Offset position) {
    _activeSurface.drawCircle(
      center: position,
      radius: _currentStrokeRadius,
      color: _currentStrokeColor,
    );
    _markDirty();
  }

  void _markDirty() {
    _compositeDirty = true;
    _scheduleCompositeRefresh();
  }

  void _scheduleCompositeRefresh() {
    if (_refreshScheduled) {
      return;
    }
    _refreshScheduled = true;
    scheduleMicrotask(() async {
      _refreshScheduled = false;
      if (!_compositeDirty) {
        return;
      }
      final BitmapSurface composite = _buildCompositeSurface();
      final Uint8List rgba = _surfaceToRgba(composite);
      ui.decodeImageFromPixels(
        rgba,
        _width,
        _height,
        ui.PixelFormat.rgba8888,
        (ui.Image image) {
          _cachedImage?.dispose();
          _cachedImage = image;
          _compositeDirty = false;
          notifyListeners();
        },
      );
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
    final BitmapSurface composite = _buildCompositeSurface();
    final int x = position.dx.floor();
    final int y = position.dy.floor();
    if (x < 0 || x >= _width || y < 0 || y >= _height) {
      return const Color(0x00000000);
    }
    return BitmapSurface.decodeColor(
      composite.pixels[y * _width + x],
    );
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

  static void _blendSurface(BitmapSurface target, BitmapSurface source) {
    final Uint32List src = source.pixels;
    final Uint32List dst = target.pixels;
    for (int i = 0; i < dst.length; i++) {
      final int color = src[i];
      if ((color >> 24) == 0) {
        continue;
      }
      final int x = i % target.width;
      final int y = i ~/ target.width;
      target.blendPixel(x, y, BitmapSurface.decodeColor(color));
    }
  }
}
