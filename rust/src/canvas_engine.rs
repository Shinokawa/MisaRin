use std::collections::HashMap;
use std::ffi::c_void;
use std::borrow::Cow;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{mpsc, Arc, Mutex, OnceLock};
use std::thread;
use std::time::Duration;

#[cfg(target_os = "macos")]
use metal::foreign_types::ForeignType;
#[cfg(target_os = "macos")]
use metal::MTLTextureType;
#[cfg(target_os = "macos")]
use wgpu_hal::{api::Metal, CopyExtent};

#[cfg(target_os = "macos")]
use crate::gpu::brush_renderer::{BrushRenderer, BrushShape, Color, Point2D};

#[cfg(target_os = "macos")]
enum EngineCommand {
    AttachPresentTexture {
        mtl_texture_ptr: usize,
        width: u32,
        height: u32,
        bytes_per_row: u32,
    },
    ClearLayer { layer_index: u32 },
    Undo,
    Redo,
    Stop,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct EnginePoint {
    pub x: f32,
    pub y: f32,
    pub pressure: f32,
    pub _pad0: f32,
    pub timestamp_us: u64,
    pub flags: u32,
    pub pointer_id: u32,
}

#[cfg(target_os = "macos")]
struct EngineInputBatch {
    points: Vec<EnginePoint>,
}

#[cfg(target_os = "macos")]
struct EngineEntry {
    mtl_device_ptr: usize,
    frame_ready: Arc<AtomicBool>,
    cmd_tx: mpsc::Sender<EngineCommand>,
    input_tx: mpsc::Sender<EngineInputBatch>,
    input_queue_len: Arc<AtomicU64>,
}

#[cfg(target_os = "macos")]
static ENGINES: OnceLock<Mutex<HashMap<u64, EngineEntry>>> = OnceLock::new();
#[cfg(target_os = "macos")]
static NEXT_HANDLE: AtomicU64 = AtomicU64::new(1);

#[cfg(target_os = "macos")]
fn engines() -> &'static Mutex<HashMap<u64, EngineEntry>> {
    ENGINES.get_or_init(|| Mutex::new(HashMap::new()))
}

#[cfg(target_os = "macos")]
struct PresentTarget {
    _texture: wgpu::Texture,
    view: wgpu::TextureView,
    width: u32,
    height: u32,
    _bytes_per_row: u32,
}

