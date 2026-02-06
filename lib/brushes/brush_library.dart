import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/preferences/app_preferences.dart';
import '../canvas/canvas_tools.dart';
import 'brush_preset.dart';

class BrushLibrary extends ChangeNotifier {
  BrushLibrary._({
    required List<BrushPreset> presets,
    required String selectedId,
  })  : _presets = presets,
        _selectedId = selectedId;

  static const int _version = 1;
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
    final Map<String, dynamic>? payload = await _readPayload();
    BrushLibrary library;
    if (payload != null) {
      library = _fromPayload(payload);
    } else {
      library = _defaultLibrary(prefs);
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
      return _defaultLibrary(null);
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

  static BrushLibrary _defaultLibrary(AppPreferences? prefs) {
    final BrushPreset pencil = BrushPreset(
      id: 'pencil',
      name: 'Pencil',
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
        name: 'Pen',
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
        name: 'Pixel',
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
        name: 'Triangle',
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
        name: 'Square',
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
        name: 'Star',
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
