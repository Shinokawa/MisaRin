part of 'painting_board.dart';

Path? _selectionPathFromMask(Uint8List mask, int width) {
  if (mask.isEmpty) {
    return null;
  }
  final int height = mask.length ~/ width;
  final Map<int, Set<int>> adjacency = <int, Set<int>>{};
  final Set<int> edges = <int>{};
  bool hasCoverage = false;

  void addEdge(int startX, int startY, int direction) {
    final int vertex = _encodeVertex(startX, startY);
    final Set<int> directions = adjacency.putIfAbsent(vertex, () => <int>{});
    if (directions.add(direction)) {
      edges.add(_encodeEdge(vertex, direction));
    }
  }

  for (int y = 0; y < height; y++) {
    final int rowOffset = y * width;
    for (int x = 0; x < width; x++) {
      final int index = rowOffset + x;
      if (mask[index] == 0) {
        continue;
      }
      hasCoverage = true;
      if (y == 0 || mask[index - width] == 0) {
        addEdge(x, y, 0); // top edge, moving right
      }
      if (x == width - 1 || mask[index + 1] == 0) {
        addEdge(x + 1, y, 1); // right edge, moving down
      }
      if (y == height - 1 || mask[index + width] == 0) {
        addEdge(x + 1, y + 1, 2); // bottom edge, moving left
      }
      if (x == 0 || mask[index - 1] == 0) {
        addEdge(x, y + 1, 3); // left edge, moving up
      }
    }
  }

  if (!hasCoverage || edges.isEmpty) {
    return null;
  }

  final Path path = Path()..fillType = PathFillType.evenOdd;
  bool aborted = false;

  void consumeEdge(int encodedEdge) {
    if (!edges.remove(encodedEdge)) {
      return;
    }
    final int vertex = _edgeVertex(encodedEdge);
    final int direction = _edgeDirection(encodedEdge);
    final Set<int>? options = adjacency[vertex];
    if (options == null) {
      return;
    }
    options.remove(direction);
    if (options.isEmpty) {
      adjacency.remove(vertex);
    }
  }

  while (edges.isNotEmpty) {
    final int startEdge = edges.first;
    final int startVertex = _edgeVertex(startEdge);
    int currentDirection = _edgeDirection(startEdge);
    consumeEdge(startEdge);

    path.moveTo(
      _vertexX(startVertex).toDouble(),
      _vertexY(startVertex).toDouble(),
    );

    int currentVertex = startVertex;
    int nextX = _vertexX(currentVertex) + _directionDx[currentDirection];
    int nextY = _vertexY(currentVertex) + _directionDy[currentDirection];
    path.lineTo(nextX.toDouble(), nextY.toDouble());
    currentVertex = _encodeVertex(nextX, nextY);

    while (currentVertex != startVertex) {
      final int? nextDirection = _selectNextDirection(
        currentVertex,
        currentDirection,
        adjacency,
      );
      if (nextDirection == null) {
        aborted = true;
        break;
      }
      currentDirection = nextDirection;
      final int encodedEdge = _encodeEdge(currentVertex, currentDirection);
      consumeEdge(encodedEdge);
      nextX = _vertexX(currentVertex) + _directionDx[currentDirection];
      nextY = _vertexY(currentVertex) + _directionDy[currentDirection];
      path.lineTo(nextX.toDouble(), nextY.toDouble());
      currentVertex = _encodeVertex(nextX, nextY);
    }
    if (aborted) {
      break;
    }
    path.close();
  }

  if (aborted) {
    return _pathFromMaskFallback(mask, width);
  }

  return path;
}

const List<int> _directionDx = <int>[1, 0, -1, 0];
const List<int> _directionDy = <int>[0, 1, 0, -1];

int _encodeVertex(int x, int y) => (y << 32) | (x & 0xFFFFFFFF);

int _vertexX(int key) => key & 0xFFFFFFFF;

int _vertexY(int key) => key >> 32;

int _encodeEdge(int vertex, int direction) => (vertex << 2) | direction;

