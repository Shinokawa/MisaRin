use std::sync::{Mutex, OnceLock};
use std::sync::Arc;
use std::time::Instant;
use std::collections::HashMap;

use crate::gpu::brush_renderer::{BrushRenderer, BrushShape, Color, Point2D};
use crate::gpu::debug::{self, LogLevel};
use crate::gpu::layer_texture::LayerTextureManager;

#[derive(Clone, Copy, Debug)]
struct StrokeEndpoint {
    point: Point2D,
    radius: f32,
    seq: u64,
    at: Instant,
}

struct GpuBrushEngine {
    textures: LayerTextureManager,
    brush: BrushRenderer,
    last_endpoints: HashMap<String, StrokeEndpoint>,
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

    let t0 = Instant::now();
    let (device, queue) = create_wgpu_device()?;
    let device = Arc::new(device);
    let queue = Arc::new(queue);
    let mut brush = BrushRenderer::new(device.clone(), queue.clone())?;
    brush.set_softness(0.0);

    let textures = LayerTextureManager::new(device.clone(), queue.clone());

    *guard = Some(GpuBrushEngine {
        textures,
        brush,
        last_endpoints: HashMap::new(),
    });
    debug::log(
        LogLevel::Info,
        format_args!("gpu_brush_init ok in {:?}.", t0.elapsed()),
    );
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

    let t0 = Instant::now();
    engine.textures.upload_layer(&layer_id, &pixels, width, height)?;
    engine.brush.set_canvas_size(width, height);
    debug::log(
        LogLevel::Info,
        format_args!(
            "gpu_upload_layer ok layer='{layer_id}' size={width}x{height} pixels={} in {:?}.",
            pixels.len(),
            t0.elapsed()
        ),
    );
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
    engine.last_endpoints.remove(&layer_id);
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
    let seq = debug::next_seq();
    let total_t0 = Instant::now();

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

    // Detect unexpected discontinuities between successive segments on the same layer.
    // This helps distinguish "input/segmentation dropped points" vs "render/display cache".
    if let Some(first_point) = converted_points.first().copied() {
        let first_radius = radii.first().copied().unwrap_or(0.0).max(0.0);
        if let Some(prev) = engine.last_endpoints.get(&layer_id).copied() {
            let dx = first_point.x - prev.point.x;
            let dy = first_point.y - prev.point.y;
            let dist = (dx * dx + dy * dy).sqrt();
            let dt_ms = prev.at.elapsed().as_millis();
            if dist.is_finite() && dist >= 2.0 && dt_ms <= 250 {
                debug::log(
                    LogLevel::Warn,
                    format_args!(
                        "#{seq} stroke discontinuity layer='{layer_id}': prev_end=({:.2},{:.2}) r={:.2} (seq #{}) -> cur_start=({:.2},{:.2}) r={:.2} dist={:.2}px dt={}ms",
                        prev.point.x,
                        prev.point.y,
                        prev.radius,
                        prev.seq,
                        first_point.x,
                        first_point.y,
                        first_radius,
                        dist,
                        dt_ms
                    ),
                );
            } else {
                debug::log(
                    LogLevel::Verbose,
                    format_args!(
                        "#{seq} stroke continuity layer='{layer_id}': dist={:.3}px dt={}ms",
                        dist,
                        dt_ms
                    ),
                );
            }
        }
    }

