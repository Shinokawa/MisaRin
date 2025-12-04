import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:system_fonts/system_fonts.dart' as sys_fonts;

class SystemFonts {
  const SystemFonts._();

  static List<String>? _cachedFamilies;

  static const List<String> _fallbackFamilies = <String>[
    'Arial',
    'Helvetica',
    'Times New Roman',
    'Courier New',
    'Roboto',
    'Noto Sans',
    'Noto Serif',
    'PingFang SC',
    'Microsoft YaHei',
  ];

  static Future<List<String>> loadFamilies() async {
    if (_cachedFamilies != null) {
      return _cachedFamilies!;
    }
    if (!_supportsNativeFonts) {
      _cachedFamilies = _fallbackFamilies;
      return _cachedFamilies!;
    }
    final List<String> directories = _fontDirectories();
    if (directories.isEmpty) {
      _cachedFamilies = _fallbackFamilies;
      return _cachedFamilies!;
    }
    try {
      final List<String> families = await compute(
        _collectFontNames,
        directories,
      );
      _cachedFamilies = families.isEmpty ? _fallbackFamilies : families;
    } catch (_) {
      _cachedFamilies = _fallbackFamilies;
    }
    return _cachedFamilies!;
  }

  static bool get _supportsNativeFonts {
    if (kIsWeb) {
      return false;
    }
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  static List<String> _fontDirectories() {
    final List<String> dirs = <String>[];
    if (Platform.isMacOS) {
      dirs.add('/System/Library/Fonts');
      dirs.add('/Library/Fonts');
      final String? home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        dirs.add(p.join(home, 'Library', 'Fonts'));
      }
    } else if (Platform.isWindows) {
      final String? winDir = Platform.environment['WINDIR'];
      if (winDir != null && winDir.isNotEmpty) {
        dirs.add(p.join(winDir, 'Fonts'));
      } else {
        dirs.add(r'C:\Windows\Fonts');
      }
      final String? userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        dirs.add(
          p.join(userProfile, 'AppData', 'Local', 'Microsoft', 'Windows', 'Fonts'),
        );
      }
    } else if (Platform.isLinux) {
      dirs.add('/usr/share/fonts');
      dirs.add('/usr/local/share/fonts');
      final String? home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        dirs.add(p.join(home, '.fonts'));
        dirs.add(p.join(home, '.local', 'share', 'fonts'));
      }
    }
    return dirs;
  }
}

List<String> _collectFontNames(List<String> roots) {
  final sys_fonts.SystemFonts loader = sys_fonts.SystemFonts();
  final Set<String> visited = <String>{};
  for (final String root in roots) {
    _registerDirectory(loader, root, visited);
  }
  final List<String> fonts = loader.getFontList();
  fonts.sort(
    (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
  );
  return fonts;
}

void _registerDirectory(
  sys_fonts.SystemFonts loader,
  String rawPath,
  Set<String> visited,
) {
  if (rawPath.isEmpty) {
    return;
  }
  final String normalized = p.normalize(rawPath);
  if (!visited.add(normalized)) {
    return;
  }
  final Directory directory = Directory(normalized);
  if (!directory.existsSync()) {
    return;
  }
  try {
    loader.addAdditionalFontDirectory(normalized);
  } catch (_) {
    return;
  }
  try {
    for (final FileSystemEntity entity in directory.listSync(followLinks: false)) {
      if (entity is Directory) {
        _registerDirectory(loader, entity.path, visited);
      }
    }
  } catch (_) {
    // Ignore directories we cannot traverse.
  }
}
