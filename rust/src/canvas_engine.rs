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
use crate::gpu::debug::{self, LogLevel};

#[cfg(target_os = "macos")]
const INITIAL_LAYER_CAPACITY: usize = 4;
#[cfg(target_os = "macos")]
const VIEW_FLAG_MIRROR: u32 = 1;
#[cfg(target_os = "macos")]
const VIEW_FLAG_BLACK_WHITE: u32 = 2;

#[cfg(target_os = "macos")]
enum EngineCommand {
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

#[cfg(target_os = "macos")]
#[derive(Clone, Copy, Debug)]
struct EngineBrushSettings {
    color_argb: u32,
    base_radius: f32,
    use_pressure: bool,
    erase: bool,
    antialias_level: u32,
    shape: BrushShape,
    random_rotation: bool,
    rotation_seed: u32,
    hollow_enabled: bool,
    hollow_ratio: f32,
    hollow_erase_occluded: bool,
}

#[cfg(target_os = "macos")]
impl Default for EngineBrushSettings {
    fn default() -> Self {
        Self {
            color_argb: 0xFFFFFFFF,
            base_radius: 6.0,
            use_pressure: true,
            erase: false,
            antialias_level: 1,
            shape: BrushShape::Circle,
            random_rotation: false,
            rotation_seed: 0,
            hollow_enabled: false,
            hollow_ratio: 0.0,
            hollow_erase_occluded: false,
        }
    }
}

#[cfg(target_os = "macos")]
impl EngineBrushSettings {
    fn sanitize(&mut self) {
        if !self.base_radius.is_finite() {
            self.base_radius = 0.0;
        }
        if self.base_radius < 0.0 {
            self.base_radius = 0.0;
        }
        if !self.hollow_ratio.is_finite() {
            self.hollow_ratio = 0.0;
        } else {
            self.hollow_ratio = self.hollow_ratio.clamp(0.0, 1.0);
        }
        self.antialias_level = self.antialias_level.clamp(0, 3);
    }

    fn radius_from_pressure(&self, pressure: f32) -> f32 {
        brush_radius_from_pressure(pressure, self.base_radius, self.use_pressure)
    }
}

#[cfg(target_os = "macos")]
const UNDO_TILE_SIZE: u32 = 256;

#[cfg(target_os = "macos")]
const UNDO_STACK_LIMIT: usize = 50;

#[cfg(target_os = "macos")]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
struct UndoTileKey {
    tx: u32,
    ty: u32,
    layer_index: u32,
}

#[cfg(target_os = "macos")]
#[derive(Clone, Copy, Debug)]
struct UndoTileRect {
    left: u32,
    top: u32,
    width: u32,
    height: u32,
}

#[cfg(target_os = "macos")]
struct UndoTileBefore {
    rect: UndoTileRect,
    before: wgpu::Texture,
}

#[cfg(target_os = "macos")]
struct UndoTilePatch {
    rect: UndoTileRect,
    before: wgpu::Texture,
    after: wgpu::Texture,
}

#[cfg(target_os = "macos")]
struct UndoRecord {
    layer_index: u32,
    tiles: Vec<UndoTilePatch>,
}

#[cfg(target_os = "macos")]
struct ActiveStrokeUndo {
    layer_index: u32,
    tiles: HashMap<UndoTileKey, UndoTileBefore>,
}

#[cfg(target_os = "macos")]
struct UndoManager {
    canvas_width: u32,
    canvas_height: u32,
    tile_size: u32,
    max_steps: usize,
    undo_stack: Vec<UndoRecord>,
    redo_stack: Vec<UndoRecord>,
    current: Option<ActiveStrokeUndo>,
}

#[cfg(target_os = "macos")]
impl UndoManager {
    fn new(canvas_width: u32, canvas_height: u32) -> Self {
        Self {
            canvas_width,
            canvas_height,
            tile_size: UNDO_TILE_SIZE,
            max_steps: UNDO_STACK_LIMIT,
            undo_stack: Vec::new(),
            redo_stack: Vec::new(),
            current: None,
        }
    }

    fn begin_stroke(&mut self, layer_index: u32) {
        self.current = Some(ActiveStrokeUndo {
            layer_index,
            tiles: HashMap::new(),
        });
    }

