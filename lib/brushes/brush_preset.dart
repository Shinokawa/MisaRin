import 'package:flutter/foundation.dart' show listEquals;

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
    this.bristleEnabled = false,
    this.bristleDensity = 0.0,
    this.bristleRandom = 0.0,
    this.bristleScale = 1.0,
    this.bristleShear = 0.0,
    this.bristleThreshold = false,
    this.bristleConnected = false,
    this.bristleUsePressure = true,
    this.bristleAntialias = false,
    this.bristleUseCompositing = true,
    this.inkAmount = 1.0,
    this.inkDepletion = 0.0,
    this.inkUseOpacity = true,
    this.inkDepletionEnabled = false,
    this.inkUseSaturation = false,
    this.inkUseWeights = false,
    this.inkPressureWeight = 0.5,
    this.inkBristleLengthWeight = 0.5,
    this.inkBristleInkAmountWeight = 0.5,
    this.inkDepletionWeight = 0.5,
    this.inkUseSoak = false,
    this.inkDepletionCurve = const <double>[0.0, 1.0],
    required this.screentoneEnabled,
    required this.screentoneSpacing,
    required this.screentoneDotSize,
    required this.screentoneRotation,
    required this.screentoneSoftness,
    required this.screentoneShape,
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
  bool bristleEnabled;
  double bristleDensity;
  double bristleRandom;
  double bristleScale;
  double bristleShear;
  bool bristleThreshold;
  bool bristleConnected;
  bool bristleUsePressure;
  bool bristleAntialias;
  bool bristleUseCompositing;
  double inkAmount;
  double inkDepletion;
  bool inkUseOpacity;
  bool inkDepletionEnabled;
  bool inkUseSaturation;
  bool inkUseWeights;
  double inkPressureWeight;
  double inkBristleLengthWeight;
  double inkBristleInkAmountWeight;
  double inkDepletionWeight;
  bool inkUseSoak;
  List<double> inkDepletionCurve;
  bool screentoneEnabled;
  double screentoneSpacing;
  double screentoneDotSize;
  double screentoneRotation;
  double screentoneSoftness;
  BrushShape screentoneShape;

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
    bool? bristleEnabled,
    double? bristleDensity,
    double? bristleRandom,
    double? bristleScale,
    double? bristleShear,
    bool? bristleThreshold,
    bool? bristleConnected,
    bool? bristleUsePressure,
    bool? bristleAntialias,
    bool? bristleUseCompositing,
    double? inkAmount,
    double? inkDepletion,
    bool? inkUseOpacity,
    bool? inkDepletionEnabled,
    bool? inkUseSaturation,
    bool? inkUseWeights,
    double? inkPressureWeight,
    double? inkBristleLengthWeight,
    double? inkBristleInkAmountWeight,
    double? inkDepletionWeight,
    bool? inkUseSoak,
    List<double>? inkDepletionCurve,
    bool? screentoneEnabled,
    double? screentoneSpacing,
    double? screentoneDotSize,
    double? screentoneRotation,
    double? screentoneSoftness,
    BrushShape? screentoneShape,
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
      bristleEnabled: bristleEnabled ?? this.bristleEnabled,
      bristleDensity: bristleDensity ?? this.bristleDensity,
      bristleRandom: bristleRandom ?? this.bristleRandom,
      bristleScale: bristleScale ?? this.bristleScale,
      bristleShear: bristleShear ?? this.bristleShear,
      bristleThreshold: bristleThreshold ?? this.bristleThreshold,
      bristleConnected: bristleConnected ?? this.bristleConnected,
      bristleUsePressure: bristleUsePressure ?? this.bristleUsePressure,
      bristleAntialias: bristleAntialias ?? this.bristleAntialias,
      bristleUseCompositing: bristleUseCompositing ?? this.bristleUseCompositing,
      inkAmount: inkAmount ?? this.inkAmount,
      inkDepletion: inkDepletion ?? this.inkDepletion,
      inkUseOpacity: inkUseOpacity ?? this.inkUseOpacity,
      inkDepletionEnabled: inkDepletionEnabled ?? this.inkDepletionEnabled,
      inkUseSaturation: inkUseSaturation ?? this.inkUseSaturation,
      inkUseWeights: inkUseWeights ?? this.inkUseWeights,
      inkPressureWeight: inkPressureWeight ?? this.inkPressureWeight,
      inkBristleLengthWeight:
          inkBristleLengthWeight ?? this.inkBristleLengthWeight,
      inkBristleInkAmountWeight:
          inkBristleInkAmountWeight ?? this.inkBristleInkAmountWeight,
      inkDepletionWeight: inkDepletionWeight ?? this.inkDepletionWeight,
      inkUseSoak: inkUseSoak ?? this.inkUseSoak,
      inkDepletionCurve: inkDepletionCurve ?? this.inkDepletionCurve,
      screentoneEnabled: screentoneEnabled ?? this.screentoneEnabled,
      screentoneSpacing: screentoneSpacing ?? this.screentoneSpacing,
      screentoneDotSize: screentoneDotSize ?? this.screentoneDotSize,
      screentoneRotation: screentoneRotation ?? this.screentoneRotation,
      screentoneSoftness: screentoneSoftness ?? this.screentoneSoftness,
      screentoneShape: screentoneShape ?? this.screentoneShape,
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
    final double bristleDensityValue =
        bristleDensity.isFinite ? bristleDensity : 0.0;
    final double bristleRandomValue =
        bristleRandom.isFinite ? bristleRandom : 0.0;
    final double bristleScaleValue =
        bristleScale.isFinite ? bristleScale : 1.0;
    final double bristleShearValue =
        bristleShear.isFinite ? bristleShear : 0.0;
    final double inkAmountValue = inkAmount.isFinite ? inkAmount : 1.0;
    final double inkDepletionValue =
        inkDepletion.isFinite ? inkDepletion : 0.0;
    final double inkPressureWeightValue =
        inkPressureWeight.isFinite ? inkPressureWeight : 0.5;
    final double inkBristleLengthWeightValue =
        inkBristleLengthWeight.isFinite ? inkBristleLengthWeight : 0.5;
    final double inkBristleInkAmountWeightValue =
        inkBristleInkAmountWeight.isFinite ? inkBristleInkAmountWeight : 0.5;
    final double inkDepletionWeightValue =
        inkDepletionWeight.isFinite ? inkDepletionWeight : 0.5;
    final List<double> inkCurveValue = _sanitizeInkCurve(inkDepletionCurve);
    final double screentoneSpacingValue =
        screentoneSpacing.isFinite ? screentoneSpacing : 10.0;
    final double screentoneDotValue =
        screentoneDotSize.isFinite ? screentoneDotSize : 0.6;
    final double screentoneRotationValue =
        screentoneRotation.isFinite ? screentoneRotation : 45.0;
    final double screentoneSoftnessValue =
        screentoneSoftness.isFinite ? screentoneSoftness : 0.0;

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
      bristleDensity: bristleDensityValue.clamp(0.0, 1.0),
      bristleRandom: bristleRandomValue.clamp(0.0, 10.0),
      bristleScale: bristleScaleValue.clamp(0.1, 10.0),
      bristleShear: bristleShearValue.clamp(0.0, 2.0),
      inkAmount: inkAmountValue.clamp(0.0, 1.0),
      inkDepletion: inkDepletionValue.clamp(0.0, 1.0),
      inkPressureWeight: inkPressureWeightValue.clamp(0.0, 100.0),
      inkBristleLengthWeight: inkBristleLengthWeightValue.clamp(0.0, 100.0),
      inkBristleInkAmountWeight:
          inkBristleInkAmountWeightValue.clamp(0.0, 100.0),
      inkDepletionWeight: inkDepletionWeightValue.clamp(0.0, 100.0),
      inkDepletionCurve: inkCurveValue,
      screentoneSpacing: screentoneSpacingValue.clamp(2.0, 200.0),
      screentoneDotSize: screentoneDotValue.clamp(0.0, 1.0),
      screentoneRotation: screentoneRotationValue.clamp(-180.0, 180.0),
      screentoneSoftness: screentoneSoftnessValue.clamp(0.0, 1.0),
      screentoneShape: screentoneShape,
    );
  }

  factory BrushPreset.fromJson(Map<String, dynamic> json) {
    final int shapeIndex = (json['shape'] as num?)?.toInt() ?? 0;
    final String? shapeId = json['shapeId'] as String?;
    final BrushShape? shapeFromId = _shapeEnumFromId(shapeId);
    final int clampedShape = shapeIndex.clamp(0, BrushShape.values.length - 1);
    final BrushShape resolvedShape = shapeFromId ?? BrushShape.values[clampedShape];
    final int screentoneShapeIndex =
        (json['screentoneShape'] as num?)?.toInt() ?? 0;
    final int clampedScreentoneShape =
        screentoneShapeIndex.clamp(0, BrushShape.values.length - 1);
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
      bristleEnabled: (json['bristleEnabled'] as bool?) ?? false,
      bristleDensity: (json['bristleDensity'] as num?)?.toDouble() ?? 0.0,
      bristleRandom: (json['bristleRandom'] as num?)?.toDouble() ?? 0.0,
      bristleScale: (json['bristleScale'] as num?)?.toDouble() ?? 1.0,
      bristleShear: (json['bristleShear'] as num?)?.toDouble() ?? 0.0,
      bristleThreshold: (json['bristleThreshold'] as bool?) ?? false,
      bristleConnected: (json['bristleConnected'] as bool?) ?? false,
      bristleUsePressure: (json['bristleUsePressure'] as bool?) ?? true,
      bristleAntialias: (json['bristleAntialias'] as bool?) ?? false,
      bristleUseCompositing: (json['bristleUseCompositing'] as bool?) ?? true,
      inkAmount: (json['inkAmount'] as num?)?.toDouble() ?? 1.0,
      inkDepletion: (json['inkDepletion'] as num?)?.toDouble() ?? 0.0,
      inkUseOpacity: (json['inkUseOpacity'] as bool?) ?? true,
      inkDepletionEnabled:
          (json['inkDepletionEnabled'] as bool?) ?? false,
      inkUseSaturation: (json['inkUseSaturation'] as bool?) ?? false,
      inkUseWeights: (json['inkUseWeights'] as bool?) ?? false,
      inkPressureWeight:
          (json['inkPressureWeight'] as num?)?.toDouble() ?? 0.5,
      inkBristleLengthWeight:
          (json['inkBristleLengthWeight'] as num?)?.toDouble() ?? 0.5,
      inkBristleInkAmountWeight:
          (json['inkBristleInkAmountWeight'] as num?)?.toDouble() ?? 0.5,
      inkDepletionWeight:
          (json['inkDepletionWeight'] as num?)?.toDouble() ?? 0.5,
      inkUseSoak: (json['inkUseSoak'] as bool?) ?? false,
      inkDepletionCurve: (json['inkDepletionCurve'] as List<dynamic>?)
              ?.map((dynamic e) => (e as num).toDouble())
              .toList(growable: false) ??
          const <double>[0.0, 1.0],
      screentoneEnabled: (json['screentoneEnabled'] as bool?) ?? false,
      screentoneSpacing:
          (json['screentoneSpacing'] as num?)?.toDouble() ?? 10.0,
      screentoneDotSize:
          (json['screentoneDotSize'] as num?)?.toDouble() ?? 0.6,
      screentoneRotation:
          (json['screentoneRotation'] as num?)?.toDouble() ?? 45.0,
      screentoneSoftness:
          (json['screentoneSoftness'] as num?)?.toDouble() ?? 0.0,
      screentoneShape: BrushShape.values[clampedScreentoneShape],
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
        'bristleEnabled': bristleEnabled,
        'bristleDensity': bristleDensity,
        'bristleRandom': bristleRandom,
        'bristleScale': bristleScale,
        'bristleShear': bristleShear,
        'bristleThreshold': bristleThreshold,
        'bristleConnected': bristleConnected,
        'bristleUsePressure': bristleUsePressure,
        'bristleAntialias': bristleAntialias,
        'bristleUseCompositing': bristleUseCompositing,
        'inkAmount': inkAmount,
        'inkDepletion': inkDepletion,
        'inkUseOpacity': inkUseOpacity,
        'inkDepletionEnabled': inkDepletionEnabled,
        'inkUseSaturation': inkUseSaturation,
        'inkUseWeights': inkUseWeights,
        'inkPressureWeight': inkPressureWeight,
        'inkBristleLengthWeight': inkBristleLengthWeight,
        'inkBristleInkAmountWeight': inkBristleInkAmountWeight,
        'inkDepletionWeight': inkDepletionWeight,
        'inkUseSoak': inkUseSoak,
        'inkDepletionCurve': inkDepletionCurve,
        'screentoneEnabled': screentoneEnabled,
        'screentoneSpacing': screentoneSpacing,
        'screentoneDotSize': screentoneDotSize,
        'screentoneRotation': screentoneRotation,
        'screentoneSoftness': screentoneSoftness,
        'screentoneShape': screentoneShape.index,
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
        a.bristleEnabled == b.bristleEnabled &&
        a.bristleDensity == b.bristleDensity &&
        a.bristleRandom == b.bristleRandom &&
        a.bristleScale == b.bristleScale &&
        a.bristleShear == b.bristleShear &&
        a.bristleThreshold == b.bristleThreshold &&
        a.bristleConnected == b.bristleConnected &&
        a.bristleUsePressure == b.bristleUsePressure &&
        a.bristleAntialias == b.bristleAntialias &&
        a.bristleUseCompositing == b.bristleUseCompositing &&
        a.inkAmount == b.inkAmount &&
        a.inkDepletion == b.inkDepletion &&
        a.inkUseOpacity == b.inkUseOpacity &&
        a.inkDepletionEnabled == b.inkDepletionEnabled &&
        a.inkUseSaturation == b.inkUseSaturation &&
        a.inkUseWeights == b.inkUseWeights &&
        a.inkPressureWeight == b.inkPressureWeight &&
        a.inkBristleLengthWeight == b.inkBristleLengthWeight &&
        a.inkBristleInkAmountWeight == b.inkBristleInkAmountWeight &&
        a.inkDepletionWeight == b.inkDepletionWeight &&
        a.inkUseSoak == b.inkUseSoak &&
        listEquals(a.inkDepletionCurve, b.inkDepletionCurve) &&
        a.screentoneEnabled == b.screentoneEnabled &&
        a.screentoneSpacing == b.screentoneSpacing &&
        a.screentoneDotSize == b.screentoneDotSize &&
        a.screentoneRotation == b.screentoneRotation &&
        a.screentoneSoftness == b.screentoneSoftness &&
        a.screentoneShape == b.screentoneShape &&
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

  static List<double> _sanitizeInkCurve(List<double>? curve) {
    if (curve == null || curve.isEmpty) {
      return const <double>[0.0, 1.0];
    }
    final List<double> result = List<double>.generate(
      curve.length,
      (int index) {
        final double value = curve[index];
        if (!value.isFinite) {
          return 0.0;
        }
        return value.clamp(0.0, 1.0);
      },
      growable: false,
    );
    if (result.isEmpty) {
      return const <double>[0.0, 1.0];
    }
    return result;
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
