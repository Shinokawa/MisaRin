const EPS: f32 = 0.000001;

struct StrokePoint {
  pos: vec2<f32>,
  radius: f32,
  _pad0: f32,
};

struct Config {
  canvas_width: u32,
  canvas_height: u32,
  origin_x: u32,
  origin_y: u32,
  region_width: u32,
  region_height: u32,
  point_count: u32,
  brush_shape: u32,        // 0: circle, 1: square
  erase_mode: u32,         // 0: paint, 1: erase
  antialias_level: u32,    // 0..3
  color_argb: u32,         // straight alpha ARGB8888
  softness: f32,           // 0.0..1.0 (edge feather as fraction of radius)
  _pad0: u32,
  _pad1: u32,
};

@group(0) @binding(0)
var<storage, read> stroke_points: array<StrokePoint>;

@group(0) @binding(1)
var layer_tex: texture_storage_2d<r32uint, read_write>;

@group(0) @binding(2)
var<uniform> cfg: Config;

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

fn brush_alpha(dist: f32, radius: f32, softness: f32) -> f32 {
  if (radius <= 0.0) {
    return 0.0;
  }
  let s = clamp(softness, 0.0, 1.0);
  if (s <= 0.0) {
    return select(0.0, 1.0, dist <= radius);
  }
  let edge = max(EPS, radius * s);
  return 1.0 - smoothstep(radius - edge, radius, dist);
}

fn closest_t_to_segment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
  let ab = b - a;
  let ap = p - a;
  let ab_len2 = dot(ab, ab);
  if (ab_len2 <= EPS) {
    return 0.0;
  }
  return clamp(dot(ap, ab) / ab_len2, 0.0, 1.0);
}

fn dist_circle_to_segment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
  let t = closest_t_to_segment(p, a, b);
  let c = a + (b - a) * t;
  return length(p - c);
}

fn dist_square_to_segment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
  let t = closest_t_to_segment(p, a, b);
  let c = a + (b - a) * t;
  let d = abs(p - c);
  return max(d.x, d.y);
}

fn stroke_coverage_at(sample_pos: vec2<f32>) -> f32 {
  let count = cfg.point_count;
  if (count == 0u) {
    return 0.0;
  }
  if (count == 1u) {
    let sp = stroke_points[0u];
    let dist = select(
      max(abs(sample_pos.x - sp.pos.x), abs(sample_pos.y - sp.pos.y)),
      distance(sample_pos, sp.pos),
      cfg.brush_shape == 0u,
    );
    return brush_alpha(dist, sp.radius, cfg.softness);
  }

  var out_alpha = 0.0;
  for (var i: u32 = 0u; i + 1u < count; i = i + 1u) {
    let p0 = stroke_points[i];
    let p1 = stroke_points[i + 1u];
    let t = closest_t_to_segment(sample_pos, p0.pos, p1.pos);
    let radius = mix(p0.radius, p1.radius, t);
    let dist = select(
      dist_square_to_segment(sample_pos, p0.pos, p1.pos),
      dist_circle_to_segment(sample_pos, p0.pos, p1.pos),
      cfg.brush_shape == 0u,
    );
    let a = brush_alpha(dist, radius, cfg.softness);
    out_alpha = max(out_alpha, a);
  }
  return out_alpha;
}

fn antialias_samples_per_axis(level: u32) -> u32 {
  let clamped = min(level, 3u);
  return 1u << clamped;
}

fn blend_paint(dst: u32, src_rgb: vec3<f32>, src_a: f32) -> u32 {
  if (src_a <= 0.0) {
    return dst;
  }
  let da = unpack_a(dst);
  let dr = unpack_r(dst);
  let dg = unpack_g(dst);
  let db = unpack_b(dst);

  let out_a = src_a + da * (1.0 - src_a);
  if (out_a <= 0.0) {
    return 0u;
  }

  let dst_w = da * (1.0 - src_a);
  let out_rgb = (src_rgb * src_a + vec3<f32>(dr, dg, db) * dst_w) / out_a;
  return pack_argb(out_a, out_rgb.x, out_rgb.y, out_rgb.z);
}

fn blend_erase(dst: u32, erase_a: f32) -> u32 {
  if (erase_a <= 0.0) {
    return dst;
  }
  let da = unpack_a(dst);
  if (da <= 0.0) {
    return dst;
  }
  let out_a = da * (1.0 - clamp01(erase_a));
  if (out_a <= 0.0) {
    return 0u;
  }
  // Preserve straight RGB; only alpha changes.
  return pack_argb(out_a, unpack_r(dst), unpack_g(dst), unpack_b(dst));
}

@compute @workgroup_size(16, 16)
fn draw_brush_stroke(@builtin(global_invocation_id) id: vec3<u32>) {
  let lx = id.x;
  let ly = id.y;
  if (lx >= cfg.region_width || ly >= cfg.region_height) {
    return;
  }

  let x = cfg.origin_x + lx;
  let y = cfg.origin_y + ly;
  if (x >= cfg.canvas_width || y >= cfg.canvas_height) {
    return;
  }

  let samples = antialias_samples_per_axis(cfg.antialias_level);
  let inv_samples = 1.0 / f32(samples);
  var alpha_accum = 0.0;
  for (var sy: u32 = 0u; sy < samples; sy = sy + 1u) {
    for (var sx: u32 = 0u; sx < samples; sx = sx + 1u) {
      let ox = (f32(sx) + 0.5) * inv_samples - 0.5;
      let oy = (f32(sy) + 0.5) * inv_samples - 0.5;
      let sample_pos = vec2<f32>(f32(x) + 0.5 + ox, f32(y) + 0.5 + oy);
      alpha_accum = alpha_accum + stroke_coverage_at(sample_pos);
    }
  }
  let total_samples = f32(samples * samples);
  let coverage = clamp01(alpha_accum / max(1.0, total_samples));

  if (coverage <= 0.0) {
    return;
  }

  let src_a_base = unpack_a(cfg.color_argb);
  let src_a = clamp01(coverage * src_a_base);
  if (src_a <= 0.0) {
    return;
  }

  let src_rgb = vec3<f32>(
    unpack_r(cfg.color_argb),
    unpack_g(cfg.color_argb),
    unpack_b(cfg.color_argb),
  );

  let dst = textureLoad(layer_tex, vec2<i32>(i32(x), i32(y))).x;
  let out = select(
    blend_erase(dst, src_a),
    blend_paint(dst, src_rgb, src_a),
    cfg.erase_mode == 0u,
  );

  textureStore(layer_tex, vec2<i32>(i32(x), i32(y)), vec4<u32>(out, 0u, 0u, 0u));
}
