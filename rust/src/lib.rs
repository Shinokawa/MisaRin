pub mod api;
mod frb_generated;
mod gpu;

use std::ffi::c_void;

#[no_mangle]
pub extern "C" fn engine_poll_frame_ready(_engine_handle: *mut c_void) -> bool {
    true
}
