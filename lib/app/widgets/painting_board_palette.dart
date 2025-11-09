part of 'painting_board.dart';

const List<int> _defaultPaletteChoices = <int>[4, 8, 12, 16];
const int _minPaletteColorCount = 2;
const int _maxPaletteColorCount = 32;
const double _paletteCardWidth = 184;
const double _paletteCardPadding = 12;
const double _paletteSwatchSize = 32;
const double _paletteMinimumColorDistance = 0.12;
const double _paletteDuplicateEpsilon = 0.01;

class _PaletteCardEntry {
  _PaletteCardEntry({
    required this.id,
    required this.title,
    required this.colors,
    required this.offset,
  });

  final int id;
  final String title;
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

class _PaletteSelection {
  const _PaletteSelection({required this.color, required this.score});

  final Color color;
  final double score;
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
    final TextEditingController controller = TextEditingController(
      text: _defaultPaletteChoices[1].toString(),
    );
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

                final bool isValid =
                    selectedCount >= _minPaletteColorCount &&
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
                      children: _defaultPaletteChoices
                          .map((int choice) {
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
                          })
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 20),
                    Text('自定义数量', style: theme.typography.caption),
                    const SizedBox(height: 6),
                    TextBox(
                      controller: controller,
                      focusNode: focusNode,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      keyboardType: TextInputType.number,
                      onChanged: handleTextChanged,
                      placeholder:
                          '范围 ${_minPaletteColorCount.toString()} - ${_maxPaletteColorCount.toString()}',
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
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
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
    _addPaletteCard(palette);
  }

  void showPaletteFromColors({
    required String title,
    required List<Color> colors,
  }) {
    if (colors.isEmpty) {
      AppNotifications.show(
        context,
        message: '该调色盘没有可用的颜色。',
        severity: InfoBarSeverity.warning,
      );
      return;
    }
    _addPaletteCard(colors, title: title);
  }

  void _addPaletteCard(List<Color> colors, {String? title}) {
    final List<Color> sanitized = _sanitizePaletteColors(colors);
    if (sanitized.length < _minPaletteColorCount) {
      AppNotifications.show(
        context,
        message: '调色盘至少需要 $_minPaletteColorCount 种颜色。',
        severity: InfoBarSeverity.warning,
      );
      return;
    }
    setState(() {
      final Offset offset = _initialPaletteOffset();
      _paletteCards.add(
        _PaletteCardEntry(
          id: _paletteCardSerial++,
          title: title?.trim().isNotEmpty == true ? title!.trim() : '调色盘',
          colors: sanitized,
          offset: _clampPaletteOffset(offset),
        ),
      );
    });
  }

