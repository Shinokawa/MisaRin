part of 'painting_board.dart';

const double _kLayerTransformPanelWidth = 280;
const double _kLayerTransformPanelMinHeight = 108;
const double _kLayerTransformHandleVisualSize = 12;
const double _kLayerTransformHandleHitSize = 24;
const double _kLayerTransformRotationHandleDistance = 36;
const double _kLayerTransformRotationHandleRadius = 6;
const double _kLayerTransformMinScale = 0.02;
const double _kLayerTransformMaxScale = 64;
const Color _kLayerTransformOverlayColor = Color(0xFF2B2B2B);
const Color _kLayerTransformOverlayHighlightColor = Color(0xFF4B4B4B);

enum _LayerTransformHandle {
  translate,
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
  rotation,
}

class _LayerTransformStateModel {
  _LayerTransformStateModel({
    required Rect bounds,
    required Offset imageOrigin,
    ui.Image? image,
    Size? fullImageSizeOverride,
  }) : image = image,
       bounds = bounds,
       imageOrigin = imageOrigin,
       fullImageSize = fullImageSizeOverride ??
           (image != null
               ? Size(
                   image.width.toDouble().clamp(1.0, double.infinity),
                   image.height.toDouble().clamp(1.0, double.infinity),
                 )
               : Size(
                   bounds.width.clamp(1.0, double.infinity),
                   bounds.height.clamp(1.0, double.infinity),
                 )),
       imageSize = Size(
         bounds.width.clamp(1.0, double.infinity),
         bounds.height.clamp(1.0, double.infinity),
       ),
       baseTranslation = bounds.topLeft,
       translation = bounds.topLeft,
       rotation = 0.0,
       scaleX = 1.0,
       scaleY = 1.0,
       pivotLocal = Offset(bounds.width / 2, bounds.height / 2) {
    clipOffset = _computeClipOffset(
      bounds,
      imageOrigin,
      fullImageSize.width,
      fullImageSize.height,
    );
  }

  final ui.Image? image;
  final Rect bounds;
  final Offset imageOrigin;
  final Size fullImageSize;
  final Size imageSize;
  late final Offset clipOffset;
  final Offset baseTranslation;
  Offset translation;
  double rotation;
  double scaleX;
  double scaleY;
  final Offset pivotLocal;

  static Offset _computeClipOffset(
    Rect bounds,
    Offset origin,
    double imageWidth,
    double imageHeight,
  ) {
    final double maxX = math.max(0.0, imageWidth - bounds.width);
    final double maxY = math.max(0.0, imageHeight - bounds.height);
    final double dx = (bounds.left - origin.dx).clamp(0.0, maxX);
    final double dy = (bounds.top - origin.dy).clamp(0.0, maxY);
    return Offset(dx, dy);
  }

  Matrix4 get matrix {
    final Matrix4 result = Matrix4.identity();
    result.translate(translation.dx, translation.dy);
    result.translate(pivotLocal.dx, pivotLocal.dy);
    result.rotateZ(rotation);
    result.scale(scaleX, scaleY);
    result.translate(-pivotLocal.dx, -pivotLocal.dy);
    return result;
  }

  Matrix4? get inverseMatrix => Matrix4.tryInvert(matrix);

  List<Offset> get corners {
    final Matrix4 m = matrix;
    return <Offset>[
      MatrixUtils.transformPoint(m, Offset.zero),
      MatrixUtils.transformPoint(m, Offset(imageSize.width, 0)),
      MatrixUtils.transformPoint(m, Offset(imageSize.width, imageSize.height)),
      MatrixUtils.transformPoint(m, Offset(0, imageSize.height)),
    ];
  }

  Offset transformPoint(Offset localPoint) =>
      MatrixUtils.transformPoint(matrix, localPoint);

  Offset toLocal(Offset globalPoint) {
    final Matrix4? inverse = inverseMatrix;
    if (inverse == null) {
      return globalPoint;
    }
    return MatrixUtils.transformPoint(inverse, globalPoint);
  }

