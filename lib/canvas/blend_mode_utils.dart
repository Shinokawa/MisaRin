import 'dart:ui' as ui;

import 'canvas_layer.dart';

const List<CanvasLayerBlendMode> kCanvasBlendModeDisplayOrder =
    <CanvasLayerBlendMode>[
      CanvasLayerBlendMode.normal,
      CanvasLayerBlendMode.dissolve,
      CanvasLayerBlendMode.darken,
      CanvasLayerBlendMode.multiply,
      CanvasLayerBlendMode.colorBurn,
      CanvasLayerBlendMode.linearBurn,
      CanvasLayerBlendMode.darkerColor,
      CanvasLayerBlendMode.lighten,
      CanvasLayerBlendMode.screen,
      CanvasLayerBlendMode.colorDodge,
      CanvasLayerBlendMode.linearDodge,
      CanvasLayerBlendMode.lighterColor,
      CanvasLayerBlendMode.overlay,
      CanvasLayerBlendMode.softLight,
      CanvasLayerBlendMode.hardLight,
      CanvasLayerBlendMode.vividLight,
      CanvasLayerBlendMode.linearLight,
      CanvasLayerBlendMode.pinLight,
      CanvasLayerBlendMode.hardMix,
      CanvasLayerBlendMode.difference,
      CanvasLayerBlendMode.exclusion,
      CanvasLayerBlendMode.subtract,
      CanvasLayerBlendMode.divide,
      CanvasLayerBlendMode.hue,
      CanvasLayerBlendMode.saturation,
      CanvasLayerBlendMode.color,
      CanvasLayerBlendMode.luminosity,
    ];

const Map<CanvasLayerBlendMode, String> _kBlendModeLabels =
    <CanvasLayerBlendMode, String>{
      CanvasLayerBlendMode.normal: '正常',
      CanvasLayerBlendMode.dissolve: '溶解',
      CanvasLayerBlendMode.darken: '变暗',
      CanvasLayerBlendMode.multiply: '正片叠底',
      CanvasLayerBlendMode.colorBurn: '颜色加深',
      CanvasLayerBlendMode.linearBurn: '线性加深',
      CanvasLayerBlendMode.darkerColor: '深色',
      CanvasLayerBlendMode.lighten: '变亮',
      CanvasLayerBlendMode.screen: '滤色',
      CanvasLayerBlendMode.colorDodge: '颜色减淡',
      CanvasLayerBlendMode.linearDodge: '线性减淡',
      CanvasLayerBlendMode.lighterColor: '浅色',
      CanvasLayerBlendMode.overlay: '叠加',
      CanvasLayerBlendMode.softLight: '柔光',
      CanvasLayerBlendMode.hardLight: '强光',
      CanvasLayerBlendMode.vividLight: '亮光',
      CanvasLayerBlendMode.linearLight: '线性光',
      CanvasLayerBlendMode.pinLight: '点光',
      CanvasLayerBlendMode.hardMix: '实色混合',
      CanvasLayerBlendMode.difference: '差值',
      CanvasLayerBlendMode.exclusion: '排除',
      CanvasLayerBlendMode.subtract: '减去',
      CanvasLayerBlendMode.divide: '划分',
      CanvasLayerBlendMode.hue: '色相',
      CanvasLayerBlendMode.saturation: '饱和度',
      CanvasLayerBlendMode.color: '颜色',
      CanvasLayerBlendMode.luminosity: '明度',
    };

