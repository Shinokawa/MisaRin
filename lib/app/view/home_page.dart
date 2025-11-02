import 'package:fluent_ui/fluent_ui.dart';

import '../dialogs/recent_projects_dialog.dart';
import '../project/project_document.dart';
import '../project/project_repository.dart';
import 'canvas_page.dart';
import '../menu/menu_action_dispatcher.dart';
import '../menu/menu_app_actions.dart';

class MisarinHomePage extends StatelessWidget {
  const MisarinHomePage({super.key});

  Future<void> _handleCreateProject(BuildContext context) async {
    await AppMenuActions.createProject(context);
  }

  Future<void> _handleOpenRecent(BuildContext context) async {
    final ProjectSummary? summary = await showRecentProjectsDialog(context);
    if (summary == null || !context.mounted) {
      return;
    }
    try {
      final ProjectDocument document = await ProjectRepository.instance
          .loadDocument(summary.path);
      if (!context.mounted) {
        return;
      }
      await Navigator.of(
        context,
      ).push(FluentPageRoute(builder: (_) => CanvasPage(document: document)));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showInfoBar(context, '打开项目失败：$error', severity: InfoBarSeverity.error);
    }
  }

  Future<void> _handleOpenSettings(BuildContext context) async {
    await AppMenuActions.openSettings(context);
  }

  Future<void> _handleOpenAbout(BuildContext context) async {
    await AppMenuActions.showAbout(context);
  }

  void _showInfoBar(
    BuildContext context,
    String message, {
    InfoBarSeverity severity = InfoBarSeverity.info,
  }) {
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: Text(message),
        severity: severity,
        action: IconButton(
          icon: const Icon(FluentIcons.clear),
          onPressed: close,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final handler = MenuActionHandler(
      newProject: () => AppMenuActions.createProject(context),
      preferences: () => AppMenuActions.openSettings(context),
      about: () => AppMenuActions.showAbout(context),
    );
    return MenuActionBinding(
      handler: handler,
      child: NavigationView(
        content: ScaffoldPage(
          padding: EdgeInsets.zero,
          content: Container(
            color: theme.micaBackgroundColor,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: _buildSidebar(context),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 48,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.resources.subtleFillColorTertiary,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.resources.controlStrokeColorDefault,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 36),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Misa Rin', style: theme.typography.titleLarge),
            const SizedBox(height: 4),
            Text('创作从这里开始', style: theme.typography.body),
            const SizedBox(height: 24),
            _buildSidebarAction(
              context,
              icon: FluentIcons.add,
              label: '新建项目',
              description: '从空白画布开启新的创意',
              onPressed: () => _handleCreateProject(context),
            ),
            _buildSidebarAction(
              context,
              icon: FluentIcons.clock,
              label: '最近打开',
              description: '快速恢复自动保存的项目',
              onPressed: () => _handleOpenRecent(context),
            ),
            _buildSidebarAction(
              context,
              icon: FluentIcons.settings,
              label: '设置',
              description: '预览即将上线的个性化选项',
              onPressed: () => _handleOpenSettings(context),
            ),
            _buildSidebarAction(
              context,
              icon: FluentIcons.info,
              label: '关于',
              description: '了解项目 misa rin',
              onPressed: () => _handleOpenAbout(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    String? description,
  }) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile.selectable(
        onPressed: onPressed,
        leading: Icon(icon, size: 20),
        title: Text(label, style: theme.typography.subtitle),
        subtitle: description == null ? null : Text(description),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: WidgetStateProperty.resolveWith(
          (states) => states.isHovered
              ? theme.resources.subtleFillColorSecondary
              : theme.resources.subtleFillColorTertiary,
        ),
      ),
    );
  }
}
