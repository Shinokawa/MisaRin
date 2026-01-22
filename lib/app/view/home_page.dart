import 'package:fluent_ui/fluent_ui.dart';

import '../dialogs/project_manager_dialog.dart';
import '../dialogs/recent_projects_dialog.dart';
import '../l10n/l10n.dart';
import '../project/project_document.dart';
import '../project/project_repository.dart';
import '../menu/menu_action_dispatcher.dart';
import '../menu/menu_app_actions.dart';
import '../widgets/app_notification.dart';

class MisarinHomePage extends StatefulWidget {
  const MisarinHomePage({super.key});

  @override
  State<MisarinHomePage> createState() => _MisarinHomePageState();
}

class _MisarinHomePageState extends State<MisarinHomePage> {
  late final ScrollController _sidebarScrollController;

  @override
  void initState() {
    super.initState();
    _sidebarScrollController = ScrollController();
  }

  @override
  void dispose() {
    _sidebarScrollController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateProject(BuildContext context) async {
    await AppMenuActions.createProject(context);
  }

  Future<void> _handleOpenProject(BuildContext context) async {
    await AppMenuActions.openProjectFromDisk(context);
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
      await AppMenuActions.openProject(context, document);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showInfoBar(
        context,
        context.l10n.openProjectFailed(error),
        severity: InfoBarSeverity.error,
      );
    }
  }

  Future<void> _handleOpenSettings(BuildContext context) async {
    await AppMenuActions.openSettings(context);
  }

  Future<void> _handleOpenAbout(BuildContext context) async {
    await AppMenuActions.showAbout(context);
  }

  Future<void> _handleManageProjects(BuildContext context) async {
    await showProjectManagerDialog(context);
  }

  void _showInfoBar(
    BuildContext context,
    String message, {
    InfoBarSeverity severity = InfoBarSeverity.info,
  }) {
    AppNotifications.show(
      context,
      message: message,
      severity: severity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final handler = MenuActionHandler(
      newProject: () => AppMenuActions.createProject(context),
      importImage: () => AppMenuActions.importImage(context),
      importImageFromClipboard: () =>
          AppMenuActions.importImageFromClipboard(context),
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
    final l10n = context.l10n;
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
        child: Scrollbar(
          controller: _sidebarScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _sidebarScrollController,
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Misa Rin', style: theme.typography.titleLarge),
                const SizedBox(height: 4),
                Text(l10n.homeTagline, style: theme.typography.body),
                const SizedBox(height: 24),
                _buildSidebarAction(
                  context,
                  icon: FluentIcons.add,
                  label: l10n.homeNewProject,
                  description: l10n.homeNewProjectDesc,
                  onPressed: () => _handleCreateProject(context),
                ),
                _buildSidebarAction(
                  context,
                  icon: FluentIcons.open_file,
                  label: l10n.homeOpenProject,
                  description: l10n.homeOpenProjectDesc,
                  onPressed: () => _handleOpenProject(context),
                ),
                _buildSidebarAction(
                  context,
                  icon: FluentIcons.clock,
                  label: l10n.homeRecentProjects,
                  description: l10n.homeRecentProjectsDesc,
                  onPressed: () => _handleOpenRecent(context),
                ),
                _buildSidebarAction(
                  context,
                  icon: FluentIcons.folder,
                  label: l10n.homeProjectManager,
                  description: l10n.homeProjectManagerDesc,
                  onPressed: () => _handleManageProjects(context),
                ),
                _buildSidebarAction(
                  context,
                  icon: FluentIcons.settings,
                  label: l10n.homeSettings,
                  description: l10n.homeSettingsDesc,
                  onPressed: () => _handleOpenSettings(context),
                ),
                _buildSidebarAction(
                  context,
                  icon: FluentIcons.info,
                  label: l10n.homeAbout,
                  description: l10n.homeAboutDesc,
                  onPressed: () => _handleOpenAbout(context),
                ),
              ],
            ),
          ),
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
