use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

use crate::gpu::compositor::{GpuCompositor, LayerData};
use crate::gpu::debug::{self, LogLevel};

static GPU_COMPOSITOR: OnceLock<Mutex<Option<GpuCompositor>>> = OnceLock::new();

fn compositor_cell() -> &'static Mutex<Option<GpuCompositor>> {
    GPU_COMPOSITOR.get_or_init(|| Mutex::new(None))
}

#[flutter_rust_bridge::frb]
pub struct GpuLayerData {
    pub pixels: Vec<u32>,
    pub opacity: f64,
    pub blend_mode_index: u32,
    pub visible: bool,
    pub clipping_mask: bool,
}

#[flutter_rust_bridge::frb(sync)]
pub fn gpu_compositor_init() -> Result<(), String> {
    let mut guard = compositor_cell()
        .lock()
        .map_err(|_| "gpu compositor lock poisoned".to_string())?;
    if guard.is_some() {
        return Ok(());
    }
    let t0 = Instant::now();
    let compositor = GpuCompositor::new()?;
    *guard = Some(compositor);
    debug::log(
        LogLevel::Info,
        format_args!("gpu_compositor_init ok in {:?}.", t0.elapsed()),
    );
    Ok(())
}

pub fn gpu_composite_layers(
    layers: Vec<GpuLayerData>,
    width: u32,
    height: u32,
) -> Result<Vec<u32>, String> {
    let seq = debug::next_seq();
    let t0 = Instant::now();

    if width == 0 || height == 0 {
        return Ok(Vec::new());
    }

    let mut guard = compositor_cell()
        .lock()
        .map_err(|_| "gpu compositor lock poisoned".to_string())?;
    if guard.is_none() {
        let result = cpu_composite_layers(&layers, width, height);
        let elapsed = t0.elapsed();
        match &result {
            Ok(out) => {
                let out_len = out.len() as u64;
                if elapsed >= Duration::from_millis(50) {
                    debug::log(
                        LogLevel::Warn,
                        format_args!(
                            "#{seq} cpu_composite_layers SLOW ok out_len={out_len} in {:?}.",
                            elapsed
                        ),
                    );
                } else {
                    debug::log(
                        LogLevel::Verbose,
                        format_args!(
                            "#{seq} cpu_composite_layers ok out_len={out_len} in {:?}.",
                            elapsed
                        ),
                    );
                }
            }
            Err(err) => {
                debug::log(
                    LogLevel::Warn,
                    format_args!("#{seq} cpu_composite_layers ERR in {:?}: {err}", elapsed),
                );
            }
        }
        return result;
    }
    let compositor = guard
        .as_mut()
        .ok_or_else(|| "gpu compositor not initialized".to_string())?;

    let pixel_count_u64 = (width as u64).saturating_mul(height as u64);
    let expected_len_u64 = pixel_count_u64;

    let mut non_empty_layers: usize = 0;
    let mut empty_layers: usize = 0;
    let mut mismatched_layers: usize = 0;
    let mut total_input_u32: u64 = 0;
    for layer in &layers {
        let len = layer.pixels.len() as u64;
        total_input_u32 = total_input_u32.saturating_add(len);
        if layer.pixels.is_empty() {
            empty_layers += 1;
            continue;
        }
        non_empty_layers += 1;
        if expected_len_u64 > 0 && len != expected_len_u64 {
            mismatched_layers += 1;
        }
    }

    debug::log(
        LogLevel::Info,
        format_args!(
            "#{seq} gpu_composite_layers canvas={width}x{height} layers={} upload_layers={non_empty_layers} empty_layers={empty_layers} mismatched_layers={mismatched_layers} total_input_u32={total_input_u32}",
            layers.len()
        ),
    );
    if !layers.is_empty() && non_empty_layers == 0 {
        debug::log(
            LogLevel::Warn,
            format_args!(
                "#{seq} gpu_composite_layers: ALL layers have empty pixels (canvas={width}x{height}); compositor will rely on cached GPU state"
            ),
        );
    }
    if mismatched_layers > 0 {
        debug::log(
            LogLevel::Warn,
            format_args!(
                "#{seq} gpu_composite_layers: {mismatched_layers} layer(s) pixel length mismatch vs expected={expected_len_u64}"
            ),
        );
    }
    if debug::level() >= LogLevel::Verbose {
        for (idx, layer) in layers.iter().enumerate() {
            debug::log(
                LogLevel::Verbose,
                format_args!(
                    "#{seq}  layer[{idx}] pixels_len={} opacity={:.3} visible={} clip={} blend={}",
                    layer.pixels.len(),
                    layer.opacity,
                    layer.visible,
                    layer.clipping_mask,
                    layer.blend_mode_index
                ),
            );
        }
    }

    let converted: Vec<LayerData> = layers
        .into_iter()
        .map(|layer| LayerData {
            pixels: layer.pixels,
            opacity: clamp_unit_f64_to_f32(layer.opacity),
            blend_mode: layer.blend_mode_index,
            visible: layer.visible,
            clipping_mask: layer.clipping_mask,
        })
        .collect();

    let result = compositor.composite_layers(converted, width, height);

    let elapsed = t0.elapsed();
    match &result {
        Ok(out) => {
            let out_len = out.len() as u64;
            if elapsed >= Duration::from_millis(50) {
                debug::log(
                    LogLevel::Warn,
                    format_args!(
                        "#{seq} gpu_composite_layers SLOW ok out_len={out_len} in {:?}.",
                        elapsed
                    ),
                );
            } else {
                debug::log(
                    LogLevel::Verbose,
                    format_args!(
                        "#{seq} gpu_composite_layers ok out_len={out_len} in {:?}.",
                        elapsed
                    ),
                );
            }
        }
        Err(err) => {
            debug::log(
                LogLevel::Warn,
                format_args!("#{seq} gpu_composite_layers ERR in {:?}: {err}", elapsed),
            );
        }
    }

    result
}

