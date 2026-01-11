const DX: [i32; 4] = [1, 0, -1, 0];
const DY: [i32; 4] = [0, 1, 0, -1];
const TURN_OFFSETS: [u8; 4] = [1, 0, 3, 2];

const SENTINEL: u32 = u32::MAX;

#[flutter_rust_bridge::frb(sync)]
pub fn selection_path_vertices_from_mask(mask: Vec<u8>, width: i32) -> Vec<u32> {
    if width <= 0 || mask.is_empty() {
        return Vec::new();
    }
    let width_usize = width as usize;
    if width_usize == 0 {
        return Vec::new();
    }
    if mask.len() % width_usize != 0 {
        return Vec::new();
    }
    let height_usize = mask.len() / width_usize;
    if height_usize == 0 {
        return Vec::new();
    }

    let vertex_w = match width_usize.checked_add(1) {
        Some(v) => v,
        None => return Vec::new(),
    };
    let vertex_h = match height_usize.checked_add(1) {
        Some(v) => v,
        None => return Vec::new(),
    };
    let vertex_count = match vertex_w.checked_mul(vertex_h) {
        Some(v) => v,
        None => return Vec::new(),
    };

    let mut outgoing: Vec<u8> = vec![0; vertex_count];
    let mut edges: Vec<u64> = Vec::new();
    let mut has_coverage = false;

    #[inline]
    fn add_edge(outgoing: &mut [u8], edges: &mut Vec<u64>, vertex: usize, direction: u8) {
        let bit = 1u8 << direction;
        if outgoing[vertex] & bit != 0 {
            return;
        }
        outgoing[vertex] |= bit;
        edges.push(((vertex as u64) << 2) | (direction as u64));
    }

    for y in 0..height_usize {
        let row_offset = y * width_usize;
        for x in 0..width_usize {
            let index = row_offset + x;
            if mask[index] == 0 {
                continue;
            }
            has_coverage = true;

            if y == 0 || mask[index - width_usize] == 0 {
                // Top edge, moving right
                add_edge(&mut outgoing, &mut edges, y * vertex_w + x, 0);
            }
            if x + 1 == width_usize || mask[index + 1] == 0 {
                // Right edge, moving down
                add_edge(&mut outgoing, &mut edges, y * vertex_w + (x + 1), 1);
            }
            if y + 1 == height_usize || mask[index + width_usize] == 0 {
                // Bottom edge, moving left
                add_edge(&mut outgoing, &mut edges, (y + 1) * vertex_w + (x + 1), 2);
            }
            if x == 0 || mask[index - 1] == 0 {
                // Left edge, moving up
                add_edge(&mut outgoing, &mut edges, (y + 1) * vertex_w + x, 3);
            }
        }
    }

    if !has_coverage || edges.is_empty() {
        return Vec::new();
    }

    let total_edges = edges.len();
    let mut result: Vec<u32> = Vec::new();
    let mut consumed_edges: usize = 0;

    while let Some(encoded_edge) = edges.pop() {
        let direction = (encoded_edge & 3) as u8;
        let vertex = (encoded_edge >> 2) as usize;
        let bit = 1u8 << direction;
        if outgoing[vertex] & bit == 0 {
            continue;
        }

        outgoing[vertex] &= !bit;
        consumed_edges += 1;
        if consumed_edges > total_edges {
            return Vec::new();
        }

        let start_x = (vertex % vertex_w) as i32;
        let start_y = (vertex / vertex_w) as i32;
        result.push(start_x as u32);
        result.push(start_y as u32);

        let mut current_dir = direction;
        let mut cur_x = start_x + DX[current_dir as usize];
        let mut cur_y = start_y + DY[current_dir as usize];
        if cur_x < 0 || cur_y < 0 || cur_x >= vertex_w as i32 || cur_y >= vertex_h as i32 {
            return Vec::new();
        }

        while cur_x != start_x || cur_y != start_y {
            let cur_vertex = (cur_y as usize) * vertex_w + (cur_x as usize);
            let options = outgoing[cur_vertex];
            if options == 0 {
                return Vec::new();
            }

            let mut next_dir: Option<u8> = None;
            for offset in TURN_OFFSETS {
                let candidate = (current_dir + offset) & 3;
                if options & (1u8 << candidate) != 0 {
                    next_dir = Some(candidate);
                    break;
                }
            }
            let next_dir = match next_dir {
                Some(v) => v,
                None => return Vec::new(),
            };

            if next_dir != current_dir {
                result.push(cur_x as u32);
                result.push(cur_y as u32);
            }

            outgoing[cur_vertex] &= !(1u8 << next_dir);
            consumed_edges += 1;
            if consumed_edges > total_edges {
                return Vec::new();
            }

            cur_x += DX[next_dir as usize];
            cur_y += DY[next_dir as usize];
            if cur_x < 0 || cur_y < 0 || cur_x >= vertex_w as i32 || cur_y >= vertex_h as i32 {
                return Vec::new();
            }
            current_dir = next_dir;
        }

        result.push(SENTINEL);
        result.push(SENTINEL);
    }

    result
}
