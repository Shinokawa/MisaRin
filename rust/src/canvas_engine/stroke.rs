use crate::gpu::brush_renderer::{BrushRenderer, BrushShape, Color, Point2D};
use crate::gpu::debug::{self, LogLevel};

use super::types::EnginePoint;

#[derive(Clone, Copy, Debug)]
pub(crate) struct EngineBrushSettings {
    pub(crate) color_argb: u32,
    pub(crate) base_radius: f32,
    pub(crate) use_pressure: bool,
    pub(crate) erase: bool,
    pub(crate) antialias_level: u32,
    pub(crate) shape: BrushShape,
    pub(crate) random_rotation: bool,
    pub(crate) rotation_seed: u32,
    pub(crate) hollow_enabled: bool,
    pub(crate) hollow_ratio: f32,
    pub(crate) hollow_erase_occluded: bool,
}

impl Default for EngineBrushSettings {
    fn default() -> Self {
        Self {
            color_argb: 0xFFFFFFFF,
            base_radius: 6.0,
            use_pressure: true,
            erase: false,
            antialias_level: 1,
            shape: BrushShape::Circle,
            random_rotation: false,
            rotation_seed: 0,
            hollow_enabled: false,
            hollow_ratio: 0.0,
            hollow_erase_occluded: false,
        }
    }
}

impl EngineBrushSettings {
    pub(crate) fn sanitize(&mut self) {
        if !self.base_radius.is_finite() {
            self.base_radius = 0.0;
        }
        if self.base_radius < 0.0 {
            self.base_radius = 0.0;
        }
        if !self.hollow_ratio.is_finite() {
            self.hollow_ratio = 0.0;
        } else {
            self.hollow_ratio = self.hollow_ratio.clamp(0.0, 1.0);
        }
        self.antialias_level = self.antialias_level.clamp(0, 3);
    }

    pub(crate) fn radius_from_pressure(&self, pressure: f32) -> f32 {
        brush_radius_from_pressure(pressure, self.base_radius, self.use_pressure)
    }
}

pub(crate) struct StrokeResampler {
    last_emitted: Option<Point2D>,
    last_pressure: f32,
    last_tick_dirty: Option<(i32, i32, i32, i32)>,
}

impl StrokeResampler {
    pub(crate) fn new() -> Self {
        Self {
            last_emitted: None,
            last_pressure: 1.0,
            last_tick_dirty: None,
        }
    }

