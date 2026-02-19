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
  });

  final BrushPreset preset;
  final String? shapeFileName;
  final BrushShapeFileType? shapeType;
  final Uint8List? shapeBytes;
}

class BrushPackageCodec {
  static const String configFileName = 'brush.json';

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
    return BrushPackageData(
      preset: preset,
      shapeFileName: shapeFileName,
      shapeType: shapeType,
      shapeBytes: shapeBytes,
    );
  }

  static Uint8List encode({
    required BrushPreset preset,
    Uint8List? shapeBytes,
    String? shapeFileName,
    BrushShapeFileType? shapeType,
  }) {
    final Map<String, dynamic> config = preset.toJson();
    config['formatVersion'] = 1;
    if (shapeFileName != null) {
      config['shapeFile'] = shapeFileName;
    }
    if (shapeType != null) {
      config['shapeType'] = _shapeTypeToString(shapeType);
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
    final List<int>? out = ZipEncoder().encode(archive);
    return Uint8List.fromList(out ?? const <int>[]);
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
