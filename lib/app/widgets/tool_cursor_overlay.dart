import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';

import '../../brushes/brush_shape_raster.dart';
import '../../canvas/brush_shape_geometry.dart';
import '../../canvas/canvas_tools.dart';

class ToolCursorStyle {
  const ToolCursorStyle({
    required this.icon,
    required this.anchor,
    this.iconOffset = Offset.zero,
    this.hideSystemCursor = true,
  });

  final Widget icon;
  final Offset anchor;
  final Offset iconOffset;
  final bool hideSystemCursor;
}

class ToolCursorStyles {
  static ToolCursorStyle? styleFor(CanvasTool tool) => _styles[tool];

  static bool hasOverlay(CanvasTool tool) => _styles.containsKey(tool);

  static const double _defaultIconSize = 20;
  static const double crosshairSize = 11;
  static const List<Offset> _defaultOutlineOffsets = <Offset>[
    Offset(-0.75, 0),
    Offset(0.75, 0),
    Offset(0, -0.75),
    Offset(0, 0.75),
    Offset(-0.75, -0.75),
    Offset(0.75, -0.75),
    Offset(-0.75, 0.75),
    Offset(0.75, 0.75),
  ];

  static final Map<CanvasTool, ToolCursorStyle> _styles =
      <CanvasTool, ToolCursorStyle>{
        CanvasTool.eyedropper: ToolCursorStyle(
          anchor: const Offset(5, 17),
          iconOffset: const Offset(5, -2),
          icon: const _OutlinedToolCursorIcon(
            size: _defaultIconSize,
            icon: FluentIcons.eyedropper,
          ),
        ),
        CanvasTool.bucket: ToolCursorStyle(
          anchor: const Offset(8, 18),
          iconOffset: const Offset(5, -2),
          icon: const _OutlinedToolCursorIcon(
            size: _defaultIconSize,
            icon: FluentIcons.bucket_color,
            mirrorHorizontally: true,
          ),
        ),
        CanvasTool.layerAdjust: ToolCursorStyle(
          anchor: Offset.zero,
          iconOffset: const Offset(0, 0),
          icon: const _OutlinedToolCursorIcon(
            size: _defaultIconSize,
            icon: FluentIcons.move,
          ),
        ),
        CanvasTool.magicWand: ToolCursorStyle(
          anchor: Offset.zero,
          iconOffset: const Offset(-5.5, -5.5),
          icon: const _OutlinedToolCursorIcon(
            size: _defaultIconSize,
            icon: FluentIcons.auto_enhance_on,
            mirrorHorizontally: true,
          ),
        ),
      };

  static Widget _buildIcon({
    required IconData icon,
    required double size,
    required Color color,
    bool mirrorHorizontally = false,
  }) {
    Widget child = Icon(icon, size: size, color: color);
    if (mirrorHorizontally) {
      child = Transform.scale(
        scaleX: -1,
        scaleY: 1,
        alignment: Alignment.center,
        child: child,
      );
    }
    return child;
  }

  static Widget buildOutlinedIcon({
    required IconData icon,
    required double size,
    bool mirrorHorizontally = false,
    Color outlineColor = Colors.white,
    Color fillColor = Colors.black,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final Offset offset in _defaultOutlineOffsets)
            Transform.translate(
              offset: offset,
              child: _buildIcon(
                icon: icon,
                size: size,
                color: outlineColor,
                mirrorHorizontally: mirrorHorizontally,
              ),
            ),
          _buildIcon(
            icon: icon,
            size: size,
            color: fillColor,
            mirrorHorizontally: mirrorHorizontally,
          ),
        ],
      ),
    );
  }

  static Widget iconFor(CanvasTool tool, {required bool isDragging}) {
    final ToolCursorStyle? style = styleFor(tool);
    if (style == null) {
      return const SizedBox.shrink();
    }
    if (tool == CanvasTool.layerAdjust && isDragging) {
      return buildOutlinedIcon(
        icon: FluentIcons.hands_free,
        size: _defaultIconSize,
      );
    }
    return style.icon;
  }
}

class PenCursorOverlay extends StatelessWidget {
  const PenCursorOverlay({
    super.key,
    required this.position,
    required this.diameter,
    required this.shape,
    this.rotation = 0.0,
  });

  final Offset position;
  final double diameter;
  final BrushShape shape;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    final double clampedDiameter = diameter.isFinite && diameter > 0
        ? diameter
        : 1.0;
    final double radius = clampedDiameter / 2;
    final double outerRadius = radius + 1;
    final double side = (outerRadius * 2 + 2).ceilToDouble();