    fn begin_stroke_if_needed(&mut self, layer_index: u32) {
        if self.current.is_none() {
            self.begin_stroke(layer_index);
        }
    }

    fn cancel_stroke(&mut self) {
        self.current = None;
    }

    fn reset(&mut self) {
        self.undo_stack.clear();
        self.redo_stack.clear();
        self.current = None;
    }

    fn capture_before_for_dirty_rect(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        layer_texture: &wgpu::Texture,
        layer_index: u32,
        dirty: (i32, i32, i32, i32),
    ) {
        let canvas_width = self.canvas_width;
        let canvas_height = self.canvas_height;
        let tile_size = self.tile_size.max(1);

        let Some(active) = self.current.as_mut() else {
            return;
        };
        if active.layer_index != layer_index {
            return;
        }
        let (left_i, top_i, width_i, height_i) = dirty;
        if width_i <= 0 || height_i <= 0 {
            return;
        }

        let left = (left_i.max(0) as u32).min(canvas_width);
        let top = (top_i.max(0) as u32).min(canvas_height);
        let right = (left_i.saturating_add(width_i).max(0) as u32).min(canvas_width);
        let bottom = (top_i.saturating_add(height_i).max(0) as u32).min(canvas_height);
        if right <= left || bottom <= top {
            return;
        }

        let tx0 = left / tile_size;
        let ty0 = top / tile_size;
        let tx1 = right.saturating_sub(1) / tile_size;
        let ty1 = bottom.saturating_sub(1) / tile_size;

        let mut encoder: Option<wgpu::CommandEncoder> = None;

        for ty in ty0..=ty1 {
            for tx in tx0..=tx1 {
                let key = UndoTileKey {
                    tx,
                    ty,
                    layer_index,
                };
                if active.tiles.contains_key(&key) {
                    continue;
                }
                let tile_left = tx.saturating_mul(tile_size);
                let tile_top = ty.saturating_mul(tile_size);
                if tile_left >= canvas_width || tile_top >= canvas_height {
                    continue;
                }
                let tile_width = tile_size.min(canvas_width.saturating_sub(tile_left));
                let tile_height = tile_size.min(canvas_height.saturating_sub(tile_top));
                if tile_width == 0 || tile_height == 0 {
                    continue;
                }
                let rect = UndoTileRect {
                    left: tile_left,
                    top: tile_top,
                    width: tile_width,
                    height: tile_height,
                };

                let before_tex = device.create_texture(&wgpu::TextureDescriptor {
                    label: Some("misa-rin undo before (tile)"),
                    size: wgpu::Extent3d {
                        width: rect.width,
                        height: rect.height,
                        depth_or_array_layers: 1,
                    },
                    mip_level_count: 1,
                    sample_count: 1,
                    dimension: wgpu::TextureDimension::D2,
                    format: wgpu::TextureFormat::R32Uint,
                    usage: wgpu::TextureUsages::COPY_DST | wgpu::TextureUsages::COPY_SRC,
                    view_formats: &[],
                });

                let enc = encoder.get_or_insert_with(|| {
                    device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
                        label: Some("misa-rin undo capture before encoder"),
                    })
                });
                enc.copy_texture_to_texture(
                    wgpu::ImageCopyTexture {
                        texture: layer_texture,
                        mip_level: 0,
                        origin: wgpu::Origin3d {
                            x: rect.left,
                            y: rect.top,
                            z: layer_index,
                        },
                        aspect: wgpu::TextureAspect::All,
                    },
                    wgpu::ImageCopyTexture {
                        texture: &before_tex,
                        mip_level: 0,
                        origin: wgpu::Origin3d::ZERO,
                        aspect: wgpu::TextureAspect::All,
                    },
                    wgpu::Extent3d {
                        width: rect.width,
                        height: rect.height,
                        depth_or_array_layers: 1,
                    },
                );

                active.tiles.insert(
                    key,
                    UndoTileBefore {
                        rect,
                        before: before_tex,
                    },
                );
            }
        }

