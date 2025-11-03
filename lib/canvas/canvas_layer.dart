import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
class CanvasStroke {
  CanvasStroke({
    required this.color,
    required this.width,
    List<Offset>? points,
  }) : points = points ?? <Offset>[];

  final Color color;
  final double width;
  final List<Offset> points;

  Path toPath() {
    final Path path = Path();
    if (points.isEmpty) {
      return path;
    }
    path.moveTo(points.first.dx, points.first.dy);
    for (int index = 1; index < points.length; index++) {
      final Offset point = points[index];
      path.lineTo(point.dx, point.dy);
    }
    return path;
  }

  CanvasStroke copyWith({
    Color? color,
    double? width,
    List<Offset>? points,
  }) {
    return CanvasStroke(
      color: color ?? this.color,
      width: width ?? this.width,
      points: points != null ? List<Offset>.from(points) : List<Offset>.from(this.points),
    );
  }

  CanvasStroke clone() => copyWith();

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'color': _encodeColor(color),
      'width': width,
      'points': points
          .map((point) => <String, double>{'x': point.dx, 'y': point.dy})
          .toList(growable: false),
    };
  }

  factory CanvasStroke.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawPoints = json['points'] as List<dynamic>? ?? const <dynamic>[];
    return CanvasStroke(
      color: Color(json['color'] as int),
      width: (json['width'] as num).toDouble(),
      points: rawPoints
          .map((dynamic entry) {
            final Map<String, dynamic> map = entry as Map<String, dynamic>;
            return Offset(
              (map['x'] as num).toDouble(),
              (map['y'] as num).toDouble(),
            );
          })
          .toList(growable: true),
    );
  }
}

@immutable
class CanvasFillSpan {
  const CanvasFillSpan({
    required this.dy,
    required this.start,
    required this.end,
  }) : assert(end >= start);

  final int dy;
  final int start;
  final int end;

  CanvasFillSpan copyWith({
    int? dy,
    int? start,
    int? end,
  }) {
    return CanvasFillSpan(
      dy: dy ?? this.dy,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'dy': dy,
      'start': start,
      'end': end,
    };
  }

  factory CanvasFillSpan.fromJson(Map<String, dynamic> json) {
    return CanvasFillSpan(
      dy: json['dy'] as int,
      start: json['start'] as int,
      end: json['end'] as int,
    );
  }
}

@immutable
class CanvasFillRegion {
  CanvasFillRegion({
    required this.color,
    required this.origin,
    required this.width,
    required this.height,
    List<CanvasFillSpan> spans = const <CanvasFillSpan>[],
  })  : spans = List<CanvasFillSpan>.unmodifiable(
          spans.map((span) => span.copyWith()),
        );

  final Color color;
  final Offset origin;
  final int width;
  final int height;
  final List<CanvasFillSpan> spans;

  Path toPath() {
    final Path path = Path();
    for (final CanvasFillSpan span in spans) {
      path.addRect(
        Rect.fromLTWH(
          origin.dx + span.start,
          origin.dy + span.dy,
          (span.end - span.start + 1).toDouble(),
          1.0,
        ),
      );
    }
    return path;
  }

  CanvasFillRegion copyWith({
    Color? color,
    Offset? origin,
    int? width,
    int? height,
    List<CanvasFillSpan>? spans,
  }) {
    return CanvasFillRegion(
      color: color ?? this.color,
      origin: origin ?? this.origin,
      width: width ?? this.width,
      height: height ?? this.height,
      spans: spans ?? this.spans,
    );
  }

  CanvasFillRegion clone() => copyWith();

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'color': _encodeColor(color),
      'origin': <String, double>{
        'x': origin.dx,
        'y': origin.dy,
      },
      'width': width,
      'height': height,
      'spans': spans
          .map((span) => span.toJson())
          .toList(growable: false),
    };
  }

  factory CanvasFillRegion.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> originMap =
        json['origin'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final List<dynamic> rawSpans = json['spans'] as List<dynamic>? ??
        const <dynamic>[];
    return CanvasFillRegion(
      color: Color(json['color'] as int),
      origin: Offset(
        (originMap['x'] as num?)?.toDouble() ?? 0.0,
        (originMap['y'] as num?)?.toDouble() ?? 0.0,
      ),
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      spans: rawSpans
          .map((dynamic entry) =>
              CanvasFillSpan.fromJson(entry as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

@immutable
class CanvasLayerData {
  CanvasLayerData({
    required this.id,
    required this.name,
    this.visible = true,
    Color? fillColor,
    List<CanvasStroke> strokes = const <CanvasStroke>[],
    List<CanvasFillRegion> fills = const <CanvasFillRegion>[],
  })  : fillColor = fillColor,
        strokes = List<CanvasStroke>.unmodifiable(
          strokes.map((stroke) => stroke.clone()),
        ),
        fills = List<CanvasFillRegion>.unmodifiable(
          fills.map((fill) => fill.clone()),
        );

  final String id;
  final String name;
  final bool visible;
  final Color? fillColor;
  final List<CanvasStroke> strokes;
  final List<CanvasFillRegion> fills;

  bool get hasFill => fillColor != null;

  CanvasLayerData copyWith({
    String? id,
    String? name,
    bool? visible,
    Color? fillColor,
    bool clearFill = false,
    List<CanvasStroke>? strokes,
    List<CanvasFillRegion>? fills,
  }) {
    return CanvasLayerData(
      id: id ?? this.id,
      name: name ?? this.name,
      visible: visible ?? this.visible,
      fillColor: clearFill ? null : (fillColor ?? this.fillColor),
      strokes: strokes ?? this.strokes,
      fills: fills ?? this.fills,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'visible': visible,
      'type': 'strokes',
      if (fillColor != null) 'fillColor': _encodeColor(fillColor!),
      'strokes': strokes.map((stroke) => stroke.toJson()).toList(growable: false),
      if (fills.isNotEmpty)
        'fills': fills.map((fill) => fill.toJson()).toList(growable: false),
    };
  }

  static CanvasLayerData fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawStrokes = json['strokes'] as List<dynamic>? ?? const <dynamic>[];
    final List<CanvasStroke> strokes = rawStrokes
        .map((dynamic entry) => CanvasStroke.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);

    final List<dynamic> rawFills = json['fills'] as List<dynamic>? ?? const <dynamic>[];
    final List<CanvasFillRegion> fills = rawFills
        .map((dynamic entry) =>
            CanvasFillRegion.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);

    Color? fill;
    if (json.containsKey('fillColor')) {
      fill = Color(json['fillColor'] as int);
    } else if (json['type'] == 'color' && json.containsKey('color')) {
      fill = Color(json['color'] as int);
    }

    return CanvasLayerData(
      id: json['id'] as String,
      name: json['name'] as String,
      visible: json['visible'] as bool? ?? true,
      fillColor: fill,
      strokes: strokes,
      fills: fills,
    );
  }
}

String generateLayerId() {
  final int timestamp = DateTime.now().microsecondsSinceEpoch;
  final int randomBits = Random().nextInt(0x7FFFFFFF);
  return 'layer_${timestamp.toRadixString(16)}_${randomBits.toRadixString(16)}';
}

int _encodeColor(Color color) {
  final int a = (color.a * 255.0).round() & 0xff;
  final int r = (color.r * 255.0).round() & 0xff;
  final int g = (color.g * 255.0).round() & 0xff;
  final int b = (color.b * 255.0).round() & 0xff;
  return (a << 24) | (r << 16) | (g << 8) | b;
}
