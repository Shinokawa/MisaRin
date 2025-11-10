part of 'painting_board.dart';

const double _referenceCardWidth = 320;
const double _referenceCardHeight = 220;

class _ReferenceCardEntry {
  _ReferenceCardEntry({
    required this.id,
    required this.image,
    required this.offset,
  });

  final int id;
  ui.Image image;
  Offset offset;
  Size? size;
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
      if (!mounted) {
        image.dispose();
        return;
      }
      _insertReferenceCard(image);
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

  void _insertReferenceCard(ui.Image image) {
    final int id = ++_referenceCardSerial;
    final Offset offset = _initialReferenceCardOffset();
    setState(() {
      _referenceCards.add(
        _ReferenceCardEntry(id: id, image: image, offset: offset),
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
      entry.offset = _clampReferenceCardOffset(next, entry.size);
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

  Offset _initialReferenceCardOffset() {
    final double stackOffset = _referenceCards.length * 28.0;
    return _workspacePanelSpawnOffset(
      this,
      panelWidth: _referenceCardWidth,
      panelHeight: _referenceCardHeight,
      additionalDy: stackOffset,
    );
  }

  Offset _clampReferenceCardOffset(Offset value, [Size? size]) {
    if (_workspaceSize.isEmpty) {
      return value;
    }
    final double width = size?.width ?? _referenceCardWidth;
    final double height = size?.height ?? _referenceCardHeight;
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

  void _disposeReferenceCards() {
    for (final _ReferenceCardEntry entry in _referenceCards) {
      entry.image.dispose();
    }
    _referenceCards.clear();
  }
}

class _ReferenceImageCard extends StatelessWidget {
  const _ReferenceImageCard({
    required this.image,
    required this.onClose,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onSizeChanged,
  });

  final ui.Image image;
  final VoidCallback onClose;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final ValueChanged<Offset> onDragUpdate;
  final ValueChanged<Size> onSizeChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: _MeasureSize(
        onChanged: onSizeChanged,
        child: WorkspaceFloatingPanel(
          title: '参考图像',
          width: _referenceCardWidth,
          onClose: onClose,
          onDragStart: onDragStart,
          onDragEnd: onDragEnd,
          onDragUpdate: onDragUpdate,
          headerPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          bodyPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          bodySpacing: 10,
          child: SizedBox(
            width: _referenceCardWidth - 24,
            height: _referenceCardHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: RawImage(
                  image: image,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
