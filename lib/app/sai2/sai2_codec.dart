import 'dart:math' as math;
import 'dart:typed_data';

class Sai2DecodedLayer {
  const Sai2DecodedLayer({
    required this.layerId,
    required this.name,
    required this.width,
    required this.height,
    required this.rgbaBytes,
    required this.opacity,
    required this.blendMode,
    required this.visible,
  });

  final int layerId;
  final String name;
  final int width;
  final int height;
  final Uint8List rgbaBytes;
  final double opacity;
  final String blendMode;
  final bool visible;
}

class Sai2DecodedImage {
  const Sai2DecodedImage({
    required this.width,
    required this.height,
    required this.rgbaBytes,
    this.layers = const <Sai2DecodedLayer>[],
  });

  final int width;
  final int height;
  final Uint8List rgbaBytes;
  final List<Sai2DecodedLayer> layers;
}

class Sai2LayerData {
  const Sai2LayerData({
    required this.name,
    required this.rgbaBytes,
    required this.opacity,
    required this.blendMode,
    required this.visible,
  });

  final String name;
  final Uint8List rgbaBytes;
  final double opacity;
  final String blendMode;
  final bool visible;
}

class Sai2Codec {
  static Sai2DecodedImage decodeFromBytes(Uint8List bytes) {
    final _ByteReader reader = _ByteReader(bytes);
    final Sai2Header header = Sai2Header.read(reader);
    final List<Sai2Entry> entries = List<Sai2Entry>.generate(
      header.tableCount,
      (_) => Sai2Entry.read(reader),
      growable: false,
    );

    if (entries.isEmpty) {
      throw StateError('SAI2 文件缺少数据块。');
    }

    final List<Sai2Entry> sorted = List<Sai2Entry>.from(entries)
      ..sort((a, b) => a.offset.compareTo(b.offset));
    final Map<Sai2Entry, int> entrySizes = <Sai2Entry, int>{};
    for (int i = 0; i < sorted.length; i++) {
      final Sai2Entry entry = sorted[i];
      final int nextOffset = (i + 1 < sorted.length)
          ? sorted[i + 1].offset
          : bytes.length;
      entrySizes[entry] = math.max(0, nextOffset - entry.offset);
    }

    Sai2Entry? intgEntry;
    final Map<int, _Sai2LayerInfo> layerInfos = <int, _Sai2LayerInfo>{};
    final List<int> layerOrder = <int>[];
    final Map<int, Uint8List> layerPixels = <int, Uint8List>{};

    for (final Sai2Entry entry in entries) {
      final int dataSize = entrySizes[entry] ?? 0;
      if (dataSize <= 0 || entry.offset + dataSize > bytes.length) {
        continue;
      }
      if (entry.type == 'intg') {
        intgEntry = entry;
        continue;
      }
      if (entry.type == 'layr') {
        final Uint8List blob = bytes.sublist(
          entry.offset,
          entry.offset + dataSize,
        );
        final _Sai2LayerInfo info = _parseLayerInfo(blob);
        layerInfos[info.layerId] = info;
        layerOrder.add(info.layerId);
      } else if (entry.type == 'lpix') {
        layerPixels[entry.layerId] = bytes.sublist(
          entry.offset,
          entry.offset + dataSize,
        );
      }
    }

    Uint8List? intgRgba;
    if (intgEntry != null) {
      final int dataSize = entrySizes[intgEntry] ?? 0;
      if (dataSize > 0 && intgEntry.offset + dataSize <= bytes.length) {
        final Uint8List blob = bytes.sublist(
          intgEntry.offset,
          intgEntry.offset + dataSize,
        );
        intgRgba = _decodeDpcm(blob, header).rgbaBytes;
      }
    }

    final List<Sai2DecodedLayer> decodedLayers = <Sai2DecodedLayer>[];
    for (final int layerId in layerOrder) {
      final _Sai2LayerInfo? info = layerInfos[layerId];
      final Uint8List? lpix = layerPixels[layerId];
      if (info == null || lpix == null) {
        continue;
      }
      final Uint8List? layerRgba = _decodeLpixSolidBlocks(
        lpix,
        header,
        info.tileCount,
      );
      if (layerRgba == null) {
        continue;
      }
      decodedLayers.add(
        Sai2DecodedLayer(
          layerId: layerId,
          name: info.name,
          width: header.width,
          height: header.height,
          rgbaBytes: layerRgba,
          opacity: info.opacity,
          blendMode: info.blendMode,
          visible: info.visible,
        ),
      );
    }

    if (intgRgba == null && decodedLayers.isEmpty) {
      throw UnsupportedError('无法读取 SAI2 图像内容。');
    }

    final Uint8List resolved =
        intgRgba ?? decodedLayers.last.rgbaBytes;

    return Sai2DecodedImage(
      width: header.width,
      height: header.height,
      rgbaBytes: resolved,
      layers: decodedLayers,
    );
  }

