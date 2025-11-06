import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../bitmap_canvas/stroke_dynamics.dart';

class AppPreferences {
  AppPreferences._({
    required this.bucketSampleAllLayers,
    required this.bucketContiguous,
    required this.historyLimit,
    required this.themeMode,
    required this.penStrokeWidth,
    required this.simulatePenPressure,
    required this.penPressureProfile,
    required this.penAntialias,
  });

  static const String _folderName = 'MisaRin';
  static const String _fileName = 'app_preferences.rinconfig';
  static const int _version = 5;
  static const int _defaultHistoryLimit = 30;
  static const int minHistoryLimit = 5;
  static const int maxHistoryLimit = 200;
  static const ThemeMode _defaultThemeMode = ThemeMode.system;
  static const double _defaultPenStrokeWidth = 3.0;
  static const bool _defaultSimulatePenPressure = false;
  static const StrokePressureProfile _defaultPenPressureProfile =
      StrokePressureProfile.auto;
  static const bool _defaultPenAntialias = false;

  static AppPreferences? _instance;

  bool bucketSampleAllLayers;
  bool bucketContiguous;
  int historyLimit;
  ThemeMode themeMode;
  double penStrokeWidth;
  bool simulatePenPressure;
  StrokePressureProfile penPressureProfile;
  bool penAntialias;

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
          if (version >= 5 && bytes.length >= 10) {
            final int rawHistory = bytes[3] | (bytes[4] << 8);
            _instance = AppPreferences._(
              bucketSampleAllLayers: bytes[1] != 0,
              bucketContiguous: bytes[2] != 0,
              historyLimit: _clampHistoryLimit(rawHistory),
              themeMode: _decodeThemeMode(bytes[5]),
              penStrokeWidth: _decodePenStrokeWidth(bytes[6]),
              simulatePenPressure: bytes[7] != 0,
              penPressureProfile: _decodePressureProfile(bytes[8]),
              penAntialias: bytes[9] != 0,
            );
            return _instance!;
          }
          if (version == 4 && bytes.length >= 9) {
            final int rawHistory = bytes[3] | (bytes[4] << 8);
            _instance = AppPreferences._(
              bucketSampleAllLayers: bytes[1] != 0,
              bucketContiguous: bytes[2] != 0,
              historyLimit: _clampHistoryLimit(rawHistory),
              themeMode: _decodeThemeMode(bytes[5]),
              penStrokeWidth: _decodePenStrokeWidth(bytes[6]),
              simulatePenPressure: bytes[7] != 0,
              penPressureProfile: _decodePressureProfile(bytes[8]),
              penAntialias: _defaultPenAntialias,
            );
            return _instance!;
          }
          if (version == 3 && bytes.length >= 6) {
            final int rawHistory = bytes[3] | (bytes[4] << 8);
            _instance = AppPreferences._(
              bucketSampleAllLayers: bytes[1] != 0,
              bucketContiguous: bytes[2] != 0,
              historyLimit: _clampHistoryLimit(rawHistory),
              themeMode: _decodeThemeMode(bytes[5]),
              penStrokeWidth: _defaultPenStrokeWidth,
              simulatePenPressure: _defaultSimulatePenPressure,
              penPressureProfile: _defaultPenPressureProfile,
              penAntialias: _defaultPenAntialias,
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
              penStrokeWidth: _defaultPenStrokeWidth,
              simulatePenPressure: _defaultSimulatePenPressure,
              penPressureProfile: _defaultPenPressureProfile,
              penAntialias: _defaultPenAntialias,
            );
            return _instance!;
          }
          if (version == 1 && bytes.length >= 3) {
            _instance = AppPreferences._(
              bucketSampleAllLayers: bytes[1] != 0,
              bucketContiguous: bytes[2] != 0,
              historyLimit: _defaultHistoryLimit,
              themeMode: _defaultThemeMode,
              penStrokeWidth: _defaultPenStrokeWidth,
              simulatePenPressure: _defaultSimulatePenPressure,
              penPressureProfile: _defaultPenPressureProfile,
              penAntialias: _defaultPenAntialias,
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
      penStrokeWidth: _defaultPenStrokeWidth,
      simulatePenPressure: _defaultSimulatePenPressure,
      penPressureProfile: _defaultPenPressureProfile,
      penAntialias: _defaultPenAntialias,
    );
    return _instance!;
  }

  static Future<void> save() async {
    final AppPreferences prefs = _instance ?? await load();
    final File file = await _preferencesFile();
    await file.create(recursive: true);
    final int history = _clampHistoryLimit(prefs.historyLimit);
    prefs.historyLimit = history;
    final int strokeWidth = _encodePenStrokeWidth(prefs.penStrokeWidth);
    prefs.penStrokeWidth = strokeWidth.toDouble();
    final Uint8List payload = Uint8List.fromList(<int>[
      _version,
      prefs.bucketSampleAllLayers ? 1 : 0,
      prefs.bucketContiguous ? 1 : 0,
      history & 0xff,
      (history >> 8) & 0xff,
      _encodeThemeMode(prefs.themeMode),
      strokeWidth,
      prefs.simulatePenPressure ? 1 : 0,
      _encodePressureProfile(prefs.penPressureProfile),
      prefs.penAntialias ? 1 : 0,
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

  static double _decodePenStrokeWidth(int value) {
    final int clamped = value.clamp(1, 60);
    return clamped.toDouble();
  }

  static int _encodePenStrokeWidth(double value) {
    final double clamped = value.clamp(1.0, 60.0);
    return clamped.round();
  }

  static StrokePressureProfile _decodePressureProfile(int value) {
    switch (value) {
      case 0:
        return StrokePressureProfile.taperEnds;
      case 1:
        return StrokePressureProfile.taperCenter;
      case 2:
      default:
        return StrokePressureProfile.auto;
    }
  }

  static int _encodePressureProfile(StrokePressureProfile profile) {
    switch (profile) {
      case StrokePressureProfile.taperEnds:
        return 0;
      case StrokePressureProfile.taperCenter:
        return 1;
      case StrokePressureProfile.auto:
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
