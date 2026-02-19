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
  static const String _textMagic = 'MRB-TEXT 1';

  static BrushPackageData? decode(Uint8List bytes) {
    if (bytes.isEmpty) {
      return null;
    }
    final BrushPackageData? textPackage = _decodeText(bytes);
    if (textPackage != null) {
      return textPackage;
    }
    return _decodeZip(bytes);
  }

  static Uint8List encode({
    required BrushPreset preset,
    Uint8List? shapeBytes,
    String? shapeFileName,
    BrushShapeFileType? shapeType,
    BrushLocalizationTable? localizations,
    String? localizationFileName,
    bool asText = true,
  }) {
    if (asText) {
      return _encodeText(
        preset: preset,
        shapeBytes: shapeBytes,
        shapeFileName: shapeFileName,
        shapeType: shapeType,
        localizations: localizations,
        localizationFileName: localizationFileName,
      );
    }
    return _encodeZip(
      preset: preset,
      shapeBytes: shapeBytes,
      shapeFileName: shapeFileName,
      shapeType: shapeType,
      localizations: localizations,
      localizationFileName: localizationFileName,
    );
  }

  static BrushPackageData? _decodeText(Uint8List bytes) {
    if (!_startsWithTextMagic(bytes)) {
      return null;
    }
    final _TextCursor cursor = _TextCursor(bytes, _skipUtf8Bom(bytes));
    final String? magicLine = cursor.readLine();
    if (magicLine == null || magicLine.trim() != _textMagic) {
      return null;
    }
    Uint8List? configBytes;
    Uint8List? localizationBytes;
    String? localizationFileName;
    Uint8List? shapeBytes;
    String? shapeFileName;
    BrushShapeFileType? shapeType;

    while (!cursor.isDone) {
      final String? headerLine = cursor.readLine();
      if (headerLine == null) {
        break;
      }
      final String header = headerLine.trim();
      if (header.isEmpty) {
        continue;
      }
      if (!header.startsWith('[') || !header.endsWith(']')) {
        return null;
      }
      final String fileName =
          header.substring(1, header.length - 1).trim();
      if (fileName.isEmpty) {
        return null;
      }
      final String? lengthLine = cursor.readLine();
      if (lengthLine == null) {
        return null;
      }
      final int? length = _parseSectionLength(lengthLine);
      if (length == null || length < 0) {
        return null;
      }
      final Uint8List? sectionBytes = cursor.readBytes(length);
      if (sectionBytes == null) {
        return null;
      }
      cursor.consumeLineBreak();

      final String lowerName = fileName.toLowerCase();
      if (lowerName.endsWith('.json')) {
        configBytes ??= sectionBytes;
        continue;
      }
      if (lowerName.endsWith('.txt')) {
        localizationBytes = sectionBytes;
        localizationFileName = fileName;
        continue;
      }
      if (lowerName.endsWith('.svg')) {
        shapeBytes = sectionBytes;
        shapeFileName = fileName;
        shapeType = BrushShapeFileType.svg;
        continue;
      }
      if (lowerName.endsWith('.png.base64')) {
        final String decoded = utf8.decode(sectionBytes, allowMalformed: true);
        final String normalized =
            decoded.replaceAll(RegExp(r'\s+'), '');
        try {
          shapeBytes = Uint8List.fromList(base64.decode(normalized));
        } catch (_) {
          return null;
        }
        shapeFileName =
            fileName.substring(0, fileName.length - '.base64'.length);
        shapeType = BrushShapeFileType.png;
        continue;
      }
      if (lowerName.endsWith('.png')) {
        final String decoded = utf8.decode(sectionBytes, allowMalformed: true);
        final String normalized =
            decoded.replaceAll(RegExp(r'\s+'), '');
        try {
          shapeBytes = Uint8List.fromList(base64.decode(normalized));
        } catch (_) {
          return null;
        }
        shapeFileName = fileName;
        shapeType = BrushShapeFileType.png;
        continue;
      }
    }

    if (configBytes == null) {
      return null;
    }
    final Map<String, dynamic>? config = _decodeConfig(configBytes);
    if (config == null) {
      return null;
    }
    final BrushPreset preset = BrushPreset.fromJson(config);
    final String? configShapeFileName = config['shapeFile'] as String?;
    final String? shapeTypeRaw = config['shapeType'] as String?;
    BrushShapeFileType? resolvedShapeType = shapeType;
    if (resolvedShapeType == null) {
      if (shapeTypeRaw != null) {
        resolvedShapeType = _shapeTypeFromString(shapeTypeRaw);
      } else if (configShapeFileName != null) {
        resolvedShapeType = _shapeTypeFromPath(configShapeFileName);
      }
    }
    final String? resolvedShapeFileName =
        shapeFileName ?? configShapeFileName;
    final String? resolvedLocalizationFileName =
        localizationFileName ?? (config[localizationFileKey] as String?);
    BrushLocalizationTable? localizationTable;
    if (localizationBytes != null) {
      localizationTable = _parseLocalizationTable(localizationBytes);
    }
    return BrushPackageData(
      preset: preset,
      shapeFileName: resolvedShapeFileName,
      shapeType: resolvedShapeType,
      shapeBytes: shapeBytes,
      localizationFileName: resolvedLocalizationFileName,
      localizations: localizationTable,
    );
  }

  static BrushPackageData? _decodeZip(Uint8List bytes) {
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

  static Uint8List _encodeText({
    required BrushPreset preset,
    Uint8List? shapeBytes,
    String? shapeFileName,
    BrushShapeFileType? shapeType,
    BrushLocalizationTable? localizations,
    String? localizationFileName,
  }) {
    final Map<String, dynamic> config = preset.toJson();
    config['formatVersion'] = 1;
    String? resolvedShapeFileName = shapeFileName;
    BrushShapeFileType? resolvedShapeType = shapeType;
    if (resolvedShapeType == null && resolvedShapeFileName != null) {
      resolvedShapeType = _shapeTypeFromPath(resolvedShapeFileName);
    }
    if (resolvedShapeFileName != null) {
      config['shapeFile'] = resolvedShapeFileName;
    }
    if (resolvedShapeType != null) {
      config['shapeType'] = _shapeTypeToString(resolvedShapeType);
    }
    final BrushLocalizationTable? table = localizations;
    String? resolvedLocalizationFile = localizationFileName;
    if (table != null && table.entries.isNotEmpty) {
      resolvedLocalizationFile ??= defaultLocalizationFileName;
      config[localizationFileKey] = resolvedLocalizationFile;
    }
    final String jsonText =
        const JsonEncoder.withIndent('  ').convert(config);
    final Uint8List configBytes = Uint8List.fromList(utf8.encode(jsonText));
    final List<_TextSection> sections = <_TextSection>[
      _TextSection(configFileName, configBytes),
    ];
    if (table != null &&
        table.entries.isNotEmpty &&
        resolvedLocalizationFile != null) {
      final String text = _encodeLocalizationTable(table);
      final Uint8List textBytes = Uint8List.fromList(utf8.encode(text));
      sections.add(_TextSection(resolvedLocalizationFile, textBytes));
    }
    if (shapeBytes != null) {
      String? fileName = resolvedShapeFileName;
      BrushShapeFileType? type = resolvedShapeType;
      if (type == null && fileName != null) {
        type = _shapeTypeFromPath(fileName);
      }
      if (type == null && fileName == null) {
        type = BrushShapeFileType.svg;
        fileName = 'shape.svg';
      } else if (fileName == null && type != null) {
        fileName = type == BrushShapeFileType.svg ? 'shape.svg' : 'shape.png';
      }
      if (fileName != null) {
        if (type == BrushShapeFileType.png) {
          final String encoded = base64.encode(shapeBytes);
          final Uint8List payload =
              Uint8List.fromList(utf8.encode(encoded));
          sections.add(_TextSection(fileName, payload));
        } else {
          sections.add(_TextSection(fileName, shapeBytes));
        }
      }
    }
    return _buildTextPackage(sections);
  }

  static Uint8List _encodeZip({
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

  static bool _startsWithTextMagic(Uint8List bytes) {
    final int offset = _skipUtf8Bom(bytes);
    final List<int> magicBytes = utf8.encode(_textMagic);
    if (bytes.length - offset < magicBytes.length) {
      return false;
    }
    for (int i = 0; i < magicBytes.length; i++) {
      if (bytes[offset + i] != magicBytes[i]) {
        return false;
      }
    }
    return true;
  }

  static int _skipUtf8Bom(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xef &&
        bytes[1] == 0xbb &&
        bytes[2] == 0xbf) {
      return 3;
    }
    return 0;
  }

  static int? _parseSectionLength(String line) {
    final String trimmed = line.trim();
    String? raw;
    if (trimmed.startsWith('length:')) {
      raw = trimmed.substring('length:'.length);
    } else if (trimmed.startsWith('length=')) {
      raw = trimmed.substring('length='.length);
    } else if (trimmed.startsWith('len:')) {
      raw = trimmed.substring('len:'.length);
    } else {
      return null;
    }
    return int.tryParse(raw.trim());
  }

  static Map<String, dynamic>? _decodeConfig(Uint8List bytes) {
    final String jsonText;
    try {
      jsonText = utf8.decode(bytes);
    } catch (_) {
      return null;
    }
    try {
      return jsonDecode(jsonText) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Uint8List _buildTextPackage(List<_TextSection> sections) {
    final BytesBuilder builder = BytesBuilder();
    builder.add(utf8.encode(_textMagic));
    builder.addByte(0x0a);
    for (final _TextSection section in sections) {
      builder.add(utf8.encode('[${section.fileName}]'));
      builder.addByte(0x0a);
      builder.add(utf8.encode('length:${section.bytes.length}'));
      builder.addByte(0x0a);
      builder.add(section.bytes);
      builder.addByte(0x0a);
    }
    return builder.toBytes();
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

class _TextSection {
  _TextSection(this.fileName, this.bytes);

  final String fileName;
  final Uint8List bytes;
}

class _TextCursor {
  _TextCursor(this.bytes, this.offset);

  final Uint8List bytes;
  int offset;

  bool get isDone => offset >= bytes.length;

  String? readLine() {
    if (isDone) {
      return null;
    }
    int end = offset;
    while (end < bytes.length && bytes[end] != 0x0a) {
      end += 1;
    }
    int lineEnd = end;
    if (lineEnd > offset && bytes[lineEnd - 1] == 0x0d) {
      lineEnd -= 1;
    }
    final String line = utf8.decode(
      bytes.sublist(offset, lineEnd),
      allowMalformed: true,
    );
    offset = end < bytes.length ? end + 1 : end;
    return line;
  }

  Uint8List? readBytes(int length) {
    if (length < 0 || offset + length > bytes.length) {
      return null;
    }
    final Uint8List out = Uint8List.sublistView(bytes, offset, offset + length);
    offset += length;
    return out;
  }

  void consumeLineBreak() {
    if (isDone) {
      return;
    }
    if (bytes[offset] == 0x0d) {
      offset += 1;
      if (!isDone && bytes[offset] == 0x0a) {
        offset += 1;
      }
      return;
    }
    if (bytes[offset] == 0x0a) {
      offset += 1;
    }
  }
}
