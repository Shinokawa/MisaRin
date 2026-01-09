part of 'painting_board.dart';

class _BakeCloudPrograms {
  static Future<ui.FragmentProgram> get program =>
      _program ??= ui.FragmentProgram.fromAsset('shaders/bake_clouds.frag');

  static Future<ui.FragmentProgram>? _program;
}

class _BakeSkyboxPalette {
  const _BakeSkyboxPalette({
    required this.dayBlend,
    required this.zenith,
    required this.horizon,
    required this.cloudColor,
    required this.shadowColor,
    required this.highlightColor,
    required this.cloudOpacity,
    required this.shadowOpacity,
    required this.highlightOpacity,
    required this.shaderShadowStrength,
  });

  final double dayBlend;
  final Color zenith;
  final Color horizon;
  final Color cloudColor;
  final Color shadowColor;
  final Color highlightColor;
  final double cloudOpacity;
  final double shadowOpacity;
  final double highlightOpacity;
  final double shaderShadowStrength;
}

_BakeSkyboxPalette _computeBakeSkyboxPalette({
  required double timeHours,
  required bool isDark,
  required Color skyColor,
  required Color sunColor,
}) {
  final double normalized = timeHours.isFinite
      ? (timeHours % 24 + 24) % 24
      : 12.0;
  final double dayPhase = ((normalized - 6.0) / 12.0) * math.pi;
  final double sunHeight = math.sin(dayPhase).clamp(-1.0, 1.0).toDouble();
  final double dayBlend = _smoothstep(-0.35, 0.15, sunHeight);

  // Sky: boost the midday blue so it doesn't look washed out / white.
  const Color dayZenithTarget = Color(0xFF2E6CFF);
  const Color dayHorizonTarget = Color(0xFFBDEBFF);
  final double zenithBoost = ((isDark ? 0.10 : 0.76) * dayBlend).clamp(0.0, 1.0);
  final Color zenith =
      Color.lerp(skyColor, dayZenithTarget, zenithBoost) ?? skyColor;

  final double warmT =
      (0.10 + 0.18 * dayBlend).clamp(0.0, isDark ? 0.24 : 0.34);
  final Color horizonWarm = Color.lerp(zenith, sunColor, warmT) ?? zenith;
  final double hazeT = ((isDark ? 0.10 : 0.34) +
          (isDark ? 0.18 : 0.58) * dayBlend)
      .clamp(0.0, 1.0);
  final Color horizon =
      Color.lerp(horizonWarm, dayHorizonTarget, hazeT) ?? horizonWarm;

  // Clouds: aim for white cumulus with soft blue ambient and less harsh shadows.
  final Color cloudBase = Color.lerp(
        zenith,
        const Color(0xFFFFFFFF),
        isDark ? 0.30 : 0.82,
      ) ??
      const Color(0xFFFFFFFF);
  final Color cloudColor = Color.lerp(
        cloudBase,
        sunColor,
        (0.04 + 0.12 * dayBlend).clamp(0.0, 0.24),
      ) ??
      cloudBase;

  final Color highlightTint =
      Color.lerp(cloudColor, sunColor, 0.55 + 0.25 * dayBlend) ?? sunColor;
  final Color highlightColor =
      Color.lerp(highlightTint, const Color(0xFFFFFFFF), 0.62) ??
          highlightTint;

  final Color shadowTint = Color.lerp(cloudColor, zenith, 0.62) ?? zenith;
  final Color shadowColor = Color.lerp(
        shadowTint,
        const Color(0xFF000000),
        isDark ? 0.45 : 0.28,
      ) ??
      shadowTint;

  final double cloudOpacity = ((0.12 + 0.50 * dayBlend) * (isDark ? 0.55 : 0.85))
      .clamp(0.0, 1.0);
  final double shadowOpacity =
      (cloudOpacity * (isDark ? 0.55 : 0.60)).clamp(0.0, 1.0);
  final double highlightOpacity = (cloudOpacity * 0.55).clamp(0.0, 1.0);

  final double shaderShadowStrength = (isDark
          ? (0.48 + 0.12 * (1.0 - dayBlend))
          : (0.24 + 0.18 * (1.0 - dayBlend)))
      .clamp(0.0, 1.0);

  return _BakeSkyboxPalette(
    dayBlend: dayBlend,
    zenith: zenith,
    horizon: horizon,
    cloudColor: cloudColor,
    shadowColor: shadowColor,
    highlightColor: highlightColor,
    cloudOpacity: cloudOpacity,
    shadowOpacity: shadowOpacity,
    highlightOpacity: highlightOpacity,
    shaderShadowStrength: shaderShadowStrength,
  );
}

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
    required this.cameraYaw,
    required this.cameraPitch,
    required this.cameraZoom,
  });

  final double timeHours;
  final _ReferenceModelBakeLighting lighting;
  final bool isDark;
  final double cameraYaw;
  final double cameraPitch;
  final double cameraZoom;

  @override
  Widget build(BuildContext context) {
    final _BakeSkyboxPalette palette = _computeBakeSkyboxPalette(
      timeHours: timeHours,
      isDark: isDark,
      skyColor: lighting.skyColor,
      sunColor: lighting.sunColor,
    );
    final Color zenith = palette.zenith;
    final Color horizon = palette.horizon;

    Widget buildCloudLayer() {
      return FutureBuilder<ui.FragmentProgram>(
        future: _BakeCloudPrograms.program,
        builder: (BuildContext context, AsyncSnapshot<ui.FragmentProgram> snapshot) {
          final ui.FragmentProgram? program = snapshot.data;
          if (program == null) {
            return CustomPaint(
              painter: _ReferenceModelBakeCloudPainter(
                seed: 1337,
                timeHours: timeHours,
                cameraYaw: cameraYaw,
                cameraPitch: cameraPitch,
                cameraZoom: cameraZoom,
                lightDirection: lighting.lightDirection,
                baseColor: palette.cloudColor,
                baseOpacity: palette.cloudOpacity,
                shadowColor: palette.shadowColor,
                shadowOpacity: palette.shadowOpacity,
                highlightColor: palette.highlightColor,
                highlightOpacity: palette.highlightOpacity,
              ),
            );
          }

          return CustomPaint(
            painter: _ReferenceModelBakeCloudShaderPainter(
              program: program,
              timeHours: timeHours,
              seed: 1337,
              cameraYaw: cameraYaw,
              cameraPitch: cameraPitch,
              cameraZoom: cameraZoom,
              lightDirection: lighting.lightDirection,
              sunColor: lighting.sunColor,
              zenith: zenith,
              horizon: horizon,
              cloudColor: palette.cloudColor,
              cloudOpacity: palette.cloudOpacity,
              shadowStrength: palette.shaderShadowStrength,
            ),
          );
        },
      );
    }

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
        buildCloudLayer(),
      ],
    );
  }
}

