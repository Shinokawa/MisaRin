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

class PaintingDrawPatchRequest {
  PaintingDrawPatchRequest({
    required this.width,
    required this.height,
    required this.pixels,
    this.mask,
    required this.command,
  });

  final int width;
  final int height;
  final TransferableTypedData pixels;
  final TransferableTypedData? mask;
  final PaintingDrawCommand command;
}

class PaintingFloodFillRequest {
  PaintingFloodFillRequest({
    required this.width,
    required this.height,
    required this.pixels,
    required this.startX,
    required this.startY,
    required this.colorValue,
    this.targetColorValue,
    this.contiguous = true,
    this.mask,
  });

  final int width;
  final int height;
  final TransferableTypedData pixels;
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

  Future<Uint32List> drawPatch(PaintingDrawPatchRequest request) async {
    await _ensureStarted();
    final Object? response = await _sendRequest(<String, Object?>{
      'kind': 'draw',
      'width': request.width,
      'height': request.height,
      'pixels': request.pixels,
      'mask': request.mask,
      'command': request.command.toJson(),
    });
    if (response is! TransferableTypedData) {
      throw StateError('Invalid draw response: $response');
    }
    final ByteBuffer buffer = response.materialize();
    return Uint32List.view(
      buffer,
      0,
      buffer.lengthInBytes ~/ Uint32List.bytesPerElement,
    );
  }

  Future<Uint32List> floodFill(PaintingFloodFillRequest request) async {
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
    if (response is! TransferableTypedData) {
      throw StateError('Invalid flood fill response: $response');
    }
    final ByteBuffer buffer = response.materialize();
    return Uint32List.view(
      buffer,
      0,
      buffer.lengthInBytes ~/ Uint32List.bytesPerElement,
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
}

@pragma('vm:entry-point')
void _paintingWorkerMain(SendPort initialReplyTo) {
  final ReceivePort port = ReceivePort();
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
      final Object? result = _paintingWorkerHandlePayload(payload);
      initialReplyTo.send(<String, Object?>{'id': id, 'data': result});
    } catch (error, stackTrace) {
      initialReplyTo.send(<String, Object?>{
        'id': id,
        'data': StateError('$error\n$stackTrace'),
      });
    }
  });
}

Object? _paintingWorkerHandlePayload(Map<String, Object?> payload) {
  final String kind = payload['kind'] as String? ?? '';
  switch (kind) {
    case 'draw':
      return _paintingWorkerHandleDraw(payload);
    case 'floodFill':
      return _paintingWorkerHandleFloodFill(payload);
    case 'selectionMask':
      return _paintingWorkerHandleSelectionMask(payload);
  }
  return null;
}

TransferableTypedData _paintingWorkerHandleDraw(Map<String, Object?> payload) {
  final int width = payload['width'] as int? ?? 0;
  final int height = payload['height'] as int? ?? 0;
  final TransferableTypedData? pixelData =
      payload['pixels'] as TransferableTypedData?;
  if (width <= 0 || height <= 0 || pixelData == null) {
    return TransferableTypedData.fromList(const <Uint8List>[]);
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
  final Map<String, Object?> command =
      (payload['command'] as Map<String, Object?>?) ?? const <String, Object?>{};
  final PaintingDrawCommandType type = PaintingDrawCommandType
      .values[(command['type'] as int? ?? 0).clamp(0,
          PaintingDrawCommandType.values.length - 1)];
  final Color color = Color(command['color'] as int? ?? 0);
  final bool erase = command['erase'] as bool? ?? false;
  final int antialias =
      (command['antialias'] as int? ?? 0).clamp(0, 3);
  switch (type) {
    case PaintingDrawCommandType.brushStamp:
      final List<double>? centerData =
          (command['center'] as List<dynamic>?)?.cast<double>();
      final double radius = (command['radius'] as num? ?? 0).toDouble();
      final int shapeIndex = command['shape'] as int? ?? 0;
      final BrushShape shape = BrushShape
          .values[shapeIndex.clamp(0, BrushShape.values.length - 1)];
      surface.drawBrushStamp(
        center: Offset(centerData?[0] ?? 0, centerData?[1] ?? 0),
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
        a: Offset(startData?[0] ?? 0, startData?[1] ?? 0),
        b: Offset(endData?[0] ?? 0, endData?[1] ?? 0),
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
        a: Offset(startData?[0] ?? 0, startData?[1] ?? 0),
        b: Offset(endData?[0] ?? 0, endData?[1] ?? 0),
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
        start: Offset(startData?[0] ?? 0, startData?[1] ?? 0),
        end: Offset(endData?[0] ?? 0, endData?[1] ?? 0),
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
  return TransferableTypedData.fromList(
    <Uint8List>[Uint8List.view(surface.pixels.buffer)],
  );
}

TransferableTypedData _paintingWorkerHandleFloodFill(
  Map<String, Object?> payload,
) {
  final int width = payload['width'] as int? ?? 0;
  final int height = payload['height'] as int? ?? 0;
  final TransferableTypedData? pixelData =
      payload['pixels'] as TransferableTypedData?;
  if (width <= 0 || height <= 0 || pixelData == null) {
    return TransferableTypedData.fromList(const <Uint8List>[]);
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
  return TransferableTypedData.fromList(
    <Uint8List>[Uint8List.view(surface.pixels.buffer)],
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
