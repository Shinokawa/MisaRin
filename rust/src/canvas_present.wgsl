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

const MAX_LAYERS: u32 = 4u;

@group(0) @binding(0)
var layer_tex0: texture_2d<u32>;

@group(0) @binding(1)
var layer_tex1: texture_2d<u32>;

@group(0) @binding(2)
var layer_tex2: texture_2d<u32>;

@group(0) @binding(3)
var layer_tex3: texture_2d<u32>;

struct CompositeConfig {
  layer_count: u32,
  _pad0: u32,
  _pad1: u32,
  _pad2: u32,
  // (opacity, visible, _, _) per layer. visible: 1.0=visible, 0.0=hidden.
  layer_params: array<vec4<f32>, MAX_LAYERS>,
};

@group(0) @binding(4)
var<uniform> cfg: CompositeConfig;

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

fn composite_over(dst_premul: vec4<f32>, src_premul: vec4<f32>) -> vec4<f32> {
  let one_minus_sa = 1.0 - src_premul.a;
  return vec4<f32>(
    src_premul.rgb + dst_premul.rgb * one_minus_sa,
    src_premul.a + dst_premul.a * one_minus_sa,
  );
}

fn apply_layer(dst_premul: vec4<f32>, straight: vec4<f32>, params: vec4<f32>) -> vec4<f32> {
  let opacity = clamp(params.x, 0.0, 1.0);
  let visible = params.y;
  if (visible < 0.5 || opacity <= 0.0) {
    return dst_premul;
  }

  let a = clamp(straight.a * opacity, 0.0, 1.0);
  if (a <= 0.0) {
    return dst_premul;
  }

  // Convert straight-alpha RGBA to premultiplied RGBA.
  let premul = vec4<f32>(straight.rgb * a, a);
  return composite_over(dst_premul, premul);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
  let x = i32(pos.x);
  let y = i32(pos.y);
  let coord = vec2<i32>(x, y);

  // MVP compositor: normal blend + per-layer opacity, bottom-to-top.
  var out_premul = vec4<f32>(0.0, 0.0, 0.0, 0.0);
  out_premul = apply_layer(out_premul, unpack_straight_rgba(textureLoad(layer_tex0, coord, 0).x), cfg.layer_params[0u]);
  out_premul = apply_layer(out_premul, unpack_straight_rgba(textureLoad(layer_tex1, coord, 0).x), cfg.layer_params[1u]);
  out_premul = apply_layer(out_premul, unpack_straight_rgba(textureLoad(layer_tex2, coord, 0).x), cfg.layer_params[2u]);
  out_premul = apply_layer(out_premul, unpack_straight_rgba(textureLoad(layer_tex3, coord, 0).x), cfg.layer_params[3u]);

  // Flutter's scene graph expects premultiplied alpha.
  return clamp(out_premul, vec4<f32>(0.0), vec4<f32>(1.0));
}
