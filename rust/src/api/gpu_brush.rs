use std::sync::{Mutex, OnceLock};
use std::sync::Arc;

use crate::gpu::brush_renderer::{BrushRenderer, BrushShape, Color, Point2D};
use crate::gpu::layer_texture::LayerTextureManager;

struct GpuBrushEngine {
    textures: LayerTextureManager,
    brush: BrushRenderer,
}

static GPU_BRUSH: OnceLock<Mutex<Option<GpuBrushEngine>>> = OnceLock::new();

fn brush_cell() -> &'static Mutex<Option<GpuBrushEngine>> {
    GPU_BRUSH.get_or_init(|| Mutex::new(None))
}

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
  pub pixels: Vec<u32>,
}

#[flutter_rust_bridge::frb(sync)]
pub fn gpu_brush_init() -> Result<(), String> {
    let mut guard = brush_cell()
        .lock()
        .map_err(|_| "gpu brush lock poisoned".to_string())?;
    if guard.is_some() {
        return Ok(());
    }

    let (device, queue) = create_wgpu_device()?;
    let device = Arc::new(device);
    let queue = Arc::new(queue);
    let mut brush = BrushRenderer::new(device.clone(), queue.clone())?;
    brush.set_softness(0.0);

    let textures = LayerTextureManager::new(device.clone(), queue.clone());

    *guard = Some(GpuBrushEngine { textures, brush });
    Ok(())
}

pub fn gpu_upload_layer(
    layer_id: String,
    pixels: Vec<u32>,
    width: u32,
    height: u32,
) -> Result<(), String> {
    let mut guard = brush_cell()
        .lock()
        .map_err(|_| "gpu brush lock poisoned".to_string())?;
    let engine = guard.as_mut().ok_or_else(|| {
        "gpu brush not initialized (call gpu_brush_init first)".to_string()
    })?;

    engine.textures.upload_layer(&layer_id, &pixels, width, height)?;
    engine.brush.set_canvas_size(width, height);
    Ok(())
}

pub fn gpu_download_layer(layer_id: String) -> Result<Vec<u32>, String> {
    let guard = brush_cell()
        .lock()
        .map_err(|_| "gpu brush lock poisoned".to_string())?;
    let engine = guard.as_ref().ok_or_else(|| {
        "gpu brush not initialized (call gpu_brush_init first)".to_string()
    })?;
    engine.textures.download_layer(&layer_id)
}

#[flutter_rust_bridge::frb(sync)]
pub fn gpu_remove_layer(layer_id: String) -> Result<(), String> {
    let mut guard = brush_cell()
        .lock()
        .map_err(|_| "gpu brush lock poisoned".to_string())?;
    let Some(engine) = guard.as_mut() else {
        return Ok(());
    };
    engine.textures.remove_layer(&layer_id);
    Ok(())
}

#[flutter_rust_bridge::frb(sync)]
pub fn gpu_brush_dispose() {
    if let Some(cell) = GPU_BRUSH.get() {
        if let Ok(mut guard) = cell.lock() {
            *guard = None;
        }
    }
}

pub fn gpu_draw_stroke(
    layer_id: String,
    points: Vec<GpuPoint2D>,
    radii: Vec<f32>,
    color: u32, // ARGB
    brush_shape: u32,
    erase: bool,
    antialias_level: u32,
) -> Result<GpuStrokeResult, String> {
    let mut guard = brush_cell()
        .lock()
        .map_err(|_| "gpu brush lock poisoned".to_string())?;
    let engine = guard.as_mut().ok_or_else(|| {
        "gpu brush not initialized (call gpu_brush_init first)".to_string()
    })?;

    let width = engine.textures.width();
    let height = engine.textures.height();
    if width == 0 || height == 0 {
        return Err("gpu_draw_stroke: layer textures not initialized (upload a layer first)"
            .to_string());
    }
    engine.brush.set_canvas_size(width, height);

    let layer_texture = engine
        .textures
        .get_texture(&layer_id)
        .ok_or_else(|| format!("gpu_draw_stroke: unknown layer '{layer_id}'"))?;

    if points.is_empty() {
        return Ok(GpuStrokeResult {
            dirty_left: 0,
            dirty_top: 0,
            dirty_width: 0,
            dirty_height: 0,
            pixels: Vec::new(),
        });
    }
    if points.len() != radii.len() {
        return Err(format!(
            "gpu_draw_stroke: points/radii length mismatch: {} vs {}",
            points.len(),
            radii.len()
        ));
    }

    let shape = map_brush_shape(brush_shape)?;

    let converted_points: Vec<Point2D> = points
        .into_iter()
        .map(|p| Point2D { x: p.x, y: p.y })
        .collect();

    engine.brush.draw_stroke(
        layer_texture,
        &converted_points,
        &radii,
        Color { argb: color },
        shape,
        erase,
        antialias_level,
    )?;

    let dirty = compute_dirty_rect_i32(&converted_points, &radii, width, height);
    let (dirty_left, dirty_top, dirty_width, dirty_height) = dirty;
    let pixels = if dirty_width > 0 && dirty_height > 0 {
        engine.textures.download_layer_region(
            &layer_id,
            dirty_left.max(0) as u32,
            dirty_top.max(0) as u32,
            dirty_width as u32,
            dirty_height as u32,
        )?
    } else {
        Vec::new()
    };
    Ok(GpuStrokeResult {
        dirty_left,
        dirty_top,
        dirty_width,
        dirty_height,
        pixels,
    })
}

