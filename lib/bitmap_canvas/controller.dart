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
  bool _pendingFullSurface = false;
  Rect? _pendingDirtyRect;
  bool _compositeInitialized = false;
  Uint32List? _compositePixels;
  Uint8List? _compositeRgba;

  UnmodifiableListView<BitmapLayerState> get layers =>
      UnmodifiableListView<BitmapLayerState>(_layers);

  String? get activeLayerId =>
      _layers.isEmpty ? null : _layers[_activeIndex].id;

  ui.Image? get image => _cachedImage;
  Color get backgroundColor => _backgroundColor;

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
    _markDirty(region: _dirtyRectForLine(last, position, _currentStrokeRadius));
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

  void _updateComposite({
    required bool requiresFullSurface,
    Rect? region,
  }) {
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
          final int src = layer.surface.pixels[index];
          if (!initialized) {
            color = src;
            initialized = true;
          } else {
            color = _blendArgb(color, src);
          }
        }
        if (!initialized) {
          color = 0;
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
    _markDirty(region: _dirtyRectForCircle(position, _currentStrokeRadius));
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
      ui.decodeImageFromPixels(
        rgba,
        _width,
        _height,
        ui.PixelFormat.rgba8888,
        (ui.Image image) {
          _cachedImage?.dispose();
          _cachedImage = image;
          _compositeDirty = _pendingFullSurface || _pendingDirtyRect != null;
          notifyListeners();
          if (_compositeDirty && !_refreshScheduled) {
            _scheduleCompositeRefresh();
          }
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
      final int src = layer.surface.pixels[index];
      if (color == null) {
        color = src;
      } else {
        color = _blendArgb(color, src);
      }
    }
    return BitmapSurface.decodeColor(color ?? 0);
  }

  void _floodFillAcrossLayers(
    int startX,
    int startY,
    Color color,
    bool contiguous,
  ) {
    _updateComposite(
      requiresFullSurface: true,
      region: null,
    );
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
          visited[leftIndex] = 1;
          stack.add(leftIndex);
        }
      }
      // right
      if (cx < _width - 1) {
        final int rightIndex = current + 1;
        if (visited[rightIndex] == 0 && compositePixels[rightIndex] == target) {
          visited[rightIndex] = 1;
          stack.add(rightIndex);
        }
      }
      // up
      if (cy > 0) {
        final int upIndex = current - _width;
        if (visited[upIndex] == 0 && compositePixels[upIndex] == target) {
          visited[upIndex] = 1;
          stack.add(upIndex);
        }
      }
      // down
      if (cy < _height - 1) {
        final int downIndex = current + _width;
        if (visited[downIndex] == 0 && compositePixels[downIndex] == target) {
          visited[downIndex] = 1;
          stack.add(downIndex);
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
