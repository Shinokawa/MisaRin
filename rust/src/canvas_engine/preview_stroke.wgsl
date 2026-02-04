struct Segment {
  p0: vec2<f32>,
  p1: vec2<f32>,
  r0: f32,
  r1: f32,
  rot_sin: f32,
  rot_cos: f32,
};

struct Config {
  canvas_width: u32,
  canvas_height: u32,
  brush_shape: u32,     // 0: circle, 1: triangle, 2: square, 3: star
  antialias_level: u32, // 0..3
  color_argb: u32,
  erase_mode: u32,      // 0: paint, 1: erase
  mirror_x: u32,
  _pad0: u32,
  hollow_ratio: f32,
  softness: f32,
  layer_opacity: f32,
  _pad1: f32,
};

@group(0) @binding(0)
var<storage, read> segments: array<Segment>;

@group(0) @binding(1)
var<uniform> cfg: Config;

struct VsOut {
  @builtin(position) pos: vec4<f32>,
  @location(0) seg_index: u32,
};

fn clamp01(x: f32) -> f32 {
  return clamp(x, 0.0, 1.0);
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

fn unpack_a(c: u32) -> f32 {
  return f32((c >> 24u) & 0xFFu) / 255.0;
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
  return 1.6;
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
  if (ab_len2 <= 0.000001) {
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
  if (cfg.brush_shape == 2u) {
    return signed_distance_box(rel, vec2<f32>(radius, radius));
  }
  let inv_r = 1.0 / max(radius, 0.000001);
  let rel_unit = rel * inv_r;
  var sd_unit = signed_distance_triangle_unit(rel_unit);
  if (cfg.brush_shape == 3u) {
    sd_unit = signed_distance_star_unit(rel_unit);
  }
  return radius + sd_unit * radius;
}

@vertex
fn vs_main(@builtin(vertex_index) vid: u32, @builtin(instance_index) iid: u32) -> VsOut {
  let seg = segments[iid];
  let max_r = max(seg.r0, seg.r1);
  let pad = max_r + 2.0;
  let min_x = min(seg.p0.x, seg.p1.x) - pad;
  let max_x = max(seg.p0.x, seg.p1.x) + pad;
  let min_y = min(seg.p0.y, seg.p1.y) - pad;
  let max_y = max(seg.p0.y, seg.p1.y) + pad;

  var corner = vec2<f32>(0.0, 0.0);
  if (vid == 0u) {
    corner = vec2<f32>(0.0, 0.0);
  } else if (vid == 1u) {
    corner = vec2<f32>(1.0, 0.0);
  } else if (vid == 2u) {
    corner = vec2<f32>(0.0, 1.0);
  } else if (vid == 3u) {
    corner = vec2<f32>(0.0, 1.0);
  } else if (vid == 4u) {
    corner = vec2<f32>(1.0, 0.0);
  } else {
    corner = vec2<f32>(1.0, 1.0);
  }

  var x = mix(min_x, max_x, corner.x);
  let y = mix(min_y, max_y, corner.y);
  if (cfg.mirror_x != 0u) {
    x = f32(cfg.canvas_width - 1u) - x;
  }

  let w = max(f32(cfg.canvas_width), 1.0);
  let h = max(f32(cfg.canvas_height), 1.0);
  let ndc_x = x / w * 2.0 - 1.0;
  let ndc_y = 1.0 - (y / h) * 2.0;

  var out: VsOut;
  out.pos = vec4<f32>(ndc_x, ndc_y, 0.0, 1.0);
  out.seg_index = iid;
  return out;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>, @location(0) seg_index: u32) -> @location(0) vec4<f32> {
  let seg = segments[seg_index];
  let sample_pos = vec2<f32>(pos.x + 0.5, pos.y + 0.5);
  let t = closest_t_to_segment(sample_pos, seg.p0, seg.p1);
  let c = seg.p0 + (seg.p1 - seg.p0) * t;
  let radius = mix(seg.r0, seg.r1, t);
  let dist = shape_distance_to_point(sample_pos, c, radius, seg.rot_sin, seg.rot_cos);
  let outer = brush_alpha(dist, radius, cfg.softness);

  let ratio = clamp(cfg.hollow_ratio, 0.0, 1.0);
  let use_hollow = (ratio > 0.0001) && (cfg.erase_mode == 0u);
  var coverage = outer;
  if (use_hollow) {
    let inner_radius = radius * ratio;
    let inner_dist = shape_distance_to_point(sample_pos, c, inner_radius, seg.rot_sin, seg.rot_cos);
    let inner = brush_alpha(inner_dist, inner_radius, cfg.softness);
    coverage = max(outer - inner, 0.0);
  }

  let opacity = clamp01(cfg.layer_opacity);
  let src_a_base = clamp01(unpack_a(cfg.color_argb) * opacity);
  let out_a = clamp01(coverage * src_a_base);
  if (out_a <= 0.0) {
    discard;
  }

  if (cfg.erase_mode != 0u) {
    return vec4<f32>(0.0, 0.0, 0.0, out_a);
  }

  let rgb = vec3<f32>(
    unpack_r(cfg.color_argb),
    unpack_g(cfg.color_argb),
    unpack_b(cfg.color_argb),
  );
  return vec4<f32>(rgb, out_a);
}
