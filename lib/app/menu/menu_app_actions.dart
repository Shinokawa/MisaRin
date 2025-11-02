import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/widgets.dart';

import '../../canvas/canvas_settings.dart';
import '../dialogs/about_dialog.dart';
import '../dialogs/canvas_settings_dialog.dart';
import '../dialogs/settings_dialog.dart';
import '../project/project_document.dart';
import '../project/project_repository.dart';
import '../view/canvas_page.dart';

class AppMenuActions {
  const AppMenuActions._();

  static Future<void> createProject(BuildContext context) async {
    final CanvasSettings? settings = await showCanvasSettingsDialog(context);
    if (settings == null || !context.mounted) {
      return;
    }
    try {
      final ProjectDocument document = await ProjectRepository.instance
          .createDocumentFromSettings(settings);
      if (!context.mounted) {
        return;
      }
      await _showProject(context, document);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showInfoBar(context, '创建项目失败：$error', severity: InfoBarSeverity.error);
    }
  }

  static Future<void> openSettings(BuildContext context) async {
    await showSettingsDialog(context);
  }

  static Future<void> showAbout(BuildContext context) async {
    await showAboutMisarinDialog(context);
  }

  static Future<void> openProject(
    BuildContext context,
    ProjectDocument document,
  ) async {
    await _showProject(context, document);
  }

  static Future<void> _showProject(
    BuildContext context,
    ProjectDocument document,
  ) async {
    final CanvasPageState? canvasState = context
        .findAncestorStateOfType<CanvasPageState>();
    if (canvasState != null) {
      await canvasState.openDocument(document);
      return;
    }
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => CanvasPage(document: document),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  static void _showInfoBar(
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
}