    return Positioned(
      left: position.dx - side / 2,
      top: position.dy - side / 2,
      child: IgnorePointer(
        ignoring: true,
        child: SizedBox(
          width: side,
          height: side,
          child: CustomPaint(
            painter: _PenCursorPainter(
              radius: radius,
              shape: shape,
              rotation: rotation,
            ),
            isComplex: false,
            willChange: false,
          ),
        ),
      ),
    );
  }
}

class CustomBrushCursorOverlay extends StatefulWidget {
  const CustomBrushCursorOverlay({
    super.key,
    required this.position,
    required this.diameter,
    required this.raster,
    this.rotation = 0.0,
  });

  final Offset position;
  final double diameter;
  final BrushShapeRaster raster;
  final double rotation;

  @override
  State<CustomBrushCursorOverlay> createState() =>
      _CustomBrushCursorOverlayState();
}

class _CustomBrushCursorOverlayState extends State<CustomBrushCursorOverlay> {
  ui.Image? _image;
  int _signature = 0;
  int _renderToken = 0;

  @override
  void initState() {
    super.initState();
    _ensureImage();
  }

  @override
  void didUpdateWidget(covariant CustomBrushCursorOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.raster.id != widget.raster.id ||
        oldWidget.raster.width != widget.raster.width ||
        oldWidget.raster.height != widget.raster.height) {
      _ensureImage();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  void _ensureImage() {
    final BrushShapeRaster raster = widget.raster;
    final int nextSignature = Object.hash(
      raster.id,
      raster.width,
      raster.height,
      raster.alpha.length,
    );
    if (nextSignature == _signature) {
      return;
    }
    _signature = nextSignature;
    final int token = ++_renderToken;
    _image?.dispose();
    _image = null;
    _buildRasterImage(raster).then((ui.Image? image) {
      if (!mounted || token != _renderToken) {
        image?.dispose();
        return;
      }
      if (image == null) {
        return;
      }
      setState(() {
        _image?.dispose();
        _image = image;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final double clampedDiameter = widget.diameter.isFinite &&
            widget.diameter > 0
        ? widget.diameter
        : 1.0;
    final double radius = clampedDiameter / 2;
    final double outerRadius = radius + 1;
    final double side = (outerRadius * 2 + 2).ceilToDouble();

    return Positioned(
      left: widget.position.dx - side / 2,
      top: widget.position.dy - side / 2,
      child: IgnorePointer(
        ignoring: true,
        child: SizedBox(
          width: side,
          height: side,
          child: CustomPaint(
            painter: _CustomBrushCursorPainter(
              radius: radius,
              rotation: widget.rotation,
              image: _image,
            ),
            isComplex: false,
            willChange: false,
          ),
        ),
      ),
    );
  }
}

class _PenCursorPainter extends CustomPainter {
  const _PenCursorPainter({
    required this.radius,
    required this.shape,
    required this.rotation,
  });

  final double radius;
  final BrushShape shape;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);

    final Paint whiteStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = false;

    final Paint blackStroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = false;

    final double outerRadius = radius + 1;
    final double innerRadius = math.max(radius - 1, 0);

    final bool rotateShape = rotation != 0.0 && shape != BrushShape.circle;
    if (rotateShape) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);
      canvas.translate(-center.dx, -center.dy);
    }

    if (outerRadius > 0) {
      final Path outline = BrushShapeGeometry.pathFor(
        shape,
        center,
        outerRadius,
      );
      canvas.drawPath(outline, whiteStroke);
    }
    if (radius > 0) {
      final Path outline = BrushShapeGeometry.pathFor(shape, center, radius);
      canvas.drawPath(outline, blackStroke);
    }
    if (innerRadius > 0) {
      final Path outline = BrushShapeGeometry.pathFor(
        shape,
        center,
        innerRadius,
      );
      canvas.drawPath(outline, whiteStroke);
    } else {
      final Paint centerDot = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
        ..isAntiAlias = false;
      canvas.drawRect(
        Rect.fromCenter(center: center, width: 1, height: 1),
        centerDot,
      );
    }

    if (rotateShape) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PenCursorPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.shape != shape ||
      oldDelegate.rotation != rotation;
}

class _CustomBrushCursorPainter extends CustomPainter {
  const _CustomBrushCursorPainter({
    required this.radius,
    required this.rotation,
    required this.image,
  });

  final double radius;
  final double rotation;
  final ui.Image? image;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double outerRadius = radius + 1;
    final double innerRadius = math.max(radius - 1, 0);

    if (image == null) {
      final Paint whiteStroke = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..isAntiAlias = false;
      final Paint blackStroke = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..isAntiAlias = false;
      if (outerRadius > 0) {
        final Path outline = BrushShapeGeometry.pathFor(
          BrushShape.circle,
          center,
          outerRadius,
        );
        canvas.drawPath(outline, whiteStroke);
      }
      if (radius > 0) {
        final Path outline =
            BrushShapeGeometry.pathFor(BrushShape.circle, center, radius);
        canvas.drawPath(outline, blackStroke);
      }
      if (innerRadius > 0) {
        final Path outline = BrushShapeGeometry.pathFor(
          BrushShape.circle,
          center,
          innerRadius,
        );
        canvas.drawPath(outline, whiteStroke);
      }
      return;
    }

    if (rotation != 0.0) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);
      canvas.translate(-center.dx, -center.dy);
    }

