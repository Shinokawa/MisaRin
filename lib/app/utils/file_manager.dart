import 'dart:io';

import 'package:flutter/foundation.dart';

Future<void> revealInFileManager(String projectPath) async {
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
  } catch (error, stackTrace) {
    debugPrint('Failed to reveal project location: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
