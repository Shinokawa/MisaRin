part of 'painting_board.dart';

enum _ReferenceModelBakeRendererPreset {
  normal,
  cinematic,
  cycles,
}

extension _ReferenceModelBakeRendererPresetLabel
    on _ReferenceModelBakeRendererPreset {
  String get label {
    return switch (this) {
      _ReferenceModelBakeRendererPreset.normal => '普通（快速）',
      _ReferenceModelBakeRendererPreset.cinematic => '电影（宣传片）',
      _ReferenceModelBakeRendererPreset.cycles => '写实（Cycles）',
    };
  }

  bool get usesBakedLighting => this != _ReferenceModelBakeRendererPreset.normal;
}

class _ReferenceModelBakeResolutionPreset {
  const _ReferenceModelBakeResolutionPreset({
    required this.label,
    required this.width,
    required this.height,
  });

  final String label;
  final int width;
  final int height;
}

const List<_ReferenceModelBakeResolutionPreset>
_kReferenceModelBakeResolutionPresets = <_ReferenceModelBakeResolutionPreset>[
  _ReferenceModelBakeResolutionPreset(label: '1280 × 720 (HD)', width: 1280, height: 720),
  _ReferenceModelBakeResolutionPreset(label: '1920 × 1080 (Full HD)', width: 1920, height: 1080),
  _ReferenceModelBakeResolutionPreset(label: '2560 × 1440 (QHD)', width: 2560, height: 1440),
  _ReferenceModelBakeResolutionPreset(label: '3840 × 2160 (4K)', width: 3840, height: 2160),
];

class _ReferenceModelBakeLighting {
  const _ReferenceModelBakeLighting({
    required this.lightDirection,
    required this.ambient,
    required this.diffuse,
    required this.sunColor,
    required this.skyColor,
    required this.groundBounceColor,
    required this.specularStrength,
    required this.roughness,
    required this.exposure,
    required this.background,
    required this.shadowStrength,
    required this.shadowBlurRadius,
  });

  final Vector3 lightDirection;
  final double ambient;
  final double diffuse;
  final Color sunColor;
  final Color skyColor;
  final Color groundBounceColor;
  final double specularStrength;
  final double roughness;
  final double exposure;
  final Color background;
  final double shadowStrength;
  final int shadowBlurRadius;
}

class _ReferenceModelBakeSkyboxBackground extends StatelessWidget {
  const _ReferenceModelBakeSkyboxBackground({
    required this.timeHours,
    required this.lighting,
    required this.isDark,
  });

  final double timeHours;
  final _ReferenceModelBakeLighting lighting;
  final bool isDark;

  static double _smoothstep(double edge0, double edge1, double x) {
    final double t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  static double _dayBlend(double timeHours) {
    final double normalized = timeHours.isFinite
        ? (timeHours % 24 + 24) % 24
        : 12.0;
    final double dayPhase = ((normalized - 6.0) / 12.0) * math.pi;
    final double sunHeight = math.sin(dayPhase).clamp(-1.0, 1.0).toDouble();
    return _smoothstep(-0.35, 0.15, sunHeight);
  }

  @override
  Widget build(BuildContext context) {
    final double dayBlend = _dayBlend(timeHours);
    final Color zenith = lighting.skyColor;
    final Color horizonTint =
        Color.lerp(zenith, lighting.sunColor, 0.16 + 0.18 * dayBlend) ?? zenith;
    final double whiteMix = isDark
        ? (0.05 + 0.18 * dayBlend).clamp(0.0, 0.28)
        : (0.18 + 0.52 * dayBlend).clamp(0.0, 0.82);
    final Color horizon =
        Color.lerp(horizonTint, const Color(0xFFFFFFFF), whiteMix) ??
            horizonTint;

    final Color cloudBase =
        Color.lerp(zenith, const Color(0xFFFFFFFF), isDark ? 0.18 : 0.55) ??
            const Color(0xFFFFFFFF);
    final Color cloudColor =
        Color.lerp(cloudBase, lighting.sunColor, 0.06 + 0.18 * dayBlend) ??
            cloudBase;
    final double cloudOpacity =
        (0.08 + 0.34 * dayBlend) * (isDark ? 0.65 : 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[zenith, horizon],
            ),
          ),
        ),
        CustomPaint(
          painter: _ReferenceModelBakeCloudPainter(
            seed: 1337,
            color: cloudColor,
            opacity: cloudOpacity,
          ),
        ),
      ],
    );
  }
}

class _ReferenceModelBakeCloudPainter extends CustomPainter {
  const _ReferenceModelBakeCloudPainter({
    required this.seed,
    required this.color,
    required this.opacity,
  });

  final int seed;
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || size.isEmpty) {
      return;
    }

    final math.Random random = math.Random(seed);
    final double blurSigma =
        (size.shortestSide * 0.035).clamp(6.0, 36.0).toDouble();
    final Paint paint = Paint()
      ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0).toDouble())
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blurSigma);

    const int cloudGroups = 10;
    for (int i = 0; i < cloudGroups; i++) {
      final double cx = (random.nextDouble() * 1.2 - 0.1) * size.width;
      final double cy = (0.06 + random.nextDouble() * 0.52) * size.height;
      final double base = (0.10 + random.nextDouble() * 0.14) * size.width;
      final int blobs = 6 + random.nextInt(4);

      for (int j = 0; j < blobs; j++) {
        final double dx = (random.nextDouble() - 0.5) * base * 0.65;
        final double dy = (random.nextDouble() - 0.5) * base * 0.18;
        final double r = base * (0.30 + random.nextDouble() * 0.22);
        canvas.drawCircle(Offset(cx + dx, cy + dy), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ReferenceModelBakeCloudPainter oldDelegate) {
    return seed != oldDelegate.seed ||
        color != oldDelegate.color ||
        opacity != oldDelegate.opacity;
  }
}
