import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../dialogs/about_dialog.dart';
import '../dialogs/canvas_settings_dialog.dart';
import '../dialogs/settings_dialog.dart';
import '../project/project_document.dart';
import '../project/project_repository.dart';
import '../utils/clipboard_image_reader.dart';
import '../view/canvas_page.dart';
import '../widgets/app_notification.dart';

class AppMenuActions {
  const AppMenuActions._();

  static Future<void> createProject(BuildContext context) async {
    final NewProjectConfig? config = await showCanvasSettingsDialog(context);
    if (config == null || !context.mounted) {
      return;
    }
    try {
      final ProjectDocument document = await ProjectRepository.instance
          .createDocumentFromSettings(config.settings, name: config.name);
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

  static Future<void> openProjectFromDisk(BuildContext context) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: '打开项目',
      type: FileType.custom,
      allowedExtensions: const ['rin', 'psd'],
      withData: kIsWeb,
    );
    final PlatformFile? file = result?.files.singleOrNull;
    if (file == null || !context.mounted) {
      return;
    }
    final String? path = kIsWeb ? null : file.path;
    final Uint8List? bytes = file.bytes;
    if (path == null && bytes == null) {
      return;
    }
    try {
      final ProjectDocument document;
      final String extension = file.name.toLowerCase();
      if (extension.endsWith('.psd')) {
        if (path != null && !kIsWeb) {
          document = await ProjectRepository.instance.importPsd(path);
        } else if (bytes != null) {
          document = await ProjectRepository.instance.importPsdFromBytes(
            bytes,
            fileName: file.name,
          );
        } else {
          throw Exception('无法读取 PSD 文件内容。');
        }
      } else {
        if (path != null && !kIsWeb) {
          document = await ProjectRepository.instance.loadDocument(path);
        } else if (bytes != null) {
          document = await ProjectRepository.instance
              .loadDocumentFromBytes(bytes);
        } else {
          throw Exception('无法读取项目文件内容。');
        }
      }
      if (!context.mounted) {
        return;
      }
      await _showProject(context, document);
      if (!context.mounted) {
        return;
      }
      _showInfoBar(
        context,
        '已打开项目：${document.name}',
        severity: InfoBarSeverity.success,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showInfoBar(context, '打开项目失败：$error', severity: InfoBarSeverity.error);
    }
  }

  static Future<void> openSettings(BuildContext context) async {
    await showSettingsDialog(context);
  }

  static Future<void> showAbout(BuildContext context) async {
    await showAboutMisarinDialog(context);
  }

  static Future<void> importImage(BuildContext context) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: '导入图片',
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'bmp', 'gif'],
    );
    final PlatformFile? file = result?.files.singleOrNull;
    final String? path = file?.path;
    if (path == null || !context.mounted) {
      return;
    }
    try {
      final ProjectDocument document = await ProjectRepository.instance
          .createDocumentFromImage(path, name: file!.name);
      if (!context.mounted) {
        return;
      }
      await _showProject(context, document);
      if (!context.mounted) {
        return;
      }
      _showInfoBar(
        context,
        '已导入图片：${file.name}',
        severity: InfoBarSeverity.success,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showInfoBar(context, '导入图片失败：$error', severity: InfoBarSeverity.error);
    }
  }

  static Future<void> importImageFromClipboard(BuildContext context) async {
    final ClipboardImageData? payload = await ClipboardImageReader.readImage();
    if (payload == null) {
      if (!context.mounted) {
        return;
      }
      _showInfoBar(
        context,
        '剪贴板中没有找到可以导入的位图。',
        severity: InfoBarSeverity.warning,
      );
      return;
    }
    try {
      final ProjectDocument document = await ProjectRepository.instance
          .createDocumentFromImageBytes(
            payload.bytes,
            name: payload.fileName ?? '剪贴板图像',
          );
      if (!context.mounted) {
        return;
      }
      await _showProject(context, document);
      if (!context.mounted) {
        return;
      }
      _showInfoBar(context, '已导入剪贴板图像', severity: InfoBarSeverity.success);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showInfoBar(
        context,
        '导入剪贴板图像失败：$error',
        severity: InfoBarSeverity.error,
      );
    }
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
    AppNotifications.show(context, message: message, severity: severity);
  }
}