class _ReferenceModelBakeCloudShaderPainter extends CustomPainter {
  const _ReferenceModelBakeCloudShaderPainter({
    required this.program,
    required this.timeHours,
    required this.seed,
    required this.cameraYaw,
    required this.cameraPitch,
    required this.cameraZoom,
    required this.lightDirection,
    required this.sunColor,
    required this.zenith,
    required this.horizon,
    required this.cloudColor,
    required this.cloudOpacity,
    required this.shadowStrength,
  });

  final ui.FragmentProgram program;
  final double timeHours;
  final int seed;
  final double cameraYaw;
  final double cameraPitch;
  final double cameraZoom;
  final Vector3 lightDirection;
  final Color sunColor;
  final Color zenith;
  final Color horizon;
  final Color cloudColor;
  final double cloudOpacity;
  final double shadowStrength;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final ui.FragmentShader shader = program.fragmentShader()
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, timeHours.isFinite ? timeHours : 0.0)
      ..setFloat(3, seed.toDouble())
      ..setFloat(4, cameraYaw)
      ..setFloat(5, cameraPitch)
      ..setFloat(6, cameraZoom)
      ..setFloat(7, lightDirection.x)
      ..setFloat(8, lightDirection.y)
      ..setFloat(9, lightDirection.z)
      ..setFloat(10, sunColor.r)
      ..setFloat(11, sunColor.g)
      ..setFloat(12, sunColor.b)
      ..setFloat(13, zenith.r)
      ..setFloat(14, zenith.g)
      ..setFloat(15, zenith.b)
      ..setFloat(16, horizon.r)
      ..setFloat(17, horizon.g)
      ..setFloat(18, horizon.b)
      ..setFloat(19, cloudColor.r)
      ..setFloat(20, cloudColor.g)
      ..setFloat(21, cloudColor.b)
      ..setFloat(22, 60.0)
      ..setFloat(23, 260.0)
      ..setFloat(24, 24.0)
      ..setFloat(25, cloudOpacity.clamp(0.0, 1.0).toDouble())
      ..setFloat(26, shadowStrength.clamp(0.0, 1.0).toDouble())
      ;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _ReferenceModelBakeCloudShaderPainter oldDelegate) {
    return program != oldDelegate.program ||
        timeHours != oldDelegate.timeHours ||
        seed != oldDelegate.seed ||
        cameraYaw != oldDelegate.cameraYaw ||
        cameraPitch != oldDelegate.cameraPitch ||
        cameraZoom != oldDelegate.cameraZoom ||
        lightDirection != oldDelegate.lightDirection ||
        sunColor != oldDelegate.sunColor ||
        zenith != oldDelegate.zenith ||
        horizon != oldDelegate.horizon ||
        cloudColor != oldDelegate.cloudColor ||
        cloudOpacity != oldDelegate.cloudOpacity ||
        shadowStrength != oldDelegate.shadowStrength;
  }
}

