import 'dart:async';
import 'dart:isolate';

import '../app/widgets/canvas_toolbar.dart';

class BoardLayoutInput {
  const BoardLayoutInput({
    required this.workspaceWidth,
    required this.workspaceHeight,
    required this.toolButtonPadding,
    required this.toolSettingsSpacing,
    required this.sidePanelWidth,
  });

  final double workspaceWidth;
  final double workspaceHeight;
  final double toolButtonPadding;
  final double toolSettingsSpacing;
  final double sidePanelWidth;
}

class BoardLayoutMetrics {
  const BoardLayoutMetrics({
    required this.layout,
    required this.toolSettingsLeft,
    required this.sidebarLeft,
    this.toolSettingsMaxWidth,
  });

  final CanvasToolbarLayout layout;
  final double toolSettingsLeft;
  final double sidebarLeft;
  final double? toolSettingsMaxWidth;
}

class BoardLayoutWorker {
  BoardLayoutWorker()
      : _receivePort = ReceivePort(),
        _pending = <int, Completer<Map<String, Object?>>>{},
        _sendPortCompleter = Completer<SendPort>() {
    _subscription = _receivePort.listen(_handleMessage);
  }

  final ReceivePort _receivePort;
  final Completer<SendPort> _sendPortCompleter;
  late final StreamSubscription<Object?> _subscription;
  final Map<int, Completer<Map<String, Object?>>> _pending;
  Isolate? _isolate;
  SendPort? _sendPort;
  int _nextId = 0;

  Future<void> _ensureStarted() async {
    if (_isolate != null) {
      return;
    }
    _isolate = await Isolate.spawn<SendPort>(
      _layoutWorkerMain,
      _receivePort.sendPort,
      debugName: 'BoardLayoutWorker',
      errorsAreFatal: false,
    );
    _sendPort = await _sendPortCompleter.future;
  }

  Future<BoardLayoutMetrics> compute(BoardLayoutInput input) async {
    await _ensureStarted();
    final Map<String, Object?> response = await _sendRequest(<String, Object?>{
      'workspaceWidth': input.workspaceWidth,
      'workspaceHeight': input.workspaceHeight,
      'toolButtonPadding': input.toolButtonPadding,
      'toolSettingsSpacing': input.toolSettingsSpacing,
      'sidePanelWidth': input.sidePanelWidth,
    });
    final CanvasToolbarLayout layout = CanvasToolbarLayout(
      columns: response['columns'] as int? ?? 1,
      rows: response['rows'] as int? ?? CanvasToolbar.buttonCount,
      width: (response['layoutWidth'] as num? ?? 0).toDouble(),
      height: (response['layoutHeight'] as num? ?? 0).toDouble(),
    );
    final double toolSettingsLeft =
        (response['toolSettingsLeft'] as num? ?? 0).toDouble();
    final double sidebarLeft =
        (response['sidebarLeft'] as num? ?? 0).toDouble();
    final double? toolSettingsMaxWidth = response['toolSettingsMaxWidth'] == null
        ? null
        : (response['toolSettingsMaxWidth'] as num).toDouble();
    return BoardLayoutMetrics(
      layout: layout,
      toolSettingsLeft: toolSettingsLeft,
      sidebarLeft: sidebarLeft,
      toolSettingsMaxWidth: toolSettingsMaxWidth,
    );
  }

  Future<Map<String, Object?>> _sendRequest(
    Map<String, Object?> request,
  ) async {
    await _ensureStarted();
    final SendPort port = _sendPort!;
    final Completer<Map<String, Object?>> completer =
        Completer<Map<String, Object?>>();
    final int id = _nextId++;
    _pending[id] = completer;
    port.send(<String, Object?>{'id': id, 'request': request});
    return completer.future;
  }

  void _handleMessage(Object? message) {
    if (message is SendPort) {
      if (!_sendPortCompleter.isCompleted) {
        _sendPortCompleter.complete(message);
      }
      return;
    }
    if (message is! Map<String, Object?>) {
      return;
    }
    final int id = message['id'] as int? ?? -1;
    final Map<String, Object?>? data =
        message['response'] as Map<String, Object?>?;
    final Completer<Map<String, Object?>>? completer = _pending.remove(id);
    if (data == null) {
      completer?.completeError(StateError('Invalid layout response'));
    } else {
      completer?.complete(data);
    }
  }

  Future<void> dispose() async {
    final Isolate? isolate = _isolate;
    if (isolate != null) {
      _sendPort?.send(null);
      isolate.kill(priority: Isolate.immediate);
      _isolate = null;
    }
    await _subscription.cancel();
    _receivePort.close();
    if (!_sendPortCompleter.isCompleted) {
      _sendPortCompleter.completeError(StateError('Worker disposed'));
    }
    for (final Completer<Map<String, Object?>> completer
        in _pending.values) {
      completer.completeError(StateError('Layout worker disposed'));
    }
    _pending.clear();
  }
}

@pragma('vm:entry-point')
void _layoutWorkerMain(SendPort replyPort) {
  final ReceivePort commandPort = ReceivePort();
  replyPort.send(commandPort.sendPort);
  commandPort.listen((Object? message) {
    if (message == null) {
      commandPort.close();
      return;
    }
    if (message is! Map<String, Object?>) {
      return;
    }
    final int id = message['id'] as int? ?? -1;
    final Map<String, Object?> request =
        (message['request'] as Map<String, Object?>?) ?? const <String, Object?>{};
    final Map<String, Object?> response = _computeLayoutResponse(request);
    replyPort.send(<String, Object?>{'id': id, 'response': response});
  });
}

Map<String, Object?> _computeLayoutResponse(Map<String, Object?> request) {
  final double workspaceWidth =
      (request['workspaceWidth'] as num? ?? 0).toDouble();
  final double workspaceHeight =
      (request['workspaceHeight'] as num? ?? 0).toDouble();
  final double toolButtonPadding =
      (request['toolButtonPadding'] as num? ?? 0).toDouble();
  final double toolSettingsSpacing =
      (request['toolSettingsSpacing'] as num? ?? 0).toDouble();
  final double sidePanelWidth =
      (request['sidePanelWidth'] as num? ?? 0).toDouble();
  final double availableToolbarHeight =
      workspaceHeight - toolButtonPadding * 2;
  final CanvasToolbarLayout layout =
      CanvasToolbar.layoutForAvailableHeight(availableToolbarHeight);
  final double toolSettingsLeft =
      toolButtonPadding + layout.width + toolSettingsSpacing;
  final double sidebarLeft =
      (workspaceWidth - sidePanelWidth - toolButtonPadding).clamp(
        0.0,
        double.infinity,
      );
  final double computedToolSettingsMaxWidth =
      sidebarLeft - toolSettingsLeft - toolSettingsSpacing;
  final double? toolSettingsMaxWidth = computedToolSettingsMaxWidth.isFinite &&
          computedToolSettingsMaxWidth > 0
      ? computedToolSettingsMaxWidth
      : null;
  return <String, Object?>{
    'columns': layout.columns,
    'rows': layout.rows,
    'layoutWidth': layout.width,
    'layoutHeight': layout.height,
    'toolSettingsLeft': toolSettingsLeft,
    'sidebarLeft': sidebarLeft,
    'toolSettingsMaxWidth': toolSettingsMaxWidth,
  };
}
