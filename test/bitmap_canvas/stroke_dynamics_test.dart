import 'package:flutter_test/flutter_test.dart';

import 'package:misa_rin/bitmap_canvas/stroke_dynamics.dart';

void main() {
  group('StrokeDynamics', () {
    test('taperEnds 慢速比快速更粗', () {
      final StrokeDynamics dynamics = StrokeDynamics();
      dynamics.start(4.0, profile: StrokePressureProfile.taperEnds);
      final double slowRadius = dynamics.sample(
        distance: 0.3,
        deltaTimeMillis: 64.0,
      );

      dynamics.start(4.0, profile: StrokePressureProfile.taperEnds);
      final double fastRadius = dynamics.sample(
        distance: 6.0,
        deltaTimeMillis: 8.0,
      );

      expect(slowRadius, greaterThan(fastRadius));
    });

    test('taperCenter 起笔较薄且随笔划稳定变粗', () {
      final StrokeDynamics dynamics = StrokeDynamics();
      dynamics.start(4.0, profile: StrokePressureProfile.taperCenter);

      final double first = dynamics.sample(
        distance: 0.3,
        deltaTimeMillis: 64.0,
      );
      final double second = dynamics.sample(
        distance: 3.0,
        deltaTimeMillis: 10.0,
      );
      final double third = dynamics.sample(
        distance: 3.0,
        deltaTimeMillis: 10.0,
      );

      expect(first, lessThan(second));
      expect(second, lessThanOrEqualTo(third));
      expect(third, greaterThan(first));
    });

    test('taperCenter 起笔明显比 taperEnds 更细', () {
      final StrokeDynamics center = StrokeDynamics();
      center.start(4.0, profile: StrokePressureProfile.taperCenter);
      final double centerStart = center.sample(
        distance: 0.3,
        deltaTimeMillis: 60.0,
      );

      final StrokeDynamics ends = StrokeDynamics();
      ends.start(4.0, profile: StrokePressureProfile.taperEnds);
      final double endsStart = ends.sample(
        distance: 0.3,
        deltaTimeMillis: 60.0,
      );

      expect(centerStart, lessThan(endsStart));
    });

    test('auto 模式下慢速停顿比快速划线更粗', () {
      final StrokeDynamics dynamics = StrokeDynamics(
        profile: StrokePressureProfile.auto,
      );

      dynamics.start(4.0);
      final double slowRadius = dynamics.sample(
        distance: 0.2,
        deltaTimeMillis: 80.0,
        metrics: const StrokeSampleMetrics(
          sampleIndex: 1,
          normalizedSpeed: 0.08,
          stationaryDuration: 240.0,
          totalDistance: 2.2,
          totalTime: 160.0,
        ),
      );

      dynamics.start(4.0);
      final double fastRadius = dynamics.sample(
        distance: 4.0,
        deltaTimeMillis: 6.0,
        metrics: const StrokeSampleMetrics(
          sampleIndex: 1,
          normalizedSpeed: 0.92,
          stationaryDuration: 0.0,
          totalDistance: 4.5,
          totalTime: 20.0,
        ),
      );

      expect(slowRadius, greaterThan(fastRadius));
    });
  });
}
