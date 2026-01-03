import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';

import '../l10n/l10n.dart';

Future<String?> showFontFamilyPickerDialog(
  BuildContext context, {
  required List<String> fontFamilies,
  required String selectedFamily,
  bool isLoading = false,
  double? initialPreviewSize,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => FontFamilyPickerDialog(
      fontFamilies: fontFamilies,
      selectedFamily: selectedFamily,
      isLoading: isLoading,
      initialPreviewSize: initialPreviewSize,
    ),
  );
}

class FontFamilyPickerDialog extends StatefulWidget {
  const FontFamilyPickerDialog({
    super.key,
    required this.fontFamilies,
    required this.selectedFamily,
    this.isLoading = false,
    this.initialPreviewSize,
  });

  final List<String> fontFamilies;
  final String selectedFamily;
  final bool isLoading;
  final double? initialPreviewSize;

  @override
  State<FontFamilyPickerDialog> createState() => _FontFamilyPickerDialogState();
}

class _FontFamilyPickerDialogState extends State<FontFamilyPickerDialog> {
  static const double _listItemExtent = 44;
  static const double _minPreviewSize = 10;
  static const double _maxPreviewSize = 200;
  static const String _sampleLatin = 'The quick brown fox jumps over the lazy dog. 0123456789';
  static const String _sampleZhHans = '简体中文：你好，世界！';
  static const String _sampleZhHant = '繁體中文：你好，世界！';
  static const String _sampleJa = '日本語：こんにちは世界！';
  static const String _sampleKo = '한국어: 안녕하세요 세계!';

  late final TextEditingController _searchController;
  late final TextEditingController _previewController;
  late final ScrollController _scrollController;
  late final List<_FontFamilyEntry> _entries;

  late List<_FontFamilyEntry> _filteredEntries;
  late String _selectedFamily;
  late double _previewSize;
  bool _includeLatin = true;
  bool _includeZhHans = true;
  bool _includeZhHant = true;
  bool _includeJa = true;
  bool _includeKo = true;

