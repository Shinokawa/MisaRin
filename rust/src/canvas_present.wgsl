struct VsOut {
  @builtin(position) pos: vec4<f32>,
};

@vertex
fn vs_main(@builtin(vertex_index) idx: u32) -> VsOut {
  var positions = array<vec2<f32>, 3>(
    vec2<f32>(-1.0, -1.0),
    vec2<f32>(3.0, -1.0),
    vec2<f32>(-1.0, 3.0),
  );
  var out: VsOut;
  out.pos = vec4<f32>(positions[idx], 0.0, 1.0);
  return out;
}

@group(0) @binding(0)
var layer_tex: texture_2d_array<u32>;

struct CompositeConfig {
  layer_count: u32,
  view_flags: u32,
  transform_layer: u32,
  transform_flags: u32,
};

struct LayerParams {
  opacity: f32,
  visible: f32,
  clipping_mask: f32,
  blend_mode: u32,
};

@group(0) @binding(1)
var<uniform> cfg: CompositeConfig;

// (opacity, visible, clipping_mask, blend_mode) per layer. visible: 1.0=visible, 0.0=hidden.
@group(0) @binding(2)
var<storage, read> layer_params: array<LayerParams>;

struct TransformConfig {
  matrix: mat4x4<f32>,
};

@group(0) @binding(3)
var<uniform> transform_cfg: TransformConfig;

fn u8_to_f32(v: u32) -> f32 {
  return f32(v) / 255.0;
}

fn unpack_straight_rgba(c: u32) -> vec4<f32> {
  let a = u8_to_f32((c >> 24u) & 0xFFu);
  let r = u8_to_f32((c >> 16u) & 0xFFu);
  let g = u8_to_f32((c >> 8u) & 0xFFu);
  let b = u8_to_f32(c & 0xFFu);
  return vec4<f32>(r, g, b, a);
}

fn pack_straight_rgba(c: vec4<f32>) -> u32 {
  let clamped = clamp(c, vec4<f32>(0.0), vec4<f32>(1.0));
  let r = u32(round(clamped.r * 255.0));
  let g = u32(round(clamped.g * 255.0));
  let b = u32(round(clamped.b * 255.0));
  let a = u32(round(clamped.a * 255.0));
  return (a << 24u) | (r << 16u) | (g << 8u) | b;
}

const EPS: f32 = 0.0000001;