    if debug::level() >= LogLevel::Info {
        let mut min_x: f32 = f32::INFINITY;
        let mut min_y: f32 = f32::INFINITY;
        let mut max_x: f32 = f32::NEG_INFINITY;
        let mut max_y: f32 = f32::NEG_INFINITY;
        let mut min_r: f32 = f32::INFINITY;
        let mut max_r: f32 = 0.0;
        let mut non_finite_xy: usize = 0;
        let mut non_finite_r: usize = 0;
        let mut out_of_bounds: usize = 0;

        for (p, &r) in converted_points.iter().zip(radii.iter()) {
            if !p.x.is_finite() || !p.y.is_finite() {
                non_finite_xy += 1;
                continue;
            }
            if p.x < 0.0 || p.y < 0.0 || p.x > width as f32 || p.y > height as f32 {
                out_of_bounds += 1;
            }
            min_x = min_x.min(p.x);
            min_y = min_y.min(p.y);
            max_x = max_x.max(p.x);
            max_y = max_y.max(p.y);

            if !r.is_finite() {
                non_finite_r += 1;
                continue;
            }
            let rr = r.max(0.0);
            min_r = min_r.min(rr);
            max_r = max_r.max(rr);
        }

        let first = converted_points.first().copied().unwrap_or(Point2D { x: 0.0, y: 0.0 });
        let last = converted_points.last().copied().unwrap_or(Point2D { x: 0.0, y: 0.0 });
        debug::log(
            LogLevel::Info,
            format_args!(
                "#{seq} gpu_draw_stroke layer='{layer_id}' canvas={width}x{height} pts={} color=0x{color:08X} erase={erase} shape={shape:?} aa={antialias_level} bbox=({min_x:.2},{min_y:.2})-({max_x:.2},{max_y:.2}) r=[{min_r:.2},{max_r:.2}] first=({:.2},{:.2}) last=({:.2},{:.2}) oob={out_of_bounds} nan_xy={non_finite_xy} nan_r={non_finite_r}",
                converted_points.len(),
                first.x,
                first.y,
                last.x,
                last.y
            ),
        );

        if max_r.is_finite() && max_r < 0.75 {
            debug::log(
                LogLevel::Warn,
                format_args!(
                    "#{seq} suspicious small brush radius: max_r={max_r:.3} (canvas={width}x{height})"
                ),
            );
        }
    }

    let draw_t0 = Instant::now();
    engine.brush.draw_stroke(
        layer_texture,
        &converted_points,
        &radii,
        Color { argb: color },
        shape,
        erase,
        antialias_level,
    )?;
    debug::log(
        LogLevel::Verbose,
        format_args!("#{seq} brush.draw_stroke ok in {:?}.", draw_t0.elapsed()),
    );

    let dirty = compute_dirty_rect_i32(&converted_points, &radii, width, height);
    let (dirty_left, dirty_top, dirty_width, dirty_height) = dirty;
    debug::log(
        LogLevel::Info,
        format_args!(
            "#{seq} dirty=({dirty_left},{dirty_top}) {dirty_width}x{dirty_height}"
        ),
    );

    let dl_t0 = Instant::now();
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
    debug::log(
        LogLevel::Verbose,
        format_args!(
            "#{seq} download_layer_region len={} in {:?}.",
            pixels.len(),
            dl_t0.elapsed()
        ),
    );

    if dirty_width > 0 && dirty_height > 0 {
        let expected_len = (dirty_width as usize).saturating_mul(dirty_height as usize);
        if expected_len != pixels.len() {
            debug::log(
                LogLevel::Warn,
                format_args!(
                    "#{seq} region pixel len mismatch: got={} expected={expected_len} (dirty={dirty_left},{dirty_top} {dirty_width}x{dirty_height})",
                    pixels.len()
                ),
            );
        }
        if debug::level() >= LogLevel::Verbose && expected_len > 0 && pixels.len() >= expected_len
        {
            let summary = summarize_argb_region(&pixels[..expected_len], dirty_width as usize);
            debug::log(
                LogLevel::Verbose,
                format_args!(
                    "#{seq} region_coverage nonzero={} max_a={} bbox=({},{})-({},{}) hash=0x{:016X}",
                    summary.nonzero,
                    summary.max_alpha,
                    dirty_left + summary.min_x,
                    dirty_top + summary.min_y,
                    dirty_left + summary.max_x,
                    dirty_top + summary.max_y,
                    summary.hash
                ),
            );
            if summary.nonzero == 0 {
                debug::log(
                    LogLevel::Warn,
                    format_args!(
                        "#{seq} region has zero coverage (dirty={dirty_left},{dirty_top} {dirty_width}x{dirty_height})"
                    ),
                );
            }
        }
    }