#[cfg(target_os = "macos")]
fn spawn_render_thread(
    device: wgpu::Device,
    queue: wgpu::Queue,
    layer_textures: Vec<wgpu::Texture>,
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

#[cfg(target_os = "macos")]
fn render_thread_main(
    device: wgpu::Device,
    queue: wgpu::Queue,
    mut layer_textures: Vec<wgpu::Texture>,
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
    let layer0 = match layer_textures.pop() {
        Some(tex) => tex,
        None => return,
    };

    let mut brush = match BrushRenderer::new(device.clone(), queue.clone()) {
        Ok(renderer) => renderer,
        Err(_) => return,
    };
    brush.set_canvas_size(canvas_width, canvas_height);
    brush.set_softness(0.0);

    let present_renderer = PresentRenderer::new(device.as_ref());
    let layer0_view = layer0.create_view(&wgpu::TextureViewDescriptor::default());
    let present_bind_group = present_renderer.create_bind_group(device.as_ref(), &layer0_view);

    let mut stroke = StrokeResampler::new();

    loop {
        match &present {
            None => match cmd_rx.recv() {
                Ok(cmd) => {
                    if handle_engine_command(
                        device.as_ref(),
                        queue.as_ref(),
                        &frame_ready,
                        &mut present,
                        cmd,
                        &layer0,
                        canvas_width,
                        canvas_height,
                    ) {
                        break;
                    }
                }
                Err(_) => break,
            },
            Some(_) => {
                while let Ok(cmd) = cmd_rx.try_recv() {
                    if handle_engine_command(
                        device.as_ref(),
                        queue.as_ref(),
                        &frame_ready,
                        &mut present,
                        cmd,
                        &layer0,
                        canvas_width,
                        canvas_height,
                    ) {
                        return;
                    }
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

                    let drawn_any = stroke.consume_and_draw(
                        &mut brush,
                        &layer0,
                        raw_points,
                        canvas_width,
                        canvas_height,
                    );

                    if drawn_any {
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
        }

        device.poll(wgpu::Maintain::Poll);
    }
}

#[cfg(target_os = "macos")]
fn handle_engine_command(
    device: &wgpu::Device,
    queue: &wgpu::Queue,
    frame_ready: &Arc<AtomicBool>,
    present: &mut Option<PresentTarget>,
    cmd: EngineCommand,
    layer0: &wgpu::Texture,
    canvas_width: u32,
    canvas_height: u32,
) -> bool {
    match cmd {
        EngineCommand::Stop => return true,
        EngineCommand::AttachPresentTexture {
            mtl_texture_ptr,
            width,
            height,
            bytes_per_row,
        } => {
            if mtl_texture_ptr == 0 || width == 0 || height == 0 {
                *present = None;
                return false;
            }
            *present =
                attach_present_texture(device, mtl_texture_ptr, width, height, bytes_per_row);
            if let Some(target) = present {
                // Clear the present target once so Flutter has a valid initial frame.
                submit_test_clear(device, queue, &target.view, 0, Arc::clone(frame_ready));
                // Also clear layer0 to transparent so the first composite is deterministic.
                clear_r32uint_texture(queue, layer0, canvas_width, canvas_height);
            }
        }
        EngineCommand::ClearLayer { layer_index: _ } => {
            // MVP: single layer only.
            clear_r32uint_texture(queue, layer0, canvas_width, canvas_height);
        }
        EngineCommand::Undo => {}
        EngineCommand::Redo => {}
    }
    false
}

#[cfg(target_os = "macos")]
fn clear_r32uint_texture(
    queue: &wgpu::Queue,
    texture: &wgpu::Texture,
    width: u32,
    height: u32,
) {
    let size_bytes = (width as usize).saturating_mul(height as usize).saturating_mul(4);
    let zeroes = vec![0u8; size_bytes];
    queue.write_texture(
        wgpu::ImageCopyTexture {
            texture,
            mip_level: 0,
            origin: wgpu::Origin3d::ZERO,
            aspect: wgpu::TextureAspect::All,
        },
        &zeroes,
        wgpu::ImageDataLayout {
            offset: 0,
            bytes_per_row: Some(4 * width),
            rows_per_image: Some(height),
        },
        wgpu::Extent3d {
            width,
            height,
            depth_or_array_layers: 1,
        },
    );
}

#[cfg(target_os = "macos")]
struct PresentRenderer {
    pipeline: wgpu::RenderPipeline,
    bind_group_layout: wgpu::BindGroupLayout,
}

#[cfg(target_os = "macos")]
impl PresentRenderer {
    fn new(device: &wgpu::Device) -> Self {
        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("misa-rin present renderer shader"),
            source: wgpu::ShaderSource::Wgsl(Cow::Borrowed(include_str!("canvas_present.wgsl"))),
        });

        let bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("misa-rin present renderer bgl"),
            entries: &[wgpu::BindGroupLayoutEntry {
                binding: 0,
                visibility: wgpu::ShaderStages::FRAGMENT,
                ty: wgpu::BindingType::Texture {
                    sample_type: wgpu::TextureSampleType::Uint,
                    view_dimension: wgpu::TextureViewDimension::D2,
                    multisampled: false,
                },
                count: None,
            }],
        });

        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("misa-rin present renderer pipeline layout"),
            bind_group_layouts: &[&bind_group_layout],
            push_constant_ranges: &[],
        });

        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("misa-rin present renderer pipeline"),
            layout: Some(&pipeline_layout),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: "vs_main",
                buffers: &[],
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: "fs_main",
                targets: &[Some(wgpu::ColorTargetState {
                    format: wgpu::TextureFormat::Bgra8Unorm,
                    blend: None,
                    write_mask: wgpu::ColorWrites::ALL,
                })],
            }),
            primitive: wgpu::PrimitiveState {
                topology: wgpu::PrimitiveTopology::TriangleList,
                strip_index_format: None,
                front_face: wgpu::FrontFace::Ccw,
                cull_mode: None,
                polygon_mode: wgpu::PolygonMode::Fill,
                unclipped_depth: false,
                conservative: false,
            },
            depth_stencil: None,
            multisample: wgpu::MultisampleState::default(),
            multiview: None,
        });

        Self {
            pipeline,
            bind_group_layout,
        }
    }

    fn create_bind_group(
        &self,
        device: &wgpu::Device,
        layer_view: &wgpu::TextureView,
    ) -> wgpu::BindGroup {
        device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("misa-rin present renderer bind group"),
            layout: &self.bind_group_layout,
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: wgpu::BindingResource::TextureView(layer_view),
            }],
        })
    }

    fn render(
        &self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        bind_group: &wgpu::BindGroup,
        present_view: &wgpu::TextureView,
        frame_ready: Arc<AtomicBool>,
    ) {
        let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("misa-rin present renderer encoder"),
        });
        {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("misa-rin present renderer pass"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: present_view,
                    resolve_target: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color::TRANSPARENT),
                        store: wgpu::StoreOp::Store,
                    },
                })],
                depth_stencil_attachment: None,
                timestamp_writes: None,
                occlusion_query_set: None,
            });
            pass.set_pipeline(&self.pipeline);
            pass.set_bind_group(0, bind_group, &[]);
            pass.draw(0..3, 0..1);
        }

        queue.submit(Some(encoder.finish()));
        queue.on_submitted_work_done(move || {
            frame_ready.store(true, Ordering::Release);
        });
    }
}

