part of 'painting_board.dart';

const List<int> _defaultPaletteChoices = <int>[4, 8, 12, 16];
const int _minPaletteColorCount = 2;
const int _maxPaletteColorCount = 32;
const double _paletteCardWidth = 184;
const double _paletteCardPadding = 12;
const double _paletteCardShadowBlur = 12;
const double _paletteSwatchSize = 32;

class _PaletteCardEntry {
  _PaletteCardEntry({
    required this.id,
    required this.colors,
    required this.offset,
  });

  final int id;
  final List<Color> colors;
  Offset offset;
  Size? size;
}

class _PaletteBucket {
  int weight = 0;
  int r = 0;
  int g = 0;
  int b = 0;
}

mixin _PaintingBoardPaletteMixin on _PaintingBoardBase {

  Future<void> showPaletteGenerator() async {
    final int? count = await _showPaletteColorCountDialog();
    if (count == null) {
      return;
    }
    await _generatePaletteCard(count);
  }

  void _handlePaletteDragStart(int id) {
    _focusPaletteCard(id);
  }

  void _handlePaletteDragEnd() {}

  Future<int?> _showPaletteColorCountDialog() async {
    final TextEditingController controller =
        TextEditingController(text: _defaultPaletteChoices[1].toString());
    final FocusNode focusNode = FocusNode();
    int selectedCount = _defaultPaletteChoices[1];

    int? result;
    try {
      result = await showDialog<int>(
        context: context,
        builder: (context) {
          final theme = FluentTheme.of(context);
          return ContentDialog(
            title: const Text('生成调色盘'),
            content: StatefulBuilder(
              builder: (context, setState) {
                void handlePresetTap(int value) {
                  setState(() {
                    selectedCount = value;
                    controller.value = TextEditingValue(
                      text: value.toString(),
                      selection: TextSelection.collapsed(
                        offset: value.toString().length,
                      ),
                    );
                  });
                }

                void handleTextChanged(String text) {
                  final int? parsed = int.tryParse(text);
                  setState(() {
                    selectedCount = parsed ?? 0;
                  });
                }

                final bool isValid = selectedCount >= _minPaletteColorCount &&
                    selectedCount <= _maxPaletteColorCount;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('请选择需要生成的颜色数量，可以直接输入自定义数值。'),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _defaultPaletteChoices.map((int choice) {
                        final bool isActive = selectedCount == choice;
                        final Widget button = isActive
                            ? FilledButton(
                                onPressed: () => handlePresetTap(choice),
                                child: Text('$choice'),
                              )
                            : Button(
                                onPressed: () => handlePresetTap(choice),
                                child: Text('$choice'),
                              );
                        return SizedBox(width: 56, child: button);
                      }).toList(growable: false),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '自定义数量',
                      style: theme.typography.caption,
                    ),
                    const SizedBox(height: 6),
                    TextBox(
                      controller: controller,
                      focusNode: focusNode,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      keyboardType: TextInputType.number,
                      onChanged: handleTextChanged,
                      placeholder: '范围 ${_minPaletteColorCount.toString()} - ${_maxPaletteColorCount.toString()}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '允许范围：$_minPaletteColorCount - $_maxPaletteColorCount 色',
                      style: theme.typography.caption,
                    ),
                    if (!isValid)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '请输入有效的颜色数量。',
                          style: theme.typography.caption?.copyWith(
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            actions: [
              Button(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  if (selectedCount < _minPaletteColorCount ||
                      selectedCount > _maxPaletteColorCount) {
                    return;
                  }
                  Navigator.of(context).pop(selectedCount);
                },
                child: const Text('创建'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
      focusNode.dispose();
    }
    return result;
  }

  Future<void> _generatePaletteCard(int colorCount) async {
    final ui.Image? image = _controller.image;
    if (image == null) {
      AppNotifications.show(
        context,
        message: '当前画布还没有可以采样的颜色。',
        severity: InfoBarSeverity.warning,
      );
      return;
    }
    final ByteData? bytes =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) {
      AppNotifications.show(
        context,
        message: '暂时无法生成调色盘，请重试。',
        severity: InfoBarSeverity.error,
      );
      return;
    }
    final Uint8List data = bytes.buffer.asUint8List();
    final List<Color> palette = _resolvePalette(
      data,
      image.width,
      image.height,
      colorCount,
    );
    if (palette.isEmpty) {
      AppNotifications.show(
        context,
        message: '未找到有效颜色，请确认画布中已有内容。',
        severity: InfoBarSeverity.warning,
      );
      return;
    }
    setState(() {
      final Offset offset = _initialPaletteOffset();
      _paletteCards.add(
        _PaletteCardEntry(
          id: _paletteCardSerial++,
          colors: palette,
          offset: _clampPaletteOffset(offset),
        ),
      );
    });
  }

  List<Color> _resolvePalette(
    Uint8List rgba,
    int width,
    int height,
    int desiredCount,
  ) {
    if (width <= 0 || height <= 0) {
      return const <Color>[];
    }
    final Map<int, _PaletteBucket> buckets = <int, _PaletteBucket>{};
    final int totalPixels = width * height;
    final int sampleTarget = math.min(60000, totalPixels);
    final int step = math.max(1, totalPixels ~/ sampleTarget);
    for (int i = 0; i < totalPixels; i += step) {
      final int index = i * 4;
      final int r = rgba[index];
      final int g = rgba[index + 1];
      final int b = rgba[index + 2];
      final int a = rgba[index + 3];
      if (a < 12) {
        continue;
      }
      final int key = ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3);
      final _PaletteBucket bucket =
          buckets.putIfAbsent(key, () => _PaletteBucket());
      bucket.weight += a;
      bucket.r += r * a;
      bucket.g += g * a;
      bucket.b += b * a;
    }
    final List<_PaletteBucket> sorted = buckets.values.toList()
      ..sort((a, b) => b.weight.compareTo(a.weight));
    final List<Color> colors = <Color>[];
    for (final _PaletteBucket bucket in sorted) {
      if (bucket.weight <= 0) {
        continue;
      }
      final int r = (bucket.r ~/ bucket.weight).clamp(0, 255);
      final int g = (bucket.g ~/ bucket.weight).clamp(0, 255);
      final int b = (bucket.b ~/ bucket.weight).clamp(0, 255);
      colors.add(Color.fromARGB(0xFF, r, g, b));
      if (colors.length >= desiredCount) {
        break;
      }
    }
    return colors;
  }

  void _closePaletteCard(int id) {
    setState(() {
      _paletteCards.removeWhere((card) => card.id == id);
    });
  }

  void _updatePaletteCardOffset(int id, Offset delta) {
    if (delta == Offset.zero) {
      return;
    }
    final _PaletteCardEntry? entry = _paletteCardById(id);
    if (entry == null) {
      return;
    }
    setState(() {
      final Offset next = entry.offset + delta;
      entry.offset = _clampPaletteOffset(next, entry.size);
    });
  }

  void _focusPaletteCard(int id) {
    final int index = _paletteCards.indexWhere((card) => card.id == id);
    if (index < 0 || index == _paletteCards.length - 1) {
      return;
    }
    setState(() {
      final _PaletteCardEntry entry = _paletteCards.removeAt(index);
      _paletteCards.add(entry);
    });
  }

  void _updatePaletteCardSize(int id, Size size) {
    final _PaletteCardEntry? entry = _paletteCardById(id);
    if (entry == null) {
      return;
    }
    entry.size = size;
    final Offset clamped = _clampPaletteOffset(entry.offset, size);
    if (clamped == entry.offset) {
      return;
    }
    setState(() {
      entry.offset = clamped;
    });
  }

  Offset _initialPaletteOffset() {
    if (_workspaceSize.isEmpty) {
      return Offset(_toolButtonPadding + 48.0, _toolButtonPadding + 48.0);
    }
    final double baseLeft =
        (_workspaceSize.width - _paletteCardWidth).clamp(0.0, double.infinity) /
                2 +
            (_paletteCards.length * 24);
    final double baseTop =
        (_workspaceSize.height - 320).clamp(0.0, double.infinity) / 2 +
            (_paletteCards.length * 24);
    return Offset(baseLeft, baseTop);
  }

  Offset _clampPaletteOffset(Offset value, [Size? size]) {
    if (_workspaceSize.isEmpty) {
      return value;
    }
    final double width = size?.width ?? _paletteCardWidth;
    final double height = size?.height ?? 180.0;
    final double minX = _toolButtonPadding;
    final double minY = _toolButtonPadding;
    final double maxX = math.max(minX, _workspaceSize.width - width - minX);
    final double maxY = math.max(minY, _workspaceSize.height - height - minY);
    final double clampedX = value.dx.clamp(minX, maxX);
    final double clampedY = value.dy.clamp(minY, maxY);
    return Offset(clampedX, clampedY);
  }

  _PaletteCardEntry? _paletteCardById(int id) {
    for (final _PaletteCardEntry entry in _paletteCards) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }
}

class _WorkspacePaletteCard extends StatelessWidget {
  const _WorkspacePaletteCard({
    super.key,
    required this.colors,
    required this.onClose,
    required this.onDragUpdate,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onSizeChanged,
  });

  final List<Color> colors;
  final VoidCallback onClose;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final ValueChanged<Size> onSizeChanged;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final BorderRadius radius = BorderRadius.circular(16);
    Color background = theme.cardColor;
    if (background.alpha != 0xFF) {
      background = theme.brightness.isDark
          ? const Color(0xFF1F1F1F)
          : Colors.white;
    }
    return _PaletteHitTestBlocker(
      child: _MeasureSize(
        onChanged: onSizeChanged,
        child: Container(
          width: _paletteCardWidth,
          decoration: BoxDecoration(
            color: background,
            borderRadius: radius,
            border: Border.all(
              color: theme.brightness.isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black.withOpacity(0.08),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: _paletteCardShadowBlur,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(_paletteCardPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => onDragStart(),
                  onPanUpdate: (details) => onDragUpdate(details.delta),
                  onPanEnd: (_) => onDragEnd(),
                  onPanCancel: onDragEnd,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '调色盘',
                          style: theme.typography.subtitle,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(FluentIcons.chrome_close, size: 12),
                        iconButtonMode: IconButtonMode.small,
                        onPressed: onClose,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _PaletteSwatches(colors: colors),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaletteSwatches extends StatelessWidget {
  const _PaletteSwatches({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    if (colors.isEmpty) {
      return Text(
        '没有检测到颜色。',
        style: theme.typography.caption,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors.map((Color color) {
        return Tooltip(
          message: _hexStringForColor(color),
          child: Container(
            width: _paletteSwatchSize,
            height: _paletteSwatchSize,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.black.withOpacity(0.08),
                width: 1,
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _PaletteHitTestBlocker extends SingleChildRenderObjectWidget {
  const _PaletteHitTestBlocker({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _PaletteHitTestRender();
  }
}

class _PaletteHitTestRender extends RenderProxyBoxWithHitTestBehavior {
  _PaletteHitTestRender() : super(behavior: HitTestBehavior.opaque);
}

String _hexStringForColor(Color color) {
  final int a = color.alpha;
  final int r = color.red;
  final int g = color.green;
  final int b = color.blue;
  final String alpha = a.toRadixString(16).padLeft(2, '0').toUpperCase();
  final String red = r.toRadixString(16).padLeft(2, '0').toUpperCase();
  final String green = g.toRadixString(16).padLeft(2, '0').toUpperCase();
  final String blue = b.toRadixString(16).padLeft(2, '0').toUpperCase();
  if (a == 0xFF) {
    return '#$red$green$blue';
  }
  return '#$alpha$red$green$blue';
}
