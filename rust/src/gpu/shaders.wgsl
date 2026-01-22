const MAX_LAYERS: u32 = 16u;
const EPS: f32 = 0.0000001;

struct LayerParams {
  opacity: f32,
  blend_mode: u32,
  visible: u32,
  clipping_mask: u32,
};

struct Config {
  width: u32,
  height: u32,
  layer_count: u32,
  _pad0: u32,
  layers: array<LayerParams, 16>,
};

@group(0) @binding(0)
var<storage, read> layer_pixels: array<u32>;

@group(0) @binding(1)
var<storage, read_write> out_pixels: array<u32>;

@group(0) @binding(2)
var<uniform> config: Config;

fn clamp01(x: f32) -> f32 {
  return clamp(x, 0.0, 1.0);
}

fn to_u8(x: f32) -> u32 {
  let v = floor(clamp01(x) * 255.0 + 0.5);
  return u32(clamp(v, 0.0, 255.0));
}

fn pack_argb(a: f32, r: f32, g: f32, b: f32) -> u32 {
  let aa = to_u8(a);
  let rr = to_u8(r);
  let gg = to_u8(g);
  let bb = to_u8(b);
  return (aa << 24u) | (rr << 16u) | (gg << 8u) | bb;
}

fn unpack_a(c: u32) -> f32 {
  return f32((c >> 24u) & 0xFFu) / 255.0;
}

fn unpack_r(c: u32) -> f32 {
  return f32((c >> 16u) & 0xFFu) / 255.0;
}

fn unpack_g(c: u32) -> f32 {
  return f32((c >> 8u) & 0xFFu) / 255.0;
}

fn unpack_b(c: u32) -> f32 {
  return f32(c & 0xFFu) / 255.0;
}

fn blend_color_burn(s: f32, d: f32) -> f32 {
  if (s <= EPS) {
    return 0.0;
  }
  return 1.0 - min(1.0, (1.0 - d) / s);
}

fn blend_color_dodge(s: f32, d: f32) -> f32 {
  if (s >= 1.0 - EPS) {
    return 1.0;
  }
  return min(1.0, d / (1.0 - s));
}

fn blend_overlay(s: f32, d: f32) -> f32 {
  if (d <= 0.5) {
    return 2.0 * s * d;
  }
  return 1.0 - 2.0 * (1.0 - s) * (1.0 - d);
}

fn blend_hard_light(s: f32, d: f32) -> f32 {
  if (s <= 0.5) {
    return 2.0 * s * d;
  }
  return 1.0 - 2.0 * (1.0 - s) * (1.0 - d);
}

fn soft_light_lum(d: f32) -> f32 {
  if (d <= 0.25) {
    return ((16.0 * d - 12.0) * d + 4.0) * d;
  }
  return sqrt(d);
}

fn blend_soft_light(s: f32, d: f32) -> f32 {
  if (s <= 0.5) {
    return d - (1.0 - 2.0 * s) * d * (1.0 - d);
  }
  return d + (2.0 * s - 1.0) * (soft_light_lum(d) - d);
}

fn blend_vivid_light(s: f32, d: f32) -> f32 {
  if (s <= 0.5) {
    if (s <= EPS) {
      return 0.0;
    }
    return 1.0 - min(1.0, (1.0 - d) / (2.0 * s));
  }
  if (s >= 1.0 - EPS) {
    return 1.0;
  }
  return min(1.0, d / (2.0 * (1.0 - s)));
}

fn blend_pin_light(s: f32, d: f32) -> f32 {
  if (s <= 0.5) {
    return min(d, 2.0 * s);
  }
  return max(d, 2.0 * s - 1.0);
}

fn blend_hard_mix(s: f32, d: f32) -> f32 {
  if (blend_vivid_light(s, d) < 0.5) {
    return 0.0;
  }
  return 1.0;
}

fn blend_divide(s: f32, d: f32) -> f32 {
  if (s <= EPS) {
    return 1.0;
  }
  return clamp01(d / s);
}

fn mix_hash(hash: u32, value: u32) -> u32 {
  var mixed = hash ^ value;
  mixed = mixed * 0x7FEB352Du;
  mixed = mixed ^ (mixed >> 15u);
  mixed = mixed * 0x846CA68Bu;
  mixed = mixed ^ (mixed >> 16u);
  return mixed;
}

