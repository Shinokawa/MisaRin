import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Color;

import '../../canvas/blend_mode_utils.dart';
import '../../canvas/canvas_layer.dart';
import '../project/project_document.dart';
import '../../canvas/blend_mode_math.dart';

/// 极简 PSD 导出器（8BPS v1 / RGB / 8bit / Raw）。
/// 仅支持普通位图图层，忽略高级特性（混合模式、剪贴蒙版遮罩等）。
class PsdExporter {
  const PsdExporter();

  Future<void> export(ProjectDocument document, String path) async {
    final int width = document.settings.width.round();
    final int height = document.settings.height.round();
    final List<CanvasLayerData> layers = document.layers;

    final _ByteWriter writer = _ByteWriter();

    writer.writeAscii('8BPS');
    writer.writeUint16(1); // PSD version
    writer.writeBytes(Uint8List(6)); // reserved
    writer.writeUint16(3); // image channels (RGB)
    writer.writeUint32(height);
    writer.writeUint32(width);
    writer.writeUint16(8); // depth
    writer.writeUint16(3); // color mode RGB

    writer.writeUint32(0); // color mode data length
    writer.writeUint32(0); // image resources length

    final _LayerMaskSection layerMaskSection = _LayerMaskSection(
      width: width,
      height: height,
      layers: layers,
    );
    layerMaskSection.write(writer);

    final _CompositeImageSection compositeSection = _CompositeImageSection(
      width: width,
      height: height,
      layers: layers,
    );
    compositeSection.write(writer);

    final File output = File(path);
    await output.writeAsBytes(writer.toBytes(), flush: true);
  }
}

class _LayerMaskSection {
  _LayerMaskSection({
    required this.width,
    required this.height,
    required this.layers,
  });

  final int width;
  final int height;
  final List<CanvasLayerData> layers;

  void write(_ByteWriter writer) {
    final _ByteWriter sectionWriter = _ByteWriter();
    final _ByteWriter layerInfo = _ByteWriter();

    // Photoshop 存储层记录时使用负值以指示是否存在透明度通道。
    layerInfo.writeInt16(-layers.length);

    // 文档内部存储为自下而上的顺序，与 PSD 保持一致。
    final List<CanvasLayerData> ordered = List<CanvasLayerData>.from(layers);

    for (final CanvasLayerData layer in ordered) {
      _writeLayerRecord(layerInfo, layer);
    }

    for (final CanvasLayerData layer in ordered) {
      _writeLayerPixelData(layerInfo, layer);
    }

    final Uint8List layerInfoBytes = layerInfo.toBytes();
    sectionWriter.writeUint32(layerInfoBytes.length);
    sectionWriter.writeBytes(layerInfoBytes);

    sectionWriter.writeUint32(0); // global layer mask length

    final Uint8List sectionBytes = sectionWriter.toBytes();
    writer.writeUint32(sectionBytes.length);
    writer.writeBytes(sectionBytes);
  }

  void _writeLayerRecord(_ByteWriter writer, CanvasLayerData layer) {
    writer.writeInt32(0); // top
    writer.writeInt32(0); // left
    writer.writeInt32(height); // bottom
    writer.writeInt32(width); // right

    writer.writeUint16(4);

    for (final int channelId in <int>[-1, 0, 1, 2]) {
      writer.writeInt16(channelId);
      writer.writeUint32(2 + width * height);
    }

    writer.writeAscii('8BIM');
    writer.writeAscii(layer.blendMode.psdKey);
    writer.writeUint8((layer.opacity.clamp(0.0, 1.0) * 255).round());
    writer.writeUint8(layer.clippingMask ? 1 : 0);

    int flags = 0;
    if (!layer.visible) {
      flags |= 0x02;
    }
    writer.writeUint8(flags);
    writer.writeUint8(0); // filler

    final _ByteWriter extra = _ByteWriter();
    extra.writeUint32(0); // layer mask data length
    extra.writeUint32(0); // blending ranges length

    final String asciiName = _asciiFallback(layer.name);
    extra.writePascal(asciiName, padding: 4);

    _writeLuniBlock(extra, layer.name);

    final Uint8List extraBytes = extra.toBytes();
    writer.writeUint32(extraBytes.length);
    writer.writeBytes(extraBytes);
  }

