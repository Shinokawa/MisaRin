use std::collections::HashMap;
use std::ffi::c_void;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{mpsc, Arc, Mutex, OnceLock};
use std::thread;
use std::time::Duration;

use metal::foreign_types::ForeignType;
use wgpu_hal::api::Metal;

use crate::gpu::brush_renderer::BrushRenderer;
use crate::gpu::debug::{self, LogLevel};

use super::layers::LayerTextures;
use super::present::{
    attach_present_texture, create_present_params_buffer, write_present_config, PresentRenderer,
    PresentTarget,
};
use super::stroke::{map_brush_shape, EngineBrushSettings, StrokeResampler};
use super::types::EnginePoint;
use super::undo::UndoManager;

const INITIAL_LAYER_CAPACITY: usize = 4;
const VIEW_FLAG_MIRROR: u32 = 1;
const VIEW_FLAG_BLACK_WHITE: u32 = 2;

pub(crate) enum EngineCommand {
    AttachPresentTexture {
        mtl_texture_ptr: usize,
        width: u32,
        height: u32,
        bytes_per_row: u32,
    },
    ResetCanvas { background_color_argb: u32 },
    FillLayer { layer_index: u32, color_argb: u32 },
    ClearLayer { layer_index: u32 },
    SetActiveLayer { layer_index: u32 },
    SetLayerOpacity { layer_index: u32, opacity: f32 },
    SetLayerVisible { layer_index: u32, visible: bool },
    SetLayerClippingMask { layer_index: u32, clipping_mask: bool },
    SetViewFlags { view_flags: u32 },
    SetBrush {
        color_argb: u32,
        base_radius: f32,
        use_pressure: bool,
        erase: bool,
        antialias_level: u32,
        brush_shape: u32,
        random_rotation: bool,
        rotation_seed: u32,
        hollow_enabled: bool,
        hollow_ratio: f32,
        hollow_erase_occluded: bool,
    },
    Undo,
    Redo,
    Stop,
}

pub(crate) struct EngineInputBatch {
    pub(crate) points: Vec<EnginePoint>,
}

pub(crate) struct EngineEntry {
    pub(crate) mtl_device_ptr: usize,
    pub(crate) frame_ready: Arc<AtomicBool>,
    pub(crate) cmd_tx: mpsc::Sender<EngineCommand>,
    pub(crate) input_tx: mpsc::Sender<EngineInputBatch>,
    pub(crate) input_queue_len: Arc<AtomicU64>,
}

static ENGINES: OnceLock<Mutex<HashMap<u64, EngineEntry>>> = OnceLock::new();
static NEXT_HANDLE: AtomicU64 = AtomicU64::new(1);

fn engines() -> &'static Mutex<HashMap<u64, EngineEntry>> {
    ENGINES.get_or_init(|| Mutex::new(HashMap::new()))
}

fn spawn_render_thread(
    device: wgpu::Device,
    queue: wgpu::Queue,
    layer_textures: LayerTextures,
    cmd_rx: mpsc::Receiver<EngineCommand>,
    input_rx: mpsc::Receiver<EngineInputBatch>,
    frame_ready: Arc<AtomicBool>,
    input_queue_len: Arc<AtomicU64>,
    canvas_width: u32,
    canvas_height: u32,
) {
    let _ = thread::Builder::new()
        .name("misa-rin-canvas-render".to_string())
        .spawn(move || {
            render_thread_main(
                device,
                queue,
                layer_textures,
                cmd_rx,
                input_rx,
                frame_ready,
                input_queue_len,
                canvas_width,
                canvas_height,
            )
        });
}

