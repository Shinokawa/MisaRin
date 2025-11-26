import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../bitmap_canvas/bitmap_canvas.dart';
import '../canvas/canvas_tools.dart';

enum PaintingDrawCommandType {
  brushStamp,
  line,
  variableLine,
  stampSegment,
}

class PaintingDrawCommand {
  const PaintingDrawCommand._({
    required this.type,
    required this.color,
    required this.antialiasLevel,
    required this.erase,
    this.center,
    this.radius,
    this.shapeIndex,
    this.start,
    this.end,
    this.startRadius,
    this.endRadius,
    this.includeStartCap,
  });

  factory PaintingDrawCommand.brushStamp({
    required Offset center,
    required double radius,
    required int colorValue,
    required int shapeIndex,
    required int antialiasLevel,
    required bool erase,
  }) {
    return PaintingDrawCommand._(
      type: PaintingDrawCommandType.brushStamp,
      color: colorValue,
      antialiasLevel: antialiasLevel,
      erase: erase,
      center: center,
      radius: radius,
      shapeIndex: shapeIndex,
    );
  }

  factory PaintingDrawCommand.line({
    required Offset start,
    required Offset end,
    required double radius,
    required int colorValue,
    required int antialiasLevel,
    required bool includeStartCap,
    required bool erase,
  }) {
    return PaintingDrawCommand._(
      type: PaintingDrawCommandType.line,
      color: colorValue,
      antialiasLevel: antialiasLevel,
      erase: erase,
      start: start,
      end: end,
      radius: radius,
      includeStartCap: includeStartCap,
    );
  }

  factory PaintingDrawCommand.variableLine({
    required Offset start,
    required Offset end,
    required double startRadius,
    required double endRadius,
    required int colorValue,
    required int antialiasLevel,
    required bool includeStartCap,
    required bool erase,
  }) {
    return PaintingDrawCommand._(
      type: PaintingDrawCommandType.variableLine,
      color: colorValue,
      antialiasLevel: antialiasLevel,
      erase: erase,
      start: start,
      end: end,
      startRadius: startRadius,
      endRadius: endRadius,
      includeStartCap: includeStartCap,
    );
  }

  factory PaintingDrawCommand.stampSegment({
    required Offset start,
    required Offset end,
    required double startRadius,
    required double endRadius,
    required int colorValue,
    required int shapeIndex,
    required int antialiasLevel,
    required bool includeStart,
    required bool erase,
  }) {
    return PaintingDrawCommand._(
      type: PaintingDrawCommandType.stampSegment,
      color: colorValue,
      antialiasLevel: antialiasLevel,
      erase: erase,
      start: start,
      end: end,
      startRadius: startRadius,
      endRadius: endRadius,
      includeStartCap: includeStart,
      shapeIndex: shapeIndex,
    );
  }

  final PaintingDrawCommandType type;
  final int color;
  final int antialiasLevel;
  final bool erase;
  final Offset? center;
  final double? radius;
  final int? shapeIndex;
  final Offset? start;
  final Offset? end;
  final double? startRadius;
  final double? endRadius;
  final bool? includeStartCap;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'type': type.index,
      'color': color,
      'antialias': antialiasLevel,
      'erase': erase,
      'center': center == null ? null : <double>[center!.dx, center!.dy],
      'radius': radius,
      'shape': shapeIndex,
      'start': start == null ? null : <double>[start!.dx, start!.dy],
      'end': end == null ? null : <double>[end!.dx, end!.dy],
      'startRadius': startRadius,
      'endRadius': endRadius,
      'includeStartCap': includeStartCap,
    };
  }
}

class PaintingWorkerPatch {
  const PaintingWorkerPatch({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.pixels,
  });

  final int left;
  final int top;
  final int width;
  final int height;
  final Uint32List pixels;
}

class PaintingDrawRequest {
  PaintingDrawRequest({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.commands,
    this.basePixels,
    this.mask,
  });

  final int left;
  final int top;
  final int width;
  final int height;
  final List<PaintingDrawCommand> commands;
  final TransferableTypedData? basePixels;
  final TransferableTypedData? mask;
}

class PaintingFloodFillRequest {
  PaintingFloodFillRequest({
    required this.width,
    required this.height,
    this.pixels,
    required this.startX,
    required this.startY,
    required this.colorValue,
    this.targetColorValue,
    this.contiguous = true,
    this.mask,
  });

  final int width;
  final int height;
  final TransferableTypedData? pixels;
  final int startX;
  final int startY;
  final int colorValue;
  final int? targetColorValue;
  final bool contiguous;
  final TransferableTypedData? mask;
}

class PaintingSelectionMaskRequest {
  PaintingSelectionMaskRequest({
    required this.width,
    required this.height,
    required this.pixels,
    required this.startX,
    required this.startY,
    this.tolerance = 0,
  });

