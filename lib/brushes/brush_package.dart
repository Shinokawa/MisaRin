import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'brush_preset.dart';
import 'brush_shape_library.dart';

class BrushPackageData {
  const BrushPackageData({
    required this.preset,
    this.shapeFileName,
    this.shapeType,
    this.shapeBytes,
    this.localizationFileName,
    this.localizations,
  });

  final BrushPreset preset;
  final String? shapeFileName;
  final BrushShapeFileType? shapeType;
  final Uint8List? shapeBytes;
  final String? localizationFileName;
  final BrushLocalizationTable? localizations;
}

class BrushLocalizationTable {
  const BrushLocalizationTable(this.entries);

  final Map<String, Map<String, String>> entries;

  bool hasKey(String key) => entries.containsKey(key);

  String? resolve(String key, String localeTag) {
    final Map<String, String>? values = entries[key];
    if (values == null || values.isEmpty) {
      return null;
    }
    final String normalized = _normalizeLocale(localeTag);
    final List<String> candidates = <String>[];
    if (normalized.isNotEmpty) {
      candidates.add(normalized);
      final int split = normalized.indexOf('_');
      if (split > 0) {
        candidates.add(normalized.substring(0, split));
      }
    }
    candidates.add('default');
    candidates.add('*');
    for (final String candidate in candidates) {
      final String? value = values[candidate];
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return values.values.first;
  }

  static String _normalizeLocale(String raw) {
    return raw.replaceAll('-', '_').trim().toLowerCase();
  }
}

class BrushPackageCodec {
  static const String configFileName = 'brush.json';
  static const String localizationFileKey = 'langFile';
  static const String defaultLocalizationFileName = 'brush_lang.txt';

