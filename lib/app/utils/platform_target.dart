import 'package:flutter/foundation.dart';

import 'platform_target_stub.dart'
    if (dart.library.html) 'platform_target_web.dart';

TargetPlatform resolvedTargetPlatform() {
  if (!kIsWeb) {
    return defaultTargetPlatform;
  }
  return detectWebTargetPlatform() ?? defaultTargetPlatform;
}

bool isResolvedPlatformMacOS() {
  return resolvedTargetPlatform() == TargetPlatform.macOS;
}
