struct LayerParams {
  opacity: f32,
  visible: f32,
  clipping_mask: f32,
  _pad0: f32,
}

struct BucketFillConfig {
  width: u32,
  height: u32,
  start_x: u32,
  start_y: u32,
  start_index: u32,
  layer_index: u32,
  layer_count: u32,
  tolerance: u32,
  fill_gap: u32,
  antialias_level: u32,
  contiguous: u32,
  sample_all_layers: u32,
  selection_enabled: u32,
  swallow_count: u32,
  fill_color: u32,
  mode: u32,
  aux0: u32,
  aux1: u32,
  aux2: u32,
  aa_factor: f32,
}

struct BucketFillState {
  base_color: atomic<u32>,
  changed: atomic<u32>,
  iter_flag: atomic<u32>,
  effective_start: atomic<u32>,
  touches_outside: atomic<u32>,
  snap_found: atomic<u32>,
}

@group(0) @binding(0) var layer_tex: texture_storage_2d<r32uint, read_write>;
@group(0) @binding(1) var layers_tex: texture_2d_array<u32>;
@group(0) @binding(2) var mask_a: texture_storage_2d<r32uint, read_write>;
@group(0) @binding(3) var mask_b: texture_storage_2d<r32uint, read_write>;
@group(0) @binding(4) var<storage, read> layer_params: array<LayerParams>;
@group(0) @binding(5) var<storage, read_write> state: BucketFillState;
@group(0) @binding(6) var<storage, read> swallow_colors: array<u32>;
@group(0) @binding(7) var<uniform> cfg: BucketFillConfig;

const MASK_SELECTION: u32 = 1u;
const MASK_TARGET: u32 = 2u;
const MASK_FILL: u32 = 4u;

const MASK_OPENED: u32 = 1u;
const MASK_OUTSIDE: u32 = 2u;
const MASK_FRONTIER: u32 = 4u;
const MASK_NEXT: u32 = 8u;
const MASK_VISITED: u32 = 16u;
const MASK_EXPANDED: u32 = 32u;
const MASK_TEMP: u32 = 64u;

const MODE_CLEAR: u32 = 0u;
const MODE_READ_BASE: u32 = 1u;
const MODE_BUILD_TARGET: u32 = 2u;
const MODE_COPY_TARGET_TO_FILL: u32 = 3u;
const MODE_INIT_INVERSE: u32 = 4u;
const MODE_DILATE_STEP: u32 = 5u;
const MODE_INVERT_MASKB: u32 = 6u;
const MODE_INIT_OUTSIDE: u32 = 7u;
const MODE_EXPAND_OUTSIDE: u32 = 8u;
const MODE_FRONTIER_SWAP: u32 = 9u;
const MODE_FILL_INIT: u32 = 10u;
const MODE_FILL_EXPAND: u32 = 11u;
const MODE_SNAP_INIT: u32 = 12u;
const MODE_SNAP_EXPAND: u32 = 13u;
const MODE_TOUCH_INIT: u32 = 14u;
const MODE_TOUCH_EXPAND: u32 = 15u;
const MODE_APPLY_FILL: u32 = 16u;
const MODE_SWALLOW_SEED: u32 = 17u;
const MODE_SWALLOW_EXPAND: u32 = 18u;
const MODE_EXPAND_MASK: u32 = 19u;
const MODE_AA_PASS: u32 = 20u;
const MODE_COPY_TEMP_TO_LAYER: u32 = 21u;
const MODE_COPY_MASKB_BIT: u32 = 22u;
const MODE_EXPAND_FILL_ONE: u32 = 23u;

fn mul255(channel: u32, alpha: u32) -> u32 {
  return (channel * alpha + 127u) / 255u;
}

