use std::borrow::Cow;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

#[cfg(target_os = "macos")]
use metal::foreign_types::ForeignType;
#[cfg(target_os = "macos")]
use metal::MTLTextureType;
#[cfg(target_os = "macos")]
use wgpu_hal::{api::Metal, CopyExtent};

pub(crate) struct PresentTarget {
    _texture: wgpu::Texture,
    pub(crate) view: wgpu::TextureView,
    pub(crate) width: u32,
    pub(crate) height: u32,
    _bytes_per_row: u32,
}

impl PresentTarget {
    pub(crate) fn texture(&self) -> &wgpu::Texture {
        &self._texture
    }
}

pub(crate) struct PresentRenderer {
    pipeline: wgpu::RenderPipeline,
    bind_group_layout: wgpu::BindGroupLayout,
}

#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
pub(crate) struct PresentCompositeHeader {
    layer_count: u32,
    view_flags: u32,
    transform_layer: u32,
    transform_flags: u32,
}

#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
struct PresentLayerParams {
    opacity: f32,
    visible: f32,
    clipping_mask: f32,
    blend_mode: u32,
}

#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
pub(crate) struct PresentTransformConfig {
    matrix: [f32; 16],
}

pub(crate) fn write_present_config(
    queue: &wgpu::Queue,
    header_buffer: &wgpu::Buffer,
    params_buffer: &wgpu::Buffer,
    layer_count: usize,
    view_flags: u32,
    transform_layer: u32,
    transform_flags: u32,
    layer_opacity: &[f32],
    layer_visible: &[bool],
    layer_clipping_mask: &[bool],
    layer_blend_mode: &[u32],
) {
    let header = PresentCompositeHeader {
        layer_count: layer_count as u32,
        view_flags,
        transform_layer,
        transform_flags,
    };
    queue.write_buffer(header_buffer, 0, bytemuck::bytes_of(&header));

    if layer_count == 0 {
        return;
    }

    let mut params: Vec<PresentLayerParams> = Vec::with_capacity(layer_count);
    for i in 0..layer_count {
        let raw_opacity = layer_opacity.get(i).copied().unwrap_or(1.0);
        let opacity = if raw_opacity.is_finite() {
            raw_opacity.clamp(0.0, 1.0)
        } else {
            0.0
        };
        let visible = if *layer_visible.get(i).unwrap_or(&true) {
            1.0
        } else {
            0.0
        };
        let clipping_mask = if *layer_clipping_mask.get(i).unwrap_or(&false) {
            1.0
        } else {
            0.0
        };
        let blend_mode = layer_blend_mode.get(i).copied().unwrap_or(0);
        params.push(PresentLayerParams {
            opacity,
            visible,
            clipping_mask,
            blend_mode,
        });
    }
    queue.write_buffer(params_buffer, 0, bytemuck::cast_slice(&params));
}

pub(crate) fn write_present_transform(
    queue: &wgpu::Queue,
    buffer: &wgpu::Buffer,
    matrix: [f32; 16],
) {
    let config = PresentTransformConfig { matrix };
    queue.write_buffer(buffer, 0, bytemuck::bytes_of(&config));
}

pub(crate) fn create_present_transform_buffer(device: &wgpu::Device) -> wgpu::Buffer {
    device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("misa-rin present transform config"),
        size: std::mem::size_of::<PresentTransformConfig>() as u64,
        usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
        mapped_at_creation: false,
    })
}

pub(crate) fn create_present_params_buffer(
    device: &wgpu::Device,
    capacity: usize,
) -> Result<wgpu::Buffer, String> {
    let size = capacity
        .checked_mul(std::mem::size_of::<PresentLayerParams>())
        .ok_or_else(|| "layer params buffer size overflow".to_string())?;
    let max_storage_binding = device.limits().max_storage_buffer_binding_size as u64;
    let max_buffer_size = device.limits().max_buffer_size;
    if (size as u64) > max_buffer_size {
        return Err(format!(
            "layer params buffer too large: {size} bytes (max {max_buffer_size})"
        ));
    }
    if (size as u64) > max_storage_binding {
        return Err(format!(
            "layer params buffer too large: {size} bytes (max {max_storage_binding})"
        ));
    }
    Ok(device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("misa-rin present layer params"),
        size: size as u64,
        usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_DST,
        mapped_at_creation: false,
    }))
}