    pub(crate) fn consume_and_draw<F: FnMut((i32, i32, i32, i32))>(
        &mut self,
        brush: &mut BrushRenderer,
        brush_settings: &EngineBrushSettings,
        layer_view: &wgpu::TextureView,
        points: Vec<EnginePoint>,
        canvas_width: u32,
        canvas_height: u32,
        before_draw: &mut F,
    ) -> bool {
        const FLAG_DOWN: u32 = 1;
        const FLAG_UP: u32 = 4;

        if points.is_empty() {
            self.last_tick_dirty = None;
            return false;
        }

        let mut emitted: Vec<(Point2D, f32)> = Vec::new();

        for p in points {
            let x = if p.x.is_finite() { p.x } else { 0.0 };
            let y = if p.y.is_finite() { p.y } else { 0.0 };
            let pressure = if p.pressure.is_finite() {
                p.pressure.clamp(0.0, 1.0)
            } else {
                0.0
            };

            let is_down = (p.flags & FLAG_DOWN) != 0;
            let is_up = (p.flags & FLAG_UP) != 0;

            let current = Point2D { x, y };
            if is_down || self.last_emitted.is_none() {
                self.last_emitted = Some(current);
                self.last_pressure = pressure;
                emitted.push((current, pressure));
                continue;
            }

            let Some(prev) = self.last_emitted else {
                continue;
            };

            let dx = current.x - prev.x;
            let dy = current.y - prev.y;
            let dist = (dx * dx + dy * dy).sqrt();
            if !dist.is_finite() || dist <= 0.0001 {
                if is_up {
                    emitted.push((current, pressure));
                    self.last_emitted = Some(current);
                    self.last_pressure = pressure;
                }
                continue;
            }

            let radius_prev = brush_settings.radius_from_pressure(self.last_pressure);
            let radius_next = brush_settings.radius_from_pressure(pressure);
            let step = resample_step_from_radius((radius_prev + radius_next) * 0.5);

            let dir_x = dx / dist;
            let dir_y = dy / dist;
            let mut traveled = 0.0f32;

            while traveled + step <= dist {
                traveled += step;
                let t = (traveled / dist).clamp(0.0, 1.0);
                let interp_pressure = self.last_pressure + (pressure - self.last_pressure) * t;
                let sample = Point2D {
                    x: prev.x + dir_x * traveled,
                    y: prev.y + dir_y * traveled,
                };
                emitted.push((sample, interp_pressure));
                self.last_emitted = Some(sample);
                self.last_pressure = interp_pressure;
            }

            if is_up {
                emitted.push((current, pressure));
                self.last_emitted = Some(current);
                self.last_pressure = pressure;
            }
        }

        if emitted.is_empty() {
            self.last_tick_dirty = None;
            return false;
        }

        brush.set_canvas_size(canvas_width, canvas_height);

        let hollow_enabled = brush_settings.hollow_enabled
            && !brush_settings.erase
            && brush_settings.hollow_ratio > 0.0001;
        let hollow_ratio = if hollow_enabled {
            brush_settings.hollow_ratio
        } else {
            0.0
        };
        let hollow_erase = hollow_enabled && brush_settings.hollow_erase_occluded;

        let mut dirty_union: Option<(i32, i32, i32, i32)> = None;
        let mut drew_any = false;
        let dirty_scale = 1.0;

        if emitted.len() == 1 {
            let (p0, pres0) = emitted[0];
            let r0 = brush_settings.radius_from_pressure(pres0);
            let dirty_r0 = r0 * dirty_scale;
            let dirty = compute_dirty_rect_i32(&[p0], &[dirty_r0], canvas_width, canvas_height);
            before_draw(dirty);
            let rotation = if brush_settings.random_rotation
                && !matches!(brush_settings.shape, BrushShape::Circle)
            {
                brush_random_rotation_radians(p0, brush_settings.rotation_seed)
            } else {
                0.0
            };
            match brush.draw_stroke(
                layer_view,
                &[p0],
                &[r0],
                Color {
                    argb: brush_settings.color_argb,
                },
                brush_settings.shape,
                brush_settings.erase,
                brush_settings.antialias_level,
                rotation,
                hollow_enabled,
                hollow_ratio,
                hollow_erase,
                hollow_enabled,
            ) {
                Ok(()) => {
                    drew_any = true;
                    dirty_union = union_dirty_rect_i32(dirty_union, dirty);
                }
                Err(err) => {
                    debug::log(
                        LogLevel::Warn,
                        format_args!("Brush draw_stroke failed: {err}"),
                    );
                }
            }
        } else if hollow_enabled {
            let mut points: Vec<Point2D> = Vec::with_capacity(emitted.len());
            let mut radii: Vec<f32> = Vec::with_capacity(emitted.len());
            for (p, pres) in &emitted {
                points.push(*p);
                radii.push(brush_settings.radius_from_pressure(*pres));
            }
            let dirty_radii: Vec<f32> = radii.iter().map(|r| r * dirty_scale).collect();
            let dirty = compute_dirty_rect_i32(&points, &dirty_radii, canvas_width, canvas_height);
            before_draw(dirty);
            let rotation = if brush_settings.random_rotation
                && !matches!(brush_settings.shape, BrushShape::Circle)
            {
                brush_random_rotation_radians(points[0], brush_settings.rotation_seed)
            } else {
                0.0
            };
            match brush.draw_stroke(
                layer_view,
                &points,
                &radii,
                Color {
                    argb: brush_settings.color_argb,
                },
                brush_settings.shape,
                brush_settings.erase,
                brush_settings.antialias_level,
                rotation,
                hollow_enabled,
                hollow_ratio,
                hollow_erase,
                hollow_enabled,
            ) {
                Ok(()) => {
                    drew_any = true;
                    dirty_union = union_dirty_rect_i32(dirty_union, dirty);
                }
                Err(err) => {
                    debug::log(
                        LogLevel::Warn,
                        format_args!("Brush draw_stroke failed: {err}"),
                    );
                }
            }
        } else {
            for i in 0..emitted.len().saturating_sub(1) {
                let (p0, pres0) = emitted[i];
                let (p1, pres1) = emitted[i + 1];
                let r0 = brush_settings.radius_from_pressure(pres0);
                let r1 = brush_settings.radius_from_pressure(pres1);
                let pts = [p0, p1];
                let radii = [r0, r1];
                let dirty_radii = [r0 * dirty_scale, r1 * dirty_scale];
                let dirty = compute_dirty_rect_i32(&pts, &dirty_radii, canvas_width, canvas_height);
                before_draw(dirty);
                let rotation = if brush_settings.random_rotation
                    && !matches!(brush_settings.shape, BrushShape::Circle)
                {
                    brush_random_rotation_radians(p0, brush_settings.rotation_seed)
                } else {
                    0.0
                };
                match brush.draw_stroke(
                    layer_view,
                    &pts,
                    &radii,
                    Color {
                        argb: brush_settings.color_argb,
                    },
                    brush_settings.shape,
                    brush_settings.erase,
                    brush_settings.antialias_level,
                    rotation,
                    hollow_enabled,
                    hollow_ratio,
                    hollow_erase,
                    hollow_enabled,
                ) {
                    Ok(()) => {
                        drew_any = true;
                        dirty_union = union_dirty_rect_i32(dirty_union, dirty);
                    }
                    Err(err) => {
                        debug::log(
                            LogLevel::Warn,
                            format_args!("Brush draw_stroke failed: {err}"),
                        );
                    }
                }
            }
        }

        self.last_tick_dirty = dirty_union;
        drew_any
    }
}

