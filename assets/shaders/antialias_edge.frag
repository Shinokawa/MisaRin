#version 320 es
precision mediump float;
#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;

const float kEdgeMin = 0.015;
const float kEdgeMax = 0.4;
const float kEdgeStrength = 1.0;
const float kEdgeGamma = 0.55;

const vec2 kNeighborOffsets[8] = vec2[8](
  vec2(-1.0, -1.0),
  vec2(0.0, -1.0),
  vec2(1.0, -1.0),
  vec2(-1.0, 0.0),
  vec2(1.0, 0.0),
  vec2(-1.0, 1.0),
  vec2(0.0, 1.0),
  vec2(1.0, 1.0)
);

const float kGaussian5x5[25] = float[25](
  1.0, 4.0, 6.0, 4.0, 1.0,
  4.0, 16.0, 24.0, 16.0, 4.0,
  6.0, 24.0, 36.0, 24.0, 6.0,
  4.0, 16.0, 24.0, 16.0, 4.0,
  1.0, 4.0, 6.0, 4.0, 1.0
);

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
    vec2 nCoord = _clampedCoord(coord + kNeighborOffsets[i]);
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
    for (int kx = -2; kx <= 2; kx++, kernelIndex++) {
      float k = kGaussian5x5[kernelIndex];
      vec2 sampleCoord = _clampedCoord(coord + vec2(float(kx), float(ky)));
      vec4 s = texture(uTexture, sampleCoord / uResolution);
      if (s.a == 0.0) {
        continue;
      }
      totalWeight += k;
      weightedAlpha += s.a * k;
      weightedPremul += s.rgb * s.a * k;
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
