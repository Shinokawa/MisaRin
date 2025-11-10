part of 'painting_board.dart';

const double _referenceCardMinBodyWidth = 160;
const double _referenceCardMinBodyHeight = 120;
const double _referenceCardMaxBodyWidth = 520;
const double _referenceCardMaxBodyHeight = 360;
const double _referenceCardBodyHorizontalPadding = 24;
const double _referenceCardPanelChromeHeight = 68;
const double _referenceCardWorkspaceHorizontalPadding = 220;
const double _referenceCardWorkspaceVerticalPadding = 200;
const double _referenceCardMinScale = 0.35;
const double _referenceCardMaxScale = 8.0;

class _ReferenceCardEntry {
  _ReferenceCardEntry({
    required this.id,
    required this.image,
    required this.offset,
    required this.bodySize,
    required this.initialPanelSize,
    this.pixelBytes,
  });

  final int id;
  ui.Image image;
  Offset offset;
  final Size bodySize;
  final Size initialPanelSize;
  final Uint8List? pixelBytes;
  Size? size;

  Size get panelSize => size ?? initialPanelSize;
}

mixin _PaintingBoardReferenceMixin on _PaintingBoardBase {
  final List<_ReferenceCardEntry> _referenceCards = <_ReferenceCardEntry>[];
  int _referenceCardSerial = 0;
  bool _isCreatingReferenceCard = false;

  Future<void> createReferenceImageCard() async {
    if (_isCreatingReferenceCard) {
      AppNotifications.show(
        context,
        message: '正在生成参考图像，请稍候…',
        severity: InfoBarSeverity.info,
      );
      return;
    }
    _isCreatingReferenceCard = true;
    try {
      final List<CanvasLayerData> snapshot = _controller.snapshotLayers();
      if (snapshot.isEmpty) {
        AppNotifications.show(
          context,
          message: '当前画布没有可用内容。',
          severity: InfoBarSeverity.warning,
        );
        return;
      }
      final CanvasExporter exporter = CanvasExporter();
      final Uint8List pngBytes = await exporter.exportToPng(
        settings: widget.settings,
        layers: snapshot,
      );
      final ui.Codec codec = await ui.instantiateImageCodec(pngBytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      codec.dispose();
      final ui.Image image = frame.image;
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final Uint8List? pixelBytes = byteData?.buffer.asUint8List();
      if (!mounted) {
        image.dispose();
        return;
      }
      final Size bodySize = _referenceCardBodySize(image);
      final Size panelSize = _referencePanelSize(bodySize);
      _insertReferenceCard(
        image: image,
        pixelBytes: pixelBytes,
        bodySize: bodySize,
        panelSize: panelSize,
      );
      AppNotifications.show(
        context,
        message: '参考图像已创建。',
        severity: InfoBarSeverity.success,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to create reference image: $error\n$stackTrace');
      AppNotifications.show(
        context,
        message: '创建参考图像失败。',
        severity: InfoBarSeverity.error,
      );
    } finally {
      _isCreatingReferenceCard = false;
    }
  }

  void _insertReferenceCard({
    required ui.Image image,
    required Uint8List? pixelBytes,
    required Size bodySize,
    required Size panelSize,
  }) {
    final int id = ++_referenceCardSerial;
    final Offset offset = _initialReferenceCardOffset(panelSize);
    setState(() {
      _referenceCards.add(
        _ReferenceCardEntry(
          id: id,
          image: image,
          offset: offset,
          bodySize: bodySize,
          initialPanelSize: panelSize,
          pixelBytes: pixelBytes,
        ),
      );
    });
  }

  void _closeReferenceCard(int id) {
    final int index = _referenceCards.indexWhere((card) => card.id == id);
    if (index < 0) {
      return;
    }
    final _ReferenceCardEntry entry = _referenceCards[index];
    setState(() {
      _referenceCards.removeAt(index);
    });
    entry.image.dispose();
  }

  void _updateReferenceCardOffset(int id, Offset delta) {
    if (delta == Offset.zero) {
      return;
    }
    final _ReferenceCardEntry? entry = _referenceCardById(id);
    if (entry == null) {
      return;
    }
    setState(() {
      final Offset next = entry.offset + delta;
      entry.offset = _clampReferenceCardOffset(
        next,
        entry.size ?? _referencePanelSize(entry.bodySize),
      );
    });
  }

  void _handleReferenceCardSizeChanged(int id, Size size) {
    final _ReferenceCardEntry? entry = _referenceCardById(id);
    if (entry == null) {
      return;
    }
    entry.size = size;
    final Offset clamped = _clampReferenceCardOffset(entry.offset, size);
    if (clamped == entry.offset) {
      return;
    }
    setState(() {
      entry.offset = clamped;
    });
  }

  void _focusReferenceCard(int id) {
    final int index = _referenceCards.indexWhere((card) => card.id == id);
    if (index < 0 || index == _referenceCards.length - 1) {
      return;
    }
    setState(() {
      final _ReferenceCardEntry entry = _referenceCards.removeAt(index);
      _referenceCards.add(entry);
    });
  }

  Offset _initialReferenceCardOffset(Size panelSize) {
    final double stackOffset = _referenceCards.length * 28.0;
    return _workspacePanelSpawnOffset(
      this,
      panelWidth: panelSize.width,
      panelHeight: panelSize.height,
      additionalDy: stackOffset,
    );
  }

  Offset _clampReferenceCardOffset(Offset value, [Size? size]) {
    if (_workspaceSize.isEmpty) {
      return value;
    }
    final double width =
        size?.width ??
        _referencePanelSize(
          const Size(_referenceCardMinBodyWidth, _referenceCardMinBodyHeight),
        ).width;
    final double height =
        size?.height ??
        _referencePanelSize(
          const Size(_referenceCardMinBodyWidth, _referenceCardMinBodyHeight),
        ).height;
    const double margin = 12.0;
    final double maxX = math.max(margin, _workspaceSize.width - width - margin);
    final double maxY = math.max(
      margin,
      _workspaceSize.height - height - margin,
    );
    return Offset(value.dx.clamp(margin, maxX), value.dy.clamp(margin, maxY));
  }

  _ReferenceCardEntry? _referenceCardById(int id) {
    for (final _ReferenceCardEntry entry in _referenceCards) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  bool _isInsideReferenceCardArea(Offset workspacePosition) {
    for (final _ReferenceCardEntry entry in _referenceCards) {
      final Size size = entry.panelSize;
      final Rect rect = Rect.fromLTWH(
        entry.offset.dx,
        entry.offset.dy,
        size.width,
        size.height,
      );
      if (rect.contains(workspacePosition)) {
        return true;
      }
    }
    return false;
  }

  Size _referenceCardBodySize(ui.Image image) {
    final double width = image.width.toDouble();
    final double height = image.height.toDouble();
    if (width <= 0 || height <= 0) {
      return const Size(
        _referenceCardMinBodyWidth,
        _referenceCardMinBodyHeight,
      );
    }
    double maxWidth = _referenceCardMaxBodyWidth;
    double maxHeight = _referenceCardMaxBodyHeight;
    if (!_workspaceSize.isEmpty) {
      final double availableWidth =
          _workspaceSize.width - _referenceCardWorkspaceHorizontalPadding;
      if (availableWidth.isFinite && availableWidth > 0) {
        maxWidth = math.min(maxWidth, availableWidth);
      }
      final double availableHeight =
          _workspaceSize.height - _referenceCardWorkspaceVerticalPadding;
      if (availableHeight.isFinite && availableHeight > 0) {
        maxHeight = math.min(maxHeight, availableHeight);
      }
    }
    if (maxWidth <= 0 || !maxWidth.isFinite) {
      maxWidth = _referenceCardMinBodyWidth;
    }
    if (maxHeight <= 0 || !maxHeight.isFinite) {
      maxHeight = _referenceCardMinBodyHeight;
    }

    final double downscale = math.min(
      1.0,
      math.min(maxWidth / width, maxHeight / height),
    );
    double targetWidth = width * downscale;
    double targetHeight = height * downscale;

    if (targetWidth < _referenceCardMinBodyWidth &&
        targetHeight < _referenceCardMinBodyHeight &&
        maxWidth >= _referenceCardMinBodyWidth &&
        maxHeight >= _referenceCardMinBodyHeight) {
      final double upscale = math.min(
        _referenceCardMinBodyWidth / targetWidth,
        _referenceCardMinBodyHeight / targetHeight,
      );
      targetWidth *= upscale;
      targetHeight *= upscale;
    }

    return Size(targetWidth, targetHeight);
  }

  Size _referencePanelSize(Size bodySize) {
    return Size(
      bodySize.width + _referenceCardBodyHorizontalPadding,
      bodySize.height + _referenceCardPanelChromeHeight,
    );
  }

  void _disposeReferenceCards() {
    for (final _ReferenceCardEntry entry in _referenceCards) {
      entry.image.dispose();
    }
    _referenceCards.clear();
  }
}

class _ReferenceImageCard extends StatefulWidget {
  const _ReferenceImageCard({
    required this.image,
    required this.bodySize,
    required this.pixelBytes,
    required this.enableEyedropperSampling,
    required this.onSamplePreview,
    required this.onSampleCommit,
    required this.onClose,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onSizeChanged,
  });

  final ui.Image image;
  final Size bodySize;
  final Uint8List? pixelBytes;
  final bool enableEyedropperSampling;
  final ValueChanged<Color>? onSamplePreview;
  final ValueChanged<Color>? onSampleCommit;
  final VoidCallback onClose;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final ValueChanged<Offset> onDragUpdate;
  final ValueChanged<Size> onSizeChanged;

  @override
  State<_ReferenceImageCard> createState() => _ReferenceImageCardState();
}

class _ReferenceImageCardState extends State<_ReferenceImageCard> {
  late final TransformationController _transformController;
  bool _samplingActive = false;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  bool get _canSampleColor =>
      widget.enableEyedropperSampling && widget.pixelBytes != null;

  bool get _interactionLocked => widget.enableEyedropperSampling;

  double get _currentScale {
    final Matrix4 matrix = _transformController.value;
    final double scaleX = matrix.storage[0].abs();
    final double scaleY = matrix.storage[5].abs();
    return math.max(scaleX, scaleY);
  }

  void _resetView() {
    if (_interactionLocked) {
      return;
    }
    _transformController.value = Matrix4.identity();
  }

  void _zoomByFactor(double factor) {
    if (_interactionLocked) {
      return;
    }
    final double target = (_currentScale * factor).clamp(
      _referenceCardMinScale,
      _referenceCardMaxScale,
    );
    _updateScale(target, _viewportCenter());
  }

  Offset _viewportCenter() {
    return Offset(widget.bodySize.width / 2, widget.bodySize.height / 2);
  }

  void _updateScale(double targetScale, Offset focalPoint) {
    final double clamped = targetScale.clamp(
      _referenceCardMinScale,
      _referenceCardMaxScale,
    );
    final Offset scenePoint = _transformController.toScene(focalPoint);
    final Offset translation = Offset(
      focalPoint.dx - scenePoint.dx * clamped,
      focalPoint.dy - scenePoint.dy * clamped,
    );
    _transformController.value = Matrix4.identity()
      ..translate(translation.dx, translation.dy)
      ..scale(clamped);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _interactionLocked) {
      return;
    }
    if (event.scrollDelta.dy == 0) {
      return;
    }
    final double target = (_currentScale * (1 - event.scrollDelta.dy * 0.0015))
        .clamp(_referenceCardMinScale, _referenceCardMaxScale);
    _updateScale(target, event.localPosition);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_shouldHandleSample(event)) {
      return;
    }
    _samplingActive = _emitSample(event.localPosition, commit: false);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_samplingActive) {
      return;
    }
    _emitSample(event.localPosition, commit: false);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!_samplingActive) {
      return;
    }
    _emitSample(event.localPosition, commit: true);
    _samplingActive = false;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (!_samplingActive) {
      return;
    }
    _samplingActive = false;
  }

  bool _shouldHandleSample(PointerEvent event) {
    if (!_canSampleColor) {
      return false;
    }
    if (event.kind == PointerDeviceKind.mouse) {
      return (event.buttons & kPrimaryMouseButton) != 0;
    }
    return true;
  }

  bool _emitSample(Offset localPosition, {required bool commit}) {
    final Color? color = _sampleColor(localPosition);
    if (color == null) {
      return false;
    }
    if (commit) {
      widget.onSampleCommit?.call(color);
    } else {
      widget.onSamplePreview?.call(color);
    }
    return true;
  }

  Color? _sampleColor(Offset localPosition) {
    if (!_canSampleColor) {
      return null;
    }
    final Offset scenePoint = _transformController.toScene(localPosition);
    if (scenePoint.dx < 0 ||
        scenePoint.dy < 0 ||
        scenePoint.dx > widget.bodySize.width ||
        scenePoint.dy > widget.bodySize.height) {
      return null;
    }
    final double relativeX = scenePoint.dx / widget.bodySize.width;
    final double relativeY = scenePoint.dy / widget.bodySize.height;
    final int pixelWidth = widget.image.width;
    final int pixelHeight = widget.image.height;
    if (pixelWidth <= 0 || pixelHeight <= 0) {
      return null;
    }
    final int pixelX = (relativeX * (pixelWidth - 1)).round().clamp(
      0,
      pixelWidth - 1,
    );
    final int pixelY = (relativeY * (pixelHeight - 1)).round().clamp(
      0,
      pixelHeight - 1,
    );
    final Uint8List? pixels = widget.pixelBytes;
    if (pixels == null || pixels.isEmpty) {
      return null;
    }
    final int index = (pixelY * pixelWidth + pixelX) * 4;
    if (index < 0 || index + 3 >= pixels.length) {
      return null;
    }
    final int r = pixels[index];
    final int g = pixels[index + 1];
    final int b = pixels[index + 2];
    final int a = pixels[index + 3];
    return Color.fromARGB(a, r, g, b);
  }

  List<Widget> _buildHeaderActions() {
    final bool disabled = _interactionLocked;
    return [
      Tooltip(
        message: '缩小',
        child: IconButton(
          icon: const Icon(FluentIcons.calculator_subtract),
          iconButtonMode: IconButtonMode.small,
          onPressed: disabled ? null : () => _zoomByFactor(0.9),
        ),
      ),
      Tooltip(
        message: '放大',
        child: IconButton(
          icon: const Icon(FluentIcons.add),
          iconButtonMode: IconButtonMode.small,
          onPressed: disabled ? null : () => _zoomByFactor(1.1),
        ),
      ),
      Tooltip(
        message: '重置视图',
        child: IconButton(
          icon: const Icon(FluentIcons.refresh),
          iconButtonMode: IconButtonMode.small,
          onPressed: disabled ? null : _resetView,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final Size bodySize = widget.bodySize;
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: _MeasureSize(
        onChanged: widget.onSizeChanged,
        child: WorkspaceFloatingPanel(
          title: '参考图像',
          width: bodySize.width + _referenceCardBodyHorizontalPadding,
          onClose: widget.onClose,
          onDragStart: widget.onDragStart,
          onDragEnd: widget.onDragEnd,
          onDragUpdate: widget.onDragUpdate,
          headerPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          bodyPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          bodySpacing: 10,
          headerActions: _buildHeaderActions(),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final Decoration decoration = BoxDecoration(
      color: Colors.black.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
    );
    return DecoratedBox(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          onPointerSignal: _handlePointerSignal,
          child: MouseRegion(
            cursor: _canSampleColor
                ? SystemMouseCursors.precise
                : MouseCursor.defer,
            child: SizedBox(
              width: widget.bodySize.width,
              height: widget.bodySize.height,
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: _referenceCardMinScale,
                maxScale: _referenceCardMaxScale,
                panEnabled: !_interactionLocked,
                scaleEnabled: !_interactionLocked,
                boundaryMargin: const EdgeInsets.all(240),
                clipBehavior: Clip.hardEdge,
                alignment: Alignment.topLeft,
                child: RawImage(
                  image: widget.image,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
