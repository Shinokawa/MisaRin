part of 'painting_board.dart';

extension _BedrockModelZBufferViewStateBuffers
    on _BedrockModelZBufferViewState {
  void _ensureBuffers(int width, int height) {
    final int pixelCount = width * height;
    final int byteCount = pixelCount * 4;
    if (_colorBuffer == null || _colorBuffer!.lengthInBytes != byteCount) {
      _colorBuffer = Uint8List(byteCount);
      _colorBuffer32 = Endian.host == Endian.little
          ? _colorBuffer!.buffer.asUint32List(0, pixelCount)
          : null;
      _depthBuffer = Float32List(pixelCount);
    } else if (_depthBuffer == null || _depthBuffer!.length != pixelCount) {
      _depthBuffer = Float32List(pixelCount);
    }

    if (_shadowMask == null || _shadowMask!.length != pixelCount) {
      _shadowMask = Uint8List(pixelCount);
      _shadowMaskScratch = Uint8List(pixelCount);
    } else if (_shadowMaskScratch == null ||
        _shadowMaskScratch!.length != pixelCount) {
      _shadowMaskScratch = Uint8List(pixelCount);
    }
  }

  Float32List _ensureSelfShadowDepth(int size) {
    final int clamped = size.clamp(64, 2048).toInt();
    final int requiredLength = clamped * clamped;
    if (_selfShadowDepth == null ||
        _selfShadowDepth!.length != requiredLength) {
      _selfShadowDepth = Float32List(requiredLength);
    }
    return _selfShadowDepth!;
  }
}
