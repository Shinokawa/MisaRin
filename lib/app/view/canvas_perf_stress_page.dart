import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

import '../../canvas/canvas_layer.dart';
import '../../canvas/canvas_settings.dart';
import '../../performance/canvas_perf_stress.dart';
import '../widgets/painting_board.dart';

class CanvasPerfStressPage extends StatefulWidget {
  const CanvasPerfStressPage({super.key});

  @override
  State<CanvasPerfStressPage> createState() => _CanvasPerfStressPageState();
}

class _CanvasPerfStressPageState extends State<CanvasPerfStressPage> {
  static const int _kCanvasSize = 2048;
  static const int _kLayerCount = 4;

  final GlobalKey<PaintingBoardState> _boardKey =
      GlobalKey<PaintingBoardState>();

  late final CanvasSettings _settings;
  late final List<CanvasLayerData> _layers;

  bool _started = false;
  bool _running = false;
  CanvasPerfStressReport? _report;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _settings = CanvasSettings(
      width: _kCanvasSize.toDouble(),
      height: _kCanvasSize.toDouble(),
      backgroundColor: const Color(0xFFFFFFFF),
    );
    _layers = <CanvasLayerData>[
      CanvasLayerData(
        id: generateLayerId(),
        name: '背景',
        fillColor: const Color(0xFFFFFFFF),
      ),
      for (int i = 2; i <= _kLayerCount; i++)
        CanvasLayerData(
          id: generateLayerId(),
          name: '图层 $i',
        ),
    ];
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _handleBoardReadyChanged(bool ready) {
    if (!ready || _started) {
      return;
    }
    _started = true;
    unawaited(_run());
  }

  Future<void> _run() async {
    if (_running) {
      return;
    }
    final PaintingBoardState? board = _boardKey.currentState;
    if (board == null) {
      return;
    }
    setState(() {
      _running = true;
      _report = null;
      _error = null;
    });
    CanvasPerfStressReport? report;
    Object? error;
    try {
      report = await board.runCanvasPerfStressTest(
        duration: const Duration(seconds: 10),
        targetPointsPerSecond: 1000,
      );
    } catch (e, stackTrace) {
      debugPrint('Perf stress test failed: $e\n$stackTrace');
      error = e;
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _report = report;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      content: ScaffoldPage(
        padding: EdgeInsets.zero,
        content: Stack(
          children: [
            Positioned.fill(
              child: PaintingBoard(
                key: _boardKey,
                settings: _settings,
                initialLayers: _layers,
                onRequestExit: () {},
                onReadyChanged: _handleBoardReadyChanged,
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: _buildOverlay(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final CanvasPerfStressReport? report = _report;
    final Object? error = _error;
    final FluentThemeData theme = FluentTheme.of(context);

    final List<Widget> lines = <Widget>[
      Text(
        '画布压测（2048² / 4 层 / 10s 连续画）',
        style: theme.typography.subtitle,
      ),
      const SizedBox(height: 6),
      if (_running) Text('运行中…（请勿操作）', style: theme.typography.caption),
      if (!_running && report == null && error == null)
        Text('等待画布初始化…', style: theme.typography.caption),
      if (error != null)
        Text(
          '失败：$error',
          style: theme.typography.caption?.copyWith(color: Colors.red),
        ),
      if (report != null) ...[
        Text(
          'input→present P50/P95: '
          '${report.presentLatencyP50Ms.toStringAsFixed(2)}/'
          '${report.presentLatencyP95Ms.toStringAsFixed(2)} ms',
          style: theme.typography.caption,
        ),
        Text(
          '吞吐: ${report.pointsPerSecond.toStringAsFixed(1)} 点/秒',
          style: theme.typography.caption,
        ),
        Text(
          'UI build P95: ${report.uiBuildP95Ms.toStringAsFixed(2)} ms',
          style: theme.typography.caption,
        ),
      ],
      const SizedBox(height: 8),
      FilledButton(
        onPressed: _running ? null : _run,
        child: Text(report == null ? '开始压测' : '再跑一次'),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.micaBackgroundColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.resources.controlStrokeColorDefault,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: lines,
      ),
    );
  }
}