fn render_thread_main(
    device: wgpu::Device,
    queue: wgpu::Queue,
    layer_textures: LayerTextures,
    cmd_rx: mpsc::Receiver<EngineCommand>,
    input_rx: mpsc::Receiver<EngineInputBatch>,
    frame_ready: Arc<AtomicBool>,
    input_queue_len: Arc<AtomicU64>,
    canvas_width: u32,
    canvas_height: u32,
) {
    let device = Arc::new(device);
    let queue = Arc::new(queue);

    let mut present: Option<PresentTarget> = None;
    let mut layers = layer_textures;
    if layers.capacity() == 0 {
        return;
    }
    // Layer order is bottom-to-top.
    let mut layer_count: usize = 1;
    let mut active_layer_index: usize = 0;

    let mut brush = match BrushRenderer::new(device.clone(), queue.clone()) {
        Ok(renderer) => renderer,
        Err(err) => {
            debug::log(LogLevel::Warn, format_args!("BrushRenderer init failed: {err}"));
            return;
        }
    };
    brush.set_canvas_size(canvas_width, canvas_height);
    brush.set_softness(0.0);
    let mut brush_settings = EngineBrushSettings::default();

    let present_renderer = PresentRenderer::new(device.as_ref());
    let mut layer_opacity: Vec<f32> = vec![1.0; layer_count];
    let mut layer_visible: Vec<bool> = vec![true; layer_count];
    let mut layer_clipping_mask: Vec<bool> = vec![false; layer_count];
    let mut view_flags: u32 = 0;
    let present_config_buffer = device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("misa-rin present composite config"),
        size: std::mem::size_of::<super::present::PresentCompositeHeader>() as u64,
        usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
        mapped_at_creation: false,
    });
    let mut present_params_capacity = layers.capacity();
    let mut present_params_buffer =
        match create_present_params_buffer(device.as_ref(), present_params_capacity) {
            Ok(buffer) => buffer,
            Err(err) => {
                debug::log(
                    LogLevel::Warn,
                    format_args!("Present params buffer init failed: {err}"),
                );
                return;
            }
        };
    write_present_config(
        queue.as_ref(),
        &present_config_buffer,
        &present_params_buffer,
        layer_count,
        view_flags,
        &layer_opacity,
        &layer_visible,
        &layer_clipping_mask,
    );
    let mut present_bind_group = present_renderer.create_bind_group(
        device.as_ref(),
        layers.array_view(),
        &present_config_buffer,
        &present_params_buffer,
    );

    let mut stroke = StrokeResampler::new();
    let mut undo_manager = UndoManager::new(canvas_width, canvas_height);

    loop {
        match &present {
            None => match cmd_rx.recv() {
                Ok(cmd) => {
                    let outcome = handle_engine_command(
                        device.as_ref(),
                        queue.as_ref(),
                        &mut present,
                        cmd,
                        &mut layers,
                        &mut layer_count,
                        &mut active_layer_index,
                        &mut layer_opacity,
                        &mut layer_visible,
                        &mut layer_clipping_mask,
                        &mut view_flags,
                        &present_renderer,
                        &present_config_buffer,
                        &mut present_params_buffer,
                        &mut present_params_capacity,
                        &mut present_bind_group,
                        &mut brush_settings,
                        &mut undo_manager,
                        canvas_width,
                        canvas_height,
                    );
                    if outcome.stop {
                        break;
                    }
                    // The first present texture attach happens while `present` is still `None`
                    // at the start of the iteration. If the command requests a render and we
                    // now have a present target, render once so Flutter gets a deterministic
                    // initial frame (e.g. white background layer).
                    if outcome.needs_render {
                        if let Some(target) = &present {
                            present_renderer.render(
                                device.as_ref(),
                                queue.as_ref(),
                                &present_bind_group,
                                &target.view,
                                Arc::clone(&frame_ready),
                            );
                        }
                    }
                }
                Err(_) => break,
            },
            Some(_) => {
                let mut needs_render = false;
                while let Ok(cmd) = cmd_rx.try_recv() {
                    let outcome = handle_engine_command(
                        device.as_ref(),
                        queue.as_ref(),
                        &mut present,
                        cmd,
                        &mut layers,
                        &mut layer_count,
                        &mut active_layer_index,
                        &mut layer_opacity,
                        &mut layer_visible,
                        &mut layer_clipping_mask,
                        &mut view_flags,
                        &present_renderer,
                        &present_config_buffer,
                        &mut present_params_buffer,
                        &mut present_params_capacity,
                        &mut present_bind_group,
                        &mut brush_settings,
                        &mut undo_manager,
                        canvas_width,
                        canvas_height,
                    );
                    if outcome.stop {
                        return;
                    }
                    needs_render |= outcome.needs_render;
                }

                let mut batches: Vec<EngineInputBatch> = Vec::new();
                match input_rx.recv_timeout(Duration::from_millis(4)) {
                    Ok(batch) => {
                        input_queue_len.fetch_sub(batch.points.len() as u64, Ordering::Relaxed);
                        batches.push(batch);
                        while let Ok(more) = input_rx.try_recv() {
                            input_queue_len
                                .fetch_sub(more.points.len() as u64, Ordering::Relaxed);
                            batches.push(more);
                        }
                    }
                    Err(mpsc::RecvTimeoutError::Timeout) => {}
                    Err(mpsc::RecvTimeoutError::Disconnected) => return,
                }

                if !batches.is_empty() {
                    let mut raw_points: Vec<EnginePoint> = Vec::new();
                    for batch in batches {
                        raw_points.extend(batch.points);
                    }

                    let active_layer_view = layers
                        .layer_view(active_layer_index)
                        .or_else(|| layers.layer_view(0))
                        .expect("layers non-empty");
                    let layer_texture = layers.texture();
                    let mut segment: Vec<EnginePoint> = Vec::new();
                    let mut drawn_any = false;

                    for p in raw_points {
                        const FLAG_DOWN: u32 = 1;
                        const FLAG_UP: u32 = 4;
                        let is_down = (p.flags & FLAG_DOWN) != 0;
                        let is_up = (p.flags & FLAG_UP) != 0;

                        if is_down {
                            undo_manager.begin_stroke(active_layer_index as u32);
                            let use_hollow_mask = brush_settings.hollow_enabled
                                && !brush_settings.erase
                                && brush_settings.hollow_ratio > 0.0001;
                            if use_hollow_mask {
                                if let Err(err) = brush.clear_stroke_mask() {
                                    debug::log(
                                        LogLevel::Warn,
                                        format_args!("Brush stroke mask clear failed: {err}"),
                                    );
                                }
                                if !brush_settings.hollow_erase_occluded {
                                    if let Err(err) = brush.capture_stroke_base(
                                        layers.texture(),
                                        active_layer_index as u32,
                                    ) {
                                        debug::log(
                                            LogLevel::Warn,
                                            format_args!(
                                                "Brush stroke base capture failed: {err}"
                                            ),
                                        );
                                    }
                                }
                            }
                        } else {
                            undo_manager.begin_stroke_if_needed(active_layer_index as u32);
                        }

                        segment.push(p);

                        if is_up {
                            let layer_idx = active_layer_index as u32;
                            let mut before_draw = |dirty_rect| {
                                undo_manager.capture_before_for_dirty_rect(
                                    device.as_ref(),
                                    queue.as_ref(),
                                    layer_texture,
                                    layer_idx,
                                    dirty_rect,
                                );
                            };
                            drawn_any |= stroke.consume_and_draw(
                                &mut brush,
                                &brush_settings,
                                active_layer_view,
                                std::mem::take(&mut segment),
                                canvas_width,
                                canvas_height,
                                &mut before_draw,
                            );
                            undo_manager.end_stroke(device.as_ref(), queue.as_ref(), layer_texture);
                        }
                    }

                    if !segment.is_empty() {
                        let layer_idx = active_layer_index as u32;
                        let mut before_draw = |dirty_rect| {
                            undo_manager.capture_before_for_dirty_rect(
                                device.as_ref(),
                                queue.as_ref(),
                                layer_texture,
                                layer_idx,
                                dirty_rect,
                            );
                        };
                        drawn_any |= stroke.consume_and_draw(
                            &mut brush,
                            &brush_settings,
                            active_layer_view,
                            segment,
                            canvas_width,
                            canvas_height,
                            &mut before_draw,
                        );
                    }

                    needs_render |= drawn_any;
                }

                if needs_render {
                    if let Some(target) = &present {
                        present_renderer.render(
                            device.as_ref(),
                            queue.as_ref(),
                            &present_bind_group,
                            &target.view,
                            Arc::clone(&frame_ready),
                        );
                    }
                }
            }
        }

        device.poll(wgpu::Maintain::Poll);
    }
}