    _drawMaskedImage(canvas, center, outerRadius, Colors.white);
    _drawMaskedImage(canvas, center, radius, Colors.black);
    if (innerRadius > 0) {
      _drawMaskedImage(canvas, center, innerRadius, Colors.white);
    } else {
      final Paint centerDot = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
        ..isAntiAlias = false;
      canvas.drawRect(
        Rect.fromCenter(center: center, width: 1, height: 1),
        centerDot,
      );
    }

    if (rotation != 0.0) {
      canvas.restore();
    }
  }

  void _drawMaskedImage(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    if (radius <= 0 || image == null) {
      return;
    }
    final double size = radius * 2;
    final Rect dst = Rect.fromCenter(center: center, width: size, height: size);
    final Rect src = Rect.fromLTWH(
      0,
      0,
      image!.width.toDouble(),
      image!.height.toDouble(),
    );
    final Paint paint = Paint()
      ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn)
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    canvas.drawImageRect(image!, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant _CustomBrushCursorPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.rotation != rotation ||
      oldDelegate.image != image;
}

Future<ui.Image?> _buildRasterImage(BrushShapeRaster raster) async {
  final int width = raster.width;
  final int height = raster.height;
  if (width <= 0 || height <= 0) {
    return null;
  }
  final int count = width * height;
  if (raster.alpha.length != count) {
    return null;
  }
  final Uint8List rgba = Uint8List(count * 4);
  int out = 0;
  for (int i = 0; i < count; i++) {
    final int alpha = raster.alpha[i];
    rgba[out++] = 255;
    rgba[out++] = 255;
    rgba[out++] = 255;
    rgba[out++] = alpha;
  }
  final Completer<ui.Image> completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

class _OutlinedToolCursorIcon extends StatelessWidget {
  const _OutlinedToolCursorIcon({
    required this.icon,
    this.size = ToolCursorStyles._defaultIconSize,
    this.mirrorHorizontally = false,
  });

  final IconData icon;
  final double size;
  final bool mirrorHorizontally;

  @override
  Widget build(BuildContext context) {
    return ToolCursorStyles.buildOutlinedIcon(
      icon: icon,
      size: size,
      mirrorHorizontally: mirrorHorizontally,
    );
  }
}

class ToolCursorCrosshair extends StatelessWidget {
  const ToolCursorCrosshair({super.key});

  static const double size = ToolCursorStyles.crosshairSize;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ToolCursorCrosshairPainter()),
    );
  }
}

class _ToolCursorCrosshairPainter extends CustomPainter {
  const _ToolCursorCrosshairPainter();

  static const double _outlineWidth = 2.0;
  static const double _innerWidth = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double arm = size.width / 2;

    void drawCross(Paint paint) {
      canvas.drawLine(
        Offset(center.dx, center.dy - arm),
        Offset(center.dx, center.dy + arm),
        paint,
      );
      canvas.drawLine(
        Offset(center.dx - arm, center.dy),
        Offset(center.dx + arm, center.dy),
        paint,
      );
    }

    final Paint outline = Paint()
      ..color = Colors.white
      ..strokeWidth = _outlineWidth
      ..strokeCap = StrokeCap.square;
    final Paint inner = Paint()
      ..color = Colors.black
      ..strokeWidth = _innerWidth
      ..strokeCap = StrokeCap.square;

    drawCross(outline);
    drawCross(inner);
  }

  @override
  bool shouldRepaint(covariant _ToolCursorCrosshairPainter oldDelegate) =>
      false;
}
