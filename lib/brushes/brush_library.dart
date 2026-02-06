import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/preferences/app_preferences.dart';
import '../canvas/canvas_tools.dart';
import '../l10n/app_localizations.dart';
import 'brush_preset.dart';

class BrushLibrary extends ChangeNotifier {
  BrushLibrary._({
    required List<BrushPreset> presets,
    required String selectedId,
  })  : _presets = presets,
        _selectedId = selectedId;

  static const int _version = 2;
  static const String _folderName = 'MisaRin';
  static const String _fileName = 'brush_presets.json';
  static const String _storageKey = 'misa_rin.brush_presets';

  static BrushLibrary? _instance;

  final List<BrushPreset> _presets;
  String _selectedId;

  static BrushLibrary get instance {
    final BrushLibrary? current = _instance;
    if (current == null) {
      throw StateError('BrushLibrary has not been loaded');
    }
    return current;
  }

  List<BrushPreset> get presets => List<BrushPreset>.unmodifiable(_presets);

  String get selectedId => _selectedId;

  BrushPreset get selectedPreset {
    return _presets.firstWhere(
      (BrushPreset preset) => preset.id == _selectedId,
      orElse: () => _presets.first,
    );
  }

  static Future<BrushLibrary> load({AppPreferences? prefs}) async {
    if (_instance != null) {
      return _instance!;
    }
    final AppLocalizations l10n = _resolveL10n(prefs);
    final Map<String, dynamic>? payload = await _readPayload();
    BrushLibrary library;
    if (payload != null) {
      library = _fromPayload(payload);
      final int payloadVersion = (payload['version'] as num?)?.toInt() ?? 0;
      if (payloadVersion < _version) {
        final bool renamed = _renameDefaultPresetNames(library, l10n);
        if (renamed) {
          unawaited(library.save());
        }
      }
    } else {
      library = _defaultLibrary(prefs, l10n);
      await library.save();
    }
    _instance = library;
    return library;
  }

  Future<void> save() async {
    await _writePayload(_toPayload());
  }

  void selectPreset(String id) {
    if (_selectedId == id) {
      return;
    }
    if (_presets.indexWhere((BrushPreset preset) => preset.id == id) < 0) {
      return;
    }
    _selectedId = id;
    notifyListeners();
    unawaited(save());
  }

  void updatePreset(BrushPreset preset) {
    final int index =
        _presets.indexWhere((BrushPreset entry) => entry.id == preset.id);
    if (index < 0) {
      return;
    }
    _presets[index] = preset.sanitized();
    notifyListeners();
    unawaited(save());
  }

  void addPreset(BrushPreset preset) {
    _presets.add(preset.sanitized());
    notifyListeners();
    unawaited(save());
  }

  void removePreset(String id) {
    if (_presets.length <= 1) {
      return;
    }
    final int index =
        _presets.indexWhere((BrushPreset preset) => preset.id == id);
    if (index < 0) {
      return;
    }
    _presets.removeAt(index);
    if (_selectedId == id) {
      _selectedId = _presets.first.id;
    }
    notifyListeners();
    unawaited(save());
  }

  static BrushLibrary _fromPayload(Map<String, dynamic> payload) {
    final List<dynamic> entries =
        payload['presets'] as List<dynamic>? ?? <dynamic>[];
    final List<BrushPreset> presets = entries
        .whereType<Map<String, dynamic>>()
        .map(BrushPreset.fromJson)
        .toList();
    if (presets.isEmpty) {
      return _defaultLibrary(
        null,
        lookupAppLocalizations(const ui.Locale('en')),
      );
    }
    String selectedId = payload['selectedId'] as String? ?? presets.first.id;
    if (presets.indexWhere((BrushPreset preset) => preset.id == selectedId) <
        0) {
      selectedId = presets.first.id;
    }
    return BrushLibrary._(presets: presets, selectedId: selectedId);
  }

  Map<String, dynamic> _toPayload() => <String, dynamic>{
        'version': _version,
        'selectedId': _selectedId,
        'presets': _presets.map((BrushPreset preset) => preset.toJson()).toList(),
      };