fn handle_engine_command(
    device: &wgpu::Device,
    queue: &wgpu::Queue,
    present: &mut Option<PresentTarget>,
    cmd: EngineCommand,
    layers: &mut LayerTextures,
    layer_count: &mut usize,
    active_layer_index: &mut usize,
    layer_opacity: &mut Vec<f32>,
    layer_visible: &mut Vec<bool>,
    layer_clipping_mask: &mut Vec<bool>,
    present_view_flags: &mut u32,
    present_renderer: &PresentRenderer,
    present_config_buffer: &wgpu::Buffer,
    present_params_buffer: &mut wgpu::Buffer,
    present_params_capacity: &mut usize,
    present_bind_group: &mut wgpu::BindGroup,
    brush_settings: &mut EngineBrushSettings,
    undo: &mut UndoManager,
    canvas_width: u32,
    canvas_height: u32,
) -> EngineCommandOutcome {
    let mut ensure_layer_index = |idx: usize| -> bool {
        if idx < *layer_count {
            return true;
        }
        let old_count = *layer_count;
        let new_count = idx + 1;
        let resized = match layers.ensure_capacity(device, queue, new_count) {
            Ok(Some(_)) => true,
            Ok(None) => false,
            Err(err) => {
                debug::log(
                    LogLevel::Warn,
                    format_args!("Layer capacity resize failed: {err}"),
                );
                return false;
            }
        };
        if resized {
            *present_params_capacity = layers.capacity();
            match create_present_params_buffer(device, *present_params_capacity) {
                Ok(buffer) => {
                    *present_params_buffer = buffer;
                    *present_bind_group = present_renderer.create_bind_group(
                        device,
                        layers.array_view(),
                        present_config_buffer,
                        present_params_buffer,
                    );
                }
                Err(err) => {
                    debug::log(
                        LogLevel::Warn,
                        format_args!("Present params buffer resize failed: {err}"),
                    );
                    return false;
                }
            }
        }

        if new_count > layer_opacity.len() {
            layer_opacity.resize(new_count, 1.0);
        }
        if new_count > layer_visible.len() {
            layer_visible.resize(new_count, true);
        }
        if new_count > layer_clipping_mask.len() {
            layer_clipping_mask.resize(new_count, false);
        }

        for layer in old_count..new_count {
            fill_r32uint_texture(
                queue,
                layers.texture(),
                canvas_width,
                canvas_height,
                layer as u32,
                0x00000000,
            );
        }

        *layer_count = new_count;
        write_present_config(
            queue,
            present_config_buffer,
            present_params_buffer,
            *layer_count,
            *present_view_flags,
            layer_opacity,
            layer_visible,
            layer_clipping_mask,
        );
        true
    };

    match cmd {
        EngineCommand::Stop => {
            return EngineCommandOutcome {
                stop: true,
                needs_render: false,
            }
        }
        EngineCommand::AttachPresentTexture {
            mtl_texture_ptr,
            width,
            height,
            bytes_per_row,
        } => {
            if mtl_texture_ptr == 0 || width == 0 || height == 0 {
                debug::log(
                    LogLevel::Warn,
                    format_args!(
                        "AttachPresentTexture ignored: ptr=0x{mtl_texture_ptr:x} size={width}x{height}"
                    ),
                );
                *present = None;
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }
            *present = attach_present_texture(device, mtl_texture_ptr, width, height, bytes_per_row);
            if present.is_some() {
                debug::log(
                    LogLevel::Info,
                    format_args!(
                        "Present texture attached: ptr=0x{mtl_texture_ptr:x} size={width}x{height} bytes_per_row={bytes_per_row}"
                    ),
                );
                // Initialize layers so the first composite is deterministic.
                // Layer 0 is the background fill layer (default white), others start transparent.
                for idx in 0..*layer_count {
                    let fill = if idx == 0 { 0xFFFFFFFF } else { 0x00000000 };
                    fill_r32uint_texture(
                        queue,
                        layers.texture(),
                        canvas_width,
                        canvas_height,
                        idx as u32,
                        fill,
                    );
                }
                // Request one render so Flutter gets an actual composited frame immediately.
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: true,
                };
            }
        }
        EngineCommand::ResetCanvas { background_color_argb } => {
            // Reset undo history so a fresh canvas doesn't "undo" back into the previous one.
            undo.reset();
            // Layer 0 is background fill; everything above starts transparent.
            for idx in 0..*layer_count {
                let fill = if idx == 0 {
                    background_color_argb
                } else {
                    0x00000000
                };
                fill_r32uint_texture(
                    queue,
                    layers.texture(),
                    canvas_width,
                    canvas_height,
                    idx as u32,
                    fill,
                );
            }
            return EngineCommandOutcome {
                stop: false,
                needs_render: present.is_some(),
            };
        }
        EngineCommand::FillLayer {
            layer_index,
            color_argb,
        } => {
            let idx = layer_index as usize;
            if ensure_layer_index(idx) {
                fill_r32uint_texture(
                    queue,
                    layers.texture(),
                    canvas_width,
                    canvas_height,
                    idx as u32,
                    color_argb,
                );
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: present.is_some(),
                };
            }
        }
        EngineCommand::ClearLayer { layer_index } => {
            let idx = layer_index as usize;
            if ensure_layer_index(idx) {
                fill_r32uint_texture(
                    queue,
                    layers.texture(),
                    canvas_width,
                    canvas_height,
                    idx as u32,
                    0x00000000,
                );
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: present.is_some(),
                };
            }
        }
        EngineCommand::SetActiveLayer { layer_index } => {
            let idx = layer_index as usize;
            if ensure_layer_index(idx) {
                *active_layer_index = idx;
            }
        }
        EngineCommand::SetLayerOpacity { layer_index, opacity } => {
            let idx = layer_index as usize;
            if ensure_layer_index(idx) {
                layer_opacity[idx] = if opacity.is_finite() {
                    opacity.clamp(0.0, 1.0)
                } else {
                    0.0
                };
                write_present_config(
                    queue,
                    present_config_buffer,
                    present_params_buffer,
                    *layer_count,
                    *present_view_flags,
                    layer_opacity,
                    layer_visible,
                    layer_clipping_mask,
                );
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: present.is_some(),
                };
            }
        }
        EngineCommand::SetLayerVisible {
            layer_index,
            visible,
        } => {
            let idx = layer_index as usize;
            if ensure_layer_index(idx) {
                layer_visible[idx] = visible;
                write_present_config(
                    queue,
                    present_config_buffer,
                    present_params_buffer,
                    *layer_count,
                    *present_view_flags,
                    layer_opacity,
                    layer_visible,
                    layer_clipping_mask,
                );
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: present.is_some(),
                };
            }
        }
        EngineCommand::SetLayerClippingMask {
            layer_index,
            clipping_mask,
        } => {
            let idx = layer_index as usize;
            if ensure_layer_index(idx) {
                layer_clipping_mask[idx] = clipping_mask;
                write_present_config(
                    queue,
                    present_config_buffer,
                    present_params_buffer,
                    *layer_count,
                    *present_view_flags,
                    layer_opacity,
                    layer_visible,
                    layer_clipping_mask,
                );
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: present.is_some(),
                };
            }
        }
        EngineCommand::SetViewFlags { view_flags } => {
            let sanitized = view_flags & (VIEW_FLAG_MIRROR | VIEW_FLAG_BLACK_WHITE);
            if *present_view_flags != sanitized {
                *present_view_flags = sanitized;
                write_present_config(
                    queue,
                    present_config_buffer,
                    present_params_buffer,
                    *layer_count,
                    *present_view_flags,
                    layer_opacity,
                    layer_visible,
                    layer_clipping_mask,
                );
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: present.is_some(),
                };
            }
        }
        EngineCommand::SetBrush {
            color_argb,
            base_radius,
            use_pressure,
            erase,
            antialias_level,
            brush_shape,
            random_rotation,
            rotation_seed,
            hollow_enabled,
            hollow_ratio,
            hollow_erase_occluded,
        } => {
            brush_settings.color_argb = color_argb;
            brush_settings.base_radius = base_radius;
            brush_settings.use_pressure = use_pressure;
            brush_settings.erase = erase;
            brush_settings.antialias_level = antialias_level;
            brush_settings.shape = map_brush_shape(brush_shape);
            brush_settings.random_rotation = random_rotation;
            brush_settings.rotation_seed = rotation_seed;
            brush_settings.hollow_enabled = hollow_enabled;
            brush_settings.hollow_ratio = hollow_ratio;
            brush_settings.hollow_erase_occluded = hollow_erase_occluded;
            brush_settings.sanitize();
        }
        EngineCommand::Undo => {
            let applied = undo.undo(device, queue, layers.texture(), *layer_count);
            return EngineCommandOutcome {
                stop: false,
                needs_render: applied && present.is_some(),
            };
        }
        EngineCommand::Redo => {
            let applied = undo.redo(device, queue, layers.texture(), *layer_count);
            return EngineCommandOutcome {
                stop: false,
                needs_render: applied && present.is_some(),
            };
        }
    }
    EngineCommandOutcome {
        stop: false,
        needs_render: false,
    }
}