fn map_brush_shape(index: u32) -> Result<BrushShape, String> {
    // Dart enum: circle=0, triangle=1, square=2, star=3.
    // Some callers may have already migrated to a 2-value enum: circle=0, square=1.
    match index {
        0 => Ok(BrushShape::Circle),
        1 | 2 => Ok(BrushShape::Square),
        _ => Err(format!("unsupported brush_shape index: {index}")),
    }
}

fn compute_dirty_rect_i32(points: &[Point2D], radii: &[f32], width: u32, height: u32) -> (i32, i32, i32, i32) {
    if width == 0 || height == 0 || points.is_empty() || points.len() != radii.len() {
        return (0, 0, 0, 0);
    }

    let mut min_x: f32 = f32::INFINITY;
    let mut min_y: f32 = f32::INFINITY;
    let mut max_x: f32 = f32::NEG_INFINITY;
    let mut max_y: f32 = f32::NEG_INFINITY;
    let mut max_r: f32 = 0.0;

    for (p, &r) in points.iter().zip(radii.iter()) {
        let x = if p.x.is_finite() { p.x } else { 0.0 };
        let y = if p.y.is_finite() { p.y } else { 0.0 };
        let radius = if r.is_finite() { r.max(0.0) } else { 0.0 };
        min_x = min_x.min(x);
        min_y = min_y.min(y);
        max_x = max_x.max(x);
        max_y = max_y.max(y);
        max_r = max_r.max(radius);
    }

    if !min_x.is_finite() || !min_y.is_finite() || !max_x.is_finite() || !max_y.is_finite() {
        return (0, 0, 0, 0);
    }

    let pad = max_r + 2.0;
    let left = ((min_x - pad).floor() as i64).clamp(0, width as i64);
    let top = ((min_y - pad).floor() as i64).clamp(0, height as i64);
    let right = ((max_x + pad).ceil() as i64).clamp(0, width as i64);
    let bottom = ((max_y + pad).ceil() as i64).clamp(0, height as i64);

    let dirty_w = (right - left).max(0) as i32;
    let dirty_h = (bottom - top).max(0) as i32;
    (left as i32, top as i32, dirty_w, dirty_h)
}

fn create_wgpu_device() -> Result<(wgpu::Device, wgpu::Queue), String> {
    let instance = wgpu::Instance::new(wgpu::InstanceDescriptor {
        backends: wgpu::Backends::all(),
        ..Default::default()
    });

    let adapter = pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
        power_preference: wgpu::PowerPreference::HighPerformance,
        compatible_surface: None,
        force_fallback_adapter: false,
    }))
    .ok_or_else(|| "wgpu: no compatible GPU adapter found".to_string())?;

    let adapter_limits = adapter.limits();
    let required_limits = wgpu::Limits {
        max_buffer_size: adapter_limits.max_buffer_size,
        max_storage_buffer_binding_size: adapter_limits.max_storage_buffer_binding_size,
        ..wgpu::Limits::default()
    };

    pollster::block_on(adapter.request_device(
        &wgpu::DeviceDescriptor {
            label: Some("misa-rin GpuBrush device"),
            required_features: wgpu::Features::empty(),
            required_limits,
        },
        None,
    ))
    .map_err(|e| format!("wgpu: request_device failed: {e:?}"))
}
