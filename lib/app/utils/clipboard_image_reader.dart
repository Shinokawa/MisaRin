import 'dart:async';
import 'dart:typed_data';

import 'package:super_clipboard/super_clipboard.dart';

class ClipboardImageData {
  const ClipboardImageData({required this.bytes, this.fileName});

  final Uint8List bytes;
  final String? fileName;
}

class ClipboardImageReader {
  const ClipboardImageReader._();

  static Future<ClipboardImageData?> readImage() async {
    final SystemClipboard? clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return null;
    }
    final ClipboardReader reader = await clipboard.read();
    if (!reader.canProvide(Formats.png)) {
      return null;
    }
    final Completer<Uint8List?> completer = Completer<Uint8List?>();
    final progress = reader.getFile(Formats.png, (file) async {
      try {
        final Uint8List data = await file.readAll();
        completer.complete(data);
      } catch (error) {
        completer.completeError(error);
      }
    });
    if (progress == null) {
      return null;
    }
    final Uint8List? bytes = await completer.future;
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    final String? suggestedName = await reader.getSuggestedName();
    return ClipboardImageData(bytes: bytes, fileName: suggestedName);
  }
}
