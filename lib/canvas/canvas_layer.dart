import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

enum CanvasLayerType { color, strokes }

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
      strokes: const <List<Offset>>[],
    );
  }

  factory CanvasLayerData.strokes({
    required String id,
    required String name,
    bool visible = true,
    List<List<Offset>> strokes = const <List<Offset>>[],
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
  final List<List<Offset>> strokes;

  CanvasLayerData copyWith({
    String? id,
    String? name,
    bool? visible,
    Color? color,
    List<List<Offset>>? strokes,
  }) {
    return CanvasLayerData._(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type,
      visible: visible ?? this.visible,
      color: type == CanvasLayerType.color ? (color ?? this.color) : null,
      strokes: type == CanvasLayerType.strokes
          ? _cloneStrokes(strokes ?? this.strokes)
          : const <List<Offset>>[],
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
        'strokes': strokes
            .map((stroke) => stroke
                .map((point) => <String, double>{
                      'x': point.dx,
                      'y': point.dy,
                    })
                .toList(growable: false))
            .toList(growable: false),
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
        final List<dynamic> rawStrokes =
            (json['strokes'] as List<dynamic>? ?? const <dynamic>[]);
        return CanvasLayerData.strokes(
          id: json['id'] as String,
          name: json['name'] as String,
          visible: json['visible'] as bool? ?? true,
          strokes: rawStrokes
              .map((stroke) => (stroke as List<dynamic>)
                  .map((point) {
                    final Map<String, dynamic> map =
                        point as Map<String, dynamic>;
                    return Offset(
                      (map['x'] as num).toDouble(),
                      (map['y'] as num).toDouble(),
                    );
                  })
                  .toList(growable: false))
              .toList(growable: false),
        );
    }
  }

  static List<List<Offset>> _cloneStrokes(List<List<Offset>> strokes) {
    return List<List<Offset>>.unmodifiable(
      strokes
          .map((stroke) =>
              List<Offset>.unmodifiable(List<Offset>.from(stroke))),
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
