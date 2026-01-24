import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:misa_rin/src/rust/canvas_engine_ffi.dart';

import '../../canvas/canvas_tools.dart';

const bool _kDebugRustCanvasInput = bool.fromEnvironment(
  'MISA_RIN_DEBUG_RUST_CANVAS_INPUT',
  defaultValue: false,
);

const int _kPointStrideBytes = 32;
const int _kPointFlagDown = 1;
const int _kPointFlagMove = 2;
const int _kPointFlagUp = 4;

final class _PackedPointBuffer {
  _PackedPointBuffer({int initialCapacityPoints = 256})
    : _bytes = Uint8List(initialCapacityPoints * _kPointStrideBytes) {
    _data = ByteData.view(_bytes.buffer);
  }

  Uint8List _bytes;
  late ByteData _data;
  int _len = 0;

  int get length => _len;

  Uint8List get bytes => _bytes;

  void clear() => _len = 0;

  void add({
    required double x,
    required double y,
    required double pressure,
    required int timestampUs,
    required int flags,
    required int pointerId,
  }) {
    _ensureCapacity(_len + 1);
    final int base = _len * _kPointStrideBytes;
    _data.setFloat32(base + 0, x, Endian.little);
    _data.setFloat32(base + 4, y, Endian.little);
    _data.setFloat32(base + 8, pressure, Endian.little);
    _data.setFloat32(base + 12, 0.0, Endian.little); // pad
    _data.setUint64(base + 16, timestampUs, Endian.little);
    _data.setUint32(base + 24, flags, Endian.little);
    _data.setUint32(base + 28, pointerId, Endian.little);
    _len++;
  }

  void _ensureCapacity(int neededPoints) {
    final int neededBytes = neededPoints * _kPointStrideBytes;
    if (_bytes.lengthInBytes >= neededBytes) {
      return;
    }
    int nextBytes = _bytes.lengthInBytes;
    while (nextBytes < neededBytes) {
      nextBytes = nextBytes * 2;
    }
    final Uint8List next = Uint8List(nextBytes);
    next.setRange(0, _len * _kPointStrideBytes, _bytes, 0);
    _bytes = next;
    _data = ByteData.view(_bytes.buffer);
  }
}

class RustCanvasSurface extends StatefulWidget {
  const RustCanvasSurface({
    super.key,
    required this.canvasSize,
    required this.enableDrawing,
    this.layerCount = 1,
    required this.brushColorArgb,
    required this.brushRadius,
    required this.erase,
    required this.brushShape,
    required this.brushRandomRotationEnabled,
    required this.brushRotationSeed,
    this.hollowStrokeEnabled = false,
    this.hollowStrokeRatio = 0.0,
    this.hollowStrokeEraseOccludedParts = false,
    this.antialiasLevel = 1,
    this.backgroundColorArgb = 0xFFFFFFFF,
    this.usePressure = true,
    this.onStrokeBegin,
    this.onEngineInfoChanged,
  });

  final Size canvasSize;
  final bool enableDrawing;
  final int layerCount;
  final int brushColorArgb;
  final double brushRadius;
  final bool erase;
  final BrushShape brushShape;
  final bool brushRandomRotationEnabled;
  final int brushRotationSeed;
  final bool hollowStrokeEnabled;
  final double hollowStrokeRatio;
  final bool hollowStrokeEraseOccludedParts;
  final int antialiasLevel;
  final int backgroundColorArgb;
  final bool usePressure;
  final VoidCallback? onStrokeBegin;
  final void Function(int? handle, Size? engineSize)? onEngineInfoChanged;

  @override
  State<RustCanvasSurface> createState() => _RustCanvasSurfaceState();
}

class _RustCanvasSurfaceState extends State<RustCanvasSurface> {
  static const MethodChannel _channel = MethodChannel(
    'misarin/rust_canvas_texture',
  );
  static int _nextSurfaceId = 1;

  int? _textureId;
  int? _engineHandle;
  Size? _engineSize;
  Object? _error;
  late final String _surfaceId;

  final _PackedPointBuffer _points = _PackedPointBuffer();
  int? _activeDrawingPointer;
  bool _activeStrokeUsesPressure = true;
  int? _lastNotifiedEngineHandle;
  Size? _lastNotifiedEngineSize;

  @override
  void initState() {
    super.initState();
    _surfaceId = 'rust_canvas_${_nextSurfaceId++}';
    unawaited(_loadTextureInfo());
  }

