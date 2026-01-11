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

// GPU blend mode ids (mapped from Dart blend mode indices in Rust):
// 0 Normal, 1 Multiply, 2 Screen, 3 Overlay, 4 Darken, 5 Lighten,
// 6 ColorDodge, 7 ColorBurn, 8 HardLight, 9 SoftLight, 10 Difference, 11 Exclusion.
fn blend_channel(mode: u32, s: f32, d: f32) -> f32 {
  switch mode {
    default { return s; }
    case 0u { return s; }
    case 1u { return s * d; }
    case 2u { return 1.0 - (1.0 - s) * (1.0 - d); }
    case 3u { return blend_overlay(s, d); }
    case 4u { return min(s, d); }
    case 5u { return max(s, d); }
    case 6u { return blend_color_dodge(s, d); }
    case 7u { return blend_color_burn(s, d); }
    case 8u { return blend_hard_light(s, d); }
    case 9u { return blend_soft_light(s, d); }
    case 10u { return abs(d - s); }
    case 11u { return d + s - 2.0 * d * s; }
  }
}

fn blend_argb(dst: u32, sr: f32, sg: f32, sb: f32, sa: f32, mode: u32) -> u32 {
  if (sa <= 0.0) {
    return dst;
  }

  let da = unpack_a(dst);
  let dr = unpack_r(dst);
  let dg = unpack_g(dst);
  let db = unpack_b(dst);

  let fr = blend_channel(mode, sr, dr);
  let fg = blend_channel(mode, sg, dg);
  let fb = blend_channel(mode, sb, db);

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

    let sr = unpack_r(src);
    let sg = unpack_g(src);
    let sb = unpack_b(src);

    if (!initialized) {
      dst = pack_argb(effective_a, sr, sg, sb);
      initialized = true;
    } else {
      dst = blend_argb(dst, sr, sg, sb, effective_a, p.blend_mode);
    }
  }

  if (!initialized) {
    out_pixels[idx] = 0u;
  } else {
    out_pixels[idx] = dst;
  }
}
