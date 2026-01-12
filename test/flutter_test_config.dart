import 'dart:async';

import 'package:misa_rin/src/rust/rust_init.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await ensureRustInitialized();
  await testMain();
}

