use crate::gpu::brush_renderer::{
    BrushRenderer, BrushShape, Color, Point2D, PointRotation, MAX_POINTS,
};
use crate::gpu::debug::{self, LogLevel};

use super::types::EnginePoint;

pub(crate) const INK_CURVE_SAMPLES: usize = 64;

#[derive(Clone, Copy, Debug)]
pub(crate) struct EngineBrushSettings {
    pub(crate) color_argb: u32,
    pub(crate) base_radius: f32,
    pub(crate) use_pressure: bool,
    pub(crate) erase: bool,
    pub(crate) antialias_level: u32,
    pub(crate) shape: BrushShape,
    pub(crate) random_rotation: bool,
    pub(crate) smooth_rotation: bool,
    pub(crate) rotation_seed: u32,
    pub(crate) spacing: f32,
    pub(crate) hardness: f32,
    pub(crate) flow: f32,
    pub(crate) scatter: f32,
    pub(crate) rotation_jitter: f32,
    pub(crate) snap_to_pixel: bool,
    pub(crate) screentone_enabled: bool,
    pub(crate) screentone_spacing: f32,
    pub(crate) screentone_dot_size: f32,
    pub(crate) screentone_rotation: f32,
    pub(crate) screentone_softness: f32,
    pub(crate) screentone_shape: BrushShape,
    pub(crate) hollow_enabled: bool,
    pub(crate) hollow_ratio: f32,
    pub(crate) hollow_erase_occluded: bool,
    pub(crate) streamline_strength: f32,
    pub(crate) smoothing_mode: u8,
    pub(crate) stabilizer_strength: f32,
    pub(crate) custom_mask_enabled: bool,
    pub(crate) bristle_enabled: bool,
    pub(crate) bristle_density: f32,
    pub(crate) bristle_random: f32,
    pub(crate) bristle_scale: f32,
    pub(crate) bristle_shear: f32,
    pub(crate) bristle_threshold: bool,
    pub(crate) bristle_connected: bool,
    pub(crate) bristle_use_pressure: bool,
    pub(crate) bristle_antialias: bool,
    pub(crate) bristle_use_compositing: bool,
    pub(crate) ink_amount: f32,
    pub(crate) ink_depletion: f32,
    pub(crate) ink_use_opacity: bool,
    pub(crate) ink_depletion_enabled: bool,
    pub(crate) ink_use_saturation: bool,
    pub(crate) ink_use_weights: bool,
    pub(crate) ink_pressure_weight: f32,
    pub(crate) ink_bristle_length_weight: f32,
    pub(crate) ink_bristle_ink_weight: f32,
    pub(crate) ink_depletion_weight: f32,
    pub(crate) ink_use_soak: bool,
    pub(crate) ink_depletion_curve: [f32; INK_CURVE_SAMPLES],
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
            smooth_rotation: false,
            rotation_seed: 0,
            spacing: 0.15,
            hardness: 0.8,
            flow: 1.0,
            scatter: 0.0,
            rotation_jitter: 1.0,
            snap_to_pixel: false,
            screentone_enabled: false,
            screentone_spacing: 10.0,
            screentone_dot_size: 0.6,
            screentone_rotation: 45.0,
            screentone_softness: 0.0,
            screentone_shape: BrushShape::Circle,
            hollow_enabled: false,
            hollow_ratio: 0.0,
            hollow_erase_occluded: false,
            streamline_strength: 0.0,
            smoothing_mode: 1,
            stabilizer_strength: 0.0,
            custom_mask_enabled: false,
            bristle_enabled: false,
            bristle_density: 0.0,
            bristle_random: 0.0,
            bristle_scale: 1.0,
            bristle_shear: 0.0,
            bristle_threshold: false,
            bristle_connected: false,
            bristle_use_pressure: true,
            bristle_antialias: false,
            bristle_use_compositing: true,
            ink_amount: 1.0,
            ink_depletion: 0.0,
            ink_use_opacity: true,
            ink_depletion_enabled: false,
            ink_use_saturation: false,
            ink_use_weights: false,
            ink_pressure_weight: 0.5,
            ink_bristle_length_weight: 0.5,
            ink_bristle_ink_weight: 0.5,
            ink_depletion_weight: 0.5,
            ink_use_soak: false,
            ink_depletion_curve: default_ink_curve(),
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
        if !self.spacing.is_finite() {
            self.spacing = 0.15;
        } else {
            self.spacing = self.spacing.clamp(0.02, 2.5);
        }
        if !self.hardness.is_finite() {
            self.hardness = 0.8;
        } else {
            self.hardness = self.hardness.clamp(0.0, 1.0);
        }
        if !self.flow.is_finite() {
            self.flow = 1.0;
        } else {
            self.flow = self.flow.clamp(0.0, 1.0);
        }
        if !self.scatter.is_finite() {
            self.scatter = 0.0;
        } else {
            self.scatter = self.scatter.clamp(0.0, 1.0);
        }
        if !self.rotation_jitter.is_finite() {
            self.rotation_jitter = 1.0;
        } else {
            self.rotation_jitter = self.rotation_jitter.clamp(0.0, 1.0);
        }
        if !self.screentone_spacing.is_finite() {
            self.screentone_spacing = 10.0;
        } else {
            self.screentone_spacing = self.screentone_spacing.clamp(2.0, 200.0);
        }
        if !self.screentone_dot_size.is_finite() {
            self.screentone_dot_size = 0.6;
        } else {
            self.screentone_dot_size = self.screentone_dot_size.clamp(0.0, 1.0);
        }
        if !self.screentone_rotation.is_finite() {
            self.screentone_rotation = 45.0;
        } else {
            self.screentone_rotation = self.screentone_rotation.clamp(-180.0, 180.0);
        }
        if !self.screentone_softness.is_finite() {
            self.screentone_softness = 0.0;
        } else {
            self.screentone_softness = self.screentone_softness.clamp(0.0, 1.0);
        }
        if !self.hollow_ratio.is_finite() {
            self.hollow_ratio = 0.0;
        } else {
            self.hollow_ratio = self.hollow_ratio.clamp(0.0, 1.0);
        }
        if !self.streamline_strength.is_finite() {
            self.streamline_strength = 0.0;
        } else {
            self.streamline_strength = self.streamline_strength.clamp(0.0, 1.0);
        }
        if !self.stabilizer_strength.is_finite() {
            self.stabilizer_strength = 0.0;
        } else {
            self.stabilizer_strength = self.stabilizer_strength.clamp(0.0, 1.0);
        }
        if !self.bristle_density.is_finite() {
            self.bristle_density = 0.0;
        } else {
            self.bristle_density = self.bristle_density.clamp(0.0, 1.0);
        }
        if !self.bristle_random.is_finite() {
            self.bristle_random = 0.0;
        } else {
            self.bristle_random = self.bristle_random.clamp(0.0, 10.0);
        }
        if !self.bristle_scale.is_finite() {
            self.bristle_scale = 1.0;
        } else {
            self.bristle_scale = self.bristle_scale.clamp(0.1, 10.0);
        }
        if !self.bristle_shear.is_finite() {
            self.bristle_shear = 0.0;
        } else {
            self.bristle_shear = self.bristle_shear.clamp(0.0, 2.0);
        }
        if !self.ink_amount.is_finite() {
            self.ink_amount = 1.0;
        } else {
            self.ink_amount = self.ink_amount.clamp(0.0, 1.0);
        }
        if !self.ink_depletion.is_finite() {
            self.ink_depletion = 0.0;
        } else {
            self.ink_depletion = self.ink_depletion.clamp(0.0, 1.0);
        }
        self.ink_pressure_weight = normalize_weight(self.ink_pressure_weight, 0.5);
        self.ink_bristle_length_weight =
            normalize_weight(self.ink_bristle_length_weight, 0.5);
        self.ink_bristle_ink_weight = normalize_weight(self.ink_bristle_ink_weight, 0.5);
        self.ink_depletion_weight = normalize_weight(self.ink_depletion_weight, 0.5);
        for value in self.ink_depletion_curve.iter_mut() {
            if !value.is_finite() {
                *value = 0.0;
            } else {
                *value = value.clamp(0.0, 1.0);
            }
        }
        if self.smoothing_mode > 3 {
            self.smoothing_mode = 1;
        }
        self.antialias_level = self.antialias_level.clamp(0, 9);
        self.color_argb = apply_flow_to_argb(self.color_argb, self.flow);
    }

    pub(crate) fn radius_from_pressure(&self, pressure: f32) -> f32 {
        brush_radius_from_pressure(pressure, self.base_radius, self.use_pressure)
    }

    pub(crate) fn softness(&self) -> f32 {
        (1.0 - self.hardness).clamp(0.0, 1.0)
    }

    pub(crate) fn supports_rotation(&self) -> bool {
        self.custom_mask_enabled || !matches!(self.shape, BrushShape::Circle)
    }

    fn smoothing_mode(&self) -> SmoothingMode {
        match self.smoothing_mode {
            1 => SmoothingMode::Simple,
            2 => SmoothingMode::Weighted,
            3 => SmoothingMode::Stabilizer,
            _ => SmoothingMode::None,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum SmoothingMode {
    None,
    Simple,
    Weighted,
    Stabilizer,
}

#[derive(Clone, Copy, Debug)]
struct StrokeSample {
    pos: Point2D,
    pressure: f32,
    timestamp_us: u64,
}

#[derive(Clone, Copy, Debug)]
struct Bristle {
    offset: Point2D,
    length: f32,
    ink: f32,
    counter: u32,
    prev: Option<Point2D>,
}

#[derive(Clone, Copy, Debug)]
struct BristleMaskSeed {
    offset: Point2D,
    length: f32,
}

struct BristleMask {
    width: u32,
    height: u32,
    seeds: Vec<BristleMaskSeed>,
}

struct BristleState {
    bristles: Vec<Bristle>,
    base_radius: f32,
    density: f32,
    random: f32,
    scale: f32,
    seed: u32,
}

pub(crate) struct StreamlinePayload {
    pub(crate) points: Vec<(Point2D, f32)>,
    pub(crate) strength: f32,
}

struct ConsumedStrokePoints {
    points_len: usize,
    down_count: usize,
    up_count: usize,
    emitted: Vec<(Point2D, f32)>,
}

const MAX_SMOOTH_HISTORY: usize = 256;
const SMOOTH_TAIL_AGGRESSIVENESS: f32 = 0.15;
const SMOOTH_PRESSURE: bool = false;
const STABILIZER_SMOOTH_PRESSURE: bool = true;
const STABILIZER_SAMPLE_TIME_US: u64 = 15_000;
const STABILIZER_DISTANCE_MAX: f32 = 50.0;
const STABILIZER_MAX_SAMPLES: usize = 64;
const SPEED_NORMALIZE_REF: f32 = 1.5;
const MAX_BRISTLES: usize = 512;
const MIN_BRISTLES: usize = 8;
const MAX_BRISTLE_SEEDS: usize = 8192;
const MAX_INK_SATURATION: f32 = 2.0;

fn normalize_weight(value: f32, fallback: f32) -> f32 {
    let mut v = if value.is_finite() { value } else { fallback };
    if v > 1.0 {
        v /= 100.0;
    }
    v.clamp(0.0, 1.0)
}

pub(crate) fn default_ink_curve() -> [f32; INK_CURVE_SAMPLES] {
    let mut curve = [0.0f32; INK_CURVE_SAMPLES];
    if INK_CURVE_SAMPLES <= 1 {
        return curve;
    }
    let denom = (INK_CURVE_SAMPLES - 1) as f32;
    for (idx, value) in curve.iter_mut().enumerate() {
        *value = (idx as f32 / denom).clamp(0.0, 1.0);
    }
    curve
}

pub(crate) fn resample_ink_curve(samples: &[f32]) -> [f32; INK_CURVE_SAMPLES] {
    if samples.is_empty() {
        return default_ink_curve();
    }
    let mut curve = [0.0f32; INK_CURVE_SAMPLES];
    if samples.len() == 1 {
        let value = if samples[0].is_finite() {
            samples[0].clamp(0.0, 1.0)
        } else {
            0.0
        };
        for v in curve.iter_mut() {
            *v = value;
        }
        return curve;
    }
    let last = samples.len() - 1;
    let denom = (INK_CURVE_SAMPLES - 1).max(1) as f32;
    for (idx, value) in curve.iter_mut().enumerate() {
        let t = idx as f32 / denom;
        let pos = t * last as f32;
        let left = pos.floor() as usize;
        let right = (left + 1).min(last);
        let frac = pos - left as f32;
        let a = if samples[left].is_finite() {
            samples[left].clamp(0.0, 1.0)
        } else {
            0.0
        };
        let b = if samples[right].is_finite() {
            samples[right].clamp(0.0, 1.0)
        } else {
            0.0
        };
        *value = (a + (b - a) * frac).clamp(0.0, 1.0);
    }
    curve
}

fn sample_ink_curve(curve: &[f32; INK_CURVE_SAMPLES], idx: u32) -> f32 {
    if INK_CURVE_SAMPLES == 0 {
        return 0.0;
    }
    let index = (idx as usize).min(INK_CURVE_SAMPLES - 1);
    let value = curve[index];
    if value.is_finite() {
        value.clamp(0.0, 1.0)
    } else {
        0.0
    }
}

struct StabilizedSampler {
    last_time_us: Option<u64>,
    real_events: Vec<StrokeSample>,
    last_event: Option<StrokeSample>,
    elapsed_override_samples: usize,
}

impl StabilizedSampler {
    fn new() -> Self {
        Self {
            last_time_us: None,
            real_events: Vec::new(),
            last_event: None,
            elapsed_override_samples: 0,
        }
    }

    fn clear(&mut self) {
        if let Some(last) = self.real_events.last().copied() {
            self.last_event = Some(last);
        }
        self.real_events.clear();
        self.elapsed_override_samples = 0;
        self.last_time_us = None;
    }

    fn add_event(&mut self, sample: StrokeSample) {
        if self.last_time_us.is_none() {
            self.last_time_us = Some(sample.timestamp_us);
        }
        self.real_events.push(sample);
    }

    fn add_finishing_event(&mut self, num_samples: usize) {
        if self.real_events.is_empty() {
            if let Some(last) = self.last_event {
                self.real_events.push(last);
            }
        }
        self.elapsed_override_samples = num_samples;
    }

    fn range(&mut self, current_time_us: u64) -> Vec<StrokeSample> {
        let Some(last_time) = self.last_time_us else {
            self.last_time_us = Some(current_time_us);
            return Vec::new();
        };

        let elapsed_us = current_time_us.saturating_sub(last_time);
        let mut elapsed_samples =
            (elapsed_us / STABILIZER_SAMPLE_TIME_US) as usize + self.elapsed_override_samples;

        if elapsed_samples == 0 {
            return Vec::new();
        }
        if elapsed_samples > STABILIZER_MAX_SAMPLES {
            elapsed_samples = STABILIZER_MAX_SAMPLES;
        }

        self.last_time_us = Some(current_time_us);
        self.elapsed_override_samples = 0;

        let last_event = if let Some(last) = self.real_events.last().copied() {
            self.last_event = Some(last);
            last
        } else if let Some(last) = self.last_event {
            last
        } else {
            return Vec::new();
        };

        let alpha = self.real_events.len() as f32 / elapsed_samples as f32;
        let mut output: Vec<StrokeSample> = Vec::with_capacity(elapsed_samples);
        for i in 0..elapsed_samples {
            let idx = (alpha * i as f32).floor() as usize;
            let sample = if idx < self.real_events.len() {
                self.real_events[idx]
            } else {
                last_event
            };
            output.push(sample);
        }
        self.real_events.clear();
        output
    }
}

struct KritaStabilizer {
    queue: std::collections::VecDeque<StrokeSample>,
    last_painted: Option<StrokeSample>,
    sampler: StabilizedSampler,
    strength: f32,
}

impl KritaStabilizer {
    fn new() -> Self {
        Self {
            queue: std::collections::VecDeque::new(),
            last_painted: None,
            sampler: StabilizedSampler::new(),
            strength: 0.0,
        }
    }

    fn reset(&mut self) {
        self.queue.clear();
        self.last_painted = None;
        self.sampler.clear();
    }

    fn begin(&mut self, first: StrokeSample, strength: f32) {
        self.queue.clear();
        let sample_size = stabilizer_sample_size(strength);
        for _ in 0..sample_size {
            self.queue.push_back(first);
        }
        self.last_painted = Some(first);
        self.sampler.clear();
        self.sampler.add_event(first);
        self.strength = strength;
    }

    fn process(
        &mut self,
        sample: StrokeSample,
        is_down: bool,
        is_up: bool,
    ) -> Vec<StrokeSample> {
        let strength = self.strength;
        if strength <= 0.0001 {
            if is_down {
                self.reset();
            }
            return vec![sample];
        }

        if is_down || self.queue.is_empty() {
            self.begin(sample, strength);
        } else {
            self.sampler.add_event(sample);
        }

        let mut output: Vec<StrokeSample> = Vec::new();
        let sampled = self.sampler.range(sample.timestamp_us);
        for sampled_info in sampled {
            let can_paint = if let Some(prev) = self.last_painted {
                let delay = stabilizer_delay_distance(strength);
                let dx = sampled_info.pos.x - prev.pos.x;
                let dy = sampled_info.pos.y - prev.pos.y;
                (dx * dx + dy * dy).sqrt() > delay
            } else {
                true
            };

            if can_paint {
                let stabilized = stabilizer_average(&self.queue, sampled_info);
                self.last_painted = Some(stabilized);
                output.push(stabilized);

                if self.queue.pop_front().is_some() {
                    self.queue.push_back(sampled_info);
                }
            } else if let Some(prev) = self.last_painted {
                for item in self.queue.iter_mut() {
                    item.pos = prev.pos;
                    item.pressure = prev.pressure;
                }
            }
        }

        if output.is_empty() && is_down {
            self.last_painted = Some(sample);
            output.push(sample);
        }

        if is_up {
            let finishing_samples = self.queue.len();
            if finishing_samples > 0 {
                self.sampler.add_finishing_event(finishing_samples);
                let finish = self.sampler.range(sample.timestamp_us);
                for sampled_info in finish {
                    let stabilized = stabilizer_average(&self.queue, sampled_info);
                    self.last_painted = Some(stabilized);
                    output.push(stabilized);
                    if self.queue.pop_front().is_some() {
                        self.queue.push_back(sampled_info);
                    }
                }
            }
        }

        output
    }
}

fn stabilizer_sample_size(strength: f32) -> usize {
    let s = if strength.is_finite() {
        strength.clamp(0.0, 1.0)
    } else {
        0.0
    };
    let value = 3.0 + s * 47.0;
    value.round().clamp(3.0, 64.0) as usize
}

fn stabilizer_delay_distance(strength: f32) -> f32 {
    let s = if strength.is_finite() {
        strength.clamp(0.0, 1.0)
    } else {
        0.0
    };
    (STABILIZER_DISTANCE_MAX * s).max(0.0)
}

fn stabilizer_average(
    queue: &std::collections::VecDeque<StrokeSample>,
    sampled: StrokeSample,
) -> StrokeSample {
    if queue.len() <= 1 {
        return sampled;
    }

    let mut result = sampled;
    let mut i = 2.0f32;
    for item in queue.iter().skip(1) {
        let k = (i - 1.0) / i;
        result.pos.x = result.pos.x * k + item.pos.x * (1.0 / i);
        result.pos.y = result.pos.y * k + item.pos.y * (1.0 / i);
        if STABILIZER_SMOOTH_PRESSURE {
            result.pressure = result.pressure * k + item.pressure * (1.0 / i);
        }
        i += 1.0;
    }
    result
}

pub(crate) struct StrokeResampler {
    last_emitted: Option<Point2D>,
    last_pressure: f32,
    last_tick_dirty: Option<(i32, i32, i32, i32)>,
    last_tick_point: Option<Point2D>,
    streamline_points: Vec<(Point2D, f32)>,
    streamline_active: bool,
    streamline_strength: f32,
    resample_scale: f32,
    smooth_history: Vec<StrokeSample>,
    smooth_distance_history: Vec<f32>,
    smooth_have_tangent: bool,
    smooth_prev_tangent: Point2D,
    smooth_older: Option<StrokeSample>,
    smooth_previous: Option<StrokeSample>,
    smooth_last_raw: Option<StrokeSample>,
    stabilizer: KritaStabilizer,
    bristle_mask: Option<BristleMask>,
    bristle_state: Option<BristleState>,
    soak_color: Option<u32>,
}

impl StrokeResampler {
    pub(crate) fn new() -> Self {
        Self {
            last_emitted: None,
            last_pressure: 1.0,
            last_tick_dirty: None,
            last_tick_point: None,
            streamline_points: Vec::new(),
            streamline_active: false,
            streamline_strength: 0.0,
            resample_scale: 1.0,
            smooth_history: Vec::new(),
            smooth_distance_history: Vec::new(),
            smooth_have_tangent: false,
            smooth_prev_tangent: Point2D { x: 0.0, y: 0.0 },
            smooth_older: None,
            smooth_previous: None,
            smooth_last_raw: None,
            stabilizer: KritaStabilizer::new(),
            bristle_mask: None,
            bristle_state: None,
            soak_color: None,
        }
    }

    pub(crate) fn last_tick_dirty(&self) -> Option<(i32, i32, i32, i32)> {
        self.last_tick_dirty
    }

    pub(crate) fn last_tick_point(&self) -> Option<Point2D> {
        self.last_tick_point
    }

    pub(crate) fn set_soak_color(&mut self, color_argb: u32) {
        self.soak_color = Some(color_argb);
    }

    pub(crate) fn clear_soak_color(&mut self) {
        self.soak_color = None;
    }

    pub(crate) fn set_bristle_mask(&mut self, width: u32, height: u32, mask: &[u8]) {
        self.bristle_mask = build_bristle_mask(width, height, mask);
        self.bristle_state = None;
    }

    pub(crate) fn clear_bristle_mask(&mut self) {
        self.bristle_mask = None;
        self.bristle_state = None;
    }

    pub(crate) fn soak_color(&self) -> Option<u32> {
        self.soak_color
    }

    pub(crate) fn needs_soak_color(&self) -> bool {
        self.soak_color.is_none()
    }

    pub(crate) fn set_resample_scale(&mut self, scale: f32) {
        let scale = if scale.is_finite() {
            scale.clamp(1.0, 8.0)
        } else {
            1.0
        };
        self.resample_scale = scale;
    }

    pub(crate) fn take_streamline_payload(&mut self) -> Option<StreamlinePayload> {
        if !self.streamline_active {
            self.streamline_points.clear();
            self.streamline_strength = 0.0;
            return None;
        }
        let points = std::mem::take(&mut self.streamline_points);
        let strength = self.streamline_strength;
        self.streamline_active = false;
        self.streamline_strength = 0.0;
        if points.len() < 2 || strength <= 0.0001 {
            return None;
        }
        Some(StreamlinePayload { points, strength })
    }

    fn begin_streamline(&mut self, strength: f32) {
        let strength = if strength.is_finite() {
            strength.clamp(0.0, 1.0)
        } else {
            0.0
        };
        self.streamline_strength = strength;
        self.streamline_active = strength > 0.0001;
        self.streamline_points.clear();
    }

    fn record_streamline_points(&mut self, emitted: &[(Point2D, f32)]) {
        if !self.streamline_active || emitted.is_empty() {
            return;
        }
        for (point, pressure) in emitted {
            if let Some((last_point, last_pressure)) = self.streamline_points.last() {
                let dx = point.x - last_point.x;
                let dy = point.y - last_point.y;
                let dist2 = dx * dx + dy * dy;
                if dist2 <= 1.0e-6 && (pressure - last_pressure).abs() <= 1.0e-4 {
                    continue;
                }
            }
            self.streamline_points.push((*point, *pressure));
        }
    }

    fn reset_for_new_stroke(&mut self) {
        self.last_emitted = None;
        self.last_pressure = 1.0;
        self.bristle_state = None;
        self.soak_color = None;
        self.smooth_history.clear();
        self.smooth_distance_history.clear();
        self.smooth_have_tangent = false;
        self.smooth_prev_tangent = Point2D { x: 0.0, y: 0.0 };
        self.smooth_older = None;
        self.smooth_previous = None;
        self.smooth_last_raw = None;
        self.stabilizer.reset();
    }

    fn emit_point(&mut self, point: Point2D, pressure: f32, emitted: &mut Vec<(Point2D, f32)>) {
        if let Some(last) = self.last_emitted {
            let dx = point.x - last.x;
            let dy = point.y - last.y;
            if dx * dx + dy * dy <= 1.0e-6 && (pressure - self.last_pressure).abs() <= 1.0e-4
            {
                return;
            }
        }
        emitted.push((point, pressure));
        self.last_emitted = Some(point);
        self.last_pressure = pressure;
    }

    fn emit_line_segment(
        &mut self,
        start: StrokeSample,
        end: StrokeSample,
        include_end: bool,
        brush_settings: &EngineBrushSettings,
        emitted: &mut Vec<(Point2D, f32)>,
    ) {
        if let Some(last) = self.last_emitted {
            if point_distance(last, start.pos) > 1.0e-3 {
                self.emit_point(start.pos, start.pressure, emitted);
            }
        } else {
            self.emit_point(start.pos, start.pressure, emitted);
        }

        let prev = start.pos;
        let dx = end.pos.x - prev.x;
        let dy = end.pos.y - prev.y;
        let dist = (dx * dx + dy * dy).sqrt();
        if !dist.is_finite() || dist <= 0.0001 {
            if include_end {
                self.emit_point(end.pos, end.pressure, emitted);
            }
            return;
        }

        let radius_prev = brush_settings.radius_from_pressure(start.pressure);
        let radius_next = brush_settings.radius_from_pressure(end.pressure);
        let mut step = resample_step_from_radius(
            (radius_prev + radius_next) * 0.5,
            brush_settings.spacing,
            self.resample_scale,
        );
        step = cap_resample_step_for_segment(dist, step);

        let dir_x = dx / dist;
        let dir_y = dy / dist;
        let mut traveled = 0.0f32;

        while traveled + step <= dist {
            traveled += step;
            let t = (traveled / dist).clamp(0.0, 1.0);
            let interp_pressure = start.pressure + (end.pressure - start.pressure) * t;
            let sample = Point2D {
                x: prev.x + dir_x * traveled,
                y: prev.y + dir_y * traveled,
            };
            self.emit_point(sample, interp_pressure, emitted);
        }

        if include_end {
            self.emit_point(end.pos, end.pressure, emitted);
        }
    }

    fn emit_bezier_segment(
        &mut self,
        p0: StrokeSample,
        p1: StrokeSample,
        tangent1: Point2D,
        tangent2: Point2D,
        brush_settings: &EngineBrushSettings,
        emitted: &mut Vec<(Point2D, f32)>,
    ) {
        let (c1, c2) = bezier_controls_from_tangents(p0.pos, p1.pos, tangent1, tangent2);
        if let Some(last) = self.last_emitted {
            if point_distance(last, p0.pos) > 1.0e-3 {
                self.emit_point(p0.pos, p0.pressure, emitted);
            }
        } else {
            self.emit_point(p0.pos, p0.pressure, emitted);
        }

        let radius = brush_settings
            .radius_from_pressure((p0.pressure + p1.pressure) * 0.5)
            .max(0.01);
        let mut step =
            resample_step_from_radius(radius, brush_settings.spacing, self.resample_scale);
        let length = cubic_length_approx(p0.pos, c1, c2, p1.pos);
        step = cap_resample_step_for_segment(length, step);
        if !length.is_finite() || length <= 0.0001 {
            self.emit_point(p1.pos, p1.pressure, emitted);
            return;
        }

        let segments = ((length / step).ceil() as usize).clamp(1, MAX_SEGMENT_SAMPLES);
        for i in 1..=segments {
            let t = (i as f32) / (segments as f32);
            let pos = cubic_point(p0.pos, c1, c2, p1.pos, t);
            let pres = p0.pressure + (p1.pressure - p0.pressure) * t;
            self.emit_point(pos, pres, emitted);
        }
    }

    fn smooth_weighted(
        &mut self,
        sample: StrokeSample,
        strength: f32,
    ) -> StrokeSample {
        let mut current = sample;
        let prev_pos = if let Some(last) = self.smooth_history.last() {
            last.pos
        } else if let Some(prev) = self.smooth_previous {
            prev.pos
        } else {
            sample.pos
        };
        let current_distance = point_distance(current.pos, prev_pos);
        self.smooth_distance_history.push(current_distance);
        self.smooth_history.push(current);

        if self.smooth_history.len() > MAX_SMOOTH_HISTORY {
            self.smooth_history.remove(0);
            if !self.smooth_distance_history.is_empty() {
                self.smooth_distance_history.remove(0);
            }
        }

        if self.smooth_history.len() > 3 && strength > 0.0001 {
            let speed = if let Some(last_raw) = self.smooth_last_raw {
                let dt_ms =
                    (sample.timestamp_us.saturating_sub(last_raw.timestamp_us) as f32) / 1000.0;
                if dt_ms > 0.0 {
                    let dist = point_distance(sample.pos, last_raw.pos);
                    dist / dt_ms
                } else {
                    0.0
                }
            } else {
                0.0
            };
            let speed01 = (speed / (speed + SPEED_NORMALIZE_REF)).clamp(0.0, 1.0);
            let max_dist = STABILIZER_DISTANCE_MAX * strength;
            let min_dist = max_dist * 0.6;
            let smooth_dist = (1.0 - speed01) * max_dist + speed01 * min_dist;
            let sigma = smooth_dist / 3.0;
            if sigma > 0.0001 {
                let gaussian_weight = 1.0 / ((2.0 * std::f32::consts::PI).sqrt() * sigma);
                let gaussian_weight2 = sigma * sigma;
                let mut distance_sum = 0.0f32;
                let mut scale_sum = 0.0f32;
                let mut x = 0.0f32;
                let mut y = 0.0f32;
                let mut pressure_sum = 0.0f32;
                let mut base_rate = 0.0f32;

                for i in (0..self.smooth_history.len()).rev() {
                    let mut rate = 0.0f32;
                    let next_info = self.smooth_history[i];
                    let mut distance = *self
                        .smooth_distance_history
                        .get(i)
                        .unwrap_or(&0.0);

                    if i + 1 < self.smooth_history.len() {
                        let pressure_grad =
                            next_info.pressure - self.smooth_history[i + 1].pressure;
                        if pressure_grad > 0.0 {
                            let tail = 40.0 * SMOOTH_TAIL_AGGRESSIVENESS;
                            distance +=
                                pressure_grad * tail * (1.0 - next_info.pressure) * 3.0 * sigma;
                        }
                    }

                    if gaussian_weight2 > 0.0 {
                        distance_sum += distance;
                        rate = gaussian_weight
                            * (-distance_sum * distance_sum / (2.0 * gaussian_weight2)).exp();
                    }

                    if self.smooth_history.len() - i == 1 {
                        base_rate = rate;
                    } else if base_rate > 0.0 && base_rate / rate > 100.0 {
                        break;
                    }

                    scale_sum += rate;
                    x += rate * next_info.pos.x;
                    y += rate * next_info.pos.y;
                    if SMOOTH_PRESSURE {
                        pressure_sum += rate * next_info.pressure;
                    }
                }

                if scale_sum > 0.0 {
                    x /= scale_sum;
                    y /= scale_sum;
                    current.pos = Point2D { x, y };
                    if SMOOTH_PRESSURE {
                        current.pressure = pressure_sum / scale_sum;
                    }
                    if let Some(last) = self.smooth_history.last_mut() {
                        last.pos = current.pos;
                        if SMOOTH_PRESSURE {
                            last.pressure = current.pressure;
                        }
                    }
                }
            }
        }

        self.smooth_last_raw = Some(sample);
        current
    }

    fn process_smoothing_sample(
        &mut self,
        sample: StrokeSample,
        mode: SmoothingMode,
        brush_settings: &EngineBrushSettings,
        emitted: &mut Vec<(Point2D, f32)>,
    ) {
        let mut current = sample;
        if mode == SmoothingMode::Weighted {
            current = self.smooth_weighted(sample, brush_settings.stabilizer_strength);
        }

        if self.smooth_previous.is_none() {
            self.emit_point(current.pos, current.pressure, emitted);
            self.smooth_previous = Some(current);
            return;
        }

        let prev = self.smooth_previous.unwrap();

        if !self.smooth_have_tangent {
            self.smooth_prev_tangent = tangent_between(prev, current);
            self.smooth_have_tangent = true;
            self.smooth_older = Some(prev);
            self.smooth_previous = Some(current);
            return;
        }

        let Some(older) = self.smooth_older else {
            self.smooth_previous = Some(current);
            return;
        };

        let new_tangent = tangent_between(older, current);
        if tangent_is_zero(new_tangent) || tangent_is_zero(self.smooth_prev_tangent) {
            self.emit_line_segment(prev, current, true, brush_settings, emitted);
        } else {
            self.emit_bezier_segment(
                older,
                prev,
                self.smooth_prev_tangent,
                new_tangent,
                brush_settings,
                emitted,
            );
        }

        self.smooth_prev_tangent = new_tangent;
        self.smooth_older = Some(prev);
        self.smooth_previous = Some(current);
    }

    fn finish_smoothing(
        &mut self,
        brush_settings: &EngineBrushSettings,
        emitted: &mut Vec<(Point2D, f32)>,
    ) {
        if !self.smooth_have_tangent {
            return;
        }
        let Some(prev) = self.smooth_previous else {
            return;
        };
        let Some(older) = self.smooth_older else {
            return;
        };
        let new_tangent = tangent_between(older, prev);
        if tangent_is_zero(new_tangent) || tangent_is_zero(self.smooth_prev_tangent) {
            self.emit_line_segment(older, prev, true, brush_settings, emitted);
        } else {
            self.emit_bezier_segment(
                older,
                prev,
                self.smooth_prev_tangent,
                new_tangent,
                brush_settings,
                emitted,
            );
        }
        self.smooth_have_tangent = false;
    }

    fn consume_points_internal(
        &mut self,
        brush_settings: &EngineBrushSettings,
        points: Vec<EnginePoint>,
    ) -> Option<ConsumedStrokePoints> {
        const FLAG_DOWN: u32 = 1;
        const FLAG_UP: u32 = 4;

        if points.is_empty() {
            if debug::level() >= LogLevel::Info && brush_settings.streamline_strength > 0.0001 {
                debug::log(
                    LogLevel::Info,
                    format_args!("stroke consume skipped: points=0"),
                );
            }
            self.last_tick_dirty = None;
            self.last_tick_point = None;
            return None;
        }

        let points_len = points.len();
        let mut emitted: Vec<(Point2D, f32)> = Vec::new();
        let mut down_count: usize = 0;
        let mut up_count: usize = 0;

        let mode = brush_settings.smoothing_mode();
        self.stabilizer.strength = brush_settings.stabilizer_strength;

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
            if is_down {
                down_count += 1;
                self.reset_for_new_stroke();
                self.begin_streamline(brush_settings.streamline_strength);
            }
            if is_up {
                up_count += 1;
            }

            let sample = StrokeSample {
                pos: Point2D { x, y },
                pressure,
                timestamp_us: p.timestamp_us,
            };

            match mode {
                SmoothingMode::Stabilizer => {
                    let stabilized = self.stabilizer.process(sample, is_down, is_up);
                    for stab in stabilized {
                        // Feed stabilizer samples into the same weighted + bezier smoothing
                        // pipeline so corners stay rounded.
                        self.process_smoothing_sample(
                            stab,
                            SmoothingMode::Weighted,
                            brush_settings,
                            &mut emitted,
                        );
                    }
                    if is_up {
                        self.finish_smoothing(brush_settings, &mut emitted);
                    }
                }
                SmoothingMode::Weighted | SmoothingMode::Simple => {
                    self.process_smoothing_sample(sample, mode, brush_settings, &mut emitted);
                    if is_up {
                        self.finish_smoothing(brush_settings, &mut emitted);
                    }
                }
                SmoothingMode::None => {
                    if is_down || self.last_emitted.is_none() {
                        self.emit_point(sample.pos, sample.pressure, &mut emitted);
                        continue;
                    }
                    let start = StrokeSample {
                        pos: self.last_emitted.unwrap(),
                        pressure: self.last_pressure,
                        timestamp_us: sample.timestamp_us,
                    };
                    self.emit_line_segment(start, sample, is_up, brush_settings, &mut emitted);
                }
            }
        }

        let emitted = if emitted.len() > MAX_EMITTED_POINTS {
            let original_len = emitted.len();
            let reduced = downsample_emitted(&emitted, MAX_EMITTED_POINTS);
            if debug::level() >= LogLevel::Info {
                debug::log(
                    LogLevel::Info,
                    format_args!(
                        "stroke resample cap emitted={} -> {}",
                        original_len, MAX_EMITTED_POINTS
                    ),
                );
            }
            reduced
        } else {
            emitted
        };

        self.record_streamline_points(&emitted);

        if emitted.is_empty() {
            if debug::level() >= LogLevel::Info && brush_settings.streamline_strength > 0.0001 {
                debug::log(
                    LogLevel::Info,
                    format_args!(
                        "stroke consume skipped: points={points_len} down={down_count} up={up_count} emitted=0"
                    ),
                );
            }
            self.last_tick_dirty = None;
            self.last_tick_point = None;
            return None;
        }

        self.last_tick_point = emitted.last().map(|(point, _)| *point);
        self.last_tick_dirty = None;
        Some(ConsumedStrokePoints {
            points_len,
            down_count,
            up_count,
            emitted,
        })
    }

    pub(crate) fn consume_points(
        &mut self,
        brush_settings: &EngineBrushSettings,
        points: Vec<EnginePoint>,
    ) -> Vec<(Point2D, f32)> {
        self.consume_points_internal(brush_settings, points)
            .map(|out| out.emitted)
            .unwrap_or_default()
    }

    pub(crate) fn consume_and_draw<F: FnMut(&mut BrushRenderer, (i32, i32, i32, i32))>(
        &mut self,
        brush: &mut BrushRenderer,
        brush_settings: &EngineBrushSettings,
        layer_view: &wgpu::TextureView,
        points: Vec<EnginePoint>,
        canvas_width: u32,
        canvas_height: u32,
        before_draw: &mut F,
    ) -> bool {
        let Some(consumed) = self.consume_points_internal(brush_settings, points) else {
            return false;
        };
        let ConsumedStrokePoints {
            points_len,
            down_count,
            up_count,
            emitted,
        } = consumed;

        let drawn = self.draw_emitted_points(
            brush,
            brush_settings,
            layer_view,
            &emitted,
            canvas_width,
            canvas_height,
            before_draw,
        );
        if debug::level() >= LogLevel::Info && brush_settings.streamline_strength > 0.0001 {
            debug::log(
                LogLevel::Info,
                format_args!(
                    "stroke consume drawn={drawn} points={points_len} down={down_count} up={up_count} emitted={}",
                    emitted.len()
                ),
            );
        }
        if !drawn && brush_settings.streamline_strength > 0.0001 {
            debug::log(
                LogLevel::Warn,
                format_args!(
                    "stroke consume no-draw points={points_len} down={down_count} up={up_count} emitted={}",
                    emitted.len()
                ),
            );
        }
        drawn
    }

    fn ensure_bristle_state(
        &mut self,
        brush_settings: &EngineBrushSettings,
        emitted: &[(Point2D, f32)],
    ) -> Option<&mut BristleState> {
        if !brush_settings.bristle_enabled || emitted.is_empty() {
            self.bristle_state = None;
            return None;
        }
        let base_radius = brush_settings.base_radius.max(0.01);
        let density = brush_settings.bristle_density.clamp(0.0, 1.0);
        let random = brush_settings.bristle_random.clamp(0.0, 10.0);
        let scale = brush_settings.bristle_scale.clamp(0.1, 10.0);
        let seed = brush_settings.rotation_seed ^ 0x7f4a_7c15;
        let mask = if brush_settings.custom_mask_enabled {
            self.bristle_mask.as_ref()
        } else {
            None
        };
        let needs_rebuild = match &self.bristle_state {
            None => true,
            Some(state) => {
                (state.base_radius - base_radius).abs() > 0.01
                    || (state.density - density).abs() > 0.001
                    || (state.random - random).abs() > 0.001
                    || (state.scale - scale).abs() > 0.001
                    || state.seed != seed
            }
        };
        if needs_rebuild {
            let origin = emitted[0].0;
            self.bristle_state = Some(build_bristle_state(origin, brush_settings, seed, mask));
        }
        self.bristle_state.as_mut()
    }

    fn draw_bristle_points<F: FnMut(&mut BrushRenderer, (i32, i32, i32, i32))>(
        &mut self,
        brush: &mut BrushRenderer,
        brush_settings: &EngineBrushSettings,
        layer_view: &wgpu::TextureView,
        emitted: &[(Point2D, f32)],
        canvas_width: u32,
        canvas_height: u32,
        before_draw: &mut F,
    ) -> (bool, Option<(i32, i32, i32, i32)>) {
        if emitted.is_empty() {
            return (false, None);
        }
        let Some(state) = self.ensure_bristle_state(brush_settings, emitted) else {
            return (false, None);
        };

        brush.set_canvas_size(canvas_width, canvas_height);
        let softness = brush_settings.softness();
        brush.set_softness(softness);
        brush.set_screentone(
            brush_settings.screentone_enabled,
            brush_settings.screentone_spacing,
            brush_settings.screentone_dot_size,
            brush_settings.screentone_rotation.to_radians(),
            brush_settings.screentone_softness,
            brush_settings.screentone_shape,
        );

        let bristle_count = state.bristles.len().max(1);
        let max_samples = (MAX_POINTS / bristle_count).max(1);
        let mut downsampled: Vec<(Point2D, f32)> = Vec::new();
        let samples: &[(Point2D, f32)] = if emitted.len() > max_samples {
            downsampled = downsample_emitted(emitted, max_samples);
            &downsampled
        } else {
            emitted
        };

        let max_per_sample = (MAX_POINTS / samples.len().max(1)).max(1);
        let mut step = (bristle_count + max_per_sample - 1) / max_per_sample;
        if step == 0 {
            step = 1;
        }

        let base_radius = brush_settings.base_radius.max(0.01);
        let ink_amount = brush_settings.ink_amount.clamp(0.0, 1.0);
        let ink_strength = brush_settings.ink_depletion.clamp(0.0, 1.0);
        let ink_enabled = brush_settings.ink_depletion_enabled;
        let use_opacity = brush_settings.ink_use_opacity;
        let use_saturation = brush_settings.ink_use_saturation && ink_enabled;
        let use_weights = brush_settings.ink_use_weights && ink_enabled;
        let weight_pressure = brush_settings.ink_pressure_weight;
        let weight_length = brush_settings.ink_bristle_length_weight;
        let weight_ink = brush_settings.ink_bristle_ink_weight;
        let weight_depletion = brush_settings.ink_depletion_weight;
        let step_len = (base_radius * 0.15).max(0.5);
        let active_bristles = (state.bristles.len() + step - 1) / step;
        let max_steps_per_bristle = (MAX_POINTS / samples.len().max(1) / active_bristles.max(1))
            .max(1);

        let mut points: Vec<Point2D> = Vec::new();
        let mut radii: Vec<f32> = Vec::new();
        let mut alphas: Vec<f32> = Vec::new();
        let mut sats: Vec<f32> = Vec::new();

        'outer: for (sample_idx, (point, pressure)) in samples.iter().enumerate() {
            let angle = if sample_idx + 1 < samples.len() {
                let next = samples[sample_idx + 1].0;
                (next.y - point.y).atan2(next.x - point.x)
            } else if sample_idx > 0 {
                let prev = samples[sample_idx - 1].0;
                (point.y - prev.y).atan2(point.x - prev.x)
            } else {
                0.0
            };
            let (sin, cos) = angle.sin_cos();
            let mut pressure_value = if brush_settings.bristle_use_pressure {
                *pressure
            } else {
                1.0
            };
            if !pressure_value.is_finite() {
                pressure_value = 1.0;
            }
            pressure_value = pressure_value.clamp(0.0, 1.0);
            let threshold = (1.0 - pressure_value).clamp(0.0, 1.0);
            for idx in (0..state.bristles.len()).step_by(step) {
                let bristle = &mut state.bristles[idx];
                if brush_settings.bristle_threshold && bristle.length < threshold {
                    bristle.prev = None;
                    continue;
                }
                let mut ox = bristle.offset.x * brush_settings.bristle_scale;
                let mut oy = bristle.offset.y * brush_settings.bristle_scale;
                let rot_x = ox * cos - oy * sin;
                let rot_y = ox * sin + oy * cos;
                let shear = brush_settings.bristle_shear * pressure_value;
                ox = rot_x + rot_y * shear;
                oy = rot_y + rot_x * shear;
                let jitter = if brush_settings.bristle_random > 0.0001 {
                    brush_scatter_offset(
                        *point,
                        state.seed,
                        base_radius * brush_settings.bristle_random,
                        (sample_idx as u32).wrapping_add(idx as u32 * 17),
                    )
                } else {
                    Point2D { x: 0.0, y: 0.0 }
                };
                let pos = Point2D {
                    x: point.x + ox + jitter.x,
                    y: point.y + oy + jitter.y,
                };
                let start = if brush_settings.bristle_connected {
                    bristle.prev.unwrap_or(pos)
                } else {
                    pos
                };
                let dist = point_distance(start, pos).max(0.0);
                let mut steps = if brush_settings.bristle_connected {
                    ((dist / step_len).ceil() as usize).max(1)
                } else {
                    1
                };
                if steps > max_steps_per_bristle {
                    steps = max_steps_per_bristle;
                }
                for step_idx in 0..steps {
                    if points.len() >= MAX_POINTS {
                        break 'outer;
                    }
                    let t = if steps == 1 {
                        1.0
                    } else {
                        (step_idx + 1) as f32 / steps as f32
                    };
                    let pos_step = Point2D {
                        x: start.x + (pos.x - start.x) * t,
                        y: start.y + (pos.y - start.y) * t,
                    };
                    let mut ink_depletion = 0.0;
                    let mut ink_level = ink_amount;
                    if ink_enabled {
                        let curve_value =
                            sample_ink_curve(&brush_settings.ink_depletion_curve, bristle.counter);
                        ink_depletion = (curve_value * ink_strength).clamp(0.0, 1.0);
                        ink_level = (ink_amount * (1.0 - ink_depletion)).clamp(0.0, 1.0);
                    }
                    bristle.ink = ink_level;
                    let mut weighted = 0.0;
                    if use_weights {
                        weighted = pressure_value * weight_pressure
                            + bristle.length * weight_length
                            + ink_level * weight_ink
                            + (1.0 - ink_depletion) * weight_depletion;
                    }
                    let mut alpha = if use_opacity {
                        if ink_enabled {
                            if use_weights {
                                weighted
                            } else {
                                bristle.length * ink_level
                            }
                        } else {
                            bristle.length
                        }
                    } else {
                        1.0
                    };
                    if !alpha.is_finite() {
                        alpha = 0.0;
                    }
                    alpha = alpha.clamp(0.0, 1.0);
                    if alpha <= 0.0005 {
                        bristle.counter = bristle.counter.saturating_add(1);
                        continue;
                    }
                    let mut sat = 1.0;
                    if use_saturation {
                        if use_weights {
                            sat = weighted.clamp(0.0, MAX_INK_SATURATION);
                        } else {
                            sat =
                                (pressure_value * bristle.length * ink_level * (1.0 - ink_depletion))
                                    .clamp(0.0, MAX_INK_SATURATION);
                        }
                    }
                    let radius = (base_radius * 0.12 * (0.3 + 0.7 * bristle.length)).max(0.05);
                    points.push(pos_step);
                    radii.push(radius);
                    alphas.push(alpha);
                    sats.push(sat);
                    bristle.counter = bristle.counter.saturating_add(1);
                }
                bristle.prev = Some(pos);
                if !brush_settings.bristle_connected {
                    bristle.prev = None;
                }
            }
        }

        if points.is_empty() {
            return (false, None);
        }

        let dirty_scale = if softness > 0.0001 { 1.0 + softness } else { 1.0 };
        let dirty_radii: Vec<f32> = radii.iter().map(|r| r * dirty_scale).collect();
        let dirty = compute_dirty_rect_i32(&points, &dirty_radii, canvas_width, canvas_height);
        before_draw(brush, dirty);

        let color_argb = if brush_settings.ink_use_soak {
            self.soak_color.unwrap_or(brush_settings.color_argb)
        } else {
            brush_settings.color_argb
        };
        let color = Color { argb: color_argb };
        let mut start = 0usize;
        let mut any_drawn = false;
        while start < points.len() {
            let end = (start + MAX_POINTS).min(points.len());
            let pts = &points[start..end];
            let rs = &radii[start..end];
            let alpha_slice = &alphas[start..end];
            let sat_slice = &sats[start..end];
            match brush.draw_points(
                layer_view,
                pts,
                rs,
                Some(alpha_slice),
                Some(sat_slice),
                None,
                color,
                brush_settings.shape,
                brush_settings.erase,
                if brush_settings.bristle_antialias {
                    brush_settings.antialias_level
                } else {
                    0
                },
                softness,
                brush_settings.hollow_enabled,
                brush_settings.hollow_ratio,
                brush_settings.hollow_erase_occluded,
                brush_settings.hollow_enabled,
                true,
                if brush_settings.bristle_use_compositing || brush_settings.bristle_antialias {
                    0
                } else {
                    1
                },
            ) {
                Ok(()) => {
                    any_drawn = true;
                }
                Err(err) => {
                    debug::log(
                        LogLevel::Warn,
                        format_args!("Bristle draw_points failed: {err}"),
                    );
                }
            }
            start = end;
        }
        if any_drawn {
            return (true, Some(dirty));
        }
        (false, None)
    }

    pub(crate) fn draw_emitted_points<F: FnMut(&mut BrushRenderer, (i32, i32, i32, i32))>(
        &mut self,
        brush: &mut BrushRenderer,
        brush_settings: &EngineBrushSettings,
        layer_view: &wgpu::TextureView,
        emitted: &[(Point2D, f32)],
        canvas_width: u32,
        canvas_height: u32,
        before_draw: &mut F,
    ) -> bool {
        self.last_tick_point = emitted.last().map(|(point, _)| *point);
        let (drew_any, dirty_union) = if brush_settings.bristle_enabled {
            self.draw_bristle_points(
                brush,
                brush_settings,
                layer_view,
                emitted,
                canvas_width,
                canvas_height,
                before_draw,
            )
        } else {
            draw_emitted_points_internal(
                brush,
                brush_settings,
                layer_view,
                emitted,
                canvas_width,
                canvas_height,
                before_draw,
            )
        };
        self.last_tick_dirty = dirty_union;
        if !drew_any {
            self.last_tick_point = None;
        }
        drew_any
    }
}

