import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
class CanvasLayerData {
  CanvasLayerData({
    required this.id,
    required this.name,
    this.visible = true,
    Color? fillColor,
    Uint8List? bitmap,
    int? bitmapWidth,
    int? bitmapHeight,
  })  : fillColor = fillColor,
        bitmap = bitmap != null ? Uint8List.fromList(bitmap) : null,
        bitmapWidth = bitmap != null ? bitmapWidth : null,
        bitmapHeight = bitmap != null ? bitmapHeight : null;

  final String id;
  final String name;
  final bool visible;
  final Color? fillColor;
  final Uint8List? bitmap;
  final int? bitmapWidth;
  final int? bitmapHeight;

  bool get hasFill => fillColor != null;
  bool get hasBitmap => bitmap != null && bitmapWidth != null && bitmapHeight != null;

  CanvasLayerData copyWith({
    String? id,
    String? name,
    bool? visible,
    Color? fillColor,
    bool clearFill = false,
    Uint8List? bitmap,
    int? bitmapWidth,
    int? bitmapHeight,
    bool clearBitmap = false,
  }) {
    final Uint8List? resolvedBitmap;
    if (clearBitmap) {
      resolvedBitmap = null;
    } else if (bitmap != null) {
      resolvedBitmap = Uint8List.fromList(bitmap);
    } else {
      resolvedBitmap = this.bitmap != null ? Uint8List.fromList(this.bitmap!) : null;
    }
    final int? resolvedWidth;
    final int? resolvedHeight;
    if (resolvedBitmap == null) {
      resolvedWidth = null;
      resolvedHeight = null;
    } else {
      resolvedWidth = bitmapWidth ?? this.bitmapWidth;
      resolvedHeight = bitmapHeight ?? this.bitmapHeight;
    }

    return CanvasLayerData(
      id: id ?? this.id,
      name: name ?? this.name,
      visible: visible ?? this.visible,
      fillColor: clearFill ? null : (fillColor ?? this.fillColor),
      bitmap: resolvedBitmap,
      bitmapWidth: resolvedWidth,
      bitmapHeight: resolvedHeight,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'visible': visible,
      if (fillColor != null) 'fillColor': _encodeColor(fillColor!),
      if (hasBitmap)
        'bitmap': <String, dynamic>{
          'width': bitmapWidth,
          'height': bitmapHeight,
          'pixels': base64Encode(bitmap!),
        },
    };
  }

  static CanvasLayerData fromJson(Map<String, dynamic> json) {
    Color? fill;
    if (json.containsKey('fillColor')) {
      fill = Color(json['fillColor'] as int);
    } else if (json['type'] == 'color' && json.containsKey('color')) {
      fill = Color(json['color'] as int);
    }

    Uint8List? bitmap;
    int? bitmapWidth;
    int? bitmapHeight;
    final Object? rawBitmap = json['bitmap'];
    if (rawBitmap is Map<String, dynamic>) {
      final String? encoded = rawBitmap['pixels'] as String?;
      if (encoded != null) {
        try {
          bitmap = Uint8List.fromList(base64Decode(encoded));
          bitmapWidth = rawBitmap['width'] as int?;
          bitmapHeight = rawBitmap['height'] as int?;
        } catch (_) {
          bitmap = null;
          bitmapWidth = null;
          bitmapHeight = null;
        }
      }
    }

    return CanvasLayerData(
      id: json['id'] as String,
      name: json['name'] as String,
      visible: json['visible'] as bool? ?? true,
      fillColor: fill,
      bitmap: bitmap,
      bitmapWidth: bitmapWidth,
      bitmapHeight: bitmapHeight,
    );
  }
}

String generateLayerId() {
  final int timestamp = DateTime.now().microsecondsSinceEpoch;
  final int randomBits = Random().nextInt(0x7FFFFFFF);
  return 'layer_${timestamp.toRadixString(16)}_${randomBits.toRadixString(16)}';
}

int _encodeColor(Color color) {
  return (color.alpha << 24) |
      (color.red << 16) |
      (color.green << 8) |
      color.blue;
}
