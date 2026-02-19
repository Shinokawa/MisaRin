#[no_mangle]
pub extern "C" fn cpu_image_bounds(
    pixels: *const u32,
    pixels_len: u64,
    width: u32,
    height: u32,
    out_bounds: *mut i32,
) -> u8 {
    if pixels.is_null() || out_bounds.is_null() {
        return 0;
    }
    if pixels_len == 0 || width == 0 || height == 0 {
        return 0;
    }
    let expected_len = width as u64 * height as u64;
    if expected_len != pixels_len {
        return 0;
    }
    let len = pixels_len as usize;
    if len == 0 || len > isize::MAX as usize {
        return 0;
    }

    let slice = unsafe { std::slice::from_raw_parts(pixels, len) };
    let width_usize = width as usize;
    let height_usize = height as usize;

    let mut min_x: i32 = width as i32;
    let mut min_y: i32 = height as i32;
    let mut max_x: i32 = -1;
    let mut max_y: i32 = -1;

    for y in 0..height_usize {
        let row_offset = y * width_usize;
        for x in 0..width_usize {
            let argb = slice[row_offset + x];
            if (argb >> 24) == 0 {
                continue;
            }
            let xi = x as i32;
            let yi = y as i32;
            if xi < min_x {
                min_x = xi;
            }
            if xi > max_x {
                max_x = xi;
            }
            if yi < min_y {
                min_y = yi;
            }
            if yi > max_y {
                max_y = yi;
            }
        }
    }

    if max_x < min_x || max_y < min_y {
        return 0;
    }

    unsafe {
        *out_bounds.add(0) = min_x;
        *out_bounds.add(1) = min_y;
        *out_bounds.add(2) = max_x + 1;
        *out_bounds.add(3) = max_y + 1;
    }
    1
}