class _ReferenceModelBakeCloudPainter extends CustomPainter {
  const _ReferenceModelBakeCloudPainter({
    required this.seed,
    required this.timeHours,
    required this.cameraYaw,
    required this.cameraPitch,
    required this.cameraZoom,
    required this.lightDirection,
    required this.baseColor,
    required this.baseOpacity,
    required this.shadowColor,
    required this.shadowOpacity,
    required this.highlightColor,
    required this.highlightOpacity,
  });

  final int seed;
  final double timeHours;
  final double cameraYaw;
  final double cameraPitch;
  final double cameraZoom;
  final Vector3 lightDirection;
  final Color baseColor;
  final double baseOpacity;
  final Color shadowColor;
  final double shadowOpacity;
  final Color highlightColor;
  final double highlightOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final double opacity = baseOpacity.clamp(0.0, 1.0).toDouble();
    if (opacity <= 0 || size.isEmpty) {
      return;
    }

    final Rect rect = Offset.zero & size;
    final double zoomFactor = cameraZoom.isFinite
        ? cameraZoom.clamp(0.8, 2.5).toDouble()
        : 1.0;
    final double tileSize =
        math.max(128.0, size.shortestSide * 1.60 * zoomFactor).toDouble();

    final double seedScrollX = _rand2d(17, 31, seed) * tileSize;
    final double seedScrollY = _rand2d(43, 59, seed) * tileSize;
    final double drift = timeHours.isFinite ? timeHours : 0.0;
    final double camScrollX =
        (cameraYaw.isFinite ? cameraYaw : 0.0) / (math.pi * 2) * tileSize;
    final double camScrollY =
        (cameraPitch.isFinite ? cameraPitch : 0.0) / math.pi * tileSize;
    final double scrollX = seedScrollX + drift * 4.0 + camScrollX;
    final double scrollY = seedScrollY + drift * 1.5 - camScrollY;
    final double driftShiftX =
        (((scrollX / tileSize) % 1.0) - 0.5) * size.width * 0.22;
    final double driftShiftY =
        (((scrollY / tileSize) % 1.0) - 0.5) * size.height * 0.14;

