use crate::cpu_filters::{cpu_filters_apply_antialias, cpu_filters_apply_filter_rgba};

#[flutter_rust_bridge::frb]
pub struct CpuFiltersResult {
    pub ok: bool,
    pub pixels: Vec<u32>,
}

#[flutter_rust_bridge::frb]
pub struct CpuFiltersBytesResult {
    pub ok: bool,
    pub pixels: Vec<u8>,
}

#[flutter_rust_bridge::frb(sync)]
pub fn cpu_filters_apply_antialias_rgba(
    pixels: Vec<u32>,
    width: u32,
    height: u32,
    level: u32,
    preview_only: bool,
) -> CpuFiltersResult {
    let mut pixels = pixels;
    let ok = cpu_filters_apply_antialias(
        pixels.as_mut_ptr(),
        pixels.len() as u64,
        width,
        height,
        level,
        if preview_only { 1 } else { 0 },
    );
    CpuFiltersResult {
        ok: ok != 0,
        pixels,
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn cpu_filters_apply_filter_rgba_bytes(
    pixels: Vec<u8>,
    width: u32,
    height: u32,
    filter_type: u32,
    param0: f32,
    param1: f32,
    param2: f32,
    param3: f32,
) -> CpuFiltersBytesResult {
    let mut pixels = pixels;
    let ok = cpu_filters_apply_filter_rgba(
        pixels.as_mut_ptr(),
        pixels.len() as u64,
        width,
        height,
        filter_type,
        param0,
        param1,
        param2,
        param3,
    );
    CpuFiltersBytesResult {
        ok: ok != 0,
        pixels,
    }
}