        if let Some(enc) = encoder {
            queue.submit(Some(enc.finish()));
        }
    }

    fn end_stroke(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        layer_texture: &wgpu::Texture,
    ) {
        let Some(active) = self.current.take() else {
            return;
        };
        if active.tiles.is_empty() {
            return;
        }

        let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("misa-rin undo capture after encoder"),
        });
        let mut patches: Vec<UndoTilePatch> = Vec::with_capacity(active.tiles.len());

        for (_, tile_before) in active.tiles {
            let rect = tile_before.rect;
            let after_tex = device.create_texture(&wgpu::TextureDescriptor {
                label: Some("misa-rin undo after (tile)"),
                size: wgpu::Extent3d {
                    width: rect.width,
                    height: rect.height,
                    depth_or_array_layers: 1,
                },
                mip_level_count: 1,
                sample_count: 1,
                dimension: wgpu::TextureDimension::D2,
                format: wgpu::TextureFormat::R32Uint,
                usage: wgpu::TextureUsages::COPY_DST | wgpu::TextureUsages::COPY_SRC,
                view_formats: &[],
            });

            encoder.copy_texture_to_texture(
                wgpu::ImageCopyTexture {
                    texture: layer_texture,
                    mip_level: 0,
                    origin: wgpu::Origin3d {
                        x: rect.left,
                        y: rect.top,
                        z: active.layer_index,
                    },
                    aspect: wgpu::TextureAspect::All,
                },
                wgpu::ImageCopyTexture {
                    texture: &after_tex,
                    mip_level: 0,
                    origin: wgpu::Origin3d::ZERO,
                    aspect: wgpu::TextureAspect::All,
                },
                wgpu::Extent3d {
                    width: rect.width,
                    height: rect.height,
                    depth_or_array_layers: 1,
                },
            );

            patches.push(UndoTilePatch {
                rect,
                before: tile_before.before,
                after: after_tex,
            });
        }

        queue.submit(Some(encoder.finish()));

        self.undo_stack.push(UndoRecord {
            layer_index: active.layer_index,
            tiles: patches,
        });
        if self.undo_stack.len() > self.max_steps {
            let overflow = self.undo_stack.len() - self.max_steps;
            self.undo_stack.drain(0..overflow);
        }
        self.redo_stack.clear();
    }

    fn undo(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        layer_texture: &wgpu::Texture,
        layer_count: usize,
    ) -> bool {
        self.cancel_stroke();
        let Some(record) = self.undo_stack.pop() else {
            return false;
        };
        if (record.layer_index as usize) >= layer_count {
            return false;
        };
        if record.tiles.is_empty() {
            return false;
        }

        let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("misa-rin undo apply encoder"),
        });
        for tile in &record.tiles {
            encoder.copy_texture_to_texture(
                wgpu::ImageCopyTexture {
                    texture: &tile.before,
                    mip_level: 0,
                    origin: wgpu::Origin3d::ZERO,
                    aspect: wgpu::TextureAspect::All,
                },
                wgpu::ImageCopyTexture {
                    texture: layer_texture,
                    mip_level: 0,
                    origin: wgpu::Origin3d {
                        x: tile.rect.left,
                        y: tile.rect.top,
                        z: record.layer_index,
                    },
                    aspect: wgpu::TextureAspect::All,
                },
                wgpu::Extent3d {
                    width: tile.rect.width,
                    height: tile.rect.height,
                    depth_or_array_layers: 1,
                },
            );
        }
        queue.submit(Some(encoder.finish()));
        self.redo_stack.push(record);
        true
    }

    fn redo(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        layer_texture: &wgpu::Texture,
        layer_count: usize,
    ) -> bool {
        self.cancel_stroke();
        let Some(record) = self.redo_stack.pop() else {
            return false;
        };
        if (record.layer_index as usize) >= layer_count {
            return false;
        };
        if record.tiles.is_empty() {
            return false;
        }

        let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("misa-rin redo apply encoder"),
        });
        for tile in &record.tiles {
            encoder.copy_texture_to_texture(
                wgpu::ImageCopyTexture {
                    texture: &tile.after,
                    mip_level: 0,
                    origin: wgpu::Origin3d::ZERO,
                    aspect: wgpu::TextureAspect::All,
                },
                wgpu::ImageCopyTexture {
                    texture: layer_texture,
                    mip_level: 0,
                    origin: wgpu::Origin3d {
                        x: tile.rect.left,
                        y: tile.rect.top,
                        z: record.layer_index,
                    },
                    aspect: wgpu::TextureAspect::All,
                },
                wgpu::Extent3d {
                    width: tile.rect.width,
                    height: tile.rect.height,
                    depth_or_array_layers: 1,
                },
            );
        }
        queue.submit(Some(encoder.finish()));
        self.undo_stack.push(record);
        true
    }
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
struct LayerTextures {
    texture: wgpu::Texture,
    array_view: wgpu::TextureView,
    layer_views: Vec<wgpu::TextureView>,
    width: u32,
    height: u32,
    capacity: usize,
}

