import 'dart:math' as math;
import 'dart:ui';

import 'stroke_dynamics.dart';
import 'stroke_sample.dart';
import 'velocity_smoother.dart';

enum SimulatedTailType { line, point }

class SimulatedTailInstruction {
  const SimulatedTailInstruction.line({
    required this.start,
    required this.end,
    required this.startRadius,
    required this.endRadius,
  })  : type = SimulatedTailType.line,
        point = null,
        pointRadius = null;

  const SimulatedTailInstruction.point({
    required this.point,
    required this.pointRadius,
  })  : type = SimulatedTailType.point,
        start = null,
        end = null,
        startRadius = null,
        endRadius = null;

  final SimulatedTailType type;
  final Offset? start;
  final Offset? end;
  final double? startRadius;
  final double? endRadius;
  final Offset? point;
  final double? pointRadius;

  bool get isLine => type == SimulatedTailType.line;
  bool get isPoint => type == SimulatedTailType.point;
}

/// 封装模拟笔压计算逻辑，便于 BitmapCanvasController 复用。
class StrokePressureSimulator {
  final StrokeDynamics _strokeDynamics = StrokeDynamics();
  final StrokeSampleSeries _strokeSamples = StrokeSampleSeries();
  final VelocitySmoother _velocitySmoother = VelocitySmoother();

  StrokePressureProfile _profile = StrokePressureProfile.auto;
  bool _simulatingStroke = false;

  bool get isSimulatingStroke => _simulatingStroke;

  /// 准备一次新的笔压模拟，返回起笔的半径（若处于模拟模式）。
  double? beginStroke({
    required Offset position,
    required double timestampMillis,
    required double baseRadius,
    required bool simulatePressure,
  }) {
    _strokeSamples.clear();
    _velocitySmoother.reset();
    _strokeSamples.add(position, timestampMillis);
    _velocitySmoother.addSample(position, timestampMillis);

    _simulatingStroke = simulatePressure;
    if (!_simulatingStroke) {
      return null;
    }

    _strokeDynamics.start(baseRadius, profile: _profile);
    return _strokeDynamics.initialRadius();
  }

  /// 计算下一段笔触的半径，内部会维护采样与速度数据。
  double? sampleNextRadius({
    required Offset lastPosition,
    required Offset position,
    double? timestampMillis,
    double? deltaTimeMillis,
  }) {
    if (!_simulatingStroke) {
      return null;
    }
    final double delta = (position - lastPosition).distance;
    final double sampleTimestamp = resolveSampleTimestamp(
      timestampMillis,
      deltaTimeMillis,
    );
    final StrokeSample sample = _strokeSamples.add(position, sampleTimestamp);
    final double normalizedSpeed =
        _velocitySmoother.addSample(position, sampleTimestamp);
    final StrokeSampleMetrics? metrics =
        _profile == StrokePressureProfile.auto
            ? StrokeSampleMetrics(
                sampleIndex: _strokeSamples.length - 1,
                normalizedSpeed: normalizedSpeed,
                stationaryDuration: sample.stationaryDuration,
                totalDistance: _strokeSamples.totalDistance,
                totalTime: _strokeSamples.totalTime,
              )
            : null;
    return _strokeDynamics.sample(
      distance: delta,
      deltaTimeMillis: deltaTimeMillis,
      metrics: metrics,
    );
  }

  /// 计算收笔时的几何指令，供外部绘制尾部渐细。
  SimulatedTailInstruction? buildTail({
    required bool hasPath,
    required Offset tip,
    Offset? previousPoint,
    required double baseRadius,
    required double lastRadius,
  }) {
    if (!_simulatingStroke) {
      return null;
    }
    final double tipRadius = _strokeDynamics.tipRadius();
    if (!hasPath || previousPoint == null) {
      return SimulatedTailInstruction.point(
        point: tip,
        pointRadius: tipRadius,
      );
    }
    final Offset direction = tip - previousPoint;
    final double length = direction.distance;
    if (length <= 0.001) {
      return SimulatedTailInstruction.point(
        point: tip,
        pointRadius: tipRadius,
      );
    }
    final Offset unit = direction / length;
    final double base = math.max(baseRadius, 0.1);
    final double taperLength = math.min(base * 6.5, length * 2.4 + 2.0);
    final Offset extension = tip + unit * taperLength;
    final double startRadius = lastRadius > 0.0 ? lastRadius : baseRadius;
    return SimulatedTailInstruction.line(
      start: tip,
      end: extension,
      startRadius: startRadius,
      endRadius: tipRadius,
    );
  }

  /// 控制器仍可在非模拟模式下更新采样，以维持时间戳推算。
  StrokeSample recordSample(Offset position, double timestampMillis) {
    return _strokeSamples.add(position, timestampMillis);
  }

  double recordVelocitySample(Offset position, double timestampMillis) {
    return _velocitySmoother.addSample(position, timestampMillis);
  }

  double resolveSampleTimestamp(
    double? timestampMillis,
    double? deltaTimeMillis,
  ) {
    if (timestampMillis != null) {
      return timestampMillis;
    }
    final double base = _strokeSamples.latest?.timestamp ?? 0.0;
    if (deltaTimeMillis != null) {
      return base + deltaTimeMillis;
    }
    return base;
  }

  void resetTracking() {
    _strokeSamples.clear();
    _velocitySmoother.reset();
    _simulatingStroke = false;
  }

  void setProfile(StrokePressureProfile profile) {
    if (_profile == profile) {
      return;
    }
    _profile = profile;
    _strokeDynamics.configure(profile: profile);
  }
}
