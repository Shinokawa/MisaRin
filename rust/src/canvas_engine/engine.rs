use std::collections::HashMap;
use std::ffi::c_void;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{mpsc, Arc, Mutex, OnceLock};
use std::thread;
use std::time::Duration;

use metal::foreign_types::ForeignType;
use wgpu_hal::api::Metal;

use crate::api::bucket_fill;
use crate::gpu::bucket_fill_renderer::BucketFillRenderer;
use crate::gpu::brush_renderer::BrushRenderer;
use crate::gpu::debug::{self, LogLevel};

use super::layers::LayerTextures;
use super::present::{
    attach_present_texture, create_present_params_buffer, create_present_transform_buffer,
    write_present_config, write_present_transform, PresentRenderer, PresentTarget,
};
use super::stroke::{map_brush_shape, EngineBrushSettings, StrokeResampler};
use super::transform::LayerTransformRenderer;
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
    BucketFill {
        layer_index: u32,
        start_x: i32,
        start_y: i32,
        color_argb: u32,
        contiguous: bool,
        sample_all_layers: bool,
        tolerance: u8,
        fill_gap: u8,
        antialias_level: u8,
        swallow_colors: Vec<u32>,
        selection_mask: Option<Vec<u8>>,
        reply: mpsc::Sender<bool>,
    },
    MagicWandMask {
        layer_index: u32,
        start_x: i32,
        start_y: i32,
        sample_all_layers: bool,
        tolerance: u8,
        selection_mask: Option<Vec<u8>>,
        reply: mpsc::Sender<Option<Vec<u8>>>,
    },
    ReadLayer {
        layer_index: u32,
        reply: mpsc::Sender<Option<Vec<u32>>>,
    },
    WriteLayer {
        layer_index: u32,
        pixels: Vec<u32>,
        record_undo: bool,
        reply: mpsc::Sender<bool>,
    },
    TranslateLayer {
        layer_index: u32,
        delta_x: i32,
        delta_y: i32,
        reply: mpsc::Sender<bool>,
    },
    SetLayerTransformPreview {
        layer_index: u32,
        matrix: [f32; 16],
        enabled: bool,
        bilinear: bool,
    },
    ApplyLayerTransform {
        layer_index: u32,
        matrix: [f32; 16],
        bilinear: bool,
        reply: mpsc::Sender<bool>,
    },
    GetLayerBounds {
        layer_index: u32,
        reply: mpsc::Sender<Option<(i32, i32, i32, i32)>>,
    },
    SetSelectionMask {
        selection_mask: Option<Vec<u8>>,
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
    let mut layer_uniform: Vec<Option<u32>> = vec![None; layer_count];

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

    let mut bucket_fill_renderer = match BucketFillRenderer::new(device.clone(), queue.clone()) {
        Ok(renderer) => Some(renderer),
        Err(err) => {
            debug::log(
                LogLevel::Warn,
                format_args!("BucketFillRenderer init failed: {err}"),
            );
            None
        }
    };

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
    let present_transform_buffer = create_present_transform_buffer(device.as_ref());
    let mut transform_matrix: [f32; 16] = [
        1.0, 0.0, 0.0, 0.0, //
        0.0, 1.0, 0.0, 0.0, //
        0.0, 0.0, 1.0, 0.0, //
        0.0, 0.0, 0.0, 1.0, //
    ];
    let mut transform_layer_index: u32 = 0;
    let mut transform_flags: u32 = 0;
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
        transform_layer_index,
        transform_flags,
        &layer_opacity,
        &layer_visible,
        &layer_clipping_mask,
    );
    write_present_transform(queue.as_ref(), &present_transform_buffer, transform_matrix);
    let mut present_bind_group = present_renderer.create_bind_group(
        device.as_ref(),
        layers.array_view(),
        &present_config_buffer,
        &present_params_buffer,
        &present_transform_buffer,
    );

    let mut stroke = StrokeResampler::new();
    let mut undo_manager = UndoManager::new(canvas_width, canvas_height);
    let mut transform_renderer = match LayerTransformRenderer::new(device.clone(), queue.clone()) {
        Ok(renderer) => Some(renderer),
        Err(err) => {
            debug::log(
                LogLevel::Warn,
                format_args!("LayerTransformRenderer init failed: {err}"),
            );
            None
        }
    };

    loop {
        match &present {
            None => match cmd_rx.recv() {
                Ok(cmd) => {
                    let outcome = handle_engine_command(
                        device.as_ref(),
                        queue.as_ref(),
                        &mut present,
                        cmd,
                        &mut bucket_fill_renderer,
                        &mut layers,
                        &mut layer_count,
                        &mut active_layer_index,
                        &mut layer_opacity,
                        &mut layer_visible,
                        &mut layer_clipping_mask,
                        &mut layer_uniform,
                        &mut view_flags,
                        &present_renderer,
                        &present_config_buffer,
                        &present_transform_buffer,
                        &mut transform_matrix,
                        &mut transform_layer_index,
                        &mut transform_flags,
                        &mut present_params_buffer,
                        &mut present_params_capacity,
                        &mut present_bind_group,
                        &mut transform_renderer,
                        &mut brush,
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
                        &mut bucket_fill_renderer,
                        &mut layers,
                        &mut layer_count,
                        &mut active_layer_index,
                        &mut layer_opacity,
                        &mut layer_visible,
                        &mut layer_clipping_mask,
                        &mut layer_uniform,
                        &mut view_flags,
                        &present_renderer,
                        &present_config_buffer,
                        &present_transform_buffer,
                        &mut transform_matrix,
                        &mut transform_layer_index,
                        &mut transform_flags,
                        &mut present_params_buffer,
                        &mut present_params_capacity,
                        &mut present_bind_group,
                        &mut transform_renderer,
                        &mut brush,
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
                                brush.begin_stroke_base_capture();
                            }
                        } else {
                            undo_manager.begin_stroke_if_needed(active_layer_index as u32);
                        }

                        segment.push(p);

                        if is_up {
                            let layer_idx = active_layer_index as u32;
                            let use_hollow_base = brush_settings.hollow_enabled
                                && !brush_settings.erase
                                && brush_settings.hollow_ratio > 0.0001
                                && !brush_settings.hollow_erase_occluded;
                            let mut before_draw = |brush: &mut BrushRenderer, dirty_rect| {
                                undo_manager.capture_before_for_dirty_rect(
                                    device.as_ref(),
                                    queue.as_ref(),
                                    layer_texture,
                                    layer_idx,
                                    dirty_rect,
                                );
                                if use_hollow_base {
                                    if let Err(err) = brush.capture_stroke_base_region(
                                        layer_texture,
                                        layer_idx,
                                        dirty_rect,
                                    ) {
                                        debug::log(
                                            LogLevel::Warn,
                                            format_args!(
                                                "Brush stroke base capture failed: {err}"
                                            ),
                                        );
                                    }
                                }
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
                        let use_hollow_base = brush_settings.hollow_enabled
                            && !brush_settings.erase
                            && brush_settings.hollow_ratio > 0.0001
                            && !brush_settings.hollow_erase_occluded;
                        let mut before_draw = |brush: &mut BrushRenderer, dirty_rect| {
                            undo_manager.capture_before_for_dirty_rect(
                                device.as_ref(),
                                queue.as_ref(),
                                layer_texture,
                                layer_idx,
                                dirty_rect,
                            );
                            if use_hollow_base {
                                if let Err(err) = brush.capture_stroke_base_region(
                                    layer_texture,
                                    layer_idx,
                                    dirty_rect,
                                ) {
                                    debug::log(
                                        LogLevel::Warn,
                                        format_args!(
                                            "Brush stroke base capture failed: {err}"
                                        ),
                                    );
                                }
                            }
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

                    if drawn_any {
                        if let Some(entry) = layer_uniform.get_mut(active_layer_index) {
                            *entry = None;
                        }
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
    bucket_fill_renderer: &mut Option<BucketFillRenderer>,
    layers: &mut LayerTextures,
    layer_count: &mut usize,
    active_layer_index: &mut usize,
    layer_opacity: &mut Vec<f32>,
    layer_visible: &mut Vec<bool>,
    layer_clipping_mask: &mut Vec<bool>,
    layer_uniform: &mut Vec<Option<u32>>,
    present_view_flags: &mut u32,
    present_renderer: &PresentRenderer,
    present_config_buffer: &wgpu::Buffer,
    present_transform_buffer: &wgpu::Buffer,
    transform_matrix: &mut [f32; 16],
    transform_layer_index: &mut u32,
    transform_flags: &mut u32,
    present_params_buffer: &mut wgpu::Buffer,
    present_params_capacity: &mut usize,
    present_bind_group: &mut wgpu::BindGroup,
    transform_renderer: &mut Option<LayerTransformRenderer>,
    brush: &mut BrushRenderer,
    brush_settings: &mut EngineBrushSettings,
    undo: &mut UndoManager,
    canvas_width: u32,
    canvas_height: u32,
) -> EngineCommandOutcome {
    let mut ensure_layer_index = |idx: usize, transform_layer_index: u32, transform_flags: u32| -> bool {
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
                        present_transform_buffer,
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
        if new_count > layer_uniform.len() {
            layer_uniform.resize(new_count, None);
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
            layer_uniform[layer] = Some(0x00000000);
        }

        *layer_count = new_count;
        write_present_config(
            queue,
            present_config_buffer,
            present_params_buffer,
            *layer_count,
            *present_view_flags,
            transform_layer_index,
            transform_flags,
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
                layer_uniform.resize(*layer_count, None);
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
                    if let Some(entry) = layer_uniform.get_mut(idx) {
                        *entry = Some(fill);
                    }
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
            layer_uniform.resize(*layer_count, None);
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
                if let Some(entry) = layer_uniform.get_mut(idx) {
                    *entry = Some(fill);
                }
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
            if ensure_layer_index(idx, *transform_layer_index, *transform_flags) {
                fill_r32uint_texture(
                    queue,
                    layers.texture(),
                    canvas_width,
                    canvas_height,
                    idx as u32,
                    color_argb,
                );
                if let Some(entry) = layer_uniform.get_mut(idx) {
                    *entry = Some(color_argb);
                }
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: present.is_some(),
                };
            }
        }
        EngineCommand::ClearLayer { layer_index } => {
            let idx = layer_index as usize;
            if ensure_layer_index(idx, *transform_layer_index, *transform_flags) {
                fill_r32uint_texture(
                    queue,
                    layers.texture(),
                    canvas_width,
                    canvas_height,
                    idx as u32,
                    0x00000000,
                );
                if let Some(entry) = layer_uniform.get_mut(idx) {
                    *entry = Some(0x00000000);
                }
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: present.is_some(),
                };
            }
        }
        EngineCommand::SetActiveLayer { layer_index } => {
            let idx = layer_index as usize;
            if ensure_layer_index(idx, *transform_layer_index, *transform_flags) {
                *active_layer_index = idx;
            }
        }
        EngineCommand::SetLayerOpacity { layer_index, opacity } => {
            let idx = layer_index as usize;
            if ensure_layer_index(idx, *transform_layer_index, *transform_flags) {
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
                    *transform_layer_index,
                    *transform_flags,
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
            if ensure_layer_index(idx, *transform_layer_index, *transform_flags) {
                layer_visible[idx] = visible;
                write_present_config(
                    queue,
                    present_config_buffer,
                    present_params_buffer,
                    *layer_count,
                    *present_view_flags,
                    *transform_layer_index,
                    *transform_flags,
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
            if ensure_layer_index(idx, *transform_layer_index, *transform_flags) {
                layer_clipping_mask[idx] = clipping_mask;
                write_present_config(
                    queue,
                    present_config_buffer,
                    present_params_buffer,
                    *layer_count,
                    *present_view_flags,
                    *transform_layer_index,
                    *transform_flags,
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
                    *transform_layer_index,
                    *transform_flags,
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
        EngineCommand::BucketFill {
            layer_index,
            start_x,
            start_y,
            color_argb,
            contiguous,
            sample_all_layers,
            tolerance,
            fill_gap,
            antialias_level,
            swallow_colors,
            selection_mask,
            reply,
        } => {
            let idx = layer_index as usize;
            if !ensure_layer_index(idx, *transform_layer_index, *transform_flags) {
                let _ = reply.send(false);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }
            if canvas_width == 0 || canvas_height == 0 {
                let _ = reply.send(false);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }
            if start_x < 0
                || start_y < 0
                || (start_x as u32) >= canvas_width
                || (start_y as u32) >= canvas_height
            {
                let _ = reply.send(false);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }

            // Fast path: uniform layer with no selection mask can be filled directly.
            if !sample_all_layers && selection_mask.is_none() {
                if let Some(base_color) = layer_uniform.get(idx).copied().flatten() {
                    if base_color == color_argb {
                        let _ = reply.send(false);
                        return EngineCommandOutcome {
                            stop: false,
                            needs_render: false,
                        };
                    }
                    undo.begin_stroke(layer_index);
                    undo.capture_before_for_dirty_rect(
                        device,
                        queue,
                        layers.texture(),
                        layer_index,
                        (0, 0, canvas_width as i32, canvas_height as i32),
                    );
                    fill_r32uint_texture(
                        queue,
                        layers.texture(),
                        canvas_width,
                        canvas_height,
                        layer_index,
                        color_argb,
                    );
                    undo.end_stroke(device, queue, layers.texture());
                    if let Some(entry) = layer_uniform.get_mut(idx) {
                        *entry = Some(color_argb);
                    }
                    let _ = reply.send(true);
                    return EngineCommandOutcome {
                        stop: false,
                        needs_render: present.is_some(),
                    };
                }
            }

            if let Some(renderer) = bucket_fill_renderer.as_mut() {
                let Some(layer_view) = layers.layer_view(idx) else {
                    let _ = reply.send(false);
                    return EngineCommandOutcome {
                        stop: false,
                        needs_render: false,
                    };
                };

                undo.begin_stroke(layer_index);
                undo.capture_before_for_dirty_rect(
                    device,
                    queue,
                    layers.texture(),
                    layer_index,
                    (0, 0, canvas_width as i32, canvas_height as i32),
                );

                let applied = match renderer.bucket_fill(
                    layer_view,
                    layers.array_view(),
                    layer_index,
                    *layer_count,
                    layer_opacity,
                    layer_visible,
                    layer_clipping_mask,
                    canvas_width,
                    canvas_height,
                    start_x,
                    start_y,
                    color_argb,
                    contiguous,
                    sample_all_layers,
                    tolerance,
                    fill_gap,
                    antialias_level,
                    &swallow_colors,
                    selection_mask.as_deref(),
                ) {
                    Ok(changed) => changed,
                    Err(err) => {
                        debug::log(
                            LogLevel::Warn,
                            format_args!("bucket fill GPU failed: {err}"),
                        );
                        false
                    }
                };

                if applied {
                    undo.end_stroke(device, queue, layers.texture());
                    if let Some(entry) = layer_uniform.get_mut(idx) {
                        *entry = None;
                    }
                } else {
                    undo.cancel_stroke();
                }

                let _ = reply.send(applied);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: present.is_some(),
                };
            }

            let (active_pixels, sample_pixels) = if sample_all_layers {
                let mut layers_pixels: Vec<Vec<u32>> = Vec::with_capacity(*layer_count);
                for layer_idx in 0..*layer_count {
                    match read_r32uint_layer(
                        device,
                        queue,
                        layers.texture(),
                        canvas_width,
                        canvas_height,
                        layer_idx as u32,
                    ) {
                        Ok(pixels) => layers_pixels.push(pixels),
                        Err(err) => {
                            debug::log(
                                LogLevel::Warn,
                                format_args!("bucket fill readback failed: {err}"),
                            );
                            let _ = reply.send(false);
                            return EngineCommandOutcome {
                                stop: false,
                                needs_render: false,
                            };
                        }
                    }
                }
                let sample = composite_layers_for_bucket_fill(
                    canvas_width as usize,
                    canvas_height as usize,
                    &layers_pixels,
                    layer_opacity,
                    layer_visible,
                    layer_clipping_mask,
                );
                let active = std::mem::take(&mut layers_pixels[idx]);
                (active, Some(sample))
            } else {
                match read_r32uint_layer(
                    device,
                    queue,
                    layers.texture(),
                    canvas_width,
                    canvas_height,
                    idx as u32,
                ) {
                    Ok(pixels) => (pixels, None),
                    Err(err) => {
                        debug::log(
                            LogLevel::Warn,
                            format_args!("bucket fill readback failed: {err}"),
                        );
                        let _ = reply.send(false);
                        return EngineCommandOutcome {
                            stop: false,
                            needs_render: false,
                        };
                    }
                }
            };

            let patch = bucket_fill::flood_fill_patch(
                canvas_width as i32,
                canvas_height as i32,
                active_pixels,
                sample_pixels,
                start_x,
                start_y,
                color_argb,
                None,
                contiguous,
                tolerance as i32,
                fill_gap as i32,
                selection_mask,
                if swallow_colors.is_empty() {
                    None
                } else {
                    Some(swallow_colors)
                },
                antialias_level as i32,
            );

            if patch.width <= 0 || patch.height <= 0 {
                let _ = reply.send(false);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }

            let left = patch.left.max(0) as u32;
            let top = patch.top.max(0) as u32;
            let width = patch.width.max(0) as u32;
            let height = patch.height.max(0) as u32;
            if width == 0 || height == 0 {
                let _ = reply.send(false);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }

            let bytes_per_row_unpadded = match width.checked_mul(4) {
                Some(v) => v,
                None => {
                    let _ = reply.send(false);
                    return EngineCommandOutcome {
                        stop: false,
                        needs_render: false,
                    };
                }
            };
            let bytes_per_row_padded = align_up_u32(bytes_per_row_unpadded, 256);
            if bytes_per_row_padded == 0 {
                let _ = reply.send(false);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }
            let packed = match pack_u32_rows_with_padding(
                &patch.pixels,
                width,
                height,
                bytes_per_row_padded,
            ) {
                Ok(data) => data,
                Err(err) => {
                    debug::log(
                        LogLevel::Warn,
                        format_args!("bucket fill pack failed: {err}"),
                    );
                    let _ = reply.send(false);
                    return EngineCommandOutcome {
                        stop: false,
                        needs_render: false,
                    };
                }
            };

            undo.begin_stroke(layer_index);
            undo.capture_before_for_dirty_rect(
                device,
                queue,
                layers.texture(),
                layer_index,
                (patch.left, patch.top, patch.width, patch.height),
            );

            write_r32uint_region(
                queue,
                layers.texture(),
                left,
                top,
                width,
                height,
                layer_index,
                bytes_per_row_padded,
                &packed,
            );
            undo.end_stroke(device, queue, layers.texture());
            if let Some(entry) = layer_uniform.get_mut(idx) {
                *entry = None;
            }

            let _ = reply.send(true);
            return EngineCommandOutcome {
                stop: false,
                needs_render: present.is_some(),
            };
        }
        EngineCommand::MagicWandMask {
            layer_index,
            start_x,
            start_y,
            sample_all_layers,
            tolerance,
            selection_mask,
            reply,
        } => {
            let idx = layer_index as usize;
            if !ensure_layer_index(idx, *transform_layer_index, *transform_flags) {
                let _ = reply.send(None);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }
            if canvas_width == 0 || canvas_height == 0 {
                let _ = reply.send(None);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }
            if start_x < 0
                || start_y < 0
                || (start_x as u32) >= canvas_width
                || (start_y as u32) >= canvas_height
            {
                let _ = reply.send(None);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }

            let pixels = if sample_all_layers {
                let mut layers_pixels: Vec<Vec<u32>> = Vec::with_capacity(*layer_count);
                for layer_idx in 0..*layer_count {
                    match read_r32uint_layer(
                        device,
                        queue,
                        layers.texture(),
                        canvas_width,
                        canvas_height,
                        layer_idx as u32,
                    ) {
                        Ok(pixels) => layers_pixels.push(pixels),
                        Err(err) => {
                            debug::log(
                                LogLevel::Warn,
                                format_args!("magic wand readback failed: {err}"),
                            );
                            let _ = reply.send(None);
                            return EngineCommandOutcome {
                                stop: false,
                                needs_render: false,
                            };
                        }
                    }
                }
                composite_layers_for_bucket_fill(
                    canvas_width as usize,
                    canvas_height as usize,
                    &layers_pixels,
                    layer_opacity,
                    layer_visible,
                    layer_clipping_mask,
                )
            } else {
                match read_r32uint_layer(
                    device,
                    queue,
                    layers.texture(),
                    canvas_width,
                    canvas_height,
                    idx as u32,
                ) {
                    Ok(pixels) => pixels,
                    Err(err) => {
                        debug::log(
                            LogLevel::Warn,
                            format_args!("magic wand readback failed: {err}"),
                        );
                        let _ = reply.send(None);
                        return EngineCommandOutcome {
                            stop: false,
                            needs_render: false,
                        };
                    }
                }
            };

            let mask = bucket_fill::magic_wand_mask(
                canvas_width as i32,
                canvas_height as i32,
                pixels,
                start_x,
                start_y,
                tolerance as i32,
                selection_mask,
            );
            let _ = reply.send(mask);
            return EngineCommandOutcome {
                stop: false,
                needs_render: false,
            };
        }
        EngineCommand::ReadLayer { layer_index, reply } => {
            let idx = layer_index as usize;
            if idx >= *layer_count {
                let _ = reply.send(None);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }
            if canvas_width == 0 || canvas_height == 0 {
                let _ = reply.send(None);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }
            match read_r32uint_layer(
                device,
                queue,
                layers.texture(),
                canvas_width,
                canvas_height,
                layer_index,
            ) {
                Ok(pixels) => {
                    let _ = reply.send(Some(pixels));
                }
                Err(err) => {
                    debug::log(
                        LogLevel::Warn,
                        format_args!("layer readback failed: {err}"),
                    );
                    let _ = reply.send(None);
                }
            }
            return EngineCommandOutcome {
                stop: false,
                needs_render: false,
            };
        }
        EngineCommand::WriteLayer {
            layer_index,
            pixels,
            record_undo,
            reply,
        } => {
            let idx = layer_index as usize;
            if !ensure_layer_index(idx, *transform_layer_index, *transform_flags) {
                let _ = reply.send(false);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }
            let expected_len = (canvas_width as usize)
                .saturating_mul(canvas_height as usize);
            if expected_len == 0 || pixels.len() != expected_len {
                if expected_len > 0 {
                    debug::log(
                        LogLevel::Warn,
                        format_args!(
                            "layer write size mismatch: got {}, expected {}",
                            pixels.len(),
                            expected_len
                        ),
                    );
                }
                let _ = reply.send(false);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }
            let bytes_per_row_unpadded = match canvas_width.checked_mul(4) {
                Some(v) => v,
                None => {
                    let _ = reply.send(false);
                    return EngineCommandOutcome {
                        stop: false,
                        needs_render: false,
                    };
                }
            };
            let bytes_per_row_padded = align_up_u32(bytes_per_row_unpadded, 256);
            if bytes_per_row_padded == 0 {
                let _ = reply.send(false);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }
            let packed = match pack_u32_rows_with_padding(
                &pixels,
                canvas_width,
                canvas_height,
                bytes_per_row_padded,
            ) {
                Ok(data) => data,
                Err(err) => {
                    debug::log(
                        LogLevel::Warn,
                        format_args!("layer write pack failed: {err}"),
                    );
                    let _ = reply.send(false);
                    return EngineCommandOutcome {
                        stop: false,
                        needs_render: false,
                    };
                }
            };
            if record_undo {
                undo.begin_stroke(layer_index);
                undo.capture_before_for_dirty_rect(
                    device,
                    queue,
                    layers.texture(),
                    layer_index,
                    (0, 0, canvas_width as i32, canvas_height as i32),
                );
            }
            write_r32uint_region(
                queue,
                layers.texture(),
                0,
                0,
                canvas_width,
                canvas_height,
                layer_index,
                bytes_per_row_padded,
                &packed,
            );
            if record_undo {
                undo.end_stroke(device, queue, layers.texture());
            }
            if let Some(entry) = layer_uniform.get_mut(idx) {
                *entry = None;
            }
            let _ = reply.send(true);
            return EngineCommandOutcome {
                stop: false,
                needs_render: present.is_some(),
            };
        }
        EngineCommand::TranslateLayer {
            layer_index,
            delta_x,
            delta_y,
            reply,
        } => {
            let idx = layer_index as usize;
            if idx >= *layer_count {
                let _ = reply.send(false);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }
            if canvas_width == 0 || canvas_height == 0 {
                let _ = reply.send(false);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }
            if delta_x == 0 && delta_y == 0 {
                let _ = reply.send(false);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }
            if let Some(renderer) = transform_renderer.as_mut() {
                let matrix = translation_matrix(delta_x, delta_y);
                undo.begin_stroke(layer_index);
                undo.capture_before_for_dirty_rect(
                    device,
                    queue,
                    layers.texture(),
                    layer_index,
                    (0, 0, canvas_width as i32, canvas_height as i32),
                );
                if let Err(err) = renderer.apply_transform(
                    layers.array_view(),
                    layers.texture(),
                    canvas_width,
                    canvas_height,
                    layer_index,
                    matrix,
                    false,
                ) {
                    debug::log(
                        LogLevel::Warn,
                        format_args!("layer translate GPU failed: {err}"),
                    );
                    undo.cancel_stroke();
                    let _ = reply.send(false);
                    return EngineCommandOutcome {
                        stop: false,
                        needs_render: false,
                    };
                }
                undo.end_stroke(device, queue, layers.texture());
                if let Some(entry) = layer_uniform.get_mut(idx) {
                    *entry = None;
                }
                let _ = reply.send(true);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: present.is_some(),
                };
            }
            let pixels = match read_r32uint_layer(
                device,
                queue,
                layers.texture(),
                canvas_width,
                canvas_height,
                layer_index,
            ) {
                Ok(pixels) => pixels,
                Err(err) => {
                    debug::log(
                        LogLevel::Warn,
                        format_args!("layer translate readback failed: {err}"),
                    );
                    let _ = reply.send(false);
                    return EngineCommandOutcome {
                        stop: false,
                        needs_render: false,
                    };
                }
            };
            let width = canvas_width as i64;
            let height = canvas_height as i64;
            let dx = delta_x as i64;
            let dy = delta_y as i64;
            let mut shifted = vec![0u32; pixels.len()];
            let src_x_start = if dx >= 0 { 0 } else { (-dx).min(width) };
            let src_x_end = if dx >= 0 {
                (width - dx).max(0)
            } else {
                width
            };
            let src_y_start = if dy >= 0 { 0 } else { (-dy).min(height) };
            let src_y_end = if dy >= 0 {
                (height - dy).max(0)
            } else {
                height
            };
            if src_x_start < src_x_end && src_y_start < src_y_end {
                let src_width = width as usize;
                let dst_width = width as usize;
                for y in src_y_start..src_y_end {
                    let dst_y = y + dy;
                    if dst_y < 0 || dst_y >= height {
                        continue;
                    }
                    let src_row = (y as usize) * src_width;
                    let dst_row = (dst_y as usize) * dst_width;
                    let src_start = src_row + src_x_start as usize;
                    let src_end = src_row + src_x_end as usize;
                    let dst_start = dst_row + (src_x_start + dx) as usize;
                    let dst_end = dst_start + (src_end - src_start);
                    shifted[dst_start..dst_end].copy_from_slice(&pixels[src_start..src_end]);
                }
            }
            let bytes_per_row_unpadded = match canvas_width.checked_mul(4) {
                Some(v) => v,
                None => {
                    let _ = reply.send(false);
                    return EngineCommandOutcome {
                        stop: false,
                        needs_render: false,
                    };
                }
            };
            let bytes_per_row_padded = align_up_u32(bytes_per_row_unpadded, 256);
            if bytes_per_row_padded == 0 {
                let _ = reply.send(false);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }
            let packed = match pack_u32_rows_with_padding(
                &shifted,
                canvas_width,
                canvas_height,
                bytes_per_row_padded,
            ) {
                Ok(data) => data,
                Err(err) => {
                    debug::log(
                        LogLevel::Warn,
                        format_args!("layer translate pack failed: {err}"),
                    );
                    let _ = reply.send(false);
                    return EngineCommandOutcome {
                        stop: false,
                        needs_render: false,
                    };
                }
            };
            undo.begin_stroke(layer_index);
            undo.capture_before_for_dirty_rect(
                device,
                queue,
                layers.texture(),
                layer_index,
                (0, 0, canvas_width as i32, canvas_height as i32),
            );
            write_r32uint_region(
                queue,
                layers.texture(),
                0,
                0,
                canvas_width,
                canvas_height,
                layer_index,
                bytes_per_row_padded,
                &packed,
            );
            undo.end_stroke(device, queue, layers.texture());
            if let Some(entry) = layer_uniform.get_mut(idx) {
                *entry = None;
            }
            let _ = reply.send(true);
            return EngineCommandOutcome {
                stop: false,
                needs_render: present.is_some(),
            };
        }
        EngineCommand::SetLayerTransformPreview {
            layer_index,
            matrix,
            enabled,
            bilinear,
        } => {
            if enabled && (layer_index as usize) < *layer_count {
                *transform_layer_index = layer_index;
                *transform_flags = 1 | if bilinear { 2 } else { 0 };
                *transform_matrix = matrix;
                write_present_transform(queue, present_transform_buffer, *transform_matrix);
            } else {
                *transform_flags = 0;
            }
            write_present_config(
                queue,
                present_config_buffer,
                present_params_buffer,
                *layer_count,
                *present_view_flags,
                *transform_layer_index,
                *transform_flags,
                layer_opacity,
                layer_visible,
                layer_clipping_mask,
            );
            return EngineCommandOutcome {
                stop: false,
                needs_render: present.is_some(),
            };
        }
        EngineCommand::ApplyLayerTransform {
            layer_index,
            matrix,
            bilinear,
            reply,
        } => {
            let idx = layer_index as usize;
            if idx >= *layer_count {
                let _ = reply.send(false);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }
            if canvas_width == 0 || canvas_height == 0 {
                let _ = reply.send(false);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }
            let Some(renderer) = transform_renderer.as_mut() else {
                let _ = reply.send(false);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            };
            undo.begin_stroke(layer_index);
            undo.capture_before_for_dirty_rect(
                device,
                queue,
                layers.texture(),
                layer_index,
                (0, 0, canvas_width as i32, canvas_height as i32),
            );
            let result = renderer.apply_transform(
                layers.array_view(),
                layers.texture(),
                canvas_width,
                canvas_height,
                layer_index,
                matrix,
                bilinear,
            );
            if let Err(err) = result {
                debug::log(
                    LogLevel::Warn,
                    format_args!("layer transform apply failed: {err}"),
                );
                undo.cancel_stroke();
                let _ = reply.send(false);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }
            undo.end_stroke(device, queue, layers.texture());
            if let Some(entry) = layer_uniform.get_mut(idx) {
                *entry = None;
            }
            let _ = reply.send(true);
            return EngineCommandOutcome {
                stop: false,
                needs_render: present.is_some(),
            };
        }
        EngineCommand::GetLayerBounds { layer_index, reply } => {
            let idx = layer_index as usize;
            if idx >= *layer_count || canvas_width == 0 || canvas_height == 0 {
                let _ = reply.send(None);
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }
            let pixels = match read_r32uint_layer(
                device,
                queue,
                layers.texture(),
                canvas_width,
                canvas_height,
                layer_index,
            ) {
                Ok(pixels) => pixels,
                Err(err) => {
                    debug::log(
                        LogLevel::Warn,
                        format_args!("layer bounds readback failed: {err}"),
                    );
                    let _ = reply.send(None);
                    return EngineCommandOutcome {
                        stop: false,
                        needs_render: false,
                    };
                }
            };
            if pixels.is_empty() {
                let _ = reply.send(Some((
                    0,
                    0,
                    canvas_width as i32,
                    canvas_height as i32,
                )));
                return EngineCommandOutcome {
                    stop: false,
                    needs_render: false,
                };
            }
            let width = canvas_width as i32;
            let height = canvas_height as i32;
            let mut min_x = width;
            let mut min_y = height;
            let mut max_x = -1;
            let mut max_y = -1;
            for y in 0..height {
                let row_offset = (y as usize) * (width as usize);
                for x in 0..width {
                    let argb = pixels[row_offset + (x as usize)];
                    if (argb >> 24) == 0 {
                        continue;
                    }
                    if x < min_x {
                        min_x = x;
                    }
                    if x > max_x {
                        max_x = x;
                    }
                    if y < min_y {
                        min_y = y;
                    }
                    if y > max_y {
                        max_y = y;
                    }
                }
            }
            if max_x < min_x || max_y < min_y {
                let _ = reply.send(Some((0, 0, width, height)));
            } else {
                let _ = reply.send(Some((min_x, min_y, max_x + 1, max_y + 1)));
            }
            return EngineCommandOutcome {
                stop: false,
                needs_render: false,
            };
        }
        EngineCommand::SetSelectionMask { selection_mask } => {
            let expected_len = (canvas_width as usize).saturating_mul(canvas_height as usize);
            let valid_mask = match selection_mask {
                Some(mask) => {
                    if mask.len() == expected_len {
                        Some(mask)
                    } else {
                        if expected_len > 0 {
                            debug::log(
                                LogLevel::Warn,
                                format_args!(
                                    "selection mask size mismatch: got {}, expected {}",
                                    mask.len(),
                                    expected_len
                                ),
                            );
                        }
                        None
                    }
                }
                None => None,
            };
            if let Err(err) = brush.set_selection_mask(valid_mask.as_deref()) {
                debug::log(
                    LogLevel::Warn,
                    format_args!("selection mask update failed: {err}"),
                );
            }
        }
        EngineCommand::Undo => {
            let applied = undo.undo(device, queue, layers.texture(), *layer_count);
            if applied {
                for entry in layer_uniform.iter_mut() {
                    *entry = None;
                }
            }
            return EngineCommandOutcome {
                stop: false,
                needs_render: applied && present.is_some(),
            };
        }
        EngineCommand::Redo => {
            let applied = undo.redo(device, queue, layers.texture(), *layer_count);
            if applied {
                for entry in layer_uniform.iter_mut() {
                    *entry = None;
                }
            }
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

fn translation_matrix(delta_x: i32, delta_y: i32) -> [f32; 16] {
    let tx = -(delta_x as f32);
    let ty = -(delta_y as f32);
    [
        1.0, 0.0, 0.0, 0.0, //
        0.0, 1.0, 0.0, 0.0, //
        0.0, 0.0, 1.0, 0.0, //
        tx, ty, 0.0, 1.0, //
    ]
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

fn read_r32uint_layer(
    device: &wgpu::Device,
    queue: &wgpu::Queue,
    texture: &wgpu::Texture,
    width: u32,
    height: u32,
    layer_index: u32,
) -> Result<Vec<u32>, String> {
    if width == 0 || height == 0 {
        return Ok(Vec::new());
    }

    const BYTES_PER_PIXEL: u32 = 4;
    const COPY_BYTES_PER_ROW_ALIGNMENT: u32 = 256;

    let bytes_per_row_unpadded = width
        .checked_mul(BYTES_PER_PIXEL)
        .ok_or_else(|| "read_r32uint_layer: bytes_per_row overflow".to_string())?;
    let bytes_per_row_padded = align_up_u32(bytes_per_row_unpadded, COPY_BYTES_PER_ROW_ALIGNMENT);
    if bytes_per_row_padded == 0 {
        return Err("read_r32uint_layer: bytes_per_row_padded == 0".to_string());
    }
    let readback_size = (bytes_per_row_padded as u64)
        .checked_mul(height as u64)
        .ok_or_else(|| "read_r32uint_layer: readback_size overflow".to_string())?;

    let readback = device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("misa-rin canvas layer readback"),
        size: readback_size,
        usage: wgpu::BufferUsages::MAP_READ | wgpu::BufferUsages::COPY_DST,
        mapped_at_creation: false,
    });

    let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
        label: Some("misa-rin canvas layer readback encoder"),
    });
    encoder.copy_texture_to_buffer(
        wgpu::ImageCopyTexture {
            texture,
            mip_level: 0,
            origin: wgpu::Origin3d {
                x: 0,
                y: 0,
                z: layer_index,
            },
            aspect: wgpu::TextureAspect::All,
        },
        wgpu::ImageCopyBuffer {
            buffer: &readback,
            layout: wgpu::ImageDataLayout {
                offset: 0,
                bytes_per_row: Some(bytes_per_row_padded),
                rows_per_image: Some(height),
            },
        },
        wgpu::Extent3d {
            width,
            height,
            depth_or_array_layers: 1,
        },
    );
    queue.submit(Some(encoder.finish()));

    let buffer_slice = readback.slice(0..readback_size);
    let (tx, rx) = mpsc::channel();
    buffer_slice.map_async(wgpu::MapMode::Read, move |res| {
        let _ = tx.send(res);
    });
    device.poll(wgpu::Maintain::Wait);

    let map_status: Result<(), String> = match rx.recv() {
        Ok(Ok(())) => Ok(()),
        Ok(Err(e)) => Err(format!("read_r32uint_layer: map_async failed: {e:?}")),
        Err(e) => Err(format!("read_r32uint_layer: map_async channel failed: {e}")),
    };

    let mut result: Option<Vec<u32>> = None;
    if map_status.is_ok() {
        let mapped = buffer_slice.get_mapped_range();
        result = Some(unpack_u32_rows_without_padding(
            &mapped,
            width,
            height,
            bytes_per_row_padded,
        )?);
        drop(mapped);
        readback.unmap();
    }

    map_status?;
    Ok(result.unwrap_or_default())
}

fn write_r32uint_region(
    queue: &wgpu::Queue,
    texture: &wgpu::Texture,
    left: u32,
    top: u32,
    width: u32,
    height: u32,
    layer_index: u32,
    bytes_per_row_padded: u32,
    data: &[u8],
) {
    if width == 0 || height == 0 {
        return;
    }
    queue.write_texture(
        wgpu::ImageCopyTexture {
            texture,
            mip_level: 0,
            origin: wgpu::Origin3d {
                x: left,
                y: top,
                z: layer_index,
            },
            aspect: wgpu::TextureAspect::All,
        },
        data,
        wgpu::ImageDataLayout {
            offset: 0,
            bytes_per_row: Some(bytes_per_row_padded),
            rows_per_image: Some(height),
        },
        wgpu::Extent3d {
            width,
            height,
            depth_or_array_layers: 1,
        },
    );
}

fn pack_u32_rows_with_padding(
    pixels: &[u32],
    width: u32,
    height: u32,
    bytes_per_row_padded: u32,
) -> Result<Vec<u8>, String> {
    if width == 0 || height == 0 {
        return Ok(Vec::new());
    }
    let expected_len = (width as usize)
        .checked_mul(height as usize)
        .ok_or_else(|| "pack_u32_rows_with_padding: pixel_count overflow".to_string())?;
    if pixels.len() != expected_len {
        return Err(format!(
            "pack_u32_rows_with_padding: pixel len mismatch: got {}, expected {}",
            pixels.len(),
            expected_len
        ));
    }

    let bytes_per_row_unpadded: usize = (width as usize)
        .checked_mul(4)
        .ok_or_else(|| "pack_u32_rows_with_padding: bytes_per_row overflow".to_string())?;
    let bytes_per_row_padded_usize = bytes_per_row_padded as usize;
    let total_bytes: usize = bytes_per_row_padded_usize
        .checked_mul(height as usize)
        .ok_or_else(|| "pack_u32_rows_with_padding: total_bytes overflow".to_string())?;

    let mut out = vec![0u8; total_bytes];
    let width_usize = width as usize;
    for y in 0..height as usize {
        let src_row_start = y * width_usize;
        let row = &pixels[src_row_start..(src_row_start + width_usize)];
        let row_bytes: &[u8] = bytemuck::cast_slice(row);
        let dst_offset = y * bytes_per_row_padded_usize;
        out[dst_offset..(dst_offset + bytes_per_row_unpadded)].copy_from_slice(row_bytes);
    }
    Ok(out)
}

fn unpack_u32_rows_without_padding(
    data: &[u8],
    width: u32,
    height: u32,
    bytes_per_row_padded: u32,
) -> Result<Vec<u32>, String> {
    if width == 0 || height == 0 {
        return Ok(Vec::new());
    }
    let bytes_per_row_unpadded: usize = (width as usize)
        .checked_mul(4)
        .ok_or_else(|| "unpack_u32_rows_without_padding: bytes_per_row overflow".to_string())?;
    let bytes_per_row_padded_usize = bytes_per_row_padded as usize;
    let pixel_count: usize = (width as usize)
        .checked_mul(height as usize)
        .ok_or_else(|| "unpack_u32_rows_without_padding: pixel_count overflow".to_string())?;
    let mut out: Vec<u32> = vec![0u32; pixel_count];

    let width_usize = width as usize;
    for y in 0..height as usize {
        let src_offset = y * bytes_per_row_padded_usize;
        let row_bytes = &data[src_offset..(src_offset + bytes_per_row_unpadded)];
        let row_u32: &[u32] = bytemuck::cast_slice(row_bytes);
        let dst_row_start = y * width_usize;
        out[dst_row_start..(dst_row_start + width_usize)].copy_from_slice(row_u32);
    }
    Ok(out)
}

fn composite_layers_for_bucket_fill(
    width: usize,
    height: usize,
    layers_pixels: &[Vec<u32>],
    layer_opacity: &[f32],
    layer_visible: &[bool],
    layer_clipping_mask: &[bool],
) -> Vec<u32> {
    let len = match width.checked_mul(height) {
        Some(v) => v,
        None => return Vec::new(),
    };
    let mut composite = vec![0u32; len];

    for index in 0..len {
        let mut color: u32 = 0;
        let mut initialized = false;
        let mut mask_alpha: u8 = 0;

        for layer_idx in 0..layers_pixels.len() {
            let visible = layer_visible.get(layer_idx).copied().unwrap_or(true);
            if !visible {
                continue;
            }
            let opacity = layer_opacity.get(layer_idx).copied().unwrap_or(1.0);
            let clipping = layer_clipping_mask
                .get(layer_idx)
                .copied()
                .unwrap_or(false);
            if opacity <= 0.0 {
                if !clipping {
                    mask_alpha = 0;
                }
                continue;
            }
            let pixels = &layers_pixels[layer_idx];
            if pixels.len() != len {
                if !clipping {
                    mask_alpha = 0;
                }
                continue;
            }
            let src = pixels[index];
            let src_a = ((src >> 24) & 0xff) as u32;
            if src_a == 0 {
                if !clipping {
                    mask_alpha = 0;
                }
                continue;
            }

            let mut total_opacity = opacity.clamp(0.0, 1.0);
            if clipping {
                if mask_alpha == 0 {
                    continue;
                }
                total_opacity *= (mask_alpha as f32) / 255.0;
                if total_opacity <= 0.0 {
                    continue;
                }
            }

            let mut effective_a = ((src_a as f32) * total_opacity).round() as i32;
            if effective_a <= 0 {
                if !clipping {
                    mask_alpha = 0;
                }
                continue;
            }
            if effective_a > 255 {
                effective_a = 255;
            }
            if !clipping {
                mask_alpha = effective_a as u8;
            }
            let effective_color = ((effective_a as u32) << 24) | (src & 0x00FFFFFF);
            if !initialized {
                color = effective_color;
                initialized = true;
            } else {
                color = blend_argb(color, effective_color);
            }
        }

        composite[index] = if initialized { color } else { 0 };
    }

    composite
}

fn blend_argb(dst: u32, src: u32) -> u32 {
    let src_a = (src >> 24) & 0xff;
    if src_a == 0 {
        return dst;
    }
    if src_a == 255 {
        return src;
    }
    let dst_a = (dst >> 24) & 0xff;
    let inv_src_a = 255 - src_a;
    let out_a = src_a + mul255(dst_a, inv_src_a);
    if out_a == 0 {
        return 0;
    }

    let src_r = (src >> 16) & 0xff;
    let src_g = (src >> 8) & 0xff;
    let src_b = src & 0xff;
    let dst_r = (dst >> 16) & 0xff;
    let dst_g = (dst >> 8) & 0xff;
    let dst_b = dst & 0xff;

    let src_prem_r = mul255(src_r, src_a);
    let src_prem_g = mul255(src_g, src_a);
    let src_prem_b = mul255(src_b, src_a);
    let dst_prem_r = mul255(dst_r, dst_a);
    let dst_prem_g = mul255(dst_g, dst_a);
    let dst_prem_b = mul255(dst_b, dst_a);

    let out_prem_r = src_prem_r + mul255(dst_prem_r, inv_src_a);
    let out_prem_g = src_prem_g + mul255(dst_prem_g, inv_src_a);
    let out_prem_b = src_prem_b + mul255(dst_prem_b, inv_src_a);

    let out_r = (((out_prem_r * 255) + (out_a >> 1)) / out_a).min(255);
    let out_g = (((out_prem_g * 255) + (out_a >> 1)) / out_a).min(255);
    let out_b = (((out_prem_b * 255) + (out_a >> 1)) / out_a).min(255);

    (out_a << 24) | (out_r << 16) | (out_g << 8) | out_b
}

fn mul255(channel: u32, alpha: u32) -> u32 {
    (channel * alpha + 127) / 255
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
