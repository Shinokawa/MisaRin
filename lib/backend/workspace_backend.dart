import '../src/rust/api/workspace.dart' as rust_workspace;

typedef WorkspaceState = rust_workspace.WorkspaceState;
typedef WorkspaceEntry = rust_workspace.WorkspaceEntry;

WorkspaceState openWorkspace({
  required WorkspaceEntry entry,
  required bool activate,
}) {
  return rust_workspace.workspaceOpen(entry: entry, activate: activate);
}

WorkspaceState markWorkspaceDirty({
  required String id,
  required bool isDirty,
}) {
  return rust_workspace.workspaceMarkDirty(id: id, isDirty: isDirty);
}

WorkspaceState setWorkspaceActive({required String id}) {
  return rust_workspace.workspaceSetActive(id: id);
}

WorkspaceEntry? workspaceNeighbor({required String id}) {
  return rust_workspace.workspaceNeighbor(id: id);
}

WorkspaceState removeWorkspace({
  required String id,
  String? activateAfter,
}) {
  return rust_workspace.workspaceRemove(id: id, activateAfter: activateAfter);
}

WorkspaceState resetWorkspace() {
  return rust_workspace.workspaceReset();
}

WorkspaceState reorderWorkspace({
  required int oldIndex,
  required int newIndex,
}) {
  return rust_workspace.workspaceReorder(
    oldIndex: oldIndex,
    newIndex: newIndex,
  );
}

WorkspaceState workspaceState() {
  return rust_workspace.workspaceState();
}
