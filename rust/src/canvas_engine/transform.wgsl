struct TransformConfig {
  matrix: mat4x4<f32>,
  layer_index: u32,
  flags: u32,
  _pad0: u32,
  _pad1: u32,
};

@group(0) @binding(0)
var src_tex: texture_2d_array<u32>;

@group(0) @binding(1)
var dst_tex: texture_storage_2d<r32uint, write>;

@group(0) @binding(2)
var<uniform> cfg: TransformConfig;

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

fn load_layer_pixel(x: i32, y: i32, layer: i32) -> vec4<f32> {
  let dims = textureDimensions(src_tex);
  if (x < 0 || y < 0 || x >= i32(dims.x) || y >= i32(dims.y)) {
    return vec4<f32>(0.0, 0.0, 0.0, 0.0);
  }
  let packed = textureLoad(src_tex, vec2<i32>(x, y), layer, 0).x;
  return unpack_straight_rgba(packed);
}

fn sample_nearest(coord: vec2<f32>, layer: i32) -> u32 {
  let sx = coord.x - 0.5;
  let sy = coord.y - 0.5;
  let ix = i32(round(sx));
  let iy = i32(round(sy));
  let dims = textureDimensions(src_tex);
  if (ix < 0 || iy < 0 || ix >= i32(dims.x) || iy >= i32(dims.y)) {
    return 0u;
  }
  return textureLoad(src_tex, vec2<i32>(ix, iy), layer, 0).x;
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
  if ((cfg.flags & 2u) != 0u) {
    return sample_bilinear(coord, layer);
  }
  return sample_nearest(coord, layer);
}

@compute @workgroup_size(8, 8, 1)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
  let dims = textureDimensions(dst_tex);
  let x = i32(gid.x);
  let y = i32(gid.y);
  if (x >= i32(dims.x) || y >= i32(dims.y)) {
    return;
  }
  let board_pos = vec2<f32>(f32(x) + 0.5, f32(y) + 0.5);
  let src = (cfg.matrix * vec4<f32>(board_pos, 0.0, 1.0)).xy;
  let packed = sample_transformed(src, i32(cfg.layer_index));
  textureStore(dst_tex, vec2<i32>(x, y), vec4<u32>(packed, 0u, 0u, 0u));
}
