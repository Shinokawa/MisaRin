part of 'painting_board.dart';

mixin _PaintingBoardBuildMixin
    on _PaintingBoardBase, _PaintingBoardInteractionMixin {
  @override
  Widget build(BuildContext context) {
    _refreshStylusPreferencesIfNeeded();
    _refreshHistoryLimit();
    final bool canUndo = this.canUndo;
    final bool canRedo = this.canRedo;
    final Map<LogicalKeySet, Intent> shortcutBindings = {
      for (final key in ToolbarShortcuts.of(ToolbarAction.undo).shortcuts)
        key: const UndoIntent(),
      for (final key in ToolbarShortcuts.of(ToolbarAction.redo).shortcuts)
        key: const RedoIntent(),
      for (final key in ToolbarShortcuts.of(
        ToolbarAction.layerAdjustTool,
      ).shortcuts)
        key: const SelectToolIntent(CanvasTool.layerAdjust),
      for (final key in ToolbarShortcuts.of(ToolbarAction.penTool).shortcuts)
        key: const SelectToolIntent(CanvasTool.pen),
      for (final key in ToolbarShortcuts.of(
        ToolbarAction.curvePenTool,
      ).shortcuts)
        key: const SelectToolIntent(CanvasTool.curvePen),
      for (final key in ToolbarShortcuts.of(ToolbarAction.shapeTool).shortcuts)
        key: const SelectToolIntent(CanvasTool.shape),
      for (final key in ToolbarShortcuts.of(ToolbarAction.bucketTool).shortcuts)
        key: const SelectToolIntent(CanvasTool.bucket),
      for (final key in ToolbarShortcuts.of(
        ToolbarAction.magicWandTool,
      ).shortcuts)
        key: const SelectToolIntent(CanvasTool.magicWand),
      for (final key in ToolbarShortcuts.of(
        ToolbarAction.eyedropperTool,
      ).shortcuts)
        key: const SelectToolIntent(CanvasTool.eyedropper),
      for (final key in ToolbarShortcuts.of(
        ToolbarAction.selectionTool,
      ).shortcuts)
        key: const SelectToolIntent(CanvasTool.selection),
      for (final key in ToolbarShortcuts.of(ToolbarAction.handTool).shortcuts)
        key: const SelectToolIntent(CanvasTool.hand),
      for (final key in ToolbarShortcuts.of(ToolbarAction.exit).shortcuts)
        key: const ExitBoardIntent(),
      for (final key in ToolbarShortcuts.of(ToolbarAction.deselect).shortcuts)
        key: const DeselectIntent(),
      LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyX):
          const CutIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyX):
          const CutIntent(),
      LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyC):
          const CopyIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC):
          const CopyIntent(),
      LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyV):
          const PasteIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV):
          const PasteIntent(),
    };

    final theme = FluentTheme.of(context);
    final bool isDark = theme.brightness.isDark;
    final Color workspaceColor = isDark
        ? const Color(0xFF1B1B1F)
        : const Color(0xFFE5E5E5);

    return LayoutBuilder(
      builder: (context, constraints) {
        final Size candidate = constraints.biggest;
        if (candidate.width.isFinite && candidate.height.isFinite) {
          _workspaceSize = candidate;
        }
        _scheduleWorkspaceMeasurement(context);
        _initializeViewportIfNeeded();
        _layoutBaseOffset = _baseOffsetForScale(_viewport.scale);
        _toolbarLayout = CanvasToolbar.layoutForAvailableHeight(
          _workspaceSize.height - _toolButtonPadding * 2,
        );
        final double toolSettingsLeft =
            _toolButtonPadding + _toolbarLayout.width + _toolSettingsSpacing;
        final double sidebarLeft =
            (_workspaceSize.width - _sidePanelWidth - _toolButtonPadding).clamp(
              0.0,
              double.infinity,
            );
        final double computedToolSettingsMaxWidth =
            sidebarLeft - toolSettingsLeft - _toolSettingsSpacing;
        final double? toolSettingsMaxWidth =
            computedToolSettingsMaxWidth.isFinite &&
                computedToolSettingsMaxWidth > 0
            ? computedToolSettingsMaxWidth
            : null;
        final Rect boardRect = _boardRect;
        final ToolCursorStyle? cursorStyle = ToolCursorStyles.styleFor(
          _effectiveActiveTool,
        );
        final bool hideCursorBecauseToolOverlay =
            cursorStyle != null &&
            _toolCursorPosition != null &&
            cursorStyle.hideSystemCursor;
        final bool hideCursorBecausePen =
            _penRequiresOverlay && _penCursorWorkspacePosition != null;
        final bool shouldHideCursor =
            hideCursorBecauseToolOverlay || hideCursorBecausePen;
        final bool isLayerAdjustDragging =
            _effectiveActiveTool == CanvasTool.layerAdjust && _isLayerDragging;

        final MouseCursor boardCursor;
        if (hideCursorBecauseToolOverlay || hideCursorBecausePen) {
          boardCursor = SystemMouseCursors.none;
        } else if (_effectiveActiveTool == CanvasTool.layerAdjust) {
          boardCursor = _isLayerDragging
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.move;
        } else {
          boardCursor = MouseCursor.defer;
        }

        final MouseCursor workspaceCursor;
        if (shouldHideCursor) {
          workspaceCursor = SystemMouseCursors.none;
        } else {
          switch (_effectiveActiveTool) {
            case CanvasTool.hand:
              workspaceCursor = _isDraggingBoard
                  ? SystemMouseCursors.grabbing
                  : SystemMouseCursors.grab;
              break;
            case CanvasTool.layerAdjust:
              workspaceCursor = _isLayerDragging
                  ? SystemMouseCursors.grabbing
                  : SystemMouseCursors.move;
              break;
            case CanvasTool.curvePen:
              workspaceCursor = SystemMouseCursors.precise;
              break;
            case CanvasTool.shape:
              workspaceCursor = SystemMouseCursors.precise;
              break;
            case CanvasTool.eyedropper:
              workspaceCursor = SystemMouseCursors.basic;
              break;
            default:
              workspaceCursor = SystemMouseCursors.basic;
              break;
          }
        }

        return Shortcuts(
          shortcuts: shortcutBindings,
          child: Actions(
            actions: <Type, Action<Intent>>{
              UndoIntent: CallbackAction<UndoIntent>(
                onInvoke: (intent) {
                  _handleUndo();
                  return null;
                },
              ),
              RedoIntent: CallbackAction<RedoIntent>(
                onInvoke: (intent) {
                  _handleRedo();
                  return null;
                },
              ),
              SelectToolIntent: CallbackAction<SelectToolIntent>(
                onInvoke: (intent) {
                  _setActiveTool(intent.tool);
                  return null;
                },
              ),
              ExitBoardIntent: CallbackAction<ExitBoardIntent>(
                onInvoke: (intent) {
                  widget.onRequestExit();
                  return null;
                },
              ),
              DeselectIntent: CallbackAction<DeselectIntent>(
                onInvoke: (intent) {
                  _clearSelection();
                  return null;
                },
              ),
              CutIntent: CallbackAction<CutIntent>(
                onInvoke: (intent) {
                  cut();
                  return null;
                },
              ),
              CopyIntent: CallbackAction<CopyIntent>(
                onInvoke: (intent) {
                  copy();
                  return null;
                },
              ),
              PasteIntent: CallbackAction<PasteIntent>(
                onInvoke: (intent) {
                  paste();
                  return null;
                },
              ),
            },
            child: Focus(
              focusNode: _focusNode,
              autofocus: true,
              onKeyEvent: _handleWorkspaceKeyEvent,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
                onScaleEnd: _handleScaleEnd,
                child: MouseRegion(
                  cursor: workspaceCursor,
                  onExit: (_) => _handleWorkspacePointerExit(),
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _handlePointerDown,
                    onPointerMove: _handlePointerMove,
                    onPointerUp: _handlePointerUp,
                    onPointerCancel: _handlePointerCancel,
                    onPointerSignal: _handlePointerSignal,
                    onPointerHover: _handlePointerHover,
                    child: Container(
                      color: workspaceColor,
                      child: Stack(
                        children: [
                          Positioned(
                            left: boardRect.left,
                            top: boardRect.top,
                            child: MouseRegion(
                              cursor: boardCursor,
                              child: Transform.scale(
                                scale: _viewport.scale,
                                alignment: Alignment.topLeft,
                                child: SizedBox(
                                  width: _canvasSize.width,
                                  height: _canvasSize.height,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isDark
                                            ? Color.lerp(
                                                Colors.white,
                                                Colors.transparent,
                                                0.88,
                                              )!
                                            : const Color(0x33000000),
                                        width: 1,
                                      ),
                                    ),
                                    child: ClipRect(
                                      child: RepaintBoundary(
                                        child: AnimatedBuilder(
                                          animation: _controller,
                                          builder: (context, _) {
                                            final ui.Image? image =
                                                _controller.image;
                                            if (image == null) {
                                              return const SizedBox.shrink();
                                            }
                                            final bool isTransforming =
                                                _controller
                                                    .isActiveLayerTransforming;
                                            final ui.Image?
                                            transformedActiveLayerImage =
                                                _controller
                                                    .activeLayerTransformImage;
                                            final Offset
                                            transformedLayerOffset = _controller
                                                .activeLayerTransformOffset;
                                            final double
                                            transformedLayerOpacity = _controller
                                                .activeLayerTransformOpacity;
                                            final ui.BlendMode?
                                            transformedLayerBlendMode =
                                                _flutterBlendMode(
                                                  _controller
                                                      .activeLayerTransformBlendMode,
                                                );
                                            final bool hasSelectionOverlay =
                                                selectionPath != null ||
                                                selectionPreviewPath != null ||
                                                magicWandPreviewPath != null;
                                            return Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                const _CheckboardBackground(),
                                                RawImage(
                                                  image: image,
                                                  filterQuality:
                                                      FilterQuality.none,
                                                ),
                                                if (isTransforming &&
                                                    transformedActiveLayerImage !=
                                                        null)
                                                  Positioned.fill(
                                                    child: IgnorePointer(
                                                      ignoring: true,
                                                      child: Transform.translate(
                                                        offset:
                                                            transformedLayerOffset,
                                                        child: _buildTransformedLayerOverlay(
                                                          image:
                                                              transformedActiveLayerImage,
                                                          opacity:
                                                              transformedLayerOpacity,
                                                          blendMode:
                                                              transformedLayerBlendMode,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                if (_curvePreviewPath != null)
                                                  Positioned.fill(
                                                    child: CustomPaint(
                                                      painter: _PreviewPathPainter(
                                                        path:
                                                            _curvePreviewPath!,
                                                        color: _primaryColor,
                                                        strokeWidth:
                                                            _penStrokeWidth,
                                                      ),
                                                    ),
                                                  ),
                                                if (shapePreviewPath != null)
                                                  Positioned.fill(
                                                    child: CustomPaint(
                                                      painter:
                                                          _PreviewPathPainter(
                                                            path:
                                                                shapePreviewPath!,
                                                            color:
                                                                _primaryColor,
                                                            strokeWidth:
                                                                _penStrokeWidth,
                                                          ),
                                                    ),
                                                  ),
                                                if (hasSelectionOverlay)
                                                  Positioned.fill(
                                                    child: CustomPaint(
                                                      painter: _SelectionOverlayPainter(
                                                        selectionPath:
                                                            selectionPath,
                                                        selectionPreviewPath:
                                                            selectionPreviewPath,
                                                        magicPreviewPath:
                                                            magicWandPreviewPath,
                                                        dashPhase:
                                                            selectionDashPhase,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: _toolButtonPadding,
                            top: _toolButtonPadding,
                            child: CanvasToolbar(
                              activeTool: _activeTool,
                              selectionShape: selectionShape,
                              shapeToolVariant: shapeToolVariant,
                              onToolSelected: _setActiveTool,
                              onUndo: _handleUndo,
                              onRedo: _handleRedo,
                              canUndo: canUndo,
                              canRedo: canRedo,
                              onExit: widget.onRequestExit,
                              layout: _toolbarLayout,
                            ),
                          ),
                          Positioned(
                            left:
                                _toolButtonPadding +
                                _toolbarLayout.width +
                                _toolSettingsSpacing,
                            top: _toolButtonPadding,
                            child: Container(
                              constraints: toolSettingsMaxWidth != null
                                  ? BoxConstraints(
                                      maxWidth: toolSettingsMaxWidth,
                                    )
                                  : null,
                              child: _ToolSettingsCard(
                                activeTool: _activeTool,
                                penStrokeWidth: _penStrokeWidth,
                                penStrokeSliderRange: _penStrokeSliderRange,
                                onPenStrokeWidthChanged: _updatePenStrokeWidth,
                                brushShape: _brushShape,
                                onBrushShapeChanged: _updateBrushShape,
                                strokeStabilizerStrength:
                                    _strokeStabilizerStrength,
                                onStrokeStabilizerChanged:
                                    _updateStrokeStabilizerStrength,
                                stylusPressureEnabled: _stylusPressureEnabled,
                                onStylusPressureEnabledChanged:
                                    _updateStylusPressureEnabled,
                                simulatePenPressure: _simulatePenPressure,
                                onSimulatePenPressureChanged:
                                    _updatePenPressureSimulation,
                                penPressureProfile: _penPressureProfile,
                                onPenPressureProfileChanged:
                                    _updatePenPressureProfile,
                                brushAntialiasLevel: _penAntialiasLevel,
                                onBrushAntialiasChanged:
                                    _updatePenAntialiasLevel,
                                autoSharpPeakEnabled: _autoSharpPeakEnabled,
                                onAutoSharpPeakChanged:
                                    _updateAutoSharpPeakEnabled,
                                bucketSampleAllLayers: _bucketSampleAllLayers,
                                bucketContiguous: _bucketContiguous,
                                bucketSwallowColorLine: _bucketSwallowColorLine,
                                onBucketSampleAllLayersChanged:
                                    _updateBucketSampleAllLayers,
                                onBucketContiguousChanged:
                                    _updateBucketContiguous,
                                onBucketSwallowColorLineChanged:
                                    _updateBucketSwallowColorLine,
                                layerAdjustCropOutside: _layerAdjustCropOutside,
                                onLayerAdjustCropOutsideChanged:
                                    _updateLayerAdjustCropOutside,
                                selectionShape: selectionShape,
                                onSelectionShapeChanged: _updateSelectionShape,
                                shapeToolVariant: shapeToolVariant,
                                onShapeToolVariantChanged:
                                    _updateShapeToolVariant,
                                onSizeChanged: _updateToolSettingsCardSize,
                              ),
                            ),
                          ),
                          Positioned(
                            left: _toolButtonPadding,
                            bottom: _toolButtonPadding,
                            child: _buildColorIndicator(theme),
                          ),
                          Positioned(
                            right: _toolButtonPadding,
                            top: _toolButtonPadding,
                            bottom: _toolButtonPadding,
                            child: SizedBox(
                              width: _sidePanelWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _PanelCard(
                                    width: _sidePanelWidth,
                                    title: '取色',
                                    trailing: _buildColorPanelTrailing(theme),
                                    child: _buildColorPanelContent(theme),
                                  ),
                                  const SizedBox(height: _sidePanelSpacing),
                                  Expanded(
                                    child: _PanelCard(
                                      width: _sidePanelWidth,
                                      title: '图层管理',
                                      trailing: Button(
                                        onPressed: _handleAddLayer,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(FluentIcons.add, size: 14),
                                            SizedBox(width: 6),
                                            Text('新增图层'),
                                          ],
                                        ),
                                      ),
                                      expand: true,
                                      child: _buildLayerPanelContent(theme),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_toolCursorPosition != null &&
                              cursorStyle != null)
                            Positioned(
                              left:
                                  _toolCursorPosition!.dx -
                                  cursorStyle.anchor.dx +
                                  cursorStyle.iconOffset.dx,
                              top:
                                  _toolCursorPosition!.dy -
                                  cursorStyle.anchor.dy +
                                  cursorStyle.iconOffset.dy,
                              child: IgnorePointer(
                                ignoring: true,
                                child: ToolCursorStyles.iconFor(
                                  _effectiveActiveTool,
                                  isDragging: isLayerAdjustDragging,
                                ),
                              ),
                            ),
                          if (_penRequiresOverlay &&
                              _penCursorWorkspacePosition != null)
                            PenCursorOverlay(
                              position: _penCursorWorkspacePosition!,
                              diameter: _penStrokeWidth * _viewport.scale,
                              shape: _brushShape,
                            ),
                          if (_toolCursorPosition != null)
                            Positioned(
                              left:
                                  _toolCursorPosition!.dx -
                                  ToolCursorStyles.crosshairSize / 2,
                              top:
                                  _toolCursorPosition!.dy -
                                  ToolCursorStyles.crosshairSize / 2,
                              child: const IgnorePointer(
                                ignoring: true,
                                child: ToolCursorCrosshair(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
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
