#[flutter_rust_bridge::frb]
pub struct GpuPoint2D {
    pub x: f32,
    pub y: f32,
}

#[flutter_rust_bridge::frb]
pub struct GpuStrokeResult {
    pub dirty_left: i32,
    pub dirty_top: i32,
    pub dirty_width: i32,
    pub dirty_height: i32,
    pub draw_calls: u32,
}

#[flutter_rust_bridge::frb(sync)]
pub fn gpu_brush_init() -> Result<(), String> {
    Err("gpu brush is not supported on web".to_string())
}

pub fn gpu_upload_layer(
    _layer_id: String,
    _pixels: Vec<u32>,
    _width: u32,
    _height: u32,
) -> Result<(), String> {
    Err("gpu brush is not supported on web".to_string())
}

pub fn gpu_download_layer(_layer_id: String) -> Result<Vec<u32>, String> {
    Err("gpu brush is not supported on web".to_string())
}

#[flutter_rust_bridge::frb(sync)]
pub fn gpu_remove_layer(_layer_id: String) -> Result<(), String> {
    Ok(())
}

#[flutter_rust_bridge::frb(sync)]
pub fn gpu_brush_dispose() {}

pub fn gpu_draw_stroke(
    _layer_id: String,
    _points: Vec<GpuPoint2D>,
    _radii: Vec<f32>,
    _color: u32,
    _brush_shape: u32,
    _erase: bool,
    _antialias_level: u32,
) -> Result<GpuStrokeResult, String> {
    Err("gpu brush is not supported on web".to_string())
}
