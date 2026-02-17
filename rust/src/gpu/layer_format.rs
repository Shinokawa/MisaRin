use wgpu::TextureFormat;

#[cfg(target_os = "ios")]
pub(crate) const LAYER_TEXTURE_FORMAT: TextureFormat = TextureFormat::Rgba8Unorm;

#[cfg(not(target_os = "ios"))]
pub(crate) const LAYER_TEXTURE_FORMAT: TextureFormat = TextureFormat::R32Uint;
