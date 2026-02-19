use crate::cpu_image::cpu_image_bounds;

#[flutter_rust_bridge::frb]
pub struct CpuImageBoundsResult {
    pub ok: bool,
    pub bounds: Vec<i32>,
}

#[flutter_rust_bridge::frb(sync)]
pub fn cpu_image_bounds_rgba(pixels: Vec<u32>, width: u32, height: u32) -> CpuImageBoundsResult {
    let mut bounds = vec![0i32; 4];
    let ok = cpu_image_bounds(
        pixels.as_ptr(),
        pixels.len() as u64,
        width,
        height,
        bounds.as_mut_ptr(),
    );
    CpuImageBoundsResult {
        ok: ok != 0,
        bounds,
    }
}