#[cfg(target_os = "macos")]
impl LayerTextures {
    fn new(
        device: &wgpu::Device,
        width: u32,
        height: u32,
        capacity: usize,
    ) -> Result<Self, String> {
        let capacity = capacity.max(1);
        let max_layers = device.limits().max_texture_array_layers as usize;
        if capacity > max_layers {
            return Err(format!(
                "layer capacity {capacity} exceeds device max {max_layers}"
            ));
        }
        let texture = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("misa-rin layer array (R32Uint)"),
            size: wgpu::Extent3d {
                width,
                height,
                depth_or_array_layers: capacity as u32,
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
        let array_view = texture.create_view(&wgpu::TextureViewDescriptor {
            dimension: Some(wgpu::TextureViewDimension::D2Array),
            base_array_layer: 0,
            array_layer_count: Some(capacity as u32),
            ..Default::default()
        });
        let mut layer_views = Vec::with_capacity(capacity);
        for idx in 0..capacity {
            let view = texture.create_view(&wgpu::TextureViewDescriptor {
                dimension: Some(wgpu::TextureViewDimension::D2),
                base_array_layer: idx as u32,
                array_layer_count: Some(1),
                ..Default::default()
            });
            layer_views.push(view);
        }

        Ok(Self {
            texture,
            array_view,
            layer_views,
            width,
            height,
            capacity,
        })
    }

    fn capacity(&self) -> usize {
        self.capacity
    }

    fn texture(&self) -> &wgpu::Texture {
        &self.texture
    }

    fn array_view(&self) -> &wgpu::TextureView {
        &self.array_view
    }

    fn layer_view(&self, index: usize) -> Option<&wgpu::TextureView> {
        self.layer_views.get(index)
    }

    fn ensure_capacity(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        required: usize,
    ) -> Result<Option<usize>, String> {
        if required <= self.capacity {
            return Ok(None);
        }

        let max_layers = device.limits().max_texture_array_layers as usize;
        let mut next_capacity = self.capacity.max(1);
        while next_capacity < required {
            next_capacity = next_capacity.saturating_mul(2).max(required);
        }
        if next_capacity > max_layers {
            return Err(format!(
                "layer capacity {next_capacity} exceeds device max {max_layers}"
            ));
        }

        let old_capacity = self.capacity;
        let new_texture = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("misa-rin layer array (R32Uint)"),
            size: wgpu::Extent3d {
                width: self.width,
                height: self.height,
                depth_or_array_layers: next_capacity as u32,
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

        let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("misa-rin layer array resize encoder"),
        });
        encoder.copy_texture_to_texture(
            wgpu::ImageCopyTexture {
                texture: &self.texture,
                mip_level: 0,
                origin: wgpu::Origin3d::ZERO,
                aspect: wgpu::TextureAspect::All,
            },
            wgpu::ImageCopyTexture {
                texture: &new_texture,
                mip_level: 0,
                origin: wgpu::Origin3d::ZERO,
                aspect: wgpu::TextureAspect::All,
            },
            wgpu::Extent3d {
                width: self.width,
                height: self.height,
                depth_or_array_layers: old_capacity as u32,
            },
        );
        queue.submit(Some(encoder.finish()));

        let array_view = new_texture.create_view(&wgpu::TextureViewDescriptor {
            dimension: Some(wgpu::TextureViewDimension::D2Array),
            base_array_layer: 0,
            array_layer_count: Some(next_capacity as u32),
            ..Default::default()
        });
        let mut layer_views = Vec::with_capacity(next_capacity);
        for idx in 0..next_capacity {
            let view = new_texture.create_view(&wgpu::TextureViewDescriptor {
                dimension: Some(wgpu::TextureViewDimension::D2),
                base_array_layer: idx as u32,
                array_layer_count: Some(1),
                ..Default::default()
            });
            layer_views.push(view);
        }

        self.texture = new_texture;
        self.array_view = array_view;
        self.layer_views = layer_views;
        self.capacity = next_capacity;

        Ok(Some(old_capacity))
    }
}

