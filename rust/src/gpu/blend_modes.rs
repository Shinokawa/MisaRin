#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u32)]
pub enum GpuBlendMode {
    Normal = 0,
    Multiply = 1,
    Dissolve = 2,
    Darken = 3,
    ColorBurn = 4,
    LinearBurn = 5,
    DarkerColor = 6,
    Lighten = 7,
    Screen = 8,
    ColorDodge = 9,
    LinearDodge = 10,
    LighterColor = 11,
    Overlay = 12,
    SoftLight = 13,
    HardLight = 14,
    VividLight = 15,
    LinearLight = 16,
    PinLight = 17,
    HardMix = 18,
    Difference = 19,
    Exclusion = 20,
    Subtract = 21,
    Divide = 22,
    Hue = 23,
    Saturation = 24,
    Color = 25,
    Luminosity = 26,
}

impl GpuBlendMode {
    pub const fn as_u32(self) -> u32 {
        self as u32
    }
}

/// Maps `CanvasLayerBlendMode.index` (Dart) to shader `GpuBlendMode`.
///
/// Unsupported modes are mapped to `Normal`.
pub fn map_canvas_blend_mode_index(index: u32) -> GpuBlendMode {
    match index {
        // CanvasLayerBlendMode.normal
        0 => GpuBlendMode::Normal,
        // CanvasLayerBlendMode.multiply
        1 => GpuBlendMode::Multiply,
        // CanvasLayerBlendMode.dissolve
        2 => GpuBlendMode::Dissolve,
        // CanvasLayerBlendMode.darken
        3 => GpuBlendMode::Darken,
        // CanvasLayerBlendMode.colorBurn
        4 => GpuBlendMode::ColorBurn,
        // CanvasLayerBlendMode.linearBurn
        5 => GpuBlendMode::LinearBurn,
        // CanvasLayerBlendMode.darkerColor
        6 => GpuBlendMode::DarkerColor,
        // CanvasLayerBlendMode.lighten
        7 => GpuBlendMode::Lighten,
        // CanvasLayerBlendMode.screen
        8 => GpuBlendMode::Screen,
        // CanvasLayerBlendMode.colorDodge
        9 => GpuBlendMode::ColorDodge,
        // CanvasLayerBlendMode.linearDodge
        10 => GpuBlendMode::LinearDodge,
        // CanvasLayerBlendMode.lighterColor
        11 => GpuBlendMode::LighterColor,
        // CanvasLayerBlendMode.overlay
        12 => GpuBlendMode::Overlay,
        // CanvasLayerBlendMode.softLight
        13 => GpuBlendMode::SoftLight,
        // CanvasLayerBlendMode.hardLight
        14 => GpuBlendMode::HardLight,
        // CanvasLayerBlendMode.vividLight
        15 => GpuBlendMode::VividLight,
        // CanvasLayerBlendMode.linearLight
        16 => GpuBlendMode::LinearLight,
        // CanvasLayerBlendMode.pinLight
        17 => GpuBlendMode::PinLight,
        // CanvasLayerBlendMode.hardMix
        18 => GpuBlendMode::HardMix,
        // CanvasLayerBlendMode.difference
        19 => GpuBlendMode::Difference,
        // CanvasLayerBlendMode.exclusion
        20 => GpuBlendMode::Exclusion,
        // CanvasLayerBlendMode.subtract
        21 => GpuBlendMode::Subtract,
        // CanvasLayerBlendMode.divide
        22 => GpuBlendMode::Divide,
        // CanvasLayerBlendMode.hue
        23 => GpuBlendMode::Hue,
        // CanvasLayerBlendMode.saturation
        24 => GpuBlendMode::Saturation,
        // CanvasLayerBlendMode.color
        25 => GpuBlendMode::Color,
        // CanvasLayerBlendMode.luminosity
        26 => GpuBlendMode::Luminosity,
        _ => GpuBlendMode::Normal,
    }
}
