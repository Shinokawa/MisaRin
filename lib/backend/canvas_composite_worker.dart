import 'dart:isolate';
import 'dart:async';
import 'dart:typed_data';

import '../bitmap_canvas/bitmap_blend_utils.dart' as blend_utils;
import '../bitmap_canvas/raster_int_rect.dart';
import '../canvas/canvas_layer.dart';

class CompositeRegionLayerPayload {
  const CompositeRegionLayerPayload({
    required this.id,
    required this.visible,
    required this.opacity,
    required this.clippingMask,
    required this.blendModeIndex,
    required this.pixels,
  });

  final String id;
  final bool visible;
  final double opacity;
  final bool clippingMask;
  final int blendModeIndex;
  final Uint32List pixels;

  CanvasLayerBlendMode get blendMode =>
      CanvasLayerBlendMode.values[blendModeIndex];
}

class CompositeRegionPayload {
  const CompositeRegionPayload({
    required this.rect,
    required this.layers,
  });

  final RasterIntRect rect;
  final List<CompositeRegionLayerPayload> layers;
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
  });

  final RasterIntRect rect;
  final Uint32List pixels;
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

  Future<List<CompositeRegionResult>> composite(
    CompositeWorkPayload payload,
  ) async {
    await _ensureStarted();
    final SendPort port = _sendPort!;
    final Completer<List<CompositeRegionResult>> completer =
        Completer<List<CompositeRegionResult>>();
    final int requestId = _nextRequestId++;
    _pending[requestId] = completer;
    port.send(_CompositeWorkerRequest(id: requestId, payload: payload));
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

@pragma('vm:entry-point')
void _compositeWorkerMain(SendPort replyPort) {
  final ReceivePort commandPort = ReceivePort();
  replyPort.send(commandPort.sendPort);
  commandPort.listen((Object? message) {
    if (message is _CompositeWorkerRequest) {
      try {
        final List<CompositeRegionResult> regions =
            runCompositeWork(message.payload);
        replyPort.send(_CompositeWorkerResponse(message.id, regions));
      } catch (error, stackTrace) {
        replyPort.send(
          _CompositeWorkerError(
            message.id,
            error.toString(),
            stackTrace.toString(),
          ),
        );
      }
      return;
    }
    if (message == null) {
      commandPort.close();
    }
  });
}

class _CompositeWorkerRequest {
  const _CompositeWorkerRequest({
    required this.id,
    required this.payload,
  });

  final int id;
  final CompositeWorkPayload payload;
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

List<CompositeRegionResult> runCompositeWork(CompositeWorkPayload payload) {
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
    final Uint32List composite = Uint32List(areaWidth * areaHeight);
    final Uint8List clipMask = Uint8List(areaWidth * areaHeight);
    for (int localY = 0; localY < areaHeight; localY++) {
      final int globalY = area.top + localY;
      final int rowOffset = localY * areaWidth;
      for (int localX = 0; localX < areaWidth; localX++) {
        final int localIndex = rowOffset + localX;
        final int globalIndex =
            (globalY * surfaceWidth) + (area.left + localX);
        int color = 0;
        bool initialized = false;
        for (final CompositeRegionLayerPayload layer in region.layers) {
          if (!layer.visible) {
            continue;
          }
          if (payload.translatingLayerId != null &&
              layer.id == payload.translatingLayerId) {
            continue;
          }
          final double opacity = _clampUnit(layer.opacity);
          if (opacity <= 0) {
            if (!layer.clippingMask) {
              clipMask[localIndex] = 0;
            }
            continue;
          }
          final int src = layer.pixels[localIndex];
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
        composite[localIndex] = initialized ? color : 0;
      }
    }
    results.add(CompositeRegionResult(rect: area, pixels: composite));
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
