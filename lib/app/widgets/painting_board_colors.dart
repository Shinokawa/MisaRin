part of 'painting_board.dart';

mixin _PaintingBoardColorMixin on _PaintingBoardBase {
  Future<void> _pickColor({
    required String title,
    required Color initialColor,
    required ValueChanged<Color> onSelected,
    VoidCallback? onCleared,
  }) async {
    Color previewColor = initialColor;
    final Color? result = await showDialog<Color>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return ContentDialog(
          title: Text(title),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 320,
                child: ColorPicker(
                  color: previewColor,
                  onChanged: (Color color) {
                    setState(() => previewColor = color);
                  },
                  isMoreButtonVisible: false,
                  isColorChannelTextInputVisible: false,
                  isHexInputVisible: true,
                  isAlphaTextInputVisible: false,
                ),
              );
            },
          ),
          actions: [
            if (onCleared != null)
              Button(
                onPressed: () {
                  Navigator.of(context).pop();
                  onCleared();
                },
                child: const Text('清除填充'),
              ),
            Button(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(previewColor),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    if (result != null) {
      onSelected(result);
    }
  }

  Future<void> _applyPaintBucket(Offset position) async {
    if (!isPointInsideSelection(position)) {
      return;
    }
    _pushUndoSnapshot();
    _controller.floodFill(
      position,
      color: _primaryColor,
      contiguous: _bucketContiguous,
      sampleAllLayers: _bucketSampleAllLayers,
      swallowColors: _bucketSwallowColorLine ? kColorLinePresets : null,
      tolerance: _bucketTolerance,
      antialiasLevel: _bucketAntialiasLevel,
    );
    setState(() {});
    _markDirty();
  }

  void _updatePrimaryFromSquare(Offset position, double size) {
    final double x = position.dx.clamp(0.0, size);
    final double y = position.dy.clamp(0.0, size);
    final double saturation = (x / size).clamp(0.0, 1.0);
    final double value = (1 - y / size).clamp(0.0, 1.0);
    final HSVColor updated = _primaryHsv
        .withSaturation(saturation)
        .withValue(value);
    _applyPrimaryHsv(updated);
  }

  void _updatePrimaryHue(double dy, double height) {
    final double y = dy.clamp(0.0, height);
    final double hue = (y / height).clamp(0.0, 1.0) * 360.0;
    final HSVColor updated = _primaryHsv.withHue(hue);
    _applyPrimaryHsv(updated);
  }

  void _applyPrimaryHsv(HSVColor hsv, {bool remember = false}) {
    setState(() {
      _primaryHsv = hsv;
      _primaryColor = hsv.toColor();
      if (remember) {
        _rememberColor(_primaryColor);
      }
    });
  }

  @override
  void _setPrimaryColor(Color color, {bool remember = true}) {
    setState(() {
      _primaryColor = color;
      _primaryHsv = HSVColor.fromColor(color);
      if (remember) {
        _rememberColor(color);
      }
    });
  }

  void _rememberCurrentPrimary() {
    if (_recentColors.isNotEmpty &&
        _recentColors.first.value == _primaryColor.value) {
      return;
    }
    setState(() {
      _rememberColor(_primaryColor);
    });
  }

  void _rememberColor(Color color) {
    _recentColors.removeWhere((c) => c.value == color.value);
    _recentColors.insert(0, color);
    if (_recentColors.length > _recentColorCapacity) {
      _recentColors.removeRange(_recentColorCapacity, _recentColors.length);
    }
  }

  void _selectRecentColor(Color color) {
    _setPrimaryColor(color);
  }

  void _handleSelectColorLineColor(Color color) {
    final bool changed = _colorLineColor.value != color.value;
    if (changed) {
      setState(() => _colorLineColor = color);
      final AppPreferences prefs = AppPreferences.instance;
      prefs.colorLineColor = color;
      unawaited(AppPreferences.save());
    }
    _setPrimaryColor(color);
  }

  Future<void> _handleEditPrimaryColor() async {
    await _pickColor(
      title: '调整当前颜色',
      initialColor: _primaryColor,
      onSelected: (color) => _setPrimaryColor(color),
    );
  }

  Widget? _buildColorPanelTrailing(FluentThemeData theme) {
    if (_recentColors.isEmpty) {
      return null;
    }
    final int count = math.min(5, _recentColors.length);
    final Color borderColor = theme.resources.controlStrokeColorDefault;
    final Color previewBorder = Color.lerp(
      borderColor,
      Colors.transparent,
      0.35,
    )!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(count, (int index) {
        final Color color = _recentColors[index];
        return Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
          child: _InlineRecentColorSwatch(
            color: color,
            selected: color.value == _primaryColor.value,
            borderColor: previewBorder,
            onTap: () => _selectRecentColor(color),
          ),
        );
      }),
    );
  }

  Widget _buildColorLineSelector(FluentThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('色线', style: theme.typography.bodyStrong),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: kColorLinePresets
                .map((Color color) {
                  return _ColorLineSwatch(
                    color: color,
                    selected: color.value == _colorLineColor.value,
                    onTap: () => _handleSelectColorLineColor(color),
                  );
                })
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPanelContent(FluentThemeData theme) {
    final Color borderColor = theme.resources.controlStrokeColorDefault;
    final Color previewBorder = Color.lerp(
      borderColor,
      Colors.transparent,
      0.35,
    )!;
    final List<Color> overflowRecent = _recentColors.length > 5
        ? _recentColors.sublist(5)
        : <Color>[];
    return LayoutBuilder(
      builder: (context, constraints) {
        double sliderWidth = 24;
        const double spacing = 12;
        double squareSize = constraints.maxWidth - sliderWidth - spacing;
        if (squareSize <= 0) {
          squareSize = constraints.maxWidth;
          sliderWidth = 0;
        }

        final HSVColor hsv = _primaryHsv;

        Widget buildColorSquare(double size) {
          return GestureDetector(
            onPanDown: (details) =>
                _updatePrimaryFromSquare(details.localPosition, size),
            onPanUpdate: (details) =>
                _updatePrimaryFromSquare(details.localPosition, size),
            onPanEnd: (_) => _rememberCurrentPrimary(),
            onPanCancel: _rememberCurrentPrimary,
            onTapUp: (_) => _rememberCurrentPrimary(),
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.white,
                                  HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x00FFFFFF), Color(0xFF000000)],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: (hsv.saturation.clamp(0.0, 1.0)) * size - 8,
                    top: ((1 - hsv.value.clamp(0.0, 1.0)) * size) - 8,
                    child: _ColorPickerHandle(color: hsv.toColor()),
                  ),
                ],
              ),
            ),
          );
        }

        Widget buildHueSlider(double height) {
          const List<Color> hueColors = [
            Color(0xFFFF0000), // 0° Red
            Color(0xFFFFFF00), // 60° Yellow
            Color(0xFF00FF00), // 120° Green
            Color(0xFF00FFFF), // 180° Cyan
            Color(0xFF0000FF), // 240° Blue
            Color(0xFFFF00FF), // 300° Magenta
            Color(0xFFFF0000), // 360° Red
          ];
          final double handleY = (hsv.hue.clamp(0.0, 360.0) / 360.0) * height;
          return GestureDetector(
            onPanDown: (details) =>
                _updatePrimaryHue(details.localPosition.dy, height),
            onPanUpdate: (details) =>
                _updatePrimaryHue(details.localPosition.dy, height),
            onPanEnd: (_) => _rememberCurrentPrimary(),
            onPanCancel: _rememberCurrentPrimary,
            onTapUp: (_) => _rememberCurrentPrimary(),
            child: SizedBox(
              width: sliderWidth,
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: hueColors,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: handleY - 8,
                    left: (sliderWidth - 32) / 2,
                    child: const _HueSliderHandle(),
                  ),
                ],
              ),
            ),
          );
        }

        Widget buildRecentColors() {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: overflowRecent
                .map<Widget>(
                  (color) => _RecentColorSwatch(
                    color: color,
                    selected: color.value == _primaryColor.value,
                    borderColor: previewBorder,
                    onTap: () => _selectRecentColor(color),
                  ),
                )
                .toList(growable: false),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildColorLineSelector(theme),
            const SizedBox(height: 12),
            if (overflowRecent.isNotEmpty) ...[
              const SizedBox(height: 12),
              buildRecentColors(),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: squareSize,
                  height: squareSize,
                  child: buildColorSquare(squareSize),
                ),
                if (sliderWidth > 0) ...[
                  const SizedBox(width: spacing),
                  SizedBox(
                    width: sliderWidth,
                    height: squareSize,
                    child: buildHueSlider(squareSize),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildColorIndicator(FluentThemeData theme) {
    final bool isDark = theme.brightness.isDark;
    final Color borderColor = isDark
        ? const Color(0xFF373737)
        : const Color(0xFFD6D6D6);
    final Color background = isDark ? const Color(0xFF1B1B1F) : Colors.white;
    return AppNotificationAnchor(
      child: Tooltip(
        message: '当前颜色 ${_hexStringForColor(_primaryColor)}',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _handleEditPrimaryColor,
            child: Container(
              width: CanvasToolbar.buttonSize,
              height: CanvasToolbar.buttonSize,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              padding: const EdgeInsets.all(6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox.expand(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      border: Border.all(color: Colors.black.withOpacity(0.1)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorPickerHandle extends StatelessWidget {
  const _ColorPickerHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withOpacity(0.8), width: 2),
        color: color,
      ),
    );
  }
}

class _HueSliderHandle extends StatelessWidget {
  const _HueSliderHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withOpacity(0.7), width: 2),
        color: Colors.white,
      ),
    );
  }
}

class _RecentColorSwatch extends StatelessWidget {
  const _RecentColorSwatch({
    required this.color,
    required this.selected,
    required this.borderColor,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final Color highlight = theme.accentColor.defaultBrushFor(theme.brightness);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: color,
            border: Border.all(
              color: selected ? highlight : borderColor,
              width: selected ? 2 : 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

class _InlineRecentColorSwatch extends StatelessWidget {
  const _InlineRecentColorSwatch({
    required this.color,
    required this.selected,
    required this.borderColor,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final Color highlight = theme.accentColor.defaultBrushFor(theme.brightness);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: color,
            border: Border.all(
              color: selected ? highlight : borderColor,
              width: selected ? 2 : 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

class _ColorLineSwatch extends StatelessWidget {
  const _ColorLineSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final Color border = theme.resources.controlStrokeColorDefault;
    final Color highlight = theme.accentColor.defaultBrushFor(theme.brightness);
    final Color effectiveBorder = selected
        ? highlight
        : border.withValues(alpha: border.a * 0.8);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: effectiveBorder,
              width: selected ? 2.2 : 1.4,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