#[flutter_rust_bridge::frb(sync)]
pub fn gpu_compositor_dispose() {
    if let Some(cell) = GPU_COMPOSITOR.get() {
        if let Ok(mut guard) = cell.lock() {
            *guard = None;
        }
    }
}

const EPS: f32 = 1.0e-7;

fn cpu_composite_layers(
    layers: &[GpuLayerData],
    width: u32,
    height: u32,
) -> Result<Vec<u32>, String> {
    let pixel_count_u64 = (width as u64).saturating_mul(height as u64);
    if pixel_count_u64 > usize::MAX as u64 {
        return Err("cpu_composite_layers: canvas too large".to_string());
    }
    let pixel_count = pixel_count_u64 as usize;
    if pixel_count == 0 {
        return Ok(Vec::new());
    }

    let expected_len = pixel_count;
    let mut layer_slices: Vec<Option<&[u32]>> = Vec::with_capacity(layers.len());
    for layer in layers {
        if layer.pixels.len() == expected_len {
            layer_slices.push(Some(layer.pixels.as_slice()));
        } else {
            layer_slices.push(None);
        }
    }

    let mut out = vec![0u32; pixel_count];
    for idx in 0..pixel_count {
        let mut dst: u32 = 0;
        let mut initialized = false;
        let mut mask_alpha: f32 = 0.0;

        for (layer_index, layer) in layers.iter().enumerate() {
            if !layer.visible {
                continue;
            }

            let opacity = clamp_unit_f64_to_f32(layer.opacity);
            if opacity <= 0.0 {
                if !layer.clipping_mask {
                    mask_alpha = 0.0;
                }
                continue;
            }

            let src = match layer_slices[layer_index] {
                Some(slice) => slice[idx],
                None => 0,
            };
            let src_a_u8 = ((src >> 24) & 0xFF) as u32;
            if src_a_u8 == 0 {
                if !layer.clipping_mask {
                    mask_alpha = 0.0;
                }
                continue;
            }

            let mut total_opacity = opacity;
            if layer.clipping_mask {
                if mask_alpha <= 0.0 {
                    continue;
                }
                total_opacity *= mask_alpha;
                if total_opacity <= 0.0 {
                    continue;
                }
            }

            let src_a = src_a_u8 as f32 / 255.0;
            let mut effective_a = src_a * total_opacity;
            if effective_a <= 0.0 {
                if !layer.clipping_mask {
                    mask_alpha = 0.0;
                }
                continue;
            }
            effective_a = clamp01(effective_a);

            if !layer.clipping_mask {
                mask_alpha = effective_a;
            }

            let effective_a_u8 = to_u8(effective_a);
            let effective_color = (effective_a_u8 << 24) | (src & 0x00FFFFFF);

            if !initialized {
                dst = effective_color;
                initialized = true;
            } else {
                dst = blend_argb(dst, effective_color, layer.blend_mode_index, idx as u32);
            }
        }

        out[idx] = if initialized { dst } else { 0 };
    }

    Ok(out)
}

fn clamp01(x: f32) -> f32 {
    if x <= 0.0 {
        return 0.0;
    }
    if x >= 1.0 {
        return 1.0;
    }
    x
}