  final int width;
  final int height;
  final TransferableTypedData pixels;
  final int startX;
  final int startY;
  final int tolerance;
}

class CanvasPaintingWorker {
  CanvasPaintingWorker()
      : _receivePort = ReceivePort(),
        _pending = <int, Completer<Object?>>{},
        _sendPortCompleter = Completer<SendPort>() {
    _subscription = _receivePort.listen(_handleMessage);
  }

  final ReceivePort _receivePort;
  final Completer<SendPort> _sendPortCompleter;
  final Map<int, Completer<Object?>> _pending;
  late final StreamSubscription<Object?> _subscription;
  Isolate? _isolate;
  SendPort? _sendPort;
  int _nextRequestId = 0;

  Future<void> _ensureStarted() async {
    if (_isolate != null) {
      return;
    }
    _isolate = await Isolate.spawn<SendPort>(
      _paintingWorkerMain,
      _receivePort.sendPort,
      debugName: 'CanvasPaintingWorker',
      errorsAreFatal: false,
    );
    _sendPort = await _sendPortCompleter.future;
  }

  Future<void> setSurface({
    required int width,
    required int height,
    required Uint32List pixels,
  }) async {
    await _ensureStarted();
    final TransferableTypedData buffer = TransferableTypedData.fromList(
      <Uint8List>[Uint8List.view(pixels.buffer)],
    );
    await _sendRequest(<String, Object?>{
      'kind': 'setSurface',
      'width': width,
      'height': height,
      'pixels': buffer,
    });
  }

  Future<void> syncSurfacePatch({
    required int left,
    required int top,
    required int width,
    required int height,
    required Uint32List pixels,
  }) async {
    await _ensureStarted();
    final TransferableTypedData buffer = TransferableTypedData.fromList(
      <Uint8List>[Uint8List.view(pixels.buffer)],
    );
    await _sendRequest(<String, Object?>{
      'kind': 'syncSurface',
      'left': left,
      'top': top,
      'width': width,
      'height': height,
      'pixels': buffer,
    });
  }

  Future<void> updateSelectionMask(Uint8List? mask) async {
    await _ensureStarted();
    TransferableTypedData? maskData;
    if (mask != null) {
      maskData = TransferableTypedData.fromList(<Uint8List>[mask]);
    }
    await _sendRequest(<String, Object?>{
      'kind': 'selection',
      'mask': maskData,
    });
  }

  Future<PaintingWorkerPatch> drawPatch(PaintingDrawRequest request) async {
    await _ensureStarted();
    final Object? response = await _sendRequest(<String, Object?>{
      'kind': 'draw',
      'left': request.left,
      'top': request.top,
      'width': request.width,
      'height': request.height,
      'pixels': request.basePixels,
      'mask': request.mask,
      'commands': request.commands
          .map((PaintingDrawCommand command) => command.toJson())
          .toList(growable: false),
    });
    return _parsePatchResponse(
      response,
      fallbackLeft: request.left,
      fallbackTop: request.top,
      fallbackWidth: request.width,
      fallbackHeight: request.height,
    );
  }

  Future<PaintingWorkerPatch> floodFill(
    PaintingFloodFillRequest request,
  ) async {
    await _ensureStarted();
    final Object? response = await _sendRequest(<String, Object?>{
      'kind': 'floodFill',
      'width': request.width,
      'height': request.height,
      'pixels': request.pixels,
      'startX': request.startX,
      'startY': request.startY,
      'color': request.colorValue,
      'targetColor': request.targetColorValue,
      'contiguous': request.contiguous,
      'mask': request.mask,
    });
    return _parsePatchResponse(
      response,
      fallbackLeft: 0,
      fallbackTop: 0,
      fallbackWidth: request.width,
      fallbackHeight: request.height,
    );
  }

  Future<Uint8List> computeSelectionMask(
    PaintingSelectionMaskRequest request,
  ) async {
    await _ensureStarted();
    final Object? response = await _sendRequest(<String, Object?>{
      'kind': 'selectionMask',
      'width': request.width,
      'height': request.height,
      'pixels': request.pixels,
      'startX': request.startX,
      'startY': request.startY,
      'tolerance': request.tolerance,
    });
    if (response is! TransferableTypedData) {
      throw StateError('Invalid selection mask response: $response');
    }
    final ByteBuffer buffer = response.materialize();
    return buffer.asUint8List();
  }

  Future<Object?> _sendRequest(Object payload) async {
    await _ensureStarted();
    final SendPort port = _sendPort!;
    final Completer<Object?> completer = Completer<Object?>();
    final int requestId = _nextRequestId++;
    _pending[requestId] = completer;
    port.send(<String, Object?>{'id': requestId, 'payload': payload});
    return completer.future;
  }

