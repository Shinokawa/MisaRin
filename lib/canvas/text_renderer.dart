import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

enum CanvasTextOrientation { horizontal, vertical }

class CanvasTextData {
  const CanvasTextData({
    required this.text,
    required this.origin,
    required this.fontSize,
    required this.fontFamily,
    required this.color,
    this.lineHeight = 1.0,
    this.letterSpacing = 0.0,
    this.maxWidth,
    this.align = ui.TextAlign.left,
    this.orientation = CanvasTextOrientation.horizontal,
    this.antialias = true,
    this.strokeEnabled = false,
    this.strokeWidth = 1.0,
    ui.Color? strokeColor,
  }) : strokeColor = strokeColor ?? const ui.Color(0xFF000000);

  final String text;
  final ui.Offset origin;
  final double fontSize;
  final String fontFamily;
  final ui.Color color;
  final double lineHeight;
  final double letterSpacing;
  final double? maxWidth;
  final ui.TextAlign align;
  final CanvasTextOrientation orientation;
  final bool antialias;
  final bool strokeEnabled;
  final double strokeWidth;
  final ui.Color strokeColor;

  CanvasTextData copyWith({
    String? text,
    ui.Offset? origin,
    double? fontSize,
    String? fontFamily,
    ui.Color? color,
    double? lineHeight,
    double? letterSpacing,
    double? maxWidth,
    ui.TextAlign? align,
    CanvasTextOrientation? orientation,
    bool? antialias,
    bool? strokeEnabled,
    double? strokeWidth,
    ui.Color? strokeColor,
  }) {
    return CanvasTextData(
      text: text ?? this.text,
      origin: origin ?? this.origin,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      color: color ?? this.color,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      maxWidth: maxWidth ?? this.maxWidth,
      align: align ?? this.align,
      orientation: orientation ?? this.orientation,
      antialias: antialias ?? this.antialias,
      strokeEnabled: strokeEnabled ?? this.strokeEnabled,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      strokeColor: strokeColor ?? this.strokeColor,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'text': text,
      'originX': origin.dx,
      'originY': origin.dy,
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      'color': color.value,
      'lineHeight': lineHeight,
      'letterSpacing': letterSpacing,
      if (maxWidth != null) 'maxWidth': maxWidth,
      'align': align.name,
      'orientation': orientation.name,
      'antialias': antialias,
      'strokeEnabled': strokeEnabled,
      'strokeWidth': strokeWidth,
      'strokeColor': strokeColor.value,
    };
  }

  static CanvasTextData fromJson(Map<String, dynamic> json) {
    final double rawOriginX =
        (json['originX'] as num?)?.toDouble() ?? 0;
    final double rawOriginY =
        (json['originY'] as num?)?.toDouble() ?? 0;
    final double? serializedLetterSpacing =
        (json['letterSpacing'] as num?)?.toDouble();
    final double legacyLeftMargin = serializedLetterSpacing == null
        ? (json['leftMargin'] as num?)?.toDouble() ?? 0.0
        : 0.0;
    return CanvasTextData(
      text: json['text'] as String? ?? '',
      origin: ui.Offset(
        rawOriginX + legacyLeftMargin,
        rawOriginY,
      ),
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16,
      fontFamily: json['fontFamily'] as String? ?? '',
      color: ui.Color(json['color'] as int? ?? 0xFF000000),
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.0,
      letterSpacing: serializedLetterSpacing ?? 0.0,
      maxWidth: (json['maxWidth'] as num?)?.toDouble(),
      align: _parseTextAlign(json['align'] as String?),
      orientation: _parseOrientation(json['orientation'] as String?),
      antialias: json['antialias'] as bool? ?? true,
      strokeEnabled: json['strokeEnabled'] as bool? ?? false,
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 1.0,
      strokeColor: ui.Color(json['strokeColor'] as int? ?? 0xFF000000),
    );
  }

  static ui.TextAlign _parseTextAlign(String? raw) {
    if (raw == null) {
      return ui.TextAlign.left;
    }
    return ui.TextAlign.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => ui.TextAlign.left,
    );
  }

  static CanvasTextOrientation _parseOrientation(String? raw) {
    if (raw == null) {
      return CanvasTextOrientation.horizontal;
    }
    return CanvasTextOrientation.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => CanvasTextOrientation.horizontal,
    );
  }
}

class CanvasTextLayout {
  const CanvasTextLayout({required this.bounds});

  final ui.Rect bounds;

  ui.Size get size => bounds.size;
}

