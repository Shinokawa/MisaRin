enum CanvasBackend {
  gpu,
  cpu,
}

extension CanvasBackendId on CanvasBackend {
  int get id => index;

  static CanvasBackend fromId(int id) {
    if (id == CanvasBackend.cpu.index) {
      return CanvasBackend.cpu;
    }
    return CanvasBackend.gpu;
  }
}