fn clamp01(x: f32) -> f32 {
  return clamp(x, 0.0, 1.0);
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

fn blend_premul(
  dst_premul: vec4<f32>,
  src_rgb: vec3<f32>,
  src_a: f32,
  mode: u32,
) -> vec4<f32> {
  let sa = clamp01(src_a);
  if (sa <= 0.0) {
    return dst_premul;
  }

  let da = dst_premul.a;
  var dr: f32 = 0.0;
  var dg: f32 = 0.0;
  var db: f32 = 0.0;
  if (da > 0.0) {
    let inv_da = 1.0 / da;
    dr = dst_premul.r * inv_da;
    dg = dst_premul.g * inv_da;
    db = dst_premul.b * inv_da;
  }

  let fr = blend_channel(mode, src_rgb.r, dr);
  let fg = blend_channel(mode, src_rgb.g, dg);
  let fb = blend_channel(mode, src_rgb.b, db);

  let out_a = sa + da * (1.0 - sa);
  if (out_a <= 0.0) {
    return vec4<f32>(0.0, 0.0, 0.0, 0.0);
  }

  let rr = ((fr * sa) + dr * da * (1.0 - sa)) / out_a;
  let rg = ((fg * sa) + dg * da * (1.0 - sa)) / out_a;
  let rb = ((fb * sa) + db * da * (1.0 - sa)) / out_a;

  return vec4<f32>(vec3<f32>(rr, rg, rb) * out_a, out_a);
}

fn load_layer_pixel(x: i32, y: i32, layer: i32) -> vec4<f32> {
  let dims = textureDimensions(layer_tex);
  if (x < 0 || y < 0 || x >= i32(dims.x) || y >= i32(dims.y)) {
    return vec4<f32>(0.0, 0.0, 0.0, 0.0);
  }
  let packed = textureLoad(layer_tex, vec2<i32>(x, y), layer, 0).x;
  return unpack_straight_rgba(packed);
}

fn sample_nearest(coord: vec2<f32>, layer: i32) -> u32 {
  let sx = coord.x - 0.5;
  let sy = coord.y - 0.5;
  let ix = i32(round(sx));
  let iy = i32(round(sy));
  let dims = textureDimensions(layer_tex);
  if (ix < 0 || iy < 0 || ix >= i32(dims.x) || iy >= i32(dims.y)) {
    return 0u;
  }
  return textureLoad(layer_tex, vec2<i32>(ix, iy), layer, 0).x;
}

fn sample_bilinear(coord: vec2<f32>, layer: i32) -> u32 {
  let sx = coord.x - 0.5;
  let sy = coord.y - 0.5;
  let x0 = i32(floor(sx));
  let y0 = i32(floor(sy));
  let fx = fract(sx);
  let fy = fract(sy);
  let c00 = load_layer_pixel(x0, y0, layer);
  let c10 = load_layer_pixel(x0 + 1, y0, layer);
  let c01 = load_layer_pixel(x0, y0 + 1, layer);
  let c11 = load_layer_pixel(x0 + 1, y0 + 1, layer);
  let top = mix(c00, c10, fx);
  let bottom = mix(c01, c11, fx);
  let out = mix(top, bottom, fy);
  return pack_straight_rgba(out);
}

fn sample_transformed(coord: vec2<f32>, layer: i32) -> u32 {
  if ((cfg.transform_flags & 2u) != 0u) {
    return sample_bilinear(coord, layer);
  }
  return sample_nearest(coord, layer);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
  let x = i32(pos.x);
  let y = i32(pos.y);
  let dims = textureDimensions(layer_tex);
  var coord = vec2<i32>(x, y);
  if ((cfg.view_flags & 1u) != 0u) {
    coord.x = i32(dims.x) - 1 - coord.x;
  }
  let board_pos = vec2<f32>(f32(coord.x) + 0.5, f32(coord.y) + 0.5);

  // Blend modes + per-layer opacity, bottom-to-top.
  var out_premul = vec4<f32>(0.0, 0.0, 0.0, 0.0);
  var mask_alpha: f32 = 0.0;
  var initialized: bool = false;
  for (var i: u32 = 0u; i < cfg.layer_count; i = i + 1u) {
    let params = layer_params[i];
    var packed: u32 = 0u;
    if ((cfg.transform_flags & 1u) != 0u && i == cfg.transform_layer) {
      let src = (transform_cfg.matrix * vec4<f32>(board_pos, 0.0, 1.0)).xy;
      packed = sample_transformed(src, i32(i));
    } else {
      packed = textureLoad(layer_tex, coord, i32(i), 0).x;
    }
    let opacity = clamp(params.opacity, 0.0, 1.0);
    let visible = params.visible;
    let clipping = params.clipping_mask;
    let blend_mode = params.blend_mode;
    if (visible < 0.5) {
      continue;
    }
    if (opacity <= 0.0) {
      if (clipping < 0.5) {
        mask_alpha = 0.0;
      }
      continue;
    }

    let straight = unpack_straight_rgba(packed);
    if (straight.a <= 0.0) {
      if (clipping < 0.5) {
        mask_alpha = 0.0;
      }
      continue;
    }

    var total_opacity = opacity;
    if (clipping >= 0.5) {
      if (mask_alpha <= 0.0) {
        continue;
      }
      total_opacity = total_opacity * mask_alpha;
      if (total_opacity <= 0.0) {
        continue;
      }
    }

    let a = clamp(straight.a * total_opacity, 0.0, 1.0);
    if (a <= 0.0) {
      if (clipping < 0.5) {
        mask_alpha = 0.0;
      }
      continue;
    }
    if (clipping < 0.5) {
      mask_alpha = a;
    }

    if (!initialized) {
      out_premul = vec4<f32>(straight.rgb * a, a);
      initialized = true;
    } else {
      out_premul = blend_premul(out_premul, straight.rgb, a, blend_mode);
    }
  }

  // Flutter's scene graph expects premultiplied alpha.
  if ((cfg.view_flags & 2u) != 0u) {
    let luma = dot(out_premul.rgb, vec3<f32>(0.299, 0.587, 0.114));
    out_premul = vec4<f32>(vec3<f32>(luma), out_premul.a);
  }
  return clamp(out_premul, vec4<f32>(0.0), vec4<f32>(1.0));
}
