part of 'app_preferences.dart';

Future<Uint8List?> _readPreferencesPayload() async {
  if (kIsWeb) {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? encoded = prefs.getString(_preferencesStorageKey);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      return Uint8List.fromList(base64Decode(encoded));
    } catch (_) {
      return null;
    }
  }
  final File file = await _preferencesFile();
  if (!await file.exists()) {
    return null;
  }
  return file.readAsBytes();
}

Future<void> _writePreferencesPayload(Uint8List bytes) async {
  if (kIsWeb) {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferencesStorageKey, base64Encode(bytes));
    return;
  }
  final File file = await _preferencesFile();
  await file.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

Future<File> _preferencesFile() async {
  if (kIsWeb) {
    throw UnsupportedError(
      'Preferences file storage is not available on web',
    );
  }
  final base = await getApplicationDocumentsDirectory();
  final Directory directory = Directory(p.join(base.path, _folderName));
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  return File(p.join(directory.path, _fileName));
}
