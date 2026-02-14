import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import '../../canvas/blend_mode_utils.dart';
import '../../canvas/canvas_layer.dart';
import '../../canvas/canvas_settings.dart';
import '../../src/rust/frb_generated.dart';
import '../../src/rust/rust_init.dart';
import '../project/project_document.dart';

/// 使用 PSD 解析器解析 PSD，并转换为 `ProjectDocument`。
///
/// 目前仅支持 8bit RGB PSD（8BPS v1）。
class PsdImporter {
  const PsdImporter();

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
    final String resolvedName = displayName ?? 'PSD 项目';
    await ensureRustInitialized();

    try {
      // NOTE: 这里故意用 dynamic 调用，避免在你尚未运行
      // flutter_rust_bridge_codegen 时直接编译报错。
      // ignore: invalid_use_of_internal_member
      final dynamic api = RustLib.instance.api;
      final dynamic result = await api.crateApiPsdImportPsd(bytes: data);
      return _buildProjectFromPsdResult(result, displayName: resolvedName);
    } on NoSuchMethodError catch (_) {
      throw UnsupportedError(
        'PSD 导入器接口未生成；请在所有任务完成后运行 flutter_rust_bridge_codegen。',
      );
    }
  }

  ProjectDocument _buildProjectFromPsdResult(
    dynamic result, {
    required String displayName,
  }) {
    final int width = result.width as int;
    final int height = result.height as int;
    final List<dynamic> layers = result.layers as List<dynamic>;

    final DateTime now = DateTime.now();
    final CanvasSettings settings = CanvasSettings(
      width: width.toDouble(),
      height: height.toDouble(),
      backgroundColor: const Color(0xFFFFFFFF),
      creationLogic: CanvasCreationLogic.multiThread,
    );

    final ProjectDocument base = ProjectDocument.newProject(
      settings: settings,
      name: displayName,
    );

    final List<CanvasLayerData> canvasLayers = <CanvasLayerData>[];
    // PSD 解析器返回的图层顺序是“自上而下”（顶层在前），而项目内部 layers
    // 使用“自下而上”（底层在前，顶层在后）。这里需要反转以保证导入后叠放顺序一致。
    for (final dynamic layer in layers.reversed) {
      final String name = layer.name as String;
      final bool visible = layer.visible as bool;
      final int opacity = layer.opacity as int;

      final bool clippingMask = _readCompatField<bool>(
        layer,
        (dynamic it) => it.clippingMask as bool,
        (dynamic it) => it.clipping_mask as bool,
      );
      final String blendModeKey = _readCompatField<String>(
        layer,
        (dynamic it) => it.blendModeKey as String,
        (dynamic it) => it.blend_mode_key as String,
      );

      final Uint8List bitmap = layer.bitmap as Uint8List;
      final int bitmapWidth = _readCompatField<int>(
        layer,
        (dynamic it) => it.bitmapWidth as int,
        (dynamic it) => it.bitmap_width as int,
      );
      final int bitmapHeight = _readCompatField<int>(
        layer,
        (dynamic it) => it.bitmapHeight as int,
        (dynamic it) => it.bitmap_height as int,
      );
      final int bitmapLeft = _readCompatField<int>(
        layer,
        (dynamic it) => it.bitmapLeft as int,
        (dynamic it) => it.bitmap_left as int,
      );
      final int bitmapTop = _readCompatField<int>(
        layer,
        (dynamic it) => it.bitmapTop as int,
        (dynamic it) => it.bitmap_top as int,
      );

      if (bitmapWidth <= 0 || bitmapHeight <= 0) {
        continue;
      }
      if (bitmap.length != bitmapWidth * bitmapHeight * 4) {
        continue;
      }

      canvasLayers.add(
        CanvasLayerData(
          id: generateLayerId(),
          name: name.isEmpty ? 'PSD 图层' : name,
          visible: visible,
          opacity: opacity / 255.0,
          clippingMask: clippingMask,
          blendMode: CanvasLayerBlendModeX.fromPsdKey(blendModeKey),
          bitmap: bitmap,
          bitmapWidth: bitmapWidth,
          bitmapHeight: bitmapHeight,
          bitmapLeft: bitmapLeft,
          bitmapTop: bitmapTop,
          cloneBitmap: false,
        ),
      );
    }

    if (canvasLayers.isEmpty) {
      canvasLayers.add(
        CanvasLayerData(
          id: generateLayerId(),
          name: 'PSD 图层',
          bitmap: Uint8List(width * height * 4),
          bitmapWidth: width,
          bitmapHeight: height,
          cloneBitmap: false,
        ),
      );
    }

    return base.copyWith(
      layers: canvasLayers,
      createdAt: now,
      updatedAt: now,
      previewBytes: null,
      path: null,
    );
  }

  T _readCompatField<T>(
    dynamic obj,
    T Function(dynamic obj) camelGetter,
    T Function(dynamic obj) snakeGetter,
  ) {
    try {
      return camelGetter(obj);
    } catch (_) {
      return snakeGetter(obj);
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