  List<Color> _sanitizePaletteColors(List<Color> colors) {
    final Set<int> unique = <int>{};
    final List<Color> sanitized = <Color>[];
    for (final Color color in colors) {
      final Color opaque = color.withAlpha(0xFF);
      if (unique.add(opaque.value)) {
        sanitized.add(opaque);
      }
      if (sanitized.length >= _maxPaletteColorCount) {
        break;
      }
    }
    return sanitized;
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
      final _PaletteBucket bucket = buckets.putIfAbsent(
        key,
        () => _PaletteBucket(),
      );
      bucket.weight += a;
      bucket.r += r * a;
      bucket.g += g * a;
      bucket.b += b * a;
    }
    final List<_PaletteBucket> sorted = buckets.values.toList()
      ..sort((a, b) => b.weight.compareTo(a.weight));
    final List<Color> candidates = <Color>[];
    for (final _PaletteBucket bucket in sorted) {
      if (bucket.weight <= 0) {
        continue;
      }
      final int r = (bucket.r ~/ bucket.weight).clamp(0, 255);
      final int g = (bucket.g ~/ bucket.weight).clamp(0, 255);
      final int b = (bucket.b ~/ bucket.weight).clamp(0, 255);
      final Color color = Color.fromARGB(0xFF, r, g, b);
      bool isDuplicate = false;
      for (final Color existing in candidates) {
        if (_colorDistance(existing, color) < _paletteDuplicateEpsilon) {
          isDuplicate = true;
          break;
        }
      }
      if (!isDuplicate) {
        candidates.add(color);
      }
    }
    if (candidates.isEmpty) {
      return const <Color>[];
    }
    final int clampedDesired = desiredCount
        .clamp(_minPaletteColorCount, _maxPaletteColorCount)
        .toInt();
    final int targetCount = math.max(
      1,
      math.min(clampedDesired, candidates.length),
    );
    // Use a farthest-point style sampling so each new color maximizes its
    // distance to the already selected ones.
    final List<Color> selectedColors = <Color>[candidates.first];
    final Set<int> used = <int>{0};
    while (selectedColors.length < targetCount) {
      double bestDistance = -1;
      int bestIndex = -1;
      for (int i = 0; i < candidates.length; i++) {
        if (used.contains(i)) {
          continue;
        }
        final Color candidate = candidates[i];
        double minDistance = double.infinity;
        for (final Color selection in selectedColors) {
          final double distance = _colorDistance(candidate, selection);
          if (distance < minDistance) {
            minDistance = distance;
          }
        }
        if (minDistance > bestDistance) {
          bestDistance = minDistance;
          bestIndex = i;
        }
      }
      if (bestIndex == -1 || bestDistance < _paletteMinimumColorDistance) {
        break;
      }
      used.add(bestIndex);
      selectedColors.add(candidates[bestIndex]);
    }
    final List<_PaletteSelection> orderedSelections = <_PaletteSelection>[];
    for (int i = 0; i < selectedColors.length; i++) {
      final Color color = selectedColors[i];
      double minDistance = double.infinity;
      for (int j = 0; j < selectedColors.length; j++) {
        if (i == j) {
          continue;
        }
        final double distance = _colorDistance(color, selectedColors[j]);
        if (distance < minDistance) {
          minDistance = distance;
        }
      }
      if (minDistance == double.infinity) {
        minDistance = double.maxFinite;
      }
      orderedSelections.add(
        _PaletteSelection(color: color, score: minDistance),
      );
    }
    orderedSelections.sort((a, b) => b.score.compareTo(a.score));
    return orderedSelections
        .map((entry) => entry.color)
        .toList(growable: false);
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
    const double margin = 16.0;
    const double rightInset = 32.0;
    final double baseLeft = math.max(
      margin,
      _workspaceSize.width - _paletteCardWidth - rightInset,
    );
    final double baseTop =
        math.max(margin, _workspaceSize.height * 0.2) +
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
    required this.title,
    required this.colors,
    required this.onClose,
    required this.onDragUpdate,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onSizeChanged,
    required this.onColorTap,
  });

  final String title;
  final List<Color> colors;
  final VoidCallback onClose;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final ValueChanged<Size> onSizeChanged;
  final ValueChanged<Color> onColorTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: _PaletteHitTestBlocker(
        child: _MeasureSize(
          onChanged: onSizeChanged,
          child: WorkspaceFloatingPanel(
            title: title,
            child: _PaletteSwatches(colors: colors, onTap: onColorTap),
            width: _paletteCardWidth,
            onClose: onClose,
            onDragStart: onDragStart,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
            headerPadding: const EdgeInsets.fromLTRB(
              _paletteCardPadding,
              _paletteCardPadding,
              _paletteCardPadding,
              0,
            ),
            bodyPadding: const EdgeInsets.fromLTRB(
              _paletteCardPadding,
              0,
              _paletteCardPadding,
              _paletteCardPadding,
            ),
            bodySpacing: 10,
            footerSpacing: 0,
            closeIconSize: 12,
          ),
        ),
      ),
    );
  }
}

class _PaletteSwatches extends StatelessWidget {
  const _PaletteSwatches({required this.colors, required this.onTap});

  final List<Color> colors;
  final ValueChanged<Color> onTap;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    if (colors.isEmpty) {
      return Text('没有检测到颜色。', style: theme.typography.caption);
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors
          .map((Color color) {
            return Tooltip(
              message: _hexStringForColor(color),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(color),
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
                ),
              ),
            );
          })
          .toList(growable: false),
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

double _colorDistance(Color a, Color b) {
  final double dr = (a.red - b.red) / 255.0;
  final double dg = (a.green - b.green) / 255.0;
  final double db = (a.blue - b.blue) / 255.0;
  return math.sqrt(dr * dr + dg * dg + db * db);
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
