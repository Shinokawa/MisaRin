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

pub fn flood_fill_patch(
    width: i32,
    height: i32,
    mut pixels: Vec<u32>,
    start_x: i32,
    start_y: i32,
    color_value: u32,
    target_color_value: Option<u32>,
    contiguous: bool,
    tolerance: i32,
    fill_gap: i32,
    selection_mask: Option<Vec<u8>>,
) -> FloodFillPatch {
    if width <= 0 || height <= 0 {
        return FloodFillPatch::empty();
    }
    let width_usize = width as usize;
    let height_usize = height as usize;
    let len = width_usize.saturating_mul(height_usize);
    if pixels.len() != len {
        return FloodFillPatch::empty();
    }
    if start_x < 0 || start_y < 0 || start_x >= width || start_y >= height {
        return FloodFillPatch::empty();
    }

    let start_index = (start_y as usize) * width_usize + (start_x as usize);
    let base_color = target_color_value.unwrap_or(pixels[start_index]);
    let replacement = color_value;
    if base_color == replacement {
        return FloodFillPatch::empty();
    }

    let selection_mask = selection_mask
        .filter(|mask| mask.len() == len)
        .map(|mask| mask);

    let tol = tolerance.clamp(0, 255) as u8;
    let gap = fill_gap.clamp(0, 64) as u8;

    let mut changed_min_x: i32 = width;
    let mut changed_min_y: i32 = height;
    let mut changed_max_x: i32 = -1;
    let mut changed_max_y: i32 = -1;

    if !contiguous {
        for i in 0..len {
            if !colors_within_tolerance(pixels[i], base_color, tol) {
                continue;
            }
            if let Some(mask) = &selection_mask {
                if mask[i] == 0 {
                    continue;
                }
            }
            if pixels[i] == replacement {
                continue;
            }
            pixels[i] = replacement;
            let x = (i % width_usize) as i32;
            let y = (i / width_usize) as i32;
            if x < changed_min_x {
                changed_min_x = x;
            }
            if y < changed_min_y {
                changed_min_y = y;
            }
            if x > changed_max_x {
                changed_max_x = x;
            }
            if y > changed_max_y {
                changed_max_y = y;
            }
        }

        return export_patch(
            width_usize,
            &pixels,
            changed_min_x,
            changed_min_y,
            changed_max_x,
            changed_max_y,
        );
    }

    if let Some(mask) = &selection_mask {
        if mask[start_index] == 0 {
            return FloodFillPatch::empty();
        }
    }

    let mut fill_mask: Vec<u8> = vec![0; len];

    if gap > 0 {
        let mut target_mask: Vec<u8> = vec![0; len];
        for i in 0..len {
            if let Some(mask) = &selection_mask {
                if mask[i] == 0 {
                    continue;
                }
            }
            if colors_within_tolerance(pixels[i], base_color, tol) {
                target_mask[i] = 1;
            }
        }
        if target_mask[start_index] == 0 {
            return FloodFillPatch::empty();
        }

        // "Fill gap" should only prevent leaking through small openings.
        // We follow the existing Dart worker implementation:
        // 1) Open the target mask, 2) Find outside region in opened mask, 3) Reconstruct inside.
        let opened_target = open_mask8(target_mask.clone(), width_usize, height_usize, gap);

        let mut outside_seeds: Vec<usize> = Vec::new();
        for x in 0..width_usize {
            let top_index = x;
            if opened_target.get(top_index) == Some(&1) {
                outside_seeds.push(top_index);
            }
            let bottom_index = (height_usize - 1) * width_usize + x;
            if opened_target.get(bottom_index) == Some(&1) {
                outside_seeds.push(bottom_index);
            }
        }
        for y in 1..height_usize.saturating_sub(1) {
            let left_index = y * width_usize;
            if opened_target.get(left_index) == Some(&1) {
                outside_seeds.push(left_index);
            }
            let right_index = y * width_usize + (width_usize - 1);
            if opened_target.get(right_index) == Some(&1) {
                outside_seeds.push(right_index);
            }
        }

        if outside_seeds.is_empty() {
            fill_from_target_mask(
                &mut target_mask,
                &mut fill_mask,
                width_usize,
                height_usize,
                start_index,
            );
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
                let x = index % width_usize;
                let y = index / width_usize;
                if x > 0 {
                    let neighbor = index - 1;
                    if outside_open[neighbor] == 0 && opened_target[neighbor] == 1 {
                        outside_open[neighbor] = 1;
                        outside_queue.push(neighbor);
                    }
                }
                if x + 1 < width_usize {
                    let neighbor = index + 1;
                    if outside_open[neighbor] == 0 && opened_target[neighbor] == 1 {
                        outside_open[neighbor] = 1;
                        outside_queue.push(neighbor);
                    }
                }
                if y > 0 {
                    let neighbor = index - width_usize;
                    if outside_open[neighbor] == 0 && opened_target[neighbor] == 1 {
                        outside_open[neighbor] = 1;
                        outside_queue.push(neighbor);
                    }
                }
                if y + 1 < height_usize {
                    let neighbor = index + width_usize;
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
                    &pixels,
                    base_color,
                    width_usize,
                    height_usize,
                    tol,
                    selection_mask.as_deref(),
                    gap as usize + 1,
                );
                if snapped.is_none() {
                    fill_from_target_mask(
                        &mut target_mask,
                        &mut fill_mask,
                        width_usize,
                        height_usize,
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
                    let x = index % width_usize;
                    let y = index / width_usize;
                    if x > 0 {
                        let neighbor = index - 1;
                        if seed_visited[neighbor] == 0 && opened_target[neighbor] == 1 {
                            seed_visited[neighbor] = 1;
                            seed_queue.push(neighbor);
                        }
                    }
                    if x + 1 < width_usize {
                        let neighbor = index + 1;
                        if seed_visited[neighbor] == 0 && opened_target[neighbor] == 1 {
                            seed_visited[neighbor] = 1;
                            seed_queue.push(neighbor);
                        }
                    }
                    if y > 0 {
                        let neighbor = index - width_usize;
                        if seed_visited[neighbor] == 0 && opened_target[neighbor] == 1 {
                            seed_visited[neighbor] = 1;
                            seed_queue.push(neighbor);
                        }
                    }
                    if y + 1 < height_usize {
                        let neighbor = index + width_usize;
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
                        width_usize,
                        height_usize,
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
                        let x = index % width_usize;
                        let y = index / width_usize;
                        if x > 0 {
                            let neighbor = index - 1;
                            if target_mask[neighbor] == 1 && outside_open[neighbor] == 0 {
                                target_mask[neighbor] = 0;
                                fill_mask[neighbor] = 1;
                                queue.push(neighbor);
                            }
                        }
                        if x + 1 < width_usize {
                            let neighbor = index + 1;
                            if target_mask[neighbor] == 1 && outside_open[neighbor] == 0 {
                                target_mask[neighbor] = 0;
                                fill_mask[neighbor] = 1;
                                queue.push(neighbor);
                            }
                        }
                        if y > 0 {
                            let neighbor = index - width_usize;
                            if target_mask[neighbor] == 1 && outside_open[neighbor] == 0 {
                                target_mask[neighbor] = 0;
                                fill_mask[neighbor] = 1;
                                queue.push(neighbor);
                            }
                        }
                        if y + 1 < height_usize {
                            let neighbor = index + width_usize;
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
            if !colors_within_tolerance(pixels[index], base_color, tol) {
                continue;
            }
            if let Some(mask) = &selection_mask {
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

        // Expand mask by 1 pixel (dilation) to cover AA edges when tolerance > 0.
        if tol > 0 {
            expand_mask_by_one(
                &mut fill_mask,
                width_usize,
                height_usize,
                selection_mask.as_deref(),
            );
        }
    }

    // Apply fill and compute changed bounds.
    for y in 0..height_usize {
        let row_offset = y * width_usize;
        for x in 0..width_usize {
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

    export_patch(
        width_usize,
        &pixels,
        changed_min_x,
        changed_min_y,
        changed_max_x,
        changed_max_y,
    )
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

fn open_mask8(mut mask: Vec<u8>, width: usize, height: usize, radius: u8) -> Vec<u8> {
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

