import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

enum CanvasLayerType { color, strokes }

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
  const CanvasLayerData._({
    required this.id,
    required this.name,
    required this.type,
    required this.visible,
    this.color,
    required this.strokes,
  });

  factory CanvasLayerData.color({
    required String id,
    required String name,
    required Color color,
    bool visible = true,
  }) {
    return CanvasLayerData._(
      id: id,
      name: name,
      type: CanvasLayerType.color,
      visible: visible,
      color: color,
      strokes: const <CanvasStroke>[],
    );
  }

  factory CanvasLayerData.strokes({
    required String id,
    required String name,
    bool visible = true,
    List<CanvasStroke> strokes = const <CanvasStroke>[],
  }) {
    return CanvasLayerData._(
      id: id,
      name: name,
      type: CanvasLayerType.strokes,
      visible: visible,
      color: null,
      strokes: _cloneStrokes(strokes),
    );
  }

  final String id;
  final String name;
  final CanvasLayerType type;
  final bool visible;
  final Color? color;
  final List<CanvasStroke> strokes;

  CanvasLayerData copyWith({
    String? id,
    String? name,
    bool? visible,
    Color? color,
    List<CanvasStroke>? strokes,
  }) {
    return CanvasLayerData._(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type,
      visible: visible ?? this.visible,
      color: type == CanvasLayerType.color ? (color ?? this.color) : null,
      strokes: type == CanvasLayerType.strokes
          ? _cloneStrokes(strokes ?? this.strokes)
          : const <CanvasStroke>[],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'type': type.name,
      'visible': visible,
      if (color != null) 'color': _encodeColor(color!),
      if (type == CanvasLayerType.strokes)
        'strokes': strokes.map((stroke) => stroke.toJson()).toList(growable: false),
    };
  }

  static CanvasLayerData fromJson(Map<String, dynamic> json) {
    final CanvasLayerType type = CanvasLayerType.values.firstWhere(
      (value) => value.name == json['type'],
      orElse: () => CanvasLayerType.strokes,
    );
    switch (type) {
      case CanvasLayerType.color:
        return CanvasLayerData.color(
          id: json['id'] as String,
          name: json['name'] as String,
          color: Color(json['color'] as int),
          visible: json['visible'] as bool? ?? true,
        );
      case CanvasLayerType.strokes:
        final List<dynamic> rawStrokes = json['strokes'] as List<dynamic>? ?? const <dynamic>[];
        return CanvasLayerData.strokes(
          id: json['id'] as String,
          name: json['name'] as String,
          visible: json['visible'] as bool? ?? true,
          strokes: rawStrokes
              .map((dynamic entry) => CanvasStroke.fromJson(entry as Map<String, dynamic>))
              .toList(growable: false),
        );
    }
  }

  static List<CanvasStroke> _cloneStrokes(List<CanvasStroke> strokes) {
    return List<CanvasStroke>.unmodifiable(strokes.map((stroke) => stroke.clone()));
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