  void _handleMessage(Object? message) {
    if (message is SendPort) {
      if (!_sendPortCompleter.isCompleted) {
        _sendPortCompleter.complete(message);
      }
      return;
    }
    if (message is Map<String, Object?>) {
      final int id = message['id'] as int? ?? -1;
      final Object? data = message['data'];
      final Completer<Object?>? completer = _pending.remove(id);
      if (data is StateError) {
        completer?.completeError(data);
      } else {
        completer?.complete(data);
      }
    }
  }

  Future<void> dispose() async {
    final Isolate? isolate = _isolate;
    if (isolate != null) {
      _sendPort?.send(null);
      isolate.kill(priority: Isolate.immediate);
      _isolate = null;
    }
    await _subscription.cancel();
    _receivePort.close();
    if (!_sendPortCompleter.isCompleted) {
      _sendPortCompleter.completeError(StateError('Worker disposed'));
    }
    for (final Completer<Object?> completer in _pending.values) {
      completer.completeError(StateError('Painting worker disposed'));
    }
    _pending.clear();
  }

  PaintingWorkerPatch _parsePatchResponse(
    Object? response, {
    int? fallbackLeft,
    int? fallbackTop,
    int? fallbackWidth,
    int? fallbackHeight,
  }) {
    if (response is Map<String, Object?>) {
      final int left = response['left'] as int? ?? fallbackLeft ?? 0;
      final int top = response['top'] as int? ?? fallbackTop ?? 0;
      final int width = response['width'] as int? ?? fallbackWidth ?? 0;
      final int height = response['height'] as int? ?? fallbackHeight ?? 0;
      final TransferableTypedData? data =
          response['pixels'] as TransferableTypedData?;
      if (data == null) {
        return PaintingWorkerPatch(
          left: left,
          top: top,
          width: width,
          height: height,
          pixels: Uint32List(width * height),
        );
      }
      final ByteBuffer buffer = data.materialize();
      return PaintingWorkerPatch(
        left: left,
        top: top,
        width: width,
        height: height,
        pixels: Uint32List.view(
          buffer,
          0,
          buffer.lengthInBytes ~/ Uint32List.bytesPerElement,
        ),
      );
    }
    if (response is TransferableTypedData) {
      if (fallbackLeft == null ||
          fallbackTop == null ||
          fallbackWidth == null ||
          fallbackHeight == null) {
        throw StateError('Missing fallback for worker patch response');
      }
      final ByteBuffer buffer = response.materialize();
      return PaintingWorkerPatch(
        left: fallbackLeft,
        top: fallbackTop,
        width: fallbackWidth,
        height: fallbackHeight,
        pixels: Uint32List.view(
          buffer,
          0,
          buffer.lengthInBytes ~/ Uint32List.bytesPerElement,
        ),
      );
    }
    throw StateError('Invalid worker patch response: $response');
  }
}

class _PaintingWorkerState {
  BitmapSurface? surface;
  Uint8List? selectionMask;
}

@pragma('vm:entry-point')
void _paintingWorkerMain(SendPort initialReplyTo) {
  final ReceivePort port = ReceivePort();
  final _PaintingWorkerState state = _PaintingWorkerState();
  initialReplyTo.send(port.sendPort);
  port.listen((Object? message) {
    if (message == null) {
      port.close();
      return;
    }
    if (message is! Map<String, Object?>) {
      return;
    }
    final int id = message['id'] as int? ?? -1;
    final Object? payload = message['payload'];
    if (payload is! Map<String, Object?>) {
      initialReplyTo.send(<String, Object?>{'id': id, 'data': null});
      return;
    }
    try {
      final Object? result = _paintingWorkerHandlePayload(state, payload);
      initialReplyTo.send(<String, Object?>{'id': id, 'data': result});
    } catch (error, stackTrace) {
      initialReplyTo.send(<String, Object?>{
        'id': id,
        'data': StateError('$error\n$stackTrace'),
      });
    }
  });
}

Object? _paintingWorkerHandlePayload(
  _PaintingWorkerState state,
  Map<String, Object?> payload,
) {
  final String kind = payload['kind'] as String? ?? '';
  switch (kind) {
    case 'setSurface':
      return _paintingWorkerHandleSetSurface(state, payload);
    case 'syncSurface':
      return _paintingWorkerHandleSyncSurface(state, payload);
    case 'selection':
      return _paintingWorkerHandleSelection(state, payload);
    case 'draw':
      return _paintingWorkerHandleDraw(state, payload);
    case 'floodFill':
      return _paintingWorkerHandleFloodFill(state, payload);
    case 'selectionMask':
      return _paintingWorkerHandleSelectionMask(payload);
  }
  return null;
}