  static BrushLibrary _defaultLibrary(
    AppPreferences? prefs,
    AppLocalizations l10n,
  ) {
    final _DefaultPresetNames names = _DefaultPresetNames.fromL10n(l10n);
    final BrushPreset pencil = BrushPreset(
      id: 'pencil',
      name: names.pencil,
      shape: prefs?.brushShape ?? BrushShape.circle,
      spacing: 0.12,
      hardness: 0.65,
      flow: 1.0,
      scatter: 0.0,
      randomRotation: prefs?.brushRandomRotationEnabled ?? false,
      rotationJitter: 1.0,
      antialiasLevel: prefs?.penAntialiasLevel ?? 1,
      hollowEnabled: prefs?.hollowStrokeEnabled ?? false,
      hollowRatio: prefs?.hollowStrokeRatio ?? 0.0,
      hollowEraseOccludedParts: prefs?.hollowStrokeEraseOccludedParts ?? false,
      autoSharpTaper: prefs?.autoSharpPeakEnabled ?? false,
      snapToPixel: false,
    ).sanitized();

    final List<BrushPreset> presets = <BrushPreset>[
      pencil,
      BrushPreset(
        id: 'pen',
        name: names.pen,
        shape: BrushShape.circle,
        spacing: 0.08,
        hardness: 0.9,
        flow: 1.0,
        scatter: 0.0,
        randomRotation: false,
        rotationJitter: 0.0,
        antialiasLevel: 1,
        hollowEnabled: false,
        hollowRatio: 0.0,
        hollowEraseOccludedParts: false,
        autoSharpTaper: true,
        snapToPixel: false,
      ),
      BrushPreset(
        id: 'pixel',
        name: names.pixel,
        shape: BrushShape.square,
        spacing: 1.0,
        hardness: 1.0,
        flow: 1.0,
        scatter: 0.0,
        randomRotation: false,
        rotationJitter: 0.0,
        antialiasLevel: 0,
        hollowEnabled: false,
        hollowRatio: 0.0,
        hollowEraseOccludedParts: false,
        autoSharpTaper: false,
        snapToPixel: true,
      ),
      BrushPreset(
        id: 'triangle',
        name: names.triangle,
        shape: BrushShape.triangle,
        spacing: 0.15,
        hardness: 0.85,
        flow: 1.0,
        scatter: 0.0,
        randomRotation: false,
        rotationJitter: 0.0,
        antialiasLevel: 1,
        hollowEnabled: false,
        hollowRatio: 0.0,
        hollowEraseOccludedParts: false,
        autoSharpTaper: false,
        snapToPixel: false,
      ),
      BrushPreset(
        id: 'square',
        name: names.square,
        shape: BrushShape.square,
        spacing: 0.15,
        hardness: 0.85,
        flow: 1.0,
        scatter: 0.0,
        randomRotation: false,
        rotationJitter: 0.0,
        antialiasLevel: 1,
        hollowEnabled: false,
        hollowRatio: 0.0,
        hollowEraseOccludedParts: false,
        autoSharpTaper: false,
        snapToPixel: false,
      ),
      BrushPreset(
        id: 'star',
        name: names.star,
        shape: BrushShape.star,
        spacing: 0.18,
        hardness: 0.8,
        flow: 1.0,
        scatter: 0.0,
        randomRotation: false,
        rotationJitter: 0.0,
        antialiasLevel: 1,
        hollowEnabled: false,
        hollowRatio: 0.0,
        hollowEraseOccludedParts: false,
        autoSharpTaper: false,
        snapToPixel: false,
      ),
    ];

    return BrushLibrary._(presets: presets, selectedId: pencil.id);
  }

  static AppLocalizations _resolveL10n(AppPreferences? prefs) {
    final ui.Locale locale =
        prefs?.localeOverride ?? ui.PlatformDispatcher.instance.locale;
    try {
      return lookupAppLocalizations(locale);
    } catch (_) {
      return lookupAppLocalizations(const ui.Locale('en'));
    }
  }

  static bool _renameDefaultPresetNames(
    BrushLibrary library,
    AppLocalizations l10n,
  ) {
    final _DefaultPresetNames target = _DefaultPresetNames.fromL10n(l10n);
    const _DefaultPresetNames legacy = _DefaultPresetNames.legacyEnglish();
    bool updated = false;
    for (final BrushPreset preset in library._presets) {
      final String? desired = target.nameForId(preset.id);
      final String? expectedLegacy = legacy.nameForId(preset.id);
      if (desired == null || expectedLegacy == null) {
        continue;
      }
      if (preset.name == expectedLegacy && preset.name != desired) {
        preset.name = desired;
        updated = true;
      }
    }
    return updated;
  }

  static Future<Map<String, dynamic>?> _readPayload() async {
    if (kIsWeb) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? encoded = prefs.getString(_storageKey);
      if (encoded == null || encoded.isEmpty) {
        return null;
      }
      try {
        final Object? decoded = jsonDecode(encoded);
        return decoded is Map<String, dynamic> ? decoded : null;
      } catch (_) {
        return null;
      }
    }
    final File file = await _libraryFile();
    if (!await file.exists()) {
      return null;
    }
    try {
      final String content = await file.readAsString();
      final Object? decoded = jsonDecode(content);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writePayload(Map<String, dynamic> payload) async {
    if (kIsWeb) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(payload));
      return;
    }
    final File file = await _libraryFile();
    await file.create(recursive: true);
    await file.writeAsString(jsonEncode(payload), flush: true);
  }

  static Future<File> _libraryFile() async {
    final Directory base = await getApplicationDocumentsDirectory();
    final Directory directory = Directory(p.join(base.path, _folderName));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File(p.join(directory.path, _fileName));
  }
}

class _DefaultPresetNames {
  const _DefaultPresetNames({
    required this.pencil,
    required this.pen,
    required this.pixel,
    required this.triangle,
    required this.square,
    required this.star,
  });

  final String pencil;
  final String pen;
  final String pixel;
  final String triangle;
  final String square;
  final String star;

  static _DefaultPresetNames fromL10n(AppLocalizations l10n) {
    return _DefaultPresetNames(
      pencil: l10n.brushPresetPencil,
      pen: l10n.brushPresetPen,
      pixel: l10n.brushPresetPixel,
      triangle: l10n.triangle,
      square: l10n.square,
      star: l10n.star,
    );
  }

  const _DefaultPresetNames.legacyEnglish()
      : pencil = 'Pencil',
        pen = 'Pen',
        pixel = 'Pixel',
        triangle = 'Triangle',
        square = 'Square',
        star = 'Star';

  String? nameForId(String id) {
    switch (id) {
      case 'pencil':
        return pencil;
      case 'pen':
        return pen;
      case 'pixel':
        return pixel;
      case 'triangle':
        return triangle;
      case 'square':
        return square;
      case 'star':
        return star;
    }
    return null;
  }
}
