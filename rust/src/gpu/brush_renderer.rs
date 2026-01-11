use std::borrow::Cow;
use std::sync::Arc;

use wgpu::{ComputePipeline, Device, Queue};

#[derive(Debug, Clone, Copy)]
pub struct Point2D {
    pub x: f32,
    pub y: f32,
}

#[derive(Debug, Clone, Copy)]
pub struct Color {
    pub argb: u32,
}

#[derive(Debug, Clone, Copy)]
pub enum BrushShape {
    Circle,
    Square,
}

#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
struct ShaderStrokePoint {
    pos: [f32; 2],
    radius: f32,
    _pad0: f32,
}

#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
struct BrushShaderConfig {
    canvas_width: u32,
    canvas_height: u32,
    origin_x: u32,
    origin_y: u32,
    region_width: u32,
    region_height: u32,
    point_count: u32,
    brush_shape: u32,
    erase_mode: u32,
    antialias_level: u32,
    color_argb: u32,
    softness: f32,
    _pad0: u32,
    _pad1: u32,
}

#[derive(Debug, Clone, Copy)]
struct DirtyRect {
    origin_x: u32,
    origin_y: u32,
    width: u32,
    height: u32,
}

const WORKGROUP_SIZE: u32 = 16;
const MAX_POINTS: usize = 8192;

pub struct BrushRenderer {
    device: Arc<Device>,
    queue: Arc<Queue>,
    pipeline: ComputePipeline,

    bind_group_layout: wgpu::BindGroupLayout,
    uniform_buffer: wgpu::Buffer,
    points_buffer: Option<wgpu::Buffer>,
    points_capacity: usize,

    canvas_width: u32,
    canvas_height: u32,
    softness: f32,
}

