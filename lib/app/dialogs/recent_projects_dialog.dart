import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';

import '../project/project_document.dart';
import '../project/project_repository.dart';
import 'misarin_dialog.dart';

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
  late Future<List<ProjectSummary>> _projectsFuture;

  @override
  void initState() {
    super.initState();
    _projectsFuture = ProjectRepository.instance.listRecentProjects();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return MisarinDialog(
      title: const Text('最近打开'),
      content: FutureBuilder<List<ProjectSummary>>(
        future: _projectsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: ProgressRing());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载最近项目失败：${snapshot.error}'));
          }
          final data = snapshot.data ?? const <ProjectSummary>[];
          if (data.isEmpty) {
            return const Center(child: Text('暂无最近打开的项目'));
          }
          return ListView.separated(
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final summary = data[index];
              return _RecentProjectTile(
                summary: summary,
                onOpen: () => Navigator.of(context).pop(summary),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: data.length,
          );
        },
      ),
      contentWidth: 480,
      maxWidth: 560,
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _RecentProjectTile extends StatefulWidget {
  const _RecentProjectTile({
    required this.summary,
    required this.onOpen,
  });

  final ProjectSummary summary;
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
              text: const Text('打开文件所在路径'),
              onPressed: () {
                unawaited(_revealInFileManager(path));
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
        child: HoverButton(
          onPressed: widget.onOpen,
          builder: (context, states) {
            final bool hovering = states.isHovered;
            final Color background = hovering
                ? theme.resources.subtleFillColorSecondary
                : theme.cardColor;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.resources.controlStrongStrokeColorDefault,
                  width: 0.6,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreviewThumbnail(bytes: widget.summary.previewBytes),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.summary.name,
                          style: theme.typography.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '最后打开：${_formatDate(widget.summary.lastOpened)}',
                          style: theme.typography.caption,
                        ),
                        Text(
                          '画布尺寸：${widget.summary.settings.width.toInt()} x ${widget.summary.settings.height.toInt()}',
                          style: theme.typography.caption,
                        ),
                      ],
                    ),
                  ),
                  const Icon(FluentIcons.open_file, size: 18),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PreviewThumbnail extends StatelessWidget {
  const _PreviewThumbnail({this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final Widget placeholder = Container(
      width: 96,
      height: 72,
      decoration: BoxDecoration(
        color: theme.resources.subtleFillColorTertiary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.resources.controlStrongStrokeColorDefault,
          width: 0.6,
        ),
      ),
      child: const Icon(FluentIcons.picture, size: 20),
    );

    final Uint8List? data = bytes;
    if (data == null || data.isEmpty) {
      return placeholder;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.memory(data, width: 96, height: 72, fit: BoxFit.cover),
    );
  }
}

Future<void> _revealInFileManager(String projectPath) async {
  if (projectPath.isEmpty) {
    return;
  }
  final File file = File(projectPath);
  final Directory directory = file.parent;
  try {
    final bool fileExists = await file.exists();
    final bool directoryExists = await directory.exists();
    if (Platform.isMacOS) {
      if (fileExists) {
        await Process.run('open', ['-R', file.path]);
      } else {
        await Process.run('open', [directory.path]);
      }
    } else if (Platform.isWindows) {
      if (fileExists) {
        await Process.run('explorer.exe', ['/select,', file.path]);
      } else {
        await Process.run('explorer.exe', [directory.path]);
      }
    } else if (Platform.isLinux) {
      final String target = directoryExists
          ? directory.path
          : (fileExists ? file.path : projectPath);
      await Process.run('xdg-open', [target]);
    }
  } catch (error) {
    debugPrint('Failed to reveal project location: $error');
  }
}

String _formatDate(DateTime dateTime) {
  final DateTime local = dateTime.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
