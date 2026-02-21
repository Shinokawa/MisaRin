import 'dart:typed_data';
import 'dart:ui';

import 'package:misa_rin/utils/io_shim.dart';

import '../../canvas/canvas_layer.dart';
import '../../canvas/canvas_settings.dart';
import '../project/project_document.dart';
import 'sai2_codec.dart';

class Sai2Importer {
  const Sai2Importer();

  Future<ProjectDocument> importFile(String path, {String? displayName}) async {
    final Uint8List data = await File(path).readAsBytes();
    return importBytes(
      data,
      displayName: displayName ?? _nameFromPath(path),
    );
  }

  Future<ProjectDocument> importBytes(
    Uint8List data, {
    String? displayName,
  }) async {
    final String resolvedName = displayName ?? 'SAI2 项目';
    final Sai2DecodedImage decoded = Sai2Codec.decodeFromBytes(data);

    final CanvasSettings settings = CanvasSettings(
      width: decoded.width.toDouble(),
      height: decoded.height.toDouble(),
      backgroundColor: const Color(0xFFFFFFFF),
      creationLogic: CanvasCreationLogic.multiThread,
    );

    final ProjectDocument base = ProjectDocument.newProject(
      settings: settings,
      name: resolvedName,
    );

    final List<CanvasLayerData> layers = <CanvasLayerData>[];
    if (decoded.layers.isNotEmpty) {
      for (final Sai2DecodedLayer layer in decoded.layers) {
        layers.add(
          CanvasLayerData(
            id: generateLayerId(),
            name: layer.name.isEmpty ? resolvedName : layer.name,
            bitmap: layer.rgbaBytes,
            bitmapWidth: layer.width,
            bitmapHeight: layer.height,
            opacity: layer.opacity,
            blendMode: _mapBlendMode(layer.blendMode),
            visible: layer.visible,
            cloneBitmap: false,
          ),
        );
      }
    } else {
      layers.add(
        CanvasLayerData(
          id: generateLayerId(),
          name: resolvedName,
          bitmap: decoded.rgbaBytes,
          bitmapWidth: decoded.width,
          bitmapHeight: decoded.height,
          cloneBitmap: false,
        ),
      );
    }

    final DateTime now = DateTime.now();
    return base.copyWith(
      layers: layers,
      createdAt: now,
      updatedAt: now,
      previewBytes: null,
      path: null,
    );
  }

  CanvasLayerBlendMode _mapBlendMode(String mode) {
    switch (mode) {
      case 'scrn':
        return CanvasLayerBlendMode.screen;
      case 'over':
        return CanvasLayerBlendMode.overlay;
      case 'ddge':
        return CanvasLayerBlendMode.colorDodge;
      case 'mul ':
        return CanvasLayerBlendMode.multiply;
      case 'norm':
      default:
        return CanvasLayerBlendMode.normal;
    }
  }

  String _nameFromPath(String path) {
    final String base = path.split(Platform.pathSeparator).last;
    final int index = base.lastIndexOf('.');
    if (index <= 0) {
      return base;
    }
    return base.substring(0, index);
  }
}
