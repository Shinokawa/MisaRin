part of 'painting_board.dart';

mixin _PaintingBoardBuildMixin
    on
        _PaintingBoardBase,
        _PaintingBoardLayerTransformMixin,
        _PaintingBoardInteractionMixin,
        _PaintingBoardPaletteMixin,
        _PaintingBoardColorMixin,
        _PaintingBoardReferenceMixin,
        _PaintingBoardReferenceModelMixin,
        _PaintingBoardPerspectiveMixin,
        _PaintingBoardTextMixin,
        _PaintingBoardFilterMixin {
  OverlayEntry? _workspaceCardsOverlayEntry;
  bool _workspaceCardsOverlaySyncScheduled = false;

  bool get _wantsWorkspaceCardsOverlay {
    if (!widget.isActive) {
      return false;
    }
    return _referenceCards.isNotEmpty ||
        _referenceModelCards.isNotEmpty ||
        _paletteCards.isNotEmpty;
  }

  @override
  void _scheduleWorkspaceCardsOverlaySync() {
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    final bool safeToSyncNow =
        phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks;
    if (safeToSyncNow) {
      _syncWorkspaceCardsOverlay();
      return;
    }
    if (_workspaceCardsOverlaySyncScheduled) {
      return;
    }
    _workspaceCardsOverlaySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _workspaceCardsOverlaySyncScheduled = false;
      if (!mounted) {
        return;
      }
      _syncWorkspaceCardsOverlay();
    });
  }

  void _syncWorkspaceCardsOverlay() {
    if (!_wantsWorkspaceCardsOverlay) {
      final OverlayEntry? entry = _workspaceCardsOverlayEntry;
      if (entry != null && entry.mounted) {
        entry.remove();
      }
      _workspaceCardsOverlayEntry = null;
      return;
    }

    final OverlayState? overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    final OverlayEntry entry =
        _workspaceCardsOverlayEntry ??= OverlayEntry(builder: _buildWorkspaceCardsOverlay);

    if (entry.mounted) {
      entry.markNeedsBuild();
      return;
    }

    if (_filterOverlayEntry?.mounted == true) {
      overlay.insert(entry, below: _filterOverlayEntry);
    } else {
      overlay.insert(entry);
    }
  }

  Widget _buildWorkspaceCardsOverlay(BuildContext overlayContext) {
    if (!_wantsWorkspaceCardsOverlay) {
      return const SizedBox.shrink();
    }
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) {
      return const SizedBox.shrink();
    }
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        ..._buildReferenceCards(),
        ..._buildReferenceModelCards(),
        ..._buildPaletteCards(),
      ],
    );
  }

  @override
  void didUpdateWidget(covariant PaintingBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) {
      return;
    }
    _scheduleWorkspaceCardsOverlaySync();
  }

  @override
  Widget build(BuildContext context) {
    _refreshStylusPreferencesIfNeeded();
    _refreshHistoryLimit();
    final bool canUndo = this.canUndo || widget.externalCanUndo;
    final bool canRedo = this.canRedo || widget.externalCanRedo;

    // Shortcuts callbacks below rely on base toggles; provide local wrappers to
    // keep the mixin type happy.
    void toggleViewBlackWhiteOverlay() => super.toggleViewBlackWhiteOverlay();
    void togglePixelGridVisibility() => super.togglePixelGridVisibility();
    void toggleViewMirrorOverlay() => super.toggleViewMirrorOverlay();

    return _buildPaintingBoardBody(
      context,
      canUndo: canUndo,
      canRedo: canRedo,
      toggleViewBlackWhiteOverlay: toggleViewBlackWhiteOverlay,
      togglePixelGridVisibility: togglePixelGridVisibility,
      toggleViewMirrorOverlay: toggleViewMirrorOverlay,
    );
  }

  List<Widget> _buildPaletteCards() {
    if (_paletteCards.isEmpty) {
      return const <Widget>[];
    }
    return _paletteCards
        .map((entry) {
          final Offset overlayOffset = _workspaceToOverlayOffset(this, entry.offset);
          return Positioned(
            left: overlayOffset.dx,
            top: overlayOffset.dy,
            child: _WorkspacePaletteCard(
              title: entry.title,
              colors: entry.colors,
              onExport: () => _exportPaletteCard(entry.id),
              onClose: () => _closePaletteCard(entry.id),
              onDragStart: () => _handlePaletteDragStart(entry.id),
              onDragEnd: _handlePaletteDragEnd,
              onDragUpdate: (delta) =>
                  _updatePaletteCardOffset(entry.id, delta),
              onSizeChanged: (size) => _updatePaletteCardSize(entry.id, size),
              onColorTap: _setPrimaryColor,
            ),
          );
        })
        .toList(growable: false);
  }

  List<Widget> _buildReferenceCards() {
    if (_referenceCards.isEmpty) {
      return const <Widget>[];
    }
    final bool eyedropperActive = _effectiveActiveTool == CanvasTool.eyedropper;
    return _referenceCards
        .map((entry) {
          final Offset overlayOffset = _workspaceToOverlayOffset(this, entry.offset);
          return Positioned(
            left: overlayOffset.dx,
            top: overlayOffset.dy,
            child: _ReferenceImageCard(
              image: entry.image,
              bodySize: entry.bodySize,
              pixelBytes: entry.pixelBytes,
              enableEyedropperSampling: eyedropperActive,
              onSamplePreview: (color) =>
                  _setPrimaryColor(color, remember: false),
              onSampleCommit: (color) => _setPrimaryColor(color),
              onClose: () => _closeReferenceCard(entry.id),
              onDragStart: () => _focusReferenceCard(entry.id),
              onDragEnd: () {},
              onDragUpdate: (delta) =>
                  _updateReferenceCardOffset(entry.id, delta),
              onSizeChanged: (size) =>
                  _handleReferenceCardSizeChanged(entry.id, size),
              onResizeStart: () => _beginReferenceCardResize(entry.id),
              onResize: (edge, delta) =>
                  _resizeReferenceCard(entry.id, edge, delta),
              onResizeEnd: _endReferenceCardResize,
            ),
          );
        })
        .toList(growable: false);
  }

  List<Widget> _buildReferenceModelCards() {
    if (_referenceModelCards.isEmpty) {
      return const <Widget>[];
    }
    return _referenceModelCards
        .map((entry) {
          final Offset overlayOffset = _workspaceToOverlayOffset(
            this,
            entry.offset,
          );
          return Positioned(
            left: overlayOffset.dx,
            top: overlayOffset.dy,
            child: _ReferenceModelCard(
              key: ValueKey<int>(entry.id),
              title: entry.title,
              modelMesh: entry.modelMesh,
              texture: _referenceModelTexture,
              dialogContext: context,
              onClose: () => _closeReferenceModelCard(entry.id),
              onDragStart: () => _focusReferenceModelCard(entry.id),
              onDragUpdate: (delta) =>
                  _updateReferenceModelCardOffset(entry.id, delta),
              onDragEnd: () {},
              onRefreshTexture: () => _refreshReferenceModelTexture(),
              onSizeChanged: (size) =>
                  _handleReferenceModelCardSizeChanged(entry.id, size),
            ),
          );
        })
        .toList(growable: false);
  }

  Widget _buildFilterPreviewStack() {
    final _FilterSession? session = _filterSession;
    if (session == null) return const SizedBox.shrink();

    ui.Image? activeImage = _previewActiveLayerImage;
    final bool useFilteredPreviewImage =
        _previewFilteredImageType == session.type &&
        _previewFilteredActiveLayerImage != null;
    if (useFilteredPreviewImage) {
      activeImage = _previewFilteredActiveLayerImage;
    }
    Widget activeLayerWidget = RawImage(
      image: activeImage,
      filterQuality: FilterQuality.none,
    );

    // Apply Filters
    if (session.type == _FilterPanelType.gaussianBlur) {
      final double sigma = _gaussianBlurSigmaForRadius(
        session.gaussianBlur.radius,
      );
      if (sigma > 0) {
        activeLayerWidget = ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: activeLayerWidget,
        );
      }
    } else if (session.type == _FilterPanelType.hueSaturation) {
      final double hue = session.hueSaturation.hue;
      final double saturation = session.hueSaturation.saturation;
      final double lightness = session.hueSaturation.lightness;
      final bool requiresAdjustments =
          hue != 0 || saturation != 0 || lightness != 0;
      if (requiresAdjustments && !useFilteredPreviewImage) {
        if (hue != 0) {
          activeLayerWidget = ColorFiltered(
            colorFilter: ColorFilter.matrix(ColorFilterGenerator.hue(hue)),
            child: activeLayerWidget,
          );
        }
        if (saturation != 0) {
          activeLayerWidget = ColorFiltered(
            colorFilter: ColorFilter.matrix(
              ColorFilterGenerator.saturation(saturation),
            ),
            child: activeLayerWidget,
          );
        }
        if (lightness != 0) {
          activeLayerWidget = ColorFiltered(
            colorFilter: ColorFilter.matrix(
              ColorFilterGenerator.brightness(lightness),
            ),
            child: activeLayerWidget,
          );
        }
      }
    } else if (session.type == _FilterPanelType.brightnessContrast) {
      final double brightness = session.brightnessContrast.brightness;
      final double contrast = session.brightnessContrast.contrast;
      if (brightness != 0 || contrast != 0) {
        activeLayerWidget = ColorFiltered(
          colorFilter: ColorFilter.matrix(
            ColorFilterGenerator.brightnessContrast(brightness, contrast),
          ),
          child: activeLayerWidget,
        );
      }
    } else if (session.type == _FilterPanelType.blackWhite) {
      if (!useFilteredPreviewImage) {
        final double black = session.blackWhite.blackPoint.clamp(0.0, 100.0);
        final double white = session.blackWhite.whitePoint.clamp(0.0, 100.0);
        final double clampedWhite = white <= black + _kBlackWhiteMinRange
            ? math.min(100.0, black + _kBlackWhiteMinRange)
            : white;
        final double blackNorm = black / 100.0;
        final double whiteNorm = math.max(
          blackNorm + (_kBlackWhiteMinRange / 100.0),
          clampedWhite / 100.0,
        );
        final double invRange = 1.0 / math.max(0.0001, whiteNorm - blackNorm);
        final double offset = -blackNorm * 255.0 * invRange;
        const double lwR = 0.299;
        const double lwG = 0.587;
        const double lwB = 0.114;
        activeLayerWidget = ColorFiltered(
          colorFilter: ColorFilter.matrix(<double>[
            lwR * invRange,
            lwG * invRange,
            lwB * invRange,
            0,
            offset,
            lwR * invRange,
            lwG * invRange,
            lwB * invRange,
            0,
            offset,
            lwR * invRange,
            lwG * invRange,
            lwB * invRange,
            0,
            offset,
            0,
            0,
            0,
            1,
            0,
          ]),
          child: activeLayerWidget,
        );
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_previewBackground != null)
          RawImage(
            image: _previewBackground,
            filterQuality: FilterQuality.none,
          ),
        activeLayerWidget,
        if (_previewForeground != null)
          RawImage(
            image: _previewForeground,
            filterQuality: FilterQuality.none,
          ),
      ],
    );
  }

  Widget _buildLayerOpacityPreviewStack() {
    if (_layerOpacityPreviewActiveLayerImage == null) {
      return const SizedBox.shrink();
    }
    final bool hasVisibleLowerLayers =
        _layerOpacityPreviewHasVisibleLowerLayers;
    Widget activeLayerWidget = RawImage(
      image: _layerOpacityPreviewActiveLayerImage,
      filterQuality: FilterQuality.low,
    );
    final double previewOpacity = (_layerOpacityPreviewValue ?? 1.0).clamp(
      0.0,
      1.0,
    );
    if (previewOpacity < 0.999) {
      activeLayerWidget = Opacity(
        opacity: previewOpacity,
        child: activeLayerWidget,
      );
    }
    final List<Widget> children = <Widget>[
      if (_layerOpacityPreviewBackground != null)
        RawImage(image: _layerOpacityPreviewBackground)
      else if (!hasVisibleLowerLayers)
        const _CheckboardBackground(),
      activeLayerWidget,
    ];
    if (_layerOpacityPreviewForeground != null) {
      children.add(RawImage(image: _layerOpacityPreviewForeground));
    }
    return Stack(fit: StackFit.expand, children: children);
  }

  Widget? _buildColorRangeCard() {
    if (!_colorRangeCardVisible) {
      return null;
    }
    final int totalColors = math.max(1, _colorRangeTotalColors);
    final int maxSelectable = math.max(1, _colorRangeMaxSelectable());
    final int selected =
        _colorRangeSelectedColors.clamp(1, maxSelectable).toInt();
    final bool busy = _colorRangePreviewInFlight || _colorRangeApplying;
    return Positioned(
      left: _colorRangeCardOffset.dx,
      top: _colorRangeCardOffset.dy,
      child: MeasuredSize(
        onChanged: _handleColorRangeCardSizeChanged,
        child: WorkspaceFloatingPanel(
          width: _kColorRangePanelWidth,
          minHeight: _kColorRangePanelMinHeight,
          title: context.l10n.colorRangeTitle,
          onClose: _cancelColorRangeEditing,
          onDragUpdate: _updateColorRangeCardOffset,
          bodyPadding: const EdgeInsets.symmetric(horizontal: 16),
          footerPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          footerSpacing: 10,
          headerPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: _colorRangeLoading
              ? const SizedBox(
                  height: _kColorRangePanelMinHeight,
                  child: Center(child: ProgressRing()),
                )
              : _ColorRangeCardBody(
                  totalColors: totalColors,
                  maxSelectableColors: maxSelectable,
                  selectedColors: selected,
                  isBusy: busy,
                  onChanged: _updateColorRangeSelection,
                ),
          footer: Row(
            children: [
              Button(
                onPressed: (_colorRangeLoading || _colorRangeApplying)
                    ? null
                    : _resetColorRangeSelection,
                child: Text(context.l10n.reset),
              ),
              const SizedBox(width: 8),
              Button(
                onPressed:
                    _colorRangeApplying ? null : _cancelColorRangeEditing,
                child: Text(context.l10n.cancel),
              ),
              const Spacer(),
              FilledButton(
                onPressed: (_colorRangeApplying ||
                        _colorRangeLoading ||
                        _colorRangePreviewInFlight)
                    ? null
                    : _applyColorRangeSelection,
                child: _colorRangeApplying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    : Text(context.l10n.apply),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildAntialiasCard() {
    if (!_antialiasCardVisible) {
      return null;
    }
    return Positioned(
      left: _antialiasCardOffset.dx,
      top: _antialiasCardOffset.dy,
      child: MeasuredSize(
        onChanged: _handleAntialiasCardSizeChanged,
        child: WorkspaceFloatingPanel(
          width: _kAntialiasPanelWidth,
          minHeight: _kAntialiasPanelMinHeight,
          title: context.l10n.edgeSoftening,
          onClose: hideLayerAntialiasPanel,
          onDragUpdate: _updateAntialiasCardOffset,
          bodyPadding: const EdgeInsets.symmetric(horizontal: 16),
          headerPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          footerPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          bodySpacing: 0,
          footerSpacing: 10,
          child: _AntialiasPanelBody(
            level: _antialiasCardLevel,
            onLevelChanged: _handleAntialiasLevelChanged,
          ),
          footer: Row(
            children: [
              Button(
                onPressed: hideLayerAntialiasPanel,
                child: Text(context.l10n.cancel),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _applyAntialiasFromCard,
                child: Text(context.l10n.apply),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    final OverlayEntry? entry = _workspaceCardsOverlayEntry;
    if (entry != null && entry.mounted) {
      entry.remove();
    }
    _workspaceCardsOverlayEntry = null;
    super.dispose();
  }
}

Widget _buildTransformedLayerOverlay({
  required ui.Image image,
  required double opacity,
  required ui.BlendMode? blendMode,
}) {
  Widget content = RawImage(
    image: image,
    filterQuality: FilterQuality.none,
    fit: BoxFit.none,
    alignment: Alignment.topLeft,
    colorBlendMode: blendMode,
    color: blendMode != null ? const Color(0xFFFFFFFF) : null,
  );
  final double clampedOpacity = opacity.clamp(0.0, 1.0).toDouble();
  if (clampedOpacity < 0.999) {
    content = Opacity(opacity: clampedOpacity, child: content);
  }
  return content;
}

ui.BlendMode? _flutterBlendMode(CanvasLayerBlendMode mode) {
  return mode.flutterBlendMode;
}