  @override
  void initState() {
    super.initState();
    _selectedFamily = widget.selectedFamily;
    _previewSize = (widget.initialPreviewSize ?? 28)
        .clamp(_minPreviewSize, _maxPreviewSize);
    _searchController = TextEditingController()..addListener(_applySearch);
    _previewController = TextEditingController();
    _applySampleText();
    _scrollController = ScrollController();
    _entries = widget.fontFamilies
        .map((family) {
          final String display = _sanitizeDisplayText(family);
          return _FontFamilyEntry(
            family: family,
            display: display,
            displayLower: display.toLowerCase(),
          );
        })
        .toList(growable: false);
    _filteredEntries = _entries;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _scrollToSelected();
    });
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_applySearch)
      ..dispose();
    _previewController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _applySearch() {
    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredEntries = _entries);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _scrollToSelected();
      });
      return;
    }
    setState(() {
      _filteredEntries = _entries
          .where((entry) => entry.displayLower.contains(query))
          .toList(growable: false);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) {
      return;
    }
    final int index =
        _filteredEntries.indexWhere((entry) => entry.family == _selectedFamily);
    if (index <= 0) {
      return;
    }
    final double target = math.max(0.0, (index - 3) * _listItemExtent);
    _scrollController.jumpTo(
      math.min(target, _scrollController.position.maxScrollExtent),
    );
  }

  void _selectFamily(String family) {
    if (_selectedFamily == family) {
      return;
    }
    setState(() => _selectedFamily = family);
  }

  void _confirm() {
    Navigator.of(context).pop(_selectedFamily);
  }

  void _applySampleText() {
    final String text = _buildSampleText();
    _previewController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  int get _enabledLanguageCount {
    int count = 0;
    if (_includeLatin) count++;
    if (_includeZhHans) count++;
    if (_includeZhHant) count++;
    if (_includeJa) count++;
    if (_includeKo) count++;
    return count;
  }

  void _toggleLanguage({
    required bool current,
    required bool next,
    required void Function(bool) assign,
  }) {
    if (!next && current && _enabledLanguageCount <= 1) {
      return;
    }
    setState(() => assign(next));
    _applySampleText();
  }

  String _buildSampleText() {
    final List<String> lines = <String>[];
    if (_includeLatin) {
      lines.add(_sampleLatin);
    }
    if (_includeZhHans) {
      lines.add(_sampleZhHans);
    }
    if (_includeZhHant) {
      lines.add(_sampleZhHant);
    }
    if (_includeJa) {
      lines.add(_sampleJa);
    }
    if (_includeKo) {
      lines.add(_sampleKo);
    }
    if (lines.isEmpty) {
      return _sampleLatin;
    }
    return lines.join('\n');
  }

  static Color _bestForegroundFor(Color background) {
    final double luminance = background.computeLuminance();
    final double contrastWithWhite = (1.05) / (luminance + 0.05);
    final double contrastWithBlack = (luminance + 0.05) / 0.05;
    return contrastWithWhite >= contrastWithBlack ? Colors.white : Colors.black;
  }

  String _sanitizeDisplayText(String raw) {
    if (raw.isEmpty) {
      return raw;
    }
    final List<int> units = raw.codeUnits;
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < units.length; i++) {
      final int unit = units[i];
      if (unit < 0x20) {
        continue;
      }
      if (_isLowSurrogate(unit)) {
        continue;
      }
      if (_isHighSurrogate(unit)) {
        if (i + 1 < units.length && _isLowSurrogate(units[i + 1])) {
          final int high = unit;
          final int low = units[++i];
          final int codePoint =
              0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00);
          buffer.writeCharCode(codePoint);
        } else {
          buffer.writeCharCode(0xFFFD);
        }
        continue;
      }
      buffer.writeCharCode(unit);
    }
    return buffer.toString();
  }

  bool _isHighSurrogate(int value) => value >= 0xD800 && value <= 0xDBFF;

  bool _isLowSurrogate(int value) => value >= 0xDC00 && value <= 0xDFFF;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final l10n = context.l10n;
    final Color selectedBackground =
        theme.accentColor.defaultBrushFor(theme.brightness);
    final Color selectedForeground = _bestForegroundFor(selectedBackground);

    final Widget loadingIndicator = SizedBox(
      width: 18,
      height: 18,
      child: const ProgressRing(strokeWidth: 2.0),
    );

    final Widget title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.fontFamily),
        if (widget.isLoading) ...[
          const SizedBox(width: 8),
          loadingIndicator,
        ],
      ],
    );

    final Widget searchBox = TextBox(
      controller: _searchController,
      autofocus: true,
      placeholder: l10n.fontSearchPlaceholder,
    );

    final Widget fontList = Container(
      decoration: BoxDecoration(
        color: theme.resources.controlFillColorDefault,
        border: Border.all(color: theme.resources.controlStrokeColorDefault),
        borderRadius: BorderRadius.circular(6),
      ),
      child: _filteredEntries.isEmpty
          ? Center(
              child: Text(
                l10n.noMatchingFonts,
                style: theme.typography.caption,
                textAlign: TextAlign.center,
              ),
            )
          : Scrollbar(
              controller: _scrollController,
              child: ListView.builder(
                controller: _scrollController,
                itemExtent: _listItemExtent,
                itemCount: _filteredEntries.length,
                itemBuilder: (context, index) {
                  final _FontFamilyEntry entry = _filteredEntries[index];
                  final bool selected = entry.family == _selectedFamily;
                  final Color foreground = selected
                      ? selectedForeground
                      : theme.typography.body?.color ?? Colors.black;
                  final String? family =
                      entry.family == 'System Default' ? null : entry.family;
                  return Button(
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all<EdgeInsets>(
                        const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                        (states) {
                          if (selected) {
                            return selectedBackground;
                          }
                          if (states.contains(WidgetState.hovered)) {
                            return theme.resources.controlFillColorSecondary;
                          }
                          return Colors.transparent;
                        },
                      ),
                    ),
                    onPressed: () => _selectFamily(entry.family),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        entry.display,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: theme.typography.body?.copyWith(
                          color: foreground,
                          fontFamily: family,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );

    final Widget previewTextBox = TextBox(controller: _previewController);

    final Widget languageToggles = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ToggleButton(
          checked: _includeLatin,
          onChanged: (value) => _toggleLanguage(
            current: _includeLatin,
            next: value,
            assign: (next) => _includeLatin = next,
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text('EN+123'),
          ),
        ),
        ToggleButton(
          checked: _includeZhHans,
          onChanged: (value) => _toggleLanguage(
            current: _includeZhHans,
            next: value,
            assign: (next) => _includeZhHans = next,
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text('简体'),
          ),
        ),
        ToggleButton(
          checked: _includeZhHant,
          onChanged: (value) => _toggleLanguage(
            current: _includeZhHant,
            next: value,
            assign: (next) => _includeZhHant = next,
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text('繁體'),
          ),
        ),
        ToggleButton(
          checked: _includeJa,
          onChanged: (value) => _toggleLanguage(
            current: _includeJa,
            next: value,
            assign: (next) => _includeJa = next,
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text('日本語'),
          ),
        ),
        ToggleButton(
          checked: _includeKo,
          onChanged: (value) => _toggleLanguage(
            current: _includeKo,
            next: value,
            assign: (next) => _includeKo = next,
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text('한국어'),
          ),
        ),
      ],
    );

    final Widget previewSlider = Row(
      children: [
        Text(
          '${l10n.fontSize}：${_previewSize.toStringAsFixed(0)}',
          style: theme.typography.caption,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Slider(
            min: _minPreviewSize,
            max: _maxPreviewSize,
            value: _previewSize,
            onChanged: (value) => setState(() => _previewSize = value),
          ),
        ),
      ],
    );

    final Widget previewArea = Container(
      decoration: BoxDecoration(
        color: theme.resources.controlFillColorSecondary,
        border: Border.all(color: theme.resources.controlStrokeColorDefault),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(12),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _previewController,
        builder: (context, value, _) {
          final String text =
              value.text.isEmpty ? _buildSampleText() : value.text;
          final String? family =
              _selectedFamily == 'System Default' ? null : _selectedFamily;
          return SingleChildScrollView(
            child: SelectableText(
              text,
              style: theme.typography.body?.copyWith(
                fontFamily: family,
                fontSize: _previewSize,
              ),
            ),
          );
        },
      ),
    );

    final Widget content = SizedBox(
      width: 820,
      height: 560,
      child: Row(
        children: [
          SizedBox(
            width: 320,
            child: Column(
              children: [
                searchBox,
                const SizedBox(height: 12),
                Expanded(child: fontList),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sanitizeDisplayText(_selectedFamily),
                  style: theme.typography.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
                const SizedBox(height: 12),
                Text(l10n.fontPreviewText, style: theme.typography.caption),
                const SizedBox(height: 4),
                previewTextBox,
                const SizedBox(height: 12),
                Text(l10n.fontPreviewLanguages, style: theme.typography.caption),
                const SizedBox(height: 4),
                languageToggles,
                const SizedBox(height: 12),
                previewSlider,
                const SizedBox(height: 12),
                Expanded(child: previewArea),
              ],
            ),
          ),
        ],
      ),
    );

    return ContentDialog(
      title: title,
      constraints: const BoxConstraints(maxWidth: 860),
      content: content,
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _confirm, child: Text(l10n.confirm)),
      ],
    );
  }
}

class _FontFamilyEntry {
  const _FontFamilyEntry({
    required this.family,
    required this.display,
    required this.displayLower,
  });

  final String family;
  final String display;
  final String displayLower;
}