#[cfg(target_os = "macos")]
struct StrokeResampler {
    last_emitted: Option<Point2D>,
    last_pressure: f32,
    last_tick_dirty: Option<(i32, i32, i32, i32)>,
}

#[cfg(target_os = "macos")]
impl StrokeResampler {
    fn new() -> Self {
        Self {
            last_emitted: None,
            last_pressure: 1.0,
            last_tick_dirty: None,
        }
    }

    fn consume_and_draw(
        &mut self,
        brush: &mut BrushRenderer,
        layer0: &wgpu::Texture,
        points: Vec<EnginePoint>,
        canvas_width: u32,
        canvas_height: u32,
    ) -> bool {
        const FLAG_DOWN: u32 = 1;
        const FLAG_UP: u32 = 4;

        if points.is_empty() {
            self.last_tick_dirty = None;
            return false;
        }

        let mut emitted: Vec<(Point2D, f32)> = Vec::new();

        for p in points {
            let x = if p.x.is_finite() { p.x } else { 0.0 };
            let y = if p.y.is_finite() { p.y } else { 0.0 };
            let pressure = if p.pressure.is_finite() {
                p.pressure.clamp(0.0, 1.0)
            } else {
                0.0
            };

            let is_down = (p.flags & FLAG_DOWN) != 0;
            let is_up = (p.flags & FLAG_UP) != 0;

            let current = Point2D { x, y };
            if is_down || self.last_emitted.is_none() {
                self.last_emitted = Some(current);
                self.last_pressure = pressure;
                emitted.push((current, pressure));
                continue;
            }

            let Some(prev) = self.last_emitted else {
                continue;
            };

            let dx = current.x - prev.x;
            let dy = current.y - prev.y;
            let dist = (dx * dx + dy * dy).sqrt();
            if !dist.is_finite() || dist <= 0.0001 {
                if is_up {
                    emitted.push((current, pressure));
                    self.last_emitted = Some(current);
                    self.last_pressure = pressure;
                }
                continue;
            }

            let radius_prev = brush_radius_from_pressure(self.last_pressure);
            let radius_next = brush_radius_from_pressure(pressure);
            let step = resample_step_from_radius((radius_prev + radius_next) * 0.5);

            let dir_x = dx / dist;
            let dir_y = dy / dist;
            let mut traveled = 0.0f32;

            while traveled + step <= dist {
                traveled += step;
                let t = (traveled / dist).clamp(0.0, 1.0);
                let interp_pressure = self.last_pressure + (pressure - self.last_pressure) * t;
                let sample = Point2D {
                    x: prev.x + dir_x * traveled,
                    y: prev.y + dir_y * traveled,
                };
                emitted.push((sample, interp_pressure));
                self.last_emitted = Some(sample);
                self.last_pressure = interp_pressure;
            }

            if is_up {
                emitted.push((current, pressure));
                self.last_emitted = Some(current);
                self.last_pressure = pressure;
            }
        }

        if emitted.is_empty() {
            self.last_tick_dirty = None;
            return false;
        }

        brush.set_canvas_size(canvas_width, canvas_height);

        let mut dirty_union: Option<(i32, i32, i32, i32)> = None;
        let mut drew_any = false;

        if emitted.len() == 1 {
            let (p0, pres0) = emitted[0];
            let r0 = brush_radius_from_pressure(pres0);
            if brush
                .draw_stroke(
                    layer0,
                    &[p0],
                    &[r0],
                    Color { argb: 0xFFFFFFFF },
                    BrushShape::Circle,
                    false,
                    1,
                )
                .is_ok()
            {
                drew_any = true;
                dirty_union = union_dirty_rect_i32(
                    dirty_union,
                    compute_dirty_rect_i32(&[p0], &[r0], canvas_width, canvas_height),
                );
            }
        } else {
            for i in 0..emitted.len().saturating_sub(1) {
                let (p0, pres0) = emitted[i];
                let (p1, pres1) = emitted[i + 1];
                let r0 = brush_radius_from_pressure(pres0);
                let r1 = brush_radius_from_pressure(pres1);
                let pts = [p0, p1];
                let radii = [r0, r1];
                if brush
                    .draw_stroke(
                        layer0,
                        &pts,
                        &radii,
                        Color { argb: 0xFFFFFFFF },
                        BrushShape::Circle,
                        false,
                        1,
                    )
                    .is_ok()
                {
                    drew_any = true;
                    dirty_union = union_dirty_rect_i32(
                        dirty_union,
                        compute_dirty_rect_i32(&pts, &radii, canvas_width, canvas_height),
                    );
                }
            }
        }

        self.last_tick_dirty = dirty_union;
        drew_any
    }
}

