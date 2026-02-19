import 'package:flutter/foundation.dart';
import 'package:misa_rin/utils/io_shim.dart';

class BrushPresetTimeline {
  const BrushPresetTimeline._();

  static final bool _enabled = _resolveEnabled();

  static bool get enabled => _enabled;

  static DateTime? _start;
  static DateTime? _last;

  static void start(String label) {
    if (!_enabled) {
      return;
    }
    _start = null;
    _last = null;
    mark(label);
  }

  static void mark(String label) {
    if (!_enabled) {
      return;
    }
    final DateTime now = DateTime.now();
    _start ??= now;
    final int fromStartMs = now.difference(_start!).inMilliseconds;
    final int fromLastMs =
        _last == null ? 0 : now.difference(_last!).inMilliseconds;
    debugPrint(
      '[brush_preset_timeline] +${fromStartMs}ms (+${fromLastMs}ms) $label',
    );
    _last = now;
  }

  static bool _resolveEnabled() {
    const bool compileTime = bool.fromEnvironment(
      'MISA_RIN_DEBUG_BRUSH_PRESET',
      defaultValue: false,
    );
    if (compileTime) {
      return true;
    }
    final String? env = Platform.environment['MISA_RIN_DEBUG_BRUSH_PRESET'];
    if (env == null) {
      return false;
    }
    final String normalized = env.trim().toLowerCase();
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'on';
  }
}
