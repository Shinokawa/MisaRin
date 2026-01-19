use std::ffi::c_void;

use super::types::EnginePoint;

#[cfg(target_os = "macos")]
use std::sync::atomic::Ordering;
#[cfg(target_os = "macos")]
use crate::gpu::debug::{self, LogLevel};
#[cfg(target_os = "macos")]
use super::engine::{create_engine, lookup_engine, remove_engine, EngineCommand, EngineInputBatch};

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

    if entry
        .input_tx
        .send(EngineInputBatch { points: owned })
        .is_err()
    {
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