fn blend_argb(dst: u32, src: u32) -> u32 {
  let src_a = (src >> 24u) & 0xffu;
  if (src_a == 0u) {
    return dst;
  }
  if (src_a == 255u) {
    return src;
  }
  let dst_a = (dst >> 24u) & 0xffu;
  let inv_src_a = 255u - src_a;
  let out_a = src_a + mul255(dst_a, inv_src_a);
  if (out_a == 0u) {
    return 0u;
  }

  let src_r = (src >> 16u) & 0xffu;
  let src_g = (src >> 8u) & 0xffu;
  let src_b = src & 0xffu;
  let dst_r = (dst >> 16u) & 0xffu;
  let dst_g = (dst >> 8u) & 0xffu;
  let dst_b = dst & 0xffu;

  let src_prem_r = mul255(src_r, src_a);
  let src_prem_g = mul255(src_g, src_a);
  let src_prem_b = mul255(src_b, src_a);
  let dst_prem_r = mul255(dst_r, dst_a);
  let dst_prem_g = mul255(dst_g, dst_a);
  let dst_prem_b = mul255(dst_b, dst_a);

  let out_prem_r = src_prem_r + mul255(dst_prem_r, inv_src_a);
  let out_prem_g = src_prem_g + mul255(dst_prem_g, inv_src_a);
  let out_prem_b = src_prem_b + mul255(dst_prem_b, inv_src_a);

  let out_r = min((out_prem_r * 255u + (out_a >> 1u)) / out_a, 255u);
  let out_g = min((out_prem_g * 255u + (out_a >> 1u)) / out_a, 255u);
  let out_b = min((out_prem_b * 255u + (out_a >> 1u)) / out_a, 255u);

  return (out_a << 24u) | (out_r << 16u) | (out_g << 8u) | out_b;
}

fn colors_within_tolerance(a: u32, b: u32, tolerance: u32) -> bool {
  if (tolerance == 0u) {
    return a == b;
  }
  let aa = i32((a >> 24u) & 0xffu);
  let ar = i32((a >> 16u) & 0xffu);
  let ag = i32((a >> 8u) & 0xffu);
  let ab = i32(a & 0xffu);

  let ba = i32((b >> 24u) & 0xffu);
  let br = i32((b >> 16u) & 0xffu);
  let bg = i32((b >> 8u) & 0xffu);
  let bb = i32(b & 0xffu);

  let t = i32(tolerance);
  return abs(aa - ba) <= t && abs(ar - br) <= t && abs(ag - bg) <= t && abs(ab - bb) <= t;
}

fn sample_color(x: u32, y: u32) -> u32 {
  if (cfg.sample_all_layers == 0u) {
    return textureLoad(layers_tex, vec2<i32>(i32(x), i32(y)), i32(cfg.layer_index), 0).x;
  }

  var color: u32 = 0u;
  var initialized: bool = false;
  var mask_alpha: u32 = 0u;

  let count = cfg.layer_count;
  for (var i: u32 = 0u; i < count; i = i + 1u) {
    let params = layer_params[i];
    if (params.visible <= 0.0) {
      continue;
    }
    let opacity = clamp(params.opacity, 0.0, 1.0);
    let clipping = params.clipping_mask > 0.0;
    if (opacity <= 0.0) {
      if (!clipping) {
        mask_alpha = 0u;
      }
      continue;
    }
    let src = textureLoad(layers_tex, vec2<i32>(i32(x), i32(y)), i32(i), 0).x;
    let src_a = (src >> 24u) & 0xffu;
    if (src_a == 0u) {
      if (!clipping) {
        mask_alpha = 0u;
      }
      continue;
    }
    var total_opacity = opacity;
    if (clipping) {
      if (mask_alpha == 0u) {
        continue;
      }
      total_opacity = total_opacity * (f32(mask_alpha) / 255.0);
      if (total_opacity <= 0.0) {
        continue;
      }
    }
    var effective_a = u32(round(f32(src_a) * total_opacity));
    if (effective_a == 0u) {
      if (!clipping) {
        mask_alpha = 0u;
      }
      continue;
    }
    if (effective_a > 255u) {
      effective_a = 255u;
    }
    if (!clipping) {
      mask_alpha = effective_a;
    }
    let effective_color = (effective_a << 24u) | (src & 0x00ffffffu);
    if (!initialized) {
      color = effective_color;
      initialized = true;
    } else {
      color = blend_argb(color, effective_color);
    }
  }

  if (initialized) {
    return color;
  }
  return 0u;
}