  void _writeLayerPixelData(_ByteWriter writer, CanvasLayerData layer) {
    final Uint8List bitmap = _resolveBitmap(layer);
    final int pixelCount = width * height;

    final Uint8List alpha = Uint8List(pixelCount);
    final Uint8List red = Uint8List(pixelCount);
    final Uint8List green = Uint8List(pixelCount);
    final Uint8List blue = Uint8List(pixelCount);

    for (int i = 0, p = 0; i < bitmap.length; i += 4, p++) {
      red[p] = bitmap[i];
      green[p] = bitmap[i + 1];
      blue[p] = bitmap[i + 2];
      alpha[p] = bitmap[i + 3];
    }

    void writeChannel(Uint8List channel) {
      writer.writeUint16(0); // compression: raw
      writer.writeBytes(channel);
    }

    writeChannel(alpha);
    writeChannel(red);
    writeChannel(green);
    writeChannel(blue);
  }

  Uint8List _resolveBitmap(CanvasLayerData layer) {
    if (layer.hasBitmap) {
      return Uint8List.fromList(layer.bitmap!);
    }
    final Uint8List buffer = Uint8List(width * height * 4);
    final int color = layer.fillColor?.value ?? 0x00000000;
    final int r = (color >> 16) & 0xFF;
    final int g = (color >> 8) & 0xFF;
    final int b = color & 0xFF;
    final int a = (color >> 24) & 0xFF;
    for (int i = 0; i < buffer.length; i += 4) {
      buffer[i] = r;
      buffer[i + 1] = g;
      buffer[i + 2] = b;
      buffer[i + 3] = a;
    }
    return buffer;
  }

  String _asciiFallback(String input) {
    final StringBuffer buffer = StringBuffer();
    for (final int rune in input.runes) {
      if (rune >= 32 && rune <= 126) {
        buffer.writeCharCode(rune);
      } else {
        buffer.write('_');
      }
    }
    final String result = buffer.isEmpty ? 'Layer' : buffer.toString();
    return result.length > 255 ? result.substring(0, 255) : result;
  }

  void _writeLuniBlock(_ByteWriter writer, String name) {
    final _ByteWriter luni = _ByteWriter();
    final List<int> units = name.codeUnits;
    luni.writeUint32(units.length);
    for (final int unit in units) {
      luni.writeUint16(unit);
    }
    final Uint8List luniBytes = luni.toBytes();

    writer.writeAscii('8BIM');
    writer.writeAscii('luni');
    writer.writeUint32(luniBytes.length);
    writer.writeBytes(luniBytes);
    if ((luniBytes.length & 1) == 1) {
      writer.writeUint8(0);
    }
  }
}

class _CompositeImageSection {
  _CompositeImageSection({
    required this.width,
    required this.height,
    required this.layers,
  });

  final int width;
  final int height;
  final List<CanvasLayerData> layers;

  void write(_ByteWriter writer) {
    final Uint8List composite = _flatten();
    final int pixelCount = width * height;
    final Uint8List alpha = Uint8List(pixelCount);
    final Uint8List red = Uint8List(pixelCount);
    final Uint8List green = Uint8List(pixelCount);
    final Uint8List blue = Uint8List(pixelCount);

    for (int i = 0, p = 0; i < composite.length; i += 4, p++) {
      red[p] = composite[i];
      green[p] = composite[i + 1];
      blue[p] = composite[i + 2];
      alpha[p] = composite[i + 3];
    }

    writer.writeUint16(0);
    writer.writeBytes(alpha);
    writer.writeUint16(0);
    writer.writeBytes(red);
    writer.writeUint16(0);
    writer.writeBytes(green);
    writer.writeUint16(0);
    writer.writeBytes(blue);
  }

