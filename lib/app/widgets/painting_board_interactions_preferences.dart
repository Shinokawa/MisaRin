part of 'painting_board.dart';

extension _PaintingBoardInteractionPreferencesExtension on _PaintingBoardInteractionMixin {
  void _updateSprayMode(SprayMode mode) {
    if (_sprayMode == mode) {
      return;
    }
    if (_activeTool == CanvasTool.spray && _isSpraying) {
      _finishSprayStroke();
    }
    setState(() => _sprayMode = mode);
    if (mode == SprayMode.splatter) {
      _kritaSprayEngine?.updateSettings(_buildKritaSpraySettings());
    } else {
      _kritaSprayEngine = null;
    }
    final AppPreferences prefs = AppPreferences.instance;
    prefs.sprayMode = mode;
    unawaited(AppPreferences.save());
  }

  void _updateBrushShape(BrushShape shape) {
    if (_brushShape == shape) {
      return;
    }
    setState(() => _brushShape = shape);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.brushShape = shape;
    unawaited(AppPreferences.save());
  }

  void _updateBrushRandomRotationEnabled(bool value) {
    if (_brushRandomRotationEnabled == value) {
      return;
    }
    setState(() {
      _brushRandomRotationEnabled = value;
      if (value) {
        _brushRandomRotationPreviewSeed = _brushRotationRandom.nextInt(1 << 31);
      }
    });
    final AppPreferences prefs = AppPreferences.instance;
    prefs.brushRandomRotationEnabled = value;
    unawaited(AppPreferences.save());
  }

  void _updateHollowStrokeEnabled(bool value) {
    if (_hollowStrokeEnabled == value) {
      return;
    }
    setState(() => _hollowStrokeEnabled = value);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.hollowStrokeEnabled = value;
    unawaited(AppPreferences.save());
  }

  void _updateHollowStrokeRatio(double value) {
    final double clamped = value.clamp(0.0, 1.0);
    if ((_hollowStrokeRatio - clamped).abs() < 0.0005) {
      return;
    }
    setState(() => _hollowStrokeRatio = clamped);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.hollowStrokeRatio = clamped;
    unawaited(AppPreferences.save());
  }

  void _updateHollowStrokeEraseOccludedParts(bool value) {
    if (_hollowStrokeEraseOccludedParts == value) {
      return;
    }
    setState(() => _hollowStrokeEraseOccludedParts = value);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.hollowStrokeEraseOccludedParts = value;
    unawaited(AppPreferences.save());
  }

  void _updateStrokeStabilizerStrength(double value) {
    final double clamped = value.clamp(0.0, 1.0);
    if ((_strokeStabilizerStrength - clamped).abs() < 0.0005) {
      return;
    }
    setState(() => _strokeStabilizerStrength = clamped);
    _strokeStabilizer.reset();
    final AppPreferences prefs = AppPreferences.instance;
    prefs.strokeStabilizerStrength = clamped;
    unawaited(AppPreferences.save());
  }

  void _updateStreamlineStrength(double value) {
    final double clamped = value.clamp(0.0, 1.0);
    if ((_streamlineStrength - clamped).abs() < 0.0005) {
      return;
    }
    setState(() => _streamlineStrength = clamped);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.streamlineStrength = clamped;
    unawaited(AppPreferences.save());
  }

  void _updateStylusPressureEnabled(bool value) {
    if (_stylusPressureEnabled == value) {
      return;
    }
    setState(() => _stylusPressureEnabled = value);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.stylusPressureEnabled = value;
    unawaited(AppPreferences.save());
    _applyStylusSettingsToController();
  }

  void _updateBucketAntialiasLevel(int value) {
    final int clamped = value.clamp(0, 9);
    if (_bucketAntialiasLevel == clamped) {
      return;
    }
    setState(() => _bucketAntialiasLevel = clamped);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.bucketAntialiasLevel = clamped;
    unawaited(AppPreferences.save());
  }
}