fn selection_ok(a: u32) -> bool {
  if (cfg.selection_enabled == 0u) {
    return true;
  }
  return (a & MASK_SELECTION) != 0u;
}

fn neighbor_has_frontier(x: u32, y: u32) -> bool {
  if (x > 0u) {
    let b = textureLoad(mask_b, vec2<i32>(i32(x - 1u), i32(y))).x;
    if ((b & MASK_FRONTIER) != 0u) {
      return true;
    }
  }
  if (x + 1u < cfg.width) {
    let b = textureLoad(mask_b, vec2<i32>(i32(x + 1u), i32(y))).x;
    if ((b & MASK_FRONTIER) != 0u) {
      return true;
    }
  }
  if (y > 0u) {
    let b = textureLoad(mask_b, vec2<i32>(i32(x), i32(y - 1u))).x;
    if ((b & MASK_FRONTIER) != 0u) {
      return true;
    }
  }
  if (y + 1u < cfg.height) {
    let b = textureLoad(mask_b, vec2<i32>(i32(x), i32(y + 1u))).x;
    if ((b & MASK_FRONTIER) != 0u) {
      return true;
    }
  }
  return false;
}

fn neighbor_has_fill(x: u32, y: u32) -> bool {
  if (x > 0u) {
    let a = textureLoad(mask_a, vec2<i32>(i32(x - 1u), i32(y))).x;
    if ((a & MASK_FILL) != 0u) {
      return true;
    }
  }
  if (x + 1u < cfg.width) {
    let a = textureLoad(mask_a, vec2<i32>(i32(x + 1u), i32(y))).x;
    if ((a & MASK_FILL) != 0u) {
      return true;
    }
  }
  if (y > 0u) {
    let a = textureLoad(mask_a, vec2<i32>(i32(x), i32(y - 1u))).x;
    if ((a & MASK_FILL) != 0u) {
      return true;
    }
  }
  if (y + 1u < cfg.height) {
    let a = textureLoad(mask_a, vec2<i32>(i32(x), i32(y + 1u))).x;
    if ((a & MASK_FILL) != 0u) {
      return true;
    }
  }
  return false;
}