  Uint8List _flatten() {
    final Uint8List result = Uint8List(width * height * 4);
    final List<CanvasLayerData> ordered = List<CanvasLayerData>.from(layers);

    for (final CanvasLayerData layer in ordered) {
      if (!layer.visible) {
        continue;
      }
      final Uint8List bitmap = layer.hasBitmap
          ? Uint8List.fromList(layer.bitmap!)
          : _solidBitmap(layer.fillColor ?? const Color(0x00000000));
      final double layerOpacity = layer.opacity.clamp(0.0, 1.0);
      if (layerOpacity <= 0) {
        continue;
      }
      _blendOnto(result, bitmap, layerOpacity, layer.blendMode);
    }

    return result;
  }

  Uint8List _solidBitmap(Color color) {
    final Uint8List buffer = Uint8List(width * height * 4);
    for (int i = 0; i < buffer.length; i += 4) {
      buffer[i] = color.red;
      buffer[i + 1] = color.green;
      buffer[i + 2] = color.blue;
      buffer[i + 3] = color.alpha;
    }
    return buffer;
  }

  void _blendOnto(
    Uint8List dest,
    Uint8List src,
    double opacity,
    CanvasLayerBlendMode mode,
  ) {
    for (int i = 0, pixelIndex = 0; i < dest.length; i += 4, pixelIndex++) {
      final int baseAlpha = src[i + 3];
      if (baseAlpha == 0) {
        continue;
      }
      final int effectiveAlpha = (baseAlpha * opacity).round().clamp(0, 255);
      if (effectiveAlpha <= 0) {
        continue;
      }
      final int srcArgb =
          (effectiveAlpha << 24) |
          (src[i] << 16) |
          (src[i + 1] << 8) |
          src[i + 2];
      final int dstArgb =
          (dest[i + 3] << 24) |
          (dest[i] << 16) |
          (dest[i + 1] << 8) |
          dest[i + 2];
      final int blended = CanvasBlendMath.blend(
        dstArgb,
        srcArgb,
        mode,
        pixelIndex: pixelIndex,
      );
      dest[i] = (blended >> 16) & 0xff;
      dest[i + 1] = (blended >> 8) & 0xff;
      dest[i + 2] = blended & 0xff;
      dest[i + 3] = (blended >> 24) & 0xff;
    }
  }
}

class _ByteWriter {
  final BytesBuilder _builder = BytesBuilder();

  void writeBytes(List<int> data) {
    if (data.isEmpty) {
      return;
    }
    _builder.add(data is Uint8List ? data : Uint8List.fromList(data));
  }

  void writeAscii(String value) {
    _builder.add(Uint8List.fromList(value.codeUnits));
  }

  void writeUint8(int value) {
    _builder.add(Uint8List.fromList(<int>[value & 0xFF]));
  }

  void writeInt16(int value) {
    if (value < 0) {
      value = 0x10000 + value;
    }
    writeUint16(value);
  }

  void writeUint16(int value) {
    _builder.add(Uint8List.fromList(<int>[(value >> 8) & 0xFF, value & 0xFF]));
  }

  void writeInt32(int value) {
    if (value < 0) {
      value = 0x100000000 + value;
    }
    writeUint32(value);
  }

  void writeUint32(int value) {
    _builder.add(
      Uint8List.fromList(<int>[
        (value >> 24) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF,
      ]),
    );
  }

  void writePascal(String text, {int padding = 1}) {
    final Uint8List bytes = Uint8List.fromList(text.codeUnits);
    final int length = min(bytes.length, 255);
    writeUint8(length);
    if (length > 0) {
      writeBytes(bytes.sublist(0, length));
    }
    final int consumed = 1 + length;
    final int remainder = consumed % padding;
    if (remainder != 0) {
      writeBytes(Uint8List(padding - remainder));
    }
  }

  Uint8List toBytes() {
    return _builder.toBytes();
  }
}
