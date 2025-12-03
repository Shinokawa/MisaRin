import 'dart:isolate';
import 'dart:async';
import 'dart:typed_data';

import '../bitmap_canvas/bitmap_blend_utils.dart' as blend_utils;
import '../bitmap_canvas/raster_int_rect.dart';
import '../canvas/canvas_layer.dart';

class CompositeRegionLayerRef {
  const CompositeRegionLayerRef({
    required this.id,
    required this.visible,
    required this.opacity,
    required this.clippingMask,
    required this.blendModeIndex,
  });

  final String id;
  final bool visible;
  final double opacity;
  final bool clippingMask;
  final int blendModeIndex;

  CanvasLayerBlendMode get blendMode =>
      CanvasLayerBlendMode.values[blendModeIndex];
}

class CompositeRegionPayload {
  const CompositeRegionPayload({
    required this.rect,
    required this.layers,
  });

  final RasterIntRect rect;
  final List<CompositeRegionLayerRef> layers;
}

class CompositeWorkPayload {
  const CompositeWorkPayload({
    required this.width,
    required this.height,
    required this.regions,
    required this.requiresFullSurface,
    this.translatingLayerId,
  });

  final int width;
  final int height;
  final List<CompositeRegionPayload> regions;
  final bool requiresFullSurface;
  final String? translatingLayerId;
}

class CompositeRegionResult {
  const CompositeRegionResult({
    required this.rect,
    required this.pixels,
    this.rgbaBytes,
  });

  final RasterIntRect rect;
  final Uint32List pixels;
  final TransferableTypedData? rgbaBytes;
}

class CanvasCompositeWorker {
  CanvasCompositeWorker()
      : _receivePort = ReceivePort(),
        _sendPortCompleter = Completer<SendPort>() {
    _subscription = _receivePort.listen(_handleMessage);
  }

  final ReceivePort _receivePort;
  final Completer<SendPort> _sendPortCompleter;
  late final StreamSubscription<Object?> _subscription;
  final Map<int, Completer<List<CompositeRegionResult>>> _pending =
      <int, Completer<List<CompositeRegionResult>>>{};
  Isolate? _isolate;
  SendPort? _sendPort;
  int _nextRequestId = 0;

  Future<void> _ensureStarted() async {
    if (_isolate != null) {
      return;
    }
    _isolate = await Isolate.spawn<SendPort>(
      _compositeWorkerMain,
      _receivePort.sendPort,
      debugName: 'CanvasCompositeWorker',
    );
    _sendPort = await _sendPortCompleter.future;
  }

  Future<void> updateLayer({
    required String id,
    required int width,
    required int height,
    Uint32List? pixels,
    RasterIntRect? rect,
  }) async {
    await _ensureStarted();
    final SendPort port = _sendPort!;
    final TransferableTypedData? buffer = pixels != null
        ? TransferableTypedData.fromList(
            <Uint8List>[Uint8List.view(pixels.buffer)],
          )
        : null;
    port.send(_CompositeWorkerRequest(
      id: -1, // No response needed for updates
      type: _CompositeWorkerRequestType.updateLayer,
      payload: <String, Object?>{
        'id': id,
        'width': width,
        'height': height,
        'pixels': buffer,
        'rect': rect,
      },
    ));
  }

  Future<List<CompositeRegionResult>> composite(
    CompositeWorkPayload payload,
  ) async {
    await _ensureStarted();
    final SendPort port = _sendPort!;
    final Completer<List<CompositeRegionResult>> completer =
        Completer<List<CompositeRegionResult>>();
    final int requestId = _nextRequestId++;
    _pending[requestId] = completer;
    port.send(_CompositeWorkerRequest(
      id: requestId,
      type: _CompositeWorkerRequestType.composite,
      payload: payload,
    ));
    return completer.future;
  }

  Future<void> dispose() async {
    if (_isolate != null) {
      _sendPort?.send(null);
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;
    }
    await _subscription.cancel();
    _receivePort.close();
    for (final Completer<List<CompositeRegionResult>> completer
        in _pending.values) {
      completer.completeError(StateError('Composite worker disposed'));
    }
    _pending.clear();
  }

