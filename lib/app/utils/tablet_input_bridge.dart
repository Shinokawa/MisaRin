import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:misa_rin/utils/io_shim.dart';

class TabletInputBridge {
  TabletInputBridge._();

  static final TabletInputBridge instance = TabletInputBridge._();

  final MethodChannel _channel = const MethodChannel('misarin/tablet_input');
    final StreamController<void> _pencilDoubleTapController =
      StreamController<void>.broadcast();
  bool _initialized = false;
  final Map<int, _TabletSample> _samples = <int, _TabletSample>{};

  bool get _supportMacOS => !kIsWeb && Platform.isMacOS;
    bool get _supportApplePencilTapChannel =>
      !kIsWeb && (Platform.isMacOS || Platform.isIOS);

    Stream<void> get pencilDoubleTapEvents => _pencilDoubleTapController.stream;

  void ensureInitialized() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    if (!_supportApplePencilTapChannel) {
      return;
    }
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'pencilDoubleTap') {
      _pencilDoubleTapController.add(null);
      return;
    }
    if (call.method != 'tabletEvent') {
      return;
    }
    final Map<dynamic, dynamic>? raw = call.arguments as Map<dynamic, dynamic>?;
    if (raw == null) {
      return;
    }
    final int? deviceId = raw['device'] as int?;
    if (deviceId == null) {
      return;
    }
    final double pressure = (raw['pressure'] as num?)?.toDouble() ?? 0.0;
    final double pressureMin = (raw['pressureMin'] as num?)?.toDouble() ?? 0.0;
    final double pressureMax = (raw['pressureMax'] as num?)?.toDouble() ?? 1.0;
    final bool inContact = raw['inContact'] as bool? ?? false;
    _samples[deviceId] = _TabletSample(
      pressure: pressure,
      min: pressureMin,
      max: pressureMax,
      inContact: inContact,
    );
    if (!inContact && pressure <= 0.0) {
      _samples.remove(deviceId);
    }
  }

  bool isTabletPointer(PointerEvent event) {
    if (event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus) {
      return true;
    }
    if (!_supportMacOS) {
      return false;
    }
    final _TabletSample? sample = _sampleForPointer(event);
    if (sample == null) {
      return false;
    }
    return sample.inContact || sample.pressure > 0.0;
  }

  double? pressureForEvent(PointerEvent? event) {
    if (event == null) {
      return null;
    }
    if (event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus) {
      final double value = event.pressure;
      if (value.isFinite) {
        return value.clamp(0.0, 1.0);
      }
      return null;
    }
    if (!_supportMacOS) {
      return null;
    }
    final _TabletSample? sample = _sampleForPointer(event);
    if (sample == null) {
      return null;
    }
    if (!sample.inContact && !event.down) {
      return null;
    }
    return sample.pressure.clamp(0.0, 1.0);
  }

  _TabletSample? _sampleForPointer(PointerEvent event) {
    final _TabletSample? direct = _samples[event.device];
    if (direct != null) {
      return direct;
    }
    if (_samples.isEmpty) {
      return null;
    }
    if (_samples.length == 1) {
      return _samples.values.first;
    }
    for (final _TabletSample sample in _samples.values) {
      if (sample.inContact) {
        return sample;
      }
    }
    return _samples.values.first;
  }
}

class _TabletSample {
  const _TabletSample({
    required this.pressure,
    required this.min,
    required this.max,
    required this.inContact,
  });

  final double pressure;
  final double min;
  final double max;
  final bool inContact;
}
