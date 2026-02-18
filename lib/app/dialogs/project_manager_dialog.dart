import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

import '../l10n/l10n.dart';
import '../project/project_repository.dart';
import '../utils/file_manager.dart';
import '../widgets/project_preview_thumbnail.dart';
import 'misarin_dialog.dart';

Future<void> showProjectManagerDialog(BuildContext context) {
  final l10n = context.l10n;
  return showMisarinDialog<void>(
    context: context,
    title: Text(l10n.projectManagerTitle),
    content: const _ProjectManagerContent(),
    contentWidth: null,
    maxWidth: 980,
    actions: [
      Button(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.close),
      ),
    ],
  );
}

class _ProjectManagerContent extends StatefulWidget {
  const _ProjectManagerContent();

  @override
  State<_ProjectManagerContent> createState() => _ProjectManagerContentState();
}

class _ProjectManagerContentState extends State<_ProjectManagerContent> {
  final List<StoredProjectInfo> _projects = <StoredProjectInfo>[];
  final Set<String> _selected = <String>{};

  StreamSubscription<StoredProjectInfo>? _subscription;

  bool _selectAll = false;
  bool _deleting = false;
  bool _revealing = false;
  bool _loading = true;
  String? _errorMessage;
  String? _focusedPath;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _subscribe() {
    _subscription?.cancel();
    setState(() {
      _projects.clear();
      _selected.clear();
      _selectAll = false;
      _deleting = false;
      _revealing = false;
      _loading = true;
      _errorMessage = null;
      _focusedPath = null;
    });
    final Stream<StoredProjectInfo> stream = ProjectRepository.instance
        .streamStoredProjects();
    _subscription = stream.listen(
      (StoredProjectInfo info) {
        if (!mounted) {
          return;
        }
        setState(() {
          final int insertIndex = _projects.indexWhere(
            (existing) => existing.lastModified.isBefore(info.lastModified),
          );
          if (insertIndex < 0) {
            _projects.add(info);
          } else {
            _projects.insert(insertIndex, info);
          }
          _focusedPath ??= info.path;
          if (_selectAll) {
            _selected.add(info.path);
          }
        });
      },
      onError: (Object error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _errorMessage = context.l10n.loadFailed(error);
          _loading = false;
        });
      },
      onDone: () {
        if (!mounted) {
          return;
        }
        setState(() {
          _loading = false;
        });
      },
      cancelOnError: true,
    );
  }

  void _toggleSelectAll(bool value) {
    setState(() {
      _selectAll = value;
      _selected.clear();
      if (_selectAll) {
        _selected.addAll(_projects.map((p) => p.path));
        if (_projects.isNotEmpty) {
          _focusedPath = _projects.first.path;
        }
      }
    });
  }

  void _toggleSelection(String path, bool value) {
    setState(() {
      if (value) {
        _selected.add(path);
      } else {
        _selected.remove(path);
      }
      _selectAll = _projects.isNotEmpty && _selected.length == _projects.length;
      _focusedPath = path;
    });
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) {
      return;
    }
    setState(() {
      _deleting = true;
      _errorMessage = null;
    });
    final List<String> targets = List<String>.from(_selected);
    try {
      for (final String path in targets) {
        await ProjectRepository.instance.deleteProject(path);
      }
    } catch (error) {
      if (mounted) {
        _errorMessage = context.l10n.deleteFailed(error);
      }
    }
    if (!mounted) {
      return;
    }
    _subscribe();
  }

  Future<void> _revealSelected() async {
    if (_selected.isEmpty || _revealing) {
      return;
    }
    final String? target = _firstSelectedPath();
    if (target == null) {
      return;
    }
    await _revealPath(target);
  }

  Future<void> _revealPath(String path) async {
    if (_revealing) {
      return;
    }
    setState(() {
      _revealing = true;
    });
    try {
      await revealInFileManager(path);
    } finally {
      if (mounted) {
        setState(() {
          _revealing = false;
        });
      }
    }
  }

  String? _firstSelectedPath() {
    for (final StoredProjectInfo info in _projects) {
      if (_selected.contains(info.path)) {
        return info.path;
      }
    }
    return _selected.isEmpty ? null : _selected.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final l10n = context.l10n;
    final bool hasSelection = _selected.isNotEmpty;
    final int totalSelected = _selected.length;
    final int totalCount = _projects.length;
    final StoredProjectInfo? focusedInfo = _resolveFocusedProject();

    if (_projects.isEmpty) {
      if (_loading) {
        return const SizedBox(
          height: 420,
          child: Center(child: ProgressRing()),
        );
      }
      return SizedBox(
        height: 420,
        child: Center(
          child: Text(
            _errorMessage ?? l10n.noAutosavedProjects,
            style: theme.typography.bodyLarge,
          ),
        ),
      );
    }

    return SizedBox(
      height: 520,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      checked: _selectAll,
                      onChanged: (value) => _toggleSelectAll(value ?? false),
                    ),
                    Text(l10n.selectAll, style: theme.typography.bodyStrong),
                    const Spacer(),
                    Tooltip(
                      message: l10n.revealProjectLocation,
                      child: Button(
                        onPressed: !_revealing && hasSelection
                            ? () => _revealSelected()
                            : null,
                        child: _revealing
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child: ProgressRing(strokeWidth: 2.0),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(FluentIcons.open_file),
                                  const SizedBox(width: 6),
                                  Text(l10n.openFolder),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: l10n.deleteSelectedProjects,
                      child: FilledButton(
                        onPressed:
                            !_deleting && hasSelection ? _deleteSelected : null,
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.isDisabled ? null : Colors.red,
                          ),
                        ),
                        child: _deleting
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child: ProgressRing(strokeWidth: 2.0),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(FluentIcons.delete),
                                  const SizedBox(width: 6),
                                  Text(l10n.deleteSelected(totalSelected)),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  InfoBar(
                    severity: InfoBarSeverity.error,
                    title: Text(_errorMessage!),
                    action: IconButton(
                      icon: const Icon(FluentIcons.clear),
                      onPressed: () => setState(() => _errorMessage = null),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.resources.subtleFillColorTertiary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.resources.controlStrokeColorDefault,
                      ),
                    ),
                    child: Stack(
                      children: [
                        ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemBuilder: (context, index) {
                            final StoredProjectInfo info = _projects[index];
                            final bool selected = _selected.contains(info.path);
                            final bool isFocused =
                                focusedInfo?.path == info.path;
                            return ListTile.selectable(
                              key: ValueKey(info.path),
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    checked: selected,
                                    onChanged: (value) => _toggleSelection(
                                        info.path, value ?? false),
                                  ),
                                  const SizedBox(width: 12),
                                  ProjectPreviewThumbnail(
                                    bytes: info.summary?.previewBytes,
                                    width: 96,
                                    height: 72,
                                  ),
                                ],
                              ),
                              onPressed: () =>
                                  _toggleSelection(info.path, !selected),
                              title: Text(
                                info.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    info.fileName,
                                    style: theme.typography.caption,
                                  ),
                                  Text(
                                    l10n.projectFileInfo(
                                        _formatFileSize(info.fileSize),
                                        _formatDate(info.lastModified)),
                                    style: theme.typography.caption,
                                  ),
                                  if (info.summary != null)
                                    Text(
                                      l10n.projectCanvasInfo(
                                          info.summary!.settings.width.toInt(),
                                          info.summary!.settings.height.toInt()),
                                      style: theme.typography.caption,
                                    ),
                                ],
                              ),
                              selected: selected || isFocused,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              tileColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.isHovered || selected || isFocused
                                        ? theme.resources
                                            .subtleFillColorSecondary
                                        : theme.resources
                                            .subtleFillColorTertiary,
                              ),
                            );
                          },
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemCount: totalCount,
                        ),
                        if (_loading)
                          const Positioned(
                            right: 12,
                            top: 12,
                            child: ProgressRing(strokeWidth: 2.5),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: _ProjectManagerDetails(
              info: focusedInfo,
              selectedCount: totalSelected,
              hasSelection: hasSelection,
              deleting: _deleting,
              onReveal: focusedInfo == null
                  ? null
                  : () => unawaited(_revealPath(focusedInfo.path)),
              onDeleteSelected:
                  !_deleting && hasSelection ? _deleteSelected : null,
            ),
          ),
        ],
      ),
    );
  }

  StoredProjectInfo? _resolveFocusedProject() {
    final String? path = _focusedPath;
    if (path != null) {
      for (final StoredProjectInfo info in _projects) {
        if (info.path == path) {
          return info;
        }
      }
    }
    if (_selected.isNotEmpty) {
      final String selectedPath = _selected.first;
      for (final StoredProjectInfo info in _projects) {
        if (info.path == selectedPath) {
          return info;
        }
      }
    }
    if (_projects.isEmpty) {
      return null;
    }
    return _projects.first;
  }
}

