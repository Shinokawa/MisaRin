pub struct PsdDocument {
    pub width: i32,
    pub height: i32,
    pub layers: Vec<PsdLayer>,
}

pub struct PsdLayer {
    pub name: String,
    pub visible: bool,
    pub opacity: u8,
    pub clipping_mask: bool,
    pub blend_mode_key: String,
    pub bitmap: Vec<u8>, // RGBA8888, tightly packed
    pub bitmap_width: i32,
    pub bitmap_height: i32,
    pub bitmap_left: i32,
    pub bitmap_top: i32,
}

pub fn import_psd(bytes: Vec<u8>) -> Result<PsdDocument, String> {
    let psd = psd::Psd::from_bytes(&bytes).map_err(|e| e.to_string())?;

    if psd.depth() != psd::PsdDepth::Eight {
        return Err(format!("仅支持 8bit PSD，当前深度：{:?}", psd.depth()));
    }
    if psd.color_mode() != psd::ColorMode::Rgb {
        return Err(format!(
            "仅支持 RGB PSD，当前色彩模式：{:?}",
            psd.color_mode()
        ));
    }

    let width: i32 = psd.width() as i32;
    let height: i32 = psd.height() as i32;

    let mut layers: Vec<PsdLayer> = Vec::new();

    for layer in psd.layers().iter() {
        let left: i32 = layer.layer_left();
        let top: i32 = layer.layer_top();
        let layer_width: i32 = layer.width() as i32;
        let layer_height: i32 = layer.height() as i32;
        if layer_width <= 0 || layer_height <= 0 {
            continue;
        }

        let right: i32 = left.saturating_add(layer_width);
        let bottom: i32 = top.saturating_add(layer_height);

        let clipped_left = left.clamp(0, width);
        let clipped_top = top.clamp(0, height);
        let clipped_right = right.clamp(0, width);
        let clipped_bottom = bottom.clamp(0, height);
        let clipped_width = clipped_right - clipped_left;
        let clipped_height = clipped_bottom - clipped_top;
        if clipped_width <= 0 || clipped_height <= 0 {
            continue;
        }

        let expected_len: usize = (layer_width as usize).saturating_mul(layer_height as usize);

        let mut red = layer
            .channel_bytes(psd::PsdChannelKind::Red)
            .unwrap_or_else(|| vec![0; expected_len]);
        let mut green = layer
            .channel_bytes(psd::PsdChannelKind::Green)
            .unwrap_or_else(|| vec![0; expected_len]);
        let mut blue = layer
            .channel_bytes(psd::PsdChannelKind::Blue)
            .unwrap_or_else(|| vec![0; expected_len]);
        let mut alpha = layer
            .channel_bytes(psd::PsdChannelKind::TransparencyMask)
            .unwrap_or_else(|| vec![255; expected_len]);

        if red.len() != expected_len {
            red.resize(expected_len, 0);
        }
        if green.len() != expected_len {
            green.resize(expected_len, 0);
        }
        if blue.len() != expected_len {
            blue.resize(expected_len, 0);
        }
        if alpha.len() != expected_len {
            alpha.resize(expected_len, 255);
        }

        let src_offset_x: usize = (clipped_left - left).max(0) as usize;
        let src_offset_y: usize = (clipped_top - top).max(0) as usize;
        let clipped_width_usize: usize = clipped_width as usize;
        let clipped_height_usize: usize = clipped_height as usize;
        let layer_width_usize: usize = layer_width as usize;

        let mut bitmap: Vec<u8> = vec![0u8; clipped_width_usize * clipped_height_usize * 4];
        for y in 0..clipped_height_usize {
            let src_y = src_offset_y + y;
            let src_row_start = src_y * layer_width_usize + src_offset_x;
            let dest_row_start = y * clipped_width_usize * 4;
            for x in 0..clipped_width_usize {
                let src_index = src_row_start + x;
                let dest_index = dest_row_start + x * 4;
                bitmap[dest_index] = red[src_index];
                bitmap[dest_index + 1] = green[src_index];
                bitmap[dest_index + 2] = blue[src_index];
                bitmap[dest_index + 3] = alpha[src_index];
            }
        }

        layers.push(PsdLayer {
            name: layer.name().to_string(),
            visible: layer.visible(),
            opacity: layer.opacity(),
            clipping_mask: layer.is_clipping_mask(),
            blend_mode_key: String::from_utf8_lossy(&layer.blend_mode_key()).to_string(),
            bitmap,
            bitmap_width: clipped_width,
            bitmap_height: clipped_height,
            bitmap_left: clipped_left,
            bitmap_top: clipped_top,
        });
    }

    Ok(PsdDocument {
        width,
        height,
        layers,
    })
}
