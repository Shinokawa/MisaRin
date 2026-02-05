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
const double _referenceCardBodyPaddingLeft = 12;
const double _referenceCardBodyPaddingRight = 12;
const double _referenceCardBodyPaddingTop = 0;
const double _referenceCardBodyPaddingBottom = 12;
const double _referenceCardResizeEdgeHitExtent = 14.0;
const double _referenceCardResizeCornerHitExtent = 18.0;

enum _ReferenceCardResizeEdge { left, right, bottom, bottomLeft, bottomRight }

typedef _ReferenceCardResizeCallback =
    void Function(_ReferenceCardResizeEdge edge, Offset delta);

class _ReferenceCardEntry {
  _ReferenceCardEntry({
    required this.id,
    required this.image,
    required this.offset,
    required this.bodySize,
    required this.initialPanelSize,
    this.pixelBytes,
    required this.rawBytes,
  });

  final int id;
  ui.Image image;
  Offset offset;
  Size bodySize;
  final Size initialPanelSize;
  final Uint8List? pixelBytes;
  final Uint8List rawBytes;
  Size? size;

  Size get panelSize => size ?? initialPanelSize;
}

mixin _PaintingBoardReferenceMixin on _PaintingBoardBase {
  final List<_ReferenceCardEntry> _referenceCards = <_ReferenceCardEntry>[];
  int _referenceCardSerial = 0;
  bool _isCreatingReferenceCard = false;
  bool _isImportingReferenceCard = false;

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
      final List<CanvasLayerData> snapshot = await snapshotLayersForExport();
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
        rawBytes: Uint8List.fromList(pngBytes),
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

  Future<void> importReferenceImageCard() async {
    if (_isImportingReferenceCard) {
      AppNotifications.show(
        context,
        message: '正在导入参考图像，请稍候…',
        severity: InfoBarSeverity.info,
      );
      return;
    }
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择参考图像',
      type: FileType.custom,
      allowedExtensions: const <String>['png', 'jpg', 'jpeg', 'bmp', 'webp'],
    );
    final PlatformFile? file = result?.files.singleOrNull;
    Uint8List? bytes = file?.bytes;
    if (bytes == null) {
      final String? path = file?.path;
      if (path == null) {
        return;
      }
      try {
        bytes = await File(path).readAsBytes();
      } catch (error) {
        if (!mounted) {
          return;
        }
        AppNotifications.show(
          context,
          message: '读取图像失败：$error',
          severity: InfoBarSeverity.error,
        );
        return;
      }
    }
    if (bytes.isEmpty) {
      return;
    }
    _isImportingReferenceCard = true;
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
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
        rawBytes: Uint8List.fromList(bytes),
      );
      AppNotifications.show(
        context,
        message: '已导入参考图像${file?.name != null ? '：${file!.name}' : ''}',
        severity: InfoBarSeverity.success,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to import reference image: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      AppNotifications.show(
        context,
        message: '导入参考图像失败。',
        severity: InfoBarSeverity.error,
      );
    } finally {
      _isImportingReferenceCard = false;
    }
  }

  void _insertReferenceCard({
    required ui.Image image,
    required Uint8List? pixelBytes,
    required Size bodySize,
    required Size panelSize,
    required Uint8List rawBytes,
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
          rawBytes: rawBytes,
        ),
      );
    });
    _scheduleWorkspaceCardsOverlaySync();
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
    _scheduleWorkspaceCardsOverlaySync();
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
    _scheduleWorkspaceCardsOverlaySync();
  }

  void _resizeReferenceCard(
    int id,
    _ReferenceCardResizeEdge edge,
    Offset delta,
  ) {
    if (delta == Offset.zero) {
      return;
    }
    final _ReferenceCardEntry? entry = _referenceCardById(id);
    if (entry == null) {
      return;
    }
    final _ReferenceCardBodyConstraints limits =
        _referenceCardBodyConstraints();
    double width = entry.bodySize.width;
    double height = entry.bodySize.height;
    Offset offset = entry.offset;
    bool widthChanged = false;
    bool heightChanged = false;

    void resizeFromRight(double dx) {
      if (dx == 0) {
        return;
      }
      final double clampedWidth = (width + dx)
          .clamp(limits.minWidth, limits.maxWidth)
          .toDouble();
      if (clampedWidth == width) {
        return;
      }
      width = clampedWidth;
      widthChanged = true;
    }

    void resizeFromLeft(double dx) {
      if (dx == 0) {
        return;
      }
      final double clampedWidth = (width - dx)
          .clamp(limits.minWidth, limits.maxWidth)
          .toDouble();
      final double appliedShift = width - clampedWidth;
      if (appliedShift == 0) {
        return;
      }
      width = clampedWidth;
      offset = offset.translate(appliedShift, 0);
      widthChanged = true;
    }

    void resizeFromBottom(double dy) {
      if (dy == 0) {
        return;
      }
      final double clampedHeight = (height + dy)
          .clamp(limits.minHeight, limits.maxHeight)
          .toDouble();
      if (clampedHeight == height) {
        return;
      }
      height = clampedHeight;
      heightChanged = true;
    }

    switch (edge) {
      case _ReferenceCardResizeEdge.right:
        resizeFromRight(delta.dx);
        break;
      case _ReferenceCardResizeEdge.left:
        resizeFromLeft(delta.dx);
        break;
      case _ReferenceCardResizeEdge.bottom:
        resizeFromBottom(delta.dy);
        break;
      case _ReferenceCardResizeEdge.bottomLeft:
        resizeFromLeft(delta.dx);
        resizeFromBottom(delta.dy);
        break;
      case _ReferenceCardResizeEdge.bottomRight:
        resizeFromRight(delta.dx);
        resizeFromBottom(delta.dy);
        break;
    }

    if (!widthChanged && !heightChanged) {
      return;
    }
    final Size nextBodySize = Size(width, height);
    setState(() {
      entry.bodySize = nextBodySize;
      entry.offset = _clampReferenceCardOffset(
        offset,
        _referencePanelSize(nextBodySize),
      );
    });
    _scheduleWorkspaceCardsOverlaySync();
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
    _scheduleWorkspaceCardsOverlaySync();
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
    _scheduleWorkspaceCardsOverlaySync();
  }

  void _beginReferenceCardResize(int id) {
    _focusReferenceCard(id);
    if (_referenceCardResizeInProgress) {
      return;
    }
    setState(() {
      _referenceCardResizeInProgress = true;
      _toolCursorPosition = null;
      _penCursorWorkspacePosition = null;
    });
  }

  void _endReferenceCardResize() {
    if (!_referenceCardResizeInProgress) {
      return;
    }
    setState(() {
      _referenceCardResizeInProgress = false;
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
    return _clampWorkspaceOffsetToViewport(
      this,
      value,
      childSize: Size(width, height),
      margin: margin,
    );
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

  _ReferenceCardBodyConstraints _referenceCardBodyConstraints() {
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
    if (!maxWidth.isFinite || maxWidth <= 0) {
      maxWidth = _referenceCardMinBodyWidth;
    }
    if (!maxHeight.isFinite || maxHeight <= 0) {
      maxHeight = _referenceCardMinBodyHeight;
    }
    final double minWidth = math.min(_referenceCardMinBodyWidth, maxWidth);
    final double minHeight = math.min(_referenceCardMinBodyHeight, maxHeight);
    return _ReferenceCardBodyConstraints(
      minWidth: minWidth,
      maxWidth: maxWidth,
      minHeight: minHeight,
      maxHeight: maxHeight,
    );
  }

  void _disposeReferenceCards() {
    for (final _ReferenceCardEntry entry in _referenceCards) {
      entry.image.dispose();
    }
    _referenceCards.clear();
  }

  List<ReferenceCardSnapshot> buildReferenceSnapshots() {
    return _referenceCards
        .map(
          (entry) => ReferenceCardSnapshot(
            imageBytes: Uint8List.fromList(entry.rawBytes),
            pixelBytes:
                entry.pixelBytes != null ? Uint8List.fromList(entry.pixelBytes!) : null,
            bodySize: entry.bodySize,
            panelSize: entry.panelSize,
            offset: entry.offset,
            size: entry.size,
          ),
        )
        .toList(growable: false);
  }

  Future<void> restoreReferenceSnapshots(
    List<ReferenceCardSnapshot> snapshots,
  ) async {
    _referenceCardSerial = 0;
    if (mounted) {
      setState(() {
        _disposeReferenceCards();
      });
    } else {
      _disposeReferenceCards();
    }
    if (snapshots.isEmpty) {
      return;
    }
    final List<_ReferenceCardEntry> restored = <_ReferenceCardEntry>[];
    for (final ReferenceCardSnapshot snapshot in snapshots) {
      try {
        final ui.Codec codec = await ui.instantiateImageCodec(snapshot.imageBytes);
        final ui.FrameInfo frame = await codec.getNextFrame();
        codec.dispose();
        final ui.Image image = frame.image;
        Uint8List? pixelBytes = snapshot.pixelBytes != null
            ? Uint8List.fromList(snapshot.pixelBytes!)
            : null;
        pixelBytes ??= (await image
                .toByteData(format: ui.ImageByteFormat.rawRgba))
            ?.buffer
            .asUint8List();
        final Offset offset = _clampReferenceCardOffset(
          snapshot.offset,
          snapshot.size ?? snapshot.panelSize,
        );
        final _ReferenceCardEntry entry = _ReferenceCardEntry(
          id: ++_referenceCardSerial,
          image: image,
          offset: offset,
          bodySize: snapshot.bodySize,
          initialPanelSize: snapshot.panelSize,
          pixelBytes: pixelBytes,
          rawBytes: Uint8List.fromList(snapshot.imageBytes),
        )..size = snapshot.size;
        restored.add(entry);
      } catch (error, stackTrace) {
        debugPrint('Failed to restore reference card: $error\n$stackTrace');
      }
    }
    if (!mounted) {
      for (final _ReferenceCardEntry entry in restored) {
        entry.image.dispose();
      }
      return;
    }
    setState(() {
      _referenceCards.addAll(restored);
    });
    _scheduleWorkspaceCardsOverlaySync();
  }
}
