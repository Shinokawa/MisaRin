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
class CanvasLayerData {
  CanvasLayerData({
    required this.id,
    required this.name,
    this.visible = true,
    Color? fillColor,
    List<CanvasStroke> strokes = const <CanvasStroke>[],
  })  : fillColor = fillColor,
        strokes = List<CanvasStroke>.unmodifiable(
          strokes.map((stroke) => stroke.clone()),
        );

  final String id;
  final String name;
  final bool visible;
  final Color? fillColor;
  final List<CanvasStroke> strokes;

  bool get hasFill => fillColor != null;

  CanvasLayerData copyWith({
    String? id,
    String? name,
    bool? visible,
    Color? fillColor,
    bool clearFill = false,
    List<CanvasStroke>? strokes,
  }) {
    return CanvasLayerData(
      id: id ?? this.id,
      name: name ?? this.name,
      visible: visible ?? this.visible,
      fillColor: clearFill ? null : (fillColor ?? this.fillColor),
      strokes: strokes ?? this.strokes,
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
    };
  }

  static CanvasLayerData fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawStrokes = json['strokes'] as List<dynamic>? ?? const <dynamic>[];
    final List<CanvasStroke> strokes = rawStrokes
        .map((dynamic entry) => CanvasStroke.fromJson(entry as Map<String, dynamic>))
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
