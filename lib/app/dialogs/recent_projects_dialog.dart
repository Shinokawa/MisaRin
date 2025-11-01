import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';

import '../project/project_document.dart';
import '../project/project_repository.dart';

Future<ProjectSummary?> showRecentProjectsDialog(BuildContext context) {
  return showDialog<ProjectSummary>(
    context: context,
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
    return ContentDialog(
      title: const Text('最近打开'),
      constraints: const BoxConstraints(maxWidth: 520),
      content: SizedBox(
        width: 480,
        child: FutureBuilder<List<ProjectSummary>>(
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
                return HoverButton(
                  onPressed: () => Navigator.of(context).pop(summary),
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
                          color:
                              theme.resources.controlStrongStrokeColorDefault,
                          width: 0.6,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PreviewThumbnail(bytes: summary.previewBytes),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  summary.name,
                                  style: theme.typography.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '最后打开：${_formatDate(summary.lastOpened)}',
                                  style: theme.typography.caption,
                                ),
                                Text(
                                  '画布尺寸：${summary.settings.width.toInt()} x ${summary.settings.height.toInt()}',
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
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: data.length,
            );
          },
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
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

String _formatDate(DateTime dateTime) {
  final DateTime local = dateTime.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
