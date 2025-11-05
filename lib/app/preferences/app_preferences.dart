import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPreferences {
  AppPreferences._({
    required this.bucketSampleAllLayers,
    required this.bucketContiguous,
    required this.historyLimit,
    required this.themeMode,
  });

  static const String _folderName = 'MisaRin';
  static const String _fileName = 'app_preferences.rinconfig';
  static const int _version = 3;
  static const int _defaultHistoryLimit = 30;
  static const int minHistoryLimit = 5;
  static const int maxHistoryLimit = 200;
  static const ThemeMode _defaultThemeMode = ThemeMode.system;

  static AppPreferences? _instance;

  bool bucketSampleAllLayers;
  bool bucketContiguous;
  int historyLimit;
  ThemeMode themeMode;

  static AppPreferences get instance {
    final AppPreferences? current = _instance;
    if (current == null) {
      throw StateError('AppPreferences has not been loaded');
    }
    return current;
  }

  static Future<AppPreferences> load() async {
    if (_instance != null) {
      return _instance!;
    }
    final File file = await _preferencesFile();
    if (await file.exists()) {
      try {
        final Uint8List bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          final int version = bytes[0];
          if (version >= 3 && bytes.length >= 6) {
            final int rawHistory = bytes[3] | (bytes[4] << 8);
            _instance = AppPreferences._(
              bucketSampleAllLayers: bytes[1] != 0,
              bucketContiguous: bytes[2] != 0,
              historyLimit: _clampHistoryLimit(rawHistory),
              themeMode: _decodeThemeMode(bytes[5]),
            );
            return _instance!;
          }
          if (version == 2 && bytes.length >= 5) {
            final int rawHistory = bytes[3] | (bytes[4] << 8);
            _instance = AppPreferences._(
              bucketSampleAllLayers: bytes[1] != 0,
              bucketContiguous: bytes[2] != 0,
              historyLimit: _clampHistoryLimit(rawHistory),
              themeMode: _defaultThemeMode,
            );
            return _instance!;
          }
          if (version == 1 && bytes.length >= 3) {
            _instance = AppPreferences._(
              bucketSampleAllLayers: bytes[1] != 0,
              bucketContiguous: bytes[2] != 0,
              historyLimit: _defaultHistoryLimit,
              themeMode: _defaultThemeMode,
            );
            return _instance!;
          }
        }
      } catch (_) {
        // fall through to defaults if the file is corrupted
      }
    }
    _instance = AppPreferences._(
      bucketSampleAllLayers: false,
      bucketContiguous: true,
      historyLimit: _defaultHistoryLimit,
      themeMode: _defaultThemeMode,
    );
    return _instance!;
  }

  static Future<void> save() async {
    final AppPreferences prefs = _instance ?? await load();
    final File file = await _preferencesFile();
    await file.create(recursive: true);
    final int history = _clampHistoryLimit(prefs.historyLimit);
    prefs.historyLimit = history;
    final Uint8List payload = Uint8List.fromList(<int>[
      _version,
      prefs.bucketSampleAllLayers ? 1 : 0,
      prefs.bucketContiguous ? 1 : 0,
      history & 0xff,
      (history >> 8) & 0xff,
      _encodeThemeMode(prefs.themeMode),
    ]);
    await file.writeAsBytes(payload, flush: true);
  }

  static int _clampHistoryLimit(int value) {
    if (value < minHistoryLimit) {
      return minHistoryLimit;
    }
    if (value > maxHistoryLimit) {
      return maxHistoryLimit;
    }
    return value;
  }

  static ThemeMode _decodeThemeMode(int value) {
    switch (value) {
      case 0:
        return ThemeMode.light;
      case 1:
        return ThemeMode.dark;
      case 2:
      default:
        return ThemeMode.system;
    }
  }

  static int _encodeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 0;
      case ThemeMode.dark:
        return 1;
      case ThemeMode.system:
      default:
        return 2;
    }
  }

  static ThemeMode get defaultThemeMode => _defaultThemeMode;
  static int get defaultHistoryLimit => _defaultHistoryLimit;

  static Future<File> _preferencesFile() async {
    final Directory base = await getApplicationDocumentsDirectory();
    final Directory directory = Directory(p.join(base.path, _folderName));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File(p.join(directory.path, _fileName));
  }
}
