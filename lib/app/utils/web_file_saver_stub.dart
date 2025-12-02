import 'dart:typed_data';

Future<void> saveBytes({
  required String fileName,
  required Uint8List bytes,
  String mimeType = 'application/octet-stream',
}) {
  throw UnsupportedError('当前平台不支持浏览器下载。');
}
