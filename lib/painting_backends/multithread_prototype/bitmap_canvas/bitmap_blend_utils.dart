import '../canvas/blend_mode_math.dart';
import '../canvas/canvas_layer.dart';

int blendWithMode(int dst, int src, CanvasLayerBlendMode mode, int pixelIndex) {
  return CanvasBlendMath.blend(dst, src, mode, pixelIndex: pixelIndex);
}

int blendArgb(int dst, int src) {
  final int srcA = (src >> 24) & 0xff;
  if (srcA == 0) {
    return dst;
  }
  if (srcA == 255) {
    return src;
  }

  final int dstA = (dst >> 24) & 0xff;
  final int invSrcA = 255 - srcA;
  final int outA = srcA + mul255(dstA, invSrcA);
  if (outA == 0) {
    return 0;
  }

  final int srcR = (src >> 16) & 0xff;
  final int srcG = (src >> 8) & 0xff;
  final int srcB = src & 0xff;
  final int dstR = (dst >> 16) & 0xff;
  final int dstG = (dst >> 8) & 0xff;
  final int dstB = dst & 0xff;

  final int srcPremR = mul255(srcR, srcA);
  final int srcPremG = mul255(srcG, srcA);
  final int srcPremB = mul255(srcB, srcA);
  final int dstPremR = mul255(dstR, dstA);
  final int dstPremG = mul255(dstG, dstA);
  final int dstPremB = mul255(dstB, dstA);

  final int outPremR = srcPremR + mul255(dstPremR, invSrcA);
  final int outPremG = srcPremG + mul255(dstPremG, invSrcA);
  final int outPremB = srcPremB + mul255(dstPremB, invSrcA);

  final int outR = clampToByte(((outPremR * 255) + (outA >> 1)) ~/ outA);
  final int outG = clampToByte(((outPremG * 255) + (outA >> 1)) ~/ outA);
  final int outB = clampToByte(((outPremB * 255) + (outA >> 1)) ~/ outA);

  return (outA << 24) | (outR << 16) | (outG << 8) | outB;
}

int mul255(int channel, int alpha) {
  return (channel * alpha + 127) ~/ 255;
}

int clampToByte(int value) {
  if (value <= 0) {
    return 0;
  }
  if (value >= 255) {
    return 255;
  }
  return value;
}

int premultiplyChannel(int channel, int alpha) {
  return (channel * alpha + 127) ~/ 255;
}
