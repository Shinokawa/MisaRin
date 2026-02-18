import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../utils/platform_target.dart';
import 'menu_action_dispatcher.dart';

VoidCallback? wrapMenuAction(MenuAsyncAction? action) {
  if (action == null) {
    return null;
  }
  return () => unawaited(Future.sync(action));
}

String? formatMenuShortcut(MenuSerializableShortcut? shortcut) {
  if (shortcut == null) {
    return null;
  }
  if (shortcut is! SingleActivator) {
    return null;
  }
  final bool isMac = isResolvedPlatformMacOS();
  final List<String> parts = <String>[];

  if (shortcut.control) {
    parts.add(isMac ? '⌃' : 'Ctrl');
  }
  if (shortcut.meta) {
    parts.add(isMac ? '⌘' : 'Ctrl');
  }
  if (shortcut.alt) {
    parts.add(isMac ? '⌥' : 'Alt');
  }
  if (shortcut.shift) {
    parts.add(isMac ? '⇧' : 'Shift');
  }

  final String keyLabel = _describeLogicalKey(shortcut.trigger);
  if (keyLabel.isNotEmpty) {
    parts.add(isMac ? keyLabel : keyLabel.toUpperCase());
  }

  if (parts.isEmpty) {
    return null;
  }

  return isMac ? parts.join() : parts.join('+');
}

String _describeLogicalKey(LogicalKeyboardKey key) {
  final String label = key.keyLabel;
  if (label.isNotEmpty) {
    if (label.length == 1 &&
        label.codeUnitAt(0) >= 97 &&
        label.codeUnitAt(0) <= 122) {
      return label.toUpperCase();
    }
    return label;
  }
  return key.debugName ?? '';
}
