const EPS: f32 = 0.000001;
const SCAN_PAPER_WHITE_MAX: f32 = 190.0;
const SCAN_PAPER_WHITE_DELTA: f32 = 90.0;
const SCAN_PAPER_COLOR_DISTANCE: f32 = 180.0 * 180.0;
const SCAN_PAPER_BLACK_DISTANCE: f32 = 320.0 * 320.0;

struct FilterConfig {
  width: u32,
  height: u32,
  radius: u32,
  flags: u32,
  params0: vec4<f32>,
  params1: vec4<f32>,
};

@group(0) @binding(0)
var src_tex: texture_storage_2d<rgba8uint, read>;

@group(0) @binding(1)
var dst_tex: texture_storage_2d<rgba8uint, read_write>;

@group(0) @binding(2)
var<uniform> cfg: FilterConfig;

fn unpack_u32(v: vec4<u32>) -> u32 {
  return (v.w << 24u) | (v.z << 16u) | (v.y << 8u) | v.x;
}

fn pack_u32(value: u32) -> vec4<u32> {
  return vec4<u32>(
    value & 0xFFu,
    (value >> 8u) & 0xFFu,
    (value >> 16u) & 0xFFu,
    (value >> 24u) & 0xFFu
  );
}

fn src_load(coord: vec2<i32>) -> u32 {
  return unpack_u32(textureLoad(src_tex, coord));
}

fn dst_store(coord: vec2<i32>, value: u32) {
  textureStore(dst_tex, coord, pack_u32(value));
}

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

fn rgb_to_hsv(rgb: vec3<f32>) -> vec3<f32> {
  let r = rgb.r;
  let g = rgb.g;
  let b = rgb.b;
  let maxc = max(max(r, g), b);
  let minc = min(min(r, g), b);
  let delta = maxc - minc;

  var h = 0.0;
  if (delta > EPS) {
    if (maxc == r) {
      h = (g - b) / delta;
      if (g < b) {
        h = h + 6.0;
      }
    } else if (maxc == g) {
      h = (b - r) / delta + 2.0;
    } else {
      h = (r - g) / delta + 4.0;
    }
    h = h / 6.0;
  }

  let s = select(0.0, delta / maxc, maxc > EPS);
  let v = maxc;
  return vec3<f32>(h, s, v);
}

fn hsv_to_rgb(hsv: vec3<f32>) -> vec3<f32> {
  let h = hsv.x;
  let s = hsv.y;
  let v = hsv.z;
  if (s <= EPS) {
    return vec3<f32>(v, v, v);
  }
  let h6 = h * 6.0;
  let i = floor(h6);
  let f = h6 - i;
  let p = v * (1.0 - s);
  let q = v * (1.0 - s * f);
  let t = v * (1.0 - s * (1.0 - f));
  let ii = u32(i) % 6u;
  if (ii == 0u) { return vec3<f32>(v, t, p); }
  if (ii == 1u) { return vec3<f32>(q, v, p); }
  if (ii == 2u) { return vec3<f32>(p, v, t); }
  if (ii == 3u) { return vec3<f32>(p, q, v); }
  if (ii == 4u) { return vec3<f32>(t, p, v); }
  return vec3<f32>(v, p, q);
}

fn luma(rgb: vec3<f32>) -> f32 {
  return dot(rgb, vec3<f32>(0.299, 0.587, 0.114));
}

