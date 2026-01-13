import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';

import 'package:misa_rin/src/rust/canvas_engine_ffi.dart';

const int _kPointStrideBytes = 32;
const int _kPointFlagDown = 1;
const int _kPointFlagMove = 2;
const int _kPointFlagUp = 4;

final class _PackedPointBuffer {
  _PackedPointBuffer({int initialCapacityPoints = 256})
    : _bytes = Uint8List(initialCapacityPoints * _kPointStrideBytes),
      _data = ByteData.view(_bytes.buffer);

  Uint8List _bytes;
  ByteData _data;
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

class RustCanvasTextureWidget extends StatefulWidget {
  const RustCanvasTextureWidget({
    super.key,
    this.canvasSize = const Size(512, 512),
  });

  final Size canvasSize;

  @override
  State<RustCanvasTextureWidget> createState() => _RustCanvasTextureWidgetState();
}

class _RustCanvasTextureWidgetState extends State<RustCanvasTextureWidget> {
  static const MethodChannel _channel = MethodChannel('misarin/rust_canvas_texture');

  int? _textureId;
  int? _engineHandle;
  Object? _error;

  final _PackedPointBuffer _points = _PackedPointBuffer();
  bool _flushScheduled = false;
  int? _activeDrawingPointer;
  Size _viewSize = Size.zero;

  double _scale = 1.0;
  Offset _pan = Offset.zero;

  double _gestureStartScale = 1.0;
  Offset _gestureStartPan = Offset.zero;
  Offset _gestureStartFocalPoint = Offset.zero;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTextureInfo());
  }

  Future<void> _loadTextureInfo() async {
    try {
      final Map<dynamic, dynamic>? info =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getTextureInfo');
      final int? textureId = (info?['textureId'] as num?)?.toInt();
      final int? engineHandle = (info?['engineHandle'] as num?)?.toInt();
      if (!mounted) {
        return;
      }
      setState(() {
        _textureId = textureId;
        _engineHandle = engineHandle;
        _error =
            (textureId == null || engineHandle == null)
                ? StateError('textureId/engineHandle == null: $info')
                : null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _textureId = null;
        _engineHandle = null;
        _error = error;
      });
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _gestureStartScale = _scale;
    _gestureStartPan = _pan;
    _gestureStartFocalPoint = details.focalPoint;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) {
      return;
    }
    final double nextScale = (_gestureStartScale * details.scale).clamp(0.1, 64.0);
    final Offset nextPan =
        _gestureStartPan + (details.focalPoint - _gestureStartFocalPoint);
    setState(() {
      _scale = nextScale;
      _pan = nextPan;
    });
  }

  bool _canSendPoints() {
    return CanvasEngineFfi.instance.isSupported && _engineHandle != null;
  }

  bool _isDrawingPointer(PointerEvent event) {
    switch (event.kind) {
      case PointerDeviceKind.stylus:
      case PointerDeviceKind.invertedStylus:
        return true;
      case PointerDeviceKind.mouse:
        return (event.buttons & kPrimaryButton) != 0;
      default:
        return false;
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_canSendPoints() || !_isDrawingPointer(event)) {
      return;
    }
    _activeDrawingPointer = event.pointer;
    _enqueuePoint(event, _kPointFlagDown);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_activeDrawingPointer != event.pointer) {
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
        return;
      }
    } catch (_) {}
    _enqueuePoint(event, _kPointFlagMove);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activeDrawingPointer != event.pointer) {
      return;
    }
    _enqueuePoint(event, _kPointFlagUp);
    _activeDrawingPointer = null;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activeDrawingPointer != event.pointer) {
      return;
    }
    _enqueuePoint(event, _kPointFlagUp);
    _activeDrawingPointer = null;
  }

  void _enqueuePoint(PointerEvent event, int flags) {
    final int? handle = _engineHandle;
    if (handle == null) {
      return;
    }
    if (_viewSize.isEmpty) {
      return;
    }
    final Offset canvasPos = _toCanvasSpace(event.localPosition, _viewSize);
    final double pressure =
        event.pressure.isFinite ? event.pressure.clamp(0.0, 1.0) : 1.0;
    final int timestampUs = event.timeStamp.inMicroseconds;
    _points.add(
      x: canvasPos.dx,
      y: canvasPos.dy,
      pressure: pressure,
      timestampUs: timestampUs,
      flags: flags,
      pointerId: event.pointer,
    );
    _scheduleFlush();
  }

  void _scheduleFlush() {
    if (_flushScheduled) {
      return;
    }
    _flushScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _flushScheduled = false;
      if (!mounted) {
        _points.clear();
        return;
      }
      final int? handle = _engineHandle;
      if (handle == null) {
        _points.clear();
        return;
      }
      _flushToRust(handle);
    });
  }

  void _flushToRust(int handle) {
    final int count = _points.length;
    if (count == 0) {
      return;
    }
    CanvasEngineFfi.instance.pushPointsPacked(
      handle: handle,
      bytes: _points.bytes,
      pointCount: count,
    );
    _points.clear();
  }

  Offset _toCanvasSpace(Offset localPos, Size viewSize) {
    final Offset viewCenter = viewSize.center(Offset.zero);
    final Offset canvasCenter = viewCenter + _pan;
    final Offset unscaled = (localPos - canvasCenter) / _scale;
    return unscaled +
        Offset(widget.canvasSize.width / 2.0, widget.canvasSize.height / 2.0);
  }

  @override
  Widget build(BuildContext context) {
    final int? textureId = _textureId;
    final Object? error = _error;

    if (error != null) {
      return ColoredBox(
        color: const Color(0xFF000000),
        child: Center(
          child: Text(
            'Rust texture init failed: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFFFFFF)),
          ),
        ),
      );
    }

    if (textureId == null) {
      return const ColoredBox(
        color: Color(0xFF000000),
        child: Center(
          child: Text(
            'Initializing Rust texture…',
            style: TextStyle(color: Color(0xFFFFFFFF)),
          ),
        ),
      );
    }

    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          _viewSize = constraints.biggest;
          return GestureDetector(
            onScaleStart: _handleScaleStart,
            onScaleUpdate: _handleScaleUpdate,
            child: Listener(
              onPointerDown: _handlePointerDown,
              onPointerMove: _handlePointerMove,
              onPointerUp: _handlePointerUp,
              onPointerCancel: _handlePointerCancel,
              child: ColoredBox(
                color: const Color(0xFF000000),
                child: Center(
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..translateByDouble(_pan.dx, _pan.dy, 0, 1)
                      ..scaleByDouble(_scale, _scale, 1, 1),
                    child: SizedBox(
                      width: widget.canvasSize.width,
                      height: widget.canvasSize.height,
                      child: Texture(textureId: textureId),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
