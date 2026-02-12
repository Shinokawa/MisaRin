use std::f32::consts::FRAC_1_SQRT_2;

const EPS: f32 = 1.0e-6;

fn clamp01(v: f32) -> f32 {
    if v.is_finite() {
        v.clamp(0.0, 1.0)
    } else {
        0.0
    }
}

fn antialias_feather(level: u32) -> f32 {
    match level {
        0 => 0.0,
        1 => 0.7,
        2 => 1.1,
        3 => 1.6,
        4 => 1.9,
        5 => 2.2,
        6 => 2.5,
        7 => 2.8,
        8 => 3.1,
        _ => 3.4,
    }
}

fn antialias_samples_per_axis(level: u32) -> u32 {
    let clamped = level.min(9);
    if clamped <= 3 {
        1u32 << clamped
    } else {
        8 + (clamped - 3) * 2
    }
}

fn brush_alpha(dist: f32, radius: f32, softness: f32, aa_level: u32) -> f32 {
    if radius <= 0.0 {
        return 0.0;
    }
    let s = clamp01(softness);
    let aa_feather = antialias_feather(aa_level);
    let edge = aa_feather.max(radius * s);
    if edge <= 0.0 {
        return if dist <= radius { 1.0 } else { 0.0 };
    }
    let inner = (radius - edge).max(0.0);
    let outer = radius + edge;
    if dist <= inner {
        return 1.0;
    }
    if dist >= outer {
        return 0.0;
    }
    (outer - dist) / (outer - inner)
}

fn rotate_to_brush_space(x: f32, y: f32, rot_sin: f32, rot_cos: f32) -> (f32, f32) {
    (x * rot_cos + y * rot_sin, -x * rot_sin + y * rot_cos)
}

fn tri_vert(i: u32) -> (f32, f32) {
    match i {
        0 => (0.0, -1.0),
        1 => (0.866025404, 0.5),
        _ => (-0.866025404, 0.5),
    }
}

fn star_vert(i: u32) -> (f32, f32) {
    match i {
        0 => (0.0, -1.0),
        1 => (0.224513988, -0.309016994),
        2 => (0.951056516, -0.309016994),
        3 => (0.363271264, 0.118033989),
        4 => (0.587785252, 0.809016994),
        5 => (0.0, 0.381966011),
        6 => (-0.587785252, 0.809016994),
        7 => (-0.363271264, 0.118033989),
        8 => (-0.951056516, -0.309016994),
        _ => (-0.224513988, -0.309016994),
    }
}

fn segment_distance(px: f32, py: f32, ax: f32, ay: f32, bx: f32, by: f32) -> f32 {
    let abx = bx - ax;
    let aby = by - ay;
    let apx = px - ax;
    let apy = py - ay;
    let ab_len2 = abx * abx + aby * aby;
    if ab_len2 <= EPS {
        return ((px - ax) * (px - ax) + (py - ay) * (py - ay)).sqrt();
    }
    let t = (apx * abx + apy * aby) / ab_len2;
    let t = t.clamp(0.0, 1.0);
    let cx = ax + abx * t;
    let cy = ay + aby * t;
    ((px - cx) * (px - cx) + (py - cy) * (py - cy)).sqrt()
}

fn signed_distance_box(px: f32, py: f32, half: f32) -> f32 {
    let dx = px.abs() - half;
    let dy = py.abs() - half;
    let outside = (dx.max(0.0) * dx.max(0.0) + dy.max(0.0) * dy.max(0.0)).sqrt();
    let inside = dx.max(dy).min(0.0);
    outside + inside
}

fn signed_distance_triangle_unit(px: f32, py: f32) -> f32 {
    let mut min_dist = 1.0e9;
    let mut inside = false;
    let mut j = 2u32;
    for i in 0..3u32 {
        let (ax, ay) = tri_vert(j);
        let (bx, by) = tri_vert(i);
        min_dist = min_dist.min(segment_distance(px, py, ax, ay, bx, by));
        if (ay > py) != (by > py) {
            let x = ax + (py - ay) * (bx - ax) / (by - ay);
            if px < x {
                inside = !inside;
            }
        }
        j = i;
    }
    if inside { -min_dist } else { min_dist }
}

fn signed_distance_star_unit(px: f32, py: f32) -> f32 {
    let mut min_dist = 1.0e9;
    let mut inside = false;
    let mut j = 9u32;
    for i in 0..10u32 {
        let (ax, ay) = star_vert(j);
        let (bx, by) = star_vert(i);
        min_dist = min_dist.min(segment_distance(px, py, ax, ay, bx, by));
        if (ay > py) != (by > py) {
            let x = ax + (py - ay) * (bx - ax) / (by - ay);
            if px < x {
                inside = !inside;
            }
        }
        j = i;
    }
    if inside { -min_dist } else { min_dist }
}

