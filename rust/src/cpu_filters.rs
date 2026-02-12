const ANTIALIAS_CENTER_WEIGHT: i32 = 4;
const ANTIALIAS_DX: [i32; 8] = [-1, 0, 1, -1, 1, -1, 0, 1];
const ANTIALIAS_DY: [i32; 8] = [-1, -1, -1, 0, 0, 1, 1, 1];
const ANTIALIAS_WEIGHTS: [i32; 8] = [1, 2, 1, 2, 2, 1, 2, 1];

static ANTIALIAS_PROFILE_0: [f32; 1] = [0.25];
static ANTIALIAS_PROFILE_1: [f32; 2] = [0.35, 0.35];
static ANTIALIAS_PROFILE_2: [f32; 3] = [0.45, 0.5, 0.5];
static ANTIALIAS_PROFILE_3: [f32; 4] = [0.6, 0.65, 0.7, 0.75];
static ANTIALIAS_PROFILE_4: [f32; 5] = [0.6, 0.65, 0.7, 0.75, 0.8];
static ANTIALIAS_PROFILE_5: [f32; 5] = [0.65, 0.7, 0.75, 0.8, 0.85];
static ANTIALIAS_PROFILE_6: [f32; 5] = [0.7, 0.75, 0.8, 0.85, 0.9];
static ANTIALIAS_PROFILE_7: [f32; 6] = [0.7, 0.75, 0.8, 0.85, 0.9, 0.9];
static ANTIALIAS_PROFILE_8: [f32; 6] = [0.75, 0.8, 0.85, 0.9, 0.9, 0.9];
static ANTIALIAS_PROFILE_9: [f32; 6] = [0.8, 0.85, 0.9, 0.9, 0.9, 0.9];

static ANTIALIAS_PROFILES: [&[f32]; 10] = [
    &ANTIALIAS_PROFILE_0,
    &ANTIALIAS_PROFILE_1,
    &ANTIALIAS_PROFILE_2,
    &ANTIALIAS_PROFILE_3,
    &ANTIALIAS_PROFILE_4,
    &ANTIALIAS_PROFILE_5,
    &ANTIALIAS_PROFILE_6,
    &ANTIALIAS_PROFILE_7,
    &ANTIALIAS_PROFILE_8,
    &ANTIALIAS_PROFILE_9,
];

const EDGE_DETECT_MIN: f32 = 0.015;
const EDGE_DETECT_MAX: f32 = 0.4;
const EDGE_SMOOTH_STRENGTH: f32 = 1.0;
const EDGE_SMOOTH_GAMMA: f32 = 0.55;

const GAUSSIAN_KERNEL_5X5: [i32; 25] = [
    1, 4, 6, 4, 1, 4, 16, 24, 16, 4, 6, 24, 36, 24, 6, 4, 16, 24, 16, 4, 1, 4, 6, 4,
    1,
];

fn clamp_u8(value: i32) -> u8 {
    if value <= 0 {
        0
    } else if value >= 255 {
        255
    } else {
        value as u8
    }
}

fn antialias_pass(
    src: &[u32],
    dest: &mut [u32],
    width: usize,
    height: usize,
    factor: f32,
) -> bool {
    dest.copy_from_slice(src);
    if factor <= 0.0 {
        return false;
    }
    let factor = factor.clamp(0.0, 1.0);
    let mut modified = false;
    for y in 0..height {
        let row_offset = y * width;
        for x in 0..width {
            let index = row_offset + x;
            let center = src[index];
            let alpha = ((center >> 24) & 0xff) as i32;
            let center_r = ((center >> 16) & 0xff) as i32;
            let center_g = ((center >> 8) & 0xff) as i32;
            let center_b = (center & 0xff) as i32;

            let mut total_weight = ANTIALIAS_CENTER_WEIGHT;
            let mut weighted_alpha = alpha * ANTIALIAS_CENTER_WEIGHT;
            let mut weighted_premul_r =
                (center_r * alpha * ANTIALIAS_CENTER_WEIGHT) as i64;
            let mut weighted_premul_g =
                (center_g * alpha * ANTIALIAS_CENTER_WEIGHT) as i64;
            let mut weighted_premul_b =
                (center_b * alpha * ANTIALIAS_CENTER_WEIGHT) as i64;

            for i in 0..ANTIALIAS_DX.len() {
                let nx = x as i32 + ANTIALIAS_DX[i];
                let ny = y as i32 + ANTIALIAS_DY[i];
                if nx < 0 || ny < 0 || nx >= width as i32 || ny >= height as i32 {
                    continue;
                }
                let neighbor = src[ny as usize * width + nx as usize];
                let neighbor_alpha = ((neighbor >> 24) & 0xff) as i32;
                let weight = ANTIALIAS_WEIGHTS[i];
                total_weight += weight;
                if neighbor_alpha == 0 {
                    continue;
                }
                weighted_alpha += neighbor_alpha * weight;
                let nr = ((neighbor >> 16) & 0xff) as i32;
                let ng = ((neighbor >> 8) & 0xff) as i32;
                let nb = (neighbor & 0xff) as i32;
                weighted_premul_r += (nr * neighbor_alpha * weight) as i64;
                weighted_premul_g += (ng * neighbor_alpha * weight) as i64;
                weighted_premul_b += (nb * neighbor_alpha * weight) as i64;
            }

            if total_weight <= 0 {
                continue;
            }
            let mut candidate_alpha = weighted_alpha / total_weight;
            if candidate_alpha < 0 {
                candidate_alpha = 0;
            } else if candidate_alpha > 255 {
                candidate_alpha = 255;
            }
            let delta_alpha = candidate_alpha - alpha;
            if delta_alpha == 0 {
                continue;
            }

            let delta = (delta_alpha as f32 * factor).round() as i32;
            let mut new_alpha = alpha + delta;
            if new_alpha < 0 {
                new_alpha = 0;
            } else if new_alpha > 255 {
                new_alpha = 255;
            }
            if new_alpha == alpha {
                continue;
            }

            let mut new_r = center_r;
            let mut new_g = center_g;
            let mut new_b = center_b;
            if delta_alpha > 0 {
                let denom = weighted_alpha.max(1) as i64;
                new_r = (weighted_premul_r / denom).clamp(0, 255) as i32;
                new_g = (weighted_premul_g / denom).clamp(0, 255) as i32;
                new_b = (weighted_premul_b / denom).clamp(0, 255) as i32;
            }

            dest[index] = ((new_alpha as u32) << 24)
                | ((new_r as u32) << 16)
                | ((new_g as u32) << 8)
                | (new_b as u32);
            modified = true;
        }
    }
    modified
}

