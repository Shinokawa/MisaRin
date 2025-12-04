import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

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
    if (kIsWeb) {
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
        _scanSystemFonts,
        _FontScanRequest(directories),
      );
      _cachedFamilies = families.isEmpty ? _fallbackFamilies : families;
      return _cachedFamilies!;
    } catch (_) {
      _cachedFamilies = _fallbackFamilies;
      return _cachedFamilies!;
    }
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

class _FontScanRequest {
  const _FontScanRequest(this.directories);

  final List<String> directories;
}

List<String> _scanSystemFonts(_FontScanRequest request) {
  final Set<String> families = <String>{};
  for (final String path in request.directories) {
    final Directory directory = Directory(path);
    if (!directory.existsSync()) {
      continue;
    }
    try {
      for (final FileSystemEntity entity in directory.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) {
          continue;
        }
        final String ext = p.extension(entity.path).toLowerCase();
        if (ext == '.ttf' || ext == '.otf') {
          final String? family = _readTrueTypeFamily(entity, 0);
          if (family != null && family.trim().isNotEmpty) {
            families.add(family.trim());
          }
        } else if (ext == '.ttc') {
          families.addAll(_readCollectionFamilies(entity));
        }
      }
    } catch (_) {
      // Ignore directories we cannot access.
    }
  }
  final List<String> sorted = families.toList()
    ..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return sorted;
}

Iterable<String> _readCollectionFamilies(File file) sync* {
  RandomAccessFile? raf;
  try {
    raf = file.openSync(mode: FileMode.read);
    final Uint8List header = raf.readSync(12);
    if (header.length < 12) {
      return;
    }
    final String signature = String.fromCharCodes(header.sublist(0, 4));
    if (signature != 'ttcf') {
      final String? family = _readTrueTypeFamily(file, 0);
      if (family != null) {
        yield family;
      }
      return;
    }
    final Uint8List countBytes = raf.readSync(4);
    if (countBytes.length < 4) {
      return;
    }
    final int numFonts = _readUint32(countBytes, 0);
    for (int i = 0; i < numFonts; i++) {
      raf.setPositionSync(12 + i * 4);
      final Uint8List offsetBytes = raf.readSync(4);
      if (offsetBytes.length < 4) {
        continue;
      }
      final int offset = _readUint32(offsetBytes, 0);
      final String? family = _readTrueTypeFamily(file, offset);
      if (family != null && family.trim().isNotEmpty) {
        yield family.trim();
      }
    }
  } catch (_) {
    return;
  } finally {
    raf?.closeSync();
  }
}

String? _readTrueTypeFamily(File file, int offset) {
  RandomAccessFile? raf;
  try {
    raf = file.openSync(mode: FileMode.read);
    raf.setPositionSync(offset);
    final Uint8List header = raf.readSync(12);
    if (header.length < 12) {
      return null;
    }
    final int numTables = _readUint16(header, 4);
    for (int i = 0; i < numTables; i++) {
      raf.setPositionSync(offset + 12 + i * 16);
      final Uint8List record = raf.readSync(16);
      if (record.length < 16) {
        continue;
      }
      final String tag = String.fromCharCodes(record.sublist(0, 4));
      if (tag != 'name') {
        continue;
      }
      final int tableOffset = offset + _readUint32(record, 8);
      final int tableLength = _readUint32(record, 12);
      return _extractName(raf, tableOffset, tableLength);
    }
  } catch (_) {
    return null;
  } finally {
    raf?.closeSync();
  }
  return null;
}

String? _extractName(
  RandomAccessFile raf,
  int offset,
  int length,
) {
  if (length <= 0) {
    return null;
  }
  raf.setPositionSync(offset);
  final Uint8List header = raf.readSync(6);
  if (header.length < 6) {
    return null;
  }
  final int count = _readUint16(header, 2);
  final int stringOffset = _readUint16(header, 4);
  String? fallback;
  for (int i = 0; i < count; i++) {
    raf.setPositionSync(offset + 6 + i * 12);
    final Uint8List record = raf.readSync(12);
    if (record.length < 12) {
      continue;
    }
    final int platformId = _readUint16(record, 0);
    final int encodingId = _readUint16(record, 2);
    final int nameId = _readUint16(record, 6);
    final int lengthBytes = _readUint16(record, 8);
    final int stringPos = _readUint16(record, 10);
    if (nameId != 1 || lengthBytes <= 0) {
      continue;
    }
    raf.setPositionSync(offset + stringOffset + stringPos);
    final Uint8List raw = raf.readSync(lengthBytes);
    final String? decoded = _decodeNameRecord(
      platformId,
      encodingId,
      raw,
    );
    if (decoded == null || decoded.trim().isEmpty) {
      continue;
    }
    if (platformId == 3) {
      return decoded.trim();
    }
    fallback ??= decoded.trim();
  }
  return fallback;
}

String? _decodeNameRecord(int platformId, int encodingId, Uint8List raw) {
  if (platformId == 3) {
    final int length = raw.length & ~1;
    if (length <= 0) {
      return null;
    }
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < length; i += 2) {
      final int codeUnit = (raw[i] << 8) | raw[i + 1];
      buffer.writeCharCode(codeUnit);
    }
    return buffer.toString();
  }
  if (platformId == 1) {
    return String.fromCharCodes(raw);
  }
  if (encodingId == 0) {
    return String.fromCharCodes(raw);
  }
  return null;
}

int _readUint16(Uint8List data, int offset) {
  return (data[offset] << 8) | data[offset + 1];
}

int _readUint32(Uint8List data, int offset) {
  return (data[offset] << 24) |
      (data[offset + 1] << 16) |
      (data[offset + 2] << 8) |
      data[offset + 3];
}
