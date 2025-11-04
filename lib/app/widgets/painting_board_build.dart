part of 'painting_board.dart';

mixin _PaintingBoardBuildMixin on _PaintingBoardBase {
  @override
  Widget build(BuildContext context) {
    _refreshHistoryLimit();
    final bool canUndo = this.canUndo;
    final bool canRedo = this.canRedo;
    final Map<LogicalKeySet, Intent> shortcutBindings = {
      for (final key in ToolbarShortcuts.of(ToolbarAction.undo).shortcuts)
        key: const UndoIntent(),
      for (final key in ToolbarShortcuts.of(ToolbarAction.redo).shortcuts)
        key: const RedoIntent(),
      for (final key in ToolbarShortcuts.of(ToolbarAction.penTool).shortcuts)
        key: const SelectToolIntent(CanvasTool.pen),
      for (final key in ToolbarShortcuts.of(ToolbarAction.bucketTool).shortcuts)
        key: const SelectToolIntent(CanvasTool.bucket),
      for (final key
          in ToolbarShortcuts.of(ToolbarAction.magicWandTool).shortcuts)
        key: const SelectToolIntent(CanvasTool.magicWand),
      for (final key
          in ToolbarShortcuts.of(ToolbarAction.selectionTool).shortcuts)
        key: const SelectToolIntent(CanvasTool.selection),
      for (final key in ToolbarShortcuts.of(ToolbarAction.handTool).shortcuts)
        key: const SelectToolIntent(CanvasTool.hand),
      for (final key in ToolbarShortcuts.of(ToolbarAction.exit).shortcuts)
        key: const ExitBoardIntent(),
      for (final key in ToolbarShortcuts.of(ToolbarAction.deselect).shortcuts)
        key: const DeselectIntent(),
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
        final Rect boardRect = _boardRect;

        final MouseCursor workspaceCursor = _activeTool == CanvasTool.hand
            ? SystemMouseCursors.move
            : SystemMouseCursors.basic;

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
            },
            child: Focus(
              focusNode: _focusNode,
              autofocus: true,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
                onScaleEnd: _handleScaleEnd,
                child: MouseRegion(
                  cursor: workspaceCursor,
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
                                          final ui.Image? image = _controller.image;
                                          if (image == null) {
                                            return const SizedBox.shrink();
                                          }
                                          final bool hasSelectionOverlay =
                                              selectionPath != null ||
                                                  selectionPreviewPath !=
                                                      null ||
                                                  magicWandPreviewPath !=
                                                      null;
                                          return Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              const _CheckboardBackground(),
                                              RawImage(
                                                image: image,
                                                filterQuality:
                                                    FilterQuality.none,
                                              ),
                                              if (hasSelectionOverlay)
                                                Positioned.fill(
                                                  child: CustomPaint(
                                                    painter:
                                                      _SelectionOverlayPainter(
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
                          Positioned(
                            left: _toolButtonPadding,
                            top: _toolButtonPadding,
                            child: CanvasToolbar(
                              activeTool: _activeTool,
                              selectionShape: selectionShape,
                              onToolSelected: _setActiveTool,
                              onUndo: _handleUndo,
                              onRedo: _handleRedo,
                              canUndo: canUndo,
                              canRedo: canRedo,
                              onExit: widget.onRequestExit,
                            ),
                          ),
                          Positioned(
                            left: _toolButtonPadding +
                                _toolbarButtonSize +
                                _toolSettingsSpacing,
                            top: _toolButtonPadding,
                            child: _ToolSettingsCard(
                              activeTool: _activeTool,
                              penStrokeWidth: _penStrokeWidth,
                              onPenStrokeWidthChanged: _updatePenStrokeWidth,
                              bucketSampleAllLayers: _bucketSampleAllLayers,
                              bucketContiguous: _bucketContiguous,
                              onBucketSampleAllLayersChanged:
                                  _updateBucketSampleAllLayers,
                              onBucketContiguousChanged:
                                  _updateBucketContiguous,
                              selectionShape: selectionShape,
                              onSelectionShapeChanged: _updateSelectionShape,
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
