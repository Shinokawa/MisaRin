class RustCpuBlendFfi {
  RustCpuBlendFfi._();

  static final RustCpuBlendFfi instance = RustCpuBlendFfi._();

  bool get isSupported => false;

  bool blendOnCanvas({
    required int srcPtr,
    required int dstPtr,
    required int pixelsLen,
    required int width,
    required int height,
    required int startX,
    required int endX,
    required int startY,
    required int endY,
    required double opacity,
    required int blendMode,
    int maskPtr = 0,
    int maskLen = 0,
    double maskOpacity = 0,
  }) {
    return false;
  }

  bool blendOverflow({
    required int canvasPtr,
    required int canvasLen,
    required int width,
    required int height,
    required int upperXPtr,
    required int upperYPtr,
    required int upperColorPtr,
    required int upperLen,
    required int lowerXPtr,
    required int lowerYPtr,
    required int lowerColorPtr,
    required int lowerLen,
    required double opacity,
    required int blendMode,
    int maskPtr = 0,
    int maskLen = 0,
    double maskOpacity = 0,
    int maskOverflowXPtr = 0,
    int maskOverflowYPtr = 0,
    int maskOverflowColorPtr = 0,
    int maskOverflowLen = 0,
    int outXPtr = 0,
    int outYPtr = 0,
    int outColorPtr = 0,
    int outCapacity = 0,
    int outCountPtr = 0,
  }) {
    return false;
  }
}