#[cfg(target_os = "macos")]
fn brush_radius_from_pressure(pressure: f32) -> f32 {
    let p = if pressure.is_finite() {
        pressure.clamp(0.0, 1.0)
    } else {
        0.0
    };
    6.0 * (0.25 + 0.75 * p)
}

#[cfg(target_os = "macos")]
fn resample_step_from_radius(radius: f32) -> f32 {
    let r = if radius.is_finite() { radius.max(0.0) } else { 0.0 };
    (r * 0.1).clamp(0.25, 0.5)
}

#[cfg(target_os = "macos")]
fn compute_dirty_rect_i32(
    points: &[Point2D],
    radii: &[f32],
    canvas_width: u32,
    canvas_height: u32,
) -> (i32, i32, i32, i32) {
    if canvas_width == 0 || canvas_height == 0 || points.is_empty() || points.len() != radii.len()
    {
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
    let left = ((min_x - pad).floor() as i64).clamp(0, canvas_width as i64);
    let top = ((min_y - pad).floor() as i64).clamp(0, canvas_height as i64);
    let right = ((max_x + pad).ceil() as i64).clamp(0, canvas_width as i64);
    let bottom = ((max_y + pad).ceil() as i64).clamp(0, canvas_height as i64);

    let width = (right - left).max(0) as i32;
    let height = (bottom - top).max(0) as i32;
    (left as i32, top as i32, width, height)
}

#[cfg(target_os = "macos")]
fn union_dirty_rect_i32(
    existing: Option<(i32, i32, i32, i32)>,
    candidate: (i32, i32, i32, i32),
) -> Option<(i32, i32, i32, i32)> {
    let (cl, ct, cw, ch) = candidate;
    if cw <= 0 || ch <= 0 {
        return existing;
    }
    let Some((el, et, ew, eh)) = existing else {
        return Some(candidate);
    };
    if ew <= 0 || eh <= 0 {
        return Some(candidate);
    }

    let el64 = el as i64;
    let et64 = et as i64;
    let er64 = el64 + ew as i64;
    let eb64 = et64 + eh as i64;

    let cl64 = cl as i64;
    let ct64 = ct as i64;
    let cr64 = cl64 + cw as i64;
    let cb64 = ct64 + ch as i64;

    let left = el64.min(cl64);
    let top = et64.min(ct64);
    let right = er64.max(cr64);
    let bottom = eb64.max(cb64);

    let width = (right - left).max(0) as i32;
    let height = (bottom - top).max(0) as i32;
    Some((left as i32, top as i32, width, height))
}

#[cfg(target_os = "macos")]
fn attach_present_texture(
    device: &wgpu::Device,
    mtl_texture_ptr: usize,
    width: u32,
    height: u32,
    bytes_per_row: u32,
) -> Option<PresentTarget> {
    let raw_ptr = mtl_texture_ptr as *mut metal::MTLTexture;
    if raw_ptr.is_null() {
        return None;
    }

    let raw_texture = unsafe { metal::Texture::from_ptr(raw_ptr) };
    let hal_texture = unsafe {
        wgpu_hal::metal::Device::texture_from_raw(
            raw_texture,
            wgpu::TextureFormat::Bgra8Unorm,
            MTLTextureType::D2,
            1,
            1,
            CopyExtent {
                width,
                height,
                depth: 1,
            },
        )
    };

    let desc = wgpu::TextureDescriptor {
        label: Some("misa-rin present texture (external MTLTexture)"),
        size: wgpu::Extent3d {
            width,
            height,
            depth_or_array_layers: 1,
        },
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format: wgpu::TextureFormat::Bgra8Unorm,
        usage: wgpu::TextureUsages::RENDER_ATTACHMENT | wgpu::TextureUsages::TEXTURE_BINDING,
        view_formats: &[],
    };

    let texture = unsafe { device.create_texture_from_hal::<Metal>(hal_texture, &desc) };
    let view = texture.create_view(&wgpu::TextureViewDescriptor::default());

    Some(PresentTarget {
        _texture: texture,
        view,
        width,
        height,
        _bytes_per_row: bytes_per_row,
    })
}

#[cfg(target_os = "macos")]
fn submit_test_clear(
    device: &wgpu::Device,
    queue: &wgpu::Queue,
    view: &wgpu::TextureView,
    _frame_index: u64,
    frame_ready: Arc<AtomicBool>,
) {
    let (r, g, b, a) = (0.0, 0.0, 0.0, 0.0);

    let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
        label: Some("misa-rin present clear encoder"),
    });
    {
        let _pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            label: Some("misa-rin present clear pass"),
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view,
                resolve_target: None,
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Clear(wgpu::Color {
                        r,
                        g,
                        b,
                        a,
                    }),
                    store: wgpu::StoreOp::Store,
                },
            })],
            depth_stencil_attachment: None,
            timestamp_writes: None,
            occlusion_query_set: None,
        });
    }

    queue.submit(Some(encoder.finish()));
    queue.on_submitted_work_done(move || {
        frame_ready.store(true, Ordering::Release);
    });
}