const RUST_PRESSURE_MIN_FACTOR: f32 = 0.09;

fn brush_radius_from_pressure(pressure: f32, base_radius: f32, use_pressure: bool) -> f32 {
    let base = if base_radius.is_finite() {
        base_radius.max(0.0)
    } else {
        0.0
    };
    if !use_pressure {
        return base;
    }
    let p = if pressure.is_finite() {
        pressure.clamp(0.0, 1.0)
    } else {
        0.0
    };
    base * (RUST_PRESSURE_MIN_FACTOR + (1.0 - RUST_PRESSURE_MIN_FACTOR) * p)
}

fn resample_step_from_radius(radius: f32) -> f32 {
    let r = if radius.is_finite() { radius.max(0.0) } else { 0.0 };
    (r * 0.1).clamp(0.25, 0.5)
}

pub(crate) fn map_brush_shape(index: u32) -> BrushShape {
    // Dart enum: circle=0, triangle=1, square=2, star=3.
    match index {
        0 => BrushShape::Circle,
        1 => BrushShape::Triangle,
        2 => BrushShape::Square,
        3 => BrushShape::Star,
        _ => BrushShape::Circle,
    }
}

fn brush_random_rotation_radians(center: Point2D, seed: u32) -> f32 {
    let x = (center.x * 256.0).round() as i32;
    let y = (center.y * 256.0).round() as i32;

    let mut h: u32 = 0;
    h ^= seed;
    h ^= (x as u32).wrapping_mul(0x9e3779b1);
    h ^= (y as u32).wrapping_mul(0x85ebca77);
    h = mix32(h);

    let unit = (h as f64) / 4294967296.0;
    (unit * std::f64::consts::PI * 2.0) as f32
}

fn mix32(mut h: u32) -> u32 {
    h ^= h >> 16;
    h = h.wrapping_mul(0x7feb352d);
    h ^= h >> 15;
    h = h.wrapping_mul(0x846ca68b);
    h ^= h >> 16;
    h
}

fn compute_dirty_rect_i32(
    points: &[Point2D],
    radii: &[f32],
    canvas_width: u32,
    canvas_height: u32,
) -> (i32, i32, i32, i32) {
    if canvas_width == 0 || canvas_height == 0 || points.is_empty() || points.len() != radii.len()
    {
        return (0, 0, 0, 0);
    }

    let mut min_x: f32 = f32::INFINITY;
    let mut min_y: f32 = f32::INFINITY;
    let mut max_x: f32 = f32::NEG_INFINITY;
    let mut max_y: f32 = f32::NEG_INFINITY;
    let mut max_r: f32 = 0.0;

    for (p, &r) in points.iter().zip(radii.iter()) {
        let x = if p.x.is_finite() { p.x } else { 0.0 };
        let y = if p.y.is_finite() { p.y } else { 0.0 };
        let radius = if r.is_finite() { r.max(0.0) } else { 0.0 };
        min_x = min_x.min(x);
        min_y = min_y.min(y);
        max_x = max_x.max(x);
        max_y = max_y.max(y);
        max_r = max_r.max(radius);
    }

    if !min_x.is_finite() || !min_y.is_finite() || !max_x.is_finite() || !max_y.is_finite() {
        return (0, 0, 0, 0);
    }

    let pad = max_r + 2.0;
    let left = ((min_x - pad).floor() as i64).clamp(0, canvas_width as i64);
    let top = ((min_y - pad).floor() as i64).clamp(0, canvas_height as i64);
    let right = ((max_x + pad).ceil() as i64).clamp(0, canvas_width as i64);
    let bottom = ((max_y + pad).ceil() as i64).clamp(0, canvas_height as i64);

    let width = (right - left).max(0) as i32;
    let height = (bottom - top).max(0) as i32;
    (left as i32, top as i32, width, height)
}

fn union_dirty_rect_i32(
    existing: Option<(i32, i32, i32, i32)>,
    candidate: (i32, i32, i32, i32),
) -> Option<(i32, i32, i32, i32)> {
    let (cl, ct, cw, ch) = candidate;
    if cw <= 0 || ch <= 0 {
        return existing;
    }
    let Some((el, et, ew, eh)) = existing else {
        return Some(candidate);
    };
    if ew <= 0 || eh <= 0 {
        return Some(candidate);
    }

    let el64 = el as i64;
    let et64 = et as i64;
    let er64 = el64 + ew as i64;
    let eb64 = et64 + eh as i64;

    let cl64 = cl as i64;
    let ct64 = ct as i64;
    let cr64 = cl64 + cw as i64;
    let cb64 = ct64 + ch as i64;

    let left = el64.min(cl64);
    let top = et64.min(ct64);
    let right = er64.max(cr64);
    let bottom = eb64.max(cb64);

    let width = (right - left).max(0) as i32;
    let height = (bottom - top).max(0) as i32;
    Some((left as i32, top as i32, width, height))
}