#[cfg(target_os = "macos")]
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

#[cfg(target_os = "macos")]
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
        size: std::mem::size_of::<PresentCompositeHeader>() as u64,
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

#[cfg(target_os = "macos")]
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
            *present =
                attach_present_texture(device, mtl_texture_ptr, width, height, bytes_per_row);
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

#[cfg(target_os = "macos")]
#[derive(Clone, Copy, Debug)]
struct EngineCommandOutcome {
    stop: bool,
    needs_render: bool,
}

#[cfg(target_os = "macos")]
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

#[cfg(target_os = "macos")]
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

#[cfg(target_os = "macos")]
struct PresentRenderer {
    pipeline: wgpu::RenderPipeline,
    bind_group_layout: wgpu::BindGroupLayout,
}

#[cfg(target_os = "macos")]
#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
struct PresentCompositeHeader {
    layer_count: u32,
    view_flags: u32,
    _pad0: u32,
    _pad1: u32,
}

#[cfg(target_os = "macos")]
#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
struct PresentLayerParams {
    opacity: f32,
    visible: f32,
    clipping_mask: f32,
    _pad0: f32,
}

#[cfg(target_os = "macos")]
fn write_present_config(
    queue: &wgpu::Queue,
    header_buffer: &wgpu::Buffer,
    params_buffer: &wgpu::Buffer,
    layer_count: usize,
    view_flags: u32,
    layer_opacity: &[f32],
    layer_visible: &[bool],
    layer_clipping_mask: &[bool],
) {
    let header = PresentCompositeHeader {
        layer_count: layer_count as u32,
        view_flags,
        _pad0: 0,
        _pad1: 0,
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
        params.push(PresentLayerParams {
            opacity,
            visible,
            clipping_mask,
            _pad0: 0.0,
        });
    }
    queue.write_buffer(params_buffer, 0, bytemuck::cast_slice(&params));
}