    double dirX = lightDirection.x;
    double dirY = -lightDirection.z;
    final double dirLen = math.sqrt(dirX * dirX + dirY * dirY).toDouble();
    if (dirLen > 1e-6) {
      dirX /= dirLen;
      dirY /= dirLen;
    } else {
      dirX = 1.0;
      dirY = 0.0;
    }
    final double offsetPx =
        (size.shortestSide * 0.018).clamp(2.0, 12.0).toDouble();
    final Offset shift = Offset(dirX * offsetPx, dirY * offsetPx);

    final math.Random random = math.Random(seed);

    final double blurSigma =
        (size.shortestSide * 0.032).clamp(4.0, 32.0).toDouble();
    final Paint shadowPaint = Paint()
      ..filterQuality = ui.FilterQuality.medium
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blurSigma * 1.05)
      ..color = shadowColor.withValues(
        alpha: shadowOpacity.clamp(0.0, 1.0).toDouble(),
      );
    final Paint basePaint = Paint()
      ..filterQuality = ui.FilterQuality.medium
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blurSigma * 0.90)
      ..color = baseColor.withValues(alpha: opacity);
    final Paint highlightPaint = Paint()
      ..filterQuality = ui.FilterQuality.medium
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blurSigma * 0.75)
      ..blendMode = ui.BlendMode.screen
      ..color = highlightColor.withValues(
        alpha: highlightOpacity.clamp(0.0, 1.0).toDouble(),
      );

    canvas.saveLayer(rect, Paint());
    const int cloudGroups = 9;
    for (int i = 0; i < cloudGroups; i++) {
      final double cx =
          (random.nextDouble() * 1.4 - 0.2) * size.width + driftShiftX;
      final double cy =
          (0.02 + random.nextDouble() * 0.55) * size.height + driftShiftY;
      final double base = (0.16 + random.nextDouble() * 0.18) * size.width;
      final int blobs = 7 + random.nextInt(5);

      canvas.save();
      canvas.translate(-shift.dx, -shift.dy);
      for (int j = 0; j < blobs; j++) {
        final double dx = (random.nextDouble() - 0.5) * base * 0.72;
        final double dy = (random.nextDouble() - 0.5) * base * 0.22;
        final double r = base * (0.26 + random.nextDouble() * 0.22);
        canvas.drawCircle(Offset(cx + dx, cy + dy), r, shadowPaint);
      }
      canvas.restore();

      for (int j = 0; j < blobs; j++) {
        final double dx = (random.nextDouble() - 0.5) * base * 0.68;
        final double dy = (random.nextDouble() - 0.5) * base * 0.18;
        final double r = base * (0.30 + random.nextDouble() * 0.22);
        canvas.drawCircle(Offset(cx + dx, cy + dy), r, basePaint);
      }

      canvas.save();
      canvas.translate(shift.dx, shift.dy);
      for (int j = 0; j < blobs; j++) {
        final double dx = (random.nextDouble() - 0.5) * base * 0.64;
        final double dy = (random.nextDouble() - 0.5) * base * 0.16;
        final double r = base * (0.24 + random.nextDouble() * 0.18);
        canvas.drawCircle(Offset(cx + dx, cy + dy), r, highlightPaint);
      }
      canvas.restore();
    }

    final Paint fadePaint = Paint()
      ..blendMode = ui.BlendMode.dstIn
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFFFFFFFF),
          Color(0xFFFFFFFF),
          Color(0x00FFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: <double>[0.0, 0.55, 0.98, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, fadePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReferenceModelBakeCloudPainter oldDelegate) {
    return seed != oldDelegate.seed ||
        timeHours != oldDelegate.timeHours ||
        cameraYaw != oldDelegate.cameraYaw ||
        cameraPitch != oldDelegate.cameraPitch ||
        cameraZoom != oldDelegate.cameraZoom ||
        lightDirection != oldDelegate.lightDirection ||
        baseColor != oldDelegate.baseColor ||
        baseOpacity != oldDelegate.baseOpacity ||
        shadowColor != oldDelegate.shadowColor ||
        shadowOpacity != oldDelegate.shadowOpacity ||
        highlightColor != oldDelegate.highlightColor ||
        highlightOpacity != oldDelegate.highlightOpacity;
  }
}
