part of 'painting_board.dart';

mixin _PaintingBoardBuildMixin on _PaintingBoardBase {
  @override
  Widget build(BuildContext context) {
    final bool canUndo = _store.canUndo;
    final bool canRedo = _store.canRedo;
    final Map<LogicalKeySet, Intent> shortcutBindings = {
      for (final key in ToolbarShortcuts.of(ToolbarAction.undo).shortcuts)
        key: const UndoIntent(),
      for (final key in ToolbarShortcuts.of(ToolbarAction.redo).shortcuts)
        key: const RedoIntent(),
      for (final key in ToolbarShortcuts.of(ToolbarAction.penTool).shortcuts)
        key: const SelectToolIntent(CanvasTool.pen),
      for (final key in ToolbarShortcuts.of(ToolbarAction.bucketTool).shortcuts)
        key: const SelectToolIntent(CanvasTool.bucket),
      for (final key in ToolbarShortcuts.of(ToolbarAction.handTool).shortcuts)
        key: const SelectToolIntent(CanvasTool.hand),
      for (final key in ToolbarShortcuts.of(ToolbarAction.exit).shortcuts)
        key: const ExitBoardIntent(),
    };

    final theme = FluentTheme.of(context);
    final bool isDark = theme.brightness.isDark;
    final Color workspaceColor = isDark
        ? const Color(0xFF1B1B1F)
        : const Color(0xFFE5E5E5);

    return LayoutBuilder(
      builder: (context, constraints) {
        _workspaceSize = constraints.biggest;
        _initializeViewportIfNeeded();
        final Size scaledSize = _scaledBoardSize;
        _layoutBaseOffset = Offset(
          (_workspaceSize.width - scaledSize.width) / 2,
          (_workspaceSize.height - scaledSize.height) / 2,
        );
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
                    child: Container(
                      color: workspaceColor,
                      child: Stack(
                        children: [
                          Positioned(
                            left: boardRect.left,
                            top: boardRect.top,
                            child: SizedBox(
                              width: _scaledBoardSize.width,
                              height: _scaledBoardSize.height,
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
                                    child: CustomPaint(
                                      painter: StrokePainter(
                                        cache: _strokeCache,
                                        cacheVersion: _strokeCache.version,
                                        currentStroke: _store.currentStroke,
                                        currentStrokeVersion:
                                            _currentStrokeVersion,
                                        scale: _viewport.scale,
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
                              onToolSelected: _setActiveTool,
                              onUndo: _handleUndo,
                              onRedo: _handleRedo,
                              canUndo: canUndo,
                              canRedo: canRedo,
                              onExit: widget.onRequestExit,
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
