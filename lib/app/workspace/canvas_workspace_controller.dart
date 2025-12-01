import 'dart:collection';

import 'package:flutter/widgets.dart';

import '../project/project_document.dart';

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
  CanvasWorkspaceController._();

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
    final int index = _entries.indexWhere((entry) => entry.id == document.id);
    if (index >= 0) {
      _entries[index].document = document;
    } else {
      _entries.add(CanvasWorkspaceEntry(document: document));
    }
    if (activate) {
      _activeId = document.id;
    }
    _scheduleNotify();
  }

  void updateDocument(ProjectDocument document) {
    open(document, activate: _activeId == document.id);
  }

  void markDirty(String id, bool isDirty) {
    final int index = _entries.indexWhere((entry) => entry.id == id);
    if (index < 0) {
      return;
    }
    if (_entries[index].isDirty == isDirty) {
      return;
    }
    _entries[index].isDirty = isDirty;
    _scheduleNotify();
  }

  void setActive(String id) {
    if (_activeId == id) {
      return;
    }
    if (_entries.any((entry) => entry.id == id)) {
      _activeId = id;
      _scheduleNotify();
    }
  }

  CanvasWorkspaceEntry? neighborFor(String id) {
    if (_entries.length <= 1) {
      return null;
    }
    final int index = _entries.indexWhere((entry) => entry.id == id);
    if (index < 0) {
      return _entries.isNotEmpty ? _entries.last : null;
    }
    if (index > 0) {
      return _entries[index - 1];
    }
    if (index + 1 < _entries.length) {
      return _entries[index + 1];
    }
    return null;
  }

  void remove(String id, {String? activateAfter}) {
    final int index = _entries.indexWhere((entry) => entry.id == id);
    if (index < 0) {
      return;
    }
    _entries.removeAt(index);
    if (activateAfter != null &&
        _entries.any((entry) => entry.id == activateAfter)) {
      _activeId = activateAfter;
    } else if (_activeId == id) {
      _activeId = _entries.isNotEmpty ? _entries.last.id : null;
    }
    _scheduleNotify();
  }

  void reset() {
    _entries.clear();
    _activeId = null;
    _scheduleNotify();
  }

  void reorder(int oldIndex, int newIndex) {
    if (_entries.length <= 1) {
      return;
    }
    if (oldIndex < 0 || oldIndex >= _entries.length) {
      return;
    }
    if (newIndex < 0) {
      newIndex = 0;
    }
    if (newIndex > _entries.length) {
      newIndex = _entries.length;
    }
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) {
      return;
    }
    final CanvasWorkspaceEntry entry = _entries.removeAt(oldIndex);
    _entries.insert(newIndex, entry);
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