#[cfg(target_os = "macos")]
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

#[cfg(target_os = "macos")]
fn create_engine(width: u32, height: u32) -> Result<u64, String> {
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

    let (device, queue) = pollster::block_on(adapter.request_device(
        &wgpu::DeviceDescriptor {
            label: Some("misa-rin CanvasEngine device"),
            required_features: wgpu::Features::empty(),
            required_limits: wgpu::Limits::default(),
        },
        None,
    ))
    .map_err(|e| format!("wgpu: request_device failed: {e:?}"))?;

    let mtl_device_ptr = mtl_device_ptr(&device) as usize;
    if mtl_device_ptr == 0 {
        return Err("wgpu: failed to extract underlying MTLDevice".to_string());
    }

    let layer0 = device.create_texture(&wgpu::TextureDescriptor {
        label: Some("misa-rin layer0 (R32Uint)"),
        size: wgpu::Extent3d {
            width,
            height,
            depth_or_array_layers: 1,
        },
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format: wgpu::TextureFormat::R32Uint,
        usage: wgpu::TextureUsages::TEXTURE_BINDING
            | wgpu::TextureUsages::COPY_DST
            | wgpu::TextureUsages::COPY_SRC
            | wgpu::TextureUsages::STORAGE_BINDING,
        view_formats: &[],
    });

    let (cmd_tx, cmd_rx) = mpsc::channel();
    let (input_tx, input_rx) = mpsc::channel();
    let input_queue_len = Arc::new(AtomicU64::new(0));
    let frame_ready = Arc::new(AtomicBool::new(false));
    spawn_render_thread(
        device,
        queue,
        vec![layer0],
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

#[cfg(target_os = "macos")]
fn lookup_engine(handle: u64) -> Option<EngineEntry> {
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

#[cfg(target_os = "macos")]
fn remove_engine(handle: u64) -> Option<EngineEntry> {
    if handle == 0 {
        return None;
    }
    let mut guard = engines().lock().ok()?;
    guard.remove(&handle)
}

#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn engine_create(width: u32, height: u32) -> u64 {
    create_engine(width, height).unwrap_or(0)
}

#[cfg(not(target_os = "macos"))]
#[no_mangle]
pub extern "C" fn engine_create(_width: u32, _height: u32) -> u64 {
    0
}

#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn engine_get_mtl_device(handle: u64) -> *mut c_void {
    lookup_engine(handle)
        .map(|entry| entry.mtl_device_ptr as *mut c_void)
        .unwrap_or(std::ptr::null_mut())
}

#[cfg(not(target_os = "macos"))]
#[no_mangle]
pub extern "C" fn engine_get_mtl_device(_handle: u64) -> *mut c_void {
    std::ptr::null_mut()
}

#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn engine_attach_present_texture(
    handle: u64,
    mtl_texture_ptr: *mut c_void,
    width: u32,
    height: u32,
    bytes_per_row: u32,
) {
    let Some(entry) = lookup_engine(handle) else {
        return;
    };
    let _ = entry.cmd_tx.send(EngineCommand::AttachPresentTexture {
        mtl_texture_ptr: mtl_texture_ptr as usize,
        width,
        height,
        bytes_per_row,
    });
}

