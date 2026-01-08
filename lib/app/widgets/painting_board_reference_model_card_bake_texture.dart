part of 'painting_board.dart';

extension _ReferenceModelCardBakeDialogTexture on _ReferenceModelCardState {
  Future<ui.Image?> _prepareBakeDialogTexture() async {
    ui.Image? bakeTexture;
    final ui.Image? sourceTexture = widget.texture;
    if (sourceTexture != null && !sourceTexture.debugDisposed) {
      final _BedrockTextureBytes? bytes =
          await _BedrockModelZBufferViewState._loadTextureBytes(sourceTexture);
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
          if (!bakeTexture.debugDisposed) {
            bakeTexture.dispose();
          }
          return null;
        }
        _BedrockModelZBufferViewState._textureBytesCache[bakeTexture] =
            Future<_BedrockTextureBytes?>.value(bytes);
      }
    }
    return bakeTexture;
  }
}

