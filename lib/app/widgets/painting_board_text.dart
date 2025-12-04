part of 'painting_board.dart';

class _TextEditingSession {
  _TextEditingSession({
    required this.origin,
    required this.isNewLayer,
    this.layerId,
    this.layerWasVisible = true,
    this.originalData,
    this.pendingHistoryEntry,
  });

  final Offset origin;
  final bool isNewLayer;
  final String? layerId;
  final bool layerWasVisible;
  final CanvasTextData? originalData;
  final Future<_CanvasHistoryEntry>? pendingHistoryEntry;
  CanvasTextData? data;
  Rect? bounds;
}

class _CommitTextEditingIntent extends Intent {
  const _CommitTextEditingIntent();
}

class _CancelTextEditingIntent extends Intent {
  const _CancelTextEditingIntent();
}

mixin _PaintingBoardTextMixin on _PaintingBoardBase {
  final CanvasTextRenderer _textOverlayRenderer = CanvasTextRenderer();
  final TextEditingController _textEditingController = TextEditingController();
  final FocusNode _textEditingFocusNode = FocusNode();

  _TextEditingSession? _textSession;
  List<String> _textFontFamilies = const <String>[];
  bool _textFontsLoading = false;

  double _textFontSize = 48;
  double _textLineHeight = 1.2;
  double _textLeftMargin = 0;
  double _textStrokeWidth = 1.0;
  String _textFontFamily = '';
  TextAlign _textAlign = TextAlign.left;
  CanvasTextOrientation _textOrientation =
      CanvasTextOrientation.horizontal;
  bool _textAntialias = true;
  bool _textStrokeEnabled = false;
  Future<void>? _pendingTextLayerUpdate;

  void initializeTextTool() {
    _textEditingController.addListener(_handleTextFieldChanged);
    _loadSystemFonts();
  }

  void disposeTextTool() {
    _textEditingController.removeListener(_handleTextFieldChanged);
    _textEditingController.dispose();
    _textEditingFocusNode.dispose();
  }

  Future<void> _loadSystemFonts() async {
    setState(() => _textFontsLoading = true);
    final List<String> fonts = await SystemFonts.loadFamilies();
    if (!mounted) {
      return;
    }
    setState(() {
      _textFontFamilies = fonts;
      _textFontsLoading = false;
    });
  }

  bool get _isTextEditingActive => _textSession != null;

  Widget? buildTextEditingOverlay() {
    final _TextEditingSession? session = _textSession;
    if (session == null || session.data == null || session.bounds == null) {
      return null;
    }
    final Rect bounds = session.bounds!;
    final double scale = _viewport.scale;
    final Offset workspacePosition = Offset(
      _boardRect.left + bounds.left * scale,
      _boardRect.top + bounds.top * scale,
    );
    final CanvasTextData data = session.data!;
    final bool showPreviewPainter = session.isNewLayer;
    return Positioned(
      left: workspacePosition.dx,
      top: workspacePosition.dy,
      child: _TextEditorOverlay(
        renderer: _textOverlayRenderer,
        data: data,
        bounds: bounds,
        scale: scale,
        controller: _textEditingController,
        focusNode: _textEditingFocusNode,
        cursorColor: _primaryColor,
        selectionColor: _primaryColor.withOpacity(0.25),
        onConfirm: () {
          unawaited(_commitTextEditingSession());
        },
        onCancel: () {
          unawaited(_cancelTextEditingSession());
        },
        paintPreview: showPreviewPainter,
      ),
    );
  }

  void _handleTextFieldChanged() {
    final _TextEditingSession? session = _textSession;
    if (session == null) {
      return;
    }
    _updateTextPreview(session.origin);
  }

  void _updateTextPreview(Offset origin) {
    final _TextEditingSession? session = _textSession;
    if (session == null) {
      return;
    }
    final CanvasTextData data = _buildTextData(
      origin: origin,
      text: _textEditingController.text,
    );
    final CanvasTextLayout layout = _textOverlayRenderer.layout(data);
    setState(() {
      session.data = data;
      session.bounds = layout.bounds;
    });
    if (!session.isNewLayer && session.layerId != null) {
      _scheduleLiveTextLayerUpdate(
        session.layerId!,
        data,
        waitForHistoryEntry: session.pendingHistoryEntry,
      );
    }
  }

  void _scheduleLiveTextLayerUpdate(
    String layerId,
    CanvasTextData data, {
    Future<_CanvasHistoryEntry>? waitForHistoryEntry,
  }) {
    Future<void> previous =
        _pendingTextLayerUpdate ?? Future<void>.value();
    if (waitForHistoryEntry != null) {
      previous = Future.wait<void>(
        <Future<void>>[
          previous,
          waitForHistoryEntry.then((_) {}),
        ],
      );
    }
    final Future<void> next =
        previous.then((_) => _controller.updateTextLayer(layerId, data));
    _pendingTextLayerUpdate =
        next.catchError((Object error, StackTrace stackTrace) {
      debugPrint('文字图层实时渲染失败: $error');
    });
  }

  Future<void> _waitForPendingTextLayerUpdate() async {
    final Future<void>? pending = _pendingTextLayerUpdate;
    if (pending == null) {
      return;
    }
    try {
      await pending;
    } finally {
      if (identical(_pendingTextLayerUpdate, pending)) {
        _pendingTextLayerUpdate = null;
      }
    }
  }

  CanvasTextData _buildTextData({
    required Offset origin,
    required String text,
  }) {
    final double maxWidth = (_canvasSize.width - origin.dx)
        .clamp(32.0, _canvasSize.width);
    return CanvasTextData(
      text: text,
      origin: origin,
      fontSize: _textFontSize,
      fontFamily: _textFontFamily,
      color: _primaryColor,
      lineHeight: _textLineHeight,
      leftMargin: _textLeftMargin,
      maxWidth: maxWidth,
      align: _textAlign,
      orientation: _textOrientation,
      antialias: _textAntialias,
      strokeEnabled: _textStrokeEnabled,
      strokeWidth: _textStrokeWidth,
      strokeColor: _colorLineColor,
    );
  }

  void _beginNewTextSession(Offset origin) {
    _pendingTextLayerUpdate = null;
    _textEditingController
      ..clear()
      ..selection = const TextSelection.collapsed(offset: 0);
    _textSession = _TextEditingSession(
      origin: origin,
      isNewLayer: true,
    );
    _updateTextPreview(origin);
    setState(() {});
    _textEditingFocusNode.requestFocus();
  }

  Rect? _textOverlayWorkspaceRect() {
    final _TextEditingSession? session = _textSession;
    if (session == null || session.bounds == null) {
      return null;
    }
    final Rect bounds = session.bounds!;
    final double scale = _viewport.scale;
    return Rect.fromLTWH(
      _boardRect.left + bounds.left * scale,
      _boardRect.top + bounds.top * scale,
      bounds.width * scale,
      bounds.height * scale,
    );
  }

  void _beginEditExistingTextLayer(BitmapLayerState layer) {
    final CanvasTextData? existing = layer.text;
    if (existing == null) {
      return;
    }
    if (layer.locked) {
      AppNotifications.show(
        context,
        message: '请先解锁文字图层后再编辑。',
        severity: InfoBarSeverity.warning,
      );
      return;
    }
    _textFontFamily = existing.fontFamily;
    _textFontSize = existing.fontSize;
    _textLineHeight = existing.lineHeight;
    _textLeftMargin = existing.leftMargin;
    _textAlign = existing.align;
    _textOrientation = existing.orientation;
    _textAntialias = existing.antialias;
    _textStrokeEnabled = existing.strokeEnabled;
    _textStrokeWidth = existing.strokeWidth;
    _colorLineColor = existing.strokeColor;
    _primaryColor = existing.color;
    _primaryHsv = HSVColor.fromColor(existing.color);
    _textEditingController.text = existing.text;
    _textEditingController.selection = TextSelection.collapsed(
      offset: existing.text.length,
    );
    _pendingTextLayerUpdate = null;
    final Future<_CanvasHistoryEntry> pendingHistory =
        _createHistoryEntry();
    _textSession = _TextEditingSession(
      origin: existing.origin,
      isNewLayer: false,
      layerId: layer.id,
      layerWasVisible: layer.visible,
      originalData: existing,
      pendingHistoryEntry: pendingHistory,
    );
    _updateTextPreview(existing.origin);
    setState(() {});
    _textEditingFocusNode.requestFocus();
  }

  Future<void> _commitTextEditingSession() async {
    final _TextEditingSession? session = _textSession;
    if (session == null) {
      return;
    }
    final String content = _textEditingController.text;
    if (content.trim().isEmpty) {
      await _cancelTextEditingSession();
      return;
    }
    final CanvasTextData data = (session.data ??
        _buildTextData(origin: session.origin, text: content)).copyWith(
      text: content,
    );
    await _waitForPendingTextLayerUpdate();
    _textEditingController.clear();
    setState(() {
      _textSession = null;
    });
    if (session.isNewLayer) {
      await _pushUndoSnapshot();
      await _controller.createTextLayer(data);
      return;
    }
    if (session.layerId == null) {
      return;
    }
    final Future<_CanvasHistoryEntry>? pendingHistory =
        session.pendingHistoryEntry;
    _restoreTextLayerVisibility(session.layerId!, session.layerWasVisible);
    if (pendingHistory != null) {
      final _CanvasHistoryEntry entry = await pendingHistory;
      await _pushUndoSnapshot(entry: entry);
    } else {
      await _pushUndoSnapshot();
    }
    await _controller.updateTextLayer(session.layerId!, data);
  }

  Future<void> _cancelTextEditingSession() async {
    final _TextEditingSession? session = _textSession;
    if (session == null) {
      return;
    }
    _textEditingController.clear();
    setState(() {
      _textSession = null;
    });
    if (session.isNewLayer || session.layerId == null) {
      return;
    }
    await _waitForPendingTextLayerUpdate();
    _restoreTextLayerVisibility(session.layerId!, session.layerWasVisible);
    final CanvasTextData? original = session.originalData;
    if (original != null) {
      await _controller.updateTextLayer(session.layerId!, original);
    }
  }

  void _restoreTextLayerVisibility(String id, bool wasVisible) {
    for (final BitmapLayerState layer in _controller.layers) {
      if (layer.id == id) {
        layer.visible = wasVisible;
        break;
      }
    }
    _controller.notifyListeners();
  }

  bool _activeLayerIsText() {
    final BitmapLayerState layer = _controller.activeLayer;
    return layer.text != null;
  }

  void _showTextToolConflictWarning() {
    AppNotifications.show(
      context,
      message: '当前图层是文字图层，请先栅格化或切换其他图层。',
      severity: InfoBarSeverity.warning,
    );
  }

  BitmapLayerState? _hitTestTextLayer(Offset boardLocal) {
    final List<BitmapLayerState> layers =
        _controller.layers.toList(growable: false);
    for (int i = layers.length - 1; i >= 0; i--) {
      final BitmapLayerState layer = layers[i];
      if (!layer.visible || layer.text == null || layer.textBounds == null) {
        continue;
      }
      if (layer.textBounds!.contains(boardLocal)) {
        return layer;
      }
    }
    return null;
  }

  void _updateTextFontFamily(String family) {
    if (_textFontFamily == family) {
      return;
    }
    setState(() => _textFontFamily = family);
    _refreshTextPreview();
  }

  void _updateTextFontSize(double value) {
    final double clamped = value.clamp(4.0, 512.0);
    if ((_textFontSize - clamped).abs() < 0.01) {
      return;
    }
    setState(() => _textFontSize = clamped);
    _refreshTextPreview();
  }

  void _updateTextLineHeight(double value) {
    final double clamped = value.clamp(0.5, 4.0);
    if ((_textLineHeight - clamped).abs() < 0.01) {
      return;
    }
    setState(() => _textLineHeight = clamped);
    _refreshTextPreview();
  }

  void _updateTextLeftMargin(double value) {
    final double clamped = value.clamp(-200.0, 400.0);
    if ((_textLeftMargin - clamped).abs() < 0.5) {
      return;
    }
    setState(() => _textLeftMargin = clamped);
    _refreshTextPreview();
  }

  void _updateTextAlign(TextAlign align) {
    if (_textAlign == align) {
      return;
    }
    setState(() => _textAlign = align);
    _refreshTextPreview();
  }

  void _updateTextOrientation(CanvasTextOrientation orientation) {
    if (_textOrientation == orientation) {
      return;
    }
    setState(() => _textOrientation = orientation);
    _refreshTextPreview();
  }

  void _updateTextAntialias(bool value) {
    if (_textAntialias == value) {
      return;
    }
    setState(() => _textAntialias = value);
    _refreshTextPreview();
  }

  void _updateTextStrokeEnabled(bool value) {
    if (_textStrokeEnabled == value) {
      return;
    }
    setState(() => _textStrokeEnabled = value);
    _refreshTextPreview();
  }

  void _updateTextStrokeWidth(double value) {
    final double clamped = value.clamp(0.5, 20.0);
    if ((_textStrokeWidth - clamped).abs() < 0.01) {
      return;
    }
    setState(() => _textStrokeWidth = clamped);
    _refreshTextPreview();
  }

  void _refreshTextPreview() {
    final _TextEditingSession? session = _textSession;
    if (session == null) {
      return;
    }
    _updateTextPreview(session.origin);
  }
}