class CanvasTextRaster {
  const CanvasTextRaster({
    required this.pixels,
    required this.width,
    required this.height,
    required this.left,
    required this.top,
    required this.layout,
  });

  final Uint8List pixels;
  final int width;
  final int height;
  final int left;
  final int top;
  final CanvasTextLayout layout;
}

class CanvasTextRenderer {
  static const double _kMaxParagraphWidth = 4096.0;

  CanvasTextLayout layout(CanvasTextData data) {
    if (data.orientation == CanvasTextOrientation.vertical) {
      final _VerticalLayout layout = _computeVerticalLayout(data);
      return CanvasTextLayout(bounds: layout.bounds);
    }
    return _layoutHorizontal(data);
  }

  Future<CanvasTextRaster> rasterize(CanvasTextData data) async {
    final CanvasTextLayout textLayout = layout(data);
    final ui.Rect bounds = textLayout.bounds;
    final int width = math.max(1, bounds.width.ceil());
    final int height = math.max(1, bounds.height.ceil());
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    canvas.translate(-bounds.left, -bounds.top);
    _paint(canvas, data);
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(width, height);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    picture.dispose();
    if (byteData == null) {
      image.dispose();
      return CanvasTextRaster(
        pixels: Uint8List(0),
        width: width,
        height: height,
        left: bounds.left.floor(),
        top: bounds.top.floor(),
        layout: textLayout,
      );
    }
    final Uint8List pixels = Uint8List.fromList(byteData.buffer.asUint8List());
    image.dispose();
    return CanvasTextRaster(
      pixels: pixels,
      width: width,
      height: height,
      left: bounds.left.floor(),
      top: bounds.top.floor(),
      layout: textLayout,
    );
  }

  void paint(ui.Canvas canvas, CanvasTextData data) {
    _paint(canvas, data);
  }

  void _paint(ui.Canvas canvas, CanvasTextData data) {
    if (data.text.isEmpty) {
      return;
    }
    if (data.orientation == CanvasTextOrientation.vertical) {
      final _VerticalLayout layout = _computeVerticalLayout(data);
      _paintVertical(canvas, data, layout);
      return;
    }
    _paintHorizontal(canvas, data);
  }

  CanvasTextLayout _layoutHorizontal(CanvasTextData data) {
    final double resolvedWidth = _resolveConstraintWidth(data);
    final ui.Paragraph paragraph = _buildParagraph(
      data,
      data.text,
      paint: null,
    );
    paragraph.layout(ui.ParagraphConstraints(width: resolvedWidth));
    final double width = math.min(
      resolvedWidth,
      math.max(1.0, paragraph.longestLine),
    );
    final double height = math.max(paragraph.height, data.fontSize);
    final ui.Offset origin = data.origin;
    return CanvasTextLayout(
      bounds: ui.Rect.fromLTWH(origin.dx, origin.dy, width, height),
    );
  }

  void _paintHorizontal(ui.Canvas canvas, CanvasTextData data) {
    final double resolvedWidth = _resolveConstraintWidth(data);
    final ui.Offset offset = data.origin;
    if (data.strokeEnabled) {
      final ui.Paragraph strokeParagraph = _buildParagraph(
        data,
        data.text,
        paint: ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = data.strokeWidth
          ..color = data.strokeColor
          ..isAntiAlias = data.antialias,
      );
      strokeParagraph.layout(ui.ParagraphConstraints(width: resolvedWidth));
      canvas.drawParagraph(strokeParagraph, offset);
    }
    final ui.Paragraph fillParagraph = _buildParagraph(
      data,
      data.text,
      paint: ui.Paint()
        ..color = data.color
        ..isAntiAlias = data.antialias,
    );
    fillParagraph.layout(ui.ParagraphConstraints(width: resolvedWidth));
    canvas.drawParagraph(fillParagraph, offset);
  }

  void _paintVertical(
    ui.Canvas canvas,
    CanvasTextData data,
    _VerticalLayout layout,
  ) {
    final Iterable<_GlyphLayout> glyphs = layout.glyphs;
    if (data.strokeEnabled) {
      final ui.Paint strokePaint = ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = data.strokeWidth
        ..color = data.strokeColor
        ..isAntiAlias = data.antialias;
      for (final _GlyphLayout glyph in glyphs) {
        final ui.Paragraph paragraph = _buildParagraph(
          data,
          glyph.text,
          paint: strokePaint,
        );
        paragraph.layout(ui.ParagraphConstraints(
          width: glyph.constraintWidth,
        ));
        canvas.drawParagraph(paragraph, glyph.offset);
      }
    }
    for (final _GlyphLayout glyph in glyphs) {
      final ui.Paragraph paragraph = _buildParagraph(
        data,
        glyph.text,
        paint: ui.Paint()
          ..color = data.color
          ..isAntiAlias = data.antialias,
      );
      paragraph.layout(ui.ParagraphConstraints(
        width: glyph.constraintWidth,
      ));
      canvas.drawParagraph(paragraph, glyph.offset);
    }
  }

