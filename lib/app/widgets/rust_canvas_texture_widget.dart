import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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
    final double nextScale = (_gestureStartScale * details.scale).clamp(0.1, 64.0);
    final Offset nextPan =
        _gestureStartPan + (details.focalPoint - _gestureStartFocalPoint);
    setState(() {
      _scale = nextScale;
      _pan = nextPan;
    });
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
      child: GestureDetector(
        onScaleStart: _handleScaleStart,
        onScaleUpdate: _handleScaleUpdate,
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
  }
}
