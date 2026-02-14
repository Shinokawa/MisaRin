class RustCpuFiltersFfi {
  RustCpuFiltersFfi._();

  static final RustCpuFiltersFfi instance = RustCpuFiltersFfi._();

  bool get isSupported => false;

  bool applyAntialias({
    required int pixelsPtr,
    required int pixelsLen,
    required int width,
    required int height,
    required int level,
    required bool previewOnly,
  }) {
    return false;
  }
}
