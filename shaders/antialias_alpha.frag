#version 320 es
precision mediump float;
#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform float uBlend;

const float kCenterWeight = 4.0;

vec2 _offset(int i) {
  if (i == 0) return vec2(-1.0, -1.0);
  if (i == 1) return vec2(0.0, -1.0);
  if (i == 2) return vec2(1.0, -1.0);
  if (i == 3) return vec2(-1.0, 0.0);
  if (i == 4) return vec2(1.0, 0.0);
  if (i == 5) return vec2(-1.0, 1.0);
  if (i == 6) return vec2(0.0, 1.0);
  return vec2(1.0, 1.0);
}

float _weight(int i) {
  if (i == 0) return 1.0;
  if (i == 1) return 2.0;
  if (i == 2) return 1.0;
  if (i == 3) return 2.0;
  if (i == 4) return 2.0;
  if (i == 5) return 1.0;
  if (i == 6) return 2.0;
  return 1.0;
}

out vec4 fragColor;

vec2 _clampedCoord(vec2 coord) {
  // Clamp to the center of border pixels to avoid sampling outside.
  return clamp(coord, vec2(0.5, 0.5), uResolution - vec2(0.5, 0.5));
}

void main() {
  vec2 coord = FlutterFragCoord().xy;
  vec2 uv = coord / uResolution;

  vec4 center = texture(uTexture, uv);
  float alpha = center.a;

  float totalWeight = kCenterWeight;
  float weightedAlpha = alpha * kCenterWeight;
  vec3 weightedPremul = center.rgb * alpha * kCenterWeight;

  for (int i = 0; i < 8; i++) {
    vec2 sampleCoord = _clampedCoord(coord + _offset(i));
    vec4 neighbor = texture(uTexture, sampleCoord / uResolution);
    float w = _weight(i);
    totalWeight += w;
    if (neighbor.a == 0.0) {
      continue;
    }
    weightedAlpha += neighbor.a * w;
    weightedPremul += neighbor.rgb * neighbor.a * w;
  }

  if (totalWeight <= 0.0) {
    fragColor = center;
    return;
  }

  float candidateAlpha = clamp(weightedAlpha / totalWeight, 0.0, 1.0);
  float newAlpha = clamp(mix(alpha, candidateAlpha, uBlend), 0.0, 1.0);
  if (abs(newAlpha - alpha) < 1e-5) {
    fragColor = center;
    return;
  }

  vec3 newColor = center.rgb;
  if (candidateAlpha > alpha) {
    float denom = max(weightedAlpha, 1e-4);
    newColor = weightedPremul / denom;
  }

  fragColor = vec4(newColor, newAlpha);
}