#[cfg(target_os = "macos")]
fn create_present_params_buffer(
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

#[cfg(target_os = "macos")]
impl PresentRenderer {
    fn new(device: &wgpu::Device) -> Self {
        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("misa-rin present renderer shader"),
            source: wgpu::ShaderSource::Wgsl(Cow::Borrowed(include_str!("canvas_present.wgsl"))),
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
                        min_binding_size: wgpu::BufferSize::new(
                            std::mem::size_of::<PresentCompositeHeader>() as u64,
                        ),
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

    fn create_bind_group(
        &self,
        device: &wgpu::Device,
        layer_view: &wgpu::TextureView,
        config_buffer: &wgpu::Buffer,
        params_buffer: &wgpu::Buffer,
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
            ],
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

    fn consume_and_draw<F: FnMut((i32, i32, i32, i32))>(
        &mut self,
        brush: &mut BrushRenderer,
        brush_settings: &EngineBrushSettings,
        layer_view: &wgpu::TextureView,
        points: Vec<EnginePoint>,
        canvas_width: u32,
        canvas_height: u32,
        before_draw: &mut F,
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

            let radius_prev = brush_settings.radius_from_pressure(self.last_pressure);
            let radius_next = brush_settings.radius_from_pressure(pressure);
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

        let hollow_enabled = brush_settings.hollow_enabled
            && !brush_settings.erase
            && brush_settings.hollow_ratio > 0.0001;
        let hollow_ratio = if hollow_enabled {
            brush_settings.hollow_ratio
        } else {
            0.0
        };
        let hollow_erase = hollow_enabled && brush_settings.hollow_erase_occluded;

        let mut dirty_union: Option<(i32, i32, i32, i32)> = None;
        let mut drew_any = false;
        let dirty_scale = 1.0;

        if emitted.len() == 1 {
            let (p0, pres0) = emitted[0];
            let r0 = brush_settings.radius_from_pressure(pres0);
            let dirty_r0 = r0 * dirty_scale;
            let dirty = compute_dirty_rect_i32(&[p0], &[dirty_r0], canvas_width, canvas_height);
            before_draw(dirty);
            let rotation = if brush_settings.random_rotation
                && !matches!(brush_settings.shape, BrushShape::Circle)
            {
                brush_random_rotation_radians(p0, brush_settings.rotation_seed)
            } else {
                0.0
            };
            match brush.draw_stroke(
                layer_view,
                &[p0],
                &[r0],
                Color {
                    argb: brush_settings.color_argb,
                },
                brush_settings.shape,
                brush_settings.erase,
                brush_settings.antialias_level,
                rotation,
                hollow_enabled,
                hollow_ratio,
                hollow_erase,
                hollow_enabled,
            ) {
                Ok(()) => {
                    drew_any = true;
                    dirty_union = union_dirty_rect_i32(dirty_union, dirty);
                }
                Err(err) => {
                    debug::log(
                        LogLevel::Warn,
                        format_args!("Brush draw_stroke failed: {err}"),
                    );
                }
            }
        } else if hollow_enabled {
            let mut points: Vec<Point2D> = Vec::with_capacity(emitted.len());
            let mut radii: Vec<f32> = Vec::with_capacity(emitted.len());
            for (p, pres) in &emitted {
                points.push(*p);
                radii.push(brush_settings.radius_from_pressure(*pres));
            }
            let dirty_radii: Vec<f32> = radii.iter().map(|r| r * dirty_scale).collect();
            let dirty = compute_dirty_rect_i32(&points, &dirty_radii, canvas_width, canvas_height);
            before_draw(dirty);
            let rotation = if brush_settings.random_rotation
                && !matches!(brush_settings.shape, BrushShape::Circle)
            {
                brush_random_rotation_radians(points[0], brush_settings.rotation_seed)
            } else {
                0.0
            };
            match brush.draw_stroke(
                layer_view,
                &points,
                &radii,
                Color {
                    argb: brush_settings.color_argb,
                },
                brush_settings.shape,
                brush_settings.erase,
                brush_settings.antialias_level,
                rotation,
                hollow_enabled,
                hollow_ratio,
                hollow_erase,
                hollow_enabled,
            ) {
                Ok(()) => {
                    drew_any = true;
                    dirty_union = union_dirty_rect_i32(dirty_union, dirty);
                }
                Err(err) => {
                    debug::log(
                        LogLevel::Warn,
                        format_args!("Brush draw_stroke failed: {err}"),
                    );
                }
            }
        } else {
            for i in 0..emitted.len().saturating_sub(1) {
                let (p0, pres0) = emitted[i];
                let (p1, pres1) = emitted[i + 1];
                let r0 = brush_settings.radius_from_pressure(pres0);
                let r1 = brush_settings.radius_from_pressure(pres1);
                let pts = [p0, p1];
                let radii = [r0, r1];
                let dirty_radii = [r0 * dirty_scale, r1 * dirty_scale];
                let dirty = compute_dirty_rect_i32(&pts, &dirty_radii, canvas_width, canvas_height);
                before_draw(dirty);
                let rotation = if brush_settings.random_rotation
                    && !matches!(brush_settings.shape, BrushShape::Circle)
                {
                    brush_random_rotation_radians(p0, brush_settings.rotation_seed)
                } else {
                    0.0
                };
                match brush.draw_stroke(
                    layer_view,
                    &pts,
                    &radii,
                    Color {
                        argb: brush_settings.color_argb,
                    },
                    brush_settings.shape,
                    brush_settings.erase,
                    brush_settings.antialias_level,
                    rotation,
                    hollow_enabled,
                    hollow_ratio,
                    hollow_erase,
                    hollow_enabled,
                ) {
                    Ok(()) => {
                        drew_any = true;
                        dirty_union = union_dirty_rect_i32(dirty_union, dirty);
                    }
                    Err(err) => {
                        debug::log(
                            LogLevel::Warn,
                            format_args!("Brush draw_stroke failed: {err}"),
                        );
                    }
                }
            }
        }

        self.last_tick_dirty = dirty_union;
        drew_any
    }
}

#[cfg(target_os = "macos")]
const RUST_PRESSURE_MIN_FACTOR: f32 = 0.09;

#[cfg(target_os = "macos")]
fn brush_radius_from_pressure(pressure: f32, base_radius: f32, use_pressure: bool) -> f32 {
    let base = if base_radius.is_finite() {
        base_radius.max(0.0)
    } else {
        0.0
    };
    if !use_pressure {
        return base;
    }
    let p = if pressure.is_finite() {
        pressure.clamp(0.0, 1.0)
    } else {
        0.0
    };
    base * (RUST_PRESSURE_MIN_FACTOR + (1.0 - RUST_PRESSURE_MIN_FACTOR) * p)
}

#[cfg(target_os = "macos")]
fn resample_step_from_radius(radius: f32) -> f32 {
    let r = if radius.is_finite() { radius.max(0.0) } else { 0.0 };
    (r * 0.1).clamp(0.25, 0.5)
}

#[cfg(target_os = "macos")]
fn map_brush_shape(index: u32) -> BrushShape {
    // Dart enum: circle=0, triangle=1, square=2, star=3.
    match index {
        0 => BrushShape::Circle,
        1 => BrushShape::Triangle,
        2 => BrushShape::Square,
        3 => BrushShape::Star,
        _ => BrushShape::Circle,
    }
}

#[cfg(target_os = "macos")]
fn brush_random_rotation_radians(center: Point2D, seed: u32) -> f32 {
    let x = (center.x * 256.0).round() as i32;
    let y = (center.y * 256.0).round() as i32;

    let mut h: u32 = 0;
    h ^= seed;
    h ^= (x as u32).wrapping_mul(0x9e3779b1);
    h ^= (y as u32).wrapping_mul(0x85ebca77);
    h = mix32(h);

    let unit = (h as f64) / 4294967296.0;
    (unit * std::f64::consts::PI * 2.0) as f32
}

#[cfg(target_os = "macos")]
fn mix32(mut h: u32) -> u32 {
    h ^= h >> 16;
    h = h.wrapping_mul(0x7feb352d);
    h ^= h >> 15;
    h = h.wrapping_mul(0x846ca68b);
    h ^= h >> 16;
    h
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
    match create_engine(width, height) {
        Ok(handle) => handle,
        Err(err) => {
            debug::log(LogLevel::Warn, format_args!("engine_create failed: {err}"));
            0
        }
    }
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
    let queue_len = entry.input_queue_len.fetch_add(len as u64, Ordering::Relaxed) + len as u64;

    if debug::level() >= LogLevel::Verbose {
        const FLAG_DOWN: u32 = 1;
        const FLAG_UP: u32 = 4;
        let mut down_count: usize = 0;
        let mut up_count: usize = 0;
        for p in slice {
            if (p.flags & FLAG_DOWN) != 0 {
                down_count += 1;
            }
            if (p.flags & FLAG_UP) != 0 {
                up_count += 1;
            }
        }
        debug::log(
            LogLevel::Verbose,
            format_args!(
                "engine_push_points handle={handle} len={len} down={down_count} up={up_count} queue_len={queue_len}"
            ),
        );
    }

    if entry.input_tx.send(EngineInputBatch { points: owned }).is_err() {
        entry.input_queue_len.fetch_sub(len as u64, Ordering::Relaxed);
        debug::log(
            LogLevel::Warn,
            format_args!("engine_push_points dropped: input thread disconnected"),
        );
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

#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn engine_set_active_layer(handle: u64, layer_index: u32) {
    let Some(entry) = lookup_engine(handle) else {
        return;
    };
    let _ = entry
        .cmd_tx
        .send(EngineCommand::SetActiveLayer { layer_index });
}

#[cfg(not(target_os = "macos"))]
#[no_mangle]
pub extern "C" fn engine_set_active_layer(_handle: u64, _layer_index: u32) {}

#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn engine_set_layer_opacity(handle: u64, layer_index: u32, opacity: f32) {
    let Some(entry) = lookup_engine(handle) else {
        return;
    };
    let _ = entry
        .cmd_tx
        .send(EngineCommand::SetLayerOpacity { layer_index, opacity });
}

#[cfg(not(target_os = "macos"))]
#[no_mangle]
pub extern "C" fn engine_set_layer_opacity(_handle: u64, _layer_index: u32, _opacity: f32) {}

#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn engine_set_layer_visible(handle: u64, layer_index: u32, visible: bool) {
    let Some(entry) = lookup_engine(handle) else {
        return;
    };
    let _ = entry
        .cmd_tx
        .send(EngineCommand::SetLayerVisible { layer_index, visible });
}

#[cfg(not(target_os = "macos"))]
#[no_mangle]
pub extern "C" fn engine_set_layer_visible(_handle: u64, _layer_index: u32, _visible: bool) {}

#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn engine_set_layer_clipping_mask(
    handle: u64,
    layer_index: u32,
    clipping_mask: bool,
) {
    let Some(entry) = lookup_engine(handle) else {
        return;
    };
    let _ = entry.cmd_tx.send(EngineCommand::SetLayerClippingMask {
        layer_index,
        clipping_mask,
    });
}

