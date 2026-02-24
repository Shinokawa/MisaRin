const EPS: f32 = 0.000001;

struct StrokePoint {
  pos: vec2<f32>,
  radius: f32,
  alpha: f32,
  rot_sin: f32,
  rot_cos: f32,
};

struct Config {
  canvas_width: u32,
  canvas_height: u32,
  origin_x: u32,
  origin_y: u32,
  region_width: u32,
  region_height: u32,
  point_count: u32,
  brush_shape: u32,        // 0: circle, 1: triangle, 2: square, 3: star
  erase_mode: u32,         // 0: paint, 1: erase
  antialias_level: u32,    // 0..9
  color_argb: u32,         // straight alpha ARGB8888
  softness: f32,           // 0.0..1.0
  rotation_sin: f32,
  rotation_cos: f32,
  hollow_mode: u32,
  hollow_ratio: f32,
  hollow_erase: u32,
  stroke_mask_mode: u32,
  stroke_base_mode: u32,
  stroke_accumulate_mode: u32,
  stroke_mode: u32,        // 0: segments, 1: points
  selection_mask_mode: u32, // 0: disabled, 1: clip by selection mask
  custom_mask_mode: u32, // 0: disabled, 1: use custom brush mask
};

const SQRT2: f32 = 1.414213562;

@group(0) @binding(0)
var<storage, read> stroke_points: array<StrokePoint>;

@group(0) @binding(1)
var layer_tex: texture_storage_2d<rgba8unorm, write>;

@group(0) @binding(2)
var<uniform> cfg: Config;

@group(0) @binding(3)
var layer_read: texture_2d<f32>;

@group(0) @binding(4)
var selection_mask: texture_2d<f32>;

@group(0) @binding(5)
var brush_mask: texture_2d<f32>;

fn to_u8(x: f32) -> u32 {
  let v = floor(clamp(x, 0.0, 1.0) * 255.0 + 0.5);
  return u32(clamp(v, 0.0, 255.0));
}

fn unpack_u32(v: vec4<f32>) -> u32 {
  let b = to_u8(v.x);
  let g = to_u8(v.y);
  let r = to_u8(v.z);
  let a = to_u8(v.w);
  return (a << 24u) | (r << 16u) | (g << 8u) | b;
}

fn pack_u32(value: u32) -> vec4<f32> {
  return vec4<f32>(
    f32(value & 0xFFu) / 255.0,
    f32((value >> 8u) & 0xFFu) / 255.0,
    f32((value >> 16u) & 0xFFu) / 255.0,
    f32((value >> 24u) & 0xFFu) / 255.0
  );
}

fn layer_load(coord: vec2<i32>) -> u32 {
  return unpack_u32(textureLoad(layer_read, coord, 0));
}

fn layer_store(coord: vec2<i32>, value: u32) {
  textureStore(layer_tex, coord, pack_u32(value));
}

fn selection_mask_load(coord: vec2<i32>) -> u32 {
  let v = textureLoad(selection_mask, coord, 0).r;
  return select(0u, 1u, v > 0.0);
}