Object? _paintingWorkerHandleSetSurface(
  _PaintingWorkerState state,
  Map<String, Object?> payload,
) {
  final int width = payload['width'] as int? ?? 0;
  final int height = payload['height'] as int? ?? 0;
  final TransferableTypedData? pixelsData =
      payload['pixels'] as TransferableTypedData?;
  if (width <= 0 || height <= 0 || pixelsData == null) {
    state.surface = null;
    return null;
  }
  final ByteBuffer buffer = pixelsData.materialize();
  final Uint32List pixels = Uint32List.view(
    buffer,
    0,
    buffer.lengthInBytes ~/ Uint32List.bytesPerElement,
  );
  final BitmapSurface surface = BitmapSurface(width: width, height: height);
  surface.pixels.setAll(0, pixels);
  state.surface = surface;
  return null;
}

Object? _paintingWorkerHandleSyncSurface(
  _PaintingWorkerState state,
  Map<String, Object?> payload,
) {
  final BitmapSurface? surface = state.surface;
  if (surface == null) {
    return null;
  }
  final int left = payload['left'] as int? ?? 0;
  final int top = payload['top'] as int? ?? 0;
  final int width = payload['width'] as int? ?? 0;
  final int height = payload['height'] as int? ?? 0;
  final TransferableTypedData? pixelsData =
      payload['pixels'] as TransferableTypedData?;
  if (width <= 0 || height <= 0 || pixelsData == null) {
    return null;
  }
  final ByteBuffer buffer = pixelsData.materialize();
  final Uint32List patchPixels = Uint32List.view(
    buffer,
    0,
    buffer.lengthInBytes ~/ Uint32List.bytesPerElement,
  );
  _paintingWorkerBlitPatch(
    surface: surface,
    left: left,
    top: top,
    width: width,
    height: height,
    pixels: patchPixels,
  );
  return null;
}

Object? _paintingWorkerHandleSelection(
  _PaintingWorkerState state,
  Map<String, Object?> payload,
) {
  final TransferableTypedData? maskData =
      payload['mask'] as TransferableTypedData?;
  if (maskData == null) {
    state.selectionMask = null;
    return null;
  }
  final ByteBuffer buffer = maskData.materialize();
  state.selectionMask = buffer.asUint8List();
  return null;
}

