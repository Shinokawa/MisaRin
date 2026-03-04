import 'package:fluent_ui/fluent_ui.dart';

import '../app/dialogs/project_manager_dialog.dart';
import '../app/dialogs/recent_projects_dialog.dart';
import '../app/l10n/l10n.dart';
import '../app/project/project_document.dart';
import '../app/project/project_repository.dart';
import '../app/menu/menu_app_actions.dart';
import '../app/widgets/app_notification.dart';

class MobileHomePage extends StatefulWidget {
  const MobileHomePage({super.key});

  @override
  State<MobileHomePage> createState() => _MobileHomePageState();
}

class _MobileHomePageState extends State<MobileHomePage> {
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
    final l10n = context.l10n;

    return NavigationView(
      content: ScaffoldPage(
        padding: EdgeInsets.zero,
        content: Container(
          color: theme.micaBackgroundColor,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Misa Rin',
                      style: theme.typography.titleLarge?.copyWith(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.homeTagline,
                      style: theme.typography.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    _buildButton(
                      context,
                      icon: FluentIcons.add,
                      label: l10n.homeNewProject,
                      onPressed: () => _handleCreateProject(context),
                      primary: true,
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      context,
                      icon: FluentIcons.open_file,
                      label: l10n.homeOpenProject,
                      onPressed: () => _handleOpenProject(context),
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      context,
                      icon: FluentIcons.clock,
                      label: l10n.homeRecentProjects,
                      onPressed: () => _handleOpenRecent(context),
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      context,
                      icon: FluentIcons.folder,
                      label: l10n.homeProjectManager,
                      onPressed: () => _handleManageProjects(context),
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      context,
                      icon: FluentIcons.settings,
                      label: l10n.homeSettings,
                      onPressed: () => _handleOpenSettings(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool primary = false,
  }) {
    final padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 24);
    final textStyle = const TextStyle(fontSize: 20, fontWeight: FontWeight.w500);

    if (primary) {
      return FilledButton(
        onPressed: onPressed,
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 16),
              Text(label, style: textStyle),
            ],
          ),
        ),
      );
    }

    return Button(
      onPressed: onPressed,
      child: Padding(
        padding: padding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 16),
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }
}