fn clamp01(x: f32) -> f32 {
  return clamp(x, 0.0, 1.0);
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

fn antialias_feather(level: u32) -> f32 {
  if (level == 0u) {
    return 0.0;
  }
  if (level == 1u) {
    return 0.7;
  }
  if (level == 2u) {
    return 1.1;
  }
  if (level == 3u) {
    return 1.6;
  }
  if (level == 4u) {
    return 1.9;
  }
  if (level == 5u) {
    return 2.2;
  }
  if (level == 6u) {
    return 2.5;
  }
  if (level == 7u) {
    return 2.8;
  }
  if (level == 8u) {
    return 3.1;
  }
  return 3.4;
}

fn brush_alpha(dist: f32, radius: f32, softness: f32) -> f32 {
  if (radius <= 0.0) {
    return 0.0;
  }
  let s = clamp(softness, 0.0, 1.0);
  let aa_feather = antialias_feather(cfg.antialias_level);
  let edge = max(aa_feather, radius * s);
  if (edge <= 0.0) {
    return select(0.0, 1.0, dist <= radius);
  }
  let inner = max(radius - edge, 0.0);
  let outer = radius + edge;
  if (dist <= inner) {
    return 1.0;
  }
  if (dist >= outer) {
    return 0.0;
  }
  return (outer - dist) / (outer - inner);
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

fn rotate_to_brush_space(v: vec2<f32>, rot_sin: f32, rot_cos: f32) -> vec2<f32> {
  return vec2<f32>(
    v.x * rot_cos + v.y * rot_sin,
    -v.x * rot_sin + v.y * rot_cos,
  );
}

fn custom_mask_sample(rel: vec2<f32>, radius: f32) -> vec2<f32> {
  if (radius <= EPS) {
    return vec2<f32>(0.0, 0.0);
  }
  let dims = textureDimensions(brush_mask);
  if (dims.x == 0u || dims.y == 0u) {
    return vec2<f32>(0.0, 0.0);
  }
  let u = rel.x / radius * 0.5 + 0.5;
  let v = rel.y / radius * 0.5 + 0.5;
  if (u < 0.0 || u > 1.0 || v < 0.0 || v > 1.0) {
    return vec2<f32>(0.0, 0.0);
  }
  let fx = u * f32(dims.x - 1u);
  let fy = v * f32(dims.y - 1u);
  let x0 = i32(floor(fx));
  let y0 = i32(floor(fy));
  let x1 = min(x0 + 1, i32(dims.x - 1u));
  let y1 = min(y0 + 1, i32(dims.y - 1u));
  let tx = fx - f32(x0);
  let ty = fy - f32(y0);
  let c00 = textureLoad(brush_mask, vec2<i32>(x0, y0), 0).rg;
  let c10 = textureLoad(brush_mask, vec2<i32>(x1, y0), 0).rg;
  let c01 = textureLoad(brush_mask, vec2<i32>(x0, y1), 0).rg;
  let c11 = textureLoad(brush_mask, vec2<i32>(x1, y1), 0).rg;
  let a0 = mix(c00, c10, tx);
  let a1 = mix(c01, c11, tx);
  return mix(a0, a1, ty);
}

fn custom_mask_alpha(rel: vec2<f32>, radius: f32) -> f32 {
  let sample = custom_mask_sample(rel, radius);
  return mix(sample.x, sample.y, clamp01(cfg.softness));
}

fn tri_vert(i: u32) -> vec2<f32> {
  if (i == 0u) {
    return vec2<f32>(0.000000000, -1.000000000);
  }
  if (i == 1u) {
    return vec2<f32>(0.866025404, 0.500000000);
  }
  return vec2<f32>(-0.866025404, 0.500000000);
}

fn star_vert(i: u32) -> vec2<f32> {
  if (i == 0u) {
    return vec2<f32>(0.000000000, -1.000000000);
  }
  if (i == 1u) {
    return vec2<f32>(0.224513988, -0.309016994);
  }
  if (i == 2u) {
    return vec2<f32>(0.951056516, -0.309016994);
  }
  if (i == 3u) {
    return vec2<f32>(0.363271264, 0.118033989);
  }
  if (i == 4u) {
    return vec2<f32>(0.587785252, 0.809016994);
  }
  if (i == 5u) {
    return vec2<f32>(0.000000000, 0.381966011);
  }
  if (i == 6u) {
    return vec2<f32>(-0.587785252, 0.809016994);
  }
  if (i == 7u) {
    return vec2<f32>(-0.363271264, 0.118033989);
  }
  if (i == 8u) {
    return vec2<f32>(-0.951056516, -0.309016994);
  }
  return vec2<f32>(-0.224513988, -0.309016994);
}

fn segment_distance(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
  let t = closest_t_to_segment(p, a, b);
  let c = a + (b - a) * t;
  return length(p - c);
}

fn signed_distance_box(p: vec2<f32>, half_size: vec2<f32>) -> f32 {
  let d = abs(p) - half_size;
  let outside = length(max(d, vec2<f32>(0.0, 0.0)));
  let inside = min(max(d.x, d.y), 0.0);
  return outside + inside;
}

fn signed_distance_triangle_unit(p: vec2<f32>) -> f32 {
  var min_dist = 1e9;
  var inside = false;
  var j: u32 = 2u;
  for (var i: u32 = 0u; i < 3u; i = i + 1u) {
    let a = tri_vert(j);
    let b = tri_vert(i);
    min_dist = min(min_dist, segment_distance(p, a, b));
    if ((a.y > p.y) != (b.y > p.y)) {
      let x = a.x + (p.y - a.y) * (b.x - a.x) / (b.y - a.y);
      if (p.x < x) {
        inside = !inside;
      }
    }
    j = i;
  }
  return select(min_dist, -min_dist, inside);
}

fn signed_distance_star_unit(p: vec2<f32>) -> f32 {
  var min_dist = 1e9;
  var inside = false;
  var j: u32 = 9u;
  for (var i: u32 = 0u; i < 10u; i = i + 1u) {
    let a = star_vert(j);
    let b = star_vert(i);
    min_dist = min(min_dist, segment_distance(p, a, b));
    if ((a.y > p.y) != (b.y > p.y)) {
      let x = a.x + (p.y - a.y) * (b.x - a.x) / (b.y - a.y);
      if (p.x < x) {
        inside = !inside;
      }
    }
    j = i;
  }
  return select(min_dist, -min_dist, inside);
}

fn shape_distance_to_point(
  sample_pos: vec2<f32>,
  center: vec2<f32>,
  radius: f32,
  rot_sin: f32,
  rot_cos: f32,
) -> f32 {
  let rel = rotate_to_brush_space(sample_pos - center, rot_sin, rot_cos);
  if (cfg.brush_shape == 0u) {
    return length(rel);
  }
  if (radius <= EPS) {
    return radius;
  }
  if (cfg.brush_shape == 2u) {
    let half_side = radius / SQRT2;
    let sd = signed_distance_box(rel, vec2<f32>(half_side, half_side));
    return radius + sd;
  }
  let inv_r = 1.0 / radius;
  let rel_unit = rel * inv_r;
  var sd_unit = signed_distance_triangle_unit(rel_unit);
  if (cfg.brush_shape == 3u) {
    sd_unit = signed_distance_star_unit(rel_unit);
  }
  return radius + sd_unit * radius;
}

fn shape_distance_to_segment(
  sample_pos: vec2<f32>,
  a: vec2<f32>,
  b: vec2<f32>,
  radius: f32,
  rot_sin: f32,
  rot_cos: f32,
) -> f32 {
  let t = closest_t_to_segment(sample_pos, a, b);
  let c = a + (b - a) * t;
  return shape_distance_to_point(sample_pos, c, radius, rot_sin, rot_cos);
}

fn point_coverage(
  sample_pos: vec2<f32>,
  center: vec2<f32>,
  radius: f32,
  rot_sin: f32,
  rot_cos: f32,
) -> f32 {
  if (cfg.custom_mask_mode == 1u) {
    let rel = rotate_to_brush_space(sample_pos - center, rot_sin, rot_cos);
    return custom_mask_alpha(rel, radius);
  }
  let dist = shape_distance_to_point(sample_pos, center, radius, rot_sin, rot_cos);
  return brush_alpha(dist, radius, cfg.softness);
}

fn segment_coverage(
  sample_pos: vec2<f32>,
  a: vec2<f32>,
  b: vec2<f32>,
  radius: f32,
  rot_sin: f32,
  rot_cos: f32,
) -> f32 {
  if (cfg.custom_mask_mode == 1u) {
    let t = closest_t_to_segment(sample_pos, a, b);
    let c = a + (b - a) * t;
    let rel = rotate_to_brush_space(sample_pos - c, rot_sin, rot_cos);
    return custom_mask_alpha(rel, radius);
  }
  let dist = shape_distance_to_segment(sample_pos, a, b, radius, rot_sin, rot_cos);
  return brush_alpha(dist, radius, cfg.softness);
}

fn stroke_coverage_at(sample_pos: vec2<f32>, radius_scale: f32) -> f32 {
  let count = cfg.point_count;
  if (count == 0u) {
    return 0.0;
  }
  let scale = max(radius_scale, 0.0);
  if (scale <= 0.0) {
    return 0.0;
  }
  if (count == 1u) {
    let sp = stroke_points[0u];
    let radius = sp.radius * scale;
    let rot_sin = select(cfg.rotation_sin, sp.rot_sin, cfg.stroke_mode == 1u);
    let rot_cos = select(cfg.rotation_cos, sp.rot_cos, cfg.stroke_mode == 1u);
    let cov = point_coverage(sample_pos, sp.pos, radius, rot_sin, rot_cos);
    return cov * clamp01(sp.alpha);
  }

  if (cfg.stroke_mode == 1u) {
    var out_alpha = 0.0;
    if (cfg.stroke_accumulate_mode == 0u) {
      for (var i: u32 = 0u; i < count; i = i + 1u) {
        let sp = stroke_points[i];
        let radius = sp.radius * scale;
        let cov = point_coverage(sample_pos, sp.pos, radius, sp.rot_sin, sp.rot_cos);
        let a = cov * clamp01(sp.alpha);
        out_alpha = max(out_alpha, a);
      }
      return out_alpha;
    }
    var remain = 1.0;
    for (var i: u32 = 0u; i < count; i = i + 1u) {
      let sp = stroke_points[i];
      let radius = sp.radius * scale;
      let cov = point_coverage(sample_pos, sp.pos, radius, sp.rot_sin, sp.rot_cos);
      let a = clamp01(cov * clamp01(sp.alpha));
      remain = remain * (1.0 - a);
    }
    return 1.0 - remain;
  }

  var out_alpha = 0.0;
  if (cfg.stroke_accumulate_mode == 0u) {
    for (var i: u32 = 0u; i + 1u < count; i = i + 1u) {
      let p0 = stroke_points[i];
      let p1 = stroke_points[i + 1u];
      let t = closest_t_to_segment(sample_pos, p0.pos, p1.pos);
      let radius = mix(p0.radius, p1.radius, t) * scale;
      let alpha = mix(p0.alpha, p1.alpha, t);
      let cov = segment_coverage(
        sample_pos,
        p0.pos,
        p1.pos,
        radius,
        cfg.rotation_sin,
        cfg.rotation_cos,
      );
      let a = cov * clamp01(alpha);
      out_alpha = max(out_alpha, a);
    }
    return out_alpha;
  }
  var remain = 1.0;
  for (var i: u32 = 0u; i + 1u < count; i = i + 1u) {
    let p0 = stroke_points[i];
    let p1 = stroke_points[i + 1u];
    let t = closest_t_to_segment(sample_pos, p0.pos, p1.pos);
    let radius = mix(p0.radius, p1.radius, t) * scale;
    let alpha = mix(p0.alpha, p1.alpha, t);
    let cov = segment_coverage(
      sample_pos,
      p0.pos,
      p1.pos,
      radius,
      cfg.rotation_sin,
      cfg.rotation_cos,
    );
    let a = clamp01(cov * clamp01(alpha));
    remain = remain * (1.0 - a);
  }
  return 1.0 - remain;
}

fn antialias_samples_per_axis(level: u32) -> u32 {
  let clamped = min(level, 9u);
  if (clamped <= 3u) {
    return 1u << clamped;
  }
  return 8u + (clamped - 3u) * 2u;
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
  if (cfg.selection_mask_mode != 0u) {
    let sel = selection_mask_load(vec2<i32>(i32(x), i32(y)));
    if (sel == 0u) {
      return;
    }
  }

  let samples = antialias_samples_per_axis(cfg.antialias_level);
  let inv_samples = 1.0 / f32(samples);
  var outer_accum = 0.0;
  for (var sy: u32 = 0u; sy < samples; sy = sy + 1u) {
    for (var sx: u32 = 0u; sx < samples; sx = sx + 1u) {
      let ox = (f32(sx) + 0.5) * inv_samples - 0.5;
      let oy = (f32(sy) + 0.5) * inv_samples - 0.5;
      let sample_pos = vec2<f32>(f32(x) + 0.5 + ox, f32(y) + 0.5 + oy);
      outer_accum = outer_accum + stroke_coverage_at(sample_pos, 1.0);
    }
  }
  let total_samples = f32(samples * samples);
  let outer = clamp01(outer_accum / max(1.0, total_samples));

  let src_a_base = unpack_a(cfg.color_argb);
  if (cfg.erase_mode != 0u) {
    let erase_a = clamp01(outer * src_a_base);
    if (erase_a <= 0.0) {
      return;
    }
    let dst = layer_load(vec2<i32>(i32(x), i32(y)));
    let out = blend_erase(dst, erase_a);
    layer_store(vec2<i32>(i32(x), i32(y)), out);
    return;
  }

  let paint_a = clamp01(outer * src_a_base);
  if (paint_a <= 0.0) {
    return;
  }

  let src_rgb = vec3<f32>(
    unpack_r(cfg.color_argb),
    unpack_g(cfg.color_argb),
    unpack_b(cfg.color_argb),
  );

  let dst = layer_load(vec2<i32>(i32(x), i32(y)));
  let out = blend_paint(dst, src_rgb, paint_a);
  layer_store(vec2<i32>(i32(x), i32(y)), out);
}
