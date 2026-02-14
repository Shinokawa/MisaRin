import 'package:flutter/foundation.dart';

class BackendCanvasTimeline {
  const BackendCanvasTimeline._();

  static DateTime? _start;
  static DateTime? _last;

  static void start(String label) {
    reset();
    mark(label);
  }

  static void reset() {
    _start = null;
    _last = null;
  }

  static void mark(String label) {
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
