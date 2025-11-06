import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show HSLColor;

import 'canvas_layer.dart';

class CanvasBlendMath {
  static const double _epsilon = 1e-7;

  static int blend(
    int dst,
    int src,
    CanvasLayerBlendMode mode, {
    int pixelIndex = 0,
  }) {
    final int srcA = (src >> 24) & 0xff;
    if (srcA == 0) {
      return dst;
    }

    switch (mode) {
      case CanvasLayerBlendMode.dissolve:
        return _blendDissolve(dst, src, pixelIndex);
      default:
        break;
    }

    final int dstA = (dst >> 24) & 0xff;
    final double sa = srcA / 255.0;
    final double da = dstA / 255.0;

    final double sr = ((src >> 16) & 0xff) / 255.0;
    final double sg = ((src >> 8) & 0xff) / 255.0;
    final double sb = (src & 0xff) / 255.0;

    final double dr = ((dst >> 16) & 0xff) / 255.0;
    final double dg = ((dst >> 8) & 0xff) / 255.0;
    final double db = (dst & 0xff) / 255.0;

    double fr = sr;
    double fg = sg;
    double fb = sb;

    switch (mode) {
      case CanvasLayerBlendMode.normal:
        break;
      case CanvasLayerBlendMode.darken:
        fr = math.min(sr, dr);
        fg = math.min(sg, dg);
        fb = math.min(sb, db);
        break;
      case CanvasLayerBlendMode.multiply:
        fr = sr * dr;
        fg = sg * dg;
        fb = sb * db;
        break;
      case CanvasLayerBlendMode.colorBurn:
        fr = _colorBurn(sr, dr);
        fg = _colorBurn(sg, dg);
        fb = _colorBurn(sb, db);
        break;
      case CanvasLayerBlendMode.linearBurn:
        fr = _clamp01(dr + sr - 1);
        fg = _clamp01(dg + sg - 1);
        fb = _clamp01(db + sb - 1);
        break;
      case CanvasLayerBlendMode.darkerColor:
        final double srcSum = (sr + sg + sb) * sa;
        final double dstSum = (dr + dg + db) * da;
        if (srcSum < dstSum) {
          fr = sr;
          fg = sg;
          fb = sb;
        } else {
          fr = dr;
          fg = dg;
          fb = db;
        }
        break;
      case CanvasLayerBlendMode.lighten:
        fr = math.max(sr, dr);
        fg = math.max(sg, dg);
        fb = math.max(sb, db);
        break;
      case CanvasLayerBlendMode.screen:
        fr = 1 - (1 - sr) * (1 - dr);
        fg = 1 - (1 - sg) * (1 - dg);
        fb = 1 - (1 - sb) * (1 - db);
        break;
      case CanvasLayerBlendMode.colorDodge:
        fr = _colorDodge(sr, dr);
        fg = _colorDodge(sg, dg);
        fb = _colorDodge(sb, db);
        break;
      case CanvasLayerBlendMode.linearDodge:
        fr = _clamp01(dr + sr);
        fg = _clamp01(dg + sg);
        fb = _clamp01(db + sb);
        break;
      case CanvasLayerBlendMode.lighterColor:
        final double srcSum = (sr + sg + sb) * sa;
        final double dstSum = (dr + dg + db) * da;
        if (srcSum > dstSum) {
          fr = sr;
          fg = sg;
          fb = sb;
        } else {
          fr = dr;
          fg = dg;
          fb = db;
        }
        break;
      case CanvasLayerBlendMode.overlay:
        fr = _overlay(sr, dr);
        fg = _overlay(sg, dg);
        fb = _overlay(sb, db);
        break;
      case CanvasLayerBlendMode.softLight:
        fr = _softLight(sr, dr);
        fg = _softLight(sg, dg);
        fb = _softLight(sb, db);
        break;
      case CanvasLayerBlendMode.hardLight:
        fr = _hardLight(sr, dr);
        fg = _hardLight(sg, dg);
        fb = _hardLight(sb, db);
        break;
      case CanvasLayerBlendMode.vividLight:
        fr = _vividLight(sr, dr);
        fg = _vividLight(sg, dg);
        fb = _vividLight(sb, db);
        break;
      case CanvasLayerBlendMode.linearLight:
        fr = _clamp01(dr + 2 * sr - 1);
        fg = _clamp01(dg + 2 * sg - 1);
        fb = _clamp01(db + 2 * sb - 1);
        break;
      case CanvasLayerBlendMode.pinLight:
        fr = _pinLight(sr, dr);
        fg = _pinLight(sg, dg);
        fb = _pinLight(sb, db);
        break;
      case CanvasLayerBlendMode.hardMix:
        fr = _hardMix(sr, dr);
        fg = _hardMix(sg, dg);
        fb = _hardMix(sb, db);
        break;
      case CanvasLayerBlendMode.difference:
        fr = (dr - sr).abs();
        fg = (dg - sg).abs();
        fb = (db - sb).abs();
        break;
      case CanvasLayerBlendMode.exclusion:
        fr = dr + sr - 2 * dr * sr;
        fg = dg + sg - 2 * dg * sg;
        fb = db + sb - 2 * db * sb;
        break;
      case CanvasLayerBlendMode.subtract:
        fr = math.max(0, dr - sr);
        fg = math.max(0, dg - sg);
        fb = math.max(0, db - sb);
        break;
      case CanvasLayerBlendMode.divide:
        fr = _divide(dr, sr);
        fg = _divide(dg, sg);
        fb = _divide(db, sb);
        break;
      case CanvasLayerBlendMode.hue:
      case CanvasLayerBlendMode.saturation:
      case CanvasLayerBlendMode.color:
      case CanvasLayerBlendMode.luminosity:
        final _ColorComponents composite = _blendHslModes(
          sr,
          sg,
          sb,
          dr,
          dg,
          db,
          mode,
        );
        fr = composite.r;
        fg = composite.g;
        fb = composite.b;
        break;
      case CanvasLayerBlendMode.dissolve:
        // Handled earlier by dedicated code path.
        break;
    }

    final double outA = sa + da * (1 - sa);
    if (outA <= 0) {
      return 0;
    }

    final double rr = ((fr * sa) + dr * da * (1 - sa)) / outA;
    final double rg = ((fg * sa) + dg * da * (1 - sa)) / outA;
    final double rb = ((fb * sa) + db * da * (1 - sa)) / outA;

    final int outAlpha = _toByte(outA);
    final int outR = _toByte(rr);
    final int outG = _toByte(rg);
    final int outB = _toByte(rb);

    return (outAlpha << 24) | (outR << 16) | (outG << 8) | outB;
  }