fn shape_distance_to_point(
    sample_x: f32,
    sample_y: f32,
    center_x: f32,
    center_y: f32,
    radius: f32,
    rot_sin: f32,
    rot_cos: f32,
    shape: u32,
) -> f32 {
    let rel_x = sample_x - center_x;
    let rel_y = sample_y - center_y;
    let (rx, ry) = rotate_to_brush_space(rel_x, rel_y, rot_sin, rot_cos);
    match shape {
        0 => (rx * rx + ry * ry).sqrt(), // circle
        2 => {
            if radius <= EPS {
                radius
            } else {
                let half_side = radius * FRAC_1_SQRT_2;
                let sd = signed_distance_box(rx, ry, half_side);
                radius + sd
            }
        }
        1 | 3 => {
            if radius <= EPS {
                return radius;
            }
            let inv_r = 1.0 / radius;
            let ux = rx * inv_r;
            let uy = ry * inv_r;
            let sd_unit = if shape == 3 {
                signed_distance_star_unit(ux, uy)
            } else {
                signed_distance_triangle_unit(ux, uy)
            };
            radius + sd_unit * radius
        }
        _ => (rx * rx + ry * ry).sqrt(),
    }
}

fn unpack_a(argb: u32) -> f32 {
    ((argb >> 24) & 0xff) as f32 / 255.0
}

fn unpack_r(argb: u32) -> f32 {
    ((argb >> 16) & 0xff) as f32 / 255.0
}

fn unpack_g(argb: u32) -> f32 {
    ((argb >> 8) & 0xff) as f32 / 255.0
}

fn unpack_b(argb: u32) -> f32 {
    (argb & 0xff) as f32 / 255.0
}

fn pack_argb(a: f32, r: f32, g: f32, b: f32) -> u32 {
    let aa = (clamp01(a) * 255.0 + 0.5).floor().clamp(0.0, 255.0) as u32;
    let rr = (clamp01(r) * 255.0 + 0.5).floor().clamp(0.0, 255.0) as u32;
    let gg = (clamp01(g) * 255.0 + 0.5).floor().clamp(0.0, 255.0) as u32;
    let bb = (clamp01(b) * 255.0 + 0.5).floor().clamp(0.0, 255.0) as u32;
    (aa << 24) | (rr << 16) | (gg << 8) | bb
}

fn blend_paint(dst: u32, src_r: f32, src_g: f32, src_b: f32, src_a: f32) -> u32 {
    if src_a <= 0.0 {
        return dst;
    }
    let da = unpack_a(dst);
    let dr = unpack_r(dst);
    let dg = unpack_g(dst);
    let db = unpack_b(dst);
    let out_a = src_a + da * (1.0 - src_a);
    if out_a <= 0.0 {
        return 0;
    }
    let dst_w = da * (1.0 - src_a);
    let out_r = (src_r * src_a + dr * dst_w) / out_a;
    let out_g = (src_g * src_a + dg * dst_w) / out_a;
    let out_b = (src_b * src_a + db * dst_w) / out_a;
    pack_argb(out_a, out_r, out_g, out_b)
}

fn blend_erase(dst: u32, erase_a: f32) -> u32 {
    if erase_a <= 0.0 {
        return dst;
    }
    let da = unpack_a(dst);
    if da <= 0.0 {
        return dst;
    }
    let out_a = da * (1.0 - clamp01(erase_a));
    if out_a <= 0.0 {
        return 0;
    }
    pack_argb(out_a, unpack_r(dst), unpack_g(dst), unpack_b(dst))
}

fn mix32(mut h: u32) -> u32 {
    h ^= h >> 16;
    h = h.wrapping_mul(0x7feb352d);
    h ^= h >> 15;
    h = h.wrapping_mul(0x846ca68b);
    h ^= h >> 16;
    h
}

fn brush_random_rotation_radians(center_x: f32, center_y: f32, seed: u32) -> f32 {
    let x = (center_x * 256.0).round() as i32;
    let y = (center_y * 256.0).round() as i32;

    let mut h: u32 = 0;
    h ^= seed;
    h ^= (x as u32).wrapping_mul(0x9e3779b1);
    h ^= (y as u32).wrapping_mul(0x85ebca77);
    h = mix32(h);

    let unit = (h as f64) / 4294967296.0;
    (unit * std::f64::consts::PI * 2.0) as f32
}