  void _handleMessage(Object? message) {
    if (message is SendPort) {
      if (!_sendPortCompleter.isCompleted) {
        _sendPortCompleter.complete(message);
      }
      return;
    }
    if (message is _CompositeWorkerResponse) {
      final Completer<List<CompositeRegionResult>>? completer =
          _pending.remove(message.id);
      completer?.complete(message.regions);
      return;
    }
    if (message is _CompositeWorkerError) {
      final Completer<List<CompositeRegionResult>>? completer =
          _pending.remove(message.id);
      completer?.completeError(
        Exception('Composite failed: ${message.error}\n${message.stackTrace}'),
      );
    }
  }
}

enum _CompositeWorkerRequestType {
  updateLayer,
  composite,
}

class _CompositeWorkerState {
  final Map<String, Uint32List> layers = <String, Uint32List>{};
  final Map<String, _LayerDimensions> layerDimensions = <String, _LayerDimensions>{};
}

class _LayerDimensions {
  const _LayerDimensions(this.width, this.height);
  final int width;
  final int height;
}

@pragma('vm:entry-point')
void _compositeWorkerMain(SendPort replyPort) {
  final ReceivePort commandPort = ReceivePort();
  replyPort.send(commandPort.sendPort);
  final _CompositeWorkerState state = _CompositeWorkerState();

  commandPort.listen((Object? message) {
    if (message is _CompositeWorkerRequest) {
      try {
        if (message.type == _CompositeWorkerRequestType.updateLayer) {
          _handleUpdateLayer(state, message.payload as Map<String, Object?>);
        } else if (message.type == _CompositeWorkerRequestType.composite) {
          final List<CompositeRegionResult> regions =
              _runCompositeWork(state, message.payload as CompositeWorkPayload);
          replyPort.send(_CompositeWorkerResponse(message.id, regions));
        }
      } catch (error, stackTrace) {
        if (message.id >= 0) {
          replyPort.send(
            _CompositeWorkerError(
              message.id,
              error.toString(),
              stackTrace.toString(),
            ),
          );
        }
      }
      return;
    }
    if (message == null) {
      commandPort.close();
    }
  });
}

void _handleUpdateLayer(
  _CompositeWorkerState state,
  Map<String, Object?> payload,
) {
  final String id = payload['id'] as String;
  final int width = payload['width'] as int;
  final int height = payload['height'] as int;
  final TransferableTypedData? pixelsData =
      payload['pixels'] as TransferableTypedData?;
  final RasterIntRect? rect = payload['rect'] as RasterIntRect?;

  if (pixelsData == null) {
    if (rect == null) {
      // Full initialization with empty buffer
      state.layers[id] = Uint32List(width * height);
      state.layerDimensions[id] = _LayerDimensions(width, height);
    }
    return;
  }

  final ByteBuffer buffer = pixelsData.materialize();
  final Uint32List incomingPixels = Uint32List.view(
    buffer,
    0,
    buffer.lengthInBytes ~/ Uint32List.bytesPerElement,
  );

  if (rect != null) {
    // Update partial region
    final Uint32List? existing = state.layers[id];
    if (existing == null) {
      return; // Layer not initialized, cannot update patch
    }
    final int regionWidth = rect.width;
    final int regionHeight = rect.height;
    for (int row = 0; row < regionHeight; row++) {
      final int dstOffset = (rect.top + row) * width + rect.left;
      final int srcOffset = row * regionWidth;
      existing.setRange(
        dstOffset,
        dstOffset + regionWidth,
        incomingPixels,
        srcOffset,
      );
    }
  } else {
    // Full update
    state.layers[id] = incomingPixels;
    state.layerDimensions[id] = _LayerDimensions(width, height);
  }
}

class _CompositeWorkerRequest {
  const _CompositeWorkerRequest({
    required this.id,
    required this.type,
    required this.payload,
  });

  final int id;
  final _CompositeWorkerRequestType type;
  final Object payload;
}

class _CompositeWorkerResponse {
  const _CompositeWorkerResponse(this.id, this.regions);

  final int id;
  final List<CompositeRegionResult> regions;
}

class _CompositeWorkerError {
  const _CompositeWorkerError(this.id, this.error, this.stackTrace);