fn scan_paper_map_rgb(
  r: f32,
  g: f32,
  b: f32,
  tone_enabled: bool,
  black: f32,
  inv_range: f32,
  gamma: f32,
) -> vec4<f32> {
  let r8 = r * 255.0;
  let g8 = g * 255.0;
  let b8 = b * 255.0;
  let maxc = max(max(r8, g8), b8);
  let minc = min(min(r8, g8), b8);
  let delta = maxc - minc;

  var white_test = maxc >= SCAN_PAPER_WHITE_MAX &&
    delta <= SCAN_PAPER_WHITE_DELTA;
  if (tone_enabled) {
    var normalized = clamp((luma(vec3<f32>(r, g, b)) - black) * inv_range, 0.0, 1.0);
    normalized = clamp(pow(normalized, gamma), 0.0, 1.0);
    let gray = normalized * 255.0;
    white_test = gray >= SCAN_PAPER_WHITE_MAX && delta <= SCAN_PAPER_WHITE_DELTA;
  }
  if (white_test) {
    return vec4<f32>(0.0, 0.0, 0.0, 0.0);
  }

  let dr = 255.0 - r8;
  let dg = 255.0 - g8;
  let db = 255.0 - b8;
  let dist_red = dr * dr + g8 * g8 + b8 * b8;
  let dist_green = r8 * r8 + dg * dg + b8 * b8;
  let dist_blue = r8 * r8 + g8 * g8 + db * db;

  var min_dist = dist_red;
  var out_r = 1.0;
  var out_g = 0.0;
  var out_b = 0.0;
  if (dist_green < min_dist) {
    min_dist = dist_green;
    out_r = 0.0;
    out_g = 1.0;
    out_b = 0.0;
  }
  if (dist_blue < min_dist) {
    min_dist = dist_blue;
    out_r = 0.0;
    out_g = 0.0;
    out_b = 1.0;
  }
  if (min_dist <= SCAN_PAPER_COLOR_DISTANCE) {
    return vec4<f32>(out_r, out_g, out_b, 1.0);
  }

  let dist_black = r8 * r8 + g8 * g8 + b8 * b8;
  if (dist_black <= SCAN_PAPER_BLACK_DISTANCE) {
    return vec4<f32>(0.0, 0.0, 0.0, 1.0);
  }

  return vec4<f32>(0.0, 0.0, 0.0, 0.0);
}

@compute @workgroup_size(16, 16)
fn color_filter(@builtin(global_invocation_id) id: vec3<u32>) {
  let x = id.x;
  let y = id.y;
  if (x >= cfg.width || y >= cfg.height) {
    return;
  }
  let src = src_load(vec2<i32>(i32(x), i32(y)));
  let a = unpack_a(src);
  var r = unpack_r(src);
  var g = unpack_g(src);
  var b = unpack_b(src);

  let filter_type = cfg.flags;
  if (filter_type == 0u) {
    let hue_delta = cfg.params0.x;
    let sat_delta = cfg.params0.y;
    let val_delta = cfg.params0.z;
    let hsv = rgb_to_hsv(vec3<f32>(r, g, b));
    var h = hsv.x + hue_delta;
    h = h - floor(h);
    let s = clamp01(hsv.y + sat_delta);
    let v = clamp01(hsv.z + val_delta);
    let out = hsv_to_rgb(vec3<f32>(h, s, v));
    r = out.x;
    g = out.y;
    b = out.z;
  } else if (filter_type == 1u) {
    let brightness = cfg.params0.x;
    let contrast = cfg.params0.y;
    r = clamp01((r - 0.5) * contrast + 0.5 + brightness);
    g = clamp01((g - 0.5) * contrast + 0.5 + brightness);
    b = clamp01((b - 0.5) * contrast + 0.5 + brightness);
  } else if (filter_type == 2u) {
    let black = cfg.params0.x;
    let inv_range = cfg.params0.y;
    let gamma = cfg.params0.z;
    let lum = luma(vec3<f32>(r, g, b));
    var normalized = clamp01((lum - black) * inv_range);
    normalized = clamp01(pow(normalized, gamma));
    r = normalized;
    g = normalized;
    b = normalized;
  } else if (filter_type == 3u) {
    let threshold = cfg.params0.x;
    if (a < threshold) {
      r = 0.0;
      g = 0.0;
      b = 0.0;
      dst_store(vec2<i32>(i32(x), i32(y)), pack_argb(0.0, r, g, b));
      return;
    }
    dst_store(vec2<i32>(i32(x), i32(y)), pack_argb(1.0, r, g, b));
    return;
  } else if (filter_type == 4u) {
    if (a <= 0.0) {
      dst_store(vec2<i32>(i32(x), i32(y)), pack_argb(a, r, g, b));
      return;
    }
    let tone_enabled = cfg.params0.w > 0.5;
    let mapped = scan_paper_map_rgb(
      r,
      g,
      b,
      tone_enabled,
      cfg.params0.x,
      cfg.params0.y,
      cfg.params0.z,
    );
    dst_store(vec2<i32>(i32(x), i32(y)), pack_argb(mapped.w, mapped.x, mapped.y, mapped.z));
    return;
  } else if (filter_type == 5u) {
    if (a > 0.0) {
      r = 1.0 - r;
      g = 1.0 - g;
      b = 1.0 - b;
    }
  } else if (filter_type == 10u) {
    if (a <= 0.0) {
      r = 0.0;
      g = 0.0;
      b = 0.0;
    } else {
      r = r * a;
      g = g * a;
      b = b * a;
    }
  } else if (filter_type == 11u) {
    if (a <= 0.0) {
      r = 0.0;
      g = 0.0;
      b = 0.0;
    } else {
      let inv_a = 1.0 / a;
      r = clamp01(r * inv_a);
      g = clamp01(g * inv_a);
      b = clamp01(b * inv_a);
    }
  }

  dst_store(vec2<i32>(i32(x), i32(y)), pack_argb(a, r, g, b));
}

