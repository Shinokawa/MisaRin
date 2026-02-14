class RustCpuTransformFfi {
  RustCpuTransformFfi._();

  static final RustCpuTransformFfi instance = RustCpuTransformFfi._();

  bool get isSupported => false;

  bool translateLayer({
    required int canvasPtr,
    required int canvasLen,
    required int canvasWidth,
    required int canvasHeight,
    required int snapshotPtr,
    required int snapshotLen,
    required int snapshotWidth,
    required int snapshotHeight,
    required int originX,
    required int originY,
    required int dx,
    required int dy,
    int overflowXPtr = 0,
    int overflowYPtr = 0,
    int overflowColorPtr = 0,
    int overflowCapacity = 0,
    int overflowCountPtr = 0,
  }) {
    return false;
  }

  bool buildOverflowSnapshot({
    required int canvasPtr,
    required int canvasLen,
    required int canvasWidth,
    required int canvasHeight,
    required int snapshotPtr,
    required int snapshotLen,
    required int snapshotWidth,
    required int snapshotHeight,
    required int originX,
    required int originY,
    int overflowXPtr = 0,
    int overflowYPtr = 0,
    int overflowColorPtr = 0,
    int overflowLen = 0,
  }) {
    return false;
  }
}