const Map<CanvasLayerBlendMode, String> _kPsdBlendKeys =
    <CanvasLayerBlendMode, String>{
      CanvasLayerBlendMode.normal: 'norm',
      CanvasLayerBlendMode.dissolve: 'diss',
      CanvasLayerBlendMode.darken: 'dark',
      CanvasLayerBlendMode.multiply: 'mul ',
      CanvasLayerBlendMode.colorBurn: 'idiv',
      CanvasLayerBlendMode.linearBurn: 'lbrn',
      CanvasLayerBlendMode.darkerColor: 'dkCl',
      CanvasLayerBlendMode.lighten: 'lite',
      CanvasLayerBlendMode.screen: 'scrn',
      CanvasLayerBlendMode.colorDodge: 'div ',
      CanvasLayerBlendMode.linearDodge: 'lddg',
      CanvasLayerBlendMode.lighterColor: 'lgCl',
      CanvasLayerBlendMode.overlay: 'over',
      CanvasLayerBlendMode.softLight: 'sLit',
      CanvasLayerBlendMode.hardLight: 'hLit',
      CanvasLayerBlendMode.vividLight: 'vLit',
      CanvasLayerBlendMode.linearLight: 'lLit',
      CanvasLayerBlendMode.pinLight: 'pLit',
      CanvasLayerBlendMode.hardMix: 'hMix',
      CanvasLayerBlendMode.difference: 'diff',
      CanvasLayerBlendMode.exclusion: 'smud',
      CanvasLayerBlendMode.subtract: 'fsub',
      CanvasLayerBlendMode.divide: 'fdiv',
      CanvasLayerBlendMode.hue: 'hue ',
      CanvasLayerBlendMode.saturation: 'sat ',
      CanvasLayerBlendMode.color: 'colr',
      CanvasLayerBlendMode.luminosity: 'lum ',
    };

final Map<String, CanvasLayerBlendMode> _kPsdKeyLookup = () {
  final Map<String, CanvasLayerBlendMode> lookup =
      <String, CanvasLayerBlendMode>{};
  _kPsdBlendKeys.forEach((CanvasLayerBlendMode mode, String key) {
    lookup[key] = mode;
    final String trimmed = key.trim();
    if (trimmed != key) {
      lookup[trimmed] = mode;
    }
    final String lower = key.toLowerCase();
    if (lower != key) {
      lookup[lower] = mode;
    }
    final String lowerTrimmed = lower.trim();
    if (lowerTrimmed != lower) {
      lookup[lowerTrimmed] = mode;
    }
  });
  return lookup;
}();

final Map<CanvasLayerBlendMode, ui.BlendMode?> _kFlutterBlendModes =
    <CanvasLayerBlendMode, ui.BlendMode?>{
      CanvasLayerBlendMode.normal: null,
      CanvasLayerBlendMode.multiply: ui.BlendMode.multiply,
      CanvasLayerBlendMode.darken: ui.BlendMode.darken,
      CanvasLayerBlendMode.lighten: ui.BlendMode.lighten,
      CanvasLayerBlendMode.screen: ui.BlendMode.screen,
      CanvasLayerBlendMode.colorBurn: ui.BlendMode.colorBurn,
      CanvasLayerBlendMode.colorDodge: ui.BlendMode.colorDodge,
      CanvasLayerBlendMode.linearDodge: ui.BlendMode.plus,
      CanvasLayerBlendMode.overlay: ui.BlendMode.overlay,
      CanvasLayerBlendMode.softLight: ui.BlendMode.softLight,
      CanvasLayerBlendMode.hardLight: ui.BlendMode.hardLight,
      CanvasLayerBlendMode.difference: ui.BlendMode.difference,
      CanvasLayerBlendMode.exclusion: ui.BlendMode.exclusion,
      CanvasLayerBlendMode.hue: ui.BlendMode.hue,
      CanvasLayerBlendMode.saturation: ui.BlendMode.saturation,
      CanvasLayerBlendMode.color: ui.BlendMode.color,
      CanvasLayerBlendMode.luminosity: ui.BlendMode.luminosity,
    };

extension CanvasLayerBlendModeX on CanvasLayerBlendMode {
  String get label => _kBlendModeLabels[this] ?? name;

  String get psdKey => _kPsdBlendKeys[this] ?? 'norm';

  ui.BlendMode? get flutterBlendMode =>
      _kFlutterBlendModes.containsKey(this) ? _kFlutterBlendModes[this] : null;

  static CanvasLayerBlendMode fromPsdKey(String? key) {
    if (key == null) {
      return CanvasLayerBlendMode.normal;
    }
    final String raw = key;
    return _kPsdKeyLookup[raw] ??
        _kPsdKeyLookup[raw.trim()] ??
        CanvasLayerBlendMode.normal;
  }
}