#[derive(Clone, Copy, Debug)]
struct EngineCommandOutcome {
    stop: bool,
    needs_render: bool,
}

fn fill_r32uint_texture(
    queue: &wgpu::Queue,
    texture: &wgpu::Texture,
    width: u32,
    height: u32,
    layer_index: u32,
    value: u32,
) {
    if width == 0 || height == 0 {
        return;
    }

    const BYTES_PER_PIXEL: u32 = 4;
    const COPY_BYTES_PER_ROW_ALIGNMENT: u32 = 256;
    // Keep temporary allocations bounded even for very large canvases.
    const MAX_CHUNK_BYTES: usize = 4 * 1024 * 1024;

    let bytes_per_row_unpadded = width.saturating_mul(BYTES_PER_PIXEL);
    let bytes_per_row_padded = align_up_u32(bytes_per_row_unpadded, COPY_BYTES_PER_ROW_ALIGNMENT);
    if bytes_per_row_padded == 0 {
        return;
    }

    let row_bytes = bytes_per_row_padded as usize;
    let rows_per_chunk = (MAX_CHUNK_BYTES / row_bytes).max(1) as u32;
    let texels_per_row = (bytes_per_row_padded / BYTES_PER_PIXEL) as usize;

    let mut y: u32 = 0;
    while y < height {
        let chunk_h = (height - y).min(rows_per_chunk);
        let texel_count = texels_per_row.saturating_mul(chunk_h as usize);
        let data: Vec<u32> = vec![value; texel_count];

        queue.write_texture(
            wgpu::ImageCopyTexture {
                texture,
                mip_level: 0,
                origin: wgpu::Origin3d {
                    x: 0,
                    y,
                    z: layer_index,
                },
                aspect: wgpu::TextureAspect::All,
            },
            bytemuck::cast_slice(&data),
            wgpu::ImageDataLayout {
                offset: 0,
                bytes_per_row: Some(bytes_per_row_padded),
                rows_per_image: Some(chunk_h),
            },
            wgpu::Extent3d {
                width,
                height: chunk_h,
                depth_or_array_layers: 1,
            },
        );

        y = y.saturating_add(chunk_h);
    }
}