impl BrushRenderer {
    pub fn new(device: Arc<Device>, queue: Arc<Queue>) -> Result<Self, String> {
        device_push_scopes(device.as_ref());

        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("BrushRenderer shader"),
            source: wgpu::ShaderSource::Wgsl(Cow::Borrowed(include_str!("brush_shaders.wgsl"))),
        });

        let bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("BrushRenderer bind group layout"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::COMPUTE,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Storage { read_only: true },
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 1,
                    visibility: wgpu::ShaderStages::COMPUTE,
                    ty: wgpu::BindingType::StorageTexture {
                        access: wgpu::StorageTextureAccess::ReadWrite,
                        format: wgpu::TextureFormat::R32Uint,
                        view_dimension: wgpu::TextureViewDimension::D2,
                    },
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 2,
                    visibility: wgpu::ShaderStages::COMPUTE,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                },
            ],
        });

        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("BrushRenderer pipeline layout"),
            bind_group_layouts: &[&bind_group_layout],
            push_constant_ranges: &[],
        });

        let pipeline = device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
            label: Some("BrushRenderer compute pipeline"),
            layout: Some(&pipeline_layout),
            module: &shader,
            entry_point: "draw_brush_stroke",
        });

        let uniform_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("BrushRenderer uniform buffer"),
            size: std::mem::size_of::<BrushShaderConfig>() as u64,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        if let Some(err) = device_pop_scope(device.as_ref()) {
            return Err(format!("wgpu validation error during brush init: {err}"));
        }
        if let Some(err) = device_pop_scope(device.as_ref()) {
            return Err(format!("wgpu out-of-memory error during brush init: {err}"));
        }

        Ok(Self {
            device,
            queue,
            pipeline,
            bind_group_layout,
            uniform_buffer,
            points_buffer: None,
            points_capacity: 0,
            canvas_width: 0,
            canvas_height: 0,
            softness: 0.0,
        })
    }

    pub fn set_canvas_size(&mut self, width: u32, height: u32) {
        self.canvas_width = width;
        self.canvas_height = height;
    }

    pub fn set_softness(&mut self, softness: f32) {
        self.softness = if softness.is_finite() {
            softness.clamp(0.0, 1.0)
        } else {
            0.0
        };
    }

    pub fn draw_stroke(
        &mut self,
        layer_texture: &wgpu::Texture,
        points: &[Point2D],
        radii: &[f32],
        color: Color,
        brush_shape: BrushShape,
        erase: bool,
        antialias_level: u32,
    ) -> Result<(), String> {
        if points.is_empty() {
            return Ok(());
        }
        if points.len() != radii.len() {
            return Err(format!(
                "points/radii length mismatch: {} vs {}",
                points.len(),
                radii.len()
            ));
        }
        if points.len() > MAX_POINTS {
            return Err(format!("too many stroke points: {} (max {MAX_POINTS})", points.len()));
        }
        if self.canvas_width == 0 || self.canvas_height == 0 {
            return Err("brush renderer canvas size not set".to_string());
        }

        let dirty = compute_dirty_rect(points, radii, self.canvas_width, self.canvas_height)?;
        if dirty.width == 0 || dirty.height == 0 {
            return Ok(());
        }

        self.ensure_points_buffer(points.len())?;
        let points_buffer = self
            .points_buffer
            .as_ref()
            .ok_or_else(|| "wgpu points buffer not initialized".to_string())?;

        let mut shader_points: Vec<ShaderStrokePoint> = Vec::with_capacity(points.len());
        for (p, &r) in points.iter().zip(radii.iter()) {
            let radius = if r.is_finite() { r.max(0.0) } else { 0.0 };
            shader_points.push(ShaderStrokePoint {
                pos: [finite_f32(p.x), finite_f32(p.y)],
                radius,
                _pad0: 0.0,
            });
        }

        self.queue
            .write_buffer(points_buffer, 0, bytemuck::cast_slice(&shader_points));

        let config = BrushShaderConfig {
            canvas_width: self.canvas_width,
            canvas_height: self.canvas_height,
            origin_x: dirty.origin_x,
            origin_y: dirty.origin_y,
            region_width: dirty.width,
            region_height: dirty.height,
            point_count: shader_points.len() as u32,
            brush_shape: match brush_shape {
                BrushShape::Circle => 0,
                BrushShape::Square => 1,
            },
            erase_mode: if erase { 1 } else { 0 },
            antialias_level: antialias_level.clamp(0, 3),
            color_argb: color.argb,
            softness: self.softness,
            _pad0: 0,
            _pad1: 0,
        };
        self.queue
            .write_buffer(&self.uniform_buffer, 0, bytemuck::bytes_of(&config));

        let view = layer_texture.create_view(&wgpu::TextureViewDescriptor::default());
        let bind_group = self.device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("BrushRenderer bind group"),
            layout: &self.bind_group_layout,
            entries: &[
                wgpu::BindGroupEntry {
                    binding: 0,
                    resource: points_buffer.as_entire_binding(),
                },
                wgpu::BindGroupEntry {
                    binding: 1,
                    resource: wgpu::BindingResource::TextureView(&view),
                },
                wgpu::BindGroupEntry {
                    binding: 2,
                    resource: self.uniform_buffer.as_entire_binding(),
                },
            ],
        });

        device_push_scopes(self.device.as_ref());

        let mut encoder = self
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("BrushRenderer encoder"),
            });
        {
            let mut pass = encoder.begin_compute_pass(&wgpu::ComputePassDescriptor {
                label: Some("BrushRenderer pass"),
                timestamp_writes: None,
            });
            pass.set_pipeline(&self.pipeline);
            pass.set_bind_group(0, &bind_group, &[]);
            let wg_x = (dirty.width + (WORKGROUP_SIZE - 1)) / WORKGROUP_SIZE;
            let wg_y = (dirty.height + (WORKGROUP_SIZE - 1)) / WORKGROUP_SIZE;
            pass.dispatch_workgroups(wg_x, wg_y, 1);
        }

        self.queue.submit(Some(encoder.finish()));

        if let Some(err) = device_pop_scope(self.device.as_ref()) {
            return Err(format!("wgpu validation error during brush draw: {err}"));
        }
        if let Some(err) = device_pop_scope(self.device.as_ref()) {
            return Err(format!("wgpu out-of-memory error during brush draw: {err}"));
        }

        Ok(())
    }

    fn ensure_points_buffer(&mut self, point_count: usize) -> Result<(), String> {
        let required_bytes: u64 = (point_count as u64)
            .checked_mul(std::mem::size_of::<ShaderStrokePoint>() as u64)
            .ok_or_else(|| "points buffer size overflow".to_string())?;

        if self.points_buffer.is_some()
            && point_count <= self.points_capacity
            && required_bytes <= self.device.limits().max_buffer_size
        {
            return Ok(());
        }

        let max_buffer_size = self.device.limits().max_buffer_size;
        let max_storage_binding_size = self.device.limits().max_storage_buffer_binding_size as u64;
        if required_bytes > max_buffer_size {
            return Err(format!(
                "stroke points buffer too large: {required_bytes} bytes (device max {max_buffer_size})"
            ));
        }
        if required_bytes > max_storage_binding_size {
            return Err(format!(
                "stroke points binding too large: {required_bytes} bytes (storage binding max {max_storage_binding_size})"
            ));
        }

        device_push_scopes(self.device.as_ref());

        let buffer = self.device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("BrushRenderer stroke points buffer"),
            size: required_bytes,
            usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        if let Some(err) = device_pop_scope(self.device.as_ref()) {
            return Err(format!(
                "wgpu validation error during brush buffer alloc: {err}"
            ));
        }
        if let Some(err) = device_pop_scope(self.device.as_ref()) {
            return Err(format!(
                "wgpu out-of-memory error during brush buffer alloc: {err}"
            ));
        }

        self.points_buffer = Some(buffer);
        self.points_capacity = point_count;
        Ok(())
    }
}