impl PresentRenderer {
    pub(crate) fn new(device: &wgpu::Device) -> Self {
        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("misa-rin present renderer shader"),
            source: wgpu::ShaderSource::Wgsl(Cow::Borrowed(include_str!("../canvas_present.wgsl"))),
        });

        let bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("misa-rin present renderer bgl"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Texture {
                        sample_type: wgpu::TextureSampleType::Uint,
                        view_dimension: wgpu::TextureViewDimension::D2Array,
                        multisampled: false,
                    },
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 1,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: wgpu::BufferSize::new(std::mem::size_of::<
                            PresentCompositeHeader,
                        >() as u64),
                    },
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 2,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Storage { read_only: true },
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 3,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: wgpu::BufferSize::new(std::mem::size_of::<
                            PresentTransformConfig,
                        >() as u64),
                    },
                    count: None,
                },
            ],
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

    pub(crate) fn create_bind_group(
        &self,
        device: &wgpu::Device,
        layer_view: &wgpu::TextureView,
        config_buffer: &wgpu::Buffer,
        params_buffer: &wgpu::Buffer,
        transform_buffer: &wgpu::Buffer,
    ) -> wgpu::BindGroup {
        device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("misa-rin present renderer bind group"),
            layout: &self.bind_group_layout,
            entries: &[
                wgpu::BindGroupEntry {
                    binding: 0,
                    resource: wgpu::BindingResource::TextureView(layer_view),
                },
                wgpu::BindGroupEntry {
                    binding: 1,
                    resource: config_buffer.as_entire_binding(),
                },
                wgpu::BindGroupEntry {
                    binding: 2,
                    resource: params_buffer.as_entire_binding(),
                },
                wgpu::BindGroupEntry {
                    binding: 3,
                    resource: transform_buffer.as_entire_binding(),
                },
            ],
        })
    }

    pub(crate) fn render(
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

pub(crate) fn attach_present_texture(
    device: &wgpu::Device,
    mtl_texture_ptr: usize,
    width: u32,
    height: u32,
    bytes_per_row: u32,
) -> Option<PresentTarget> {
    #[cfg(not(target_os = "macos"))]
    {
        let _ = (mtl_texture_ptr, bytes_per_row);
        if width == 0 || height == 0 {
            return None;
        }
        let texture = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("misa-rin present texture (internal)"),
            size: wgpu::Extent3d {
                width,
                height,
                depth_or_array_layers: 1,
            },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: wgpu::TextureFormat::Bgra8Unorm,
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT
                | wgpu::TextureUsages::TEXTURE_BINDING
                | wgpu::TextureUsages::COPY_SRC,
            view_formats: &[],
        });
        let view = texture.create_view(&wgpu::TextureViewDescriptor::default());
        let bytes_per_row = width.saturating_mul(4);
        return Some(PresentTarget {
            _texture: texture,
            view,
            width,
            height,
            _bytes_per_row: bytes_per_row,
        });
    }
    #[cfg(target_os = "macos")]
    let raw_ptr = mtl_texture_ptr as *mut metal::MTLTexture;
    if raw_ptr.is_null() {
        return None;
    }

    // Use ForeignTypeRef logic to avoid taking ownership if possible,
    // or ensure we clone it properly.
    // metal::Texture::from_ptr wraps it.
    // In metal-rs 0.24+, from_ptr calls objc_retain.
    // So dropping it will call release. This is correct if we want to share ownership.
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