@compute @workgroup_size(16, 16)
fn blur_pass(@builtin(global_invocation_id) id: vec3<u32>) {
  let x = id.x;
  let y = id.y;
  if (x >= cfg.width || y >= cfg.height) {
    return;
  }
  let radius = i32(cfg.radius);
  if (radius <= 0) {
    let src = src_load(vec2<i32>(i32(x), i32(y)));
    dst_store(vec2<i32>(i32(x), i32(y)), src);
    return;
  }
  let horizontal = (cfg.flags & 1u) == 0u;
  var sum_r: f32 = 0.0;
  var sum_g: f32 = 0.0;
  var sum_b: f32 = 0.0;
  var sum_a: f32 = 0.0;
  let count = f32(radius * 2 + 1);
  for (var i: i32 = -radius; i <= radius; i = i + 1) {
    let sx = i32(x) + select(0, i, horizontal);
    let sy = i32(y) + select(0, i, !horizontal);
    let cx = clamp(sx, 0, i32(cfg.width) - 1);
    let cy = clamp(sy, 0, i32(cfg.height) - 1);
    let c = src_load(vec2<i32>(cx, cy));
    let a = unpack_a(c);
    sum_r = sum_r + unpack_r(c);
    sum_g = sum_g + unpack_g(c);
    sum_b = sum_b + unpack_b(c);
    sum_a = sum_a + a;
  }
  let inv = 1.0 / max(count, 1.0);
  let out_r = sum_r * inv;
  let out_g = sum_g * inv;
  let out_b = sum_b * inv;
  let out_a = sum_a * inv;
  dst_store(vec2<i32>(i32(x), i32(y)), pack_argb(out_a, out_r, out_g, out_b));
}

@compute @workgroup_size(16, 16)
fn morphology_pass(@builtin(global_invocation_id) id: vec3<u32>) {
  let x = id.x;
  let y = id.y;
  if (x >= cfg.width || y >= cfg.height) {
    return;
  }
  let dilate = (cfg.flags & 1u) != 0u;

  let center = src_load(vec2<i32>(i32(x), i32(y)));
  let center_alpha = unpack_a(center);
  var use_luma = center_alpha >= 1.0 - EPS;
  let center_luma = clamp01(
    1.0 - luma(vec3<f32>(unpack_r(center), unpack_g(center), unpack_b(center)))
  );
  var best_alpha = center;
  var best_alpha_cov = center_alpha;
  var best_luma = center;
  var best_luma_cov = center_luma;

  for (var dy: i32 = -1; dy <= 1; dy = dy + 1) {
    let ny = i32(y) + dy;
    if (ny < 0 || ny >= i32(cfg.height)) {
      continue;
    }
    for (var dx: i32 = -1; dx <= 1; dx = dx + 1) {
      let nx = i32(x) + dx;
      if (nx < 0 || nx >= i32(cfg.width)) {
        continue;
      }
      let sample = src_load(vec2<i32>(nx, ny));
      let sa = unpack_a(sample);
      if (sa < 1.0 - EPS) {
        use_luma = false;
      }
      let luma_cov = clamp01(
        1.0 - luma(vec3<f32>(unpack_r(sample), unpack_g(sample), unpack_b(sample)))
      );
      let alpha_cov = sa;
      if (dilate) {
        if (alpha_cov > best_alpha_cov + EPS) {
          best_alpha_cov = alpha_cov;
          best_alpha = sample;
        }
        if (luma_cov > best_luma_cov + EPS) {
          best_luma_cov = luma_cov;
          best_luma = sample;
        }
      } else {
        if (alpha_cov + EPS < best_alpha_cov) {
          best_alpha_cov = alpha_cov;
          best_alpha = sample;
        }
        if (luma_cov + EPS < best_luma_cov) {
          best_luma_cov = luma_cov;
          best_luma = sample;
        }
      }
    }
  }

  let preserve_alpha = use_luma;
  let best = select(best_alpha, best_luma, use_luma);
  let best_cov = select(best_alpha_cov, best_luma_cov, use_luma);
  if (best_cov <= EPS) {
    if (preserve_alpha) {
      dst_store(vec2<i32>(i32(x), i32(y)), center);
    } else {
      dst_store(vec2<i32>(i32(x), i32(y)), 0u);
    }
    return;
  }

  if (preserve_alpha) {
    let a = unpack_a(center);
    let r = unpack_r(best);
    let g = unpack_g(best);
    let b = unpack_b(best);
    dst_store(vec2<i32>(i32(x), i32(y)), pack_argb(a, r, g, b));
    return;
  }

  let r = unpack_r(best);
  let g = unpack_g(best);
  let b = unpack_b(best);
  dst_store(vec2<i32>(i32(x), i32(y)), pack_argb(best_cov, r, g, b));
}

