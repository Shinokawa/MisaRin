#[flutter_rust_bridge::frb(sync)]
pub fn convert_pixels_to_rgba(pixels: Vec<u32>) -> Vec<u8> {
    let mut rgba = vec![0u8; pixels.len().saturating_mul(4)];
    for (argb, out) in pixels.into_iter().zip(rgba.chunks_exact_mut(4)) {
        out[0] = ((argb >> 16) & 0xff) as u8;
        out[1] = ((argb >> 8) & 0xff) as u8;
        out[2] = (argb & 0xff) as u8;
        out[3] = ((argb >> 24) & 0xff) as u8;
    }
    rgba
}