#[cfg(not(target_os = "macos"))]
#[no_mangle]
pub extern "C" fn engine_attach_present_texture(
    _handle: u64,
    _mtl_texture_ptr: *mut c_void,
    _width: u32,
    _height: u32,
    _bytes_per_row: u32,
) {
}

#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn engine_dispose(handle: u64) {
    let Some(entry) = remove_engine(handle) else {
        return;
    };
    let _ = entry.cmd_tx.send(EngineCommand::Stop);
}

#[cfg(not(target_os = "macos"))]
#[no_mangle]
pub extern "C" fn engine_dispose(_handle: u64) {}

#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn engine_poll_frame_ready(handle: u64) -> bool {
    let Some(entry) = lookup_engine(handle) else {
        return false;
    };
    entry.frame_ready.swap(false, Ordering::AcqRel)
}

#[cfg(not(target_os = "macos"))]
#[no_mangle]
pub extern "C" fn engine_poll_frame_ready(_handle: u64) -> bool {
    false
}

#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn engine_push_points(handle: u64, points: *const EnginePoint, len: usize) {
    let Some(entry) = lookup_engine(handle) else {
        return;
    };
    if points.is_null() || len == 0 {
        return;
    }
    let slice = unsafe { std::slice::from_raw_parts(points, len) };
    let mut owned: Vec<EnginePoint> = Vec::with_capacity(len);
    owned.extend_from_slice(slice);
    entry.input_queue_len.fetch_add(len as u64, Ordering::Relaxed);
    if entry.input_tx.send(EngineInputBatch { points: owned }).is_err() {
        entry.input_queue_len.fetch_sub(len as u64, Ordering::Relaxed);
    }
}

#[cfg(not(target_os = "macos"))]
#[no_mangle]
pub extern "C" fn engine_push_points(_handle: u64, _points: *const EnginePoint, _len: usize) {}

#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn engine_get_input_queue_len(handle: u64) -> u64 {
    lookup_engine(handle)
        .map(|entry| entry.input_queue_len.load(Ordering::Relaxed))
        .unwrap_or(0)
}

#[cfg(not(target_os = "macos"))]
#[no_mangle]
pub extern "C" fn engine_get_input_queue_len(_handle: u64) -> u64 {
    0
}