fn pseudo_random(index: u32, src: u32, dst: u32) -> f32 {
  var hash = 0x9E3779B9u;
  hash = mix_hash(hash, index);
  hash = mix_hash(hash, src);
  hash = mix_hash(hash, dst);
  hash = hash ^ (hash >> 16u);
  return f32(hash) / 4294967295.0;
}

fn rgb_to_hsl(rgb: vec3<f32>) -> vec3<f32> {
  let r = rgb.r;
  let g = rgb.g;
  let b = rgb.b;
  let maxc = max(max(r, g), b);
  let minc = min(min(r, g), b);
  let l = (maxc + minc) * 0.5;

  var h = 0.0;
  var s = 0.0;
  if (maxc != minc) {
    let d = maxc - minc;
    if (l > 0.5) {
      s = d / (2.0 - maxc - minc);
    } else {
      s = d / (maxc + minc);
    }
    if (maxc == r) {
      h = (g - b) / d;
      if (g < b) {
        h = h + 6.0;
      }
    } else if (maxc == g) {
      h = (b - r) / d + 2.0;
    } else {
      h = (r - g) / d + 4.0;
    }
    h = h / 6.0;
  }
  return vec3<f32>(h, s, l);
}

fn hue_to_rgb(p: f32, q: f32, t: f32) -> f32 {
  var tt = t;
  if (tt < 0.0) {
    tt = tt + 1.0;
  }
  if (tt > 1.0) {
    tt = tt - 1.0;
  }
  if (tt < 1.0 / 6.0) {
    return p + (q - p) * 6.0 * tt;
  }
  if (tt < 0.5) {
    return q;
  }
  if (tt < 2.0 / 3.0) {
    return p + (q - p) * (2.0 / 3.0 - tt) * 6.0;
  }
  return p;
}

fn hsl_to_rgb(hsl: vec3<f32>) -> vec3<f32> {
  let h = hsl.x;
  let s = hsl.y;
  let l = hsl.z;
  if (s <= 0.0) {
    return vec3<f32>(l, l, l);
  }
  let q = select(l * (1.0 + s), l + s - l * s, l >= 0.5);
  let p = 2.0 * l - q;
  let r = hue_to_rgb(p, q, h + 1.0 / 3.0);
  let g = hue_to_rgb(p, q, h);
  let b = hue_to_rgb(p, q, h - 1.0 / 3.0);
  return vec3<f32>(r, g, b);
}

// GPU blend mode ids (mapped from Dart blend mode indices in Rust):
// 0 Normal, 1 Multiply, 2 Dissolve, 3 Darken, 4 ColorBurn, 5 LinearBurn, 6 DarkerColor,
// 7 Lighten, 8 Screen, 9 ColorDodge, 10 LinearDodge, 11 LighterColor, 12 Overlay, 13 SoftLight,
// 14 HardLight, 15 VividLight, 16 LinearLight, 17 PinLight, 18 HardMix, 19 Difference,
// 20 Exclusion, 21 Subtract, 22 Divide, 23 Hue, 24 Saturation, 25 Color, 26 Luminosity.
fn blend_channel(mode: u32, s: f32, d: f32) -> f32 {
  switch mode {
    default { return s; }
    case 0u { return s; }
    case 1u { return s * d; }
    case 3u { return min(s, d); }
    case 4u { return blend_color_burn(s, d); }
    case 5u { return clamp01(d + s - 1.0); }
    case 7u { return max(s, d); }
    case 8u { return 1.0 - (1.0 - s) * (1.0 - d); }
    case 9u { return blend_color_dodge(s, d); }
    case 10u { return clamp01(d + s); }
    case 12u { return blend_overlay(s, d); }
    case 13u { return blend_soft_light(s, d); }
    case 14u { return blend_hard_light(s, d); }
    case 15u { return blend_vivid_light(s, d); }
    case 16u { return clamp01(d + 2.0 * s - 1.0); }
    case 17u { return blend_pin_light(s, d); }
    case 18u { return blend_hard_mix(s, d); }
    case 19u { return abs(d - s); }
    case 20u { return d + s - 2.0 * d * s; }
    case 21u { return max(0.0, d - s); }
    case 22u { return blend_divide(s, d); }
  }
}