  static BrushPackageData? decode(Uint8List bytes) {
    if (bytes.isEmpty) {
      return null;
    }
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (_) {
      return null;
    }
    ArchiveFile? configFile;
    for (final ArchiveFile file in archive.files) {
      if (file.name == configFileName) {
        configFile = file;
        break;
      }
    }
    if (configFile == null) {
      for (final ArchiveFile file in archive.files) {
        if (file.name.endsWith('.json')) {
          configFile = file;
          break;
        }
      }
    }
    if (configFile == null) {
      return null;
    }
    final String jsonText;
    try {
      jsonText = utf8.decode(configFile.content as List<int>);
    } catch (_) {
      return null;
    }
    final Map<String, dynamic> config;
    try {
      config = jsonDecode(jsonText) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    final BrushPreset preset = BrushPreset.fromJson(config);
    final String? shapeFileName = config['shapeFile'] as String?;
    final String? shapeTypeRaw = config['shapeType'] as String?;
    BrushShapeFileType? shapeType;
    if (shapeTypeRaw != null) {
      shapeType = _shapeTypeFromString(shapeTypeRaw);
    } else if (shapeFileName != null) {
      shapeType = _shapeTypeFromPath(shapeFileName);
    }
    Uint8List? shapeBytes;
    if (shapeFileName != null) {
      ArchiveFile? shapeFile;
      for (final ArchiveFile file in archive.files) {
        if (file.name == shapeFileName) {
          shapeFile = file;
          break;
        }
      }
      if (shapeFile != null) {
        shapeBytes = Uint8List.fromList(shapeFile.content as List<int>);
      }
    }
    final String? localizationFileName =
        config[localizationFileKey] as String?;
    final String? resolvedLocalizationFile =
        localizationFileName ??
        _findLocalizationFile(archive);
    BrushLocalizationTable? localizationTable;
    if (resolvedLocalizationFile != null) {
      ArchiveFile? localizationFile;
      for (final ArchiveFile file in archive.files) {
        if (file.name == resolvedLocalizationFile) {
          localizationFile = file;
          break;
        }
      }
      if (localizationFile != null) {
        final Uint8List textBytes =
            Uint8List.fromList(localizationFile.content as List<int>);
        localizationTable = _parseLocalizationTable(textBytes);
      }
    }
    return BrushPackageData(
      preset: preset,
      shapeFileName: shapeFileName,
      shapeType: shapeType,
      shapeBytes: shapeBytes,
      localizationFileName: resolvedLocalizationFile,
      localizations: localizationTable,
    );
  }

  static Uint8List encode({
    required BrushPreset preset,
    Uint8List? shapeBytes,
    String? shapeFileName,
    BrushShapeFileType? shapeType,
    BrushLocalizationTable? localizations,
    String? localizationFileName,
  }) {
    final Map<String, dynamic> config = preset.toJson();
    config['formatVersion'] = 1;
    if (shapeFileName != null) {
      config['shapeFile'] = shapeFileName;
    }
    if (shapeType != null) {
      config['shapeType'] = _shapeTypeToString(shapeType);
    }
    final BrushLocalizationTable? table = localizations;
    String? resolvedLocalizationFile = localizationFileName;
    if (table != null && table.entries.isNotEmpty) {
      resolvedLocalizationFile ??= defaultLocalizationFileName;
      config[localizationFileKey] = resolvedLocalizationFile;
    }
    final Archive archive = Archive();
    final List<int> jsonBytes = utf8.encode(jsonEncode(config));
    archive.addFile(
      ArchiveFile(configFileName, jsonBytes.length, jsonBytes),
    );
    if (shapeBytes != null && shapeFileName != null) {
      archive.addFile(
        ArchiveFile(shapeFileName, shapeBytes.length, shapeBytes),
      );
    }
    if (table != null &&
        table.entries.isNotEmpty &&
        resolvedLocalizationFile != null) {
      final String text = _encodeLocalizationTable(table);
      final List<int> textBytes = utf8.encode(text);
      archive.addFile(
        ArchiveFile(resolvedLocalizationFile, textBytes.length, textBytes),
      );
    }
    final List<int>? out = ZipEncoder().encode(archive);
    return Uint8List.fromList(out ?? const <int>[]);
  }

  static String? _findLocalizationFile(Archive archive) {
    for (final ArchiveFile file in archive.files) {
      if (file.name == defaultLocalizationFileName) {
        return file.name;
      }
    }
    for (final ArchiveFile file in archive.files) {
      if (file.name.toLowerCase().endsWith('.txt')) {
        return file.name;
      }
    }
    return null;
  }

  static BrushLocalizationTable _parseLocalizationTable(Uint8List bytes) {
    final String text = utf8.decode(bytes, allowMalformed: true);
    final Map<String, Map<String, String>> entries =
        <String, Map<String, String>>{};
    for (final String rawLine in text.split('\n')) {
      final String line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) {
        continue;
      }
      List<String> parts = line.split('|');
      if (parts.length < 3) {
        parts = line.split('\t');
      }
      if (parts.length < 3) {
        continue;
      }
      final String key = parts[0].trim();
      final String locale = parts[1].trim();
      final String value = parts.sublist(2).join('|').trim();
      if (key.isEmpty || locale.isEmpty || value.isEmpty) {
        continue;
      }
      final String normalizedLocale =
          BrushLocalizationTable._normalizeLocale(locale);
      final Map<String, String> values =
          entries.putIfAbsent(key, () => <String, String>{});
      values[normalizedLocale] = value;
    }
    return BrushLocalizationTable(entries);
  }

  static String _encodeLocalizationTable(BrushLocalizationTable table) {
    final List<String> lines = <String>[];
    final List<String> keys = table.entries.keys.toList()..sort();
    for (final String key in keys) {
      final Map<String, String> values = table.entries[key]!;
      final List<String> locales = values.keys.toList()..sort();
      for (final String locale in locales) {
        final String value = values[locale] ?? '';
        if (value.isEmpty) {
          continue;
        }
        lines.add('$key|$locale|$value');
      }
    }
    return lines.join('\n');
  }

  static BrushShapeFileType? _shapeTypeFromPath(String path) {
    final String lower = path.toLowerCase();
    if (lower.endsWith('.svg')) {
      return BrushShapeFileType.svg;
    }
    if (lower.endsWith('.png')) {
      return BrushShapeFileType.png;
    }
    return null;
  }

  static BrushShapeFileType? _shapeTypeFromString(String raw) {
    switch (raw.toLowerCase()) {
      case 'svg':
        return BrushShapeFileType.svg;
      case 'png':
        return BrushShapeFileType.png;
    }
    return null;
  }

  static String _shapeTypeToString(BrushShapeFileType type) {
    switch (type) {
      case BrushShapeFileType.svg:
        return 'svg';
      case BrushShapeFileType.png:
        return 'png';
    }
  }
}