Object? _paintingWorkerHandleDraw(
  _PaintingWorkerState state,
  Map<String, Object?> payload,
) {
  final int left = payload['left'] as int? ?? 0;
  final int top = payload['top'] as int? ?? 0;
  final int width = payload['width'] as int? ?? 0;
  final int height = payload['height'] as int? ?? 0;
  final TransferableTypedData? pixelData =
      payload['pixels'] as TransferableTypedData?;
  final List<Map<String, Object?>> commands =
      ((payload['commands'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, Object?>>()
          .toList(growable: false);
  if (width <= 0 || height <= 0 || commands.isEmpty) {
    return _paintingWorkerEmptyPatch(left, top, width, height);
  }

  if (pixelData != null) {
    // 兼容旧路径：提供基准 patch，由 worker 在局部 surface 上绘制。
    final BitmapSurface tempSurface = BitmapSurface(width: width, height: height);
    final ByteBuffer buffer = pixelData.materialize();
    final Uint32List patchPixels = Uint32List.view(
      buffer,
      0,
      width * height,
    );
    tempSurface.pixels.setAll(0, patchPixels);
    Uint8List? mask;
    final TransferableTypedData? maskData =
        payload['mask'] as TransferableTypedData?;
    if (maskData != null) {
      mask = maskData.materialize().asUint8List();
    }
    _paintingWorkerRunCommands(
      surface: tempSurface,
      commands: commands,
      originX: left.toDouble(),
      originY: top.toDouble(),
      mask: mask,
    );
    return <String, Object?>{
      'left': left,
      'top': top,
      'width': width,
      'height': height,
      'pixels': TransferableTypedData.fromList(
        <Uint8List>[Uint8List.view(tempSurface.pixels.buffer)],
      ),
    };
  }

  final BitmapSurface? surface = state.surface;
  if (surface == null) {
    return _paintingWorkerEmptyPatch(left, top, width, height);
  }
  final int clampedLeft = left.clamp(0, surface.width);
  final int clampedTop = top.clamp(0, surface.height);
  final int clampedRight = math.min(clampedLeft + width, surface.width);
  final int clampedBottom = math.min(clampedTop + height, surface.height);
  if (clampedRight <= clampedLeft || clampedBottom <= clampedTop) {
    return _paintingWorkerEmptyPatch(left, top, width, height);
  }
  _paintingWorkerRunCommands(
    surface: surface,
    commands: commands,
    // 在 worker 的主 surface 上绘图时，命令使用的是全局坐标，
    // 因此不应再减去 patch 的 left/top。
    originX: 0.0,
    originY: 0.0,
    mask: state.selectionMask,
  );
  return _paintingWorkerExportPatch(
    surface: surface,
    left: clampedLeft,
    top: clampedTop,
    width: clampedRight - clampedLeft,
    height: clampedBottom - clampedTop,
  );
}

Map<String, Object?> _paintingWorkerEmptyPatch(
  int left,
  int top,
  int width,
  int height,
) {
  return <String, Object?>{
    'left': left,
    'top': top,
    'width': width,
    'height': height,
    'pixels': TransferableTypedData.fromList(const <Uint8List>[]),
  };
}

void _paintingWorkerRunCommands({
  required BitmapSurface surface,
  required List<Map<String, Object?>> commands,
  required double originX,
  required double originY,
  required Uint8List? mask,
}) {
  for (final Map<String, Object?> command in commands) {
    _paintingWorkerApplyCommand(
      surface: surface,
      command: command,
      originX: originX,
      originY: originY,
      mask: mask,
    );
  }
}

Map<String, Object?> _paintingWorkerExportPatch({
  required BitmapSurface surface,
  required int left,
  required int top,
  required int width,
  required int height,
}) {
  if (width <= 0 || height <= 0) {
    return _paintingWorkerEmptyPatch(left, top, width, height);
  }
  final Uint32List patch = Uint32List(width * height);
  for (int row = 0; row < height; row++) {
    final int srcOffset = (top + row) * surface.width + left;
    final int dstOffset = row * width;
    patch.setRange(
      dstOffset,
      dstOffset + width,
      surface.pixels,
      srcOffset,
    );
  }
  return <String, Object?>{
    'left': left,
    'top': top,
    'width': width,
    'height': height,
    'pixels': TransferableTypedData.fromList(
      <Uint8List>[Uint8List.view(patch.buffer)],
    ),
  };
}

void _paintingWorkerBlitPatch({
  required BitmapSurface surface,
  required int left,
  required int top,
  required int width,
  required int height,
  required Uint32List pixels,
}) {
  if (width <= 0 || height <= 0) {
    return;
  }
  final int surfaceWidth = surface.width;
  final int surfaceHeight = surface.height;
  if (surfaceWidth <= 0 || surfaceHeight <= 0) {
    return;
  }
  final int clampedLeft = math.max(0, math.min(left, surfaceWidth - 1));
  final int clampedTop = math.max(0, math.min(top, surfaceHeight - 1));
  final int maxWidth = math.min(width, surfaceWidth - clampedLeft);
  final int maxHeight = math.min(height, surfaceHeight - clampedTop);
  for (int row = 0; row < maxHeight; row++) {
    final int srcOffset = row * width;
    final int dstOffset = (clampedTop + row) * surface.width + clampedLeft;
    surface.pixels.setRange(
      dstOffset,
      dstOffset + maxWidth,
      pixels,
      srcOffset,
    );
  }
}

void _paintingWorkerApplyCommand({
  required BitmapSurface surface,
  required Map<String, Object?> command,
  required double originX,
  required double originY,
  required Uint8List? mask,
}) {
  final PaintingDrawCommandType type = PaintingDrawCommandType.values[
      (command['type'] as int? ?? 0)
          .clamp(0, PaintingDrawCommandType.values.length - 1)];
  final Color color = Color(command['color'] as int? ?? 0);
  final bool erase = command['erase'] as bool? ?? false;
  final int antialias = (command['antialias'] as int? ?? 0).clamp(0, 3);
  switch (type) {
    case PaintingDrawCommandType.brushStamp:
      final List<double>? centerData =
          (command['center'] as List<dynamic>?)?.cast<double>();
      final double radius = (command['radius'] as num? ?? 0).toDouble();
      final int shapeIndex = command['shape'] as int? ?? 0;
      final BrushShape shape = BrushShape
          .values[shapeIndex.clamp(0, BrushShape.values.length - 1)];
      surface.drawBrushStamp(
        center: _relativeOffset(centerData, originX, originY),
        radius: radius,
        color: color,
        shape: shape,
        mask: mask,
        antialiasLevel: antialias,
        erase: erase,
      );
      break;
    case PaintingDrawCommandType.line:
      final List<double>? startData =
          (command['start'] as List<dynamic>?)?.cast<double>();
      final List<double>? endData =
          (command['end'] as List<dynamic>?)?.cast<double>();
      final double radius = (command['radius'] as num? ?? 0).toDouble();
      final bool includeStartCap = command['includeStartCap'] as bool? ?? true;
      surface.drawLine(
        a: _relativeOffset(startData, originX, originY),
        b: _relativeOffset(endData, originX, originY),
        radius: radius,
        color: color,
        mask: mask,
        antialiasLevel: antialias,
        includeStartCap: includeStartCap,
        erase: erase,
      );
      break;
    case PaintingDrawCommandType.variableLine:
      final List<double>? startData =
          (command['start'] as List<dynamic>?)?.cast<double>();
      final List<double>? endData =
          (command['end'] as List<dynamic>?)?.cast<double>();
      final double startRadius =
          (command['startRadius'] as num? ?? 0).toDouble();
      final double endRadius = (command['endRadius'] as num? ?? 0).toDouble();
      final bool includeStartCap = command['includeStartCap'] as bool? ?? true;
      surface.drawVariableLine(
        a: _relativeOffset(startData, originX, originY),
        b: _relativeOffset(endData, originX, originY),
        startRadius: startRadius,
        endRadius: endRadius,
        color: color,
        mask: mask,
        antialiasLevel: antialias,
        includeStartCap: includeStartCap,
        erase: erase,
      );
      break;
    case PaintingDrawCommandType.stampSegment:
      final List<double>? startData =
          (command['start'] as List<dynamic>?)?.cast<double>();
      final List<double>? endData =
          (command['end'] as List<dynamic>?)?.cast<double>();
      final double startRadius =
          (command['startRadius'] as num? ?? 0).toDouble();
      final double endRadius = (command['endRadius'] as num? ?? 0).toDouble();
      final bool includeStart = command['includeStartCap'] as bool? ?? true;
      final int shapeIndex = command['shape'] as int? ?? 0;
      final BrushShape shape = BrushShape
          .values[shapeIndex.clamp(0, BrushShape.values.length - 1)];
      _paintingWorkerStampSegment(
        surface: surface,
        start: _relativeOffset(startData, originX, originY),
        end: _relativeOffset(endData, originX, originY),
        startRadius: startRadius,
        endRadius: endRadius,
        includeStart: includeStart,
        shape: shape,
        color: color,
        mask: mask,
        antialias: antialias,
        erase: erase,
      );
      break;
  }
}

Offset _relativeOffset(
  List<double>? values,
  double originX,
  double originY,
) {
  if (values == null || values.length < 2) {
    return Offset.zero;
  }
  return Offset(values[0] - originX, values[1] - originY);
}

Object? _paintingWorkerHandleFloodFill(
  _PaintingWorkerState state,
  Map<String, Object?> payload,
) {
  final TransferableTypedData? pixelData =
      payload['pixels'] as TransferableTypedData?;
  if (pixelData != null) {
    return _paintingWorkerHandleLegacyFloodFill(payload, pixelData);
  }
  final BitmapSurface? surface = state.surface;
  if (surface == null) {
    return _paintingWorkerEmptyPatch(0, 0, 0, 0);
  }
  final _FloodFillResult result = _paintingWorkerFloodFillSurface(
    surface: surface,
    startX: payload['startX'] as int? ?? 0,
    startY: payload['startY'] as int? ?? 0,
    colorValue: payload['color'] as int? ?? 0,
    targetColorValue: payload['targetColor'] as int?,
    contiguous: payload['contiguous'] as bool? ?? true,
    mask: state.selectionMask,
  );
  if (!result.changed) {
    return _paintingWorkerEmptyPatch(0, 0, 0, 0);
  }
  return _paintingWorkerExportPatch(
    surface: surface,
    left: result.left,
    top: result.top,
    width: result.width,
    height: result.height,
  );
}

Map<String, Object?> _paintingWorkerHandleLegacyFloodFill(
  Map<String, Object?> payload,
  TransferableTypedData pixelData,
) {
  final int width = payload['width'] as int? ?? 0;
  final int height = payload['height'] as int? ?? 0;
  if (width <= 0 || height <= 0) {
    return _paintingWorkerEmptyPatch(0, 0, 0, 0);
  }
  final ByteBuffer pixelBuffer = pixelData.materialize();
  final Uint32List pixels = Uint32List.view(
    pixelBuffer,
    0,
    width * height,
  );
  final BitmapSurface surface = BitmapSurface(width: width, height: height);
  surface.pixels.setAll(0, pixels);
  Uint8List? mask;
  final TransferableTypedData? maskData =
      payload['mask'] as TransferableTypedData?;
  if (maskData != null) {
    final ByteBuffer buffer = maskData.materialize();
    mask = buffer.asUint8List();
  }
  final int startX = payload['startX'] as int? ?? 0;
  final int startY = payload['startY'] as int? ?? 0;
  final int colorValue = payload['color'] as int? ?? 0;
  final int? targetColorValue = payload['targetColor'] as int?;
  final bool contiguous = payload['contiguous'] as bool? ?? true;
  surface.floodFill(
    start: Offset(startX.toDouble(), startY.toDouble()),
    color: Color(colorValue),
    targetColor:
        targetColorValue != null ? Color(targetColorValue) : null,
    contiguous: contiguous,
    mask: mask,
  );
  return _paintingWorkerExportPatch(
    surface: surface,
    left: 0,
    top: 0,
    width: width,
    height: height,
  );
}

TransferableTypedData _paintingWorkerHandleSelectionMask(
  Map<String, Object?> payload,
) {
  final int width = payload['width'] as int? ?? 0;
  final int height = payload['height'] as int? ?? 0;
  final TransferableTypedData? pixelData =
      payload['pixels'] as TransferableTypedData?;
  final int startX = payload['startX'] as int? ?? 0;
  final int startY = payload['startY'] as int? ?? 0;
  final int tolerance = (payload['tolerance'] as int? ?? 0).clamp(0, 255);
  if (width <= 0 || height <= 0 || pixelData == null) {
    return TransferableTypedData.fromList(const <Uint8List>[]);
  }
  final ByteBuffer pixelBuffer = pixelData.materialize();
  final Uint32List pixels = Uint32List.view(
    pixelBuffer,
    0,
    width * height,
  );
  final Uint8List mask = Uint8List(width * height);
  final int target = pixels[startY * width + startX];
  _paintingWorkerFloodMask(
    pixels: pixels,
    targetColor: target,
    width: width,
    height: height,
    startX: startX,
    startY: startY,
    tolerance: tolerance,
    mask: mask,
  );
  return TransferableTypedData.fromList(<Uint8List>[mask]);
}

void _paintingWorkerStampSegment({
  required BitmapSurface surface,
  required Offset start,
  required Offset end,
  required double startRadius,
  required double endRadius,
  required bool includeStart,
  required BrushShape shape,
  required Color color,
  required Uint8List? mask,
  required int antialias,
  required bool erase,
}) {
  final double distance = (end - start).distance;
  if (!distance.isFinite || distance <= 0.0001) {
    surface.drawBrushStamp(
      center: end,
      radius: endRadius,
      color: color,
      shape: shape,
      mask: mask,
      antialiasLevel: antialias,
      erase: erase,
    );
    return;
  }
  final double maxRadius = math.max(
    math.max(startRadius.abs(), endRadius.abs()),
    0.01,
  );
  final double spacing = _paintingWorkerStampSpacing(maxRadius);
  final int samples = math.max(1, (distance / spacing).ceil());
  final int startIndex = includeStart ? 0 : 1;
  for (int i = startIndex; i <= samples; i++) {
    final double t = samples == 0 ? 1.0 : (i / samples);
    final double radius =
        lerpDouble(startRadius, endRadius, t) ?? endRadius;
    final double sampleX = lerpDouble(start.dx, end.dx, t) ?? end.dx;
    final double sampleY = lerpDouble(start.dy, end.dy, t) ?? end.dy;
    surface.drawBrushStamp(
      center: Offset(sampleX, sampleY),
      radius: radius,
      color: color,
      shape: shape,
      mask: mask,
      antialiasLevel: antialias,
      erase: erase,
    );
  }
}

double _paintingWorkerStampSpacing(double radius) {
  if (!radius.isFinite) {
    return 0.5;
  }
  const double minSpacing = 0.45;
  const double maxSpacing = 0.98;
  const double minRadius = 0.01;
  const double maxRadius = 28.0;
  final double normalized = ((radius - minRadius) / (maxRadius - minRadius))
      .clamp(0.0, 1.0);
  final double spacing =
      minSpacing + (maxSpacing - minSpacing) * normalized;
  return math.max(spacing, minSpacing);
}

class _FloodFillResult {
  const _FloodFillResult._({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.changed,
  });

  factory _FloodFillResult.none() => const _FloodFillResult._(
        left: 0,
        top: 0,
        width: 0,
        height: 0,
        changed: false,
      );

  factory _FloodFillResult.region({
    required int left,
    required int top,
    required int width,
    required int height,
  }) => _FloodFillResult._(
        left: left,
        top: top,
        width: width,
        height: height,
        changed: true,
      );

  final int left;
  final int top;
  final int width;
  final int height;
  final bool changed;
}

_FloodFillResult _paintingWorkerFloodFillSurface({
  required BitmapSurface surface,
  required int startX,
  required int startY,
  required int colorValue,
  int? targetColorValue,
  required bool contiguous,
  Uint8List? mask,
}) {
  final int width = surface.width;
  final int height = surface.height;
  if (startX < 0 || startX >= width || startY < 0 || startY >= height) {
    return _FloodFillResult.none();
  }
  final Uint32List pixels = surface.pixels;
  final int startIndex = startY * width + startX;
  final int baseColor = targetColorValue ?? pixels[startIndex];
  final int replacement = colorValue;
  if (baseColor == replacement) {
    return _FloodFillResult.none();
  }
  if (!contiguous) {
    return _paintingWorkerFloodFillNonContiguous(
      pixels: pixels,
      width: width,
      height: height,
      baseColor: baseColor,
      replacement: replacement,
      mask: mask,
    );
  }
  return _paintingWorkerFloodFillContiguous(
    pixels: pixels,
    width: width,
    height: height,
    baseColor: baseColor,
    replacement: replacement,
    startX: startX,
    startY: startY,
    mask: mask,
  );
}

_FloodFillResult _paintingWorkerFloodFillNonContiguous({
  required Uint32List pixels,
  required int width,
  required int height,
  required int baseColor,
  required int replacement,
  Uint8List? mask,
}) {
  int minX = width;
  int minY = height;
  int maxX = -1;
  int maxY = -1;
  bool changed = false;
  for (int i = 0; i < pixels.length; i++) {
    if (pixels[i] != baseColor) {
      continue;
    }
    if (mask != null && mask[i] == 0) {
      continue;
    }
    pixels[i] = replacement;
    changed = true;
    final int px = i % width;
    final int py = i ~/ width;
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
  if (!changed) {
    return _FloodFillResult.none();
  }
  return _FloodFillResult.region(
    left: minX,
    top: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
}

_FloodFillResult _paintingWorkerFloodFillContiguous({
  required Uint32List pixels,
  required int width,
  required int height,
  required int baseColor,
  required int replacement,
  required int startX,
  required int startY,
  Uint8List? mask,
}) {
  final int startIndex = startY * width + startX;
  if (mask != null && mask[startIndex] == 0) {
    return _FloodFillResult.none();
  }
  final List<int> stack = <int>[startIndex];
  bool changed = false;
  int minX = width;
  int minY = height;
  int maxX = -1;
  int maxY = -1;
  while (stack.isNotEmpty) {
    final int index = stack.removeLast();
    if (index < 0 || index >= pixels.length) {
      continue;
    }
    if (pixels[index] != baseColor) {
      continue;
    }
    if (mask != null && mask[index] == 0) {
      continue;
    }
    pixels[index] = replacement;
    changed = true;
    final int x = index % width;
    final int y = index ~/ width;
    if (x < minX) {
      minX = x;
    }
    if (y < minY) {
      minY = y;
    }
    if (x > maxX) {
      maxX = x;
    }
    if (y > maxY) {
      maxY = y;
    }
    if (x > 0) {
      stack.add(index - 1);
    }
    if (x < width - 1) {
      stack.add(index + 1);
    }
    if (y > 0) {
      stack.add(index - width);
    }
    if (y < height - 1) {
      stack.add(index + width);
    }
  }
  if (!changed) {
    return _FloodFillResult.none();
  }
  return _FloodFillResult.region(
    left: minX,
    top: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
}

void _paintingWorkerFloodMask({
  required Uint32List pixels,
  required int targetColor,
  required int width,
  required int height,
  required int startX,
  required int startY,
  required int tolerance,
  required Uint8List mask,
}) {
  if (startX < 0 ||
      startX >= width ||
      startY < 0 ||
      startY >= height) {
    return;
  }
  final int baseA = (targetColor >> 24) & 0xff;
  final int baseR = (targetColor >> 16) & 0xff;
  final int baseG = (targetColor >> 8) & 0xff;
  final int baseB = targetColor & 0xff;
  final int toleranceSq = tolerance * tolerance * 3;
  final List<int> stack = <int>[startY * width + startX];
  while (stack.isNotEmpty) {
    final int index = stack.removeLast();
    if (index < 0 || index >= pixels.length) {
      continue;
    }
    if (mask[index] != 0) {
      continue;
    }
    final int color = pixels[index];
    final int a = (color >> 24) & 0xff;
    final int r = (color >> 16) & 0xff;
    final int g = (color >> 8) & 0xff;
    final int b = color & 0xff;
    final int da = a - baseA;
    final int dr = r - baseR;
    final int dg = g - baseG;
    final int db = b - baseB;
    final int distanceSq = da * da + dr * dr + dg * dg + db * db;
    if (distanceSq > toleranceSq) {
      continue;
    }
    mask[index] = 0xff;
    final int x = index % width;
    final int y = index ~/ width;
    if (x > 0) {
      stack.add(index - 1);
    }
    if (x < width - 1) {
      stack.add(index + 1);
    }
    if (y > 0) {
      stack.add(index - width);
    }
    if (y < height - 1) {
      stack.add(index + width);
    }
  }
}
