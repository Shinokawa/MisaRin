import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:misa_rin/minecraft/bedrock_animation.dart';
import 'package:misa_rin/minecraft/bedrock_model.dart';

void main() {
  test('samplePose maps bone names case-insensitively', () {
    final String geometryText =
        File('assets/bedrock_models/armor_steve.json').readAsStringSync();
    final BedrockGeometryModel? model =
        BedrockGeometryModel.tryParseFromJsonText(geometryText);
    expect(model, isNotNull);

    final String animationText =
        File('assets/bedrock_models/dfsteve_armor.animation.json')
            .readAsStringSync();
    final BedrockAnimationLibrary? library =
        BedrockAnimationLibrary.tryParseFromJsonText(animationText);
    expect(library, isNotNull);

    final BedrockAnimation? move =
        library!.animations['animation.dfsteve_armor.move'];
    expect(move, isNotNull);

    final Map<String, BedrockBonePose> pose =
        move!.samplePose(model!, timeSeconds: 0);
    expect(pose.containsKey('leftArm'), isTrue);
    expect(pose.containsKey('rightArm'), isTrue);
    expect(pose.containsKey('leftLeg'), isTrue);
    expect(pose.containsKey('rightLeg'), isTrue);
  });

  test('animation isDynamic matches time-varying data', () {
    final String animationText =
        File('assets/bedrock_models/dfsteve_armor.animation.json')
            .readAsStringSync();
    final BedrockAnimationLibrary? library =
        BedrockAnimationLibrary.tryParseFromJsonText(animationText);
    expect(library, isNotNull);

    expect(
      library!.animations['animation.dfsteve_armor.default_pose']!.isDynamic,
      isFalse,
    );
    expect(library.animations['animation.armor.shoot']!.isDynamic, isTrue);
  });
}
