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
    _streamlineStabilizer.reset();
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
    _strokeStabilizer.reset();
    _streamlineStabilizer.reset();
    final AppPreferences prefs = AppPreferences.instance;
    prefs.streamlineStrength = clamped;
    unawaited(AppPreferences.save());
  }

  void _updateStreamlineEnabled(bool value) {
    if (_streamlineEnabled == value) {
      return;
    }
    setState(() => _streamlineEnabled = value);
    _strokeStabilizer.reset();
    _streamlineStabilizer.reset();
    final AppPreferences prefs = AppPreferences.instance;
    prefs.streamlineEnabled = value;
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
    final int clamped = value.clamp(0, 3);
    if (_bucketAntialiasLevel == clamped) {
      return;
    }
    setState(() => _bucketAntialiasLevel = clamped);
    final AppPreferences prefs = AppPreferences.instance;
    prefs.bucketAntialiasLevel = clamped;
    unawaited(AppPreferences.save());
  }

  Future<_DisableVectorDrawingConfirmResult?>
  _confirmDisableVectorDrawing() async {
    bool doNotShowAgain = false;
    final l10n = context.l10n;
    return showDialog<_DisableVectorDrawingConfirmResult>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return ContentDialog(
          title: Text(l10n.disableVectorDrawing),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.disableVectorDrawingConfirm),
                  const SizedBox(height: 8),
                  Text(l10n.disableVectorDrawingDesc),
                  const SizedBox(height: 12),
                  Checkbox(
                    checked: doNotShowAgain,
                    content: Text(l10n.dontShowAgain),
                    onChanged: (value) {
                      setState(() => doNotShowAgain = value ?? false);
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            Button(
              onPressed: () {
                Navigator.of(context).pop(
                  _DisableVectorDrawingConfirmResult(
                    confirmed: false,
                    doNotShowAgain: doNotShowAgain,
                  ),
                );
              },
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  _DisableVectorDrawingConfirmResult(
                    confirmed: true,
                    doNotShowAgain: doNotShowAgain,
                  ),
                );
              },
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );
  }

  void _updateVectorDrawingEnabled(bool value) async {
    if (_vectorDrawingEnabled == value) {
      return;
    }

    final AppPreferences prefs = AppPreferences.instance;
    if (!value && prefs.showDisableVectorDrawingConfirmDialog) {
      final _DisableVectorDrawingConfirmResult? result =
          await _confirmDisableVectorDrawing();
      if (!mounted) {
        return;
      }
      if (result == null) {
        // Treat barrier dismiss as cancellation.
        setState(() {});
        return;
      }
      if (result.doNotShowAgain) {
        prefs.showDisableVectorDrawingConfirmDialog = false;
      }
      if (!result.confirmed) {
        // Force a rebuild so the toggle reflects the current state.
        setState(() {});
        if (result.doNotShowAgain) {
          unawaited(AppPreferences.save());
        }
        return;
      }
    }

    if (value) {
      _disposeCurveRasterPreview(restoreLayer: true);
      _disposeShapeRasterPreview(restoreLayer: true);
    }
    setState(() => _vectorDrawingEnabled = value);
    _controller.setVectorDrawingEnabled(value);
    prefs.vectorDrawingEnabled = value;
    unawaited(AppPreferences.save());
  }
}