  final int id;
  final String error;
  final String stackTrace;
}

List<CompositeRegionResult> _runCompositeWork(
  _CompositeWorkerState state,
  CompositeWorkPayload payload,
) {
  if (payload.regions.isEmpty) {
    return const <CompositeRegionResult>[];
  }
  final int surfaceWidth = payload.width;
  final List<CompositeRegionResult> results = <CompositeRegionResult>[];

  for (final CompositeRegionPayload region in payload.regions) {
    final RasterIntRect area = region.rect;
    final int areaWidth = area.width;
    final int areaHeight = area.height;
    if (areaWidth <= 0 || areaHeight <= 0) {
      continue;
    }
    final int length = areaWidth * areaHeight;
    final Uint32List composite = Uint32List(length);
    final Uint8List clipMask = Uint8List(length);
    final Uint8List rgba = Uint8List(length * 4);

    for (int localY = 0; localY < areaHeight; localY++) {
      final int globalY = area.top + localY;
      final int rowOffset = localY * areaWidth;
      for (int localX = 0; localX < areaWidth; localX++) {
        final int localIndex = rowOffset + localX;
        final int globalIndex =
            (globalY * surfaceWidth) + (area.left + localX);
        int color = 0;
        bool initialized = false;

        for (final CompositeRegionLayerRef layer in region.layers) {
          if (!layer.visible) {
            continue;
          }
          if (payload.translatingLayerId != null &&
              layer.id == payload.translatingLayerId) {
            continue;
          }
          
          final Uint32List? layerPixels = state.layers[layer.id];
          if (layerPixels == null) {
             continue;
          }

          final double opacity = _clampUnit(layer.opacity);
          if (opacity <= 0) {
            if (!layer.clippingMask) {
              clipMask[localIndex] = 0;
            }
            continue;
          }

          final int src = layerPixels[globalIndex];
          final int srcA = (src >> 24) & 0xff;
          if (srcA == 0) {
            if (!layer.clippingMask) {
              clipMask[localIndex] = 0;
            }
            continue;
          }

          double totalOpacity = opacity;
          if (layer.clippingMask) {
            final int maskAlpha = clipMask[localIndex];
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
              clipMask[localIndex] = 0;
            }
            continue;
          }
          effectiveA = effectiveA.clamp(0, 255);

          if (!layer.clippingMask) {
            clipMask[localIndex] = effectiveA;
          }

          final int effectiveColor = (effectiveA << 24) | (src & 0x00FFFFFF);
          if (!initialized) {
            color = effectiveColor;
            initialized = true;
          } else {
            color = blend_utils.blendWithMode(
              color,
              effectiveColor,
              layer.blendMode,
              globalIndex,
            );
          }
        }
        
        // Save ARGB
        composite[localIndex] = initialized ? color : 0;

        // Compute RGBA + Premultiply
        final int argb = composite[localIndex];
        final int a = (argb >> 24) & 0xff;
        final int r = (argb >> 16) & 0xff;
        final int g = (argb >> 8) & 0xff;
        final int b = argb & 0xff;
        
        final int offset = localIndex * 4;
        if (a == 0) {
            rgba[offset] = 0;
            rgba[offset + 1] = 0;
            rgba[offset + 2] = 0;
            rgba[offset + 3] = 0;
        } else if (a == 255) {
            rgba[offset] = r;
            rgba[offset + 1] = g;
            rgba[offset + 2] = b;
            rgba[offset + 3] = 255;
        } else {
            // Premultiply
            rgba[offset] = (r * a) ~/ 255;
            rgba[offset + 1] = (g * a) ~/ 255;
            rgba[offset + 2] = (b * a) ~/ 255;
            rgba[offset + 3] = a;
        }
      }
    }
    
    results.add(CompositeRegionResult(
        rect: area, 
        pixels: composite,
        rgbaBytes: TransferableTypedData.fromList(<Uint8List>[rgba]),
    ));
  }
  return results;
}

double _clampUnit(double value) {
  if (value.isNaN) {
    return 0.0;
  }
  if (value < 0) {
    return 0.0;
  }
  if (value > 1) {
    return 1.0;
  }
  return value;
}