  static Uint8List encodeFromRgba({
    required Uint8List rgbaBytes,
    required int width,
    required int height,
    required bool hasAlpha,
    int backgroundColorArgb = 0xFFFFFFFF,
    String layerEffect = 'norm',
  }) {
    final Uint8List dpcm = _encodeDpcm(
      rgbaBytes: rgbaBytes,
      width: width,
      height: height,
      hasAlpha: hasAlpha,
    );

    final List<_Chunk> chunks = <_Chunk>[
      _Chunk(type: 'intg', layerId: 0, data: dpcm),
    ];

    final _ByteWriter writer = _ByteWriter();
    writer.writeAscii('SAI-CANVAS-TYPE0');

    writer.writeUint8(0);
    writer.writeUint8(hasAlpha ? 0 : 1);
    writer.writeUint8(0);
    writer.writeUint8(0);

    writer.writeUint32(width);
    writer.writeUint32(height);
    writer.writeUint32(0x001C58B1);
    writer.writeUint32(chunks.length);
    writer.writeUint32(0);
    writer.writeUint64(0);
    writer.writeUint64(0);
    writer.writeUint32(backgroundColorArgb);
    writer.writeAscii(layerEffect, length: 4);

    int offset = Sai2Header.byteSize + chunks.length * Sai2Entry.byteSize;
    for (final _Chunk chunk in chunks) {
      chunk.offset = offset;
      offset += chunk.data.length;
    }

    for (final _Chunk chunk in chunks) {
      writer.writeAscii(chunk.type, length: 4);
      writer.writeUint32(chunk.layerId);
      writer.writeUint64(chunk.offset);
    }

    for (final _Chunk chunk in chunks) {
      writer.writeBytes(chunk.data);
    }

    return writer.toBytes();
  }

  static Uint8List encodeFromLayers({
    required int width,
    required int height,
    required Uint8List compositeRgba,
    required List<Sai2LayerData> layers,
    int backgroundColorArgb = 0xFFFFFFFF,
    String layerEffect = 'norm',
  }) {
    bool hasAlpha = _hasAlpha(compositeRgba);
    if (!hasAlpha) {
      for (final Sai2LayerData layer in layers) {
        if (_hasAlpha(layer.rgbaBytes)) {
          hasAlpha = true;
          break;
        }
      }
    }
    final Uint8List dpcm = _encodeDpcm(
      rgbaBytes: compositeRgba,
      width: width,
      height: height,
      hasAlpha: hasAlpha,
    );

    final int tileWidth = 256;
    final int tileHeight = 128;
    final int tilesX = (width + tileWidth - 1) ~/ tileWidth;
    final int tilesY = (height + tileHeight - 1) ~/ tileHeight;
    final int tileCount = tilesX * tilesY;

    final List<_Chunk> layrChunks = <_Chunk>[];
    final List<_Chunk> lpixChunks = <_Chunk>[];
    for (int i = 0; i < layers.length; i++) {
      final Sai2LayerData layer = layers[i];
      final int layerId = i + 2;
      final Uint8List layr = _encodeLayerInfo(
        layerId: layerId,
        name: layer.name,
        tileCount: tileCount,
        blendMode: layer.blendMode,
        opacity: layer.opacity,
        visible: layer.visible,
      );
      final Uint8List lpix = _encodeLpixSolidBlocks(
        rgbaBytes: layer.rgbaBytes,
        width: width,
        height: height,
        tileCount: tileCount,
        tileWidth: tileWidth,
        tileHeight: tileHeight,
        hasAlpha: hasAlpha,
      );
      layrChunks.add(_Chunk(type: 'layr', layerId: layerId, data: layr));
      lpixChunks.add(_Chunk(type: 'lpix', layerId: layerId, data: lpix));
    }

    final List<_Chunk> chunks = <_Chunk>[
      _Chunk(type: 'intg', layerId: 0, data: dpcm),
      ...layrChunks,
      ...lpixChunks,
    ];

    final _ByteWriter writer = _ByteWriter();
    writer.writeAscii('SAI-CANVAS-TYPE0');

    writer.writeUint8(0);
    writer.writeUint8(hasAlpha ? 0 : 1);
    writer.writeUint8(0);
    writer.writeUint8(0);

    writer.writeUint32(width);
    writer.writeUint32(height);
    writer.writeUint32(0x001C58B1);
    writer.writeUint32(chunks.length);
    writer.writeUint32(layers.isEmpty ? 0 : layers.length + 1);
    writer.writeUint64(0);
    writer.writeUint64(0);
    writer.writeUint32(backgroundColorArgb);
    writer.writeAscii(layerEffect, length: 4);

    int offset = Sai2Header.byteSize + chunks.length * Sai2Entry.byteSize;
    for (final _Chunk chunk in chunks) {
      chunk.offset = offset;
      offset += chunk.data.length;
    }

    for (final _Chunk chunk in chunks) {
      writer.writeAscii(chunk.type, length: 4);
      writer.writeUint32(chunk.layerId);
      writer.writeUint64(chunk.offset);
    }

    for (final _Chunk chunk in chunks) {
      writer.writeBytes(chunk.data);
    }

    return writer.toBytes();
  }

