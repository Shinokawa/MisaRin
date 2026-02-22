#version 320 es
precision highp float;
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform float uSeed;
uniform float uCameraYaw;
uniform float uCameraPitch;
uniform float uCameraZoom;
uniform vec3 uSunDir;
uniform vec3 uSunColor;
uniform vec3 uZenithColor;
uniform vec3 uHorizonColor;
uniform vec3 uCloudColor;
uniform float uCloudHeight;
uniform float uTileWorldSize;
uniform float uBlockTexelSize;
uniform float uCloudOpacity;
uniform float uShadowStrength;

out vec4 fragColor;

const float PI = 3.1415926535897932384626433832795;
const float TAU = 6.2831853071795864769252867665590;

vec3 _rotateY(vec3 v, float a) {
  float s = sin(a);
  float c = cos(a);
  return vec3(c * v.x + s * v.z, v.y, -s * v.x + c * v.z);
}

vec3 _rotateX(vec3 v, float a) {
  float s = sin(a);
  float c = cos(a);
  return vec3(v.x, c * v.y - s * v.z, s * v.y + c * v.z);
}

float _hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float _hash13(vec3 p3) {
  p3 = fract(p3 * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float _noise2(vec2 x) {
  vec2 i = floor(x);
  vec2 f = fract(x);
  f = f * f * (3.0 - 2.0 * f);

  float a = _hash12(i + vec2(0.0, 0.0));
  float b = _hash12(i + vec2(1.0, 0.0));
  float c = _hash12(i + vec2(0.0, 1.0));
  float d = _hash12(i + vec2(1.0, 1.0));

  float u = mix(a, b, f.x);
  float v = mix(c, d, f.x);
  return mix(u, v, f.y);
}

float _noise3(vec3 x) {
  vec3 i = floor(x);
  vec3 f = fract(x);
  f = f * f * (3.0 - 2.0 * f);

  float n000 = _hash13(i + vec3(0.0, 0.0, 0.0));
  float n100 = _hash13(i + vec3(1.0, 0.0, 0.0));
  float n010 = _hash13(i + vec3(0.0, 1.0, 0.0));
  float n110 = _hash13(i + vec3(1.0, 1.0, 0.0));
  float n001 = _hash13(i + vec3(0.0, 0.0, 1.0));
  float n101 = _hash13(i + vec3(1.0, 0.0, 1.0));
  float n011 = _hash13(i + vec3(0.0, 1.0, 1.0));
  float n111 = _hash13(i + vec3(1.0, 1.0, 1.0));

  float n00 = mix(n000, n100, f.x);
  float n10 = mix(n010, n110, f.x);
  float n01 = mix(n001, n101, f.x);
  float n11 = mix(n011, n111, f.x);

  float n0 = mix(n00, n10, f.y);
  float n1 = mix(n01, n11, f.y);
  return mix(n0, n1, f.z);
}

float _fbm2(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 3; i++) {
    v += a * _noise2(p);
    p = p * 2.02 + vec2(17.0, 19.0);
    a *= 0.5;
  }
  return v;
}

float _hg(float cosTheta, float g) {
  float g2 = g * g;
  float denom = 1.0 + g2 - 2.0 * g * cosTheta;
  return (1.0 - g2) / pow(max(denom, 1e-4), 1.5);
}

float _saturate(float v) { return clamp(v, 0.0, 1.0); }

float _hash11(float n) {
  return fract(sin(n) * 43758.5453);
}

float _fbm3(vec3 p) {
  mat3 m = mat3(
    0.00, 0.80, 0.60,
    -0.80, 0.36, -0.48,
    -0.60, -0.48, 0.64
  );
  float f = 0.0;
  f += 0.5000 * _noise3(p);
  p = m * p * 2.02;
  f += 0.2500 * _noise3(p);
  p = m * p * 2.03;
  f += 0.1250 * _noise3(p);
  return f;
}

float _clouds(vec3 p, out float cloudHeight, bool fast) {
  float cloudBase = max(0.0, uCloudHeight);
  float cloudThickness = max(12.0, uBlockTexelSize);
  float atmoHeight = p.y;
  cloudHeight = _saturate((atmoHeight - cloudBase) / max(1e-3, cloudThickness));
  if (cloudHeight <= 0.0 || cloudHeight >= 1.0) {
    return 0.0;
  }

  float worldScale = max(uTileWorldSize, 1.0) / 16.0;
  vec3 wp = p * worldScale;
  wp += vec3(uSeed * 0.27, uSeed * 0.19, uSeed * 0.23);

  wp.z += uTime * 10.3;
  float largeWeather = clamp((_noise2(-0.00005 * wp.zx) - 0.18) * 5.0, 0.0, 2.0);
  wp.x += uTime * 8.3;
  float weather = largeWeather *
      max(0.0, _noise2(0.0002 * wp.zx) - 0.28) / 0.72;
  weather *= smoothstep(0.0, 0.5, cloudHeight) * smoothstep(1.0, 0.5, cloudHeight);
  float cloudShape =
      pow(weather, 0.3 + 1.5 * smoothstep(0.2, 0.5, cloudHeight));
  if (cloudShape <= 0.0) {
    return 0.0;
  }

  wp.x += uTime * 12.3;
  float den = max(0.0, cloudShape - 0.7 * _fbm3(wp * 0.01));
  if (den <= 0.0) {
    return 0.0;
  }

  if (fast) {
    return largeWeather * 0.2 * min(1.0, 5.0 * den);
  }

  wp.y += uTime * 15.2;
  den = max(0.0, den - 0.2 * _fbm3(wp * 0.05));
  return largeWeather * 0.2 * min(1.0, 5.0 * den);
}

float _numericalMieFit(float costh) {
  float bestParams[10];
  bestParams[0] = 9.805233e-06;
  bestParams[1] = -6.500000e+01;
  bestParams[2] = -5.500000e+01;
  bestParams[3] = 8.194068e-01;
  bestParams[4] = 1.388198e-01;
  bestParams[5] = -8.370334e+01;
  bestParams[6] = 7.810083e+00;
  bestParams[7] = 2.054747e-03;
  bestParams[8] = 2.600563e-02;
  bestParams[9] = -4.552125e-12;

  float p1 = costh + bestParams[3];
  vec4 expValues = exp(vec4(
    bestParams[1] * costh + bestParams[2],
    bestParams[5] * p1 * p1,
    bestParams[6] * costh,
    bestParams[9] * costh
  ));
  vec4 expValWeight = vec4(
    bestParams[0],
    bestParams[4],
    bestParams[7],
    bestParams[8]
  );
  return dot(expValues, expValWeight);
}

float _lightRay(
  vec3 p,
  float phaseFunction,
  float dC,
  float mu,
  vec3 sunDirection,
  float cloudHeight,
  float cloudThickness,
  bool fast
) {
  int nbSampleLight = fast ? 7 : 16;
  float zMaxl = max(24.0, cloudThickness * 2.5);
  float stepL = zMaxl / float(nbSampleLight);

  float lightRayDen = 0.0;
  p += sunDirection * stepL * _hash11(dot(p, vec3(12.256, 2.646, 6.356)) + uTime);
  for (int j = 0; j < 20; j++) {
    if (j >= nbSampleLight) {
      break;
    }
    float ch;
    lightRayDen += _clouds(p + sunDirection * float(j) * stepL, ch, fast);
  }

  if (fast) {
    float result =
        (0.5 * exp(-0.4 * stepL * lightRayDen) +
            max(0.0, -mu * 0.6 + 0.3) * exp(-0.02 * stepL * lightRayDen)) *
        phaseFunction;
    return _saturate(result);
  }

  float scatterAmount = mix(0.008, 1.0, smoothstep(0.96, 0.0, mu));
  float beersLaw =
      exp(-stepL * lightRayDen) +
      0.5 * scatterAmount * exp(-0.1 * stepL * lightRayDen) +
      scatterAmount * 0.4 * exp(-0.02 * stepL * lightRayDen);
  float heightBoost = 0.3 + 5.5 * cloudHeight;
  float densBoost = pow(min(1.0, dC * 8.5), heightBoost);
  float result = beersLaw * phaseFunction *
      mix(0.05 + 1.5 * densBoost, 1.0, clamp(lightRayDen * 0.4, 0.0, 1.0));
  return _saturate(result);
}

void main() {
  vec2 coord = FlutterFragCoord().xy;
  vec2 uv = coord / uResolution;

  float normalizedTime = mod(uTime, 24.0);
  if (normalizedTime < 0.0) {
    normalizedTime += 24.0;
  }
  float dayPhase = ((normalizedTime - 6.0) / 12.0) * PI;
  float sunHeight = clamp(sin(dayPhase), -1.0, 1.0);
  float dayBlend = smoothstep(-0.35, 0.15, sunHeight);
  float nightBlend = 1.0 - dayBlend;

  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 p = vec2((uv.x - 0.5) * 2.0 * aspect, (0.5 - uv.y) * 2.0);
  float zoom = clamp(uCameraZoom, 0.8, 2.5);
  float fov = 1.1 / zoom;
  vec3 rayDir = normalize(vec3(p.x, p.y, fov));
  rayDir = _rotateX(rayDir, -uCameraPitch);
  rayDir = _rotateY(rayDir, -uCameraYaw);

  vec3 sunDir = normalize(uSunDir);
  float skyT = clamp(1.0 - rayDir.y, 0.0, 1.0);
  vec3 sky = mix(uZenithColor, uHorizonColor, skyT);

  // Stars + sun/moon: all composited behind clouds.
  float starsStrength = pow(_saturate(nightBlend), 1.8);
  starsStrength *= smoothstep(0.02, 0.38, rayDir.y);
  if (starsStrength > 0.001) {
    vec2 skyUv = vec2(
      atan(rayDir.x, rayDir.z) / TAU + 0.5,
      asin(clamp(rayDir.y, -1.0, 1.0)) / PI + 0.5
    );
    vec2 starCoord = skyUv * vec2(520.0, 260.0);
    vec2 baseCell = floor(starCoord);

    vec3 stars = vec3(0.0);
    for (int oy = -1; oy <= 1; oy++) {
      for (int ox = -1; ox <= 1; ox++) {
        vec2 cell = baseCell + vec2(float(ox), float(oy));
        float rnd = _hash12(cell + uSeed * 0.031 + 12.34);
        if (rnd > 0.985) {
          vec2 jitter = vec2(
            _hash12(cell + vec2(3.1, 5.7)),
            _hash12(cell + vec2(7.3, 1.9))
          );
          vec2 starPos = cell + jitter;
          vec2 d = starCoord - starPos;
          float dist2 = dot(d, d);

          float size = mix(0.03, 0.11, _hash12(cell + vec2(2.2, 9.4)));
          float size2 = max(1e-4, size * size);
          float core = smoothstep(size2, 0.0, dist2);
          float sparkle = smoothstep(0.985, 0.9995, rnd);
          float twinkle = 0.75 + 0.25 * sin((uTime * 0.18 + rnd * 17.0) * TAU);
          float intensity = core * sparkle * twinkle;

          vec3 starColor = mix(
            vec3(0.65, 0.72, 1.0),
            vec3(1.0),
            _hash12(cell + vec2(5.9, 2.6))
          );
          stars += starColor * intensity;
        }
      }
    }
    sky += stars * starsStrength * 0.95;
  }

  float azimuth = normalizedTime / 24.0 * TAU;
  vec3 sunDiscDir = normalize(vec3(cos(azimuth), sunHeight, -sin(azimuth)));
  vec3 moonDiscDir = normalize(vec3(cos(azimuth + PI), -sunHeight, -sin(azimuth + PI)));

  float sunDot = clamp(dot(rayDir, sunDiscDir), -1.0, 1.0);
  float moonDot = clamp(dot(rayDir, moonDiscDir), -1.0, 1.0);

  float sunCore = smoothstep(cos(0.040), 1.0, sunDot);
  float sunGlow = pow(smoothstep(cos(0.130), 1.0, sunDot), 2.4);
  float sunVis = smoothstep(-0.12, 0.05, sunHeight) * dayBlend;
  vec3 sunCol = mix(vec3(1.0, 0.66, 0.34), uSunColor, 0.65);
  sky += sunCol * sunVis * (sunGlow * 0.45 + sunCore * 1.35);

  float moonCore = smoothstep(cos(0.034), 1.0, moonDot);
  float moonGlow = pow(smoothstep(cos(0.090), 1.0, moonDot), 2.0);
  float moonVis = smoothstep(-0.10, 0.06, -sunHeight) * nightBlend;
  vec3 moonCol = mix(vec3(0.55, 0.62, 0.85), uSunColor, 0.85);
  sky += moonCol * moonVis * (moonGlow * 0.22 + moonCore * 0.62);

  if (rayDir.y <= 0.001) {
    fragColor = vec4(sky, 1.0);
    return;
  }

  float cloudBase = uCloudHeight;
  float thickness = max(6.0, uBlockTexelSize);
  float cloudTop = cloudBase + thickness;

  float t0 = cloudBase / rayDir.y;
  float t1 = cloudTop / rayDir.y;
  if (t1 <= 0.0) {
    fragColor = vec4(sky, 1.0);
    return;
  }
  t0 = max(t0, 0.0);
  float maxMarch = thickness * 7.0;
  t1 = min(t1, t0 + maxMarch);
  if (t1 <= t0) {
    fragColor = vec4(sky, 1.0);
    return;
  }

  float shadowStrength = clamp(uShadowStrength, 0.0, 1.0);
  float densityScale = mix(0.18, 0.88, clamp(uCloudOpacity, 0.0, 1.0));
  densityScale *= smoothstep(0.05, 0.28, rayDir.y);

  const int STEPS = 24;
  float dt = (t1 - t0) / float(STEPS);
  float jitter = _hash13(vec3(coord, uSeed)) - 0.5;
  float t = t0 + jitter * dt;

  float trans = 1.0;
  vec3 accum = vec3(0.0);

  float absorption = 0.48;
  float scatterScale = 1.75;
  float mu = clamp(dot(rayDir, sunDir), -1.0, 1.0);
  float phase = _hg(mu, 0.70);
  float phaseForward = _hg(mu, 0.90) * 0.18;
  float miePhase = clamp(_numericalMieFit(mu) * 0.12, 0.0, 1.0);
  bool fast = (uResolution.x * uResolution.y) > 900000.0;

  for (int i = 0; i < STEPS; i++) {
    vec3 pos = rayDir * (t + float(i) * dt);
    float cloudHeight = 0.0;
    float d = _clouds(pos, cloudHeight, fast) * densityScale;
    if (d > 0.001) {
      float lightT = 1.0;
      if (shadowStrength > 0.001) {
        lightT = _lightRay(
          pos,
          miePhase,
          d,
          mu,
          sunDir,
          cloudHeight,
          thickness,
          fast
        );
        lightT = mix(1.0, lightT, shadowStrength);
      }

      vec3 ambientTint = mix(sky, vec3(1.0), 0.28);
      vec3 ambient = ambientTint * (0.34 + 0.62 * (1.0 - skyT));
      vec3 sunLit = uSunColor * (0.62 * phase + phaseForward) * lightT;
      vec3 lighting = ambient + sunLit;
      lighting = max(lighting, ambientTint * 0.25 + vec3(0.04));

      float stepExt = d * dt * absorption;
      float atten = exp(-stepExt);
      float scatterAmt = (1.0 - atten);

      vec3 albedo = mix(vec3(1.0), uCloudColor, 0.18);
      float powder = 1.0 - exp(-d * 2.4);
      vec3 col = albedo * lighting * (0.88 + 0.70 * powder);
      col += albedo * uSunColor * (0.06 + 0.04 * powder) * (1.0 - lightT);

      accum += trans * scatterAmt * col * scatterScale;
      trans *= atten;
      if (trans < 0.012) {
        break;
      }
    }
  }

  vec3 outColor = sky * trans + accum;
  fragColor = vec4(clamp(outColor, 0.0, 1.0), 1.0);
}