fn draw_emitted_points_internal<F: FnMut(&mut BrushRenderer, (i32, i32, i32, i32))>(
    brush: &mut BrushRenderer,
    brush_settings: &EngineBrushSettings,
    layer_view: &wgpu::TextureView,
    emitted: &[(Point2D, f32)],
    canvas_width: u32,
    canvas_height: u32,
    before_draw: &mut F,
) -> (bool, Option<(i32, i32, i32, i32)>) {
    if emitted.is_empty() {
        return (false, None);
    }

    brush.set_canvas_size(canvas_width, canvas_height);
    let softness = brush_settings.softness();
    brush.set_softness(softness);
    brush.set_screentone(
        brush_settings.screentone_enabled,
        brush_settings.screentone_spacing,
        brush_settings.screentone_dot_size,
        brush_settings.screentone_rotation.to_radians(),
        brush_settings.screentone_softness,
        brush_settings.screentone_shape,
    );

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
    let dirty_scale = if softness > 0.0001 { 1.0 + softness } else { 1.0 };
    let (points, radii) = prepare_brush_samples(brush_settings, emitted);
    if points.is_empty() || points.len() != radii.len() {
        return (false, None);
    }

    let use_point_mode = true;
    if use_point_mode {
        let dirty_radii: Vec<f32> = radii.iter().map(|r| r * dirty_scale).collect();
        let dirty = compute_dirty_rect_i32(&points, &dirty_radii, canvas_width, canvas_height);
        before_draw(brush, dirty);

        let supports_rotation = brush_settings.supports_rotation();
        let use_smooth = brush_settings.smooth_rotation && supports_rotation;
        let use_random =
            brush_settings.random_rotation && brush_settings.rotation_jitter > 0.0001 && supports_rotation;
        let rotations = if use_smooth || use_random {
            let jitter = if brush_settings.rotation_jitter.is_finite() {
                brush_settings.rotation_jitter.clamp(0.0, 1.0)
            } else {
                1.0
            };
            let mut rotations: Vec<PointRotation> = Vec::with_capacity(points.len());
            for (idx, point) in points.iter().enumerate() {
                let mut angle = if use_smooth {
                    stroke_direction_angle(&points, idx)
                } else {
                    0.0
                };
                if use_random {
                    angle += brush_random_rotation_radians(*point, brush_settings.rotation_seed) * jitter;
                }
                rotations.push(PointRotation {
                    sin: angle.sin(),
                    cos: angle.cos(),
                });
            }
            Some(rotations)
        } else {
            None
        };

        let color = Color {
            argb: brush_settings.color_argb,
        };
        let mut start = 0usize;
        let mut any_drawn = false;
        while start < points.len() {
            let end = (start + MAX_POINTS).min(points.len());
            let pts = &points[start..end];
            let rs = &radii[start..end];
            let rot_slice = rotations.as_ref().map(|rots| &rots[start..end]);
            match brush.draw_points(
                layer_view,
                pts,
                rs,
                None,
                None,
                rot_slice,
                color,
                brush_settings.shape,
                brush_settings.erase,
                brush_settings.antialias_level,
                softness,
                hollow_enabled,
                hollow_ratio,
                hollow_erase,
                hollow_enabled,
                true,
                0,
            ) {
                Ok(()) => {
                    any_drawn = true;
                }
                Err(err) => {
                    debug::log(
                        LogLevel::Warn,
                        format_args!("Brush draw_points failed: {err}"),
                    );
                }
            }
            start = end;
        }
        if any_drawn {
            drew_any = true;
            dirty_union = union_dirty_rect_i32(dirty_union, dirty);
        }
        return (drew_any, dirty_union);
    }

    if points.len() == 1 {
        let p0 = points[0];
        let r0 = radii[0];
        let dirty_r0 = r0 * dirty_scale;
        let dirty = compute_dirty_rect_i32(&[p0], &[dirty_r0], canvas_width, canvas_height);
        before_draw(brush, dirty);
        let rotation = if brush_settings.random_rotation
            && brush_settings.rotation_jitter > 0.0001
            && brush_settings.supports_rotation()
        {
            brush_random_rotation_radians(p0, brush_settings.rotation_seed)
                * brush_settings.rotation_jitter
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
            false,
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
        let dirty_radii: Vec<f32> = radii.iter().map(|r| r * dirty_scale).collect();
        let dirty = compute_dirty_rect_i32(&points, &dirty_radii, canvas_width, canvas_height);
        before_draw(brush, dirty);
        let rotation = if brush_settings.random_rotation
            && brush_settings.rotation_jitter > 0.0001
            && brush_settings.supports_rotation()
        {
            brush_random_rotation_radians(points[0], brush_settings.rotation_seed)
                * brush_settings.rotation_jitter
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
            false,
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
        let needs_per_segment_rotation =
            brush_settings.random_rotation
                && brush_settings.rotation_jitter > 0.0001
                && brush_settings.supports_rotation();
        let color = Color {
            argb: brush_settings.color_argb,
        };
        if needs_per_segment_rotation {
            for i in 0..points.len().saturating_sub(1) {
                let p0 = points[i];
                let p1 = points[i + 1];
                let r0 = radii[i];
                let r1 = radii[i + 1];
                let pts = [p0, p1];
                let radii = [r0, r1];
                let dirty_radii = [r0 * dirty_scale, r1 * dirty_scale];
                let dirty = compute_dirty_rect_i32(&pts, &dirty_radii, canvas_width, canvas_height);
                before_draw(brush, dirty);
                let rotation =
                    brush_random_rotation_radians(p0, brush_settings.rotation_seed)
                        * brush_settings.rotation_jitter;
                match brush.draw_stroke(
                    layer_view,
                    &pts,
                    &radii,
                    color,
                    brush_settings.shape,
                    brush_settings.erase,
                    brush_settings.antialias_level,
                    rotation,
                    hollow_enabled,
                    hollow_ratio,
                    hollow_erase,
                    hollow_enabled,
                    false,
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
        } else {
            const MAX_BATCH_POINTS: usize = 128;
            let mut batch_points: Vec<Point2D> = Vec::with_capacity(MAX_BATCH_POINTS + 1);
            let mut batch_radii: Vec<f32> = Vec::with_capacity(MAX_BATCH_POINTS + 1);
            let mut batch_dirty_union: Option<(i32, i32, i32, i32)> = None;

            for i in 0..points.len().saturating_sub(1) {
                let p0 = points[i];
                let p1 = points[i + 1];
                let r0 = radii[i];
                let r1 = radii[i + 1];
                let pts = [p0, p1];
                let dirty_radii = [r0 * dirty_scale, r1 * dirty_scale];
                let dirty = compute_dirty_rect_i32(&pts, &dirty_radii, canvas_width, canvas_height);
                before_draw(brush, dirty);
                batch_dirty_union = union_dirty_rect_i32(batch_dirty_union, dirty);

                if batch_points.is_empty() {
                    batch_points.push(p0);
                    batch_radii.push(r0);
                }
                batch_points.push(p1);
                batch_radii.push(r1);

                if batch_points.len() >= MAX_BATCH_POINTS {
                    match brush.draw_stroke(
                        layer_view,
                        &batch_points,
                        &batch_radii,
                        color,
                        brush_settings.shape,
                        brush_settings.erase,
                        brush_settings.antialias_level,
                        0.0,
                        hollow_enabled,
                        hollow_ratio,
                        hollow_erase,
                        hollow_enabled,
                        false,
                    ) {
                        Ok(()) => {
                            drew_any = true;
                            if let Some(batch_dirty) = batch_dirty_union {
                                dirty_union = union_dirty_rect_i32(dirty_union, batch_dirty);
                            }
                        }
                        Err(err) => {
                            debug::log(
                                LogLevel::Warn,
                                format_args!("Brush draw_stroke failed: {err}"),
                            );
                        }
                    }
                    let last_point = *batch_points.last().expect("batch points not empty");
                    let last_radius = *batch_radii.last().expect("batch radii not empty");
                    batch_points.clear();
                    batch_radii.clear();
                    batch_points.push(last_point);
                    batch_radii.push(last_radius);
                    batch_dirty_union = None;
                }
            }

            if batch_points.len() > 1 {
                match brush.draw_stroke(
                    layer_view,
                    &batch_points,
                    &batch_radii,
                    color,
                    brush_settings.shape,
                    brush_settings.erase,
                    brush_settings.antialias_level,
                    0.0,
                    hollow_enabled,
                    hollow_ratio,
                    hollow_erase,
                    hollow_enabled,
                    false,
                ) {
                    Ok(()) => {
                        drew_any = true;
                        if let Some(batch_dirty) = batch_dirty_union {
                            dirty_union = union_dirty_rect_i32(dirty_union, batch_dirty);
                        }
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
    }

    (drew_any, dirty_union)
}

fn build_bristle_state(
    origin: Point2D,
    brush_settings: &EngineBrushSettings,
    seed: u32,
    mask: Option<&BristleMask>,
) -> BristleState {
    let base_radius = brush_settings.base_radius.max(0.01);
    let density = brush_settings.bristle_density.clamp(0.0, 1.0);
    let random = brush_settings.bristle_random.clamp(0.0, 10.0);
    let scale = brush_settings.bristle_scale.clamp(0.1, 10.0);
    if let Some(mask) = mask {
        if let Some(bristles) = build_bristles_from_mask(mask, brush_settings, seed, base_radius) {
            return BristleState {
                bristles,
                base_radius,
                density,
                random,
                scale,
                seed,
            };
        }
    }
    let area = std::f32::consts::PI * base_radius * base_radius;
    let mut count = (area * density * 0.35).round() as usize;
    if count < MIN_BRISTLES {
        count = MIN_BRISTLES;
    }
    if count > MAX_BRISTLES {
        count = MAX_BRISTLES;
    }
    let mut bristles: Vec<Bristle> = Vec::with_capacity(count);
    for i in 0..count {
        let offset = brush_scatter_offset(origin, seed, base_radius, i as u32);
        let length = brush_random_unit(origin, seed, (i as u32).wrapping_add(0x9e37_79b9))
            .clamp(0.0, 1.0);
        bristles.push(Bristle {
            offset,
            length,
            ink: brush_settings.ink_amount.clamp(0.0, 1.0),
            counter: 0,
            prev: None,
        });
    }
    BristleState {
        bristles,
        base_radius,
        density,
        random,
        scale,
        seed,
    }
}

fn build_bristle_mask(width: u32, height: u32, mask: &[u8]) -> Option<BristleMask> {
    if width == 0 || height == 0 {
        return None;
    }
    let expected = width as usize * height as usize * 2;
    if mask.len() < expected {
        return None;
    }
    let denom_x = if width > 1 { (width - 1) as f32 } else { 1.0 };
    let denom_y = if height > 1 { (height - 1) as f32 } else { 1.0 };
    let mut seeds: Vec<BristleMaskSeed> = Vec::new();
    for y in 0..height {
        let fy = if height > 1 {
            y as f32 / denom_y
        } else {
            0.5
        };
        let ny = (fy - 0.5) * 2.0;
        for x in 0..width {
            let idx = ((y * width + x) * 2) as usize;
            let alpha = mask[idx];
            if alpha == 0 {
                continue;
            }
            let fx = if width > 1 {
                x as f32 / denom_x
            } else {
                0.5
            };
            let nx = (fx - 0.5) * 2.0;
            let length = (alpha as f32 / 255.0).clamp(0.0, 1.0);
            seeds.push(BristleMaskSeed {
                offset: Point2D { x: nx, y: ny },
                length,
            });
        }
    }
    if seeds.is_empty() {
        return None;
    }
    if seeds.len() > MAX_BRISTLE_SEEDS {
        seeds = select_bristle_seeds(&seeds, MAX_BRISTLE_SEEDS, 0x19d7_5c2b);
    }
    Some(BristleMask {
        width,
        height,
        seeds,
    })
}

fn build_bristles_from_mask(
    mask: &BristleMask,
    brush_settings: &EngineBrushSettings,
    seed: u32,
    base_radius: f32,
) -> Option<Vec<Bristle>> {
    let count = mask.seeds.len();
    if count == 0 {
        return None;
    }
    let density = brush_settings.bristle_density.clamp(0.0, 1.0);
    let mut target = ((count as f32) * density).round() as usize;
    if target < MIN_BRISTLES {
        target = MIN_BRISTLES;
    }
    if target > MAX_BRISTLES {
        target = MAX_BRISTLES;
    }
    if target > count {
        target = count;
    }
    if target == 0 {
        return Some(Vec::new());
    }
    let selected = select_bristle_seeds(&mask.seeds, target, seed ^ 0x4a1d_3b25);
    let mut bristles: Vec<Bristle> = Vec::with_capacity(selected.len());
    let ink = brush_settings.ink_amount.clamp(0.0, 1.0);
    for seed in selected {
        bristles.push(Bristle {
            offset: Point2D {
                x: seed.offset.x * base_radius,
                y: seed.offset.y * base_radius,
            },
            length: seed.length,
            ink,
            counter: 0,
            prev: None,
        });
    }
    Some(bristles)
}

fn select_bristle_seeds(
    seeds: &[BristleMaskSeed],
    target: usize,
    seed: u32,
) -> Vec<BristleMaskSeed> {
    if target >= seeds.len() {
        return seeds.to_vec();
    }
    let mut rng = LcgRng::new(seed);
    let mut selected: Vec<BristleMaskSeed> = Vec::with_capacity(target);
    for (idx, seed_value) in seeds.iter().enumerate() {
        if idx < target {
            selected.push(*seed_value);
            continue;
        }
        let j = (rng.next_f32() * (idx as f32 + 1.0)) as usize;
        if j < target {
            selected[j] = *seed_value;
        }
    }
    selected
}

const RUST_PRESSURE_MIN_FACTOR: f32 = 0.09;
// Allow dense resampling on long straight segments (e.g., line/perspective tools)
// so small brushes don't turn into dashed strokes.
const MAX_SEGMENT_SAMPLES: usize = 4096;
const MAX_EMITTED_POINTS: usize = 4096;

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

fn apply_flow_to_argb(color_argb: u32, flow: f32) -> u32 {
    if !flow.is_finite() || flow >= 0.9999 {
        return color_argb;
    }
    let clamped = flow.clamp(0.0, 1.0);
    let alpha = ((color_argb >> 24) & 0xFF) as f32;
    let scaled = (alpha * clamped).round().clamp(0.0, 255.0) as u32;
    (color_argb & 0x00FF_FFFF) | (scaled << 24)
}

fn snap_point_to_pixel(point: Point2D) -> Point2D {
    Point2D {
        x: point.x.floor() + 0.5,
        y: point.y.floor() + 0.5,
    }
}

fn snap_radius_to_pixel(radius: f32) -> f32 {
    if !radius.is_finite() {
        return radius;
    }
    (radius * 2.0).round() * 0.5
}

pub(crate) fn prepare_brush_samples(
    brush_settings: &EngineBrushSettings,
    emitted: &[(Point2D, f32)],
) -> (Vec<Point2D>, Vec<f32>) {
    let mut points: Vec<Point2D> = Vec::with_capacity(emitted.len());
    let mut radii: Vec<f32> = Vec::with_capacity(emitted.len());
    let scatter = brush_settings.scatter;
    let snap = brush_settings.snap_to_pixel;
    let scatter_seed = if brush_settings.random_rotation {
        brush_settings.rotation_seed
    } else {
        0
    };
    for (idx, (p, pres)) in emitted.iter().enumerate() {
        let mut radius = brush_settings.radius_from_pressure(*pres);
        if !radius.is_finite() || radius <= 0.0 {
            radius = 0.01;
        }
        let mut point = *p;
        if scatter > 0.0001 {
            let scatter_radius = radius.abs().max(0.01) * 2.0 * scatter;
            if scatter_radius > 0.0001 {
                let jitter = brush_scatter_offset(
                    point,
                    scatter_seed,
                    scatter_radius,
                    idx as u32,
                );
                point.x += jitter.x;
                point.y += jitter.y;
            }
        }
        if snap {
            point = snap_point_to_pixel(point);
            radius = snap_radius_to_pixel(radius);
        }
        if !radius.is_finite() || radius <= 0.0 {
            radius = 0.01;
        }
        points.push(point);
        radii.push(radius);
    }
    (points, radii)
}

fn resample_step_from_radius(radius: f32, spacing: f32, scale: f32) -> f32 {
    let r = if radius.is_finite() {
        radius.max(0.0)
    } else {
        0.0
    };
    let spacing = if spacing.is_finite() {
        spacing.clamp(0.02, 2.5)
    } else {
        0.15
    };
    let base = (r * 2.0 * spacing).max(0.1);
    let scale = if scale.is_finite() {
        scale.clamp(1.0, 8.0)
    } else {
        1.0
    };
    (base * scale).clamp(base, base * 8.0)
}

fn cap_resample_step_for_segment(dist: f32, step: f32) -> f32 {
    if !dist.is_finite() || dist <= 0.0 || !step.is_finite() || step <= 0.0 {
        return step;
    }
    let max_samples = MAX_SEGMENT_SAMPLES as f32;
    if dist / step > max_samples {
        dist / max_samples
    } else {
        step
    }
}

fn downsample_emitted(points: &[(Point2D, f32)], target_count: usize) -> Vec<(Point2D, f32)> {
    let len = points.len();
    if len <= target_count {
        return points.to_vec();
    }
    if target_count <= 1 {
        return vec![points[len.saturating_sub(1)]];
    }
    let last = len - 1;
    let mut output = Vec::with_capacity(target_count);
    for i in 0..target_count {
        let idx = (i * last) / (target_count - 1);
        output.push(points[idx]);
    }
    output
}

fn average_segment_length(points: &[(Point2D, f32)]) -> f32 {
    if points.len() < 2 {
        return 0.0;
    }
    let mut total = 0.0f32;
    let mut count = 0u32;
    for i in 1..points.len() {
        let dist = point_distance(points[i - 1].0, points[i].0);
        if dist.is_finite() {
            total += dist;
            count += 1;
        }
    }
    if count == 0 {
        0.0
    } else {
        total / count as f32
    }
}

fn gaussian_kernel(radius: usize, sigma: f32) -> Vec<f32> {
    let sigma = if sigma.is_finite() { sigma.max(0.1) } else { 1.0 };
    let size = radius.saturating_mul(2).saturating_add(1);
    if size == 0 {
        return Vec::new();
    }
    let mut kernel = Vec::with_capacity(size);
    let mut sum = 0.0f32;
    let two_sigma2 = 2.0 * sigma * sigma;
    for i in 0..size {
        let x = i as i32 - radius as i32;
        let v = (-(x as f32 * x as f32) / two_sigma2).exp();
        kernel.push(v);
        sum += v;
    }
    if sum > 1.0e-6 {
        for k in kernel.iter_mut() {
            *k /= sum;
        }
    }
    kernel
}

fn gaussian_smooth_points(
    points: &[(Point2D, f32)],
    kernel: &[f32],
) -> Vec<(Point2D, f32)> {
    if points.len() < 3 || kernel.is_empty() {
        return points.to_vec();
    }
    let radius = kernel.len() / 2;
    let len = points.len();
    let mut output: Vec<(Point2D, f32)> = Vec::with_capacity(len);
    for i in 0..len {
        let mut sum_w = 0.0f32;
        let mut x = 0.0f32;
        let mut y = 0.0f32;
        let mut p = 0.0f32;
        for (k, &w) in kernel.iter().enumerate() {
            let offset = k as isize - radius as isize;
            let idx = if offset < 0 {
                i.saturating_sub((-offset) as usize)
            } else {
                (i + offset as usize).min(len - 1)
            };
            let (pos, pres) = points[idx];
            x += pos.x * w;
            y += pos.y * w;
            p += pres * w;
            sum_w += w;
        }
        if sum_w > 1.0e-6 {
            x /= sum_w;
            y /= sum_w;
            p /= sum_w;
        }
        output.push((Point2D { x, y }, p));
    }
    output[0] = points[0];
    output[len - 1] = points[len - 1];
    output
}

pub(crate) fn apply_streamline(
    points: &[(Point2D, f32)],
    strength: f32,
) -> Vec<(Point2D, f32)> {
    let strength = if strength.is_finite() {
        strength.clamp(0.0, 1.0)
    } else {
        0.0
    };
    if strength <= 0.0001 || points.len() < 3 {
        return points.to_vec();
    }
    let eased = strength.powf(0.32);
    let avg_dist = average_segment_length(points);
    if avg_dist <= 1.0e-4 {
        return points.to_vec();
    }
    let avg_dist = avg_dist.clamp(0.25, 50.0);
    let target_px = 3.0 + 45.0 * eased;
    let mut radius = (target_px / avg_dist).round() as usize;
    let max_radius = (points.len().saturating_sub(1) / 2).clamp(2, 96);
    radius = radius.clamp(2, max_radius);
    let sigma = radius as f32 * 0.8 + 0.5;
    let kernel = gaussian_kernel(radius, sigma);
    let passes = if eased < 0.25 { 2 } else if eased < 0.6 { 3 } else { 4 };
    let mut smoothed = points.to_vec();
    for _ in 0..passes {
        smoothed = gaussian_smooth_points(&smoothed, &kernel);
    }
    let mut resampled = adaptive_resample_spline(&smoothed, points.len());
    if resampled.len() != points.len() {
        return points.to_vec();
    }
    let last_idx = resampled.len() - 1;
    resampled[0] = points[0];
    resampled[last_idx] = points[points.len() - 1];
    for (idx, sample) in resampled.iter_mut().enumerate() {
        let pres = points[idx].1;
        sample.1 = if pres.is_finite() { pres.clamp(0.0, 1.0) } else { 0.0 };
    }
    let mut output: Vec<(Point2D, f32)> = Vec::with_capacity(points.len());
    let pos_mix = eased;
    for (orig, smooth) in points.iter().zip(resampled.iter()) {
        let x = orig.0.x + (smooth.0.x - orig.0.x) * pos_mix;
        let y = orig.0.y + (smooth.0.y - orig.0.y) * pos_mix;
        let pres = orig.1;
        output.push((Point2D { x, y }, pres));
    }
    output
}

fn adaptive_resample_spline(points: &[(Point2D, f32)], target_count: usize) -> Vec<(Point2D, f32)> {
    if points.len() < 2 || target_count < 2 {
        return points.to_vec();
    }

    let mut turning: Vec<f32> = vec![0.0; points.len()];
    for i in 1..points.len().saturating_sub(1) {
        turning[i] = turning_angle(points[i - 1].0, points[i].0, points[i + 1].0);
    }

    let curvature_weight = 0.75f32;
    let mut weights: Vec<f32> = Vec::with_capacity(points.len().saturating_sub(1));
    let mut total_weight = 0.0f32;

    for i in 0..points.len().saturating_sub(1) {
        let length = point_distance(points[i].0, points[i + 1].0);
        let mut curvature = 0.0f32;
        let mut count = 0.0f32;
        if i > 0 {
            curvature += turning[i];
            count += 1.0;
        }
        if i + 1 < points.len().saturating_sub(1) {
            curvature += turning[i + 1];
            count += 1.0;
        }
        if count > 0.0 {
            curvature /= count;
        }
        let weight = (length * (1.0 + curvature_weight * curvature)).max(1.0e-4);
        weights.push(weight);
        total_weight += weight;
    }

    if !total_weight.is_finite() || total_weight <= 0.0 {
        return points.to_vec();
    }

    let mut output: Vec<(Point2D, f32)> = Vec::with_capacity(target_count);
    output.push(points[0]);

    let step = total_weight / (target_count.saturating_sub(1) as f32);
    if !step.is_finite() || step <= 0.0 {
        return points.to_vec();
    }

    let mut seg_index = 0usize;
    let mut seg_start = 0.0f32;
    let mut seg_end = weights[0];

    for sample_idx in 1..target_count.saturating_sub(1) {
        let target = step * sample_idx as f32;
        while target > seg_end && seg_index + 1 < weights.len() {
            seg_index += 1;
            seg_start = seg_end;
            seg_end += weights[seg_index];
        }

        let denom = (seg_end - seg_start).max(1.0e-6);
        let t = ((target - seg_start) / denom).clamp(0.0, 1.0);

        let p0 = if seg_index == 0 {
            points[0].0
        } else {
            points[seg_index - 1].0
        };
        let p1 = points[seg_index].0;
        let p2 = points[seg_index + 1].0;
        let p3 = if seg_index + 2 < points.len() {
            points[seg_index + 2].0
        } else {
            points[points.len() - 1].0
        };
        let pos = catmull_rom(p0, p1, p2, p3, t);
        let pres = points[seg_index].1 + (points[seg_index + 1].1 - points[seg_index].1) * t;
        output.push((pos, pres));
    }

    output.push(points[points.len() - 1]);
    output
}

fn point_distance(a: Point2D, b: Point2D) -> f32 {
    let dx = a.x - b.x;
    let dy = a.y - b.y;
    (dx * dx + dy * dy).sqrt()
}

fn tangent_between(a: StrokeSample, b: StrokeSample) -> Point2D {
    let dt_ms = (b.timestamp_us.saturating_sub(a.timestamp_us) as f32) / 1000.0;
    let denom = dt_ms.max(1.0);
    Point2D {
        x: (b.pos.x - a.pos.x) / denom,
        y: (b.pos.y - a.pos.y) / denom,
    }
}

fn tangent_is_zero(t: Point2D) -> bool {
    if !t.x.is_finite() || !t.y.is_finite() {
        return true;
    }
    t.x.abs() <= 1.0e-6 && t.y.abs() <= 1.0e-6
}

fn cubic_point(p0: Point2D, p1: Point2D, p2: Point2D, p3: Point2D, t: f32) -> Point2D {
    let t = if t.is_finite() { t.clamp(0.0, 1.0) } else { 0.0 };
    let u = 1.0 - t;
    let tt = t * t;
    let uu = u * u;
    let uuu = uu * u;
    let ttt = tt * t;
    let x = uuu * p0.x + 3.0 * uu * t * p1.x + 3.0 * u * tt * p2.x + ttt * p3.x;
    let y = uuu * p0.y + 3.0 * uu * t * p1.y + 3.0 * u * tt * p2.y + ttt * p3.y;
    Point2D { x, y }
}

fn cubic_length_approx(p0: Point2D, p1: Point2D, p2: Point2D, p3: Point2D) -> f32 {
    let steps = 8usize;
    let mut length = 0.0f32;
    let mut prev = p0;
    for i in 1..=steps {
        let t = i as f32 / steps as f32;
        let curr = cubic_point(p0, p1, p2, p3, t);
        length += point_distance(prev, curr);
        prev = curr;
    }
    length
}

fn bezier_controls_from_tangents(
    p0: Point2D,
    p3: Point2D,
    t1: Point2D,
    t2: Point2D,
) -> (Point2D, Point2D) {
    let max_sane = 1.0e6;
    let control_dir1 = Point2D {
        x: p0.x + t1.x,
        y: p0.y + t1.y,
    };
    let control_dir2 = Point2D {
        x: p3.x - t2.x,
        y: p3.y - t2.y,
    };

    let mut control_target1;
    let mut control_target2;

    if let Some(intersection) =
        line_intersection_bounded(control_dir1, control_dir2, p0, p3)
    {
        let control_length = point_distance(p0, p3) * 0.5;
        control_target1 = point_on_line(p0, control_dir1, control_length);
        control_target2 = point_on_line(p3, control_dir2, control_length);
    } else {
        let intersection = line_intersection(p0, control_dir1, p3, control_dir2)
            .filter(|p| (p.x.abs() + p.y.abs()) <= max_sane)
            .unwrap_or(Point2D {
                x: (p0.x + p3.x) * 0.5,
                y: (p0.y + p3.y) * 0.5,
            });
        control_target1 = intersection;
        control_target2 = intersection;
    }

    let mut coeff = 0.8f32;
    let mut v1 = (t1.x * t1.x + t1.y * t1.y).sqrt();
    let mut v2 = (t2.x * t2.x + t2.y * t2.y).sqrt();
    if v1 <= 0.0 {
        v1 = 1.0e-6;
    }
    if v2 <= 0.0 {
        v2 = 1.0e-6;
    }
    let mut similarity = (v1 / v2).min(v2 / v1);
    if similarity < 0.5 {
        similarity = 0.5;
    }
    coeff *= 1.0 - (similarity - 0.8).max(0.0);

    let control1;
    let control2;
    if v1 > v2 {
        control1 = Point2D {
            x: p0.x * (1.0 - coeff) + control_target1.x * coeff,
            y: p0.y * (1.0 - coeff) + control_target1.y * coeff,
        };
        coeff *= similarity;
        control2 = Point2D {
            x: p3.x * (1.0 - coeff) + control_target2.x * coeff,
            y: p3.y * (1.0 - coeff) + control_target2.y * coeff,
        };
    } else {
        control2 = Point2D {
            x: p3.x * (1.0 - coeff) + control_target2.x * coeff,
            y: p3.y * (1.0 - coeff) + control_target2.y * coeff,
        };
        coeff *= similarity;
        control1 = Point2D {
            x: p0.x * (1.0 - coeff) + control_target1.x * coeff,
            y: p0.y * (1.0 - coeff) + control_target1.y * coeff,
        };
    }

    (control1, control2)
}

fn line_intersection(a1: Point2D, a2: Point2D, b1: Point2D, b2: Point2D) -> Option<Point2D> {
    let r = Point2D {
        x: a2.x - a1.x,
        y: a2.y - a1.y,
    };
    let s = Point2D {
        x: b2.x - b1.x,
        y: b2.y - b1.y,
    };
    let denom = r.x * s.y - r.y * s.x;
    if denom.abs() <= 1.0e-6 {
        return None;
    }
    let u = Point2D {
        x: b1.x - a1.x,
        y: b1.y - a1.y,
    };
    let t = (u.x * s.y - u.y * s.x) / denom;
    Some(Point2D {
        x: a1.x + t * r.x,
        y: a1.y + t * r.y,
    })
}

fn line_intersection_bounded(
    a1: Point2D,
    a2: Point2D,
    b1: Point2D,
    b2: Point2D,
) -> Option<Point2D> {
    let r = Point2D {
        x: a2.x - a1.x,
        y: a2.y - a1.y,
    };
    let s = Point2D {
        x: b2.x - b1.x,
        y: b2.y - b1.y,
    };
    let denom = r.x * s.y - r.y * s.x;
    if denom.abs() <= 1.0e-6 {
        return None;
    }
    let u = Point2D {
        x: b1.x - a1.x,
        y: b1.y - a1.y,
    };
    let t = (u.x * s.y - u.y * s.x) / denom;
    let v = (u.x * r.y - u.y * r.x) / denom;
    if t < 0.0 || t > 1.0 || v < 0.0 || v > 1.0 {
        return None;
    }
    Some(Point2D {
        x: a1.x + t * r.x,
        y: a1.y + t * r.y,
    })
}

fn point_on_line(start: Point2D, end: Point2D, length: f32) -> Point2D {
    let dx = end.x - start.x;
    let dy = end.y - start.y;
    let dist = (dx * dx + dy * dy).sqrt();
    if dist <= 1.0e-6 {
        return start;
    }
    let t = length / dist;
    Point2D {
        x: start.x + dx * t,
        y: start.y + dy * t,
    }
}

fn stroke_direction_angle(points: &[Point2D], index: usize) -> f32 {
    if points.len() < 2 {
        return 0.0;
    }
    let (dx, dy) = if index + 1 < points.len() {
        let next = points[index + 1];
        let curr = points[index];
        (next.x - curr.x, next.y - curr.y)
    } else if index > 0 {
        let curr = points[index];
        let prev = points[index - 1];
        (curr.x - prev.x, curr.y - prev.y)
    } else {
        (0.0, 0.0)
    };
    if !dx.is_finite() || !dy.is_finite() {
        return 0.0;
    }
    if dx.abs() <= 1.0e-6 && dy.abs() <= 1.0e-6 {
        return 0.0;
    }
    dy.atan2(dx)
}

fn turning_angle(prev: Point2D, curr: Point2D, next: Point2D) -> f32 {
    let v1x = curr.x - prev.x;
    let v1y = curr.y - prev.y;
    let v2x = next.x - curr.x;
    let v2y = next.y - curr.y;
    let len1 = (v1x * v1x + v1y * v1y).sqrt();
    let len2 = (v2x * v2x + v2y * v2y).sqrt();
    if len1 <= 1.0e-6 || len2 <= 1.0e-6 {
        return 0.0;
    }
    let cos = ((v1x * v2x + v1y * v2y) / (len1 * len2)).clamp(-1.0, 1.0);
    cos.acos()
}

fn catmull_rom(p0: Point2D, p1: Point2D, p2: Point2D, p3: Point2D, t: f32) -> Point2D {
    let t = if t.is_finite() {
        t.clamp(0.0, 1.0)
    } else {
        0.0
    };
    let t2 = t * t;
    let t3 = t2 * t;
    let x = 0.5
        * ((2.0 * p1.x)
            + (-p0.x + p2.x) * t
            + (2.0 * p0.x - 5.0 * p1.x + 4.0 * p2.x - p3.x) * t2
            + (-p0.x + 3.0 * p1.x - 3.0 * p2.x + p3.x) * t3);
    let y = 0.5
        * ((2.0 * p1.y)
            + (-p0.y + p2.y) * t
            + (2.0 * p0.y - 5.0 * p1.y + 4.0 * p2.y - p3.y) * t2
            + (-p0.y + 3.0 * p1.y - 3.0 * p2.y + p3.y) * t3);
    Point2D { x, y }
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

pub(crate) fn brush_random_rotation_radians(center: Point2D, seed: u32) -> f32 {
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

fn brush_random_unit(center: Point2D, seed: u32, salt: u32) -> f32 {
    let x = (center.x * 256.0).round() as i32;
    let y = (center.y * 256.0).round() as i32;

    let mut h: u32 = 0;
    h ^= seed;
    h ^= salt;
    h ^= (x as u32).wrapping_mul(0x9e3779b1);
    h ^= (y as u32).wrapping_mul(0x85ebca77);
    h = mix32(h);

    (h as f64 / 4294967296.0) as f32
}

fn brush_scatter_offset(center: Point2D, seed: u32, radius: f32, salt: u32) -> Point2D {
    if !radius.is_finite() || radius <= 0.0 {
        return Point2D { x: 0.0, y: 0.0 };
    }
    let u = brush_random_unit(center, seed, salt);
    let v = brush_random_unit(center, seed, salt.wrapping_add(1));
    let dist = u.sqrt() * radius;
    let angle = v * std::f32::consts::PI * 2.0;
    Point2D {
        x: angle.cos() * dist,
        y: angle.sin() * dist,
    }
}

struct LcgRng {
    state: u32,
}

impl LcgRng {
    fn new(seed: u32) -> Self {
        Self {
            state: if seed == 0 { 0x6d2b_79f5 } else { seed },
        }
    }

    fn next_u32(&mut self) -> u32 {
        self.state = self
            .state
            .wrapping_mul(1664525)
            .wrapping_add(1013904223);
        self.state
    }

    fn next_f32(&mut self) -> f32 {
        (self.next_u32() as f64 / 4294967296.0) as f32
    }
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
    if canvas_width == 0 || canvas_height == 0 || points.is_empty() || points.len() != radii.len() {
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