  static int _blendDissolve(int dst, int src, int pixelIndex) {
    final int srcA = (src >> 24) & 0xff;
    if (srcA == 0) {
      return dst;
    }

    final double sa = srcA / 255.0;
    final double noise = _pseudoRandom(pixelIndex, src, dst);
    if (noise > sa) {
      return dst;
    }

    final int dstA = (dst >> 24) & 0xff;
    final double effectiveAlpha = 1.0;
    final double da = dstA / 255.0;

    final double sr = ((src >> 16) & 0xff) / 255.0;
    final double sg = ((src >> 8) & 0xff) / 255.0;
    final double sb = (src & 0xff) / 255.0;

    final double dr = ((dst >> 16) & 0xff) / 255.0;
    final double dg = ((dst >> 8) & 0xff) / 255.0;
    final double db = (dst & 0xff) / 255.0;

    final double outA = effectiveAlpha + da * (1 - effectiveAlpha);
    if (outA <= 0) {
      return 0;
    }

    final double rr =
        ((sr * effectiveAlpha) + dr * da * (1 - effectiveAlpha)) / outA;
    final double rg =
        ((sg * effectiveAlpha) + dg * da * (1 - effectiveAlpha)) / outA;
    final double rb =
        ((sb * effectiveAlpha) + db * da * (1 - effectiveAlpha)) / outA;

    final int outAlpha = _toByte(outA);
    final int outR = _toByte(rr);
    final int outG = _toByte(rg);
    final int outB = _toByte(rb);

    return (outAlpha << 24) | (outR << 16) | (outG << 8) | outB;
  }

  static int _toByte(double value) {
    return (_clamp01(value) * 255.0).round().clamp(0, 255);
  }

  static double _clamp01(double value) {
    if (value <= 0) {
      return 0;
    }
    if (value >= 1) {
      return 1;
    }
    return value;
  }

