part of 'painting_board.dart';

const Color _kVectorEraserPreviewColor = _kSelectionPreviewFillColor;

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class SelectToolIntent extends Intent {
  const SelectToolIntent(this.tool);

  final CanvasTool tool;
}

class ExitBoardIntent extends Intent {
  const ExitBoardIntent();
}

class DeselectIntent extends Intent {
  const DeselectIntent();
}

class ResizeImageIntent extends Intent {
  const ResizeImageIntent();
}

class ResizeCanvasIntent extends Intent {
  const ResizeCanvasIntent();
}

class AdjustHueSaturationIntent extends Intent {
  const AdjustHueSaturationIntent();
}

class AdjustBrightnessContrastIntent extends Intent {
  const AdjustBrightnessContrastIntent();
}

class AdjustGaussianBlurIntent extends Intent {
  const AdjustGaussianBlurIntent();
}

class NarrowLinesIntent extends Intent {
  const NarrowLinesIntent();
}

class ExpandFillIntent extends Intent {
  const ExpandFillIntent();
}

class RemoveColorLeakIntent extends Intent {
  const RemoveColorLeakIntent();
}

class ShowLayerAntialiasIntent extends Intent {
  const ShowLayerAntialiasIntent();
}

class LayerFreeTransformIntent extends Intent {
  const LayerFreeTransformIntent();
}

class CutIntent extends Intent {
  const CutIntent();
}

class CopyIntent extends Intent {
  const CopyIntent();
}

class PasteIntent extends Intent {
  const PasteIntent();
}

class ImportReferenceImageIntent extends Intent {
  const ImportReferenceImageIntent();
}

class ToggleViewBlackWhiteIntent extends Intent {
  const ToggleViewBlackWhiteIntent();
}

class TogglePixelGridIntent extends Intent {
  const TogglePixelGridIntent();
}

class ToggleViewMirrorIntent extends Intent {
  const ToggleViewMirrorIntent();
}

class _CheckboardBackground extends StatelessWidget {
  const _CheckboardBackground({
    this.cellSize = 16.0,
    this.lightColor = const Color(0xFFF9F9F9),
    this.darkColor = const ui.Color.fromARGB(255, 211, 211, 211),
  });

  final double cellSize;
  final Color lightColor;
  final Color darkColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CheckboardPainter(
        cellSize: cellSize,
        lightColor: lightColor,
        darkColor: darkColor,
      ),
    );
  }
}

class _CheckboardPainter extends CustomPainter {
  const _CheckboardPainter({
    required this.cellSize,
    required this.lightColor,
    required this.darkColor,
  });

  final double cellSize;
  final Color lightColor;
  final Color darkColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint lightPaint = Paint()
      ..color = lightColor
      ..isAntiAlias = false;
    final Paint darkPaint = Paint()
      ..color = darkColor
      ..isAntiAlias = false;
    double step = cellSize <= 0 ? 12.0 : cellSize;
    if (size.width > 0 && size.height > 0) {
      final double minSide = math.min(size.width, size.height);
      if (minSide > 0 && step >= minSide) {
        step = math.max(1.0, minSide / 2.0);
      }
    }
    final int horizontalCount = (size.width / step).ceil();
    final int verticalCount = (size.height / step).ceil();