  static Sai2DecodedImage _decodeDpcm(Uint8List blob, Sai2Header header) {
    final _ByteReader reader = _ByteReader(blob);
    final String format = reader.readAscii(4);
    if (format != 'dpcm') {
      throw UnsupportedError('仅支持 dpcm 格式的 intg 数据。');
    }

    final int tileSize = 256;
    final int tilesX = (header.width + tileSize - 1) ~/ tileSize;
    final int tilesY = (header.height + tileSize - 1) ~/ tileSize;
    final int tilesCount = tilesX * tilesY;

    final List<int> tileSizes = List<int>.generate(
      tilesCount,
      (_) => reader.readUint32(),
      growable: false,
    );

    final Uint32List output =
        Uint32List(header.width * header.height);

    int cursor = reader.offset;
    final Uint8List source = blob;

    int tileIndex = 0;
    for (int tileY = 0; tileY < tilesY; tileY++) {
      final int tileBegY = tileY * tileSize;
      final int tileEndY = math.min(tileBegY + tileSize, header.height);
      final int tileSizeY = tileEndY - tileBegY;

      for (int tileX = 0; tileX < tilesX; tileX++, tileIndex++) {
        final int tileDataSize = tileSizes[tileIndex];
        if (tileDataSize <= 2 ||
            cursor + tileDataSize > source.length) {
          throw StateError('dpcm tile 数据异常。');
        }

        final Uint8List tileBytes = source.sublist(
          cursor,
          cursor + tileDataSize,
        );
        cursor += tileDataSize;

        final int tileBegX = tileX * tileSize;
        final int tileEndX = math.min(tileBegX + tileSize, header.width);
        final int tileSizeX = tileEndX - tileBegX;

        int tileOffset = 2; // skip checksum
        Uint32List previousRow = Uint32List(tileSizeX);
        Uint32List currentRow = Uint32List(tileSizeX);

        for (int row = 0; row < tileSizeY; row++) {
          // Match SAI2 behavior: prefill with -1 and keep going on decode gaps.
          final Int16List deltaRow =
              Int16List(tileSizeX * 4)..fillRange(0, tileSizeX * 4, -1);
          final int consumed = _unpackDeltaRle16(
            tileBytes,
            tileOffset,
            deltaRow,
            tileSizeX,
            4,
            header.channelCount,
          );
          if (consumed > 0) {
            tileOffset += consumed;
          }

          _deltaUnpackRow16Bpc(
            dest: currentRow,
            previousRow: previousRow,
            deltaRow: deltaRow,
            pixelCount: tileSizeX,
          );

          final int destOffset =
              (tileBegY + row) * header.width + tileBegX;
          output.setAll(destOffset, currentRow);

          final Uint32List swap = previousRow;
          previousRow = currentRow;
          currentRow = swap;
        }
      }
      // Each tile row has an extra 2-byte checksum separator.
      if (cursor + 2 <= source.length) {
        cursor += 2;
      }
    }

    if (header.channelCount == 3) {
      for (int i = 0; i < output.length; i++) {
        output[i] |= 0xFF000000;
      }
    }

    final Uint8List rgbaBytes =
        Uint8List(output.length * 4);
    for (int i = 0; i < output.length; i++) {
      final int bgra = output[i];
      final int offset = i * 4;
      rgbaBytes[offset] = (bgra) & 0xFF;
      rgbaBytes[offset + 1] = (bgra >> 8) & 0xFF;
      rgbaBytes[offset + 2] = (bgra >> 16) & 0xFF;
      rgbaBytes[offset + 3] = (bgra >> 24) & 0xFF;
      final int tmp = rgbaBytes[offset];
      rgbaBytes[offset] = rgbaBytes[offset + 2];
      rgbaBytes[offset + 2] = tmp;
    }

    return Sai2DecodedImage(
      width: header.width,
      height: header.height,
      rgbaBytes: rgbaBytes,
    );
  }

  static Uint8List _encodeDpcm({
    required Uint8List rgbaBytes,
    required int width,
    required int height,
    required bool hasAlpha,
  }) {
    final int tileSize = 256;
    final int tilesX = (width + tileSize - 1) ~/ tileSize;
    final int tilesY = (height + tileSize - 1) ~/ tileSize;
    final int tilesCount = tilesX * tilesY;

    final Uint32List bgra = Uint32List(width * height);
    for (int i = 0; i < bgra.length; i++) {
      final int offset = i * 4;
      final int r = rgbaBytes[offset];
      final int g = rgbaBytes[offset + 1];
      final int b = rgbaBytes[offset + 2];
      final int a = rgbaBytes[offset + 3];
      bgra[i] = (a << 24) | (r << 16) | (g << 8) | b;
    }

    final List<int> tileSizes = List<int>.filled(tilesCount, 0);
    final List<Uint8List> tileData = <Uint8List>[];

    int tileIndex = 0;
    for (int tileY = 0; tileY < tilesY; tileY++) {
      final int tileBegY = tileY * tileSize;
      final int tileEndY = math.min(tileBegY + tileSize, height);
      final int tileSizeY = tileEndY - tileBegY;

      for (int tileX = 0; tileX < tilesX; tileX++, tileIndex++) {
        final int tileBegX = tileX * tileSize;
        final int tileEndX = math.min(tileBegX + tileSize, width);
        final int tileSizeX = tileEndX - tileBegX;

        final _ByteWriter tileWriter = _ByteWriter();
        final int checksum = 0xFF | (tileX << 8);
        tileWriter.writeUint16(checksum);

        Uint32List previousRow = Uint32List(tileSizeX);
        Uint32List currentRow = Uint32List(tileSizeX);

        for (int row = 0; row < tileSizeY; row++) {
          final int srcOffset =
              (tileBegY + row) * width + tileBegX;
          currentRow.setAll(
            0,
            bgra.sublist(srcOffset, srcOffset + tileSizeX),
          );

          final Int16List deltaRow = _deltaPackRow16Bpc(
            currentRow,
            previousRow,
            tileSizeX,
          );
          final Uint8List packed = _packDeltaRle16(
            deltaRow,
            tileSizeX,
            4,
            hasAlpha ? 4 : 3,
          );
          tileWriter.writeBytes(packed);

          final Uint32List swap = previousRow;
          previousRow = currentRow;
          currentRow = swap;
        }

        final Uint8List tileBytes = tileWriter.toBytes();
        tileSizes[tileIndex] = tileBytes.length;
        tileData.add(tileBytes);
      }
    }

    final _ByteWriter writer = _ByteWriter();
    writer.writeAscii('dpcm');
    for (final int size in tileSizes) {
      writer.writeUint32(size);
    }
    int tileCursor = 0;
    for (int tileY = 0; tileY < tilesY; tileY++) {
      for (int tileX = 0; tileX < tilesX; tileX++) {
        writer.writeBytes(tileData[tileCursor++]);
      }
      final int rowChecksum = 0xFF | (tilesX << 8);
      writer.writeUint16(rowChecksum);
    }
    return writer.toBytes();
  }

