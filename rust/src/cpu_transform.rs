#[no_mangle]
pub extern "C" fn cpu_layer_translate(
    canvas: *mut u32,
    canvas_len: u64,
    canvas_width: u32,
    canvas_height: u32,
    snapshot: *const u32,
    snapshot_len: u64,
    snapshot_width: u32,
    snapshot_height: u32,
    origin_x: i32,
    origin_y: i32,
    dx: i32,
    dy: i32,
    out_x: *mut i32,
    out_y: *mut i32,
    out_color: *mut u32,
    out_capacity: u64,
    out_count: *mut u64,
) -> u8 {
    if canvas.is_null() || snapshot.is_null() {
        return 0;
    }
    if canvas_len == 0 || snapshot_len == 0 {
        return 0;
    }
    if canvas_width == 0 || canvas_height == 0 || snapshot_width == 0 || snapshot_height == 0 {
        return 0;
    }

    let expected_canvas = canvas_width as u64 * canvas_height as u64;
    if expected_canvas != canvas_len {
        return 0;
    }
    let expected_snapshot = snapshot_width as u64 * snapshot_height as u64;
    if expected_snapshot != snapshot_len {
        return 0;
    }

    let canvas_len_usize = canvas_len as usize;
    if canvas_len_usize == 0 || canvas_len_usize > isize::MAX as usize {
        return 0;
    }
    let snapshot_len_usize = snapshot_len as usize;
    if snapshot_len_usize == 0 || snapshot_len_usize > isize::MAX as usize {
        return 0;
    }

    let canvas_slice = unsafe { std::slice::from_raw_parts_mut(canvas, canvas_len_usize) };
    let snapshot_slice = unsafe { std::slice::from_raw_parts(snapshot, snapshot_len_usize) };
    for pixel in canvas_slice.iter_mut() {
        *pixel = 0;
    }

    let use_overflow = !out_x.is_null()
        && !out_y.is_null()
        && !out_color.is_null()
        && !out_count.is_null()
        && out_capacity > 0;

    let mut overflow_count: u64 = 0;
    let canvas_w = canvas_width as i64;
    let canvas_h = canvas_height as i64;
    let snapshot_w = snapshot_width as usize;
    let snapshot_h = snapshot_height as usize;

    for sy in 0..snapshot_h {
        let row_offset = sy * snapshot_w;
        for sx in 0..snapshot_w {
            let color = snapshot_slice[row_offset + sx];
            if (color >> 24) == 0 {
                continue;
            }
            let cx = origin_x as i64 + sx as i64 + dx as i64;
            let cy = origin_y as i64 + sy as i64 + dy as i64;
            if cx >= 0 && cy >= 0 && cx < canvas_w && cy < canvas_h {
                let index = cy as usize * canvas_width as usize + cx as usize;
                canvas_slice[index] = color;
            } else if use_overflow {
                if overflow_count >= out_capacity {
                    return 0;
                }
                let idx = overflow_count as usize;
                unsafe {
                    *out_x.add(idx) = cx as i32;
                    *out_y.add(idx) = cy as i32;
                    *out_color.add(idx) = color;
                }
                overflow_count += 1;
            }
        }
    }

    if use_overflow {
        unsafe {
            *out_count = overflow_count;
        }
    }
    1
}
