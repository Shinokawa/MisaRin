import 'dart:ui';

enum PerspectiveGuideMode { off, onePoint, twoPoint, threePoint }

class PerspectiveGuideState {
  const PerspectiveGuideState({
    required this.mode,
    required this.enabled,
    required this.visible,
    required this.horizonY,
    required this.vp1,
    this.vp2,
    this.vp3,
    this.snapAngleToleranceDegrees = 14,
  });

  final PerspectiveGuideMode mode;
  final bool enabled;
  final bool visible;
  final double horizonY;
  final Offset vp1;
  final Offset? vp2;
  final Offset? vp3;
  final double snapAngleToleranceDegrees;

  PerspectiveGuideState copyWith({
    PerspectiveGuideMode? mode,
    bool? enabled,
    bool? visible,
    double? horizonY,
    Offset? vp1,
    Offset? vp2,
    Offset? vp3,
    double? snapAngleToleranceDegrees,
  }) {
    return PerspectiveGuideState(
      mode: mode ?? this.mode,
      enabled: enabled ?? this.enabled,
      visible: visible ?? this.visible,
      horizonY: horizonY ?? this.horizonY,
      vp1: vp1 ?? this.vp1,
      vp2: vp2 ?? this.vp2,
      vp3: vp3 ?? this.vp3,
      snapAngleToleranceDegrees:
          snapAngleToleranceDegrees ?? this.snapAngleToleranceDegrees,
    );
  }

  static PerspectiveGuideState defaults(Size canvasSize) {
    final double horizon = canvasSize.height * 0.5;
    final Offset center = Offset(canvasSize.width * 0.5, horizon);
    return PerspectiveGuideState(
      mode: PerspectiveGuideMode.off,
      enabled: false,
      visible: false,
      horizonY: horizon,
      vp1: center,
      vp2: Offset(canvasSize.width * 0.75, horizon),
      vp3: Offset(canvasSize.width * 0.5, canvasSize.height * -0.4),
    );
  }
}
