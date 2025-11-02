import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../canvas/canvas_settings.dart';
import 'project_binary_codec.dart';
import 'project_document.dart';
import 'recent_projects_index.dart';

class ProjectRepository {
  ProjectRepository._();

  static final ProjectRepository instance = ProjectRepository._();

  Directory? _projectDirectory;
  RecentProjectsIndex? _recentIndex;

  static const String _folderName = 'MisaRin';

  Future<Directory> _ensureProjectDirectory() async {
    if (_projectDirectory != null) {
      return _projectDirectory!;
    }
    final Directory base = await getApplicationDocumentsDirectory();
    final Directory directory = Directory(p.join(base.path, _folderName));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _projectDirectory = directory;
    _recentIndex = RecentProjectsIndex(directory);
    return directory;
  }

  Future<ProjectDocument> saveDocument(ProjectDocument document) async {
    final Directory directory = await _ensureProjectDirectory();
    final String fileName = document.path == null
        ? _buildFileName(document)
        : p.basename(document.path!);
    final String absolutePath = p.join(directory.path, fileName);
    final ProjectDocument resolved = document.copyWith(
      path: absolutePath,
      updatedAt: DateTime.now(),
    );
    final Uint8List binary = ProjectBinaryCodec.encode(resolved);
    final File file = File(absolutePath);
    await file.writeAsBytes(binary, flush: true);
    await _recentIndex?.touch(absolutePath);
    return resolved;
  }

  Future<ProjectDocument> saveDocumentAs(
    ProjectDocument document,
    String absolutePath,
  ) async {
    await _ensureProjectDirectory();
    final File file = File(absolutePath);
    await file.parent.create(recursive: true);
    final ProjectDocument resolved = document.copyWith(
      path: absolutePath,
      updatedAt: DateTime.now(),
    );
    final Uint8List binary = ProjectBinaryCodec.encode(resolved);
    await file.writeAsBytes(binary, flush: true);
    await _recentIndex?.touch(absolutePath);
    return resolved;
  }

  Future<ProjectDocument> loadDocument(String path) async {
    await _ensureProjectDirectory();
    final File file = File(path);
    final Uint8List bytes = await file.readAsBytes();
    final ProjectDocument document = ProjectBinaryCodec.decode(
      bytes,
      path: path,
    );
    await _recentIndex?.touch(path);
    return document;
  }

  Future<List<ProjectSummary>> listRecentProjects() async {
    await _ensureProjectDirectory();
    final List<ProjectSummary> summaries = <ProjectSummary>[];
    final List<_IndexedEntry> entries = await _loadIndexEntries();
    for (final _IndexedEntry entry in entries) {
      final File file = File(entry.path);
      if (!await file.exists()) {
        await _recentIndex?.remove(entry.path);
        continue;
      }
      try {
        final Uint8List bytes = await file.readAsBytes();
        final ProjectSummary summary = ProjectBinaryCodec.decodeSummary(
          bytes,
          path: entry.path,
          lastOpened: entry.lastOpened,
        );
        summaries.add(summary);
      } catch (_) {
        // ignore malformed entries
      }
    }
    summaries.sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
    return summaries;
  }

  Future<void> deleteProject(String path) async {
    await _ensureProjectDirectory();
    final File file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    await _recentIndex?.remove(path);
  }

  Future<List<_IndexedEntry>> _loadIndexEntries() async {
    final List<_IndexedEntry> entries = <_IndexedEntry>[];
    final List<RecentProjectRecord> raw = await (_recentIndex?.entries() ??
        Future<List<RecentProjectRecord>>.value(
          const <RecentProjectRecord>[],
        ));
    for (final RecentProjectRecord entry in raw) {
      entries.add(_IndexedEntry(entry.path, entry.lastOpened));
    }
    return entries;
  }

  String _buildFileName(ProjectDocument document) {
    final String sanitizedName = document.name
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    final String namePart = sanitizedName.isEmpty ? 'project' : sanitizedName;
    return '${document.id}_$namePart.rin';
  }

  Future<ProjectDocument> createDocumentFromSettings(
    CanvasSettings settings, {
    String name = '未命名项目',
  }) async {
    await _ensureProjectDirectory();
    return ProjectDocument.newProject(settings: settings, name: name);
  }
}

class _IndexedEntry {
  const _IndexedEntry(this.path, this.lastOpened);

  final String path;
  final DateTime lastOpened;
}
