import 'dart:math' as math;
import 'dart:typed_data';
import 'package:misa_rin/utils/io_shim.dart';

import '../../canvas/canvas_exporter.dart';
import '../../canvas/canvas_layer.dart';
import '../project/project_document.dart';
import 'sai2_codec.dart';

class Sai2Exporter {
  const Sai2Exporter();

  Future<void> export(ProjectDocument document, String path) async {
    final Uint8List bytes = await exportToBytes(document);
    final File output = File(path);
    await output.writeAsBytes(bytes, flush: true);
  }

  Future<Uint8List> exportToBytes(ProjectDocument document) async {
    final CanvasExporter exporter = CanvasExporter();
    final Uint8List rgba = await exporter.exportToRgba(
      settings: document.settings,
      layers: document.layers,
    );
    final int width = document.settings.width.round();
    final int height = document.settings.height.round();
    final List<CanvasLayerData> sourceLayers = document.layers;
    final List<Sai2LayerData> layerData = <Sai2LayerData>[];
    // SAI2 写入顺序需要“自上而下”（顶层在前）。
    for (final CanvasLayerData layer in sourceLayers.reversed) {
      layerData.add(
        Sai2LayerData(
          name: layer.name,
          rgbaBytes: _buildLayerRgba(layer, width, height),
          opacity: layer.opacity,
          blendMode: _blendModeToSai2(layer.blendMode),
          visible: layer.visible,
          clippingMask: layer.clippingMask,
        ),
      );
    }
    return Sai2Codec.encodeFromLayers(
      width: width,
      height: height,
      compositeRgba: rgba,
      layers: layerData,
      backgroundColorArgb: document.settings.backgroundColor.value,
    );
  }

  String _blendModeToSai2(CanvasLayerBlendMode mode) {
    switch (mode) {
      case CanvasLayerBlendMode.normal:
        return 'norm';
      case CanvasLayerBlendMode.screen:
        return 'scrn';
      case CanvasLayerBlendMode.overlay:
        return 'over';
      case CanvasLayerBlendMode.colorDodge:
        return 'ddge';
      case CanvasLayerBlendMode.multiply:
        return 'mul ';
      default:
        return 'norm';
    }
  }

  Uint8List _buildLayerRgba(
    CanvasLayerData layer,
    int width,
    int height,
  ) {
    final Uint8List output = Uint8List(width * height * 4);
    if (layer.hasBitmap) {
      final Uint8List? bitmap = layer.bitmap;
      final int bitmapWidth = layer.bitmapWidth ?? width;
      final int bitmapHeight = layer.bitmapHeight ?? height;
      final int left = layer.bitmapLeft ?? 0;
      final int top = layer.bitmapTop ?? 0;
      if (bitmap != null) {
        for (int y = 0; y < bitmapHeight; y++) {
          final int destY = y + top;
          if (destY < 0 || destY >= height) {
            continue;
          }
          final int srcRow = y * bitmapWidth * 4;
          int srcX = 0;
          int destX = left;
          if (destX < 0) {
            srcX = -destX;
            destX = 0;
          }
          final int maxPixels = math.min(
            bitmapWidth - srcX,
            width - destX,
          );
          if (maxPixels <= 0) {
            continue;
          }
          final int destOffset = (destY * width + destX) * 4;
          final int copyBytes = maxPixels * 4;
          output.setRange(
            destOffset,
            destOffset + copyBytes,
            bitmap,
            srcRow + srcX * 4,
          );
        }
      }
      return output;
    }
    if (layer.fillColor != null) {
      final int color = layer.fillColor!.value;
      final int r = (color >> 16) & 0xFF;
      final int g = (color >> 8) & 0xFF;
      final int b = color & 0xFF;
      final int a = (color >> 24) & 0xFF;
      for (int i = 0; i < output.length; i += 4) {
        output[i] = r;
        output[i + 1] = g;
        output[i + 2] = b;
        output[i + 3] = a;
      }
    }
    return output;
  }
}