  static _Sai2LayerInfo _parseLayerInfo(Uint8List blob) {
    final _ByteReader reader = _ByteReader(blob);
    final String tag = reader.readAscii(4);
    if (tag != 'layr') {
      throw StateError('layr 块格式不正确。');
    }
    final int layerId = reader.readUint32();
    reader.readUint64();
    final String layerType = reader.readAscii(4);
    for (int i = 0; i < 4; i++) {
      reader.readInt32();
    }
    final int unknownA = reader.readUint32();
    final int tileCount = reader.readUint32();
    final String blendMode = reader.readAscii(4);
    final int opacityRaw = reader.readUint32();
    final int flags = reader.readUint32();

    String name = '图层';
    while (reader.remaining >= 8) {
      final String paramName = reader.readAscii(4);
      if (paramName.codeUnits.every((int c) => c == 0)) {
        break;
      }
      final int paramLength = reader.readUint32();
      final Uint8List value = reader.readBytes(paramLength);
      if (paramName == 'name') {
        name = _decodeLayerName(value);
      }
    }

    return _Sai2LayerInfo(
      layerId: layerId,
      name: name,
      tileCount: tileCount > 0 ? tileCount : unknownA,
      blendMode: blendMode,
      opacity: (opacityRaw.clamp(0, 100)) / 100.0,
      visible: (flags & 0x00010000) != 0,
      layerType: layerType,
    );
  }

  static Uint8List? _decodeLpixSolidBlocks(
    Uint8List blob,
    Sai2Header header,
    int tileCount,
  ) {
    if (blob.length < 4) {
      return null;
    }
    final _ByteReader reader = _ByteReader(blob);
    final String format = reader.readAscii(4);
    if (format != 'dpcm' || tileCount <= 0) {
      return null;
    }

    final List<int> tileSizes = List<int>.generate(
      tileCount,
      (_) => reader.readUint32(),
      growable: false,
    );

    final int width = header.width;
    final int height = header.height;

    int tileWidth = 256;
    int tileHeight = 128;
    int tilesX = (width + tileWidth - 1) ~/ tileWidth;
    int tilesY = (height + tileHeight - 1) ~/ tileHeight;
    if (tilesX * tilesY != tileCount) {
      tilesX = 1;
      tilesY = tileCount;
      tileWidth = width;
      tileHeight = (height + tileCount - 1) ~/ tileCount;
    }

    final Uint8List rgba = Uint8List(width * height * 4);
    int cursor = reader.offset;
    int tileIndex = 0;
    for (int tileY = 0; tileY < tilesY; tileY++) {
      for (int tileX = 0; tileX < tilesX; tileX++, tileIndex++) {
        if (tileIndex >= tileCount || tileIndex >= tileSizes.length) {
          break;
        }
        final int tileSizeBytes = tileSizes[tileIndex];
        if (tileSizeBytes <= 2 ||
            cursor + tileSizeBytes > blob.length) {
          return null;
        }
        final Uint8List tileBytes = blob.sublist(
          cursor,
          cursor + tileSizeBytes,
        );
        cursor += tileSizeBytes;

        final int tileBegX = tileX * tileWidth;
        final int tileBegY = tileY * tileHeight;
        final int tileEndX = math.min(tileBegX + tileWidth, width);
        final int tileEndY = math.min(tileBegY + tileHeight, height);
        final int tileSizeX = tileEndX - tileBegX;
        final int tileSizeY = tileEndY - tileBegY;

        const int blockSize = 32;
        final int blocksX = (tileSizeX + blockSize - 1) ~/ blockSize;
        final int blocksY = (tileSizeY + blockSize - 1) ~/ blockSize;
        if (blocksX == 0 || blocksY == 0) {
          continue;
        }
        if (16 % blocksX != 0) {
          return null;
        }
        final int groupRows = 16 ~/ blocksX;

        int pos = 0;
        int recordIndex = 0;
        while (pos + 2 <= tileBytes.length &&
            recordIndex < blocksX * blocksY) {
          final int marker = _readUint16LE(tileBytes, pos);
          pos += 2;
          if (marker == 0xF0FF) {
            break;
          }
          if (pos + 8 > tileBytes.length) {
            break;
          }
          final int r16 = _readUint16LE(tileBytes, pos);
          final int g16 = _readUint16LE(tileBytes, pos + 2);
          final int b16 = _readUint16LE(tileBytes, pos + 4);
          final int a16 = _readUint16LE(tileBytes, pos + 6);
          pos += 8;

          final int headerIndex = ((marker >> 8) & 0xFF) - 0x50;
          final int blockIndexInGroup = (headerIndex >= 0 &&
                  headerIndex < 16)
              ? headerIndex
              : (recordIndex % 16);
          final int groupIndex = recordIndex ~/ 16;
          final int blockX = blockIndexInGroup % blocksX;
          final int blockY =
              groupIndex * groupRows + (blockIndexInGroup ~/ blocksX);
          if (blockY >= blocksY) {
            recordIndex++;
            continue;
          }

          final int pixelBegX = tileBegX + blockX * blockSize;
          final int pixelBegY = tileBegY + blockY * blockSize;
          final int pixelEndX =
              math.min(pixelBegX + blockSize, width);
          final int pixelEndY =
              math.min(pixelBegY + blockSize, height);

          final int r8 = _scale14To8(r16);
          final int g8 = _scale14To8(g16);
          final int b8 = _scale14To8(b16);
          final int a8 = header.channelCount == 3
              ? 0xFF
              : _scale14To8(a16);

          for (int py = pixelBegY; py < pixelEndY; py++) {
            int rowOffset = (py * width + pixelBegX) * 4;
            for (int px = pixelBegX; px < pixelEndX; px++) {
              rgba[rowOffset] = r8;
              rgba[rowOffset + 1] = g8;
              rgba[rowOffset + 2] = b8;
              rgba[rowOffset + 3] = a8;
              rowOffset += 4;
            }
          }

          recordIndex++;
        }
      }
    }
    return rgba;
  }

