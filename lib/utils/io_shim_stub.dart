import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

abstract class FileSystemEntity {
  String get path;
}

class File implements FileSystemEntity {
  File(this.path);

  @override
  final String path;

  Directory get parent => Directory(_parentOf(path));

  Future<bool> exists() async => false;
  bool existsSync() => false;

  Future<Uint8List> readAsBytes() async {
    debugPrint('File.readAsBytes is not supported on web: $path');
    return Uint8List(0);
  }

  Future<String> readAsString() async {
    debugPrint('File.readAsString is not supported on web: $path');
    return '';
  }

  String readAsStringSync() {
    debugPrint('File.readAsStringSync is not supported on web: $path');
    return '';
  }

  Future<File> create({bool recursive = false}) async {
    debugPrint('File.create is not supported on web: $path');
    return this;
  }

  Future<File> writeAsBytes(
    List<int> bytes, {
    bool flush = false,
  }) async {
    debugPrint('File.writeAsBytes is not supported on web: $path');
    return this;
  }

  Future<File> writeAsString(
    String contents, {
    bool flush = false,
  }) async {
    debugPrint('File.writeAsString is not supported on web: $path');
    return this;
  }

  Future<void> delete() async {
    debugPrint('File.delete is not supported on web: $path');
  }

  Future<int> length() async => 0;

  Future<DateTime> lastModified() async => DateTime.fromMillisecondsSinceEpoch(0);
}

class Directory implements FileSystemEntity {
  Directory(this.path);

  @override
  final String path;

  static Directory get systemTemp => Directory('');
  static Directory get current => Directory('');

  Future<bool> exists() async => false;
  bool existsSync() => false;

  Future<Directory> create({bool recursive = false}) async {
    debugPrint('Directory.create is not supported on web: $path');
    return this;
  }

  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) {
    return Stream<FileSystemEntity>.empty();
  }

  List<FileSystemEntity> listSync({bool recursive = false, bool followLinks = true}) {
    return const <FileSystemEntity>[];
  }
}

class ProcessResult {
  ProcessResult(this.exitCode, this.stdout, this.stderr);

  final int exitCode;
  final Object? stdout;
  final Object? stderr;
}

class Process {
  static Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Object? stdoutEncoding,
    Object? stderrEncoding,
  }) async {
    debugPrint('Process.run is not supported on web: $executable');
    return ProcessResult(0, null, null);
  }
}

class Platform {
  static bool get isMacOS => defaultTargetPlatform == TargetPlatform.macOS;
  static bool get isWindows => defaultTargetPlatform == TargetPlatform.windows;
  static bool get isLinux => defaultTargetPlatform == TargetPlatform.linux;
  static bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;

  static String get pathSeparator => isWindows ? '\\\\' : '/';

  static Map<String, String> get environment => const <String, String>{};

  static String get resolvedExecutable => '';
}

String _parentOf(String value) {
  if (value.isEmpty) {
    return '';
  }
  String normalized = value.replaceAll('\\', '/');
  if (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  final int index = normalized.lastIndexOf('/');
  if (index <= 0) {
    return '';
  }
  return normalized.substring(0, index);
}