@compute @workgroup_size(16, 16)
fn bucket_fill_main(@builtin(global_invocation_id) id: vec3<u32>) {
  let x = id.x;
  let y = id.y;
  if (x >= cfg.width || y >= cfg.height) {
    return;
  }
  let mode = cfg.mode;

  if (mode == MODE_CLEAR) {
    var a = textureLoad(mask_a, vec2<i32>(i32(x), i32(y))).x;
    if (cfg.selection_enabled == 0u) {
      a = 0u;
    } else {
      a = a & MASK_SELECTION;
    }
    textureStore(mask_a, vec2<i32>(i32(x), i32(y)), vec4<u32>(a, 0u, 0u, 0u));
    textureStore(mask_b, vec2<i32>(i32(x), i32(y)), vec4<u32>(0u, 0u, 0u, 0u));
    return;
  }

  if (mode == MODE_READ_BASE) {
    if (x != cfg.start_x || y != cfg.start_y) {
      return;
    }
    let color = sample_color(x, y);
    atomicStore(&state.base_color, color);
    return;
  }

  if (mode == MODE_BUILD_TARGET) {
    var a = textureLoad(mask_a, vec2<i32>(i32(x), i32(y))).x;
    let ok = selection_ok(a);
    let base = atomicLoad(&state.base_color);
    var is_target: bool = false;
    if (ok) {
      let sample = sample_color(x, y);
      is_target = colors_within_tolerance(sample, base, cfg.tolerance);
    }
    a = (a & MASK_SELECTION) | select(0u, MASK_TARGET, is_target);
    textureStore(mask_a, vec2<i32>(i32(x), i32(y)), vec4<u32>(a, 0u, 0u, 0u));
    return;
  }

  if (mode == MODE_COPY_TARGET_TO_FILL) {
    var a = textureLoad(mask_a, vec2<i32>(i32(x), i32(y))).x;
    let is_target = (a & MASK_TARGET) != 0u;
    if (is_target) {
      a = a | MASK_FILL;
    } else {
      a = a & ~MASK_FILL;
    }
    textureStore(mask_a, vec2<i32>(i32(x), i32(y)), vec4<u32>(a, 0u, 0u, 0u));
    return;
  }

  if (mode == MODE_INIT_INVERSE) {
    let a = textureLoad(mask_a, vec2<i32>(i32(x), i32(y))).x;
    let is_target = (a & MASK_TARGET) != 0u;
    var b: u32 = 0u;
    if (!is_target) {
      b = b | MASK_OPENED;
    }
    textureStore(mask_b, vec2<i32>(i32(x), i32(y)), vec4<u32>(b, 0u, 0u, 0u));
    return;
  }

  if (mode == MODE_DILATE_STEP) {
    let input_bit = cfg.aux0;
    let output_bit = cfg.aux1;
    let boundary = cfg.aux2 != 0u;

    var any = false;
    for (var dy: i32 = -1; dy <= 1; dy = dy + 1) {
      for (var dx: i32 = -1; dx <= 1; dx = dx + 1) {
        let nx = i32(x) + dx;
        let ny = i32(y) + dy;
        if (nx < 0 || ny < 0 || nx >= i32(cfg.width) || ny >= i32(cfg.height)) {
          if (boundary) {
            any = true;
          }
        } else {
          let b = textureLoad(mask_b, vec2<i32>(nx, ny)).x;
          if ((b & input_bit) != 0u) {
            any = true;
          }
        }
      }
    }

    var b = textureLoad(mask_b, vec2<i32>(i32(x), i32(y))).x;
    if (any) {
      b = b | output_bit;
    } else {
      b = b & ~output_bit;
    }
    textureStore(mask_b, vec2<i32>(i32(x), i32(y)), vec4<u32>(b, 0u, 0u, 0u));
    return;
  }

  if (mode == MODE_INVERT_MASKB) {
    let bit = cfg.aux0;
    var b = textureLoad(mask_b, vec2<i32>(i32(x), i32(y))).x;
    if ((b & bit) != 0u) {
      b = b & ~bit;
    } else {
      b = b | bit;
    }
    textureStore(mask_b, vec2<i32>(i32(x), i32(y)), vec4<u32>(b, 0u, 0u, 0u));
    return;
  }

  if (mode == MODE_INIT_OUTSIDE) {
    let b_in = textureLoad(mask_b, vec2<i32>(i32(x), i32(y))).x;
    let opened = (b_in & MASK_OPENED) != 0u;
    let on_edge = x == 0u || y == 0u || x + 1u == cfg.width || y + 1u == cfg.height;
    var b = b_in & MASK_OPENED;
    if (opened && on_edge) {
      b = b | MASK_OUTSIDE | MASK_FRONTIER;
    }
    textureStore(mask_b, vec2<i32>(i32(x), i32(y)), vec4<u32>(b, 0u, 0u, 0u));
    return;
  }

  if (mode == MODE_EXPAND_OUTSIDE) {
    var b = textureLoad(mask_b, vec2<i32>(i32(x), i32(y))).x;
    let opened = (b & MASK_OPENED) != 0u;
    let outside = (b & MASK_OUTSIDE) != 0u;
    let frontier_neighbor = neighbor_has_frontier(x, y);
    var next = false;
    if (!outside && opened && frontier_neighbor) {
      b = b | MASK_OUTSIDE;
      next = true;
    }
    if (next) {
      b = b | MASK_NEXT;
      atomicStore(&state.iter_flag, 1u);
    } else {
      b = b & ~MASK_NEXT;
    }
    textureStore(mask_b, vec2<i32>(i32(x), i32(y)), vec4<u32>(b, 0u, 0u, 0u));
    return;
  }

  if (mode == MODE_FRONTIER_SWAP) {
    var b = textureLoad(mask_b, vec2<i32>(i32(x), i32(y))).x;
    let next = (b & MASK_NEXT) != 0u;
    if (next) {
      b = b | MASK_FRONTIER;
    } else {
      b = b & ~MASK_FRONTIER;
    }
    b = b & ~MASK_NEXT;
    textureStore(mask_b, vec2<i32>(i32(x), i32(y)), vec4<u32>(b, 0u, 0u, 0u));
    return;
  }

  if (mode == MODE_FILL_INIT) {
    let index = y * cfg.width + x;
    var b = textureLoad(mask_b, vec2<i32>(i32(x), i32(y))).x;
    b = b & ~(MASK_FRONTIER | MASK_NEXT | MASK_VISITED);
    var a = textureLoad(mask_a, vec2<i32>(i32(x), i32(y))).x;
    if (index == cfg.start_index) {
      let is_target = (a & MASK_TARGET) != 0u;
      let use_outside = cfg.aux0 != 0u;
      let outside = (b & MASK_OUTSIDE) != 0u;
      if (is_target && (!use_outside || !outside)) {
        a = a | MASK_FILL;
        b = b | MASK_FRONTIER;
      }
    }
    textureStore(mask_a, vec2<i32>(i32(x), i32(y)), vec4<u32>(a, 0u, 0u, 0u));
    textureStore(mask_b, vec2<i32>(i32(x), i32(y)), vec4<u32>(b, 0u, 0u, 0u));
    return;
  }

  if (mode == MODE_FILL_EXPAND) {
    var a = textureLoad(mask_a, vec2<i32>(i32(x), i32(y))).x;
    var b = textureLoad(mask_b, vec2<i32>(i32(x), i32(y))).x;
    let filled = (a & MASK_FILL) != 0u;
    let is_target = (a & MASK_TARGET) != 0u;
    let use_outside = cfg.aux0 != 0u;
    let outside = (b & MASK_OUTSIDE) != 0u;
    let frontier_neighbor = neighbor_has_frontier(x, y);
    var next = false;
    if (!filled && is_target && (!use_outside || !outside) && frontier_neighbor) {
      a = a | MASK_FILL;
      next = true;
    }
    if (next) {
      b = b | MASK_NEXT;
      atomicStore(&state.iter_flag, 1u);
    } else {
      b = b & ~MASK_NEXT;
    }
    textureStore(mask_a, vec2<i32>(i32(x), i32(y)), vec4<u32>(a, 0u, 0u, 0u));
    textureStore(mask_b, vec2<i32>(i32(x), i32(y)), vec4<u32>(b, 0u, 0u, 0u));
    return;
  }

  if (mode == MODE_SNAP_INIT) {
    let index = y * cfg.width + x;
    var b = textureLoad(mask_b, vec2<i32>(i32(x), i32(y))).x;
    b = b & ~(MASK_FRONTIER | MASK_NEXT | MASK_VISITED);
    if (index == cfg.start_index) {
      let a = textureLoad(mask_a, vec2<i32>(i32(x), i32(y))).x;
      let is_target = (a & MASK_TARGET) != 0u;
      if (is_target) {
        b = b | MASK_FRONTIER | MASK_VISITED;
      }
    }
    textureStore(mask_b, vec2<i32>(i32(x), i32(y)), vec4<u32>(b, 0u, 0u, 0u));
    return;
  }

  if (mode == MODE_SNAP_EXPAND) {
    let index = y * cfg.width + x;
    var b = textureLoad(mask_b, vec2<i32>(i32(x), i32(y))).x;
    let frontier = (b & MASK_FRONTIER) != 0u;
    let opened = (b & MASK_OPENED) != 0u;
    if (frontier && opened) {
      atomicStore(&state.snap_found, 1u);
      atomicMin(&state.effective_start, index);
    }
    let visited = (b & MASK_VISITED) != 0u;
    let a = textureLoad(mask_a, vec2<i32>(i32(x), i32(y))).x;
    let is_target = (a & MASK_TARGET) != 0u;
    let frontier_neighbor = neighbor_has_frontier(x, y);
    var next = false;
    if (!visited && is_target && frontier_neighbor) {
      b = b | MASK_VISITED;
      next = true;
    }
    if (next) {
      b = b | MASK_NEXT;
      atomicStore(&state.iter_flag, 1u);
    } else {
      b = b & ~MASK_NEXT;
    }
    textureStore(mask_b, vec2<i32>(i32(x), i32(y)), vec4<u32>(b, 0u, 0u, 0u));
    return;
  }

  if (mode == MODE_TOUCH_INIT) {
    let index = y * cfg.width + x;
    let effective_start = atomicLoad(&state.effective_start);
    var b = textureLoad(mask_b, vec2<i32>(i32(x), i32(y))).x;
    b = b & ~(MASK_FRONTIER | MASK_NEXT | MASK_VISITED);
    if (index == effective_start) {
      b = b | MASK_FRONTIER | MASK_VISITED;
      if ((b & MASK_OUTSIDE) != 0u) {
        atomicStore(&state.touches_outside, 1u);
      }
    }
    textureStore(mask_b, vec2<i32>(i32(x), i32(y)), vec4<u32>(b, 0u, 0u, 0u));
    return;
  }

  if (mode == MODE_TOUCH_EXPAND) {
    var b = textureLoad(mask_b, vec2<i32>(i32(x), i32(y))).x;
    let frontier = (b & MASK_FRONTIER) != 0u;
    if (frontier && (b & MASK_OUTSIDE) != 0u) {
      atomicStore(&state.touches_outside, 1u);
    }
    let visited = (b & MASK_VISITED) != 0u;
    let opened = (b & MASK_OPENED) != 0u;
    let frontier_neighbor = neighbor_has_frontier(x, y);
    var next = false;
    if (!visited && opened && frontier_neighbor) {
      b = b | MASK_VISITED;
      next = true;
    }
    if (next) {
      b = b | MASK_NEXT;
      atomicStore(&state.iter_flag, 1u);
    } else {
      b = b & ~MASK_NEXT;
    }
    textureStore(mask_b, vec2<i32>(i32(x), i32(y)), vec4<u32>(b, 0u, 0u, 0u));
    return;
  }

  if (mode == MODE_APPLY_FILL) {
    let a = textureLoad(mask_a, vec2<i32>(i32(x), i32(y))).x;
    if ((a & MASK_FILL) == 0u) {
      return;
    }
    let current = textureLoad(layer_tex, vec2<i32>(i32(x), i32(y))).x;
    if (current != cfg.fill_color) {
      textureStore(layer_tex, vec2<i32>(i32(x), i32(y)), vec4<u32>(cfg.fill_color, 0u, 0u, 0u));
      atomicStore(&state.changed, 1u);
    }
    return;
  }

  if (mode == MODE_SWALLOW_SEED) {
    let a = textureLoad(mask_a, vec2<i32>(i32(x), i32(y))).x;
    var b = textureLoad(mask_b, vec2<i32>(i32(x), i32(y))).x;
    b = b & ~(MASK_FRONTIER | MASK_NEXT | MASK_VISITED);
    if (selection_ok(a)) {
      let color = textureLoad(layer_tex, vec2<i32>(i32(x), i32(y))).x;
      let swallow = swallow_colors[cfg.aux0];
      if (color == swallow && neighbor_has_fill(x, y)) {
        b = b | MASK_FRONTIER | MASK_VISITED;
        atomicStore(&state.iter_flag, 1u);
      }
    }
    textureStore(mask_b, vec2<i32>(i32(x), i32(y)), vec4<u32>(b, 0u, 0u, 0u));
    return;
  }

  if (mode == MODE_SWALLOW_EXPAND) {
    var b = textureLoad(mask_b, vec2<i32>(i32(x), i32(y))).x;
    let a = textureLoad(mask_a, vec2<i32>(i32(x), i32(y))).x;
    b = b & ~MASK_NEXT;
    if (selection_ok(a)) {
      let swallow = swallow_colors[cfg.aux0];
      let color = textureLoad(layer_tex, vec2<i32>(i32(x), i32(y))).x;
      let frontier = (b & MASK_FRONTIER) != 0u;
      if (frontier && color == swallow) {
        if (color != cfg.fill_color) {
          textureStore(layer_tex, vec2<i32>(i32(x), i32(y)), vec4<u32>(cfg.fill_color, 0u, 0u, 0u));
          atomicStore(&state.changed, 1u);
        }
      }
      let visited = (b & MASK_VISITED) != 0u;
      let frontier_neighbor = neighbor_has_frontier(x, y);
      var next = false;
      if (!visited && color == swallow && frontier_neighbor) {
        b = b | MASK_VISITED;
        next = true;
      }
      if (next) {
        b = b | MASK_NEXT;
        atomicStore(&state.iter_flag, 1u);
      }
    }
    textureStore(mask_b, vec2<i32>(i32(x), i32(y)), vec4<u32>(b, 0u, 0u, 0u));
    return;
  }

  if (mode == MODE_EXPAND_MASK) {
    let a = textureLoad(mask_a, vec2<i32>(i32(x), i32(y))).x;
    var b = textureLoad(mask_b, vec2<i32>(i32(x), i32(y))).x;
    var expanded = false;
    if (selection_ok(a)) {
      for (var dy: i32 = -1; dy <= 1; dy = dy + 1) {
        for (var dx: i32 = -1; dx <= 1; dx = dx + 1) {
          let nx = i32(x) + dx;
          let ny = i32(y) + dy;
          if (nx < 0 || ny < 0 || nx >= i32(cfg.width) || ny >= i32(cfg.height)) {
            continue;
          }
          let na = textureLoad(mask_a, vec2<i32>(nx, ny)).x;
          if ((na & MASK_FILL) != 0u) {
            expanded = true;
          }
        }
      }
    }
    if (expanded) {
      b = b | MASK_EXPANDED;
    } else {
      b = b & ~MASK_EXPANDED;
    }
    textureStore(mask_b, vec2<i32>(i32(x), i32(y)), vec4<u32>(b, 0u, 0u, 0u));
    return;
  }

  if (mode == MODE_AA_PASS) {
    let b = textureLoad(mask_b, vec2<i32>(i32(x), i32(y))).x;
    let expanded = (b & MASK_EXPANDED) != 0u;
    let use_layer_src = cfg.aux0 != 0u;
    let src = select(
      textureLoad(mask_a, vec2<i32>(i32(x), i32(y))).x,
      textureLoad(layer_tex, vec2<i32>(i32(x), i32(y))).x,
      use_layer_src
    );
    var out = src;
    if (expanded && cfg.aa_factor > 0.0) {
      let alpha = i32((src >> 24u) & 0xffu);
      let center_r = i32((src >> 16u) & 0xffu);
      let center_g = i32((src >> 8u) & 0xffu);
      let center_b = i32(src & 0xffu);

      var total_weight: i32 = 4;
      var weighted_alpha: i32 = alpha * 4;
      var weighted_premul_r: i32 = center_r * alpha * 4;
      var weighted_premul_g: i32 = center_g * alpha * 4;
      var weighted_premul_b: i32 = center_b * alpha * 4;

      for (var dy: i32 = -1; dy <= 1; dy = dy + 1) {
        for (var dx: i32 = -1; dx <= 1; dx = dx + 1) {
          if (dx == 0 && dy == 0) {
            continue;
          }
          let nx = i32(x) + dx;
          let ny = i32(y) + dy;
          if (nx < 0 || ny < 0 || nx >= i32(cfg.width) || ny >= i32(cfg.height)) {
            continue;
          }
          let neighbor = select(
            textureLoad(mask_a, vec2<i32>(nx, ny)).x,
            textureLoad(layer_tex, vec2<i32>(nx, ny)).x,
            use_layer_src
          );
          let na = i32((neighbor >> 24u) & 0xffu);
          let w = select(1, 2, dx == 0 || dy == 0);
          total_weight = total_weight + w;
          if (na == 0) {
            continue;
          }
          weighted_alpha = weighted_alpha + na * w;
          weighted_premul_r = weighted_premul_r + i32((neighbor >> 16u) & 0xffu) * na * w;
          weighted_premul_g = weighted_premul_g + i32((neighbor >> 8u) & 0xffu) * na * w;
          weighted_premul_b = weighted_premul_b + i32(neighbor & 0xffu) * na * w;
        }
      }

      if (total_weight > 0) {
        let candidate_alpha = clamp(weighted_alpha / total_weight, 0, 255);
        let delta_alpha = candidate_alpha - alpha;
        if (delta_alpha != 0) {
          let new_alpha = clamp(
            alpha + i32(round(f32(delta_alpha) * cfg.aa_factor)),
            0,
            255
          );
          if (new_alpha != alpha) {
            var new_r = center_r;
            var new_g = center_g;
            var new_b = center_b;
            if (delta_alpha > 0) {
              let bounded_alpha = max(weighted_alpha, 1);
              new_r = clamp(weighted_premul_r / bounded_alpha, 0, 255);
              new_g = clamp(weighted_premul_g / bounded_alpha, 0, 255);
              new_b = clamp(weighted_premul_b / bounded_alpha, 0, 255);
            }
            out = (u32(new_alpha) << 24u)
              | (u32(new_r) << 16u)
              | (u32(new_g) << 8u)
              | u32(new_b);
          }
        }
      }
    }
    if (out != src) {
      atomicStore(&state.changed, 1u);
    }
    if (use_layer_src) {
      textureStore(mask_a, vec2<i32>(i32(x), i32(y)), vec4<u32>(out, 0u, 0u, 0u));
    } else {
      textureStore(layer_tex, vec2<i32>(i32(x), i32(y)), vec4<u32>(out, 0u, 0u, 0u));
    }
    return;
  }

  if (mode == MODE_COPY_TEMP_TO_LAYER) {
    let src = textureLoad(mask_a, vec2<i32>(i32(x), i32(y))).x;
    textureStore(layer_tex, vec2<i32>(i32(x), i32(y)), vec4<u32>(src, 0u, 0u, 0u));
    return;
  }

  if (mode == MODE_COPY_MASKB_BIT) {
    let src_bit = cfg.aux0;
    let dst_bit = cfg.aux1;
    var b = textureLoad(mask_b, vec2<i32>(i32(x), i32(y))).x;
    let has = (b & src_bit) != 0u;
    if (has) {
      b = b | dst_bit;
    } else {
      b = b & ~dst_bit;
    }
    b = b & ~src_bit;
    textureStore(mask_b, vec2<i32>(i32(x), i32(y)), vec4<u32>(b, 0u, 0u, 0u));
    return;
  }

  if (mode == MODE_EXPAND_FILL_ONE) {
    var a = textureLoad(mask_a, vec2<i32>(i32(x), i32(y))).x;
    if ((a & MASK_FILL) == 0u && selection_ok(a) && neighbor_has_fill(x, y)) {
      a = a | MASK_FILL;
    }
    textureStore(mask_a, vec2<i32>(i32(x), i32(y)), vec4<u32>(a, 0u, 0u, 0u));
    return;
  }
}