  static Uint8List _encodeLayerInfo({
    required int layerId,
    required String name,
    required int tileCount,
    required String blendMode,
    required double opacity,
    required bool visible,
  }) {
    final _ByteWriter writer = _ByteWriter();
    writer.writeAscii('layr', length: 4);
    writer.writeUint32(layerId);
    writer.writeUint64(0);
    writer.writeAscii('norm', length: 4);
    for (int i = 0; i < 4; i++) {
      writer.writeInt32(0);
    }
    writer.writeUint32(tileCount);
    writer.writeUint32(tileCount);
    writer.writeAscii(blendMode, length: 4);
    final int opacityValue =
        (opacity * 100).round().clamp(0, 100);
    writer.writeUint32(opacityValue);
    writer.writeUint32(visible ? 0x00010000 : 0);

    final Uint8List nameBytes = _encodeLayerName(name);
    writer.writeAscii('name', length: 4);
    writer.writeUint32(nameBytes.length);
    writer.writeBytes(nameBytes);
    writer.writeUint32(0);
    return writer.toBytes();
  }

  static Uint8List _encodeLpixSolidBlocks({
    required Uint8List rgbaBytes,
    required int width,
    required int height,
    required int tileCount,
    required int tileWidth,
    required int tileHeight,
    required bool hasAlpha,
  }) {
    final int tilesX = (width + tileWidth - 1) ~/ tileWidth;
    final int tilesY = (height + tileHeight - 1) ~/ tileHeight;
    if (tilesX * tilesY != tileCount) {
      throw StateError('lpix 瓦片数量与画布尺寸不匹配。');
    }

    const int blockSize = 32;
    final int blocksX = (tileWidth + blockSize - 1) ~/ blockSize;
    final int blocksY = (tileHeight + blockSize - 1) ~/ blockSize;
    if (blocksX == 0 || blocksY == 0 || 16 % blocksX != 0) {
      throw StateError('lpix 瓦片分块参数不兼容。');
    }
    final int groupRows = 16 ~/ blocksX;

    final List<int> tileSizes = List<int>.filled(tileCount, 0);
    final List<Uint8List> tileData = <Uint8List>[];

    int tileIndex = 0;
    for (int tileY = 0; tileY < tilesY; tileY++) {
      for (int tileX = 0; tileX < tilesX; tileX++, tileIndex++) {
        final int tileBegX = tileX * tileWidth;
        final int tileBegY = tileY * tileHeight;
        final int tileEndX = math.min(tileBegX + tileWidth, width);
        final int tileEndY = math.min(tileBegY + tileHeight, height);
        final int tileSizeX = tileEndX - tileBegX;
        final int tileSizeY = tileEndY - tileBegY;

        final int blocksXTile =
            (tileSizeX + blockSize - 1) ~/ blockSize;
        final int blocksYTile =
            (tileSizeY + blockSize - 1) ~/ blockSize;
        final _ByteWriter tileWriter = _ByteWriter();

        for (int recordIndex = 0;
            recordIndex < blocksX * blocksY;
            recordIndex++) {
          final int groupIndex = recordIndex ~/ 16;
          final int blockIndexInGroup = recordIndex % 16;
          final int blockX = blockIndexInGroup % blocksX;
          final int blockY =
              groupIndex * groupRows + (blockIndexInGroup ~/ blocksX);

          final int header =
              0xFF | ((0x50 + blockIndexInGroup) << 8);
          tileWriter.writeUint16(header);

          if (blockX >= blocksXTile || blockY >= blocksYTile) {
            tileWriter.writeUint16(0);
            tileWriter.writeUint16(0);
            tileWriter.writeUint16(0);
            tileWriter.writeUint16(hasAlpha ? 0 : 0x4000);
            continue;
          }

          final int pixelBegX = tileBegX + blockX * blockSize;
          final int pixelBegY = tileBegY + blockY * blockSize;
          final int pixelEndX =
              math.min(pixelBegX + blockSize, width);
          final int pixelEndY =
              math.min(pixelBegY + blockSize, height);

          int sumR = 0;
          int sumG = 0;
          int sumB = 0;
          int sumA = 0;
          int count = 0;
          for (int py = pixelBegY; py < pixelEndY; py++) {
            int rowOffset = (py * width + pixelBegX) * 4;
            for (int px = pixelBegX; px < pixelEndX; px++) {
              sumR += rgbaBytes[rowOffset];
              sumG += rgbaBytes[rowOffset + 1];
              sumB += rgbaBytes[rowOffset + 2];
              sumA += rgbaBytes[rowOffset + 3];
              rowOffset += 4;
              count++;
            }
          }

          if (count == 0) {
            tileWriter.writeUint16(0);
            tileWriter.writeUint16(0);
            tileWriter.writeUint16(0);
            tileWriter.writeUint16(hasAlpha ? 0 : 0x4000);
            continue;
          }

          final int r8 = (sumR + count ~/ 2) ~/ count;
          final int g8 = (sumG + count ~/ 2) ~/ count;
          final int b8 = (sumB + count ~/ 2) ~/ count;
          final int a8 = hasAlpha
              ? (sumA + count ~/ 2) ~/ count
              : 0xFF;

          tileWriter.writeUint16(_scale8To14(r8));
          tileWriter.writeUint16(_scale8To14(g8));
          tileWriter.writeUint16(_scale8To14(b8));
          tileWriter.writeUint16(_scale8To14(a8));
        }

        tileWriter.writeUint16(0xF0FF);
        final Uint8List tileBytes = tileWriter.toBytes();
        tileSizes[tileIndex] = tileBytes.length;
        tileData.add(tileBytes);
      }
    }

    final _ByteWriter writer = _ByteWriter();
    writer.writeAscii('dpcm');
    for (final int size in tileSizes) {
      writer.writeUint32(size);
    }
    for (final Uint8List tileBytes in tileData) {
      writer.writeBytes(tileBytes);
    }
    return writer.toBytes();
  }