    // Update last endpoint tracking for continuity diagnostics.
    if let Some(last_point) = converted_points.last().copied() {
        let last_radius = radii.last().copied().unwrap_or(0.0).max(0.0);
        engine.last_endpoints.insert(
            layer_id.clone(),
            StrokeEndpoint {
                point: last_point,
                radius: last_radius,
                seq,
                at: Instant::now(),
            },
        );
    }

    debug::log(
        LogLevel::Verbose,
        format_args!("#{seq} gpu_draw_stroke total {:?}.", total_t0.elapsed()),
    );
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
        _ => Ok(BrushShape::Square),
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

#[derive(Clone, Copy, Debug)]
struct RegionCoverageSummary {
    nonzero: usize,
    min_x: i32,
    min_y: i32,
    max_x: i32,
    max_y: i32,
    max_alpha: u8,
    hash: u64,
}

fn summarize_argb_region(pixels: &[u32], width: usize) -> RegionCoverageSummary {
    if width == 0 || pixels.is_empty() {
        return RegionCoverageSummary {
            nonzero: 0,
            min_x: 0,
            min_y: 0,
            max_x: 0,
            max_y: 0,
            max_alpha: 0,
            hash: 0,
        };
    }
    let height = pixels.len() / width;
    if height == 0 {
        return RegionCoverageSummary {
            nonzero: 0,
            min_x: 0,
            min_y: 0,
            max_x: 0,
            max_y: 0,
            max_alpha: 0,
            hash: 0,
        };
    }

    let mut nonzero: usize = 0;
    let mut min_x: i32 = width as i32;
    let mut min_y: i32 = height as i32;
    let mut max_x: i32 = -1;
    let mut max_y: i32 = -1;
    let mut max_alpha: u8 = 0;

    let mut hash: u64 = 14695981039346656037u64; // FNV-1a 64-bit offset basis
    let sample_stride: usize = (pixels.len() / 8192).max(1);

    for (i, &argb) in pixels.iter().enumerate() {
        if i % sample_stride == 0 {
            hash ^= argb as u64;
            hash = hash.wrapping_mul(1099511628211u64);
        }

        let a: u8 = (argb >> 24) as u8;
        if a == 0 {
            continue;
        }
        max_alpha = max_alpha.max(a);
        nonzero += 1;
        let x = (i % width) as i32;
        let y = (i / width) as i32;
        min_x = min_x.min(x);
        min_y = min_y.min(y);
        max_x = max_x.max(x);
        max_y = max_y.max(y);
    }

    if nonzero == 0 {
        return RegionCoverageSummary {
            nonzero,
            min_x: 0,
            min_y: 0,
            max_x: 0,
            max_y: 0,
            max_alpha,
            hash,
        };
    }

    RegionCoverageSummary {
        nonzero,
        min_x,
        min_y,
        max_x,
        max_y,
        max_alpha,
        hash,
    }
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

    if debug::level() >= LogLevel::Info {
        let info = adapter.get_info();
        let limits = adapter.limits();
        debug::log(
            LogLevel::Info,
            format_args!(
                "wgpu adapter: backend={:?} device_type={:?} name='{}' max_tex_2d={} max_buf={} max_storage_binding={}",
                info.backend,
                info.device_type,
                info.name,
                limits.max_texture_dimension_2d,
                limits.max_buffer_size,
                limits.max_storage_buffer_binding_size
            ),
        );
    }

    let adapter_limits = adapter.limits();
    let adapter_features = adapter.features();
    let required_limits = wgpu::Limits {
        max_buffer_size: adapter_limits.max_buffer_size,
        max_storage_buffer_binding_size: adapter_limits.max_storage_buffer_binding_size,
        ..wgpu::Limits::default()
    };

    let required_features = wgpu::Features::TEXTURE_ADAPTER_SPECIFIC_FORMAT_FEATURES;
    if !adapter_features.contains(required_features) {
        return Err("wgpu: adapter does not support TEXTURE_ADAPTER_SPECIFIC_FORMAT_FEATURES".to_string());
    }

    pollster::block_on(adapter.request_device(
        &wgpu::DeviceDescriptor {
            label: Some("misa-rin GpuBrush device"),
            required_features,
            required_limits,
        },
        None,
    ))
    .map_err(|e| format!("wgpu: request_device failed: {e:?}"))
}