#[cfg(not(target_os = "macos"))]
#[no_mangle]
pub extern "C" fn engine_set_layer_clipping_mask(
    _handle: u64,
    _layer_index: u32,
    _clipping_mask: bool,
) {
}

#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn engine_set_view_flags(handle: u64, view_flags: u32) {
    let Some(entry) = lookup_engine(handle) else {
        return;
    };
    let _ = entry.cmd_tx.send(EngineCommand::SetViewFlags { view_flags });
}

#[cfg(not(target_os = "macos"))]
#[no_mangle]
pub extern "C" fn engine_set_view_flags(_handle: u64, _view_flags: u32) {}

#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn engine_set_brush(
    handle: u64,
    color_argb: u32,
    base_radius: f32,
    use_pressure: u8,
    erase: u8,
    antialias_level: u32,
    brush_shape: u32,
    random_rotation: u8,
    rotation_seed: u32,
    hollow_enabled: u8,
    hollow_ratio: f32,
    hollow_erase_occluded: u8,
) {
    let Some(entry) = lookup_engine(handle) else {
        return;
    };
    let _ = entry.cmd_tx.send(EngineCommand::SetBrush {
        color_argb,
        base_radius,
        use_pressure: use_pressure != 0,
        erase: erase != 0,
        antialias_level,
        brush_shape,
        random_rotation: random_rotation != 0,
        rotation_seed,
        hollow_enabled: hollow_enabled != 0,
        hollow_ratio,
        hollow_erase_occluded: hollow_erase_occluded != 0,
    });
}