fn to_u8(x: f32) -> u32 {
    let v = (clamp01(x) * 255.0 + 0.5).floor();
    let clamped = if v < 0.0 {
        0.0
    } else if v > 255.0 {
        255.0
    } else {
        v
    };
    clamped as u32
}

fn pack_argb(a: f32, r: f32, g: f32, b: f32) -> u32 {
    let aa = to_u8(a);
    let rr = to_u8(r);
    let gg = to_u8(g);
    let bb = to_u8(b);
    (aa << 24) | (rr << 16) | (gg << 8) | bb
}

fn unpack_a(c: u32) -> f32 {
    ((c >> 24) & 0xFF) as f32 / 255.0
}

fn unpack_r(c: u32) -> f32 {
    ((c >> 16) & 0xFF) as f32 / 255.0
}

fn unpack_g(c: u32) -> f32 {
    ((c >> 8) & 0xFF) as f32 / 255.0
}

fn unpack_b(c: u32) -> f32 {
    (c & 0xFF) as f32 / 255.0
}

fn blend_color_burn(s: f32, d: f32) -> f32 {
    if s <= EPS {
        return 0.0;
    }
    1.0 - ((1.0 - d) / s).min(1.0)
}

fn blend_color_dodge(s: f32, d: f32) -> f32 {
    if s >= 1.0 - EPS {
        return 1.0;
    }
    (d / (1.0 - s)).min(1.0)
}

fn blend_overlay(s: f32, d: f32) -> f32 {
    if d <= 0.5 {
        return 2.0 * s * d;
    }
    1.0 - 2.0 * (1.0 - s) * (1.0 - d)
}

fn blend_hard_light(s: f32, d: f32) -> f32 {
    if s <= 0.5 {
        return 2.0 * s * d;
    }
    1.0 - 2.0 * (1.0 - s) * (1.0 - d)
}

fn soft_light_lum(d: f32) -> f32 {
    if d <= 0.25 {
        return ((16.0 * d - 12.0) * d + 4.0) * d;
    }
    d.sqrt()
}

fn blend_soft_light(s: f32, d: f32) -> f32 {
    if s <= 0.5 {
        return d - (1.0 - 2.0 * s) * d * (1.0 - d);
    }
    d + (2.0 * s - 1.0) * (soft_light_lum(d) - d)
}

fn blend_vivid_light(s: f32, d: f32) -> f32 {
    if s <= 0.5 {
        if s <= EPS {
            return 0.0;
        }
        return 1.0 - ((1.0 - d) / (2.0 * s)).min(1.0);
    }
    if s >= 1.0 - EPS {
        return 1.0;
    }
    (d / (2.0 * (1.0 - s))).min(1.0)
}

fn blend_pin_light(s: f32, d: f32) -> f32 {
    if s <= 0.5 {
        return d.min(2.0 * s);
    }
    d.max(2.0 * s - 1.0)
}

fn blend_hard_mix(s: f32, d: f32) -> f32 {
    if blend_vivid_light(s, d) < 0.5 {
        return 0.0;
    }
    1.0
}

fn blend_divide(s: f32, d: f32) -> f32 {
    if s <= EPS {
        return 1.0;
    }
    clamp01(d / s)
}

fn mix_hash(hash: u32, value: u32) -> u32 {
    let mut mixed = hash ^ value;
    mixed = mixed.wrapping_mul(0x7FEB352D);
    mixed ^= mixed >> 15;
    mixed = mixed.wrapping_mul(0x846CA68B);
    mixed ^= mixed >> 16;
    mixed
}

fn pseudo_random(index: u32, src: u32, dst: u32) -> f32 {
    let mut hash = 0x9E3779B9u32;
    hash = mix_hash(hash, index);
    hash = mix_hash(hash, src);
    hash = mix_hash(hash, dst);
    hash ^= hash >> 16;
    hash as f32 / 4294967295.0
}

fn rgb_to_hsl(r: f32, g: f32, b: f32) -> (f32, f32, f32) {
    let maxc = r.max(g).max(b);
    let minc = r.min(g).min(b);
    let l = (maxc + minc) * 0.5;
    let mut h = 0.0;
    let mut s = 0.0;
    if (maxc - minc).abs() > EPS {
        let d = maxc - minc;
        if l > 0.5 {
            s = d / (2.0 - maxc - minc);
        } else {
            s = d / (maxc + minc);
        }
        if (maxc - r).abs() <= EPS {
            h = (g - b) / d;
            if g < b {
                h += 6.0;
            }
        } else if (maxc - g).abs() <= EPS {
            h = (b - r) / d + 2.0;
        } else {
            h = (r - g) / d + 4.0;
        }
        h /= 6.0;
    }
    (h, s, l)
}

