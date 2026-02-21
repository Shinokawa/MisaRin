import 'dart:io';
import 'package:misa_rin/app/sai2/sai2_codec.dart';

void main() {
  final file = File('/Users/dfsteve/Downloads/新建画布2.sai2');
  final bytes = file.readAsBytesSync();
  final decoded = Sai2Codec.decodeFromBytes(bytes);
  print('decoded ${decoded.width}x${decoded.height}');
  final rgba = decoded.rgbaBytes;
  print('first pixel rgba: ${rgba[0]},${rgba[1]},${rgba[2]},${rgba[3]}');
  final mid = (decoded.width ~/ 2) + (decoded.height ~/ 2) * decoded.width;
  final offset = mid * 4;
  print('mid pixel rgba: ${rgba[offset]},${rgba[offset + 1]},${rgba[offset + 2]},${rgba[offset + 3]}');
}
