import '../canvas/canvas_tools.dart';

class BrushPreset {
  BrushPreset({
    required this.id,
    required this.name,
    required this.shape,
    this.shapeId,
    this.author,
    this.version,
    required this.spacing,
    required this.hardness,
    required this.flow,
    required this.scatter,
    required this.randomRotation,
    required this.smoothRotation,
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
  String? shapeId;
  String? author;
  String? version;
  double spacing;
  double hardness;
  double flow;
  double scatter;
  bool randomRotation;
  bool smoothRotation;
  double rotationJitter;
  int antialiasLevel;
  bool hollowEnabled;
  double hollowRatio;
  bool hollowEraseOccludedParts;
  bool autoSharpTaper;
  bool snapToPixel;

  BrushPreset copyWith({
    String? id,
    String? name,
    BrushShape? shape,
    String? shapeId,
    String? author,
    String? version,
    double? spacing,
    double? hardness,
    double? flow,
    double? scatter,
    bool? randomRotation,
    bool? smoothRotation,
    double? rotationJitter,
    int? antialiasLevel,
    bool? hollowEnabled,
    double? hollowRatio,
    bool? hollowEraseOccludedParts,
    bool? autoSharpTaper,
    bool? snapToPixel,
  }) {
    return BrushPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      shape: shape ?? this.shape,
      shapeId: shapeId ?? this.shapeId,
      author: author ?? this.author,
      version: version ?? this.version,
      spacing: spacing ?? this.spacing,
      hardness: hardness ?? this.hardness,
      flow: flow ?? this.flow,
      scatter: scatter ?? this.scatter,
      randomRotation: randomRotation ?? this.randomRotation,
      smoothRotation: smoothRotation ?? this.smoothRotation,
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

    final String? resolvedShapeId = shapeId ?? _shapeIdFromEnum(shape);

    return copyWith(
      spacing: spacingValue.clamp(0.02, 2.5),
      hardness: hardnessValue.clamp(0.0, 1.0),
      flow: flowValue.clamp(0.0, 1.0),
      scatter: scatterValue.clamp(0.0, 1.0),
      smoothRotation: smoothRotation,
      rotationJitter: rotationValue,
      antialiasLevel: aaValue,
      hollowRatio: hollowValue.clamp(0.0, 1.0),
      shapeId: resolvedShapeId,
    );
  }

  factory BrushPreset.fromJson(Map<String, dynamic> json) {
    final int shapeIndex = (json['shape'] as num?)?.toInt() ?? 0;
    final String? shapeId = json['shapeId'] as String?;
    final BrushShape? shapeFromId = _shapeEnumFromId(shapeId);
    final int clampedShape = shapeIndex.clamp(0, BrushShape.values.length - 1);
    final BrushShape resolvedShape = shapeFromId ?? BrushShape.values[clampedShape];
    return BrushPreset(
      id: (json['id'] as String?) ?? 'brush_${DateTime.now().millisecondsSinceEpoch}',
      name: (json['name'] as String?) ?? 'Brush',
      shape: resolvedShape,
      shapeId: shapeId,
      author: json['author'] as String?,
      version: json['version'] as String?,
      spacing: (json['spacing'] as num?)?.toDouble() ?? 0.15,
      hardness: (json['hardness'] as num?)?.toDouble() ?? 0.8,
      flow: (json['flow'] as num?)?.toDouble() ?? 1.0,
      scatter: (json['scatter'] as num?)?.toDouble() ?? 0.0,
      randomRotation: (json['randomRotation'] as bool?) ?? false,
      smoothRotation: (json['smoothRotation'] as bool?) ?? false,
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
        'shapeId': shapeId,
        'author': author,
        'version': version,
        'spacing': spacing,
        'hardness': hardness,
        'flow': flow,
        'scatter': scatter,
        'randomRotation': randomRotation,
        'smoothRotation': smoothRotation,
        'rotationJitter': rotationJitter,
        'antialiasLevel': antialiasLevel,
        'hollowEnabled': hollowEnabled,
        'hollowRatio': hollowRatio,
        'hollowEraseOccludedParts': hollowEraseOccludedParts,
        'autoSharpTaper': autoSharpTaper,
        'snapToPixel': snapToPixel,
      };

  String get resolvedShapeId => shapeId ?? _shapeIdFromEnum(shape);

  bool isSameAs(BrushPreset other) {
    final BrushPreset a = sanitized();
    final BrushPreset b = other.sanitized();
    return a.name == b.name &&
        a.resolvedShapeId == b.resolvedShapeId &&
        a.spacing == b.spacing &&
        a.hardness == b.hardness &&
        a.flow == b.flow &&
        a.scatter == b.scatter &&
        a.randomRotation == b.randomRotation &&
        a.smoothRotation == b.smoothRotation &&
        a.rotationJitter == b.rotationJitter &&
        a.antialiasLevel == b.antialiasLevel &&
        a.hollowEnabled == b.hollowEnabled &&
        a.hollowRatio == b.hollowRatio &&
        a.hollowEraseOccludedParts == b.hollowEraseOccludedParts &&
        a.autoSharpTaper == b.autoSharpTaper &&
        a.snapToPixel == b.snapToPixel &&
        a.author == b.author &&
        a.version == b.version;
  }

  static BrushShape? _shapeEnumFromId(String? id) {
    if (id == null || id.isEmpty) {
      return null;
    }
    switch (id.toLowerCase()) {
      case 'circle':
        return BrushShape.circle;
      case 'triangle':
        return BrushShape.triangle;
      case 'square':
        return BrushShape.square;
      case 'star':
        return BrushShape.star;
    }
    return null;
  }

  static String _shapeIdFromEnum(BrushShape shape) {
    switch (shape) {
      case BrushShape.circle:
        return 'circle';
      case BrushShape.triangle:
        return 'triangle';
      case BrushShape.square:
        return 'square';
      case BrushShape.star:
        return 'star';
    }
  }
}