  ui.Paragraph _buildParagraph(
    CanvasTextData data,
    String text, {
    required ui.Paint? paint,
  }) {
    final double resolvedLineHeight =
        data.lineHeight <= 0 ? 1.0 : data.lineHeight;
    final ui.ParagraphStyle style = ui.ParagraphStyle(
      fontFamily: data.fontFamily.isEmpty ? null : data.fontFamily,
      fontSize: data.fontSize,
      height: resolvedLineHeight,
      textAlign: data.align,
      maxLines: null,
      ellipsis: null,
    );
    final ui.TextStyle textStyle = ui.TextStyle(
      color: paint == null ? data.color : null,
      foreground: paint,
      fontFamily: data.fontFamily.isEmpty ? null : data.fontFamily,
      fontSize: data.fontSize,
      height: resolvedLineHeight,
      letterSpacing: data.letterSpacing,
    );
    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(style)
      ..pushStyle(textStyle)
      ..addText(text);
    return builder.build();
  }

  double _resolveConstraintWidth(CanvasTextData data) {
    if (data.maxWidth != null &&
        data.maxWidth!.isFinite &&
        data.maxWidth! > 1) {
      return data.maxWidth!.clamp(1.0, _kMaxParagraphWidth);
    }
    final int charCount = math.max(1, data.text.length);
    final int spacingSlots = math.max(0, charCount - 1);
    final double estimated =
        data.fontSize * charCount * 1.1 + data.letterSpacing * spacingSlots;
    return estimated.clamp(64.0, _kMaxParagraphWidth);
  }

  _VerticalLayout _computeVerticalLayout(CanvasTextData data) {
    final double baseX = data.origin.dx;
    final double baseY = data.origin.dy;
    final double lineGap = data.fontSize * (data.lineHeight - 1.0);
    final double lineSpacing = math.max(0, lineGap);
    double maxWidth = 0;
    double maxHeight = 0;
    double columnX = baseX;
    final List<_GlyphLayout> glyphs = <_GlyphLayout>[];
    final List<String> lines = data.text.split('\n');
    for (final String rawLine in lines) {
      final String line = rawLine;
      double y = baseY;
      double columnWidth = 0;
      if (line.isEmpty) {
        y += data.fontSize + lineSpacing + data.letterSpacing;
        columnWidth = math.max(columnWidth, data.fontSize);
      } else {
        for (final int codePoint in line.runes) {
          final String char = String.fromCharCode(codePoint);
          final ui.Paragraph paragraph = _buildParagraph(
            data,
            char,
            paint: ui.Paint()
              ..color = data.color
              ..isAntiAlias = data.antialias,
          );
          final double constraint = data.fontSize * 2;
          paragraph.layout(ui.ParagraphConstraints(width: constraint));
          columnWidth = math.max(columnWidth, paragraph.longestLine);
          glyphs.add(
            _GlyphLayout(
              text: char,
              offset: ui.Offset(columnX, y),
              constraintWidth: constraint,
            ),
          );
          y += paragraph.height + lineSpacing + data.letterSpacing;
        }
      }
      maxWidth = math.max(maxWidth, (columnX - baseX) + columnWidth);
      maxHeight = math.max(maxHeight, y - baseY);
      columnX += columnWidth + data.fontSize * 0.35;
    }
    if (maxWidth <= 0) {
      maxWidth = data.fontSize;
    }
    if (maxHeight <= 0) {
      maxHeight = data.fontSize;
    }
    return _VerticalLayout(
      bounds: ui.Rect.fromLTWH(baseX, baseY, maxWidth, maxHeight),
      glyphs: glyphs,
    );
  }
}

class _VerticalLayout {
  const _VerticalLayout({
    required this.bounds,
    required this.glyphs,
  });

  final ui.Rect bounds;
  final List<_GlyphLayout> glyphs;
}

class _GlyphLayout {
  const _GlyphLayout({
    required this.text,
    required this.offset,
    required this.constraintWidth,
  });

  final String text;
  final ui.Offset offset;
  final double constraintWidth;
}
