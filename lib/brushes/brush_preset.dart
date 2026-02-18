import '../canvas/canvas_tools.dart';

class BrushPreset {
  BrushPreset({
    required this.id,
    required this.name,
    required this.shape,
    required this.spacing,
    required this.hardness,
    required this.flow,
    required this.scatter,
    required this.randomRotation,
    required this.rotationJitter,
    required this.antialiasLevel,
    required this.hollowEnabled,
    required this.hollowRatio,
    required this.hollowEraseOccludedParts,
    required this.autoSharpTaper,
    required this.snapToPixel,
  });

  final String id;
  String name;
  BrushShape shape;
  double spacing;
  double hardness;
  double flow;
  double scatter;
  bool randomRotation;
  double rotationJitter;
  int antialiasLevel;
  bool hollowEnabled;
  double hollowRatio;
  bool hollowEraseOccludedParts;
  bool autoSharpTaper;
  bool snapToPixel;

  BrushPreset copyWith({
    String? name,
    BrushShape? shape,
    double? spacing,
    double? hardness,
    double? flow,
    double? scatter,
    bool? randomRotation,
    double? rotationJitter,
    int? antialiasLevel,
    bool? hollowEnabled,
    double? hollowRatio,
    bool? hollowEraseOccludedParts,
    bool? autoSharpTaper,
    bool? snapToPixel,
  }) {
    return BrushPreset(
      id: id,
      name: name ?? this.name,
      shape: shape ?? this.shape,
      spacing: spacing ?? this.spacing,
      hardness: hardness ?? this.hardness,
      flow: flow ?? this.flow,
      scatter: scatter ?? this.scatter,
      randomRotation: randomRotation ?? this.randomRotation,
      rotationJitter: rotationJitter ?? this.rotationJitter,
      antialiasLevel: antialiasLevel ?? this.antialiasLevel,
      hollowEnabled: hollowEnabled ?? this.hollowEnabled,
      hollowRatio: hollowRatio ?? this.hollowRatio,
      hollowEraseOccludedParts:
          hollowEraseOccludedParts ?? this.hollowEraseOccludedParts,
      autoSharpTaper: autoSharpTaper ?? this.autoSharpTaper,
      snapToPixel: snapToPixel ?? this.snapToPixel,
    );
  }

  BrushPreset sanitized() {
    final double spacingValue = spacing.isFinite ? spacing : 0.15;
    final double hardnessValue = hardness.isFinite ? hardness : 0.8;
    final double flowValue = flow.isFinite ? flow : 1.0;
    final double scatterValue = scatter.isFinite ? scatter : 0.0;
    double rotationValue = rotationJitter.isFinite ? rotationJitter : 1.0;
    rotationValue = rotationValue.clamp(0.0, 1.0);
    if (randomRotation && rotationValue <= 0.0001) {
      rotationValue = 1.0;
    }
    final int aaValue = antialiasLevel.clamp(0, 9);
    final double hollowValue = hollowRatio.isFinite ? hollowRatio : 0.0;

    return copyWith(
      spacing: spacingValue.clamp(0.02, 2.5),
      hardness: hardnessValue.clamp(0.0, 1.0),
      flow: flowValue.clamp(0.0, 1.0),
      scatter: scatterValue.clamp(0.0, 1.0),
      rotationJitter: rotationValue,
      antialiasLevel: aaValue,
      hollowRatio: hollowValue.clamp(0.0, 1.0),
    );
  }

  factory BrushPreset.fromJson(Map<String, dynamic> json) {
    final int shapeIndex = (json['shape'] as num?)?.toInt() ?? 0;
    final int clampedShape = shapeIndex.clamp(0, BrushShape.values.length - 1);
    return BrushPreset(
      id: (json['id'] as String?) ?? 'brush_${DateTime.now().millisecondsSinceEpoch}',
      name: (json['name'] as String?) ?? 'Brush',
      shape: BrushShape.values[clampedShape],
      spacing: (json['spacing'] as num?)?.toDouble() ?? 0.15,
      hardness: (json['hardness'] as num?)?.toDouble() ?? 0.8,
      flow: (json['flow'] as num?)?.toDouble() ?? 1.0,
      scatter: (json['scatter'] as num?)?.toDouble() ?? 0.0,
      randomRotation: (json['randomRotation'] as bool?) ?? false,
      rotationJitter: (json['rotationJitter'] as num?)?.toDouble() ?? 1.0,
      antialiasLevel: (json['antialiasLevel'] as num?)?.toInt() ?? 1,
      hollowEnabled: (json['hollowEnabled'] as bool?) ?? false,
      hollowRatio: (json['hollowRatio'] as num?)?.toDouble() ?? 0.0,
      hollowEraseOccludedParts:
          (json['hollowEraseOccludedParts'] as bool?) ?? false,
      autoSharpTaper: (json['autoSharpTaper'] as bool?) ?? false,
      snapToPixel: (json['snapToPixel'] as bool?) ?? false,
    ).sanitized();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'shape': shape.index,
        'spacing': spacing,
        'hardness': hardness,
        'flow': flow,
        'scatter': scatter,
        'randomRotation': randomRotation,
        'rotationJitter': rotationJitter,
        'antialiasLevel': antialiasLevel,
        'hollowEnabled': hollowEnabled,
        'hollowRatio': hollowRatio,
        'hollowEraseOccludedParts': hollowEraseOccludedParts,
        'autoSharpTaper': autoSharpTaper,
        'snapToPixel': snapToPixel,
      };
}
