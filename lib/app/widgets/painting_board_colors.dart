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

  void _applyPaintBucket(Offset position) {
    final CanvasLayerData? active = _store.activeLayer;
    bool applied = false;
    if (active != null) {
      applied = _store.setLayerFillColor(active.id, _primaryColor);
    }
    if (!applied) {
      for (final CanvasLayerData layer in _layers.reversed) {
        if (!layer.visible) {
          continue;
        }
        applied = _store.setLayerFillColor(layer.id, _primaryColor);
        if (applied) {
          break;
        }
      }
    }
    if (!applied) {
      _store.addLayer(
        name: '填充',
        fillColor: _primaryColor,
        aboveLayerId: active?.id,
      );
      applied = true;
    }

    if (!applied) {
      return;
    }
    _syncStrokeCache();
    setState(() {
      _bumpCurrentStrokeVersion();
    });
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
      _recentColors.removeRange(
        _recentColorCapacity,
        _recentColors.length,
      );
    }
  }

  void _selectRecentColor(Color color) {
    _setPrimaryColor(color);
  }

  Future<void> _handleEditPrimaryColor() async {
    await _pickColor(
      title: '调整当前颜色',
      initialColor: _primaryColor,
      onSelected: (color) => _setPrimaryColor(color),
    );
  }

  String _formatColorHex(Color color) {
    final int a = (color.a * 255.0).round().clamp(0, 255);
    final int r = (color.r * 255.0).round().clamp(0, 255);
    final int g = (color.g * 255.0).round().clamp(0, 255);
    final int b = (color.b * 255.0).round().clamp(0, 255);
    final String alpha = a.toRadixString(16).padLeft(2, '0').toUpperCase();
    final String red = r.toRadixString(16).padLeft(2, '0').toUpperCase();
    final String green = g.toRadixString(16).padLeft(2, '0').toUpperCase();
    final String blue = b.toRadixString(16).padLeft(2, '0').toUpperCase();
    if (a == 0xFF) {
      return '#$red$green$blue';
    }
    return '#$alpha$red$green$blue';
  }

  Widget _buildColorPanelContent(FluentThemeData theme) {
    final Color borderColor = theme.resources.controlStrokeColorDefault;
    final Color previewBorder =
        Color.lerp(borderColor, Colors.transparent, 0.35)!;
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
                                colors: [
                                  Color(0x00FFFFFF),
                                  Color(0xFF000000),
                                ],
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
            Color(0xFFFF0000),
            Color(0xFFFF00FF),
            Color(0xFF0000FF),
            Color(0xFF00FFFF),
            Color(0xFF00FF00),
            Color(0xFFFFFF00),
            Color(0xFFFF0000),
          ];
          final double handleY =
              (hsv.hue.clamp(0.0, 360.0) / 360.0) * height;
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
                  ClipRRect(
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
            children: _recentColors
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
            if (_recentColors.isNotEmpty) ...[
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
    final Color borderColor = theme.resources.controlStrokeColorDefault;
    return Tooltip(
      message: '当前颜色 ${_formatColorHex(_primaryColor)}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _handleEditPrimaryColor,
          child: Container(
            width: _colorIndicatorSize,
            height: _colorIndicatorSize,
            decoration: BoxDecoration(
              color: _primaryColor,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: borderColor, width: _colorIndicatorBorder),
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
        border: Border.all(
          color: Colors.black.withOpacity(0.8),
          width: 2,
        ),
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
        border: Border.all(
          color: Colors.black.withOpacity(0.7),
          width: 2,
        ),
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