  @override
  void didUpdateWidget(covariant RustCanvasSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canvasSize != widget.canvasSize) {
      unawaited(_loadTextureInfo());
    }
    final bool brushChanged =
        oldWidget.brushColorArgb != widget.brushColorArgb ||
        (oldWidget.brushRadius - widget.brushRadius).abs() > 1e-6 ||
        oldWidget.erase != widget.erase ||
        oldWidget.antialiasLevel != widget.antialiasLevel ||
        oldWidget.usePressure != widget.usePressure ||
        oldWidget.brushShape != widget.brushShape ||
        oldWidget.brushRandomRotationEnabled !=
            widget.brushRandomRotationEnabled ||
        oldWidget.brushRotationSeed != widget.brushRotationSeed ||
        oldWidget.hollowStrokeEnabled != widget.hollowStrokeEnabled ||
        (oldWidget.hollowStrokeRatio - widget.hollowStrokeRatio).abs() > 1e-6 ||
        oldWidget.hollowStrokeEraseOccludedParts !=
            widget.hollowStrokeEraseOccludedParts;
    if (brushChanged && _activeDrawingPointer == null) {
      final int? handle = _engineHandle;
      if (handle != null) {
        _applyBrushSettings(handle);
      }
    }
    if (oldWidget.backgroundColorArgb != widget.backgroundColorArgb &&
        _activeDrawingPointer == null) {
      final int? handle = _engineHandle;
      if (handle != null) {
        _applyBackground(handle);
      }
    }
  }

  Future<void> _loadTextureInfo() async {
    try {
      final int width = widget.canvasSize.width.round().clamp(1, 16384);
      final int height = widget.canvasSize.height.round().clamp(1, 16384);
      final Map<dynamic, dynamic>? info = await _channel
          .invokeMethod<Map<dynamic, dynamic>>(
            'getTextureInfo',
            <String, Object?>{
              'surfaceId': _surfaceId,
              'width': width,
              'height': height,
              'layerCount': widget.layerCount,
              'backgroundColorArgb': widget.backgroundColorArgb,
            },
          );
      final int? textureId = (info?['textureId'] as num?)?.toInt();
      final int? engineHandle = (info?['engineHandle'] as num?)?.toInt();
      final int? engineWidth = (info?['width'] as num?)?.toInt();
      final int? engineHeight = (info?['height'] as num?)?.toInt();
      if (!mounted) {
        return;
      }
      setState(() {
        _textureId = textureId;
        _engineHandle = engineHandle;
        _engineSize = (engineWidth != null && engineHeight != null)
            ? Size(engineWidth.toDouble(), engineHeight.toDouble())
            : null;
        _error = (textureId == null || engineHandle == null)
            ? StateError('textureId/engineHandle == null: $info')
            : null;
      });

      final int? handle = _engineHandle;
      if (handle != null) {
        _applyBrushSettings(handle);
      }
      _notifyEngineInfoChanged();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _textureId = null;
        _engineHandle = null;
        _engineSize = null;
        _error = error;
      });
      _notifyEngineInfoChanged();
    }
  }

  void _notifyEngineInfoChanged() {
    final int? handle = _engineHandle;
    final Size? size = _engineSize;
    if (_lastNotifiedEngineHandle == handle &&
        _lastNotifiedEngineSize == size) {
      return;
    }
    _lastNotifiedEngineHandle = handle;
    _lastNotifiedEngineSize = size;
    widget.onEngineInfoChanged?.call(handle, size);
  }

  @override
  void dispose() {
    unawaited(_disposeSurface());
    if (_lastNotifiedEngineHandle != null || _lastNotifiedEngineSize != null) {
      widget.onEngineInfoChanged?.call(null, null);
    }
    super.dispose();
  }

  Future<void> _disposeSurface() async {
    try {
      await _channel.invokeMethod<void>('disposeTexture', <String, Object?>{
        'surfaceId': _surfaceId,
      });
    } catch (_) {}
  }

  void _applyBackground(int handle) {
    if (!CanvasEngineFfi.instance.isSupported) {
      return;
    }
    // Background is represented by layer 0 in the Rust MVP compositor.
    CanvasEngineFfi.instance.fillLayer(
      handle: handle,
      layerIndex: 0,
      colorArgb: widget.backgroundColorArgb,
    );
  }

  bool _canSendPoints() {
    return CanvasEngineFfi.instance.isSupported && _engineHandle != null;
  }

  void _applyBrushSettings(int handle, {bool? usePressureOverride}) {
    if (!CanvasEngineFfi.instance.isSupported) {
      return;
    }
    double radius = widget.brushRadius;
    final Size engineSize = _engineSize ?? widget.canvasSize;
    if (engineSize != widget.canvasSize &&
        widget.canvasSize.width > 0 &&
        widget.canvasSize.height > 0) {
      final double sx = engineSize.width / widget.canvasSize.width;
      final double sy = engineSize.height / widget.canvasSize.height;
      final double scale = (sx.isFinite && sy.isFinite)
          ? ((sx + sy) / 2.0)
          : 1.0;
      if (scale.isFinite && scale > 0) {
        radius *= scale;
      }
    }
    CanvasEngineFfi.instance.setBrush(
      handle: handle,
      colorArgb: widget.brushColorArgb,
      baseRadius: radius,
      usePressure: usePressureOverride ?? widget.usePressure,
      erase: widget.erase,
      antialiasLevel: widget.antialiasLevel,
      brushShape: widget.brushShape.index,
      randomRotation: widget.brushRandomRotationEnabled,
      rotationSeed: widget.brushRotationSeed,
      hollow: widget.hollowStrokeEnabled,
      hollowRatio: widget.hollowStrokeRatio,
      hollowEraseOccludedParts: widget.hollowStrokeEraseOccludedParts,
    );
  }

  bool _isDrawingPointer(PointerEvent event) {
    if (event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus) {
      return true;
    }
    if (event.kind == PointerDeviceKind.mouse) {
      return (event.buttons & kPrimaryMouseButton) != 0;
    }
    return false;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enableDrawing) {
      return;
    }
    if (!_canSendPoints() || !_isDrawingPointer(event)) {
      return;
    }
    final int? handle = _engineHandle;
    if (handle == null) {
      return;
    }
    if (_kDebugRustCanvasInput) {
      debugPrint(
        '[rust_canvas] down id=${event.pointer} pos=${event.localPosition} pressure=${event.pressure}',
      );
    }
    final bool supportsPressure =
        event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;
    _activeStrokeUsesPressure = widget.usePressure && supportsPressure;
    _applyBrushSettings(handle, usePressureOverride: _activeStrokeUsesPressure);
    _activeDrawingPointer = event.pointer;
    _enqueuePoint(event, _kPointFlagDown);
    _flushToRust(handle);
    widget.onStrokeBegin?.call();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_activeDrawingPointer != event.pointer) {
      return;
    }
    final int? handle = _engineHandle;
    if (handle == null) {
      return;
    }
    final dynamic dyn = event;
    try {
      final List<dynamic>? coalesced = dyn.coalescedEvents as List<dynamic>?;
      if (coalesced != null && coalesced.isNotEmpty) {
        for (final dynamic e in coalesced) {
          if (e is PointerEvent) {
            _enqueuePoint(e, _kPointFlagMove);
          }
        }
        _flushToRust(handle);
        return;
      }
    } catch (_) {}
    _enqueuePoint(event, _kPointFlagMove);
    _flushToRust(handle);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activeDrawingPointer != event.pointer) {
      return;
    }
    if (_kDebugRustCanvasInput) {
      debugPrint(
        '[rust_canvas] up id=${event.pointer} pos=${event.localPosition}',
      );
    }
    _enqueuePoint(event, _kPointFlagUp);
    final int? handle = _engineHandle;
    if (handle != null) {
      _flushToRust(handle);
    }
    _activeDrawingPointer = null;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activeDrawingPointer != event.pointer) {
      return;
    }
    if (_kDebugRustCanvasInput) {
      debugPrint(
        '[rust_canvas] cancel id=${event.pointer} pos=${event.localPosition}',
      );
    }
    _enqueuePoint(event, _kPointFlagUp);
    final int? handle = _engineHandle;
    if (handle != null) {
      _flushToRust(handle);
    }
    _activeDrawingPointer = null;
  }

  Offset _toEngineSpace(Offset localPosition) {
    final Size engineSize = _engineSize ?? widget.canvasSize;
    if (engineSize == widget.canvasSize) {
      return localPosition;
    }
    final double sx = widget.canvasSize.width <= 0
        ? 1.0
        : engineSize.width / widget.canvasSize.width;
    final double sy = widget.canvasSize.height <= 0
        ? 1.0
        : engineSize.height / widget.canvasSize.height;
    return Offset(localPosition.dx * sx, localPosition.dy * sy);
  }

  void _enqueuePoint(PointerEvent event, int flags) {
    final int? handle = _engineHandle;
    if (handle == null) {
      return;
    }
    final Offset canvasPos = _toEngineSpace(event.localPosition);
    final double pressure = !_activeStrokeUsesPressure
        ? 1.0
        : (event.pressure.isFinite ? event.pressure.clamp(0.0, 1.0) : 1.0);
    final int timestampUs = event.timeStamp.inMicroseconds;
    _points.add(
      x: canvasPos.dx,
      y: canvasPos.dy,
      pressure: pressure,
      timestampUs: timestampUs,
      flags: flags,
      pointerId: event.pointer,
    );
  }

  void _flushToRust(int handle) {
    final int count = _points.length;
    if (count == 0) {
      return;
    }
    if (_kDebugRustCanvasInput) {
      final int queued = CanvasEngineFfi.instance.getInputQueueLen(handle);
      debugPrint('[rust_canvas] flush points=$count queued_before=$queued');
    }
    CanvasEngineFfi.instance.pushPointsPacked(
      handle: handle,
      bytes: _points.bytes,
      pointCount: count,
    );
    _points.clear();
  }

  @override
  Widget build(BuildContext context) {
    final Size canvasSize = widget.canvasSize;
    final Object? error = _error;
    final int? textureId = _textureId;

    if (error != null) {
      return SizedBox(
        width: canvasSize.width,
        height: canvasSize.height,
        child: ColoredBox(
          color: const Color(0xFF000000),
          child: Center(
            child: Text(
              'Rust canvas init failed: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 12),
            ),
          ),
        ),
      );
    }

    if (textureId == null) {
      return SizedBox(
        width: canvasSize.width,
        height: canvasSize.height,
        child: const ColoredBox(color: Color(0xFFFFFFFF)),
      );
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: SizedBox(
        width: canvasSize.width,
        height: canvasSize.height,
        child: Texture(textureId: textureId, filterQuality: FilterQuality.none),
      ),
    );
  }
}