  Rect get boundingBox {
    final List<Offset> points = corners;
    double minX = points.first.dx;
    double maxX = minX;
    double minY = points.first.dy;
    double maxY = minY;
    for (final Offset point in points.skip(1)) {
      if (point.dx < minX) {
        minX = point.dx;
      }
      if (point.dx > maxX) {
        maxX = point.dx;
      }
      if (point.dy < minY) {
        minY = point.dy;
      }
      if (point.dy > maxY) {
        maxY = point.dy;
      }
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Offset localHandlePosition(_LayerTransformHandle handle) {
    switch (handle) {
      case _LayerTransformHandle.topLeft:
        return Offset.zero;
      case _LayerTransformHandle.top:
        return Offset(imageSize.width / 2, 0);
      case _LayerTransformHandle.topRight:
        return Offset(imageSize.width, 0);
      case _LayerTransformHandle.right:
        return Offset(imageSize.width, imageSize.height / 2);
      case _LayerTransformHandle.bottomRight:
        return Offset(imageSize.width, imageSize.height);
      case _LayerTransformHandle.bottom:
        return Offset(imageSize.width / 2, imageSize.height);
      case _LayerTransformHandle.bottomLeft:
        return Offset(0, imageSize.height);
      case _LayerTransformHandle.left:
        return Offset(0, imageSize.height / 2);
      case _LayerTransformHandle.translate:
      case _LayerTransformHandle.rotation:
        return pivotLocal;
    }
  }

  Offset handlePosition(_LayerTransformHandle handle) {
    switch (handle) {
      case _LayerTransformHandle.rotation:
        final Offset topLeft = transformPoint(Offset.zero);
        final Offset topRight = transformPoint(Offset(imageSize.width, 0));
        final Offset topCenter = transformPoint(Offset(imageSize.width / 2, 0));
        final Offset edge = topRight - topLeft;
        Offset normal = Offset(edge.dy, -edge.dx);
        final double length = normal.distance;
        if (length > 0.0001) {
          normal = normal / length;
        } else {
          normal = const Offset(0, -1);
        }
        return topCenter + normal * _kLayerTransformRotationHandleDistance;
      case _LayerTransformHandle.translate:
        return translation + pivotLocal;
      default:
        return transformPoint(localHandlePosition(handle));
    }
  }

  void reset() {
    translation = baseTranslation;
    rotation = 0.0;
    scaleX = 1.0;
    scaleY = 1.0;
  }
}

class _LayerTransformRenderResult {
  const _LayerTransformRenderResult({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.rgba,
  });

  final int left;
  final int top;
  final int width;
  final int height;
  final Uint8List rgba;
}

class _LayerTransformOverlayPainter extends CustomPainter {
  _LayerTransformOverlayPainter({
    required this.state,
    required this.boardScale,
    required this.lineColor,
    required this.highlightColor,
    required this.revision,
    this.activeHandle,
    this.hoverHandle,
  });

  final _LayerTransformStateModel state;
  final double boardScale;
  final Color lineColor;
  final Color highlightColor;
  final int revision;
  final _LayerTransformHandle? activeHandle;
  final _LayerTransformHandle? hoverHandle;

  @override
  void paint(Canvas canvas, Size size) {
    final List<Offset> points = state.corners;
    if (points.length != 4) {
      return;
    }
    final Paint outlinePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / boardScale
      ..isAntiAlias = true;
    final Path path = Path()..addPolygon(points, true);
    canvas.drawPath(path, outlinePaint);

    final double handleSize = (_kLayerTransformHandleVisualSize / boardScale)
        .clamp(6.0, 24.0);
    final Paint handlePaint = Paint()..isAntiAlias = true;
    for (final _LayerTransformHandle handle in _LayerTransformHandle.values) {
      if (handle == _LayerTransformHandle.translate ||
          handle == _LayerTransformHandle.rotation) {
        continue;
      }
      final Offset position = state.handlePosition(handle);
      final bool isActive = handle == activeHandle;
      final bool isHover = handle == hoverHandle;
      handlePaint.color = isActive || isHover ? highlightColor : lineColor;
      final Rect rect = Rect.fromCenter(
        center: position,
        width: handleSize,
        height: handleSize,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(handleSize / 4)),
        handlePaint,
      );
    }

    // Rotation handle
    final Offset rotateHandle = state.handlePosition(
      _LayerTransformHandle.rotation,
    );
    final Offset topCenter = state.handlePosition(_LayerTransformHandle.top);
    final Paint rotationPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / boardScale
      ..isAntiAlias = true;
    canvas.drawLine(topCenter, rotateHandle, rotationPaint);
    final Paint rotationFill = Paint()
      ..color =
          (activeHandle == _LayerTransformHandle.rotation ||
              hoverHandle == _LayerTransformHandle.rotation)
          ? highlightColor
          : lineColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(
      rotateHandle,
      (_kLayerTransformRotationHandleRadius / boardScale).clamp(3.0, 18.0),
      rotationFill,
    );
  }

  @override
  bool shouldRepaint(covariant _LayerTransformOverlayPainter oldDelegate) {
    return oldDelegate.revision != revision ||
        oldDelegate.boardScale != boardScale ||
        oldDelegate.activeHandle != activeHandle ||
        oldDelegate.hoverHandle != hoverHandle ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.highlightColor != highlightColor;
  }
}
