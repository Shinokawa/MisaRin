use std::sync::{Mutex, OnceLock};

use crate::gpu::compositor::{GpuCompositor, LayerData};

static GPU_COMPOSITOR: OnceLock<Mutex<Option<GpuCompositor>>> = OnceLock::new();

fn compositor_cell() -> &'static Mutex<Option<GpuCompositor>> {
    GPU_COMPOSITOR.get_or_init(|| Mutex::new(None))
}

#[flutter_rust_bridge::frb]
pub struct GpuLayerData {
    pub pixels: Vec<u32>,
    pub opacity: f64,
    pub blend_mode_index: u32,
    pub visible: bool,
    pub clipping_mask: bool,
}

#[flutter_rust_bridge::frb(sync)]
pub fn gpu_compositor_init() -> Result<(), String> {
    let mut guard = compositor_cell()
        .lock()
        .map_err(|_| "gpu compositor lock poisoned".to_string())?;
    if guard.is_some() {
        return Ok(());
    }
    let compositor = GpuCompositor::new()?;
    *guard = Some(compositor);
    Ok(())
}

pub fn gpu_composite_layers(
    layers: Vec<GpuLayerData>,
    width: u32,
    height: u32,
) -> Result<Vec<u32>, String> {
    let mut guard = compositor_cell()
        .lock()
        .map_err(|_| "gpu compositor lock poisoned".to_string())?;
    let compositor = guard.as_mut().ok_or_else(|| {
        "gpu compositor not initialized (call gpu_compositor_init first)".to_string()
    })?;

    let converted: Vec<LayerData> = layers
        .into_iter()
        .map(|layer| LayerData {
            pixels: layer.pixels,
            opacity: clamp_unit_f64_to_f32(layer.opacity),
            blend_mode: layer.blend_mode_index,
            visible: layer.visible,
            clipping_mask: layer.clipping_mask,
        })
        .collect();

    compositor.composite_layers(converted, width, height)
}

#[flutter_rust_bridge::frb(sync)]
pub fn gpu_compositor_dispose() {
    if let Some(cell) = GPU_COMPOSITOR.get() {
        if let Ok(mut guard) = cell.lock() {
            *guard = None;
        }
    }
}

fn clamp_unit_f64_to_f32(value: f64) -> f32 {
    if !value.is_finite() {
        return 0.0;
    }
    let clamped = value.clamp(0.0, 1.0);
    clamped as f32
}
