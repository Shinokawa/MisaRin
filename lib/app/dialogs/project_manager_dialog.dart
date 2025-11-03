import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

import '../project/project_repository.dart';
import 'misarin_dialog.dart';

Future<void> showProjectManagerDialog(BuildContext context) {
  return showMisarinDialog<void>(
    context: context,
    title: const Text('项目管理'),
    content: const _ProjectManagerContent(),
    contentWidth: 540,
    maxWidth: 640,
    actions: [
      Button(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('关闭'),
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
  late Future<List<StoredProjectInfo>> _projectsFuture;
  final Set<String> _selected = <String>{};
  bool _selectAll = false;
  bool _deleting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _projectsFuture = _loadProjects();
  }

  Future<List<StoredProjectInfo>> _loadProjects() {
    return ProjectRepository.instance.listStoredProjects();
  }

  void _toggleSelectAll(List<StoredProjectInfo> projects, bool value) {
    setState(() {
      _selectAll = value;
      _selected.clear();
      if (value) {
        _selected.addAll(projects.map((p) => p.path));
      }
    });
  }

  void _toggleSelection(String path, bool value, int totalCount) {
    setState(() {
      if (value) {
        _selected.add(path);
      } else {
        _selected.remove(path);
      }
      _selectAll = totalCount > 0 && _selected.length == totalCount;
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
      _errorMessage = '删除失败：$error';
    }
    setState(() {
      _projectsFuture = _loadProjects();
      _selected.clear();
      _selectAll = false;
      _deleting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return FutureBuilder<List<StoredProjectInfo>>(
      future: _projectsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 320,
            child: Center(child: ProgressRing()),
          );
        }
        if (snapshot.hasError) {
          return SizedBox(
            height: 320,
            child: Center(child: Text('加载失败：${snapshot.error}')),
          );
        }
        final List<StoredProjectInfo> projects = snapshot.data ?? <StoredProjectInfo>[];
        if (projects.isEmpty) {
          return SizedBox(
            height: 320,
            child: Center(
              child: Text('暂无自动保存的项目', style: theme.typography.bodyLarge),
            ),
          );
        }
        final bool hasSelection = _selected.isNotEmpty;
        final int totalSelected = _selected.length;
        final int totalCount = projects.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  checked: _selectAll,
                  onChanged: (value) => _toggleSelectAll(projects, value ?? false),
                ),
                Text('全选', style: theme.typography.bodyStrong),
                const Spacer(),
                Tooltip(
                  message: '删除所选项目',
                  child: FilledButton(
                    onPressed: !_deleting && hasSelection ? _deleteSelected : null,
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
                              Text('删除所选 ($totalSelected)'),
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
              child: ListView.separated(
                itemBuilder: (context, index) {
                  final StoredProjectInfo info = projects[index];
                  final bool selected = _selected.contains(info.path);
                  return ListTile.selectable(
                    leading: Checkbox(
                      checked: selected,
                      onChanged: (value) =>
                          _toggleSelection(info.path, value ?? false, totalCount),
                    ),
                    onPressed: () =>
                        _toggleSelection(info.path, !selected, totalCount),
                    title: Text(
                      info.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(info.fileName, style: theme.typography.caption),
                        Text(
                          '大小：${_formatFileSize(info.fileSize)} · 更新：${_formatDate(info.lastModified)}',
                          style: theme.typography.caption,
                        ),
                        if (info.summary != null)
                          Text(
                            '画布 ${info.summary!.settings.width.toInt()} x ${info.summary!.settings.height.toInt()}',
                            style: theme.typography.caption,
                          ),
                      ],
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: WidgetStateProperty.resolveWith(
                      (states) => states.isHovered
                          ? theme.resources.subtleFillColorSecondary
                          : theme.resources.subtleFillColorTertiary,
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: totalCount,
              ),
            ),
          ],
        );
      },
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