fn compute_luma(color: u32) -> f32 {
    let alpha = ((color >> 24) & 0xff) as i32;
    if alpha == 0 {
        return 0.0;
    }
    let r = ((color >> 16) & 0xff) as f32;
    let g = ((color >> 8) & 0xff) as f32;
    let b = (color & 0xff) as f32;
    (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
}

fn edge_gradient(src: &[u32], width: usize, height: usize, x: usize, y: usize) -> f32 {
    let index = y * width + x;
    let center = src[index];
    let alpha = ((center >> 24) & 0xff) as i32;
    if alpha == 0 {
        return 0.0;
    }
    let center_luma = compute_luma(center);
    let mut max_diff = 0.0;

    let mut accumulate = |nx: i32, ny: i32| {
        if nx < 0 || ny < 0 || nx >= width as i32 || ny >= height as i32 {
            return;
        }
        let neighbor = src[ny as usize * width + nx as usize];
        let neighbor_alpha = ((neighbor >> 24) & 0xff) as i32;
        if neighbor_alpha == 0 {
            return;
        }
        let diff = (center_luma - compute_luma(neighbor)).abs();
        if diff > max_diff {
            max_diff = diff;
        }
    };

    let x = x as i32;
    let y = y as i32;
    accumulate(x - 1, y);
    accumulate(x + 1, y);
    accumulate(x, y - 1);
    accumulate(x, y + 1);
    accumulate(x - 1, y - 1);
    accumulate(x + 1, y - 1);
    accumulate(x - 1, y + 1);
    accumulate(x + 1, y + 1);
    max_diff
}

fn edge_smooth_weight(gradient: f32) -> f32 {
    if gradient <= EDGE_DETECT_MIN {
        return 0.0;
    }
    let normalized = ((gradient - EDGE_DETECT_MIN) / (EDGE_DETECT_MAX - EDGE_DETECT_MIN))
        .clamp(0.0, 1.0);
    normalized.powf(EDGE_SMOOTH_GAMMA) * EDGE_SMOOTH_STRENGTH
}

fn lerp_argb(a: u32, b: u32, t: f32) -> u32 {
    let clamped_t = t.clamp(0.0, 1.0);
    let lerp_channel = |ca: i32, cb: i32| -> u8 {
        let v = ca as f32 + (cb - ca) as f32 * clamped_t;
        clamp_u8(v.round() as i32)
    };

    let a_a = ((a >> 24) & 0xff) as i32;
    let a_r = ((a >> 16) & 0xff) as i32;
    let a_g = ((a >> 8) & 0xff) as i32;
    let a_b = (a & 0xff) as i32;

    let b_a = ((b >> 24) & 0xff) as i32;
    let b_r = ((b >> 16) & 0xff) as i32;
    let b_g = ((b >> 8) & 0xff) as i32;
    let b_b = (b & 0xff) as i32;

    let out_a = lerp_channel(a_a, b_a);
    let out_r = lerp_channel(a_r, b_r);
    let out_g = lerp_channel(a_g, b_g);
    let out_b = lerp_channel(a_b, b_b);
    ((out_a as u32) << 24)
        | ((out_r as u32) << 16)
        | ((out_g as u32) << 8)
        | (out_b as u32)
}

fn gaussian_blur(src: &[u32], dest: &mut [u32], width: usize, height: usize) {
    for y in 0..height {
        for x in 0..width {
            let mut weighted_alpha = 0.0f32;
            let mut weighted_r = 0.0f32;
            let mut weighted_g = 0.0f32;
            let mut weighted_b = 0.0f32;
            let mut total_weight = 0.0f32;
            let mut kernel_index = 0usize;
            for ky in -2..=2 {
                let ny = (y as i32 + ky).clamp(0, height as i32 - 1) as usize;
                let row_offset = ny * width;
                for kx in -2..=2 {
                    let nx = (x as i32 + kx).clamp(0, width as i32 - 1) as usize;
                    let weight = GAUSSIAN_KERNEL_5X5[kernel_index] as f32;
                    kernel_index += 1;
                    let sample = src[row_offset + nx];
                    let alpha = ((sample >> 24) & 0xff) as f32;
                    if alpha == 0.0 {
                        continue;
                    }
                    total_weight += weight;
                    weighted_alpha += alpha * weight;
                    weighted_r += ((sample >> 16) & 0xff) as f32 * alpha * weight;
                    weighted_g += ((sample >> 8) & 0xff) as f32 * alpha * weight;
                    weighted_b += (sample & 0xff) as f32 * alpha * weight;
                }
            }
            if total_weight == 0.0 {
                dest[y * width + x] = src[y * width + x];
                continue;
            }
            let normalized_alpha = weighted_alpha / total_weight;
            let premul_alpha = weighted_alpha.max(1.0);
            let out_alpha = clamp_u8(normalized_alpha.round() as i32);
            let out_r = clamp_u8((weighted_r / premul_alpha).round() as i32);
            let out_g = clamp_u8((weighted_g / premul_alpha).round() as i32);
            let out_b = clamp_u8((weighted_b / premul_alpha).round() as i32);
            dest[y * width + x] = ((out_alpha as u32) << 24)
                | ((out_r as u32) << 16)
                | ((out_g as u32) << 8)
                | (out_b as u32);
        }
    }
}

fn edge_smooth_pass(
    src: &[u32],
    dest: &mut [u32],
    blur_buffer: &mut [u32],
    width: usize,
    height: usize,
) -> bool {
    gaussian_blur(src, blur_buffer, width, height);
    let mut modified = false;
    for y in 0..height {
        let row_offset = y * width;
        for x in 0..width {
            let index = row_offset + x;
            let base_color = src[index];
            let alpha = ((base_color >> 24) & 0xff) as i32;
            if alpha == 0 {
                dest[index] = base_color;
                continue;
            }
            let gradient = edge_gradient(src, width, height, x, y);
            let weight = edge_smooth_weight(gradient);
            if weight <= 0.0 {
                dest[index] = base_color;
                continue;
            }
            let blurred = blur_buffer[index];
            let new_color = lerp_argb(base_color, blurred, weight);
            dest[index] = new_color;
            if new_color != base_color {
                modified = true;
            }
        }
    }
    modified
}

#[no_mangle]
pub extern "C" fn cpu_filters_apply_antialias(
    pixels: *mut u32,
    pixels_len: u64,
    width: u32,
    height: u32,
    level: u32,
    preview_only: u8,
) -> u8 {
    if pixels.is_null() || pixels_len == 0 || width == 0 || height == 0 {
        return 0;
    }
    let expected_len = width as u64 * height as u64;
    if expected_len != pixels_len {
        return 0;
    }
    let len = pixels_len as usize;
    let pixels_slice = unsafe { std::slice::from_raw_parts_mut(pixels, len) };
    if len == 0 {
        return 0;
    }

    let level = level.min(9) as usize;
    let profile = match ANTIALIAS_PROFILES.get(level) {
        Some(p) => *p,
        None => return 0,
    };
    if profile.is_empty() {
        return 0;
    }

    let preview_only = preview_only != 0;
    let width = width as usize;
    let height = height as usize;

    let mut buffer_a = Vec::with_capacity(len);
    buffer_a.extend_from_slice(pixels_slice);
    let mut buffer_b = vec![0u32; len];
    let mut src_is_a = true;
    let mut any_change = false;

    for &factor in profile {
        if factor <= 0.0 {
            continue;
        }
        let (src, dest) = if src_is_a {
            (&buffer_a[..], &mut buffer_b[..])
        } else {
            (&buffer_b[..], &mut buffer_a[..])
        };
        let modified = antialias_pass(src, dest, width, height, factor);
        if !modified {
            continue;
        }
        if preview_only {
            return 1;
        }
        any_change = true;
        src_is_a = !src_is_a;
    }

    let mut blur_buffer = vec![0u32; len];
    let (src, dest) = if src_is_a {
        (&buffer_a[..], &mut buffer_b[..])
    } else {
        (&buffer_b[..], &mut buffer_a[..])
    };
    let color_changed = edge_smooth_pass(src, dest, &mut blur_buffer, width, height);
    if color_changed {
        if preview_only {
            return 1;
        }
        any_change = true;
        src_is_a = !src_is_a;
    }

    if !any_change {
        return 0;
    }
    if preview_only {
        return 1;
    }
    let final_buf = if src_is_a { &buffer_a } else { &buffer_b };
    pixels_slice.copy_from_slice(final_buf);
    1
}
