#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u32)]
pub enum GpuBlendMode {
    Normal = 0,
    Multiply = 1,
    Screen = 2,
    Overlay = 3,
    Darken = 4,
    Lighten = 5,
    ColorDodge = 6,
    ColorBurn = 7,
    HardLight = 8,
    SoftLight = 9,
    Difference = 10,
    Exclusion = 11,
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
        // CanvasLayerBlendMode.darken
        3 => GpuBlendMode::Darken,
        // CanvasLayerBlendMode.colorBurn
        4 => GpuBlendMode::ColorBurn,
        // CanvasLayerBlendMode.lighten
        7 => GpuBlendMode::Lighten,
        // CanvasLayerBlendMode.screen
        8 => GpuBlendMode::Screen,
        // CanvasLayerBlendMode.colorDodge
        9 => GpuBlendMode::ColorDodge,
        // CanvasLayerBlendMode.overlay
        12 => GpuBlendMode::Overlay,
        // CanvasLayerBlendMode.softLight
        13 => GpuBlendMode::SoftLight,
        // CanvasLayerBlendMode.hardLight
        14 => GpuBlendMode::HardLight,
        // CanvasLayerBlendMode.difference
        19 => GpuBlendMode::Difference,
        // CanvasLayerBlendMode.exclusion
        20 => GpuBlendMode::Exclusion,
        _ => GpuBlendMode::Normal,
    }
}