  static String _decodeLayerName(Uint8List data) {
    if (data.isEmpty) {
      return '图层';
    }
    if (data.length >= 2) {
      final ByteData view = ByteData.sublistView(data);
      final int count = view.getUint16(0, Endian.little);
      if (count > 0 && data.length >= 2 + count * 2) {
        final List<int> codeUnits = <int>[];
        for (int i = 0; i < count; i++) {
          final int unit = view.getUint16(2 + i * 2, Endian.little);
          if (unit == 0) {
            break;
          }
          codeUnits.add(unit);
        }
        if (codeUnits.isNotEmpty) {
          return String.fromCharCodes(codeUnits);
        }
      }
    }
    try {
      return String.fromCharCodes(data).trim();
    } catch (_) {
      return '图层';
    }
  }

  static Uint8List _encodeLayerName(String name) {
    final List<int> codeUnits = name.isEmpty
        ? <int>[0x56FE, 0x5C42]
        : name.codeUnits;
    final int count = codeUnits.length;
    final _ByteWriter writer = _ByteWriter();
    writer.writeUint16(count);
    for (final int unit in codeUnits) {
      writer.writeUint16(unit);
    }
    writer.writeUint16(0);
    return writer.toBytes();
  }

  static bool _hasAlpha(Uint8List rgba) {
    for (int i = 3; i < rgba.length; i += 4) {
      if (rgba[i] != 0xFF) {
        return true;
      }
    }
    return false;
  }

  static int _readUint16LE(Uint8List bytes, int offset) {
    return bytes.buffer
        .asByteData()
        .getUint16(bytes.offsetInBytes + offset, Endian.little);
  }

  static int _scale14To8(int value) {
    if (value <= 0) {
      return 0;
    }
    if (value >= 0x4000) {
      return 255;
    }
    return ((value * 255) + 0x2000) ~/ 0x4000;
  }

  static int _scale8To14(int value) {
    if (value <= 0) {
      return 0;
    }
    if (value >= 255) {
      return 0x4000;
    }
    return ((value * 0x4000) + 127) ~/ 255;
  }

  static int _unpackDeltaRle16(
    Uint8List source,
    int offset,
    Int16List output,
    int pixelCount,
    int outputChannels,
    int inputChannels,
  ) {
    int idx = offset;
    int remainingBits = 0;
    int mask = 0;
    const int mask64 = 0xFFFFFFFFFFFFFFFF;

    for (int channel = 0; channel < inputChannels; channel++) {
      int channelCount = 0;
      int writeIndex = channel;
      while (true) {
        while (remainingBits < 32 && idx < source.length) {
          final int shiftAmount = remainingBits;
          int newWord;
          if (idx + 4 <= source.length) {
            newWord = source.buffer.asByteData().getUint32(
              source.offsetInBytes + idx,
              Endian.little,
            );
            idx += 4;
            remainingBits += 32;
          } else if (idx + 2 <= source.length) {
            newWord = source.buffer.asByteData().getUint16(
              source.offsetInBytes + idx,
              Endian.little,
            );
            idx += 2;
            remainingBits += 16;
          } else {
            newWord = source[idx];
            idx += 1;
            remainingBits += 8;
          }
          mask |= (newWord << shiftAmount);
          mask &= mask64;
        }

        if (mask == 0) {
          return 0;
        }

        final int firstSetBit = _ctz(mask);
        final int nextMask = mask >> (firstSetBit + 1);
        final int opCode = (2 * firstSetBit) | (nextMask & 1);
        remainingBits -= (2 + firstSetBit);
        mask = nextMask >> 1;

        if (opCode == 0) {
          output[writeIndex] = 0;
          channelCount += 1;
          writeIndex += outputChannels;
        } else if (opCode <= 0xE) {
          final int bitActiveMask =
              ((mask & (1 << opCode)) != 0) ? -1 : 0;
          final int bitValueMask = (1 << opCode) - 1;
          final int bitValue = mask & bitValueMask;
          final int channelValue =
              (bitActiveMask & 1) +
              (bitActiveMask ^ (((1 << opCode) | bitValue) - 1));
          remainingBits -= (opCode + 1);
          mask >>= (opCode + 1);
          output[writeIndex] = _toInt16(channelValue);
          channelCount += 1;
          writeIndex += outputChannels;
        } else if (opCode == 0xF) {
          final int zeroFill = (mask & 0x7F) + 8;
          remainingBits -= 7;
          mask >>= 7;
          for (int i = 0; i < zeroFill; i++) {
            output[writeIndex + i * outputChannels] = 0;
          }
          channelCount += zeroFill;
          writeIndex += outputChannels * zeroFill;
        } else {
          return 0;
        }

        if (channelCount >= pixelCount) {
          break;
        }
      }
    }

    if (inputChannels < outputChannels) {
      for (int channel = inputChannels;
          channel < outputChannels;
          channel++) {
        int writeIndex = channel;
        for (int i = 0; i < pixelCount; i++) {
          output[writeIndex] = 0;
          writeIndex += outputChannels;
        }
      }
    }

    final int totalRead = idx - offset;
    final int remainingBytes = remainingBits ~/ 8;
    return totalRead - remainingBytes;
  }

