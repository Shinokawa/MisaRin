import 'dart:convert';

import 'package:misa_rin/utils/io_shim.dart';
import 'package:path/path.dart' as p;

class RecentProjectsIndex {
  RecentProjectsIndex(this.projectRoot);

  final Directory projectRoot;

  File get _indexFile => File(p.join(projectRoot.path, 'recent_projects.json'));

  Future<List<RecentProjectRecord>> entries() async {
    try {
      if (!await _indexFile.exists()) {
        return const <RecentProjectRecord>[];
      }
      final String content = await _indexFile.readAsString();
      if (content.trim().isEmpty) {
        return const <RecentProjectRecord>[];
      }
      final List<dynamic> raw = jsonDecode(content) as List<dynamic>;
      return raw
          .map(
            (dynamic item) =>
                RecentProjectRecord.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
    } catch (_) {
      return const <RecentProjectRecord>[];
    }
  }

  Future<void> touch(String projectPath) async {
    final DateTime now = DateTime.now();
    final List<RecentProjectRecord> current = await entries();
    final List<RecentProjectRecord> updated = <RecentProjectRecord>[];
    bool found = false;
    for (final RecentProjectRecord entry in current) {
      if (entry.path == projectPath) {
        updated.add(entry.copyWith(lastOpened: now));
        found = true;
      } else {
        updated.add(entry);
      }
    }
    if (!found) {
      updated.add(RecentProjectRecord(path: projectPath, lastOpened: now));
    }
    updated.sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
    await _writeEntries(updated);
  }

  Future<void> remove(String projectPath) async {
    final List<RecentProjectRecord> current = await entries();
    final List<RecentProjectRecord> filtered = current
        .where((entry) => entry.path != projectPath)
        .toList(growable: false);
    await _writeEntries(filtered);
  }

  Future<void> _writeEntries(List<RecentProjectRecord> entries) async {
    final String json = jsonEncode(
      entries.map((entry) => entry.toJson()).toList(growable: false),
    );
    await _indexFile.create(recursive: true);
    await _indexFile.writeAsString(json, flush: true);
  }
}

class RecentProjectRecord {
  const RecentProjectRecord({required this.path, required this.lastOpened});

  final String path;
  final DateTime lastOpened;

  RecentProjectRecord copyWith({String? path, DateTime? lastOpened}) {
    return RecentProjectRecord(
      path: path ?? this.path,
      lastOpened: lastOpened ?? this.lastOpened,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'path': path,
      'lastOpened': lastOpened.toIso8601String(),
    };
  }

  factory RecentProjectRecord.fromJson(Map<String, dynamic> json) {
    return RecentProjectRecord(
      path: json['path'] as String,
      lastOpened: DateTime.parse(json['lastOpened'] as String),
    );
  }
}
