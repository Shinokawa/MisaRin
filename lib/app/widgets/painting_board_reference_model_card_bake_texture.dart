part of 'painting_board.dart';

extension _ReferenceModelCardBakeDialogTexture on _ReferenceModelCardState {
  Future<ui.Image?> _prepareBakeDialogTexture() async {
    ui.Image? bakeTexture;
    final ui.Image? sourceTexture = widget.texture;
    final ui.Image? safeTexture =
        _isImageUsable(sourceTexture) ? sourceTexture : null;
    if (safeTexture != null) {
      final _BedrockTextureBytes? bytes =
          await _BedrockModelZBufferViewState._loadTextureBytes(safeTexture);
      if (!mounted) {
        return null;
      }
      if (bytes != null) {
        final Completer<ui.Image> textureCompleter = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          bytes.rgba,
          bytes.width,
          bytes.height,
          ui.PixelFormat.rgba8888,
          textureCompleter.complete,
        );
        bakeTexture = await textureCompleter.future;
        if (!mounted) {
          _disposeImageSafely(bakeTexture);
          return null;
        }
        _BedrockModelZBufferViewState._textureBytesCache[bakeTexture] =
            Future<_BedrockTextureBytes?>.value(bytes);
      }
    }
    return bakeTexture;
  }
}
