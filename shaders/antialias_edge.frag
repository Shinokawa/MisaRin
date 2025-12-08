#version 320 es
precision mediump float;
#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;

const float kEdgeMin = 0.015;
const float kEdgeMax = 0.4;
const float kEdgeStrength = 1.0;
const float kEdgeGamma = 0.55;

vec2 _neighborOffset(int i) {
  if (i == 0) return vec2(-1.0, -1.0);
  if (i == 1) return vec2(0.0, -1.0);
  if (i == 2) return vec2(1.0, -1.0);
  if (i == 3) return vec2(-1.0, 0.0);
  if (i == 4) return vec2(1.0, 0.0);
  if (i == 5) return vec2(-1.0, 1.0);
  if (i == 6) return vec2(0.0, 1.0);
  return vec2(1.0, 1.0);
}

float _gaussianWeight(int idx) {
  if (idx == 0) return 1.0;
  if (idx == 1) return 4.0;
  if (idx == 2) return 6.0;
  if (idx == 3) return 4.0;
  if (idx == 4) return 1.0;
  if (idx == 5) return 4.0;
  if (idx == 6) return 16.0;
  if (idx == 7) return 24.0;
  if (idx == 8) return 16.0;
  if (idx == 9) return 4.0;
  if (idx == 10) return 6.0;
  if (idx == 11) return 24.0;
  if (idx == 12) return 36.0;
  if (idx == 13) return 24.0;
  if (idx == 14) return 6.0;
  if (idx == 15) return 4.0;
  if (idx == 16) return 16.0;
  if (idx == 17) return 24.0;
  if (idx == 18) return 16.0;
  if (idx == 19) return 4.0;
  if (idx == 20) return 1.0;
  if (idx == 21) return 4.0;
  if (idx == 22) return 6.0;
  if (idx == 23) return 4.0;
  return 1.0;
}

out vec4 fragColor;

vec2 _clampedCoord(vec2 coord) {
  return clamp(coord, vec2(0.5, 0.5), uResolution - vec2(0.5, 0.5));
}

float _luma(vec3 rgb) {
  return dot(rgb, vec3(0.2126, 0.7152, 0.0722));
}

void main() {
  vec2 coord = FlutterFragCoord().xy;
  vec2 uv = coord / uResolution;

  vec4 base = texture(uTexture, uv);
  if (base.a == 0.0) {
    fragColor = base;
    return;
  }

  float centerLuma = _luma(base.rgb);
  float maxDiff = 0.0;
  for (int i = 0; i < 8; i++) {
    vec2 nCoord = _clampedCoord(coord + _neighborOffset(i));
    vec4 n = texture(uTexture, nCoord / uResolution);
    if (n.a == 0.0) {
      continue;
    }
    float diff = abs(centerLuma - _luma(n.rgb));
    maxDiff = max(maxDiff, diff);
  }

  float weight = 0.0;
  if (maxDiff > kEdgeMin) {
    float normalized = clamp(
      (maxDiff - kEdgeMin) / (kEdgeMax - kEdgeMin),
      0.0,
      1.0
    );
    weight = pow(normalized, kEdgeGamma) * kEdgeStrength;
  }

  float weightedAlpha = 0.0;
  vec3 weightedPremul = vec3(0.0);
  float totalWeight = 0.0;
  int kernelIndex = 0;
  for (int ky = -2; ky <= 2; ky++) {
    for (int kx = -2; kx <= 2; kx++) {
      float k = _gaussianWeight(kernelIndex);
      vec2 sampleCoord = _clampedCoord(coord + vec2(float(kx), float(ky)));
      vec4 s = texture(uTexture, sampleCoord / uResolution);
      if (s.a == 0.0) {
        continue;
      }
      totalWeight += k;
      weightedAlpha += s.a * k;
      weightedPremul += s.rgb * s.a * k;
      kernelIndex++;
    }
  }

  if (totalWeight == 0.0) {
    fragColor = base;
    return;
  }

  float outAlpha = clamp(weightedAlpha / totalWeight, 0.0, 1.0);
  vec3 blurColor = weightedPremul / max(weightedAlpha, 1e-4);
  vec4 blurred = vec4(blurColor, outAlpha);

  fragColor = mix(base, blurred, weight);
}