#[cfg(not(target_os = "macos"))]
#[no_mangle]
pub extern "C" fn engine_set_brush(
    _handle: u64,
    _color_argb: u32,
    _base_radius: f32,
    _use_pressure: u8,
    _erase: u8,
    _antialias_level: u32,
    _brush_shape: u32,
    _random_rotation: u8,
    _rotation_seed: u32,
    _hollow_enabled: u8,
    _hollow_ratio: f32,
    _hollow_erase_occluded: u8,
) {
}

#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn engine_clear_layer(handle: u64, layer_index: u32) {
    let Some(entry) = lookup_engine(handle) else {
        return;
    };
    let _ = entry
        .cmd_tx
        .send(EngineCommand::ClearLayer { layer_index });
}

#[cfg(not(target_os = "macos"))]
#[no_mangle]
pub extern "C" fn engine_clear_layer(_handle: u64, _layer_index: u32) {}

#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn engine_fill_layer(handle: u64, layer_index: u32, color_argb: u32) {
    let Some(entry) = lookup_engine(handle) else {
        return;
    };
    let _ = entry
        .cmd_tx
        .send(EngineCommand::FillLayer { layer_index, color_argb });
}

#[cfg(not(target_os = "macos"))]
#[no_mangle]
pub extern "C" fn engine_fill_layer(_handle: u64, _layer_index: u32, _color_argb: u32) {}

#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn engine_reset_canvas(handle: u64, background_color_argb: u32) {
    let Some(entry) = lookup_engine(handle) else {
        return;
    };
    let _ = entry
        .cmd_tx
        .send(EngineCommand::ResetCanvas { background_color_argb });
}

#[cfg(not(target_os = "macos"))]
#[no_mangle]
pub extern "C" fn engine_reset_canvas(_handle: u64, _background_color_argb: u32) {}

#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn engine_undo(handle: u64) {
    let Some(entry) = lookup_engine(handle) else {
        return;
    };
    let _ = entry.cmd_tx.send(EngineCommand::Undo);
}

#[cfg(not(target_os = "macos"))]
#[no_mangle]
pub extern "C" fn engine_undo(_handle: u64) {}

#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn engine_redo(handle: u64) {
    let Some(entry) = lookup_engine(handle) else {
        return;
    };
    let _ = entry.cmd_tx.send(EngineCommand::Redo);
}

#[cfg(not(target_os = "macos"))]
#[no_mangle]
pub extern "C" fn engine_redo(_handle: u64) {}
