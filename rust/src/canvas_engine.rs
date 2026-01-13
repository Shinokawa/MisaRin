use std::collections::HashMap;
use std::ffi::c_void;
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
enum EngineCommand {
    AttachPresentTexture {
        mtl_texture_ptr: usize,
        width: u32,
        height: u32,
        bytes_per_row: u32,
    },
    Stop,
}

#[cfg(target_os = "macos")]
struct EngineEntry {
    mtl_device_ptr: usize,
    frame_ready: Arc<AtomicBool>,
    cmd_tx: mpsc::Sender<EngineCommand>,
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
    frame_ready: Arc<AtomicBool>,
) {
    let _ = thread::Builder::new()
        .name("misa-rin-canvas-render".to_string())
        .spawn(move || render_thread_main(device, queue, layer_textures, cmd_rx, frame_ready));
}

#[cfg(target_os = "macos")]
fn render_thread_main(
    device: wgpu::Device,
    queue: wgpu::Queue,
    _layer_textures: Vec<wgpu::Texture>,
    cmd_rx: mpsc::Receiver<EngineCommand>,
    frame_ready: Arc<AtomicBool>,
) {
    let mut present: Option<PresentTarget> = None;
    let mut frame_index: u64 = 0;

    loop {
        match &present {
            None => match cmd_rx.recv() {
                Ok(cmd) => {
                    if handle_engine_command(&device, &queue, &frame_ready, &mut present, cmd) {
                        break;
                    }
                }
                Err(_) => break,
            },
            Some(_) => match cmd_rx.recv_timeout(Duration::from_millis(16)) {
                Ok(cmd) => {
                    if handle_engine_command(&device, &queue, &frame_ready, &mut present, cmd) {
                        break;
                    }
                }
                Err(mpsc::RecvTimeoutError::Timeout) => {
                    if let Some(target) = &present {
                        frame_index = frame_index.wrapping_add(1);
                        submit_test_clear(
                            &device,
                            &queue,
                            &target.view,
                            frame_index,
                            Arc::clone(&frame_ready),
                        );
                    }
                }
                Err(mpsc::RecvTimeoutError::Disconnected) => break,
            },
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
                submit_test_clear(device, queue, &target.view, 0, Arc::clone(frame_ready));
            }
        }
    }
    false
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
    frame_index: u64,
    frame_ready: Arc<AtomicBool>,
) {
    let phase = (frame_index / 60) % 3;
    let (r, g, b) = match phase {
        0 => (0.85, 0.15, 0.15),
        1 => (0.15, 0.85, 0.15),
        _ => (0.15, 0.15, 0.85),
    };

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
                        a: 1.0,
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
    let frame_ready = Arc::new(AtomicBool::new(false));
    spawn_render_thread(device, queue, vec![layer0], cmd_rx, Arc::clone(&frame_ready));

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