class _TextEditorOverlay extends StatelessWidget {
  const _TextEditorOverlay({
    required this.renderer,
    required this.data,
    required this.bounds,
    required this.scale,
    required this.controller,
    required this.focusNode,
    required this.cursorColor,
    required this.selectionColor,
    required this.onConfirm,
    required this.onCancel,
    this.paintPreview = true,
  });

  final CanvasTextRenderer renderer;
  final CanvasTextData data;
  final Rect bounds;
  final double scale;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color cursorColor;
  final Color selectionColor;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool paintPreview;

  @override
  Widget build(BuildContext context) {
    final Size scaledSize = Size(
      math.max(bounds.width * scale, 4),
      math.max(bounds.height * scale, 4),
    );
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.escape):
            _CancelTextEditingIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.enter,
        ): _CommitTextEditingIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.enter,
        ): _CommitTextEditingIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _CommitTextEditingIntent: CallbackAction<_CommitTextEditingIntent>(
            onInvoke: (intent) {
              onConfirm();
              return null;
            },
          ),
          _CancelTextEditingIntent: CallbackAction<_CancelTextEditingIntent>(
            onInvoke: (intent) {
              onCancel();
              return null;
            },
          ),
        },
        child: SizedBox(
          width: scaledSize.width,
          height: scaledSize.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (paintPreview)
                CustomPaint(
                  painter: _TextPreviewPainter(
                    renderer: renderer,
                    data: data,
                    bounds: bounds,
                    scale: scale,
                  ),
                ),
              EditableText(
                controller: controller,
                focusNode: focusNode,
                cursorColor: cursorColor,
                backgroundCursorColor: Colors.transparent,
                style: TextStyle(
                  color: Colors.transparent,
                  fontSize: data.fontSize,
                  fontFamily:
                      data.fontFamily.isEmpty ? null : data.fontFamily,
                  height: data.lineHeight,
                ),
                selectionColor: selectionColor,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                textAlign: data.align,
                textDirection: TextDirection.ltr,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(FluentIcons.check_mark),
                  onPressed: onConfirm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextPreviewPainter extends CustomPainter {
  const _TextPreviewPainter({
    required this.renderer,
    required this.data,
    required this.bounds,
    required this.scale,
  });

  final CanvasTextRenderer renderer;
  final CanvasTextData data;
  final Rect bounds;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale, scale);
    canvas.translate(-bounds.left, -bounds.top);
    renderer.paint(canvas, data);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TextPreviewPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.bounds != bounds ||
        oldDelegate.scale != scale;
  }
}