int _edgeVertex(int edge) => edge >> 2;

int _edgeDirection(int edge) => edge & 0x3;

int? _selectNextDirection(
  int vertex,
  int previousDirection,
  Map<int, Set<int>> adjacency,
) {
  final Set<int>? options = adjacency[vertex];
  if (options == null || options.isEmpty) {
    return null;
  }
  for (final int offset in const <int>[1, 0, 3, 2]) {
    final int candidate = (previousDirection + offset) & 0x3;
    if (options.contains(candidate)) {
      return candidate;
    }
  }
  return null;
}

Path? _pathFromMaskFallback(Uint8List mask, int width) {
  if (mask.isEmpty) {
    return null;
  }
  final int height = mask.length ~/ width;
  Path? result;
  for (int y = 0; y < height; y++) {
    final int rowOffset = y * width;
    int x = 0;
    while (x < width) {
      if (mask[rowOffset + x] == 0) {
        x += 1;
        continue;
      }
      final int start = x;
      while (x < width && mask[rowOffset + x] != 0) {
        x += 1;
      }
      final Rect rect = Rect.fromLTWH(
        start.toDouble(),
        y.toDouble(),
        (x - start).toDouble(),
        1,
      );
      final Path segment = Path()..addRect(rect);
      result = result == null
          ? segment
          : Path.combine(ui.PathOperation.union, result!, segment);
    }
  }
  return result;
}

class _SelectionOverlayPainter extends CustomPainter {
  const _SelectionOverlayPainter({
    this.selectionPath,
    this.selectionPreviewPath,
    this.magicPreviewPath,
    required this.dashPhase,
    required this.viewportScale,
    this.showPreviewStroke = true,
    this.fillSelectionPath = false,
  });

  final Path? selectionPath;
  final Path? selectionPreviewPath;
  final Path? magicPreviewPath;
  final double dashPhase;
  final double viewportScale;
  final bool showPreviewStroke;
  final bool fillSelectionPath;

  static final Paint _selectionFillPaint = Paint()
    ..color = _kSelectionFillColor
    ..style = PaintingStyle.fill;
  static final Paint _previewFillPaint = Paint()
    ..color = _kSelectionPreviewFillColor
    ..style = PaintingStyle.fill;
  static final _MarchingAntsStroke _selectionStroke = _MarchingAntsStroke(
    dashLength: _kSelectionDashLength,
    dashGap: _kSelectionDashGap,
    strokeWidth: 1.0,
    lightColor: const Color(0xE6FFFFFF),
    darkColor: const Color(0xFF2B2B2B),
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (fillSelectionPath && selectionPath != null) {
      canvas.drawPath(selectionPath!, _selectionFillPaint);
    }
    if (magicPreviewPath != null) {
      canvas.drawPath(magicPreviewPath!, _previewFillPaint);
      _selectionStroke.paint(
        canvas,
        magicPreviewPath!,
        dashPhase,
        viewportScale: viewportScale,
      );
    }
    if (selectionPreviewPath != null) {
      canvas.drawPath(selectionPreviewPath!, _previewFillPaint);
      if (showPreviewStroke) {
        _selectionStroke.paint(
          canvas,
          selectionPreviewPath!,
          dashPhase,
          viewportScale: viewportScale,
        );
      }
    }
    if (selectionPath != null) {
      _selectionStroke.paint(
        canvas,
        selectionPath!,
        dashPhase,
        viewportScale: viewportScale,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionOverlayPainter oldDelegate) {
    return oldDelegate.selectionPath != selectionPath ||
        oldDelegate.selectionPreviewPath != selectionPreviewPath ||
        oldDelegate.magicPreviewPath != magicPreviewPath ||
        oldDelegate.dashPhase != dashPhase ||
        oldDelegate.viewportScale != viewportScale ||
        oldDelegate.showPreviewStroke != showPreviewStroke ||
        oldDelegate.fillSelectionPath != fillSelectionPath;
  }
}