#[no_mangle]
pub extern "C" fn cpu_brush_draw_stamp(
    pixels_ptr: *mut u32,
    pixels_len: usize,
    width: u32,
    height: u32,
    center_x: f32,
    center_y: f32,
    radius: f32,
    color_argb: u32,
    brush_shape: u32,
    antialias_level: u32,
    softness: f32,
    erase: u8,
    random_rotation: u8,
    rotation_seed: u32,
    rotation_jitter: f32,
    snap_to_pixel: u8,
    selection_ptr: *const u8,
    selection_len: usize,
) -> u8 {
    if pixels_ptr.is_null() || width == 0 || height == 0 {
        return 0;
    }
    let pixel_count = (width as usize).saturating_mul(height as usize);
    if pixel_count == 0 || pixels_len < pixel_count {
        return 0;
    }

    let pixels = unsafe { std::slice::from_raw_parts_mut(pixels_ptr, pixels_len) };
    let selection = if selection_ptr.is_null() || selection_len < pixel_count {
        None
    } else {
        Some(unsafe { std::slice::from_raw_parts(selection_ptr, selection_len) })
    };

    let mut cx = center_x;
    let mut cy = center_y;
    let mut r = radius;
    if snap_to_pixel != 0 {
        cx = cx.floor() + 0.5;
        cy = cy.floor() + 0.5;
        if r.is_finite() {
            r = (r * 2.0).round() * 0.5;
        }
    }
    if !r.is_finite() || r <= 0.0 {
        r = 0.01;
    }

    let aa_level = antialias_level.min(9);
    let soft = clamp01(softness);
    let feather = antialias_feather(aa_level);
    let edge = feather.max(r * soft);
    let outer = r + edge + 1.5;

    let min_x = (cx - outer).floor().max(0.0) as i32;
    let max_x = (cx + outer).ceil().min((width as f32) - 1.0) as i32;
    let min_y = (cy - outer).floor().max(0.0) as i32;
    let max_y = (cy + outer).ceil().min((height as f32) - 1.0) as i32;
    if min_x > max_x || min_y > max_y {
        return 1;
    }

    let src_a = unpack_a(color_argb);
    let src_r = unpack_r(color_argb);
    let src_g = unpack_g(color_argb);
    let src_b = unpack_b(color_argb);

    let rotation = if random_rotation != 0 {
        let angle = brush_random_rotation_radians(cx, cy, rotation_seed);
        let jitter = if rotation_jitter.is_finite() {
            rotation_jitter.clamp(0.0, 1.0)
        } else {
            1.0
        };
        angle * jitter
    } else {
        0.0
    };
    let rot_sin = rotation.sin();
    let rot_cos = rotation.cos();

    let samples = antialias_samples_per_axis(aa_level);
    let inv_samples = 1.0 / (samples as f32);
    let total_samples = (samples * samples) as f32;

    for y in min_y..=max_y {
        let row = (y as usize) * (width as usize);
        for x in min_x..=max_x {
            let idx = row + (x as usize);
            if let Some(mask) = selection {
                if mask.get(idx).copied().unwrap_or(0) == 0 {
                    continue;
                }
            }

            let mut accum = 0.0f32;
            for sy in 0..samples {
                for sx in 0..samples {
                    let ox = (sx as f32 + 0.5) * inv_samples - 0.5;
                    let oy = (sy as f32 + 0.5) * inv_samples - 0.5;
                    let sample_x = x as f32 + 0.5 + ox;
                    let sample_y = y as f32 + 0.5 + oy;
                    let dist = shape_distance_to_point(
                        sample_x,
                        sample_y,
                        cx,
                        cy,
                        r,
                        rot_sin,
                        rot_cos,
                        brush_shape,
                    );
                    let a = brush_alpha(dist, r, soft, aa_level);
                    accum += a;
                }
            }
            let coverage = clamp01(accum / total_samples.max(1.0));
            if coverage <= 0.0 {
                continue;
            }

            let dst = pixels[idx];
            if erase != 0 {
                let erase_a = clamp01(coverage * src_a);
                if erase_a > 0.0 {
                    pixels[idx] = blend_erase(dst, erase_a);
                }
            } else {
                let paint_a = clamp01(coverage * src_a);
                if paint_a > 0.0 {
                    pixels[idx] = blend_paint(dst, src_r, src_g, src_b, paint_a);
                }
            }
        }
    }

    1
}