  static void _deltaUnpackRow16Bpc({
    required Uint32List dest,
    required Uint32List previousRow,
    required Int16List deltaRow,
    required int pixelCount,
  }) {
    final List<int> sum16 = <int>[0, 0, 0, 0];
    final List<int> prevRowPixel = <int>[0, 0, 0, 0];

    for (int i = 0; i < pixelCount; i++) {
      final int prevPixel = previousRow[i];
      final List<int> curPrev = <int>[
        prevPixel & 0xFF,
        (prevPixel >> 8) & 0xFF,
        (prevPixel >> 16) & 0xFF,
        (prevPixel >> 24) & 0xFF,
      ];

      for (int c = 0; c < 4; c++) {
        int value = (sum16[c] + curPrev[c]) & 0xFFFF;
        value = _subSaturate(value, prevRowPixel[c]);
        value = _addSaturate(value, 0xFF00);
        value = _subSaturate(value, 0xFF00);
        final int delta = deltaRow[i * 4 + c];
        value = _addSaturateSigned(value, delta);
        sum16[c] = value;
      }

      int pixel = 0;
      for (int c = 0; c < 4; c++) {
        int channel = sum16[c];
        if (channel > 0xFF) {
          channel = 0xFF;
        }
        pixel |= (channel & 0xFF) << (8 * c);
      }
      dest[i] = pixel;
      prevRowPixel
        ..[0] = curPrev[0]
        ..[1] = curPrev[1]
        ..[2] = curPrev[2]
        ..[3] = curPrev[3];
    }
  }

  static Int16List _deltaPackRow16Bpc(
    Uint32List currentRow,
    Uint32List previousRow,
    int pixelCount,
  ) {
    final Int16List deltas = Int16List(pixelCount * 4);
    final List<int> sum16 = <int>[0, 0, 0, 0];
    final List<int> prevRowPixel = <int>[0, 0, 0, 0];

    for (int i = 0; i < pixelCount; i++) {
      final int prevPixel = previousRow[i];
      final List<int> curPrev = <int>[
        prevPixel & 0xFF,
        (prevPixel >> 8) & 0xFF,
        (prevPixel >> 16) & 0xFF,
        (prevPixel >> 24) & 0xFF,
      ];

      final int pixel = currentRow[i];
      final List<int> target = <int>[
        pixel & 0xFF,
        (pixel >> 8) & 0xFF,
        (pixel >> 16) & 0xFF,
        (pixel >> 24) & 0xFF,
      ];

      for (int c = 0; c < 4; c++) {
        int base = (sum16[c] + curPrev[c]) & 0xFFFF;
        base = _subSaturate(base, prevRowPixel[c]);
        base = _addSaturate(base, 0xFF00);
        base = _subSaturate(base, 0xFF00);

        final int delta = target[c] - base;
        deltas[i * 4 + c] = _toInt16(delta);
        sum16[c] = (base + delta) & 0xFFFF;
      }

      prevRowPixel
        ..[0] = curPrev[0]
        ..[1] = curPrev[1]
        ..[2] = curPrev[2]
        ..[3] = curPrev[3];
    }

    return deltas;
  }

  static Uint8List _packDeltaRle16(
    Int16List deltaRow,
    int pixelCount,
    int outputChannels,
    int inputChannels,
  ) {
    final _BitWriter writer = _BitWriter();
    for (int channel = 0; channel < inputChannels; channel++) {
      int index = 0;
      while (index < pixelCount) {
        final int value = deltaRow[index * outputChannels + channel];
        if (value == 0) {
          int run = 1;
          while (index + run < pixelCount &&
              deltaRow[(index + run) * outputChannels + channel] == 0 &&
              run < 135) {
            run++;
          }
          if (run >= 8) {
            _writeOpcode(writer, 0xF);
            writer.writeBits(run - 8, 7);
            index += run;
            continue;
          } else {
            for (int i = 0; i < run; i++) {
              _writeOpcode(writer, 0);
            }
            index += run;
            continue;
          }
        }

        _writeValue(writer, value);
        index += 1;
      }
    }
    return writer.toBytes();
  }

  static void _writeValue(_BitWriter writer, int value) {
    if (value == 0) {
      _writeOpcode(writer, 0);
      return;
    }
    final int absValue = value.abs();
    int op = (absValue + 1).bitLength - 1;
    if (op > 14) {
      op = 14;
    }
    _writeOpcode(writer, op);
    final int magnitude = absValue - ((1 << op) - 1);
    writer.writeBits(magnitude, op);
    writer.writeBits(value < 0 ? 1 : 0, 1);
  }

  static void _writeOpcode(_BitWriter writer, int op) {
    final int zeros = op >> 1;
    if (zeros > 0) {
      writer.writeZeros(zeros);
    }
    writer.writeBits(1, 1);
    writer.writeBits(op & 1, 1);
  }

  static int _ctz(int value) {
    if (value == 0) {
      return 0;
    }
    final int isolated = value & -value;
    return isolated.bitLength - 1;
  }


  static int _toInt16(int value) {
    int v = value & 0xFFFF;
    if (v & 0x8000 != 0) {
      v = v - 0x10000;
    }
    return v;
  }

  static int _addSaturate(int a, int b) {
    final int sum = a + b;
    return sum > 0xFFFF ? 0xFFFF : sum;
  }

  static int _addSaturateSigned(int a, int b) {
    int sum = a + b;
    if (sum < 0) {
      sum = 0;
    } else if (sum > 0xFFFF) {
      sum = 0xFFFF;
    }
    return sum;
  }

  static int _subSaturate(int a, int b) {
    final int diff = a - b;
    return diff < 0 ? 0 : diff;
  }
}

class Sai2Header {
  Sai2Header({
    required this.flags0,
    required this.canvasBackgroundFlags,
    required this.flags2,
    required this.flags3,
    required this.width,
    required this.height,
    required this.printingResolution,
    required this.tableCount,
    required this.selectedLayer,
    required this.backgroundColor,
    required this.layerEffectColor,
  });

