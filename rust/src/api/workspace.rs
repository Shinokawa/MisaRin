use std::sync::{Mutex, OnceLock};

#[flutter_rust_bridge::frb]
#[derive(Clone, Debug, Default)]
pub struct WorkspaceEntry {
    pub id: String,
    pub name: String,
    pub is_dirty: bool,
}

#[flutter_rust_bridge::frb]
#[derive(Clone, Debug, Default)]
pub struct WorkspaceState {
    pub entries: Vec<WorkspaceEntry>,
    pub active_id: Option<String>,
}

static WORKSPACE: OnceLock<Mutex<WorkspaceState>> = OnceLock::new();

fn workspace_cell() -> &'static Mutex<WorkspaceState> {
    WORKSPACE.get_or_init(|| Mutex::new(WorkspaceState::default()))
}

fn snapshot<F>(apply: F) -> WorkspaceState
where
    F: FnOnce(&mut WorkspaceState),
{
    let cell = workspace_cell();
    let mut guard = cell.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
    apply(&mut guard);
    guard.clone()
}

#[flutter_rust_bridge::frb(sync)]
pub fn workspace_state() -> WorkspaceState {
    snapshot(|_| {})
}

#[flutter_rust_bridge::frb(sync)]
pub fn workspace_reset() -> WorkspaceState {
    snapshot(|state| {
        state.entries.clear();
        state.active_id = None;
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn workspace_open(entry: WorkspaceEntry, activate: bool) -> WorkspaceState {
    snapshot(|state| {
        if let Some(existing) = state.entries.iter_mut().find(|it| it.id == entry.id) {
            existing.name = entry.name.clone();
        } else {
            state.entries.push(entry.clone());
        }
        if activate {
            state.active_id = Some(entry.id.clone());
        }
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn workspace_mark_dirty(id: String, is_dirty: bool) -> WorkspaceState {
    snapshot(|state| {
        if let Some(entry) = state.entries.iter_mut().find(|it| it.id == id) {
            entry.is_dirty = is_dirty;
        }
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn workspace_set_active(id: String) -> WorkspaceState {
    snapshot(|state| {
        if state.entries.iter().any(|entry| entry.id == id) {
            state.active_id = Some(id);
        }
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn workspace_neighbor(id: String) -> Option<WorkspaceEntry> {
    let cell = workspace_cell();
    let guard = cell.lock().ok()?;
    let entries = &guard.entries;
    if entries.len() <= 1 {
        return None;
    }
    if let Some(index) = entries.iter().position(|entry| entry.id == id) {
        if index > 0 {
            return entries.get(index - 1).cloned();
        }
        if index + 1 < entries.len() {
            return entries.get(index + 1).cloned();
        }
        return None;
    }
    entries.last().cloned()
}

#[flutter_rust_bridge::frb(sync)]
pub fn workspace_remove(id: String, activate_after: Option<String>) -> WorkspaceState {
    snapshot(|state| {
        let Some(index) = state.entries.iter().position(|entry| entry.id == id) else {
            return;
        };
        state.entries.remove(index);
        if let Some(target) = activate_after {
            if state.entries.iter().any(|entry| entry.id == target) {
                state.active_id = Some(target);
                return;
            }
        }
        if state.active_id.as_deref() == Some(id.as_str()) {
            state.active_id = state.entries.last().map(|entry| entry.id.clone());
        }
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn workspace_reorder(old_index: i32, new_index: i32) -> WorkspaceState {
    snapshot(|state| {
        let len = state.entries.len();
        if len <= 1 {
            return;
        }
        if old_index < 0 || old_index as usize >= len {
            return;
        }
        let mut next_index = new_index;
        if next_index < 0 {
            next_index = 0;
        }
        if next_index as usize > len {
            next_index = len as i32;
        }
        if next_index > old_index {
            next_index -= 1;
        }
        if next_index == old_index {
            return;
        }
        let old = old_index as usize;
        let new_pos = next_index as usize;
        let entry = state.entries.remove(old);
        state.entries.insert(new_pos, entry);
    })
}
