use std::f32::consts::FRAC_1_SQRT_2;

const EPS: f32 = 1.0e-6;
const SUBPIXEL_RADIUS_LIMIT: f32 = 0.6;
const HALF_PIXEL: f32 = 0.5;
const SUPERSAMPLE_DIAMETER_THRESHOLD: f32 = 10.0;
const SUPERSAMPLE_FINE_DIAMETER: f32 = 1.0;
const MIN_INTEGRATION_SLICES: i32 = 6;
const MAX_INTEGRATION_SLICES: i32 = 20;

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

fn needs_supersampling(radius: f32, antialias_level: u32) -> bool {
    if antialias_level == 0 || radius <= 0.0 {
        return false;
    }
    let diameter = radius * 2.0;
    if diameter < SUPERSAMPLE_FINE_DIAMETER {
        return true;
    }
    diameter < SUPERSAMPLE_DIAMETER_THRESHOLD
}

fn supersample_factor(radius: f32) -> i32 {
    let diameter = radius * 2.0;
    if diameter < SUPERSAMPLE_FINE_DIAMETER {
        return 6;
    }
    if diameter < SUPERSAMPLE_DIAMETER_THRESHOLD {
        return 3;
    }
    1
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

fn radial_coverage(distance: f32, radius: f32, feather: f32, antialias_level: u32) -> f32 {
    if radius <= 0.0 {
        return 0.0;
    }
    if antialias_level == 0 || feather <= 0.0 {
        return if distance <= radius { 1.0 } else { 0.0 };
    }
    let inner = (radius - feather).max(0.0);
    let outer = radius + feather;
    if distance <= inner {
        return 1.0;
    }
    if distance >= outer || outer <= inner {
        return 0.0;
    }
    (outer - distance) / (outer - inner)
}

fn integration_slices_for_radius(radius: f32) -> i32 {
    let scaled = (radius * 32.0).clamp(
        MIN_INTEGRATION_SLICES as f32,
        MAX_INTEGRATION_SLICES as f32,
    );
    let rounded = scaled.round() as i32;
    rounded.clamp(MIN_INTEGRATION_SLICES, MAX_INTEGRATION_SLICES)
}

fn vertical_intersection_length(sample_x: f32, cx: f32, cy: f32, radius: f32) -> f32 {
    let dx = sample_x - cx;
    let rad_sq = radius * radius;
    let remainder = rad_sq - dx * dx;
    if remainder <= 0.0 {
        return 0.0;
    }
    let chord = remainder.sqrt();
    let low = (-HALF_PIXEL).max(cy - chord);
    let high = HALF_PIXEL.min(cy + chord);
    let span = high - low;
    if span > 0.0 { span } else { 0.0 }
}

fn projected_pixel_coverage(dx: f32, dy: f32, radius: f32) -> f32 {
    let abs_dx = dx.abs();
    let abs_dy = dy.abs();
    if abs_dx >= radius + HALF_PIXEL || abs_dy >= radius + HALF_PIXEL {
        return 0.0;
    }
    if abs_dx + radius <= HALF_PIXEL && abs_dy + radius <= HALF_PIXEL {
        let area = std::f32::consts::PI * radius * radius;
        return if area >= 1.0 { 1.0 } else { area };
    }
    let cx = -dx;
    let cy = -dy;
    let min_x = (-HALF_PIXEL).max(cx - radius);
    let max_x = HALF_PIXEL.min(cx + radius);
    if min_x >= max_x {
        return 0.0;
    }
    let width = max_x - min_x;
    let slices = integration_slices_for_radius(radius);
    let mut area = 0.0;
    for i in 0..slices {
        let start = min_x + width * (i as f32 / slices as f32);
        let end = min_x + width * ((i + 1) as f32 / slices as f32);
        let mid = (start + end) * 0.5;
        let span = vertical_intersection_length(mid, cx, cy, radius);
        if span <= 0.0 {
            continue;
        }
        area += span * (end - start);
    }
    area.clamp(0.0, 1.0)
}

fn supersample_circle_coverage(
    dx: f32,
    dy: f32,
    radius: f32,
    feather: f32,
    antialias_level: u32,
) -> f32 {
    let samples = supersample_factor(radius).clamp(1, 6);
    if samples <= 1 {
        let dist = (dx * dx + dy * dy).sqrt();
        return radial_coverage(dist, radius, feather, antialias_level);
    }
    let step = 1.0 / samples as f32;
    let start = -0.5 + step * 0.5;
    let mut accum = 0.0;
    for sy in 0..samples {
        let offset_y = start + sy as f32 * step;
        for sx in 0..samples {
            let offset_x = start + sx as f32 * step;
            let sample_dx = dx + offset_x;
            let sample_dy = dy + offset_y;
            let distance = (sample_dx * sample_dx + sample_dy * sample_dy).sqrt();
            accum += radial_coverage(distance, radius, feather, antialias_level);
        }
    }
    let inv = 1.0 / (samples * samples) as f32;
    accum * inv
}

fn compute_pixel_coverage(
    dx: f32,
    dy: f32,
    distance: f32,
    radius: f32,
    feather: f32,
    antialias_level: u32,
) -> f32 {
    if radius <= 0.0 {
        return 0.0;
    }
    if needs_supersampling(radius, antialias_level) {
        return supersample_circle_coverage(dx, dy, radius, feather, antialias_level);
    }
    if antialias_level > 0 && radius <= SUBPIXEL_RADIUS_LIMIT {
        return projected_pixel_coverage(dx, dy, radius);
    }
    radial_coverage(distance, radius, feather, antialias_level)
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

#[derive(Clone, Copy, Debug)]
struct CapsuleCoverageSample {
    coverage: f32,
    radius: f32,
}

fn capsule_coverage_sample(
    px: f32,
    py: f32,
    ax: f32,
    ay: f32,
    abx: f32,
    aby: f32,
    inv_len_sq: f32,
    include_start_cap: bool,
    variable_radius: bool,
    start_radius: f32,
    radius_delta: f32,
    feather: f32,
    antialias_level: u32,
) -> Option<CapsuleCoverageSample> {
    let raw_t = ((px - ax) * abx + (py - ay) * aby) * inv_len_sq;
    let mut t = raw_t;
    if t < 0.0 {
        if !include_start_cap && t < -1.0e-6 {
            return None;
        }
        t = 0.0;
    } else if t > 1.0 {
        t = 1.0;
    }
    let closest_x = ax + abx * t;
    let closest_y = ay + aby * t;
    let dxp = px - closest_x;
    let dyp = py - closest_y;
    let distance = (dxp * dxp + dyp * dyp).sqrt();
    let mut radius = if variable_radius {
        start_radius + radius_delta * t
    } else {
        start_radius
    };
    radius = radius.abs();
    if radius == 0.0 && feather == 0.0 {
        return None;
    }
    let coverage = compute_pixel_coverage(dxp, dyp, distance, radius, feather, antialias_level);
    if coverage <= 0.0 {
        return None;
    }
    Some(CapsuleCoverageSample { coverage, radius })
}

fn supersample_capsule_coverage(
    px: f32,
    py: f32,
    ax: f32,
    ay: f32,
    abx: f32,
    aby: f32,
    inv_len_sq: f32,
    include_start_cap: bool,
    variable_radius: bool,
    start_radius: f32,
    radius_delta: f32,
    feather: f32,
    antialias_level: u32,
    supersample: i32,
) -> f32 {
    if supersample <= 1 {
        return capsule_coverage_sample(
            px,
            py,
            ax,
            ay,
            abx,
            aby,
            inv_len_sq,
            include_start_cap,
            variable_radius,
            start_radius,
            radius_delta,
            feather,
            antialias_level,
        )
        .map(|s| s.coverage)
        .unwrap_or(0.0);
    }
    let step = 1.0 / supersample as f32;
    let start = -0.5 + step * 0.5;
    let mut accum = 0.0;
    for sy in 0..supersample {
        let offset_y = start + sy as f32 * step;
        let sample_py = py + offset_y;
        for sx in 0..supersample {
            let offset_x = start + sx as f32 * step;
            let sample_px = px + offset_x;
            if let Some(sample) = capsule_coverage_sample(
                sample_px,
                sample_py,
                ax,
                ay,
                abx,
                aby,
                inv_len_sq,
                include_start_cap,
                variable_radius,
                start_radius,
                radius_delta,
                feather,
                antialias_level,
            ) {
                accum += sample.coverage;
            }
        }
    }
    let inv = 1.0 / (supersample * supersample) as f32;
    accum * inv
}

fn signed_distance_to_polygon(px: f32, py: f32, vertices: &[(f32, f32)]) -> f32 {
    let count = vertices.len();
    if count < 3 {
        return f32::INFINITY;
    }
    let mut min_dist_sq = f32::INFINITY;
    let mut inside = false;
    for i in 0..count {
        let (ax, ay) = vertices[i];
        let (bx, by) = vertices[(i + 1) % count];
        let abx = bx - ax;
        let aby = by - ay;
        let mut proj = 0.0;
        let denom = abx * abx + aby * aby;
        if denom > 0.0 {
            proj = ((px - ax) * abx + (py - ay) * aby) / denom;
            if proj < 0.0 {
                proj = 0.0;
            } else if proj > 1.0 {
                proj = 1.0;
            }
        }
        let closest_x = ax + abx * proj;
        let closest_y = ay + aby * proj;
        let dx = px - closest_x;
        let dy = py - closest_y;
        let dist_sq = dx * dx + dy * dy;
        if dist_sq < min_dist_sq {
            min_dist_sq = dist_sq;
        }
        if (ay > py) != (by > py) {
            let x = ax + (bx - ax) * (py - ay) / (by - ay);
            if px < x {
                inside = !inside;
            }
        }
    }
    let distance = (min_dist_sq.max(0.0)).sqrt();
    if inside { -distance } else { distance }
}

fn polygon_coverage_at_point(px: f32, py: f32, vertices: &[(f32, f32)], feather: f32) -> f32 {
    let signed_distance = signed_distance_to_polygon(px, py, vertices);
    if !signed_distance.is_finite() {
        return 0.0;
    }
    if feather <= 0.0 {
        return if signed_distance <= 0.0 { 1.0 } else { 0.0 };
    }
    if signed_distance <= -feather {
        return 1.0;
    }
    if signed_distance >= feather {
        return 0.0;
    }
    (feather - signed_distance) / (2.0 * feather)
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

#[no_mangle]
pub extern "C" fn cpu_brush_draw_capsule_segment(
    pixels_ptr: *mut u32,
    pixels_len: usize,
    width: u32,
    height: u32,
    ax: f32,
    ay: f32,
    bx: f32,
    by: f32,
    start_radius: f32,
    end_radius: f32,
    color_argb: u32,
    antialias_level: u32,
    include_start_cap: u8,
    erase: u8,
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

    let max_radius = start_radius.abs().max(end_radius.abs()).max(0.0);
    if max_radius <= 0.0 {
        return 1;
    }
    let abx = bx - ax;
    let aby = by - ay;
    let len_sq = abx * abx + aby * aby;
    let aa_level = antialias_level.min(9);
    let feather = antialias_feather(aa_level);
    let include_start = include_start_cap != 0;

    let src_a = unpack_a(color_argb);
    let src_r = unpack_r(color_argb);
    let src_g = unpack_g(color_argb);
    let src_b = unpack_b(color_argb);

    if len_sq <= 1.0e-6 {
        let expand = max_radius + feather + 1.5;
        let min_x = (ax - expand).floor().max(0.0) as i32;
        let max_x = (ax + expand).ceil().min((width as f32) - 1.0) as i32;
        let min_y = (ay - expand).floor().max(0.0) as i32;
        let max_y = (ay + expand).ceil().min((height as f32) - 1.0) as i32;
        if min_x > max_x || min_y > max_y {
            return 1;
        }
        for y in min_y..=max_y {
            let py = y as f32 + 0.5;
            let row = (y as usize) * (width as usize);
            for x in min_x..=max_x {
                let idx = row + (x as usize);
                if let Some(mask) = selection {
                    if mask.get(idx).copied().unwrap_or(0) == 0 {
                        continue;
                    }
                }
                let px = x as f32 + 0.5;
                let dx = px - ax;
                let dy = py - ay;
                let distance = (dx * dx + dy * dy).sqrt();
                let coverage =
                    compute_pixel_coverage(dx, dy, distance, max_radius, feather, aa_level);
                if coverage <= 0.0 {
                    continue;
                }
                let dst = pixels[idx];
                let alpha = if coverage >= 0.999 {
                    src_a
                } else {
                    clamp01(coverage * src_a)
                };
                if alpha <= 0.0 {
                    continue;
                }
                pixels[idx] = if erase != 0 {
                    blend_erase(dst, alpha)
                } else {
                    blend_paint(dst, src_r, src_g, src_b, alpha)
                };
            }
        }
        return 1;
    }

    let inv_len_sq = 1.0 / len_sq;
    let expand = max_radius + feather + 1.5;
    let min_x = (ax.min(bx) - expand).floor().max(0.0) as i32;
    let max_x = (ax.max(bx) + expand).ceil().min((width as f32) - 1.0) as i32;
    let min_y = (ay.min(by) - expand).floor().max(0.0) as i32;
    let max_y = (ay.max(by) + expand).ceil().min((height as f32) - 1.0) as i32;
    if min_x > max_x || min_y > max_y {
        return 1;
    }

    let variable_radius = (start_radius - end_radius).abs() > 1.0e-6;
    let radius_delta = end_radius - start_radius;

    for y in min_y..=max_y {
        let py = y as f32 + 0.5;
        let row = (y as usize) * (width as usize);
        for x in min_x..=max_x {
            let idx = row + (x as usize);
            if let Some(mask) = selection {
                if mask.get(idx).copied().unwrap_or(0) == 0 {
                    continue;
                }
            }
            let px = x as f32 + 0.5;
            let Some(center_sample) = capsule_coverage_sample(
                px,
                py,
                ax,
                ay,
                abx,
                aby,
                inv_len_sq,
                include_start,
                variable_radius,
                start_radius,
                radius_delta,
                feather,
                aa_level,
            ) else {
                continue;
            };
            let mut coverage = center_sample.coverage;
            if coverage <= 0.0 {
                continue;
            }
            if needs_supersampling(center_sample.radius, aa_level) {
                let supersample = supersample_factor(center_sample.radius);
                coverage = supersample_capsule_coverage(
                    px,
                    py,
                    ax,
                    ay,
                    abx,
                    aby,
                    inv_len_sq,
                    include_start,
                    variable_radius,
                    start_radius,
                    radius_delta,
                    feather,
                    aa_level,
                    supersample,
                );
                if coverage <= 0.0 {
                    continue;
                }
            }
            let dst = pixels[idx];
            let alpha = if coverage >= 0.999 {
                src_a
            } else {
                clamp01(coverage * src_a)
            };
            if alpha <= 0.0 {
                continue;
            }
            pixels[idx] = if erase != 0 {
                blend_erase(dst, alpha)
            } else {
                blend_paint(dst, src_r, src_g, src_b, alpha)
            };
        }
    }

    1
}

#[no_mangle]
pub extern "C" fn cpu_brush_fill_polygon(
    pixels_ptr: *mut u32,
    pixels_len: usize,
    width: u32,
    height: u32,
    vertices_ptr: *const f32,
    vertices_len: usize,
    radius: f32,
    color_argb: u32,
    antialias_level: u32,
    softness: f32,
    erase: u8,
    selection_ptr: *const u8,
    selection_len: usize,
) -> u8 {
    if pixels_ptr.is_null() || width == 0 || height == 0 {
        return 0;
    }
    if vertices_ptr.is_null() || vertices_len < 6 {
        return 0;
    }
    let pixel_count = (width as usize).saturating_mul(height as usize);
    if pixel_count == 0 || pixels_len < pixel_count {
        return 0;
    }

    let vertices_floats = unsafe { std::slice::from_raw_parts(vertices_ptr, vertices_len) };
    let mut vertices: Vec<(f32, f32)> = Vec::with_capacity(vertices_len / 2);
    let mut min_x = f32::INFINITY;
    let mut max_x = f32::NEG_INFINITY;
    let mut min_y = f32::INFINITY;
    let mut max_y = f32::NEG_INFINITY;
    let mut iter = vertices_floats.chunks_exact(2);
    for chunk in &mut iter {
        let x = chunk[0];
        let y = chunk[1];
        if !x.is_finite() || !y.is_finite() {
            return 0;
        }
        if x < min_x {
            min_x = x;
        }
        if x > max_x {
            max_x = x;
        }
        if y < min_y {
            min_y = y;
        }
        if y > max_y {
            max_y = y;
        }
        vertices.push((x, y));
    }
    if vertices.len() < 3 {
        return 0;
    }
    if !min_x.is_finite() || !max_x.is_finite() || !min_y.is_finite() || !max_y.is_finite() {
        return 0;
    }

    let aa_level = antialias_level.min(9);
    let base_feather = antialias_feather(aa_level);
    let soft = clamp01(softness);
    let softness_feather = radius * soft;
    let feather = if aa_level > 0 {
        base_feather.max(softness_feather)
    } else {
        softness_feather
    };
    let padding = feather + 1.5;
    let min_px = (min_x - padding).floor().max(0.0) as i32;
    let max_px = (max_x + padding).ceil().min((width as f32) - 1.0) as i32;
    let min_py = (min_y - padding).floor().max(0.0) as i32;
    let max_py = (max_y + padding).ceil().min((height as f32) - 1.0) as i32;
    if min_px > max_px || min_py > max_py {
        return 1;
    }

    let mut supersample = 1;
    let mut step = 1.0;
    let mut start = 0.0;
    let mut inv_sample_count = 1.0;
    if aa_level > 0 {
        let requires_supersampling = needs_supersampling(radius, aa_level);
        let adaptive_samples = if requires_supersampling {
            supersample_factor(radius).clamp(1, 6)
        } else {
            1
        };
        let desired_samples = (aa_level + 1) as i32 * 2;
        supersample = adaptive_samples.max(desired_samples).clamp(2, 6);
        step = 1.0 / supersample as f32;
        start = -0.5 + step * 0.5;
        inv_sample_count = 1.0 / (supersample * supersample) as f32;
    }

    let pixels = unsafe { std::slice::from_raw_parts_mut(pixels_ptr, pixels_len) };
    let selection = if selection_ptr.is_null() || selection_len < pixel_count {
        None
    } else {
        Some(unsafe { std::slice::from_raw_parts(selection_ptr, selection_len) })
    };

    let src_a = unpack_a(color_argb);
    let src_r = unpack_r(color_argb);
    let src_g = unpack_g(color_argb);
    let src_b = unpack_b(color_argb);

    for y in min_py..=max_py {
        let py = y as f32 + 0.5;
        let row = (y as usize) * (width as usize);
        for x in min_px..=max_px {
            let idx = row + (x as usize);
            if let Some(mask) = selection {
                if mask.get(idx).copied().unwrap_or(0) == 0 {
                    continue;
                }
            }
            let mut coverage = 0.0;
            if supersample <= 1 {
                coverage = polygon_coverage_at_point(x as f32 + 0.5, py, &vertices, feather);
            } else {
                let mut accumulated = 0.0;
                for sy in 0..supersample {
                    let offset_y = start + sy as f32 * step;
                    let sample_py = py + offset_y;
                    for sx in 0..supersample {
                        let offset_x = start + sx as f32 * step;
                        let sample_px = x as f32 + 0.5 + offset_x;
                        accumulated +=
                            polygon_coverage_at_point(sample_px, sample_py, &vertices, feather);
                    }
                }
                coverage = accumulated * inv_sample_count;
            }
            if coverage <= 0.0 {
                continue;
            }
            let dst = pixels[idx];
            let alpha = if coverage >= 0.999 {
                src_a
            } else {
                clamp01(coverage * src_a)
            };
            if alpha <= 0.0 {
                continue;
            }
            pixels[idx] = if erase != 0 {
                blend_erase(dst, alpha)
            } else {
                blend_paint(dst, src_r, src_g, src_b, alpha)
            };
        }
    }

    1
}
