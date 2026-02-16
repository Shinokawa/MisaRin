use crate::cpu_brush::{
    cpu_brush_apply_streamline, cpu_brush_draw_capsule_segment, cpu_brush_draw_spray,
    cpu_brush_draw_stamp, cpu_brush_draw_stamp_segment, cpu_brush_fill_polygon,
};

#[flutter_rust_bridge::frb]
pub struct CpuBrushResult {
    pub ok: bool,
    pub pixels: Vec<u32>,
}

#[flutter_rust_bridge::frb]
pub struct CpuStreamlineResult {
    pub ok: bool,
    pub samples: Vec<f32>,
}

fn bool_to_u8(v: bool) -> u8 {
    if v { 1 } else { 0 }
}

#[flutter_rust_bridge::frb(sync)]
pub fn cpu_brush_draw_stamp_rgba(
    pixels: Vec<u32>,
    width: u32,
    height: u32,
    center_x: f32,
    center_y: f32,
    radius: f32,
    color_argb: u32,
    brush_shape: u32,
    antialias_level: u32,
    softness: f32,
    erase: bool,
    random_rotation: bool,
    rotation_seed: u32,
    rotation_jitter: f32,
    snap_to_pixel: bool,
    selection: Option<Vec<u8>>,
) -> CpuBrushResult {
    let mut pixels = pixels;
    let (selection_ptr, selection_len) = match selection.as_ref() {
        Some(mask) => (mask.as_ptr(), mask.len()),
        None => (std::ptr::null(), 0),
    };
    let ok = cpu_brush_draw_stamp(
        pixels.as_mut_ptr(),
        pixels.len(),
        width,
        height,
        center_x,
        center_y,
        radius,
        color_argb,
        brush_shape,
        antialias_level,
        softness,
        bool_to_u8(erase),
        bool_to_u8(random_rotation),
        rotation_seed,
        rotation_jitter,
        bool_to_u8(snap_to_pixel),
        selection_ptr,
        selection_len,
    );
    CpuBrushResult {
        ok: ok != 0,
        pixels,
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn cpu_brush_draw_capsule_segment_rgba(
    pixels: Vec<u32>,
    width: u32,
    height: u32,
    ax: f32,
    ay: f32,
    bx: f32,
    by: f32,
    start_radius: f32,
    end_radius: f32,
    color_argb: u32,
    antialias_level: u32,
    include_start_cap: bool,
    erase: bool,
    selection: Option<Vec<u8>>,
) -> CpuBrushResult {
    let mut pixels = pixels;
    let (selection_ptr, selection_len) = match selection.as_ref() {
        Some(mask) => (mask.as_ptr(), mask.len()),
        None => (std::ptr::null(), 0),
    };
    let ok = cpu_brush_draw_capsule_segment(
        pixels.as_mut_ptr(),
        pixels.len(),
        width,
        height,
        ax,
        ay,
        bx,
        by,
        start_radius,
        end_radius,
        color_argb,
        antialias_level,
        bool_to_u8(include_start_cap),
        bool_to_u8(erase),
        selection_ptr,
        selection_len,
    );
    CpuBrushResult {
        ok: ok != 0,
        pixels,
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn cpu_brush_fill_polygon_rgba(
    pixels: Vec<u32>,
    width: u32,
    height: u32,
    vertices: Vec<f32>,
    radius: f32,
    color_argb: u32,
    antialias_level: u32,
    softness: f32,
    erase: bool,
    selection: Option<Vec<u8>>,
) -> CpuBrushResult {
    let mut pixels = pixels;
    let (selection_ptr, selection_len) = match selection.as_ref() {
        Some(mask) => (mask.as_ptr(), mask.len()),
        None => (std::ptr::null(), 0),
    };
    let ok = cpu_brush_fill_polygon(
        pixels.as_mut_ptr(),
        pixels.len(),
        width,
        height,
        vertices.as_ptr(),
        vertices.len(),
        radius,
        color_argb,
        antialias_level,
        softness,
        bool_to_u8(erase),
        selection_ptr,
        selection_len,
    );
    CpuBrushResult {
        ok: ok != 0,
        pixels,
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn cpu_brush_draw_stamp_segment_rgba(
    pixels: Vec<u32>,
    width: u32,
    height: u32,
    start_x: f32,
    start_y: f32,
    end_x: f32,
    end_y: f32,
    start_radius: f32,
    end_radius: f32,
    color_argb: u32,
    brush_shape: u32,
    antialias_level: u32,
    include_start: bool,
    erase: bool,
    random_rotation: bool,
    rotation_seed: u32,
    rotation_jitter: f32,
    spacing: f32,
    scatter: f32,
    softness: f32,
    snap_to_pixel: bool,
    accumulate: bool,
    selection: Option<Vec<u8>>,
) -> CpuBrushResult {
    let mut pixels = pixels;
    let (selection_ptr, selection_len) = match selection.as_ref() {
        Some(mask) => (mask.as_ptr(), mask.len()),
        None => (std::ptr::null(), 0),
    };
    let ok = cpu_brush_draw_stamp_segment(
        pixels.as_mut_ptr(),
        pixels.len(),
        width,
        height,
        start_x,
        start_y,
        end_x,
        end_y,
        start_radius,
        end_radius,
        color_argb,
        brush_shape,
        antialias_level,
        bool_to_u8(include_start),
        bool_to_u8(erase),
        bool_to_u8(random_rotation),
        rotation_seed,
        rotation_jitter,
        spacing,
        scatter,
        softness,
        bool_to_u8(snap_to_pixel),
        bool_to_u8(accumulate),
        selection_ptr,
        selection_len,
    );
    CpuBrushResult {
        ok: ok != 0,
        pixels,
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn cpu_brush_draw_spray_rgba(
    pixels: Vec<u32>,
    width: u32,
    height: u32,
    points: Vec<f32>,
    color_argb: u32,
    brush_shape: u32,
    antialias_level: u32,
    softness: f32,
    erase: bool,
    accumulate: bool,
    selection: Option<Vec<u8>>,
) -> CpuBrushResult {
    let mut pixels = pixels;
    let (selection_ptr, selection_len) = match selection.as_ref() {
        Some(mask) => (mask.as_ptr(), mask.len()),
        None => (std::ptr::null(), 0),
    };
    let ok = cpu_brush_draw_spray(
        pixels.as_mut_ptr(),
        pixels.len(),
        width,
        height,
        points.as_ptr(),
        points.len(),
        color_argb,
        brush_shape,
        antialias_level,
        softness,
        bool_to_u8(erase),
        bool_to_u8(accumulate),
        selection_ptr,
        selection_len,
    );
    CpuBrushResult {
        ok: ok != 0,
        pixels,
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn cpu_brush_apply_streamline_samples(
    samples: Vec<f32>,
    strength: f32,
) -> CpuStreamlineResult {
    let mut samples = samples;
    let ok = cpu_brush_apply_streamline(samples.as_mut_ptr(), samples.len(), strength);
    CpuStreamlineResult {
        ok: ok != 0,
        samples,
    }
}