fn align_up_u32(value: u32, alignment: u32) -> u32 {
    if alignment == 0 {
        return value;
    }
    let rem = value % alignment;
    if rem == 0 {
        value
    } else {
        value + (alignment - rem)
    }
}

fn mtl_device_ptr(device: &wgpu::Device) -> *mut c_void {
    let result = unsafe {
        device.as_hal::<Metal, _, _>(|hal_device| {
            hal_device.map(|hal_device| {
                let raw_device = hal_device.raw_device().lock();
                raw_device.as_ptr() as *mut c_void
            })
        })
    };
    result.flatten().unwrap_or(std::ptr::null_mut())
}

pub(crate) fn create_engine(width: u32, height: u32) -> Result<u64, String> {
    if width == 0 || height == 0 {
        return Err("engine_create: width/height must be > 0".to_string());
    }

    let instance = wgpu::Instance::new(wgpu::InstanceDescriptor {
        backends: wgpu::Backends::METAL,
        ..Default::default()
    });

    let adapter =
        pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
            power_preference: wgpu::PowerPreference::HighPerformance,
            compatible_surface: None,
            force_fallback_adapter: false,
        }))
        .ok_or_else(|| "wgpu: no compatible Metal adapter found".to_string())?;

    let required_features = wgpu::Features::TEXTURE_ADAPTER_SPECIFIC_FORMAT_FEATURES;
    if !adapter.features().contains(required_features) {
        return Err(
            "wgpu: adapter does not support TEXTURE_ADAPTER_SPECIFIC_FORMAT_FEATURES (required for read-write storage textures)"
                .to_string(),
        );
    }

    let (device, queue) = pollster::block_on(adapter.request_device(
        &wgpu::DeviceDescriptor {
            label: Some("misa-rin CanvasEngine device"),
            required_features,
            required_limits: wgpu::Limits::default(),
        },
        None,
    ))
    .map_err(|e| format!("wgpu: request_device failed: {e:?}"))?;

    let mtl_device_ptr = mtl_device_ptr(&device) as usize;
    if mtl_device_ptr == 0 {
        return Err("wgpu: failed to extract underlying MTLDevice".to_string());
    }

    let layers = LayerTextures::new(&device, width, height, INITIAL_LAYER_CAPACITY)
        .map_err(|err| format!("engine_create: layer init failed: {err}"))?;

    let (cmd_tx, cmd_rx) = mpsc::channel();
    let (input_tx, input_rx) = mpsc::channel();
    let input_queue_len = Arc::new(AtomicU64::new(0));
    let frame_ready = Arc::new(AtomicBool::new(false));
    spawn_render_thread(
        device,
        queue,
        layers,
        cmd_rx,
        input_rx,
        Arc::clone(&frame_ready),
        Arc::clone(&input_queue_len),
        width,
        height,
    );

    let handle = NEXT_HANDLE.fetch_add(1, Ordering::Relaxed);
    let mut guard = engines()
        .lock()
        .map_err(|_| "engine registry lock poisoned".to_string())?;
    guard.insert(
        handle,
        EngineEntry {
            mtl_device_ptr,
            frame_ready,
            cmd_tx,
            input_tx,
            input_queue_len,
        },
    );

    Ok(handle)
}

pub(crate) fn lookup_engine(handle: u64) -> Option<EngineEntry> {
    if handle == 0 {
        return None;
    }
    let guard = engines().lock().ok()?;
    let entry = guard.get(&handle)?;
    Some(EngineEntry {
        mtl_device_ptr: entry.mtl_device_ptr,
        frame_ready: Arc::clone(&entry.frame_ready),
        cmd_tx: entry.cmd_tx.clone(),
        input_tx: entry.input_tx.clone(),
        input_queue_len: Arc::clone(&entry.input_queue_len),
    })
}

pub(crate) fn remove_engine(handle: u64) -> Option<EngineEntry> {
    if handle == 0 {
        return None;
    }
    let mut guard = engines().lock().ok()?;
    guard.remove(&handle)
}
