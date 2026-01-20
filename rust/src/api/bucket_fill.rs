use std::cmp;

#[derive(Debug, Clone)]
pub struct FloodFillPatch {
    pub left: i32,
    pub top: i32,
    pub width: i32,
    pub height: i32,
    pub pixels: Vec<u32>,
}

impl FloodFillPatch {
    fn empty() -> Self {
        Self {
            left: 0,
            top: 0,
            width: 0,
            height: 0,
            pixels: Vec::new(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct FloodFillRect {
    pub left: i32,
    pub top: i32,
    pub width: i32,
    pub height: i32,
}

impl FloodFillRect {
    fn empty() -> Self {
        Self {
            left: 0,
            top: 0,
            width: 0,
            height: 0,
        }
    }
}

pub fn flood_fill_patch(
    width: i32,
    height: i32,
    mut pixels: Vec<u32>,
    sample_pixels: Option<Vec<u32>>,
    start_x: i32,
    start_y: i32,
    color_value: u32,
    target_color_value: Option<u32>,
    contiguous: bool,
    tolerance: i32,
    fill_gap: i32,
    selection_mask: Option<Vec<u8>>,
    swallow_colors: Option<Vec<u32>>,
    antialias_level: i32,
) -> FloodFillPatch {
    if width <= 0 || height <= 0 {
        return FloodFillPatch::empty();
    }
    let width_usize = width as usize;
    let height_usize = height as usize;
    let len = match width_usize.checked_mul(height_usize) {
        Some(v) => v,
        None => return FloodFillPatch::empty(),
    };
    if pixels.len() != len {
        return FloodFillPatch::empty();
    }

    let Some((min_x, min_y, max_x, max_y)) = flood_fill_bounds(
        width_usize,
        height_usize,
        pixels.as_mut_slice(),
        sample_pixels,
        start_x,
        start_y,
        color_value,
        target_color_value,
        contiguous,
        tolerance,
        fill_gap,
        selection_mask,
        swallow_colors,
        antialias_level,
    ) else {
        return FloodFillPatch::empty();
    };

    export_patch(width_usize, &pixels, min_x, min_y, max_x, max_y)
}

pub fn flood_fill_in_place(
    ptr: usize,
    width: i32,
    height: i32,
    sample_pixels: Option<Vec<u32>>,
    start_x: i32,
    start_y: i32,
    color_value: u32,
    target_color_value: Option<u32>,
    contiguous: bool,
    tolerance: i32,
    fill_gap: i32,
    selection_mask: Option<Vec<u8>>,
    swallow_colors: Option<Vec<u32>>,
    antialias_level: i32,
) -> FloodFillRect {
    if ptr == 0 || width <= 0 || height <= 0 {
        return FloodFillRect::empty();
    }
    let width_usize = width as usize;
    let height_usize = height as usize;
    let len = match width_usize.checked_mul(height_usize) {
        Some(v) => v,
        None => return FloodFillRect::empty(),
    };
    if len == 0 || len > isize::MAX as usize {
        return FloodFillRect::empty();
    }

    let pixels: &mut [u32] = unsafe { std::slice::from_raw_parts_mut(ptr as *mut u32, len) };

    let Some((min_x, min_y, max_x, max_y)) = flood_fill_bounds(
        width_usize,
        height_usize,
        pixels,
        sample_pixels,
        start_x,
        start_y,
        color_value,
        target_color_value,
        contiguous,
        tolerance,
        fill_gap,
        selection_mask,
        swallow_colors,
        antialias_level,
    ) else {
        return FloodFillRect::empty();
    };

    FloodFillRect {
        left: min_x,
        top: min_y,
        width: max_x.saturating_sub(min_x).saturating_add(1),
        height: max_y.saturating_sub(min_y).saturating_add(1),
    }
}

pub fn magic_wand_mask(
    width: i32,
    height: i32,
    pixels: Vec<u32>,
    start_x: i32,
    start_y: i32,
    tolerance: i32,
    selection_mask: Option<Vec<u8>>,
) -> Option<Vec<u8>> {
    if width <= 0 || height <= 0 {
        return None;
    }
    let width_usize = width as usize;
    let height_usize = height as usize;
    let len = width_usize.checked_mul(height_usize)?;
    if pixels.len() != len {
        return None;
    }
    if start_x < 0 || start_y < 0 {
        return None;
    }
    if start_x as usize >= width_usize || start_y as usize >= height_usize {
        return None;
    }

    let start_index = (start_y as usize) * width_usize + (start_x as usize);
    let selection_mask = selection_mask.filter(|mask| mask.len() == len);
    if let Some(mask) = selection_mask.as_deref() {
        if mask[start_index] == 0 {
            return None;
        }
    }

    let base_color = pixels[start_index];
    let tol = tolerance.clamp(0, 255) as u8;
    let mut fill_mask: Vec<u8> = vec![0; len];
    let mut stack: Vec<usize> = vec![start_index];
    while let Some(index) = stack.pop() {
        if fill_mask[index] == 1 {
            continue;
        }
        if !colors_within_tolerance(pixels[index], base_color, tol) {
            continue;
        }
        if let Some(mask) = selection_mask.as_deref() {
            if mask[index] == 0 {
                continue;
            }
        }
        fill_mask[index] = 1;
        let x = index % width_usize;
        let y = index / width_usize;
        if x > 0 {
            stack.push(index - 1);
        }
        if x + 1 < width_usize {
            stack.push(index + 1);
        }
        if y > 0 {
            stack.push(index - width_usize);
        }
        if y + 1 < height_usize {
            stack.push(index + width_usize);
        }
    }

    if tol > 0 {
        expand_mask_by_one(&mut fill_mask, width_usize, height_usize, selection_mask.as_deref());
    }

    if fill_mask.iter().all(|&value| value == 0) {
        return None;
    }
    Some(fill_mask)
}

fn flood_fill_bounds(
    width: usize,
    height: usize,
    pixels: &mut [u32],
    sample_pixels: Option<Vec<u32>>,
    start_x: i32,
    start_y: i32,
    color_value: u32,
    target_color_value: Option<u32>,
    contiguous: bool,
    tolerance: i32,
    fill_gap: i32,
    selection_mask: Option<Vec<u8>>,
    swallow_colors: Option<Vec<u32>>,
    antialias_level: i32,
) -> Option<(i32, i32, i32, i32)> {
    if width == 0 || height == 0 {
        return None;
    }
    let len: usize = width.checked_mul(height)?;
    if pixels.len() != len {
        return None;
    }
    if start_x < 0 || start_y < 0 {
        return None;
    }
    if start_x as usize >= width || start_y as usize >= height {
        return None;
    }

    let start_index = (start_y as usize) * width + (start_x as usize);
    let sample_pixels = sample_pixels.filter(|sample| sample.len() == len);
    let sample_base = sample_pixels
        .as_deref()
        .unwrap_or(pixels)
        .get(start_index)
        .copied()
        .unwrap_or(0);
    let base_color = target_color_value.unwrap_or(sample_base);
    let replacement = color_value;

    let selection_mask = selection_mask.filter(|mask| mask.len() == len);

    let tol = tolerance.clamp(0, 255) as u8;
    let gap = fill_gap.clamp(0, 64) as u8;
    let antialias_level = antialias_level.clamp(0, 3) as u8;
    let swallow_colors = swallow_colors
        .unwrap_or_default()
        .into_iter()
        .filter(|&c| c != replacement)
        .collect::<Vec<u32>>();

    let mut changed_min_x: i32 = width as i32;
    let mut changed_min_y: i32 = height as i32;
    let mut changed_max_x: i32 = -1;
    let mut changed_max_y: i32 = -1;

    if let Some(mask) = selection_mask.as_deref() {
        if mask[start_index] == 0 {
            return None;
        }
    }

    if base_color == replacement
        && sample_pixels.is_none()
        && swallow_colors.is_empty()
        && antialias_level == 0
    {
        return None;
    }

    let sample_slice: &[u32] = sample_pixels.as_deref().unwrap_or(pixels);
    let mut fill_mask: Vec<u8> = vec![0; len];

    if !contiguous {
        for i in 0..len {
            if let Some(mask) = selection_mask.as_deref() {
                if mask[i] == 0 {
                    continue;
                }
            }
            if colors_within_tolerance(sample_slice[i], base_color, tol) {
                fill_mask[i] = 1;
            }
        }
    } else if gap > 0 {
        let mut target_mask: Vec<u8> = vec![0; len];
        for i in 0..len {
            if let Some(mask) = selection_mask.as_deref() {
                if mask[i] == 0 {
                    continue;
                }
            }
            if colors_within_tolerance(sample_slice[i], base_color, tol) {
                target_mask[i] = 1;
            }
        }
        if target_mask[start_index] == 0 {
            return None;
        }

        // "Fill gap" should only prevent leaking through small openings.
        // Strategy:
        // 1) Open the target mask (Chebyshev radius = fill_gap),
        // 2) Identify the outside region in the opened mask,
        // 3) Reconstruct the interior on the original target mask.
        //
        // Important: The outside region can be only a few pixels thick (e.g. tiny canvases),
        // so we pad with 1s inside `open_mask8` to avoid eroding the boundary away entirely.
        let opened_target = open_mask8(target_mask.clone(), width, height, gap);

        let mut outside_seeds: Vec<usize> = Vec::new();
        for x in 0..width {
            let top_index = x;
            if opened_target.get(top_index) == Some(&1) {
                outside_seeds.push(top_index);
            }
            let bottom_index = (height - 1) * width + x;
            if opened_target.get(bottom_index) == Some(&1) {
                outside_seeds.push(bottom_index);
            }
        }
        for y in 1..height.saturating_sub(1) {
            let left_index = y * width;
            if opened_target.get(left_index) == Some(&1) {
                outside_seeds.push(left_index);
            }
            let right_index = y * width + (width - 1);
            if opened_target.get(right_index) == Some(&1) {
                outside_seeds.push(right_index);
            }
        }

        if outside_seeds.is_empty() {
            fill_from_target_mask(&mut target_mask, &mut fill_mask, width, height, start_index);
        } else {
            let mut outside_open: Vec<u8> = vec![0; len];
            let mut outside_queue: Vec<usize> = outside_seeds.clone();
            let mut outside_head: usize = 0;
            for &seed in &outside_seeds {
                outside_open[seed] = 1;
            }
            while outside_head < outside_queue.len() {
                let index = outside_queue[outside_head];
                outside_head += 1;
                let x = index % width;
                let y = index / width;
                if x > 0 {
                    let neighbor = index - 1;
                    if outside_open[neighbor] == 0 && opened_target[neighbor] == 1 {
                        outside_open[neighbor] = 1;
                        outside_queue.push(neighbor);
                    }
                }
                if x + 1 < width {
                    let neighbor = index + 1;
                    if outside_open[neighbor] == 0 && opened_target[neighbor] == 1 {
                        outside_open[neighbor] = 1;
                        outside_queue.push(neighbor);
                    }
                }
                if y > 0 {
                    let neighbor = index - width;
                    if outside_open[neighbor] == 0 && opened_target[neighbor] == 1 {
                        outside_open[neighbor] = 1;
                        outside_queue.push(neighbor);
                    }
                }
                if y + 1 < height {
                    let neighbor = index + width;
                    if outside_open[neighbor] == 0 && opened_target[neighbor] == 1 {
                        outside_open[neighbor] = 1;
                        outside_queue.push(neighbor);
                    }
                }
            }

            let mut effective_start: Option<usize> = Some(start_index);
            if opened_target[start_index] == 0 {
                let snapped = find_nearest_fillable_start_index(
                    start_index,
                    &opened_target,
                    sample_slice,
                    base_color,
                    width,
                    height,
                    tol,
                    selection_mask.as_deref(),
                    gap as usize + 1,
                );
                if snapped.is_none() {
                    fill_from_target_mask(
                        &mut target_mask,
                        &mut fill_mask,
                        width,
                        height,
                        start_index,
                    );
                    effective_start = None;
                } else {
                    effective_start = snapped;
                }
            }

            if let Some(effective_start_index) = effective_start {
                let mut seed_visited: Vec<u8> = vec![0; len];
                let mut seed_queue: Vec<usize> = vec![effective_start_index];
                seed_visited[effective_start_index] = 1;
                let mut seed_head: usize = 0;
                let mut touches_outside: bool = outside_open[effective_start_index] == 1;
                while seed_head < seed_queue.len() {
                    let index = seed_queue[seed_head];
                    seed_head += 1;
                    if outside_open[index] == 1 {
                        touches_outside = true;
                        break;
                    }
                    let x = index % width;
                    let y = index / width;
                    if x > 0 {
                        let neighbor = index - 1;
                        if seed_visited[neighbor] == 0 && opened_target[neighbor] == 1 {
                            seed_visited[neighbor] = 1;
                            seed_queue.push(neighbor);
                        }
                    }
                    if x + 1 < width {
                        let neighbor = index + 1;
                        if seed_visited[neighbor] == 0 && opened_target[neighbor] == 1 {
                            seed_visited[neighbor] = 1;
                            seed_queue.push(neighbor);
                        }
                    }
                    if y > 0 {
                        let neighbor = index - width;
                        if seed_visited[neighbor] == 0 && opened_target[neighbor] == 1 {
                            seed_visited[neighbor] = 1;
                            seed_queue.push(neighbor);
                        }
                    }
                    if y + 1 < height {
                        let neighbor = index + width;
                        if seed_visited[neighbor] == 0 && opened_target[neighbor] == 1 {
                            seed_visited[neighbor] = 1;
                            seed_queue.push(neighbor);
                        }
                    }
                }

                if touches_outside {
                    fill_from_target_mask(
                        &mut target_mask,
                        &mut fill_mask,
                        width,
                        height,
                        start_index,
                    );
                } else {
                    let mut queue: Vec<usize> = seed_queue.clone();
                    let mut head: usize = 0;

                    // Seed initial pixels (inside the opened region) back into the original target.
                    for &index in &queue {
                        if target_mask[index] == 1 && outside_open[index] == 0 {
                            target_mask[index] = 0;
                            fill_mask[index] = 1;
                        }
                    }

                    while head < queue.len() {
                        let index = queue[head];
                        head += 1;
                        let x = index % width;
                        let y = index / width;
                        if x > 0 {
                            let neighbor = index - 1;
                            if target_mask[neighbor] == 1 && outside_open[neighbor] == 0 {
                                target_mask[neighbor] = 0;
                                fill_mask[neighbor] = 1;
                                queue.push(neighbor);
                            }
                        }
                        if x + 1 < width {
                            let neighbor = index + 1;
                            if target_mask[neighbor] == 1 && outside_open[neighbor] == 0 {
                                target_mask[neighbor] = 0;
                                fill_mask[neighbor] = 1;
                                queue.push(neighbor);
                            }
                        }
                        if y > 0 {
                            let neighbor = index - width;
                            if target_mask[neighbor] == 1 && outside_open[neighbor] == 0 {
                                target_mask[neighbor] = 0;
                                fill_mask[neighbor] = 1;
                                queue.push(neighbor);
                            }
                        }
                        if y + 1 < height {
                            let neighbor = index + width;
                            if target_mask[neighbor] == 1 && outside_open[neighbor] == 0 {
                                target_mask[neighbor] = 0;
                                fill_mask[neighbor] = 1;
                                queue.push(neighbor);
                            }
                        }
                    }
                }
            }
        }
    } else {
        let mut stack: Vec<usize> = vec![start_index];
        while let Some(index) = stack.pop() {
            if fill_mask[index] == 1 {
                continue;
            }
            if !colors_within_tolerance(sample_slice[index], base_color, tol) {
                continue;
            }
            if let Some(mask) = selection_mask.as_deref() {
                if mask[index] == 0 {
                    continue;
                }
            }
            fill_mask[index] = 1;
            let x = index % width;
            let y = index / width;
            if x > 0 {
                stack.push(index - 1);
            }
            if x + 1 < width {
                stack.push(index + 1);
            }
            if y > 0 {
                stack.push(index - width);
            }
            if y + 1 < height {
                stack.push(index + width);
            }
        }

        // Expand mask by 1 pixel (dilation) to cover AA edges when tolerance > 0.
        if tol > 0 {
            expand_mask_by_one(&mut fill_mask, width, height, selection_mask.as_deref());
        }
    }

    // Apply fill and compute changed bounds.
    for y in 0..height {
        let row_offset = y * width;
        for x in 0..width {
            let index = row_offset + x;
            if fill_mask[index] == 0 {
                continue;
            }
            if pixels[index] == replacement {
                continue;
            }
            pixels[index] = replacement;
            let xi = x as i32;
            let yi = y as i32;
            if xi < changed_min_x {
                changed_min_x = xi;
            }
            if yi < changed_min_y {
                changed_min_y = yi;
            }
            if xi > changed_max_x {
                changed_max_x = xi;
            }
            if yi > changed_max_y {
                changed_max_y = yi;
            }
        }
    }

    if !swallow_colors.is_empty() {
        swallow_color_lines(
            pixels,
            width,
            height,
            &fill_mask,
            selection_mask.as_deref(),
            &swallow_colors,
            replacement,
            &mut changed_min_x,
            &mut changed_min_y,
            &mut changed_max_x,
            &mut changed_max_y,
        );
    }

    if antialias_level > 0 {
        apply_antialias_to_mask(
            pixels,
            width,
            height,
            &fill_mask,
            antialias_level,
            &mut changed_min_x,
            &mut changed_min_y,
            &mut changed_max_x,
            &mut changed_max_y,
        );
    }

    if changed_max_x < changed_min_x || changed_max_y < changed_min_y {
        return None;
    }
    Some((changed_min_x, changed_min_y, changed_max_x, changed_max_y))
}

fn export_patch(
    width: usize,
    pixels: &[u32],
    min_x: i32,
    min_y: i32,
    max_x: i32,
    max_y: i32,
) -> FloodFillPatch {
    if max_x < min_x || max_y < min_y {
        return FloodFillPatch::empty();
    }
    let patch_width = (max_x - min_x + 1) as usize;
    let patch_height = (max_y - min_y + 1) as usize;
    let left = min_x as usize;
    let top = min_y as usize;
    let mut patch_pixels: Vec<u32> = Vec::with_capacity(patch_width * patch_height);
    for row in 0..patch_height {
        let src_offset = (top + row) * width + left;
        patch_pixels.extend_from_slice(&pixels[src_offset..src_offset + patch_width]);
    }
    FloodFillPatch {
        left: min_x,
        top: min_y,
        width: patch_width as i32,
        height: patch_height as i32,
        pixels: patch_pixels,
    }
}

fn colors_within_tolerance(a: u32, b: u32, tolerance: u8) -> bool {
    if tolerance == 0 {
        return a == b;
    }
    let aa = ((a >> 24) & 0xff) as i32;
    let ar = ((a >> 16) & 0xff) as i32;
    let ag = ((a >> 8) & 0xff) as i32;
    let ab = (a & 0xff) as i32;

    let ba = ((b >> 24) & 0xff) as i32;
    let br = ((b >> 16) & 0xff) as i32;
    let bg = ((b >> 8) & 0xff) as i32;
    let bb = (b & 0xff) as i32;

    let t = tolerance as i32;
    (aa - ba).abs() <= t && (ar - br).abs() <= t && (ag - bg).abs() <= t && (ab - bb).abs() <= t
}

fn open_mask8(mask: Vec<u8>, width: usize, height: usize, radius: u8) -> Vec<u8> {
    if mask.is_empty() || width == 0 || height == 0 || radius == 0 {
        return mask;
    }

    let pad = radius as usize;
    let padded_width = match width.checked_add(pad.saturating_mul(2)) {
        Some(v) => v,
        None => return open_mask8_unpadded(mask, width, height, radius),
    };
    let padded_height = match height.checked_add(pad.saturating_mul(2)) {
        Some(v) => v,
        None => return open_mask8_unpadded(mask, width, height, radius),
    };
    let padded_len = match padded_width.checked_mul(padded_height) {
        Some(v) => v,
        None => return open_mask8_unpadded(mask, width, height, radius),
    };
    if padded_len == 0 || padded_len > isize::MAX as usize {
        return open_mask8_unpadded(mask, width, height, radius);
    }

    // Pad with 1s so the outside region stays connected to the canvas boundary after opening.
    let mut padded: Vec<u8> = vec![1u8; padded_len];
    for y in 0..height {
        let src_offset = y * width;
        let dst_offset = (y + pad) * padded_width + pad;
        padded[dst_offset..dst_offset + width]
            .copy_from_slice(&mask[src_offset..src_offset + width]);
    }

    let opened = open_mask8_unpadded(padded, padded_width, padded_height, radius);

    // Crop back to the original size.
    let mut result: Vec<u8> = vec![0u8; mask.len()];
    for y in 0..height {
        let src_offset = (y + pad) * padded_width + pad;
        let dst_offset = y * width;
        result[dst_offset..dst_offset + width]
            .copy_from_slice(&opened[src_offset..src_offset + width]);
    }
    result
}

fn open_mask8_unpadded(mut mask: Vec<u8>, width: usize, height: usize, radius: u8) -> Vec<u8> {
    if mask.is_empty() || width == 0 || height == 0 || radius == 0 {
        return mask;
    }

    let mut buffer: Vec<u8> = vec![0; mask.len()];
    let mut queue: Vec<usize> = Vec::new();

    fn dilate_from_mask_value(
        source: &[u8],
        out: &mut [u8],
        seed_value: u8,
        width: usize,
        height: usize,
        radius: u8,
        queue: &mut Vec<usize>,
    ) {
        queue.clear();
        out.fill(0);
        for (i, &v) in source.iter().enumerate() {
            if v != seed_value {
                continue;
            }
            out[i] = 1;
            queue.push(i);
        }
        if queue.is_empty() {
            return;
        }

        let mut head: usize = 0;
        let last_row_start = (height - 1) * width;
        for _ in 0..radius {
            let level_end = queue.len();
            while head < level_end {
                let index = queue[head];
                head += 1;
                let x = index % width;
                let has_left = x > 0;
                let has_right = x + 1 < width;
                let has_up = index >= width;
                let has_down = index < last_row_start;

                let mut try_add = |neighbor: usize| {
                    if neighbor >= out.len() {
                        return;
                    }
                    if out[neighbor] != 0 {
                        return;
                    }
                    out[neighbor] = 1;
                    queue.push(neighbor);
                };

                if has_left {
                    try_add(index - 1);
                }
                if has_right {
                    try_add(index + 1);
                }
                if has_up {
                    try_add(index - width);
                    if has_left {
                        try_add(index - width - 1);
                    }
                    if has_right {
                        try_add(index - width + 1);
                    }
                }
                if has_down {
                    try_add(index + width);
                    if has_left {
                        try_add(index + width - 1);
                    }
                    if has_right {
                        try_add(index + width + 1);
                    }
                }
            }
        }
    }

    // Phase 1 (Erosion): erode by dilating the inverse and then inverting.
    dilate_from_mask_value(&mask, &mut buffer, 0, width, height, radius, &mut queue);
    for i in 0..mask.len() {
        mask[i] = if buffer[i] == 0 { 1 } else { 0 };
    }

    // Phase 2 (Dilation): dilate eroded mask.
    dilate_from_mask_value(&mask, &mut buffer, 1, width, height, radius, &mut queue);
    buffer
}

fn fill_from_target_mask(
    target_mask: &mut [u8],
    fill_mask: &mut [u8],
    width: usize,
    height: usize,
    seed_index: usize,
) {
    if seed_index >= target_mask.len() {
        return;
    }
    let mut stack: Vec<usize> = vec![seed_index];
    while let Some(index) = stack.pop() {
        if index >= target_mask.len() {
            continue;
        }
        if target_mask[index] == 0 {
            continue;
        }
        target_mask[index] = 0;
        fill_mask[index] = 1;
        let x = index % width;
        let y = index / width;
        if x > 0 {
            let neighbor = index - 1;
            if target_mask[neighbor] == 1 {
                stack.push(neighbor);
            }
        }
        if x + 1 < width {
            let neighbor = index + 1;
            if target_mask[neighbor] == 1 {
                stack.push(neighbor);
            }
        }
        if y > 0 {
            let neighbor = index - width;
            if target_mask[neighbor] == 1 {
                stack.push(neighbor);
            }
        }
        if y + 1 < height {
            let neighbor = index + width;
            if target_mask[neighbor] == 1 {
                stack.push(neighbor);
            }
        }
    }
}

fn find_nearest_fillable_start_index(
    start_index: usize,
    fillable: &[u8],
    pixels: &[u32],
    base_color: u32,
    width: usize,
    height: usize,
    tolerance: u8,
    selection_mask: Option<&[u8]>,
    max_depth: usize,
) -> Option<usize> {
    if start_index >= fillable.len() {
        return None;
    }
    if fillable[start_index] == 1 {
        return Some(start_index);
    }

    let mut visited: Vec<u8> = vec![0; fillable.len()];
    visited[start_index] = 1;
    let mut queue: Vec<usize> = vec![start_index];
    let mut head: usize = 0;

    for _depth in 0..=max_depth {
        let level_end = queue.len();
        while head < level_end {
            let index = queue[head];
            head += 1;
            if fillable[index] == 1 {
                return Some(index);
            }
            let x = index % width;
            let y = index / width;

            let mut try_neighbor = |nx: isize, ny: isize| {
                if nx < 0 || ny < 0 {
                    return;
                }
                let nx = nx as usize;
                let ny = ny as usize;
                if nx >= width || ny >= height {
                    return;
                }
                let neighbor = ny * width + nx;
                if visited[neighbor] != 0 {
                    return;
                }
                visited[neighbor] = 1;
                if let Some(sel) = selection_mask {
                    if sel[neighbor] == 0 {
                        return;
                    }
                }
                if !colors_within_tolerance(pixels[neighbor], base_color, tolerance) {
                    return;
                }
                queue.push(neighbor);
            };

            try_neighbor(x as isize - 1, y as isize);
            try_neighbor(x as isize + 1, y as isize);
            try_neighbor(x as isize, y as isize - 1);
            try_neighbor(x as isize, y as isize + 1);
        }
        if head >= queue.len() {
            break;
        }
    }
    None
}

fn expand_mask_by_one(
    fill_mask: &mut [u8],
    width: usize,
    height: usize,
    selection_mask: Option<&[u8]>,
) {
    // Find current bounds.
    let mut min_x: i32 = width as i32;
    let mut min_y: i32 = height as i32;
    let mut max_x: i32 = -1;
    let mut max_y: i32 = -1;

    for i in 0..fill_mask.len() {
        if fill_mask[i] == 0 {
            continue;
        }
        let x = (i % width) as i32;
        let y = (i / width) as i32;
        if x < min_x {
            min_x = x;
        }
        if y < min_y {
            min_y = y;
        }
        if x > max_x {
            max_x = x;
        }
        if y > max_y {
            max_y = y;
        }
    }

    if max_x < min_x || max_y < min_y {
        return;
    }

    let expand_min_x = cmp::max(0, min_x - 1) as usize;
    let expand_max_x = cmp::min(width as i32 - 1, max_x + 1) as usize;
    let expand_min_y = cmp::max(0, min_y - 1) as usize;
    let expand_max_y = cmp::min(height as i32 - 1, max_y + 1) as usize;

    let mut expansion: Vec<usize> = Vec::new();
    for y in expand_min_y..=expand_max_y {
        let row_offset = y * width;
        for x in expand_min_x..=expand_max_x {
            let index = row_offset + x;
            if fill_mask[index] == 1 {
                continue;
            }
            if let Some(sel) = selection_mask {
                if sel[index] == 0 {
                    continue;
                }
            }
            let mut has_filled_neighbor = false;
            if x > 0 && fill_mask[index - 1] == 1 {
                has_filled_neighbor = true;
            } else if x + 1 < width && fill_mask[index + 1] == 1 {
                has_filled_neighbor = true;
            } else if y > 0 && fill_mask[index - width] == 1 {
                has_filled_neighbor = true;
            } else if y + 1 < height && fill_mask[index + width] == 1 {
                has_filled_neighbor = true;
            }
            if has_filled_neighbor {
                expansion.push(index);
            }
        }
    }

    for index in expansion {
        fill_mask[index] = 1;
    }
}

fn swallow_color_lines(
    pixels: &mut [u32],
    width: usize,
    height: usize,
    region_mask: &[u8],
    selection_mask: Option<&[u8]>,
    swallow_colors: &[u32],
    fill_color: u32,
    min_x: &mut i32,
    min_y: &mut i32,
    max_x: &mut i32,
    max_y: &mut i32,
) {
    if region_mask.is_empty() || swallow_colors.is_empty() || pixels.is_empty() {
        return;
    }
    let len = pixels.len().min(region_mask.len());
    let mut visited: Vec<u8> = vec![0; len];

    for index in 0..len {
        if region_mask[index] == 0 {
            continue;
        }
        let x = index % width;
        let y = index / width;

        let try_neighbor = |nx: isize, ny: isize| -> Option<usize> {
            if nx < 0 || ny < 0 {
                return None;
            }
            let nx = nx as usize;
            let ny = ny as usize;
            if nx >= width || ny >= height {
                return None;
            }
            let neighbor_index = ny * width + nx;
            if neighbor_index >= len {
                return None;
            }
            Some(neighbor_index)
        };

        for (nx, ny) in [
            (x as isize + 1, y as isize),
            (x as isize - 1, y as isize),
            (x as isize, y as isize + 1),
            (x as isize, y as isize - 1),
        ] {
            let Some(neighbor_index) = try_neighbor(nx, ny) else {
                continue;
            };
            if visited[neighbor_index] != 0 {
                continue;
            }
            let neighbor_color = pixels[neighbor_index];
            if neighbor_color == fill_color {
                continue;
            }
            if !swallow_colors.iter().any(|&c| c == neighbor_color) {
                continue;
            }
            flood_color_line(
                pixels,
                width,
                height,
                len,
                neighbor_index,
                neighbor_color,
                fill_color,
                selection_mask,
                &mut visited,
                min_x,
                min_y,
                max_x,
                max_y,
            );
        }
    }
}

fn flood_color_line(
    pixels: &mut [u32],
    width: usize,
    height: usize,
    len: usize,
    start_index: usize,
    target_color: u32,
    fill_color: u32,
    selection_mask: Option<&[u8]>,
    visited: &mut [u8],
    min_x: &mut i32,
    min_y: &mut i32,
    max_x: &mut i32,
    max_y: &mut i32,
) {
    if start_index >= len {
        return;
    }
    if visited[start_index] != 0 {
        return;
    }
    let mut stack: Vec<usize> = vec![start_index];
    visited[start_index] = 1;
    while let Some(index) = stack.pop() {
        if index >= len {
            continue;
        }
        if pixels[index] != target_color {
            continue;
        }
        if let Some(sel) = selection_mask {
            if sel.get(index).copied().unwrap_or(0) == 0 {
                continue;
            }
        }
        if pixels[index] == fill_color {
            continue;
        }
        pixels[index] = fill_color;

        let x = (index % width) as i32;
        let y = (index / width) as i32;
        if x < *min_x {
            *min_x = x;
        }
        if y < *min_y {
            *min_y = y;
        }
        if x > *max_x {
            *max_x = x;
        }
        if y > *max_y {
            *max_y = y;
        }

        let ux = x as usize;
        let uy = y as usize;
        if ux > 0 {
            let neighbor = index - 1;
            if visited[neighbor] == 0
                && selection_mask.map_or(true, |sel| sel[neighbor] != 0)
                && pixels[neighbor] == target_color
            {
                visited[neighbor] = 1;
                stack.push(neighbor);
            }
        }
        if ux + 1 < width {
            let neighbor = index + 1;
            if visited[neighbor] == 0
                && selection_mask.map_or(true, |sel| sel[neighbor] != 0)
                && pixels[neighbor] == target_color
            {
                visited[neighbor] = 1;
                stack.push(neighbor);
            }
        }
        if uy > 0 {
            let neighbor = index - width;
            if visited[neighbor] == 0
                && selection_mask.map_or(true, |sel| sel[neighbor] != 0)
                && pixels[neighbor] == target_color
            {
                visited[neighbor] = 1;
                stack.push(neighbor);
            }
        }
        if uy + 1 < height {
            let neighbor = index + width;
            if visited[neighbor] == 0
                && selection_mask.map_or(true, |sel| sel[neighbor] != 0)
                && pixels[neighbor] == target_color
            {
                visited[neighbor] = 1;
                stack.push(neighbor);
            }
        }
    }
}

fn apply_antialias_to_mask(
    pixels: &mut [u32],
    width: usize,
    height: usize,
    region_mask: &[u8],
    level: u8,
    min_x: &mut i32,
    min_y: &mut i32,
    max_x: &mut i32,
    max_y: &mut i32,
) {
    if pixels.is_empty() || region_mask.is_empty() || width == 0 || height == 0 || level == 0 {
        return;
    }

    let profile: &[f32] = match level {
        1 => &[0.35, 0.35],
        2 => &[0.45, 0.5, 0.5],
        3 => &[0.6, 0.65, 0.7, 0.75],
        _ => &[],
    };
    if profile.is_empty() {
        return;
    }

    let len = pixels.len().min(region_mask.len());
    let expanded_mask = expand_mask(region_mask, width, height, 1);
    let mut temp: Vec<u32> = vec![0; pixels.len()];

    let mut src_is_pixels = true;
    let mut any_change = false;

    for &factor in profile {
        if factor <= 0.0 {
            continue;
        }
        let changed = if src_is_pixels {
            run_masked_antialias_pass(
                pixels,
                temp.as_mut_slice(),
                &expanded_mask,
                width,
                height,
                factor,
                len,
                min_x,
                min_y,
                max_x,
                max_y,
            )
        } else {
            run_masked_antialias_pass(
                temp.as_slice(),
                pixels,
                &expanded_mask,
                width,
                height,
                factor,
                len,
                min_x,
                min_y,
                max_x,
                max_y,
            )
        };
        if !changed {
            continue;
        }
        any_change = true;
        src_is_pixels = !src_is_pixels;
    }

    if !any_change {
        return;
    }
    if !src_is_pixels {
        pixels.copy_from_slice(temp.as_slice());
    }
}

fn expand_mask(mask: &[u8], width: usize, height: usize, radius: usize) -> Vec<u8> {
    if mask.is_empty() || width == 0 || height == 0 || radius == 0 {
        return mask.to_vec();
    }
    let len = width.saturating_mul(height);
    let mut expanded: Vec<u8> = vec![0; len];
    let limit = len.min(mask.len());
    for y in 0..height {
        let row_offset = y * width;
        for x in 0..width {
            let index = row_offset + x;
            if index >= limit || mask[index] == 0 {
                continue;
            }
            let min_x = x.saturating_sub(radius);
            let max_x = cmp::min(width - 1, x + radius);
            let min_y = y.saturating_sub(radius);
            let max_y = cmp::min(height - 1, y + radius);
            for ny in min_y..=max_y {
                let nrow = ny * width;
                for nx in min_x..=max_x {
                    let nindex = nrow + nx;
                    if nindex < expanded.len() {
                        expanded[nindex] = 1;
                    }
                }
            }
        }
    }
    expanded
}

fn run_masked_antialias_pass(
    src: &[u32],
    dest: &mut [u32],
    mask: &[u8],
    width: usize,
    height: usize,
    blend_factor: f32,
    len: usize,
    min_x: &mut i32,
    min_y: &mut i32,
    max_x: &mut i32,
    max_y: &mut i32,
) -> bool {
    dest.copy_from_slice(src);
    if blend_factor <= 0.0 {
        return false;
    }
    let factor = blend_factor.clamp(0.0, 1.0);
    let mut modified = false;

    const CENTER_WEIGHT: i32 = 4;
    const DX: [i32; 8] = [-1, 0, 1, -1, 1, -1, 0, 1];
    const DY: [i32; 8] = [-1, -1, -1, 0, 0, 1, 1, 1];
    const WEIGHTS: [i32; 8] = [1, 2, 1, 2, 2, 1, 2, 1];

    for y in 0..height {
        let row_offset = y * width;
        for x in 0..width {
            let index = row_offset + x;
            if index >= len {
                continue;
            }
            if mask.get(index).copied().unwrap_or(0) == 0 {
                continue;
            }

            let center = src[index];
            let alpha = ((center >> 24) & 0xff) as i32;
            let center_r = ((center >> 16) & 0xff) as i32;
            let center_g = ((center >> 8) & 0xff) as i32;
            let center_b = (center & 0xff) as i32;

            let mut total_weight: i32 = CENTER_WEIGHT;
            let mut weighted_alpha: i32 = alpha * CENTER_WEIGHT;
            let mut weighted_premul_r: i32 = center_r * alpha * CENTER_WEIGHT;
            let mut weighted_premul_g: i32 = center_g * alpha * CENTER_WEIGHT;
            let mut weighted_premul_b: i32 = center_b * alpha * CENTER_WEIGHT;

            for i in 0..8 {
                let nx = x as i32 + DX[i];
                let ny = y as i32 + DY[i];
                if nx < 0 || ny < 0 {
                    continue;
                }
                let nx = nx as usize;
                let ny = ny as usize;
                if nx >= width || ny >= height {
                    continue;
                }
                let nindex = ny * width + nx;
                if nindex >= len {
                    continue;
                }
                let neighbor = src[nindex];
                let neighbor_alpha = ((neighbor >> 24) & 0xff) as i32;
                let weight = WEIGHTS[i];
                total_weight += weight;
                if neighbor_alpha == 0 {
                    continue;
                }
                weighted_alpha += neighbor_alpha * weight;
                weighted_premul_r += (((neighbor >> 16) & 0xff) as i32) * neighbor_alpha * weight;
                weighted_premul_g += (((neighbor >> 8) & 0xff) as i32) * neighbor_alpha * weight;
                weighted_premul_b += ((neighbor & 0xff) as i32) * neighbor_alpha * weight;
            }

            if total_weight <= 0 {
                continue;
            }

            let candidate_alpha: i32 = (weighted_alpha / total_weight).clamp(0, 255);
            let delta_alpha: i32 = candidate_alpha - alpha;
            if delta_alpha == 0 {
                continue;
            }
            let new_alpha: i32 =
                (alpha + ((delta_alpha as f32) * factor).round() as i32).clamp(0, 255);
            if new_alpha == alpha {
                continue;
            }

            let mut new_r = center_r;
            let mut new_g = center_g;
            let mut new_b = center_b;
            if delta_alpha > 0 {
                let bounded_weighted_alpha = cmp::max(weighted_alpha, 1);
                new_r = (weighted_premul_r / bounded_weighted_alpha).clamp(0, 255);
                new_g = (weighted_premul_g / bounded_weighted_alpha).clamp(0, 255);
                new_b = (weighted_premul_b / bounded_weighted_alpha).clamp(0, 255);
            }

            let new_color: u32 = ((new_alpha as u32) << 24)
                | ((new_r as u32) << 16)
                | ((new_g as u32) << 8)
                | (new_b as u32);
            if new_color != center {
                dest[index] = new_color;
                modified = true;
                let xi = x as i32;
                let yi = y as i32;
                if xi < *min_x {
                    *min_x = xi;
                }
                if yi < *min_y {
                    *min_y = yi;
                }
                if xi > *max_x {
                    *max_x = xi;
                }
                if yi > *max_y {
                    *max_y = yi;
                }
            }
        }
    }

    modified
}
