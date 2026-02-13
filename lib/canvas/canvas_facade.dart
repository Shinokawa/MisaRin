import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../bitmap_canvas/raster_frame.dart';
import '../bitmap_canvas/stroke_dynamics.dart';
import 'canvas_layer.dart';
import 'canvas_layer_info.dart';
import 'canvas_composite_layer.dart';
import 'canvas_tool_host.dart';
import 'canvas_tools.dart';
import 'text_renderer.dart';

abstract class CanvasFacade extends Listenable implements CanvasToolHost {
  int get width;
  int get height;
  Color get backgroundColor;

  UnmodifiableListView<CanvasLayerInfo> get layers;
  UnmodifiableListView<CanvasCompositeLayer> get compositeLayers;
  CanvasLayerInfo get activeLayer;
  String? get activeLayerId;

  int get activeStrokeRotationSeed;
  BitmapCanvasFrame? get frame;

  Image? get activeLayerTransformImage;
  Offset get activeLayerTransformOffset;
  Offset get activeLayerTransformOrigin;
  Rect? get activeLayerTransformBounds;
  double get activeLayerTransformOpacity;
  CanvasLayerBlendMode get activeLayerTransformBlendMode;

  bool get clipLayerOverflow;
  bool get hasVisibleContent;
  bool get isActiveLayerTransforming;
  bool get isActiveLayerTransformPendingCleanup;

  void configureStylusPressure({
    required bool enabled,
    double? curve,
  });

  void configureSharpTips({required bool enabled});

  void beginStroke(
    Offset position, {
    required Color color,
    required double radius,
    bool simulatePressure = false,
    bool useDevicePressure = false,
    double stylusPressureBlend = 1.0,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
    StrokePressureProfile profile = StrokePressureProfile.auto,
    double? timestampMillis,
    int antialiasLevel = 0,
    BrushShape brushShape = BrushShape.circle,
    bool enableNeedleTips = false,
    bool randomRotation = false,
    int? rotationSeed,
    double spacing = 0.15,
    double hardness = 0.8,
    double flow = 1.0,
    double scatter = 0.0,
    double rotationJitter = 1.0,
    bool snapToPixel = false,
    bool erase = false,
    bool hollow = false,
    double hollowRatio = 0.0,
    bool eraseOccludedParts = false,
  });

  void extendStroke(
    Offset position, {
    double? deltaTimeMillis,
    double? timestampMillis,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
  });

  void endStroke();
  void cancelStroke();

  void clear();

  void setLayerOverflowCropping(bool enabled);
  void translateActiveLayer(int dx, int dy);
  void commitActiveLayerTranslation();
  void cancelActiveLayerTranslation();
  void disposeActiveLayerTransformSession();

  void setActiveLayer(String id);
  void updateLayerVisibility(String id, bool visible);
  void setLayerOpacity(String id, double opacity);
  void setLayerLocked(String id, bool locked);
  void setLayerClippingMask(String id, bool clippingMask);
  void setLayerBlendMode(String id, CanvasLayerBlendMode mode);
  void renameLayer(String id, String name);
  void addLayer({String? aboveLayerId, String? name});
  Future<String> createTextLayer(CanvasTextData data);
  Future<void> updateTextLayer(String id, CanvasTextData data);
  void rasterizeTextLayer(String id);
  void removeLayer(String id);
  void reorderLayer(int fromIndex, int toIndex);
  bool mergeLayerDown(String id);

  void loadLayers(List<CanvasLayerData> layers, Color backgroundColor);
  List<CanvasLayerData> snapshotLayers();
  CanvasLayerData? buildClipboardLayer(String id, {Uint8List? mask});
  void clearLayerRegion(String id, {Uint8List? mask});
  String insertLayerFromData(CanvasLayerData data, {String? aboveLayerId});
  void replaceLayer(String id, CanvasLayerData data);

  Rect? restoreLayerRegion(
    CanvasLayerData snapshot,
    Rect region, {
    Uint32List? pixelCache,
    bool markDirty = true,
  });

  void markLayerRegionDirty(String id, Rect region);

  Future<Image> snapshotImage();
  Future<void> waitForPendingWorkerTasks();
  Future<void> disposeController();
  void notifyListeners();

  Future<bool> applyAntialiasToActiveLayer(
    int level, {
    bool previewOnly = false,
  });

  void setSelectionMask(Uint8List? mask);

  Color sampleColor(Offset position, {bool sampleAllLayers = true});

  Uint32List? readLayerPixels(String id);
  Size? readLayerSurfaceSize(String id);
  bool writeLayerPixels(
    String id,
    Uint32List pixels, {
    bool markDirty = true,
  });
}