fn antialias_weight(i: u32) -> f32 {
  if (i == 0u) { return 1.0; }
  if (i == 1u) { return 2.0; }
  if (i == 2u) { return 1.0; }
  if (i == 3u) { return 2.0; }
  if (i == 4u) { return 2.0; }
  if (i == 5u) { return 1.0; }
  if (i == 6u) { return 2.0; }
  return 1.0;
}

fn neighbor_offset(i: u32) -> vec2<i32> {
  if (i == 0u) { return vec2<i32>(-1, -1); }
  if (i == 1u) { return vec2<i32>(0, -1); }
  if (i == 2u) { return vec2<i32>(1, -1); }
  if (i == 3u) { return vec2<i32>(-1, 0); }
  if (i == 4u) { return vec2<i32>(1, 0); }
  if (i == 5u) { return vec2<i32>(-1, 1); }
  if (i == 6u) { return vec2<i32>(0, 1); }
  return vec2<i32>(1, 1);
}

@compute @workgroup_size(16, 16)
fn antialias_alpha(@builtin(global_invocation_id) id: vec3<u32>) {
  let x = id.x;
  let y = id.y;
  if (x >= cfg.width || y >= cfg.height) {
    return;
  }
  let blend = clamp01(cfg.params0.x);
  let center = src_load(vec2<i32>(i32(x), i32(y)));
  let alpha = unpack_a(center);
  let center_r = unpack_r(center);
  let center_g = unpack_g(center);
  let center_b = unpack_b(center);

  var total_weight: f32 = 4.0;
  var weighted_alpha: f32 = alpha * 4.0;
  var weighted_r: f32 = center_r * alpha * 4.0;
  var weighted_g: f32 = center_g * alpha * 4.0;
  var weighted_b: f32 = center_b * alpha * 4.0;

  for (var i: u32 = 0u; i < 8u; i = i + 1u) {
    let offset = neighbor_offset(i);
    let nx = clamp(i32(x) + offset.x, 0, i32(cfg.width) - 1);
    let ny = clamp(i32(y) + offset.y, 0, i32(cfg.height) - 1);
    let n = src_load(vec2<i32>(nx, ny));
    let na = unpack_a(n);
    let w = antialias_weight(i);
    total_weight = total_weight + w;
    if (na <= 0.0) {
      continue;
    }
    weighted_alpha = weighted_alpha + na * w;
    weighted_r = weighted_r + unpack_r(n) * na * w;
    weighted_g = weighted_g + unpack_g(n) * na * w;
    weighted_b = weighted_b + unpack_b(n) * na * w;
  }

  if (total_weight <= EPS) {
    dst_store(vec2<i32>(i32(x), i32(y)), center);
    return;
  }

  let candidate_alpha = clamp01(weighted_alpha / total_weight);
  let new_alpha = clamp01(mix(alpha, candidate_alpha, blend));
  if (abs(new_alpha - alpha) <= EPS) {
    dst_store(vec2<i32>(i32(x), i32(y)), center);
    return;
  }

  var out_r = center_r;
  var out_g = center_g;
  var out_b = center_b;
  if (candidate_alpha > alpha + EPS) {
    let denom = max(weighted_alpha, 1.0e-4);
    out_r = weighted_r / denom;
    out_g = weighted_g / denom;
    out_b = weighted_b / denom;
  }

  dst_store(vec2<i32>(i32(x), i32(y)), pack_argb(new_alpha, out_r, out_g, out_b));
}

