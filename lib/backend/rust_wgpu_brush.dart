import '../src/rust/api/gpu_brush.dart' as rust_gpu;

typedef RustWgpuStrokeResult = rust_gpu.GpuStrokeResult;

void rustWgpuRemoveLayer({required String layerId}) {
  rust_gpu.gpuRemoveLayer(layerId: layerId);
}
