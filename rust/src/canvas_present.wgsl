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
  _pad0: u32,
  _pad1: u32,
};

@group(0) @binding(1)
var<uniform> cfg: CompositeConfig;

// (opacity, visible, clipping_mask, _) per layer. visible: 1.0=visible, 0.0=hidden.
@group(0) @binding(2)
var<storage, read> layer_params: array<vec4<f32>>;

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

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
  let x = i32(pos.x);
  let y = i32(pos.y);
  let dims = textureDimensions(layer_tex);
  var coord = vec2<i32>(x, y);
  if ((cfg.view_flags & 1u) != 0u) {
    coord.x = i32(dims.x) - 1 - coord.x;
  }

  // Normal blend + per-layer opacity, bottom-to-top.
  var out_premul = vec4<f32>(0.0, 0.0, 0.0, 0.0);
  var mask_alpha: f32 = 0.0;
  for (var i: u32 = 0u; i < cfg.layer_count; i = i + 1u) {
    let params = layer_params[i];
    let packed = textureLoad(layer_tex, coord, i32(i), 0).x;
    let opacity = clamp(params.x, 0.0, 1.0);
    let visible = params.y;
    let clipping = params.z;
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

    // Convert straight-alpha RGBA to premultiplied RGBA.
    let premul = vec4<f32>(straight.rgb * a, a);
    out_premul = composite_over(out_premul, premul);
  }

  // Flutter's scene graph expects premultiplied alpha.
  if ((cfg.view_flags & 2u) != 0u) {
    let luma = dot(out_premul.rgb, vec3<f32>(0.299, 0.587, 0.114));
    out_premul = vec4<f32>(vec3<f32>(luma), out_premul.a);
  }
  return clamp(out_premul, vec4<f32>(0.0), vec4<f32>(1.0));
}