fn hue_to_rgb(p: f32, q: f32, t: f32) -> f32 {
    let mut tt = t;
    if tt < 0.0 {
        tt += 1.0;
    }
    if tt > 1.0 {
        tt -= 1.0;
    }
    if tt < 1.0 / 6.0 {
        return p + (q - p) * 6.0 * tt;
    }
    if tt < 0.5 {
        return q;
    }
    if tt < 2.0 / 3.0 {
        return p + (q - p) * (2.0 / 3.0 - tt) * 6.0;
    }
    p
}

fn hsl_to_rgb(h: f32, s: f32, l: f32) -> (f32, f32, f32) {
    if s <= 0.0 {
        return (l, l, l);
    }
    let q = if l >= 0.5 {
        l + s - l * s
    } else {
        l * (1.0 + s)
    };
    let p = 2.0 * l - q;
    let r = hue_to_rgb(p, q, h + 1.0 / 3.0);
    let g = hue_to_rgb(p, q, h);
    let b = hue_to_rgb(p, q, h - 1.0 / 3.0);
    (r, g, b)
}

fn blend_channel(mode: u32, s: f32, d: f32) -> f32 {
    match mode {
        0 => s,
        1 => s * d,
        3 => s.min(d),
        4 => blend_color_burn(s, d),
        5 => clamp01(d + s - 1.0),
        7 => s.max(d),
        8 => 1.0 - (1.0 - s) * (1.0 - d),
        9 => blend_color_dodge(s, d),
        10 => clamp01(d + s),
        12 => blend_overlay(s, d),
        13 => blend_soft_light(s, d),
        14 => blend_hard_light(s, d),
        15 => blend_vivid_light(s, d),
        16 => clamp01(d + 2.0 * s - 1.0),
        17 => blend_pin_light(s, d),
        18 => blend_hard_mix(s, d),
        19 => (d - s).abs(),
        20 => d + s - 2.0 * d * s,
        21 => 0.0f32.max(d - s),
        22 => blend_divide(s, d),
        _ => s,
    }
}

fn blend_argb(dst: u32, src: u32, mode: u32, pixel_index: u32) -> u32 {
    let sa = unpack_a(src);
    if sa <= 0.0 {
        return dst;
    }

    let da = unpack_a(dst);
    let sr = unpack_r(src);
    let sg = unpack_g(src);
    let sb = unpack_b(src);
    let dr = unpack_r(dst);
    let dg = unpack_g(dst);
    let db = unpack_b(dst);

    if mode == 2 {
        let noise = pseudo_random(pixel_index, src, dst);
        if noise > sa {
            return dst;
        }
        return pack_argb(1.0, sr, sg, sb);
    }

    let mut fr = sr;
    let mut fg = sg;
    let mut fb = sb;
    if mode == 6 || mode == 11 {
        let src_sum = (sr + sg + sb) * sa;
        let dst_sum = (dr + dg + db) * da;
        let use_src = (mode == 6 && src_sum < dst_sum) || (mode == 11 && src_sum > dst_sum);
        if !use_src {
            fr = dr;
            fg = dg;
            fb = db;
        }
    } else if mode >= 23 {
        let (src_h, src_s, src_l) = rgb_to_hsl(sr, sg, sb);
        let (dst_h, dst_s, dst_l) = rgb_to_hsl(dr, dg, db);
        let (out_h, out_s, out_l) = match mode {
            23 => (src_h, dst_s, dst_l),
            24 => (dst_h, src_s, dst_l),
            25 => (src_h, src_s, dst_l),
            26 => (dst_h, dst_s, src_l),
            _ => (dst_h, dst_s, dst_l),
        };
        let (r, g, b) = hsl_to_rgb(out_h, out_s, out_l);
        fr = r;
        fg = g;
        fb = b;
    } else {
        fr = blend_channel(mode, sr, dr);
        fg = blend_channel(mode, sg, dg);
        fb = blend_channel(mode, sb, db);
    }

    let out_a = sa + da * (1.0 - sa);
    if out_a <= 0.0 {
        return 0;
    }

    let rr = ((fr * sa) + dr * da * (1.0 - sa)) / out_a;
    let rg = ((fg * sa) + dg * da * (1.0 - sa)) / out_a;
    let rb = ((fb * sa) + db * da * (1.0 - sa)) / out_a;

    pack_argb(out_a, rr, rg, rb)
}

fn clamp_unit_f64_to_f32(value: f64) -> f32 {
    if !value.is_finite() {
        return 0.0;
    }
    let clamped = value.clamp(0.0, 1.0);
    clamped as f32
}
