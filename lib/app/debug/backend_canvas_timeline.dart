import 'package:flutter/foundation.dart';

class BackendCanvasTimeline {
  const BackendCanvasTimeline._();

  static final bool _enabled =
      bool.fromEnvironment(
        'MISA_RIN_DEBUG_BACKEND_CANVAS_TIMELINE',
        defaultValue: false,
      ) ||
      bool.fromEnvironment(
        'MISA_RIN_DEBUG_BACKEND_CANVAS_INPUT',
        defaultValue: false,
      ) ||
      bool.fromEnvironment(
        'MISA_RIN_DEBUG_RUST_CANVAS_INPUT',
        defaultValue: false,
      );

  static DateTime? _start;
  static DateTime? _last;

  static void start(String label) {
    if (!_enabled) {
      return;
    }
    reset();
    mark(label);
  }

  static void reset() {
    if (!_enabled) {
      return;
    }
    _start = null;
    _last = null;
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
      '[backend_canvas_timeline] +${fromStartMs}ms (+${fromLastMs}ms) '
      '$label @ ${now.toIso8601String()}',
    );
    _last = now;
  }
}
