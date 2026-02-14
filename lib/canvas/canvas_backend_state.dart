import 'canvas_backend.dart';

class CanvasBackendState {
  CanvasBackendState._();

  static bool _initialized = false;
  static CanvasBackend _backend = CanvasBackend.gpu;

  static CanvasBackend get backend => _backend;

  static void initialize(CanvasBackend backend) {
    if (_initialized) {
      return;
    }
    _backend = backend;
    _initialized = true;
  }

  static CanvasBackend resolveRasterBackend({required bool useBackendCanvas}) {
    return useBackendCanvas ? CanvasBackend.gpu : CanvasBackend.cpu;
  }
}
