import 'dart:typed_data';

import '../src/rust/frb_generated.dart';
import '../src/rust/rust_init.dart';

Future<dynamic> importPsdBytes(Uint8List data) async {
  await ensureRustInitialized();
  // NOTE: Use dynamic to avoid compile errors before codegen.
  // ignore: invalid_use_of_internal_member
  final dynamic api = RustLib.instance.api;
  return api.crateApiPsdImportPsd(bytes: data);
}