  static const int byteSize = 64;

  final int flags0;
  final int canvasBackgroundFlags;
  final int flags2;
  final int flags3;
  final int width;
  final int height;
  final int printingResolution;
  final int tableCount;
  final int selectedLayer;
  final int backgroundColor;
  final int layerEffectColor;

  int get channelCount => (canvasBackgroundFlags & 7) == 0 ? 4 : 3;

  static Sai2Header read(_ByteReader reader) {
    final String ident = reader.readAscii(16);
    if (ident != 'SAI-CANVAS-TYPE0') {
      throw UnsupportedError('不是有效的 SAI2 文件。');
    }
    final int flags0 = reader.readUint8();
    final int backgroundFlags = reader.readUint8();
    final int flags2 = reader.readUint8();
    final int flags3 = reader.readUint8();
    final int width = reader.readUint32();
    final int height = reader.readUint32();
    final int printingResolution = reader.readUint32();
    final int tableCount = reader.readUint32();
    final int selectedLayer = reader.readUint32();
    reader.readUint64();
    reader.readUint64();
    final int backgroundColor = reader.readUint32();
    final int layerEffect = reader.readUint32();
    return Sai2Header(
      flags0: flags0,
      canvasBackgroundFlags: backgroundFlags,
      flags2: flags2,
      flags3: flags3,
      width: width,
      height: height,
      printingResolution: printingResolution,
      tableCount: tableCount,
      selectedLayer: selectedLayer,
      backgroundColor: backgroundColor,
      layerEffectColor: layerEffect,
    );
  }
}

class Sai2Entry {
  Sai2Entry({
    required this.type,
    required this.layerId,
    required this.offset,
  });

  static const int byteSize = 16;

  final String type;
  final int layerId;
  final int offset;

  static Sai2Entry read(_ByteReader reader) {
    final String type = reader.readAscii(4);
    final int layerId = reader.readUint32();
    final int offset = reader.readUint64();
    return Sai2Entry(type: type, layerId: layerId, offset: offset);
  }
}

class _Chunk {
  _Chunk({required this.type, required this.layerId, required this.data});

  final String type;
  final int layerId;
  final Uint8List data;
  int offset = 0;
}

class _Sai2LayerInfo {
  _Sai2LayerInfo({
    required this.layerId,
    required this.name,
    required this.tileCount,
    required this.blendMode,
    required this.opacity,
    required this.visible,
    required this.layerType,
  });

  final int layerId;
  final String name;
  final int tileCount;
  final String blendMode;
  final double opacity;
  final bool visible;
  final String layerType;
}

class _ByteReader {
  _ByteReader(this._bytes) : _data = ByteData.sublistView(_bytes);

  final Uint8List _bytes;
  final ByteData _data;
  int _offset = 0;

  int get offset => _offset;
  int get remaining => _bytes.length - _offset;

  int readUint8() => _data.getUint8(_offset++);

  int readUint16() {
    final int value = _data.getUint16(_offset, Endian.little);
    _offset += 2;
    return value;
  }

  int readUint32() {
    final int value = _data.getUint32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  int readInt32() {
    final int value = _data.getInt32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  int readUint64() {
    final int value = _data.getUint64(_offset, Endian.little);
    _offset += 8;
    return value;
  }

  Uint8List readBytes(int count) {
    final Uint8List slice = _bytes.sublist(_offset, _offset + count);
    _offset += count;
    return slice;
  }

  String readAscii(int count) {
    final String value = String.fromCharCodes(
      _bytes.sublist(_offset, _offset + count),
    );
    _offset += count;
    return value;
  }
}

class _ByteWriter {
  final BytesBuilder _builder = BytesBuilder();

  void writeUint8(int value) {
    _builder.addByte(value & 0xFF);
  }

  void writeUint16(int value) {
    _builder.addByte(value & 0xFF);
    _builder.addByte((value >> 8) & 0xFF);
  }

  void writeUint32(int value) {
    _builder.addByte(value & 0xFF);
    _builder.addByte((value >> 8) & 0xFF);
    _builder.addByte((value >> 16) & 0xFF);
    _builder.addByte((value >> 24) & 0xFF);
  }

  void writeInt32(int value) {
    writeUint32(value);
  }

  void writeUint64(int value) {
    for (int i = 0; i < 8; i++) {
      _builder.addByte((value >> (8 * i)) & 0xFF);
    }
  }

  void writeAscii(String value, {int? length}) {
    final List<int> bytes = value.codeUnits;
    if (length != null) {
      final List<int> padded = List<int>.filled(length, 0);
      for (int i = 0; i < math.min(length, bytes.length); i++) {
        padded[i] = bytes[i];
      }
      _builder.add(padded);
    } else {
      _builder.add(bytes);
    }
  }

  void writeBytes(Uint8List bytes) {
    _builder.add(bytes);
  }

  Uint8List toBytes() => _builder.toBytes();
}

class _BitWriter {
  final BytesBuilder _builder = BytesBuilder();
  int _buffer = 0;
  int _bits = 0;

  void writeZeros(int count) {
    _bits += count;
    while (_bits >= 8) {
      _builder.addByte(_buffer & 0xFF);
      _buffer >>= 8;
      _bits -= 8;
    }
  }

  void writeBits(int value, int count) {
    if (count <= 0) {
      return;
    }
    _buffer |= (value << _bits);
    _bits += count;
    while (_bits >= 8) {
      _builder.addByte(_buffer & 0xFF);
      _buffer >>= 8;
      _bits -= 8;
    }
  }

  Uint8List toBytes() {
    if (_bits > 0) {
      _builder.addByte(_buffer & 0xFF);
      _buffer = 0;
      _bits = 0;
    }
    return _builder.toBytes();
  }
}
