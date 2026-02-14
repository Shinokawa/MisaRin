import 'dart:collection';

import 'package:flutter/widgets.dart';

import '../project/project_document.dart';
import '../../src/rust/api/workspace.dart' as workspace_backend;

class CanvasWorkspaceEntry {
  CanvasWorkspaceEntry({required this.document, this.isDirty = false});

  ProjectDocument document;
  bool isDirty;

  String get id => document.id;
  String get name => document.name;

  CanvasWorkspaceEntry copyWith({ProjectDocument? document, bool? isDirty}) {
    return CanvasWorkspaceEntry(
      document: document ?? this.document,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}

class CanvasWorkspaceController extends ChangeNotifier {
  CanvasWorkspaceController._() {
    _restoreFromBackend();
  }

  static final CanvasWorkspaceController instance =
      CanvasWorkspaceController._();

  final List<CanvasWorkspaceEntry> _entries = <CanvasWorkspaceEntry>[];
  String? _activeId;
  bool _notifyScheduled = false;

  UnmodifiableListView<CanvasWorkspaceEntry> get entries =>
      UnmodifiableListView<CanvasWorkspaceEntry>(_entries);

  String? get activeId => _activeId;

  CanvasWorkspaceEntry? entryById(String id) {
    for (final CanvasWorkspaceEntry entry in _entries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  void open(ProjectDocument document, {bool activate = true}) {
    final CanvasWorkspaceEntry? existing = entryById(document.id);
    final bool isDirty = existing?.isDirty ?? false;
    final workspace_backend.WorkspaceState state = workspace_backend.workspaceOpen(
      entry: workspace_backend.WorkspaceEntry(
        id: document.id,
        name: document.name,
        isDirty: isDirty,
      ),
      activate: activate,
    );
    _applyBackendState(state, documentOverride: document);
  }

  void updateDocument(ProjectDocument document) {
    open(document, activate: _activeId == document.id);
  }

  void markDirty(String id, bool isDirty) {
    final CanvasWorkspaceEntry? current = entryById(id);
    if (current == null || current.isDirty == isDirty) {
      return;
    }
    final workspace_backend.WorkspaceState state = workspace_backend.workspaceMarkDirty(
      id: id,
      isDirty: isDirty,
    );
    _applyBackendState(state);
  }

  void setActive(String id) {
    if (_activeId == id) {
      return;
    }
    if (entryById(id) == null) {
      return;
    }
    final workspace_backend.WorkspaceState state = workspace_backend.workspaceSetActive(id: id);
    _applyBackendState(state);
  }

  CanvasWorkspaceEntry? neighborFor(String id) {
    workspace_backend.WorkspaceEntry? neighbor;
    try {
      neighbor = workspace_backend.workspaceNeighbor(id: id);
    } catch (_) {
      neighbor = null;
    }
    if (neighbor == null) {
      return null;
    }
    final CanvasWorkspaceEntry? existing = entryById(neighbor.id);
    if (existing == null) {
      return null;
    }
    if (existing.isDirty == neighbor.isDirty && existing.name == neighbor.name) {
      return existing;
    }
    final ProjectDocument document = existing.name == neighbor.name
        ? existing.document
        : existing.document.copyWith(name: neighbor.name);
    return CanvasWorkspaceEntry(
      document: document,
      isDirty: neighbor.isDirty,
    );
  }

  void remove(String id, {String? activateAfter}) {
    if (entryById(id) == null) {
      return;
    }
    final workspace_backend.WorkspaceState state = workspace_backend.workspaceRemove(
      id: id,
      activateAfter: activateAfter,
    );
    _applyBackendState(state);
  }

  void reset() {
    final workspace_backend.WorkspaceState state = workspace_backend.workspaceReset();
    _applyBackendState(state);
  }

  void reorder(int oldIndex, int newIndex) {
    if (_entries.length <= 1) {
      return;
    }
    if (oldIndex < 0 || oldIndex >= _entries.length) {
      return;
    }
    final workspace_backend.WorkspaceState state = workspace_backend.workspaceReorder(
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
    _applyBackendState(state);
  }

  void _restoreFromBackend() {
    try {
      final workspace_backend.WorkspaceState state = workspace_backend.workspaceState();
      _applyBackendState(state);
    } catch (_) {
      _entries.clear();
      _activeId = null;
    }
  }

  void _applyBackendState(
    workspace_backend.WorkspaceState state, {
    ProjectDocument? documentOverride,
  }) {
    final Map<String, CanvasWorkspaceEntry> cache =
        <String, CanvasWorkspaceEntry>{
      for (final CanvasWorkspaceEntry entry in _entries) entry.id: entry,
    };

    if (documentOverride != null) {
      final bool isDirty = cache[documentOverride.id]?.isDirty ?? false;
      cache[documentOverride.id] = CanvasWorkspaceEntry(
        document: documentOverride,
        isDirty: isDirty,
      );
    }

    final List<CanvasWorkspaceEntry> nextEntries = <CanvasWorkspaceEntry>[];
    for (final workspace_backend.WorkspaceEntry entry in state.entries) {
      final CanvasWorkspaceEntry? current = cache[entry.id];
      if (current == null) {
        continue;
      }
      final ProjectDocument document = current.name == entry.name
          ? current.document
          : current.document.copyWith(name: entry.name);
      nextEntries.add(
        CanvasWorkspaceEntry(
          document: document,
          isDirty: entry.isDirty,
        ),
      );
    }

    bool sameEntries = nextEntries.length == _entries.length;
    if (sameEntries) {
      for (int i = 0; i < nextEntries.length; i++) {
        final CanvasWorkspaceEntry next = nextEntries[i];
        final CanvasWorkspaceEntry current = _entries[i];
        if (next.id != current.id ||
            next.name != current.name ||
            next.isDirty != current.isDirty ||
            next.document != current.document) {
          sameEntries = false;
          break;
        }
      }
    }

    if (sameEntries && _activeId == state.activeId) {
      return;
    }

    _entries
      ..clear()
      ..addAll(nextEntries);
    _activeId = state.activeId;
    _scheduleNotify();
  }

  void _scheduleNotify() {
    final WidgetsBinding binding = WidgetsBinding.instance;
    if (_notifyScheduled) {
      return;
    }
    _notifyScheduled = true;
    binding.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
  }
}