fn blend_argb(dst: u32, src: u32, mode: u32, pixel_index: u32) -> u32 {
  let sa = unpack_a(src);
  if (sa <= 0.0) {
    return dst;
  }

  let da = unpack_a(dst);
  let sr = unpack_r(src);
  let sg = unpack_g(src);
  let sb = unpack_b(src);
  let dr = unpack_r(dst);
  let dg = unpack_g(dst);
  let db = unpack_b(dst);

  if (mode == 2u) {
    let noise = pseudo_random(pixel_index, src, dst);
    if (noise > sa) {
      return dst;
    }
    return pack_argb(1.0, sr, sg, sb);
  }

  var fr = sr;
  var fg = sg;
  var fb = sb;
  if (mode == 6u || mode == 11u) {
    let src_sum = (sr + sg + sb) * sa;
    let dst_sum = (dr + dg + db) * da;
    let use_src = (mode == 6u && src_sum < dst_sum) ||
      (mode == 11u && src_sum > dst_sum);
    if (!use_src) {
      fr = dr;
      fg = dg;
      fb = db;
    }
  } else if (mode >= 23u) {
    let src_hsl = rgb_to_hsl(vec3<f32>(sr, sg, sb));
    let dst_hsl = rgb_to_hsl(vec3<f32>(dr, dg, db));
    var out_hsl = dst_hsl;
    if (mode == 23u) {
      out_hsl = vec3<f32>(src_hsl.x, dst_hsl.y, dst_hsl.z);
    } else if (mode == 24u) {
      out_hsl = vec3<f32>(dst_hsl.x, src_hsl.y, dst_hsl.z);
    } else if (mode == 25u) {
      out_hsl = vec3<f32>(src_hsl.x, src_hsl.y, dst_hsl.z);
    } else if (mode == 26u) {
      out_hsl = vec3<f32>(dst_hsl.x, dst_hsl.y, src_hsl.z);
    }
    let rgb = hsl_to_rgb(out_hsl);
    fr = rgb.r;
    fg = rgb.g;
    fb = rgb.b;
  } else {
    fr = blend_channel(mode, sr, dr);
    fg = blend_channel(mode, sg, dg);
    fb = blend_channel(mode, sb, db);
  }

  let out_a = sa + da * (1.0 - sa);
  if (out_a <= 0.0) {
    return 0u;
  }

  let rr = ((fr * sa) + dr * da * (1.0 - sa)) / out_a;
  let rg = ((fg * sa) + dg * da * (1.0 - sa)) / out_a;
  let rb = ((fb * sa) + db * da * (1.0 - sa)) / out_a;

  return pack_argb(out_a, rr, rg, rb);
}

@compute @workgroup_size(16, 16)
fn composite_main(@builtin(global_invocation_id) id: vec3<u32>) {
  let x = id.x;
  let y = id.y;
  if (x >= config.width || y >= config.height) {
    return;
  }

  let pixel_count = config.width * config.height;
  let idx = y * config.width + x;

  var dst: u32 = 0u;
  var initialized: bool = false;
  var mask_alpha: f32 = 0.0;

  for (var layer_idx: u32 = 0u; layer_idx < config.layer_count && layer_idx < MAX_LAYERS; layer_idx = layer_idx + 1u) {
    let p = config.layers[layer_idx];
    if (p.visible == 0u) {
      continue;
    }

    let opacity = p.opacity;
    if (opacity <= 0.0) {
      if (p.clipping_mask == 0u) {
        mask_alpha = 0.0;
      }
      continue;
    }

    let src = layer_pixels[layer_idx * pixel_count + idx];
    let src_a_u8 = (src >> 24u) & 0xFFu;
    if (src_a_u8 == 0u) {
      if (p.clipping_mask == 0u) {
        mask_alpha = 0.0;
      }
      continue;
    }

    var total_opacity = opacity;
    if (p.clipping_mask != 0u) {
      if (mask_alpha <= 0.0) {
        continue;
      }
      total_opacity = total_opacity * mask_alpha;
      if (total_opacity <= 0.0) {
        continue;
      }
    }

    let src_a = f32(src_a_u8) / 255.0;
    var effective_a = src_a * total_opacity;
    if (effective_a <= 0.0) {
      if (p.clipping_mask == 0u) {
        mask_alpha = 0.0;
      }
      continue;
    }
    effective_a = clamp01(effective_a);

    if (p.clipping_mask == 0u) {
      mask_alpha = effective_a;
    }

    let effective_a_u8 = to_u8(effective_a);
    let effective_color = (effective_a_u8 << 24u) | (src & 0x00FFFFFFu);

    if (!initialized) {
      dst = effective_color;
      initialized = true;
    } else {
      dst = blend_argb(dst, effective_color, p.blend_mode, idx);
    }
  }

  if (!initialized) {
    out_pixels[idx] = 0u;
  } else {
    out_pixels[idx] = dst;
  }
}
