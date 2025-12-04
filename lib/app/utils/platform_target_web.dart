import 'dart:html' as html;

import 'package:flutter/foundation.dart';

TargetPlatform? detectWebTargetPlatform() {
  final navigator = html.window.navigator;
  final buffer = StringBuffer();

  void addLowerCase(String? value) {
    if (value == null || value.isEmpty) {
      return;
    }
    buffer.write(value.toLowerCase());
    buffer.write(' ');
  }

  addLowerCase(navigator.platform);
  addLowerCase(navigator.userAgent);

  final combined = buffer.toString();
  if (combined.isEmpty) {
    return null;
  }

  TargetPlatform? matchPlatform(List<String> keywords, TargetPlatform platform) {
    for (final keyword in keywords) {
      if (combined.contains(keyword)) {
        return platform;
      }
    }
    return null;
  }

  return matchPlatform(const ['mac', 'darwin'], TargetPlatform.macOS) ??
      matchPlatform(const ['iphone', 'ipad', 'ios'], TargetPlatform.iOS) ??
      matchPlatform(const ['android'], TargetPlatform.android) ??
      matchPlatform(const ['win'], TargetPlatform.windows) ??
      matchPlatform(const ['linux', 'cros'], TargetPlatform.linux);
}