    for (int y = 0; y < verticalCount; y++) {
      final bool oddRow = y.isOdd;
      for (int x = 0; x < horizontalCount; x++) {
        final bool useDark = oddRow ? x.isEven : x.isOdd;
        final Rect rect = Rect.fromLTWH(x * step, y * step, step, step);
        canvas.drawRect(rect, useDark ? darkPaint : lightPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckboardPainter oldDelegate) {
    return oldDelegate.cellSize != cellSize ||
        oldDelegate.lightColor != lightColor ||
        oldDelegate.darkColor != darkColor;
  }
}

// 网格线力求保持恒定屏幕像素宽度，同时根据缩放自动调节网格步长。
const double _kPixelGridScreenStrokeWidth = 1.0;
const double _kPixelGridTargetScreenSpacing = 24.0;
const int _kPixelGridMaxStep = 256;

int _resolvePixelGridStep(double scale) {
  if (scale <= 0.0 || scale.isNaN) {
    return 1;
  }
  final double desiredCanvasSpacing = _kPixelGridTargetScreenSpacing / scale;
  if (desiredCanvasSpacing <= 1.0) {
    return 1;
  }
  final double log2 = math.log(desiredCanvasSpacing) / math.ln2;
  final int powerOfTwo = math.pow(2, log2.floor()).toInt();
  return powerOfTwo.clamp(1, _kPixelGridMaxStep);
}

class _PixelGridPainter extends CustomPainter {
  const _PixelGridPainter({
    required this.pixelWidth,
    required this.pixelHeight,
    required this.color,
    required this.scale,
  });

  final int pixelWidth;
  final int pixelHeight;
  final Color color;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    if (pixelWidth <= 1 && pixelHeight <= 1) {
      return;
    }
    final double resolvedScale = scale.abs() < 0.0001 ? 1.0 : scale.abs();
    final int step = _resolvePixelGridStep(resolvedScale);
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kPixelGridScreenStrokeWidth / resolvedScale
      ..isAntiAlias = false;
    final double maxX = size.width;
    final double maxY = size.height;
    if (pixelWidth > 1) {
      for (int x = step; x < pixelWidth; x += step) {
        final double dx = x.toDouble();
        canvas.drawLine(Offset(dx, 0), Offset(dx, maxY), paint);
      }
    }
    if (pixelHeight > 1) {
      for (int y = step; y < pixelHeight; y += step) {
        final double dy = y.toDouble();
        canvas.drawLine(Offset(0, dy), Offset(maxX, dy), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PixelGridPainter oldDelegate) {
    return oldDelegate.pixelWidth != pixelWidth ||
        oldDelegate.pixelHeight != pixelHeight ||
        oldDelegate.color != color ||
        oldDelegate.scale != scale;
  }
}

class _PreviewPathPainter extends CustomPainter {
  const _PreviewPathPainter({
    required this.path,
    required this.color,
    required this.strokeWidth,
    this.fill = false,
  });

  final Path path;
  final Color color;
  final double strokeWidth;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (fill) {
      final Paint fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);
    }
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth.clamp(kPenStrokeMin, kPenStrokeMax)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PreviewPathPainter oldDelegate) {
    return oldDelegate.path != path ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.fill != fill;
  }
}

class _ShapeFillOverlayPainter extends CustomPainter {
  const _ShapeFillOverlayPainter({required this.path, required this.color});

  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(_ShapeFillOverlayPainter oldDelegate) {
    return oldDelegate.path != path || oldDelegate.color != color;
  }
}

class _ActiveStrokeOverlayPainter extends CustomPainter {
  const _ActiveStrokeOverlayPainter({
    required this.points,
    required this.radii,
    required this.color,
    this.shape = BrushShape.circle,
    required this.randomRotationEnabled,
    required this.rotationSeed,
    required this.committingStrokes,
    this.antialiasLevel = 1,
    this.hollowStrokeEnabled = false,
    this.hollowStrokeRatio = 0.0,
    required this.activeStrokeIsEraser,
    this.eraserPreviewColor = _kVectorEraserPreviewColor,
  });

  final List<Offset> points;
  final List<double> radii;
  final Color color;
  final BrushShape shape;
  final bool randomRotationEnabled;
  final int rotationSeed;
  final List<PaintingDrawCommand> committingStrokes;
  final int antialiasLevel;
  final bool hollowStrokeEnabled;
  final double hollowStrokeRatio;
  final bool activeStrokeIsEraser;
  final Color eraserPreviewColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw committing strokes (fading out/waiting for raster) first
    for (final PaintingDrawCommand command in committingStrokes) {
      if (command.points == null || command.radii == null) continue;
      final Color commandColor = command.erase
          ? eraserPreviewColor
          : Color(command.color);
      final bool commandHollow = (command.hollow ?? false) && !command.erase;
      VectorStrokePainter.paint(
        canvas: canvas,
        points: command.points!,
        radii: command.radii!,
        color: commandColor,
        shape: BrushShape.values[command.shapeIndex ?? 0],
        antialiasLevel: command.antialiasLevel,
        hollow: commandHollow,
        hollowRatio: command.hollowRatio ?? 0.0,
        randomRotation: command.randomRotation ?? false,
        rotationSeed: command.rotationSeed ?? 0,
      );
    }

    // Draw active stroke on top
    if (points.isNotEmpty) {
      final Color activeColor = activeStrokeIsEraser
          ? eraserPreviewColor
          : color;
      final bool activeHollow = hollowStrokeEnabled && !activeStrokeIsEraser;
      VectorStrokePainter.paint(
        canvas: canvas,
        points: points,
        radii: radii,
        color: activeColor,
        shape: shape,
        antialiasLevel: antialiasLevel,
        hollow: activeHollow,
        hollowRatio: hollowStrokeRatio,
        randomRotation: randomRotationEnabled,
        rotationSeed: rotationSeed,
      );
    }
  }

  @override
  bool shouldRepaint(_ActiveStrokeOverlayPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.radii != radii ||
        oldDelegate.color != color ||
        oldDelegate.shape != shape ||
        oldDelegate.randomRotationEnabled != randomRotationEnabled ||
        oldDelegate.rotationSeed != rotationSeed ||
        oldDelegate.committingStrokes != committingStrokes ||
        oldDelegate.antialiasLevel != antialiasLevel ||
        oldDelegate.hollowStrokeEnabled != hollowStrokeEnabled ||
        oldDelegate.hollowStrokeRatio != hollowStrokeRatio ||
        oldDelegate.activeStrokeIsEraser != activeStrokeIsEraser ||
        oldDelegate.eraserPreviewColor != eraserPreviewColor;
  }
}

class _StreamlinePostStroke {
  const _StreamlinePostStroke({
    required this.fromPoints,
    required this.fromRadii,
    required this.toPoints,
    required this.toRadii,
    required this.color,
    required this.shape,
    required this.erase,
    required this.antialiasLevel,
    required this.hollowStrokeEnabled,
    required this.hollowStrokeRatio,
    required this.eraseOccludedParts,
    required this.randomRotationEnabled,
    required this.rotationSeed,
  });