  static double _colorBurn(double s, double d) {
    if (s <= _epsilon) {
      return 0;
    }
    return 1 - math.min(1, (1 - d) / s);
  }

  static double _colorDodge(double s, double d) {
    if (s >= 1 - _epsilon) {
      return 1;
    }
    return math.min(1, d / (1 - s));
  }

  static double _overlay(double s, double d) {
    if (d <= 0.5) {
      return 2 * s * d;
    }
    return 1 - 2 * (1 - s) * (1 - d);
  }

  static double _hardLight(double s, double d) {
    if (s <= 0.5) {
      return 2 * s * d;
    }
    return 1 - 2 * (1 - s) * (1 - d);
  }

  static double _softLight(double s, double d) {
    if (s <= 0.5) {
      return d - (1 - 2 * s) * d * (1 - d);
    }
    return d + (2 * s - 1) * (_softLightLum(d) - d);
  }

  static double _softLightLum(double d) {
    if (d <= 0.25) {
      return ((16 * d - 12) * d + 4) * d;
    }
    return math.sqrt(d);
  }

  static double _vividLight(double s, double d) {
    if (s <= 0.5) {
      if (s <= _epsilon) {
        return 0;
      }
      return 1 - math.min(1, (1 - d) / (2 * s));
    }
    if (s >= 1 - _epsilon) {
      return 1;
    }
    return math.min(1, d / (2 * (1 - s)));
  }

  static double _pinLight(double s, double d) {
    if (s <= 0.5) {
      return math.min(d, 2 * s);
    }
    return math.max(d, 2 * s - 1);
  }

  static double _hardMix(double s, double d) {
    final double vivid = _vividLight(s, d);
    return vivid < 0.5 ? 0 : 1;
  }

  static double _divide(double d, double s) {
    if (s <= _epsilon) {
      return 1;
    }
    return _clamp01(d / s);
  }

  static _ColorComponents _blendHslModes(
    double sr,
    double sg,
    double sb,
    double dr,
    double dg,
    double db,
    CanvasLayerBlendMode mode,
  ) {
    final Color srcColor = Color.fromARGB(
      0xFF,
      (sr * 255).round().clamp(0, 255),
      (sg * 255).round().clamp(0, 255),
      (sb * 255).round().clamp(0, 255),
    );
    final Color dstColor = Color.fromARGB(
      0xFF,
      (dr * 255).round().clamp(0, 255),
      (dg * 255).round().clamp(0, 255),
      (db * 255).round().clamp(0, 255),
    );

    final HSLColor srcHsl = HSLColor.fromColor(srcColor);
    final HSLColor dstHsl = HSLColor.fromColor(dstColor);

    HSLColor result;
    switch (mode) {
      case CanvasLayerBlendMode.hue:
        result = dstHsl.withHue(srcHsl.hue);
        break;
      case CanvasLayerBlendMode.saturation:
        result = dstHsl.withSaturation(srcHsl.saturation);
        break;
      case CanvasLayerBlendMode.color:
        result = dstHsl.withHue(srcHsl.hue).withSaturation(srcHsl.saturation);
        break;
      case CanvasLayerBlendMode.luminosity:
        result = dstHsl.withLightness(srcHsl.lightness);
        break;
      default:
        result = dstHsl;
        break;
    }

    final Color rgba = result.toColor();
    return _ColorComponents(
      rgba.red / 255.0,
      rgba.green / 255.0,
      rgba.blue / 255.0,
    );
  }

  static double _pseudoRandom(int index, int src, int dst) {
    int hash = 0x9E3779B9;
    hash = _mixHash(hash, index);
    hash = _mixHash(hash, src);
    hash = _mixHash(hash, dst);
    hash ^= (hash >> 16);
    final int masked = hash & 0xFFFFFFFF;
    return masked / 0xFFFFFFFF;
  }

  static int _mixHash(int hash, int value) {
    int mixed = (hash ^ value) & 0xFFFFFFFF;
    mixed = (mixed * 0x7FEB352D) & 0xFFFFFFFF;
    mixed ^= (mixed >> 15);
    mixed = (mixed * 0x846CA68B) & 0xFFFFFFFF;
    mixed ^= (mixed >> 16);
    return mixed & 0xFFFFFFFF;
  }
}

class _ColorComponents {
  const _ColorComponents(this.r, this.g, this.b);

  final double r;
  final double g;
  final double b;
}
