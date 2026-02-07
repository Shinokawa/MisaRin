#[repr(C)]
#[derive(Clone, Copy)]
pub struct EnginePoint {
    pub x: f32,
    pub y: f32,
    pub pressure: f32,
    pub _pad0: f32,
    pub timestamp_us: u64,
    pub flags: u32,
    pub pointer_id: u32,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct SprayPoint {
    pub x: f32,
    pub y: f32,
    pub radius: f32,
    pub alpha: f32,
}
