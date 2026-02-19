import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

import '../l10n/l10n.dart';
import '../project/project_document.dart';
import '../project/project_repository.dart';
import '../widgets/project_preview_thumbnail.dart';
import 'misarin_dialog.dart';
import '../utils/file_manager.dart';

Future<ProjectSummary?> showRecentProjectsDialog(BuildContext context) {
  return showDialog<ProjectSummary>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _RecentProjectsDialog(),
  );
}

class _RecentProjectsDialog extends StatefulWidget {
  const _RecentProjectsDialog();

  @override
  State<_RecentProjectsDialog> createState() => _RecentProjectsDialogState();
}

class _RecentProjectsDialogState extends State<_RecentProjectsDialog> {
  final List<ProjectSummary> _projects = <ProjectSummary>[];
  StreamSubscription<ProjectSummary>? _subscription;
  bool _loading = true;
  String? _errorMessage;
  String? _focusedPath;

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startLoading() {
    _subscription?.cancel();
    _subscription = null;
    setState(() {
      _projects.clear();
      _loading = true;
      _errorMessage = null;
      _focusedPath = null;
    });
    final Stream<ProjectSummary> stream = ProjectRepository.instance
        .streamRecentProjects();
    _subscription = stream.listen(
      (ProjectSummary summary) {
        if (!mounted) {
          return;
        }
        setState(() {
          _projects.add(summary);
          _focusedPath ??= summary.path;
        });
      },
      onError: (Object error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _errorMessage = context.l10n.recentProjectsLoadFailed(error);
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

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final l10n = context.l10n;
    return MisarinDialog(
      title: Text(l10n.recentProjectsTitle),
      content: SizedBox(height: 420, child: _buildContent(context, theme)),
      contentWidth: null,
      maxWidth: 920,
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, FluentThemeData theme) {
    if (_errorMessage != null && _projects.isEmpty) {
      return Center(child: Text(_errorMessage!));
    }
    if (_projects.isEmpty) {
      if (_loading) {
        return const Center(child: ProgressRing());
      }
      return Center(child: Text(context.l10n.recentProjectsEmpty));
    }
    final ProjectSummary? focused = _resolveFocusedProject();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
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
                    final ProjectSummary summary = _projects[index];
                    return _RecentProjectTile(
                      summary: summary,
                      selected: focused?.path == summary.path,
                      onSelect: () => _setFocus(summary.path),
                      onOpen: () => _openProject(summary),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemCount: _projects.length,
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
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: _RecentProjectDetails(
            summary: focused,
            onOpen: focused == null ? null : () => _openProject(focused),
            onReveal: focused == null || focused.path.isEmpty
                ? null
                : () => unawaited(revealInFileManager(focused.path)),
          ),
        ),
      ],
    );
  }

  void _setFocus(String path) {
    if (_focusedPath == path) {
      return;
    }
    setState(() {
      _focusedPath = path;
    });
  }

  void _openProject(ProjectSummary summary) {
    Navigator.of(context).pop(summary);
  }

  ProjectSummary? _resolveFocusedProject() {
    final String? path = _focusedPath;
    if (path != null) {
      for (final ProjectSummary summary in _projects) {
        if (summary.path == path) {
          return summary;
        }
      }
    }
    if (_projects.isEmpty) {
      return null;
    }
    return _projects.first;
  }
}

class _RecentProjectTile extends StatefulWidget {
  const _RecentProjectTile({
    required this.summary,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
  });

  final ProjectSummary summary;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  @override
  State<_RecentProjectTile> createState() => _RecentProjectTileState();
}

class _RecentProjectTileState extends State<_RecentProjectTile> {
  late final FlyoutController _flyoutController;

  @override
  void initState() {
    super.initState();
    _flyoutController = FlyoutController();
  }

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  void _showContextMenu(Offset position) {
    final String path = widget.summary.path;
    if (path.isEmpty) {
      return;
    }
    _flyoutController.showFlyout(
      barrierDismissible: true,
      position: position,
      builder: (context) {
        return MenuFlyout(
          items: [
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.folder_open),
              text: Text(context.l10n.openFileLocation),
              onPressed: () {
                unawaited(revealInFileManager(path));
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return FlyoutTarget(
      controller: _flyoutController,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (details) {
          _showContextMenu(details.globalPosition);
        },
        onDoubleTap: widget.onOpen,
        child: ListTile.selectable(
          leading: ProjectPreviewThumbnail(bytes: widget.summary.previewBytes),
          title: Text(
            widget.summary.name,
            style: theme.typography.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.lastOpened(
                  _formatDate(widget.summary.lastOpened),
                ),
                style: theme.typography.caption,
              ),
              Text(
                context.l10n.canvasSize(
                  widget.summary.settings.width.toInt(),
                  widget.summary.settings.height.toInt(),
                ),
                style: theme.typography.caption,
              ),
            ],
          ),
          trailing: const Icon(FluentIcons.open_file, size: 16),
          selected: widget.selected,
          onPressed: widget.onSelect,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          tileColor: WidgetStateProperty.resolveWith(
            (states) => states.isHovered || widget.selected
                ? theme.resources.subtleFillColorSecondary
                : theme.resources.subtleFillColorTertiary,
          ),
        ),
      ),
    );
  }
}

class _RecentProjectDetails extends StatelessWidget {
  const _RecentProjectDetails({
    required this.summary,
    required this.onOpen,
    required this.onReveal,
  });

  final ProjectSummary? summary;
  final VoidCallback? onOpen;
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final ProjectSummary? data = summary;
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
                    data.name,
                    style: theme.typography.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ProjectPreviewThumbnail(
                      bytes: data.previewBytes,
                      width: 240,
                      height: 180,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.lastOpened(_formatDate(data.lastOpened)),
                    style: theme.typography.caption,
                  ),
                  Text(
                    context.l10n.canvasSize(
                      data.settings.width.toInt(),
                      data.settings.height.toInt(),
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
                        child: FilledButton(
                          onPressed: onOpen,
                          child: Text(context.l10n.homeOpenProject),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Button(
                        onPressed: onReveal,
                        child: Text(context.l10n.openFileLocation),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

String _formatDate(DateTime dateTime) {
  final DateTime local = dateTime.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