fn gaussian_weight(i: u32) -> f32 {
  if (i == 0u) { return 1.0; }
  if (i == 1u) { return 4.0; }
  if (i == 2u) { return 6.0; }
  if (i == 3u) { return 4.0; }
  if (i == 4u) { return 1.0; }
  if (i == 5u) { return 4.0; }
  if (i == 6u) { return 16.0; }
  if (i == 7u) { return 24.0; }
  if (i == 8u) { return 16.0; }
  if (i == 9u) { return 4.0; }
  if (i == 10u) { return 6.0; }
  if (i == 11u) { return 24.0; }
  if (i == 12u) { return 36.0; }
  if (i == 13u) { return 24.0; }
  if (i == 14u) { return 6.0; }
  if (i == 15u) { return 4.0; }
  if (i == 16u) { return 16.0; }
  if (i == 17u) { return 24.0; }
  if (i == 18u) { return 16.0; }
  if (i == 19u) { return 4.0; }
  if (i == 20u) { return 1.0; }
  if (i == 21u) { return 4.0; }
  if (i == 22u) { return 6.0; }
  if (i == 23u) { return 4.0; }
  return 1.0;
}

@compute @workgroup_size(16, 16)
fn antialias_edge(@builtin(global_invocation_id) id: vec3<u32>) {
  let x = id.x;
  let y = id.y;
  if (x >= cfg.width || y >= cfg.height) {
    return;
  }
  let base = src_load(vec2<i32>(i32(x), i32(y)));
  let base_a = unpack_a(base);
  if (base_a <= 0.0) {
    dst_store(vec2<i32>(i32(x), i32(y)), base);
    return;
  }

  let base_luma = luma(vec3<f32>(unpack_r(base), unpack_g(base), unpack_b(base)));
  var max_diff: f32 = 0.0;
  for (var i: u32 = 0u; i < 8u; i = i + 1u) {
    let offset = neighbor_offset(i);
    let nx = clamp(i32(x) + offset.x, 0, i32(cfg.width) - 1);
    let ny = clamp(i32(y) + offset.y, 0, i32(cfg.height) - 1);
    let n = src_load(vec2<i32>(nx, ny));
    let na = unpack_a(n);
    if (na <= 0.0) {
      continue;
    }
    let diff = abs(base_luma - luma(vec3<f32>(unpack_r(n), unpack_g(n), unpack_b(n))));
    max_diff = max(max_diff, diff);
  }

  let edge_min: f32 = 0.015;
  let edge_max: f32 = 0.4;
  let edge_strength: f32 = 1.0;
  let edge_gamma: f32 = 0.55;
  var weight: f32 = 0.0;
  if (max_diff > edge_min) {
    let normalized = clamp01((max_diff - edge_min) / (edge_max - edge_min));
    weight = pow(normalized, edge_gamma) * edge_strength;
  }
  if (weight <= EPS) {
    dst_store(vec2<i32>(i32(x), i32(y)), base);
    return;
  }

  var weighted_alpha: f32 = 0.0;
  var weighted_r: f32 = 0.0;
  var weighted_g: f32 = 0.0;
  var weighted_b: f32 = 0.0;
  var total_weight: f32 = 0.0;
  var idx: u32 = 0u;
  for (var ky: i32 = -2; ky <= 2; ky = ky + 1) {
    for (var kx: i32 = -2; kx <= 2; kx = kx + 1) {
      let k = gaussian_weight(idx);
      idx = idx + 1u;
      let nx = clamp(i32(x) + kx, 0, i32(cfg.width) - 1);
      let ny = clamp(i32(y) + ky, 0, i32(cfg.height) - 1);
      let s = src_load(vec2<i32>(nx, ny));
      let sa = unpack_a(s);
      if (sa <= 0.0) {
        continue;
      }
      total_weight = total_weight + k;
      weighted_alpha = weighted_alpha + sa * k;
      weighted_r = weighted_r + unpack_r(s) * sa * k;
      weighted_g = weighted_g + unpack_g(s) * sa * k;
      weighted_b = weighted_b + unpack_b(s) * sa * k;
    }
  }

  if (total_weight <= EPS) {
    dst_store(vec2<i32>(i32(x), i32(y)), base);
    return;
  }

  let out_alpha = clamp01(weighted_alpha / total_weight);
  let denom = max(weighted_alpha, 1.0e-4);
  let blur_r = weighted_r / denom;
  let blur_g = weighted_g / denom;
  let blur_b = weighted_b / denom;
  let base_r = unpack_r(base);
  let base_g = unpack_g(base);
  let base_b = unpack_b(base);
  let mix_r = mix(base_r, blur_r, weight);
  let mix_g = mix(base_g, blur_g, weight);
  let mix_b = mix(base_b, blur_b, weight);
  let mix_a = mix(base_a, out_alpha, weight);
  let out = pack_argb(mix_a, mix_r, mix_g, mix_b);
  dst_store(vec2<i32>(i32(x), i32(y)), out);
}