class _ProjectManagerDetails extends StatelessWidget {
  const _ProjectManagerDetails({
    required this.info,
    required this.selectedCount,
    required this.hasSelection,
    required this.deleting,
    required this.onReveal,
    required this.onDeleteSelected,
  });

  final StoredProjectInfo? info;
  final int selectedCount;
  final bool hasSelection;
  final bool deleting;
  final VoidCallback? onReveal;
  final VoidCallback? onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final l10n = context.l10n;
    final StoredProjectInfo? data = info;
    return Container(
      decoration: BoxDecoration(
        color: theme.resources.subtleFillColorTertiary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.resources.controlStrokeColorDefault,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: data == null
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.displayName,
                    style: theme.typography.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ProjectPreviewThumbnail(
                      bytes: data.summary?.previewBytes,
                      width: 240,
                      height: 180,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data.fileName,
                    style: theme.typography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    l10n.projectFileInfo(
                      _formatFileSize(data.fileSize),
                      _formatDate(data.lastModified),
                    ),
                    style: theme.typography.caption,
                  ),
                  if (data.summary != null)
                    Text(
                      l10n.projectCanvasInfo(
                        data.summary!.settings.width.toInt(),
                        data.summary!.settings.height.toInt(),
                      ),
                      style: theme.typography.caption,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    data.path,
                    style: theme.typography.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Button(
                          onPressed: onReveal,
                          child: Text(l10n.openFolder),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: onDeleteSelected,
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith(
                              (states) => states.isDisabled ? null : Colors.red,
                            ),
                          ),
                          child: deleting
                              ? const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: ProgressRing(strokeWidth: 2.0),
                                )
                              : Text(l10n.deleteSelected(selectedCount)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

String _formatFileSize(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const List<String> units = ['B', 'KB', 'MB', 'GB'];
  double value = bytes.toDouble();
  int unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  return '${value.toStringAsFixed(value >= 10 || value < 1 ? 1 : 2)} ${units[unitIndex]}';
}

String _formatDate(DateTime dateTime) {
  final DateTime local = dateTime.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