  final List<Offset> fromPoints;
  final List<double> fromRadii;
  final List<Offset> toPoints;
  final List<double> toRadii;
  final Color color;
  final BrushShape shape;
  final bool erase;
  final int antialiasLevel;
  final bool hollowStrokeEnabled;
  final double hollowStrokeRatio;
  final bool eraseOccludedParts;
  final bool randomRotationEnabled;
  final int rotationSeed;
}

class _StreamlinePostStrokeOverlayPainter extends CustomPainter {
  _StreamlinePostStrokeOverlayPainter({
    required this.stroke,
    required this.progress,
    this.curve = Curves.easeOutBack,
    this.eraserPreviewColor = _kVectorEraserPreviewColor,
  }) : super(repaint: progress);

  final _StreamlinePostStroke stroke;
  final AnimationController progress;
  final Curve curve;
  final Color eraserPreviewColor;

  @override
  void paint(Canvas canvas, Size size) {
    final List<Offset> from = stroke.fromPoints;
    final List<Offset> to = stroke.toPoints;
    if (from.isEmpty || to.isEmpty) {
      return;
    }

    final int count = math.min(from.length, to.length);
    if (count == 0) {
      return;
    }

    final double t = curve.transform(progress.value);
    final List<Offset> points = List<Offset>.filled(
      count,
      Offset.zero,
      growable: false,
    );
    for (int i = 0; i < count; i++) {
      final Offset p0 = from[i];
      final Offset p1 = to[i];
      points[i] = p0 + (p1 - p0) * t;
    }

    double radiusAt(List<double> radii, int index) {
      if (radii.isEmpty) {
        return 1.0;
      }
      if (index < 0) {
        return radii.first;
      }
      if (index >= radii.length) {
        return radii.last;
      }
      final double value = radii[index];
      if (value.isFinite && value >= 0) {
        return value;
      }
      return radii.last >= 0 ? radii.last : 1.0;
    }

    final List<double> radii = List<double>.filled(count, 1.0, growable: false);
    for (int i = 0; i < count; i++) {
      final double r0 = radiusAt(stroke.fromRadii, i);
      final double r1 = radiusAt(stroke.toRadii, i);
      radii[i] = (ui.lerpDouble(r0, r1, t) ?? r1).clamp(0.0, double.infinity);
    }

    final Color color = stroke.erase ? eraserPreviewColor : stroke.color;
    final bool hollow = stroke.hollowStrokeEnabled && !stroke.erase;
    VectorStrokePainter.paint(
      canvas: canvas,
      points: points,
      radii: radii,
      color: color,
      shape: stroke.shape,
      antialiasLevel: stroke.antialiasLevel,
      hollow: hollow,
      hollowRatio: stroke.hollowStrokeRatio,
      randomRotation: stroke.randomRotationEnabled,
      rotationSeed: stroke.rotationSeed,
    );
  }

  @override
  bool shouldRepaint(_StreamlinePostStrokeOverlayPainter oldDelegate) {
    return oldDelegate.stroke != stroke ||
        oldDelegate.progress != progress ||
        oldDelegate.curve != curve ||
        oldDelegate.eraserPreviewColor != eraserPreviewColor;
  }
}

class _BucketOptionTile extends StatelessWidget {
  const _BucketOptionTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: theme.typography.bodyStrong,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(width: 8),
        ToggleSwitch(checked: value, onChanged: onChanged),
      ],
    );
  }
}