fn compute_dirty_rect(
    points: &[Point2D],
    radii: &[f32],
    canvas_width: u32,
    canvas_height: u32,
) -> Result<DirtyRect, String> {
    if canvas_width == 0 || canvas_height == 0 {
        return Ok(DirtyRect {
            origin_x: 0,
            origin_y: 0,
            width: 0,
            height: 0,
        });
    }
    if points.is_empty() || points.len() != radii.len() {
        return Ok(DirtyRect {
            origin_x: 0,
            origin_y: 0,
            width: 0,
            height: 0,
        });
    }

    let mut min_x: f32 = f32::INFINITY;
    let mut min_y: f32 = f32::INFINITY;
    let mut max_x: f32 = f32::NEG_INFINITY;
    let mut max_y: f32 = f32::NEG_INFINITY;
    let mut max_r: f32 = 0.0;

    for (p, &r) in points.iter().zip(radii.iter()) {
        let x = finite_f32(p.x);
        let y = finite_f32(p.y);
        let radius = if r.is_finite() { r.max(0.0) } else { 0.0 };
        if x < min_x {
            min_x = x;
        }
        if y < min_y {
            min_y = y;
        }
        if x > max_x {
            max_x = x;
        }
        if y > max_y {
            max_y = y;
        }
        if radius > max_r {
            max_r = radius;
        }
    }

    if !min_x.is_finite() || !min_y.is_finite() || !max_x.is_finite() || !max_y.is_finite() {
        return Ok(DirtyRect {
            origin_x: 0,
            origin_y: 0,
            width: 0,
            height: 0,
        });
    }

    let pad: f32 = max_r + 2.0;
    let left = ((min_x - pad).floor() as i64).clamp(0, canvas_width as i64);
    let top = ((min_y - pad).floor() as i64).clamp(0, canvas_height as i64);
    let right = ((max_x + pad).ceil() as i64).clamp(0, canvas_width as i64);
    let bottom = ((max_y + pad).ceil() as i64).clamp(0, canvas_height as i64);

    let width = (right - left).max(0) as u32;
    let height = (bottom - top).max(0) as u32;
    Ok(DirtyRect {
        origin_x: left as u32,
        origin_y: top as u32,
        width,
        height,
    })
}

fn finite_f32(value: f32) -> f32 {
    if value.is_finite() {
        value
    } else {
        0.0
    }
}

fn device_push_scopes(device: &wgpu::Device) {
    device.push_error_scope(wgpu::ErrorFilter::OutOfMemory);
    device.push_error_scope(wgpu::ErrorFilter::Validation);
}

fn device_pop_scope(device: &wgpu::Device) -> Option<wgpu::Error> {
    pollster::block_on(device.pop_error_scope())
}
