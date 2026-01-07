part of 'painting_board.dart';

const String _kSteveReferenceModelAsset =
    'assets/bedrock_models/armor_steve.json';
const String _kAlexReferenceModelAsset =
    'assets/bedrock_models/armor_alex.json';
const String _kReferenceModelAnimationAsset =
    'assets/bedrock_models/dfsteve_armor.animation.json';

const double _referenceModelCardWidth = 420;
const double _referenceModelViewportHeight = 320;

const String _kReferenceModelActionNone = '__none__';

enum _ReferenceModelActionType { none, pose, animation }

class _ReferenceModelActionSeed {
  const _ReferenceModelActionSeed({
    required this.id,
    required this.label,
    required this.type,
    required this.order,
  });

  final String id;
  final String label;
  final _ReferenceModelActionType type;
  final int order;
}

const List<_ReferenceModelActionSeed> _kReferenceModelActionSeeds =
    <_ReferenceModelActionSeed>[
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.default_pose',
        label: '站立',
        type: _ReferenceModelActionType.pose,
        order: 0,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.kawaii',
        label: '坐',
        type: _ReferenceModelActionType.pose,
        order: 1,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.solemn_pose',
        label: '肃立',
        type: _ReferenceModelActionType.pose,
        order: 2,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.brandish_pose',
        label: '挥舞',
        type: _ReferenceModelActionType.pose,
        order: 3,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.honor_pose',
        label: '荣耀',
        type: _ReferenceModelActionType.pose,
        order: 4,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.entertain_pose',
        label: '拥抱',
        type: _ReferenceModelActionType.pose,
        order: 5,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.salute_pose',
        label: '欢迎',
        type: _ReferenceModelActionType.pose,
        order: 6,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.zombie_pose',
        label: '僵尸',
        type: _ReferenceModelActionType.pose,
        order: 7,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.cancan_a_pose',
        label: '康康舞a',
        type: _ReferenceModelActionType.pose,
        order: 8,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.cancan_b_pose',
        label: '康康舞b',
        type: _ReferenceModelActionType.pose,
        order: 9,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.hero_pose',
        label: '英雄',
        type: _ReferenceModelActionType.pose,
        order: 10,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.athena_pose',
        label: '雅典娜',
        type: _ReferenceModelActionType.pose,
        order: 11,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.wiggle',
        label: '立正',
        type: _ReferenceModelActionType.pose,
        order: 12,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.riposte_pose',
        label: '耍酷',
        type: _ReferenceModelActionType.pose,
        order: 13,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.qitao_pose',
        label: '卖萌',
        type: _ReferenceModelActionType.pose,
        order: 14,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.hello_pose',
        label: '打招呼',
        type: _ReferenceModelActionType.pose,
        order: 15,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.jojo_pose',
        label: 'JOJO立',
        type: _ReferenceModelActionType.pose,
        order: 16,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.dontstop_pose',
        label: '不要停下来',
        type: _ReferenceModelActionType.pose,
        order: 17,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.bata_pose',
        label: '异议！！',
        type: _ReferenceModelActionType.pose,
        order: 18,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.sneak_pose',
        label: '潜行',
        type: _ReferenceModelActionType.pose,
        order: 19,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.sleep_pose',
        label: '睡觉',
        type: _ReferenceModelActionType.pose,
        order: 20,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.sleep2_pose',
        label: '侧躺',
        type: _ReferenceModelActionType.pose,
        order: 21,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.houbunjump_pose',
        label: '芳文跳',
        type: _ReferenceModelActionType.pose,
        order: 22,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.yee_pose',
        label: '四脚着地',
        type: _ReferenceModelActionType.pose,
        order: 23,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.run_pose',
        label: '奔跑',
        type: _ReferenceModelActionType.pose,
        order: 24,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.saber_pose',
        label: '拔剑',
        type: _ReferenceModelActionType.pose,
        order: 25,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.dame',
        label: '拦截',
        type: _ReferenceModelActionType.pose,
        order: 26,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.down',
        label: '后仰撑地',
        type: _ReferenceModelActionType.pose,
        order: 27,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.move',
        label: '奔跑',
        type: _ReferenceModelActionType.animation,
        order: 100,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.stop',
        label: '立正',
        type: _ReferenceModelActionType.animation,
        order: 101,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.armor.swim',
        label: '游泳',
        type: _ReferenceModelActionType.animation,
        order: 102,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.armor.shoot',
        label: '射击',
        type: _ReferenceModelActionType.animation,
        order: 103,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.anime_sneak',
        label: '潜行',
        type: _ReferenceModelActionType.animation,
        order: 104,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.anime_eat',
        label: '吃东西',
        type: _ReferenceModelActionType.animation,
        order: 105,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.anime_omedetou',
        label: '鼓掌',
        type: _ReferenceModelActionType.animation,
        order: 106,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.anime_agree',
        label: '点头',
        type: _ReferenceModelActionType.animation,
        order: 107,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.anime_disagree',
        label: '摇头',
        type: _ReferenceModelActionType.animation,
        order: 108,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.anime_loop',
        label: '大风车',
        type: _ReferenceModelActionType.animation,
        order: 109,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.anime_hunbunjump',
        label: '芳文跳',
        type: _ReferenceModelActionType.animation,
        order: 110,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.anime_nani',
        label: '上下转',
        type: _ReferenceModelActionType.animation,
        order: 111,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.anime_nani2',
        label: '左右转',
        type: _ReferenceModelActionType.animation,
        order: 112,
      ),
      _ReferenceModelActionSeed(
        id: 'animation.dfsteve_armor.anime_head',
        label: '分头行动',
        type: _ReferenceModelActionType.animation,
        order: 113,
      ),
    ];

class _ReferenceModelActionItem {
  const _ReferenceModelActionItem({
    required this.id,
    required this.label,
    required this.type,
    required this.isAnimated,
    required this.order,
  });

  final String id;
  final String label;
  final _ReferenceModelActionType type;
  final bool isAnimated;
  final int order;
}

class _ReferenceModelActionCatalog {
  const _ReferenceModelActionCatalog({required this.items, required this.byId});

  final List<_ReferenceModelActionItem> items;
  final Map<String, _ReferenceModelActionItem> byId;
}

class _ReferenceModelCardEntry {
  _ReferenceModelCardEntry({
    required this.id,
    required this.title,
    required this.modelMesh,
    required this.offset,
  });

  final int id;
  final String title;
  final BedrockModelMesh modelMesh;
  Offset offset;
  Size? size;
}

mixin _PaintingBoardReferenceModelMixin on _PaintingBoardBase {
  final List<_ReferenceModelCardEntry> _referenceModelCards =
      <_ReferenceModelCardEntry>[];
  int _referenceModelCardSerial = 0;

  ui.Image? _referenceModelTexture;
  bool _referenceModelTextureLoading = false;
  bool _referenceModelTextureDirty = false;
  bool _referenceModelTextureSyncScheduled = false;
  int? _referenceModelTextureLastAppliedGeneration;

  final List<ui.Image> _referenceModelTexturePendingDisposals = <ui.Image>[];
  bool _referenceModelTextureDisposalScheduled = false;

  bool _referenceModelImportInProgress = false;
  bool _referenceModelBuiltinLoadInProgress = false;

  Future<void> showSteveReferenceModelCard() async {
    await _openReferenceModelFromAsset(
      _kSteveReferenceModelAsset,
      title: 'Steve模型',
    );
  }

  Future<void> showAlexReferenceModelCard() async {
    await _openReferenceModelFromAsset(
      _kAlexReferenceModelAsset,
      title: 'Alex模型',
    );
  }

  Future<void> importReferenceModelCard() async {
    if (_referenceModelImportInProgress) {
      AppNotifications.show(
        context,
        message: '正在导入模型，请稍候…',
        severity: InfoBarSeverity.info,
      );
      return;
    }
    _referenceModelImportInProgress = true;
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: '导入模型',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: kIsWeb,
      );
      final PlatformFile? file = result?.files.singleOrNull;
      if (!mounted || file == null) {
        return;
      }
      final Uint8List? bytes = file.bytes;
      final String? path = kIsWeb ? null : file.path;
      Uint8List? jsonBytes = bytes;
      if (jsonBytes == null && path != null) {
        jsonBytes = await File(path).readAsBytes();
      }
      if (jsonBytes == null) {
        AppNotifications.show(
          context,
          message: '无法读取模型文件内容。',
          severity: InfoBarSeverity.error,
        );
        return;
      }
      await _openReferenceModelFromJsonBytes(
        jsonBytes,
        sourcePath: path,
        title: file.name.isNotEmpty ? file.name : '导入模型',
      );
      AppNotifications.show(
        context,
        message: '已导入模型${file.name.isNotEmpty ? '：${file.name}' : ''}',
        severity: InfoBarSeverity.success,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to import reference model: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      AppNotifications.show(
        context,
        message: '导入模型失败。',
        severity: InfoBarSeverity.error,
      );
    } finally {
      _referenceModelImportInProgress = false;
    }
  }

  Future<void> _openReferenceModelFromAsset(
    String asset, {
    required String title,
  }) async {
    if (_referenceModelBuiltinLoadInProgress) {
      AppNotifications.show(
        context,
        message: '正在加载模型，请稍候…',
        severity: InfoBarSeverity.info,
      );
      return;
    }
    _referenceModelBuiltinLoadInProgress = true;
    try {
      final String text = await rootBundle.loadString(asset);
      final BedrockGeometryModel? geometry =
          BedrockGeometryModel.tryParseFromJsonText(text);
      if (geometry == null) {
        if (!mounted) return;
        AppNotifications.show(
          context,
          message: '内置模型格式无效：$asset',
          severity: InfoBarSeverity.error,
        );
        return;
      }
      final BedrockModelMesh modelMesh = buildBedrockModelMesh(geometry);
      await _ensureReferenceModelTexture();
      if (!mounted) return;
      _insertReferenceModelCard(title: title, modelMesh: modelMesh);
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to load built-in reference model: $error\n$stackTrace',
      );
      if (!mounted) {
        return;
      }
      AppNotifications.show(
        context,
        message: '加载模型失败。',
        severity: InfoBarSeverity.error,
      );
    } finally {
      _referenceModelBuiltinLoadInProgress = false;
    }
  }

  Future<void> _openReferenceModelFromJsonBytes(
    Uint8List jsonBytes, {
    required String title,
    String? sourcePath,
  }) async {
    final BedrockModelMesh modelMesh = await _loadBedrockModelMeshFromAnyJson(
      jsonBytes,
      sourcePath: sourcePath,
    );
    await _ensureReferenceModelTexture();
    if (!mounted) {
      return;
    }
    _insertReferenceModelCard(title: title, modelMesh: modelMesh);
  }

  Future<BedrockModelMesh> _loadBedrockModelMeshFromAnyJson(
    Uint8List jsonBytes, {
    String? sourcePath,
  }) async {
    final String text = utf8.decode(jsonBytes, allowMalformed: true);
    final BedrockGeometryModel? geometry =
        BedrockGeometryModel.tryParseFromJsonText(text);
    if (geometry != null) {
      return buildBedrockModelMesh(geometry);
    }

    final Object? decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('Invalid JSON root');
    }
    final Map<String, Object?> root = decoded.cast<String, Object?>();
    final String? preferredGeometryId = _extractGeometryIdentifier(root);
    if (preferredGeometryId == null) {
      throw const FormatException(
        'Not a Bedrock geometry / client entity file',
      );
    }
    if (sourcePath == null || sourcePath.isEmpty || kIsWeb) {
      throw const FormatException(
        'Client entity JSON needs a file path to resolve geometry',
      );
    }
    final String? geometryPath = _resolveGeometryPath(
      sourcePath,
      preferredGeometryId,
    );
    if (geometryPath == null) {
      throw FormatException(
        '无法解析几何文件：$preferredGeometryId（请直接导入 geometry JSON）',
      );
    }
    final Uint8List geometryBytes = await File(geometryPath).readAsBytes();
    final String geometryText = utf8.decode(
      geometryBytes,
      allowMalformed: true,
    );
    final BedrockGeometryModel? resolved =
        BedrockGeometryModel.tryParseFromJsonText(
          geometryText,
          preferredIdentifier: preferredGeometryId,
        );
    if (resolved == null) {
      throw FormatException('几何文件中未找到：$preferredGeometryId');
    }
    return buildBedrockModelMesh(resolved);
  }

  String? _extractGeometryIdentifier(Map<String, Object?> root) {
    final Map<String, Object?>? clientEntity =
        root['minecraft:client_entity'] is Map
        ? (root['minecraft:client_entity'] as Map).cast<String, Object?>()
        : null;
    final Map<String, Object?>? description =
        clientEntity?['description'] is Map
        ? (clientEntity!['description'] as Map).cast<String, Object?>()
        : null;
    final Object? geometry = description?['geometry'];
    if (geometry is String) {
      return geometry.trim().isNotEmpty ? geometry.trim() : null;
    }
    if (geometry is Map) {
      final Map<String, Object?> entries = geometry.cast<String, Object?>();
      final Object? defaultGeo = entries['default'];
      if (defaultGeo is String && defaultGeo.trim().isNotEmpty) {
        return defaultGeo.trim();
      }
      for (final value in entries.values) {
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    return null;
  }

  String? _resolveGeometryPath(String sourcePath, String geometryId) {
    final String? root = _findResourcePackRoot(sourcePath);
    if (root == null) {
      return null;
    }
    String name = geometryId;
    if (name.startsWith('geometry.')) {
      name = name.substring('geometry.'.length);
    }
    final String guessed = p.join(root, 'models', 'entity', '$name.json');
    if (File(guessed).existsSync()) {
      return guessed;
    }

    final Directory dir = Directory(p.join(root, 'models', 'entity'));
    if (!dir.existsSync()) {
      return null;
    }
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! File) continue;
      if (p.extension(entity.path).toLowerCase() != '.json') continue;
      try {
        final String text = entity.readAsStringSync();
        final BedrockGeometryModel? parsed =
            BedrockGeometryModel.tryParseFromJsonText(
              text,
              preferredIdentifier: geometryId,
            );
        if (parsed != null) {
          return entity.path;
        }
      } catch (_) {
        // Ignore invalid JSON during scan.
      }
    }
    return null;
  }

  String? _findResourcePackRoot(String sourcePath) {
    String dir = p.dirname(sourcePath);
    for (int i = 0; i < 6; i++) {
      final Directory models = Directory(p.join(dir, 'models', 'entity'));
      if (models.existsSync()) {
        return dir;
      }
      final String next = p.dirname(dir);
      if (next == dir) {
        break;
      }
      dir = next;
    }
    return null;
  }

  Future<void> _ensureReferenceModelTexture() async {
    if (_referenceModelTexture != null) {
      return;
    }
    await _refreshReferenceModelTexture(showSuccessToast: false, force: true);
  }

  Future<void> _refreshReferenceModelTexture({
    bool showSuccessToast = true,
    bool force = false,
  }) async {
    if (_referenceModelCards.isEmpty && !force) {
      return;
    }
    if (_referenceModelTextureLoading) {
      _referenceModelTextureDirty = true;
      if (showSuccessToast) {
        AppNotifications.show(
          context,
          message: '正在更新模型贴图，请稍候…',
          severity: InfoBarSeverity.info,
        );
      }
      return;
    }
    final int? generation = _controller.frame?.generation;
    if (!force &&
        generation != null &&
        _referenceModelTexture != null &&
        _referenceModelTextureLastAppliedGeneration == generation) {
      _referenceModelTextureDirty = false;
      return;
    }
    // Clear the dirty flag now; if another change arrives while we are doing
    // work, the scheduler will mark it dirty again and re-run after completion.
    _referenceModelTextureDirty = false;
    _referenceModelTextureLoading = true;
    try {
      final ui.Image image = await _controller.snapshotImage();
      if (!mounted) {
        image.dispose();
        return;
      }
      final ui.Image? previous = _referenceModelTexture;
      setState(() {
        _referenceModelTexture = image;
      });
      _scheduleWorkspaceCardsOverlaySync();
      if (previous != null && !previous.debugDisposed) {
        _enqueueReferenceModelTextureDisposal(previous);
      }
      _referenceModelTextureLastAppliedGeneration = generation;
      if (showSuccessToast) {
        AppNotifications.show(
          context,
          message: '模型贴图已更新。',
          severity: InfoBarSeverity.success,
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to refresh reference model texture: $error\n$stackTrace',
      );
      if (!mounted) {
        return;
      }
      AppNotifications.show(
        context,
        message: '更新模型贴图失败。',
        severity: InfoBarSeverity.error,
      );
    } finally {
      _referenceModelTextureLoading = false;
      if (_referenceModelTextureDirty) {
        _scheduleReferenceModelTextureRefresh();
      }
    }
  }

  void _scheduleReferenceModelTextureRefresh() {
    if (_referenceModelCards.isEmpty) {
      return;
    }
    _referenceModelTextureDirty = true;
    if (_referenceModelTextureSyncScheduled) {
      return;
    }
    _referenceModelTextureSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _referenceModelTextureSyncScheduled = false;
      if (!mounted || _referenceModelCards.isEmpty) {
        return;
      }
      unawaited(_refreshReferenceModelTexture(showSuccessToast: false));
    });
  }

  void _enqueueReferenceModelTextureDisposal(ui.Image image) {
    _referenceModelTexturePendingDisposals.add(image);
    if (_referenceModelTextureDisposalScheduled) {
      return;
    }
    _referenceModelTextureDisposalScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _referenceModelTextureDisposalScheduled = false;
      if (_referenceModelTexturePendingDisposals.isEmpty) {
        return;
      }
      final List<ui.Image> pending = List<ui.Image>.from(
        _referenceModelTexturePendingDisposals,
      );
      _referenceModelTexturePendingDisposals.clear();
      for (final ui.Image image in pending) {
        if (!image.debugDisposed) {
          image.dispose();
        }
      }
    });
  }

  void _insertReferenceModelCard({
    required String title,
    required BedrockModelMesh modelMesh,
  }) {
    final int id = ++_referenceModelCardSerial;
    final Offset offset = _initialReferenceModelCardOffset();
    setState(() {
      _referenceModelCards.add(
        _ReferenceModelCardEntry(
          id: id,
          title: title,
          modelMesh: modelMesh,
          offset: offset,
        ),
      );
    });
    _scheduleWorkspaceCardsOverlaySync();
  }

  Offset _initialReferenceModelCardOffset() {
    final double stackOffset = _referenceModelCards.length * 28.0;
    return _workspacePanelSpawnOffset(
      this,
      panelWidth: _referenceModelCardWidth,
      panelHeight: _referenceModelViewportHeight + 120,
      additionalDy: stackOffset,
    );
  }

  void _closeReferenceModelCard(int id) {
    final int index = _referenceModelCards.indexWhere((card) => card.id == id);
    if (index < 0) {
      return;
    }
    final bool wasLast = _referenceModelCards.length == 1;
    final ui.Image? texture = wasLast ? _referenceModelTexture : null;
    setState(() {
      _referenceModelCards.removeAt(index);
      if (_referenceModelCards.isEmpty) {
        _referenceModelTexture = null;
      }
    });
    if (texture != null && !texture.debugDisposed) {
      _enqueueReferenceModelTextureDisposal(texture);
    }
    _scheduleWorkspaceCardsOverlaySync();
  }

  void _updateReferenceModelCardOffset(int id, Offset delta) {
    if (delta == Offset.zero) return;
    final _ReferenceModelCardEntry? entry = _referenceModelCardById(id);
    if (entry == null) return;
    setState(() {
      final Size size = entry.size ?? const Size(_referenceModelCardWidth, 420);
      entry.offset = _clampWorkspaceOffsetToViewport(
        this,
        entry.offset + delta,
        childSize: size,
        margin: 12,
      );
    });
    _scheduleWorkspaceCardsOverlaySync();
  }

  void _handleReferenceModelCardSizeChanged(int id, Size size) {
    final _ReferenceModelCardEntry? entry = _referenceModelCardById(id);
    if (entry == null) return;
    entry.size = size;
    final Offset clamped = _clampWorkspaceOffsetToViewport(
      this,
      entry.offset,
      childSize: size,
      margin: 12,
    );
    if (clamped == entry.offset) return;
    setState(() {
      entry.offset = clamped;
    });
    _scheduleWorkspaceCardsOverlaySync();
  }

  void _focusReferenceModelCard(int id) {
    final int index = _referenceModelCards.indexWhere((card) => card.id == id);
    if (index < 0 || index == _referenceModelCards.length - 1) return;
    setState(() {
      final _ReferenceModelCardEntry entry = _referenceModelCards.removeAt(
        index,
      );
      _referenceModelCards.add(entry);
    });
    _scheduleWorkspaceCardsOverlaySync();
  }

  _ReferenceModelCardEntry? _referenceModelCardById(int id) {
    for (final entry in _referenceModelCards) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  @override
  bool _isInsideReferenceModelCardArea(Offset workspacePosition) {
    for (final _ReferenceModelCardEntry entry in _referenceModelCards) {
      final Size size = entry.size ?? const Size(_referenceModelCardWidth, 420);
      final Rect rect = Rect.fromLTWH(
        entry.offset.dx,
        entry.offset.dy,
        size.width,
        size.height,
      );
      if (rect.contains(workspacePosition)) {
        return true;
      }
    }
    return false;
  }

  void _disposeReferenceModelCards() {
    for (final ui.Image image in _referenceModelTexturePendingDisposals) {
      if (!image.debugDisposed) {
        image.dispose();
      }
    }
    _referenceModelTexturePendingDisposals.clear();
    _referenceModelTextureDisposalScheduled = false;
    _referenceModelTextureSyncScheduled = false;
    _referenceModelTextureDirty = false;
    _referenceModelTextureLastAppliedGeneration = null;
    _referenceModelTexture?.dispose();
    _referenceModelTexture = null;
    _referenceModelCards.clear();
  }
}

class _ReferenceModelCard extends StatefulWidget {
  const _ReferenceModelCard({
    required super.key,
    required this.title,
    required this.modelMesh,
    required this.texture,
    required this.dialogContext,
    required this.onClose,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onRefreshTexture,
    required this.onSizeChanged,
  });

  final String title;
  final BedrockModelMesh modelMesh;
  final ui.Image? texture;
  final BuildContext dialogContext;
  final VoidCallback onClose;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onRefreshTexture;
  final ValueChanged<Size> onSizeChanged;

  @override
  State<_ReferenceModelCard> createState() => _ReferenceModelCardState();
}

class _ReferenceModelCardState extends State<_ReferenceModelCard>
    with TickerProviderStateMixin {
  static Future<BedrockAnimationLibrary?>? _animationLibraryFuture;
  static Future<_ReferenceModelActionCatalog?>? _actionCatalogFuture;

  double _yaw = math.pi / 4;
  double _pitch = -math.pi / 12;
  double _zoom = 1.0;
  bool _multiViewEnabled = false;

  late final AnimationController _actionController;
  BedrockAnimationLibrary? _animationLibrary;
  _ReferenceModelActionCatalog? _actionCatalog;
  String _selectedAction = _kReferenceModelActionNone;
  _ReferenceModelActionItem? _selectedActionItem;
  BedrockAnimation? _selectedAnimation;

  @override
  void initState() {
    super.initState();
    _actionController = AnimationController(vsync: this);
    unawaited(_ensureActionCatalog());
  }

  @override
  void dispose() {
    _actionController.dispose();
    super.dispose();
  }

  void _resetView() {
    setState(() {
      _yaw = math.pi / 4;
      _pitch = -math.pi / 12;
      _zoom = 1.0;
    });
  }

  void _toggleMultiView() {
    setState(() {
      _multiViewEnabled = !_multiViewEnabled;
    });
  }

  void _updateRotation(Offset delta) {
    setState(() {
      _yaw -= delta.dx * 0.01;
      _pitch = (_pitch - delta.dy * 0.01).clamp(-math.pi / 2, math.pi / 2);
    });
  }

  void _updateZoom(double delta) {
    setState(() {
      _zoom = (_zoom + delta).clamp(0.35, 6.0);
    });
  }

  Future<BedrockAnimationLibrary?> _ensureAnimationLibrary() async {
    if (_animationLibrary != null) {
      return _animationLibrary;
    }
    _animationLibraryFuture ??= () async {
      final String text = await rootBundle.loadString(
        _kReferenceModelAnimationAsset,
      );
      return BedrockAnimationLibrary.tryParseFromJsonText(text);
    }();

    final BedrockAnimationLibrary? library = await _animationLibraryFuture;
    if (!mounted) {
      return library;
    }
    setState(() {
      _animationLibrary = library;
      if (_selectedAnimation == null &&
          _selectedAction != _kReferenceModelActionNone) {
        _selectedAnimation = library?.animations[_selectedAction];
      }
    });
    return library;
  }

  String _formatActionName(String name) {
    const List<String> prefixes = <String>[
      'animation.dfsteve_armor.',
      'animation.armor.',
    ];
    for (final prefix in prefixes) {
      if (name.startsWith(prefix)) {
        return name.substring(prefix.length);
      }
    }
    return name;
  }

  Future<_ReferenceModelActionCatalog?> _ensureActionCatalog() async {
    final BedrockAnimationLibrary? library = await _ensureAnimationLibrary();
    if (library == null) {
      return null;
    }
    _actionCatalogFuture ??= _loadReferenceModelActionCatalog(library);
    final _ReferenceModelActionCatalog? catalog = await _actionCatalogFuture;
    if (!mounted) {
      return catalog;
    }
    setState(() {
      _actionCatalog = catalog;
      _selectedActionItem = catalog?.byId[_selectedAction];
      if (_selectedAction == _kReferenceModelActionNone) {
        _selectedAnimation = null;
      } else {
        _selectedAnimation ??= library.animations[_selectedAction];
      }
    });
    return catalog;
  }

  String _displayNameForActionId(String actionId) {
    if (actionId == _kReferenceModelActionNone) {
      return '无';
    }
    final _ReferenceModelActionItem? item = _actionCatalog?.byId[actionId];
    if (item != null) {
      return item.label;
    }
    return _formatActionName(actionId);
  }

  void _applySelectedAnimation() {
    _actionController.stop();
    if (_selectedAction == _kReferenceModelActionNone) {
      _actionController.value = 0;
      return;
    }

    final BedrockAnimation? animation = _selectedAnimation;
    if (animation == null) {
      _actionController.value = 0;
      return;
    }
    final bool shouldAnimate =
        _selectedActionItem?.isAnimated ?? animation.isDynamic;
    if (!shouldAnimate || animation.lengthSeconds <= 0) {
      _actionController.value = 0;
      return;
    }
    final int durationMs = math.max(
      1,
      (animation.lengthSeconds * 1000).round(),
    );
    _actionController.duration = Duration(milliseconds: durationMs);
    if (animation.loop) {
      _actionController.repeat();
    } else {
      _actionController.forward(from: 0);
    }
  }

  Future<void> _showActionDialog() async {
    final BedrockAnimationLibrary? library = await _ensureAnimationLibrary();
    final _ReferenceModelActionCatalog? catalog = await _ensureActionCatalog();
    if (!mounted) {
      return;
    }
    if (library == null || library.animations.isEmpty || catalog == null) {
      AppNotifications.show(
        context,
        message: '无法加载预览动作动画。',
        severity: InfoBarSeverity.error,
      );
      return;
    }

    String selection = catalog.byId.containsKey(_selectedAction)
        ? _selectedAction
        : _kReferenceModelActionNone;
    String query = '';

    final BuildContext dialogContext = widget.dialogContext;
    final ScrollController scrollController = ScrollController();
    final AnimationController previewController = AnimationController(
      vsync: this,
    );

    OverlayEntry? dialogEntry;
    Completer<String?>? dialogCompleter;

    void closeDialog([String? value]) {
      dialogEntry?.remove();
      dialogEntry = null;
      dialogCompleter?.complete(value);
      dialogCompleter = null;
    }

    void syncPreviewController({
      required _ReferenceModelActionItem? selectedItem,
      required BedrockAnimation? selectedAnimation,
    }) {
      previewController.stop();
      if (selection == _kReferenceModelActionNone ||
          selectedAnimation == null) {
        previewController.value = 0;
        return;
      }
      final bool shouldAnimate =
          selectedItem?.isAnimated ?? selectedAnimation.isDynamic;
      if (!shouldAnimate || selectedAnimation.lengthSeconds <= 0) {
        previewController.value = 0;
        return;
      }
      final int durationMs = math.max(
        1,
        (selectedAnimation.lengthSeconds * 1000).round(),
      );
      previewController.duration = Duration(milliseconds: durationMs);
      if (selectedAnimation.loop) {
        previewController.repeat();
      } else {
        previewController.forward(from: 0);
      }
    }

    final String? result;
    try {
      final OverlayState? overlay = Overlay.of(
        dialogContext,
        rootOverlay: true,
      );
      if (overlay == null) {
        return;
      }

      dialogCompleter = Completer<String?>();
      dialogEntry = OverlayEntry(
        builder: (BuildContext overlayContext) {
          final Color barrierColor = Colors.black.withValues(alpha: 0.35);
          return Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => closeDialog(),
                child: ColoredBox(color: barrierColor),
              ),
              Center(
                child: MisarinDialog(
                  title: const Text('切换动作'),
                  contentWidth: null,
                  maxWidth: 920,
                  content: StatefulBuilder(
                    builder: (BuildContext context, StateSetter setDialogState) {
                      final FluentThemeData theme = FluentTheme.of(context);
                      final Color border =
                          theme.resources.controlStrokeColorDefault;
                      final Color background = theme.brightness.isDark
                          ? const Color(0xFF101010)
                          : const Color(0xFFF7F7F7);
                      final double contentHeight = math.min(
                        700,
                        MediaQuery.of(context).size.height * 0.78,
                      );
                      final String trimmedQuery = query.trim();
                      final List<_ReferenceModelActionItem> visible = catalog
                          .items
                          .where((item) {
                            if (trimmedQuery.isEmpty) {
                              return true;
                            }
                            final String haystack = '${item.label}\n${item.id}'
                                .toLowerCase();
                            return haystack.contains(
                              trimmedQuery.toLowerCase(),
                            );
                          })
                          .toList(growable: false);

                      final List<_ReferenceModelActionItem> poses =
                          visible
                              .where(
                                (item) =>
                                    item.type == _ReferenceModelActionType.pose,
                              )
                              .toList()
                            ..sort((a, b) => a.order.compareTo(b.order));
                      final List<_ReferenceModelActionItem> animations =
                          visible
                              .where(
                                (item) =>
                                    item.type ==
                                    _ReferenceModelActionType.animation,
                              )
                              .toList()
                            ..sort((a, b) => a.order.compareTo(b.order));

                      final _ReferenceModelActionItem? selectedItem =
                          catalog.byId[selection];
                      final BedrockAnimation? selectedAnimation =
                          selection == _kReferenceModelActionNone
                          ? null
                          : library.animations[selection];
                      final bool selectedIsDynamic =
                          selectedItem?.isAnimated ??
                          selectedAnimation?.isDynamic ??
                          false;

                      Widget buildActionToggle(
                        _ReferenceModelActionItem item, {
                        required IconData icon,
                      }) {
                        final bool checked = selection == item.id;
                        return ToggleButton(
                          checked: checked,
                          onChanged: (value) {
                            if (!value) {
                              return;
                            }
                            setDialogState(() => selection = item.id);
                            syncPreviewController(
                              selectedItem: item,
                              selectedAnimation: library.animations[item.id],
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  item.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (item.isAnimated) ...[
                                  const SizedBox(width: 6),
                                  _buildActionTag(context, '动画'),
                                ],
                              ],
                            ),
                          ),
                        );
                      }

                      Widget buildSection(
                        String title,
                        List<_ReferenceModelActionItem> items, {
                        required IconData icon,
                      }) {
                        if (items.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 14),
                                const SizedBox(width: 8),
                                Text(
                                  '$title（${items.length}）',
                                  style: theme.typography.bodyStrong,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final item in items)
                                  buildActionToggle(item, icon: icon),
                              ],
                            ),
                          ],
                        );
                      }

                      Widget buildPreviewPanel() {
                        final String label =
                            selection == _kReferenceModelActionNone
                            ? '选择动作预览'
                            : _displayNameForActionId(selection);
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    FluentIcons.view,
                                    size: 14,
                                    color: selectedIsDynamic
                                        ? theme.accentColor.darkest
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: theme.typography.bodyStrong,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: background,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: border.withValues(
                                        alpha: border.a * 0.85,
                                      ),
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child:
                                      selection == _kReferenceModelActionNone ||
                                          selectedAnimation == null
                                      ? Center(
                                          child: Text(
                                            '选择一个动作以预览。',
                                            style: theme.typography.caption,
                                          ),
                                        )
                                      : SizedBox.expand(
                                          child: CustomPaint(
                                            painter: _BedrockModelPainter(
                                              baseModel: widget.modelMesh,
                                              modelTextureWidth: widget
                                                  .modelMesh
                                                  .model
                                                  .textureWidth,
                                              modelTextureHeight: widget
                                                  .modelMesh
                                                  .model
                                                  .textureHeight,
                                              texture: widget.texture,
                                              yaw: math.pi / 4,
                                              pitch: -math.pi / 12,
                                              zoom: 1.0,
                                              animation: selectedAnimation,
                                              animationController:
                                                  previewController,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              if (selection != _kReferenceModelActionNone) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (selectedItem != null)
                                      _buildActionTag(
                                        context,
                                        switch (selectedItem.type) {
                                          _ReferenceModelActionType.pose =>
                                            '姿势',
                                          _ReferenceModelActionType.animation =>
                                            '动画',
                                          _ReferenceModelActionType.none => '无',
                                        },
                                      ),
                                    if (selectedIsDynamic)
                                      _buildActionTag(context, '动画'),
                                    if (selectedAnimation?.loop == true)
                                      _buildActionTag(context, '循环'),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      return SizedBox(
                        height: contentHeight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextBox(
                              placeholder: '搜索动作…',
                              prefix: const Icon(FluentIcons.search, size: 14),
                              onChanged: (value) =>
                                  setDialogState(() => query = value),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Scrollbar(
                                      controller: scrollController,
                                      thumbVisibility: true,
                                      child: SingleChildScrollView(
                                        controller: scrollController,
                                        physics: const ClampingScrollPhysics(),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                ToggleButton(
                                                  checked:
                                                      selection ==
                                                      _kReferenceModelActionNone,
                                                  onChanged: (value) {
                                                    if (!value) {
                                                      return;
                                                    }
                                                    setDialogState(() {
                                                      selection =
                                                          _kReferenceModelActionNone;
                                                    });
                                                    syncPreviewController(
                                                      selectedItem: null,
                                                      selectedAnimation: null,
                                                    );
                                                  },
                                                  child: const Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 6,
                                                        ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          FluentIcons.clear,
                                                          size: 14,
                                                        ),
                                                        SizedBox(width: 6),
                                                        Text('无'),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            if (poses.isEmpty &&
                                                animations.isEmpty)
                                              Text(
                                                '没有匹配的动作。',
                                                style: theme.typography.caption,
                                              )
                                            else ...[
                                              buildSection(
                                                '姿势',
                                                poses,
                                                icon: FluentIcons.contact,
                                              ),
                                              if (animations.isNotEmpty) ...[
                                                const SizedBox(height: 16),
                                                buildSection(
                                                  '动画',
                                                  animations,
                                                  icon: FluentIcons.play,
                                                ),
                                              ],
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 320,
                                    child: buildPreviewPanel(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  actions: [
                    Button(
                      child: Text(dialogContext.l10n.cancel),
                      onPressed: () => closeDialog(),
                    ),
                    FilledButton(
                      child: Text(dialogContext.l10n.confirm),
                      onPressed: () => closeDialog(selection),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );

      overlay.insert(dialogEntry!);
      syncPreviewController(
        selectedItem: catalog.byId[selection],
        selectedAnimation: selection == _kReferenceModelActionNone
            ? null
            : library.animations[selection],
      );

      result = await dialogCompleter!.future;
    } finally {
      scrollController.dispose();
      previewController.dispose();
      closeDialog();
    }

    if (!mounted || result == null) {
      return;
    }

    final String selectedAction = result;
    setState(() {
      _selectedAction = selectedAction;
      _selectedActionItem = catalog.byId[selectedAction];
      _selectedAnimation = selectedAction == _kReferenceModelActionNone
          ? null
          : library.animations[selectedAction];
    });
    _applySelectedAnimation();
  }

  static Widget _buildActionTag(BuildContext context, String text) {
    final FluentThemeData theme = FluentTheme.of(context);
    final Color border = theme.resources.controlStrokeColorDefault.withValues(
      alpha: theme.resources.controlStrokeColorDefault.a * 0.7,
    );
    final Color background = theme.accentColor.lightest.withValues(alpha: 0.12);
    final Color foreground = theme.accentColor.darkest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: theme.typography.caption?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static Future<_ReferenceModelActionCatalog?> _loadReferenceModelActionCatalog(
    BedrockAnimationLibrary library,
  ) async {
    try {
      final Map<String, _ReferenceModelActionItem> byId =
          <String, _ReferenceModelActionItem>{};
      final List<_ReferenceModelActionItem> items =
          <_ReferenceModelActionItem>[];

      for (final _ReferenceModelActionSeed seed
          in _kReferenceModelActionSeeds) {
        if (byId.containsKey(seed.id)) {
          continue;
        }
        final BedrockAnimation? animation = library.animations[seed.id];
        if (animation == null) {
          continue;
        }
        final _ReferenceModelActionItem item = _ReferenceModelActionItem(
          id: seed.id,
          label: seed.label,
          type: seed.type,
          isAnimated: animation.isDynamic,
          order: seed.order,
        );
        items.add(item);
        byId[seed.id] = item;
      }

      return _ReferenceModelActionCatalog(
        items: List<_ReferenceModelActionItem>.unmodifiable(items),
        byId: Map<String, _ReferenceModelActionItem>.unmodifiable(byId),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to load reference model action catalog: $error\n$stackTrace',
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final Color border = theme.resources.controlStrokeColorDefault;
    final Color background = theme.brightness.isDark
        ? const Color(0xFF101010)
        : const Color(0xFFF7F7F7);
    final Color accent = theme.accentColor.defaultBrushFor(theme.brightness);
    final l10n = context.l10n;

    final Color gridLineColor = border.withValues(alpha: border.a * 0.55);

    Widget buildModelPaint({
      required double yaw,
      required double pitch,
      String? label,
    }) {
      Widget painted = _BedrockModelZBufferView(
        baseModel: widget.modelMesh,
        modelTextureWidth: widget.modelMesh.model.textureWidth,
        modelTextureHeight: widget.modelMesh.model.textureHeight,
        texture: widget.texture,
        yaw: yaw,
        pitch: pitch,
        zoom: _zoom,
        animation: _selectedAnimation,
        animationController: _actionController,
      );

      if (label != null && label.trim().isNotEmpty) {
        final Color chipBackground = theme.brightness.isDark
            ? const Color(0x99000000)
            : const Color(0xCCFFFFFF);
        final Color chipForeground = theme.brightness.isDark
            ? const Color(0xFFE6E6E6)
            : const Color(0xFF333333);
        painted = Stack(
          fit: StackFit.expand,
          children: [
            painted,
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: chipBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: border.withValues(alpha: border.a * 0.6),
                  ),
                ),
                child: Text(
                  label,
                  style: theme.typography.caption?.copyWith(
                    color: chipForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      }

      return SizedBox.expand(child: painted);
    }

    Widget buildModelViewport({
      required double height,
      required double yaw,
      required double pitch,
      String? label,
      bool interactive = false,
    }) {
      Widget painted = buildModelPaint(yaw: yaw, pitch: pitch, label: label);

      if (interactive) {
        painted = Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              _updateZoom(-event.scrollDelta.dy * 0.002);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: _resetView,
            onPanUpdate: (details) => _updateRotation(details.delta),
            child: painted,
          ),
        );
      }

      return Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: painted,
      );
    }

    return MeasuredSize(
      onChanged: widget.onSizeChanged,
      child: WorkspaceFloatingPanel(
        title: widget.title,
        width: _referenceModelCardWidth,
        headerActions: [
          HoverDetailTooltip(
            message: '动作',
            detail: _selectedAction == _kReferenceModelActionNone
                ? '切换预览动作'
                : '当前：${_displayNameForActionId(_selectedAction)}'
                      '${_selectedActionItem?.isAnimated == true ? '（动画）' : ''}',
            child: IconButton(
              icon: const Icon(FluentIcons.running, size: 14),
              iconButtonMode: IconButtonMode.small,
              style: ButtonStyle(
                padding: WidgetStateProperty.all(const EdgeInsets.all(4)),
              ),
              onPressed: _showActionDialog,
            ),
          ),
          HoverDetailTooltip(
            message: l10n.referenceModelRefreshTexture,
            detail: l10n.referenceModelRefreshTextureDesc,
            child: IconButton(
              icon: const Icon(FluentIcons.refresh, size: 14),
              iconButtonMode: IconButtonMode.small,
              style: ButtonStyle(
                padding: WidgetStateProperty.all(const EdgeInsets.all(4)),
              ),
              onPressed: widget.onRefreshTexture,
            ),
          ),
          HoverDetailTooltip(
            message: l10n.referenceModelResetView,
            detail: l10n.referenceModelResetViewDesc,
            child: IconButton(
              icon: const Icon(FluentIcons.reset, size: 14),
              iconButtonMode: IconButtonMode.small,
              style: ButtonStyle(
                padding: WidgetStateProperty.all(const EdgeInsets.all(4)),
              ),
              onPressed: _resetView,
            ),
          ),
          HoverDetailTooltip(
            message: _multiViewEnabled
                ? l10n.referenceModelSingleView
                : l10n.referenceModelSixView,
            detail: _multiViewEnabled
                ? l10n.referenceModelSingleViewDesc
                : l10n.referenceModelSixViewDesc,
            child: IconButton(
              icon: Icon(
                FluentIcons.picture,
                size: 14,
                color: _multiViewEnabled ? accent : null,
              ),
              iconButtonMode: IconButtonMode.small,
              style: ButtonStyle(
                padding: WidgetStateProperty.all(const EdgeInsets.all(4)),
              ),
              onPressed: _toggleMultiView,
            ),
          ),
        ],
        onClose: widget.onClose,
        onDragStart: widget.onDragStart,
        onDragUpdate: widget.onDragUpdate,
        onDragEnd: widget.onDragEnd,
        bodyPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        bodySpacing: 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_multiViewEnabled)
              buildModelViewport(
                height: _referenceModelViewportHeight,
                yaw: _yaw,
                pitch: _pitch,
                interactive: true,
              )
            else
              Container(
                height: _referenceModelViewportHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      _updateZoom(-event.scrollDelta.dy * 0.002);
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: _resetView,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(color: gridLineColor),
                                      bottom: BorderSide(color: gridLineColor),
                                    ),
                                  ),
                                  child: buildModelPaint(
                                    yaw: 0,
                                    pitch: 0,
                                    label: l10n.referenceModelViewFront,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(color: gridLineColor),
                                      bottom: BorderSide(color: gridLineColor),
                                    ),
                                  ),
                                  child: buildModelPaint(
                                    yaw: math.pi,
                                    pitch: 0,
                                    label: l10n.referenceModelViewBack,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(color: gridLineColor),
                                    ),
                                  ),
                                  child: buildModelPaint(
                                    yaw: 0,
                                    pitch: -math.pi / 2,
                                    label: l10n.referenceModelViewTop,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: gridLineColor),
                                    ),
                                  ),
                                  child: buildModelPaint(
                                    yaw: 0,
                                    pitch: math.pi / 2,
                                    label: l10n.referenceModelViewBottom,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: gridLineColor),
                                    ),
                                  ),
                                  child: buildModelPaint(
                                    yaw: -math.pi / 2,
                                    pitch: 0,
                                    label: l10n.referenceModelViewLeft,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: buildModelPaint(
                                  yaw: math.pi / 2,
                                  pitch: 0,
                                  label: l10n.referenceModelViewRight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(FluentIcons.search, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _zoom.clamp(0.35, 6.0),
                    min: 0.35,
                    max: 6.0,
                    onChanged: (value) => setState(() => _zoom = value),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BedrockModelZBufferView extends StatefulWidget {
  const _BedrockModelZBufferView({
    required this.baseModel,
    required this.modelTextureWidth,
    required this.modelTextureHeight,
    required this.texture,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.animation,
    required this.animationController,
  });

  final BedrockModelMesh baseModel;
  final int modelTextureWidth;
  final int modelTextureHeight;
  final ui.Image? texture;
  final double yaw;
  final double pitch;
  final double zoom;
  final BedrockAnimation? animation;
  final AnimationController? animationController;

  @override
  State<_BedrockModelZBufferView> createState() => _BedrockModelZBufferViewState();
}

class _BedrockModelZBufferViewState extends State<_BedrockModelZBufferView> {
  static const double _kMaxRenderScale = 2.0;

  ui.Image? _rendered;
  int _renderWidth = 0;
  int _renderHeight = 0;
  double _renderScale = 1.0;

  Uint8List? _colorBuffer;
  Uint32List? _colorBuffer32;
  Float32List? _depthBuffer;

  ui.Image? _textureSource;
  Uint8List? _textureRgba;
  int _textureWidth = 0;
  int _textureHeight = 0;

  bool _dirty = true;
  bool _renderScheduled = false;
  bool _renderInProgress = false;
  int _renderGeneration = 0;

  static final Vector3 _lightDirection = Vector3(0.35, 0.7, -1)..normalize();

  @override
  void initState() {
    super.initState();
    widget.animationController?.addListener(_handleTick);
  }

  @override
  void didUpdateWidget(covariant _BedrockModelZBufferView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationController != widget.animationController) {
      oldWidget.animationController?.removeListener(_handleTick);
      widget.animationController?.addListener(_handleTick);
    }

    final bool propsChanged =
        oldWidget.baseModel != widget.baseModel ||
        oldWidget.modelTextureWidth != widget.modelTextureWidth ||
        oldWidget.modelTextureHeight != widget.modelTextureHeight ||
        oldWidget.texture != widget.texture ||
        oldWidget.yaw != widget.yaw ||
        oldWidget.pitch != widget.pitch ||
        oldWidget.zoom != widget.zoom ||
        oldWidget.animation != widget.animation;
    if (propsChanged) {
      _markDirty();
    }
  }

  @override
  void dispose() {
    widget.animationController?.removeListener(_handleTick);
    final ui.Image? rendered = _rendered;
    if (rendered != null && !rendered.debugDisposed) {
      rendered.dispose();
    }
    super.dispose();
  }

  void _handleTick() {
    if (!mounted) return;
    _markDirty();
  }

  void _markDirty() {
    _dirty = true;
    if (_renderScheduled) {
      return;
    }
    _renderScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _renderScheduled = false;
      _maybeStartRender();
    });
  }

  void _maybeStartRender() {
    if (!mounted || _renderInProgress || !_dirty) {
      return;
    }
    if (_renderWidth <= 0 || _renderHeight <= 0) {
      return;
    }
    _dirty = false;
    _renderInProgress = true;
    final int generation = ++_renderGeneration;
    unawaited(_renderFrame(generation));
  }

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
  }

  Future<void> _ensureTextureBytes(int generation) async {
    final ui.Image? image = widget.texture;
    if (image == null || image.debugDisposed) {
      _textureSource = null;
      _textureRgba = null;
      _textureWidth = 0;
      _textureHeight = 0;
      return;
    }
    if (identical(_textureSource, image) && _textureRgba != null) {
      return;
    }
    _textureSource = image;
    _textureRgba = null;
    _textureWidth = image.width;
    _textureHeight = image.height;

    try {
      final ByteData? data =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (!mounted || generation != _renderGeneration) {
        return;
      }
      if (data == null) {
        _textureRgba = null;
        return;
      }
      _textureRgba = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to read reference model texture: $error\n$stackTrace');
      _textureRgba = null;
    }
  }

  BedrockMesh _buildMeshForFrame() {
    final BedrockAnimation? animation = widget.animation;
    final AnimationController? controller = widget.animationController;
    if (animation == null || controller == null) {
      return widget.baseModel.mesh;
    }

    final Duration? elapsed = controller.lastElapsedDuration;
    final double lifeTimeSeconds =
        elapsed == null ? 0 : elapsed.inMicroseconds / 1000000.0;
    final double timeSeconds = animation.lengthSeconds <= 0
        ? 0
        : controller.value * animation.lengthSeconds;

    final Map<String, BedrockBonePose> pose = animation.samplePose(
      widget.baseModel.model,
      timeSeconds: timeSeconds,
      lifeTimeSeconds: lifeTimeSeconds,
    );

    return buildBedrockMeshForPose(
      widget.baseModel.model,
      center: widget.baseModel.center,
      pose: pose,
    );
  }

  Future<void> _renderFrame(int generation) async {
    try {
      await _ensureTextureBytes(generation);
      if (!mounted || generation != _renderGeneration) {
        return;
      }

      _ensureBuffers(_renderWidth, _renderHeight);
      final Uint8List? colorBuffer = _colorBuffer;
      final Float32List? depthBuffer = _depthBuffer;
      if (colorBuffer == null || depthBuffer == null) {
        return;
      }

      final Uint32List? color32 = _colorBuffer32;
      if (color32 != null) {
        color32.fillRange(0, color32.length, 0);
      } else {
        colorBuffer.fillRange(0, colorBuffer.length, 0);
      }
      depthBuffer.fillRange(0, depthBuffer.length, 0);

      final BedrockMesh mesh = _buildMeshForFrame();
      _rasterizeMesh(
        mesh: mesh,
        colorBuffer: colorBuffer,
        colorBuffer32: color32,
        depthBuffer: depthBuffer,
        width: _renderWidth,
        height: _renderHeight,
        modelExtent: widget.baseModel.mesh.size,
        yaw: widget.yaw,
        pitch: widget.pitch,
        zoom: widget.zoom,
        textureRgba: _textureRgba,
        textureWidth: _textureWidth,
        textureHeight: _textureHeight,
        modelTextureWidth: widget.modelTextureWidth,
        modelTextureHeight: widget.modelTextureHeight,
      );

      final ui.Image image = await _decodeRgbaImage(
        colorBuffer,
        _renderWidth,
        _renderHeight,
      );
      if (!mounted || generation != _renderGeneration) {
        if (!image.debugDisposed) {
          image.dispose();
        }
        return;
      }
      final ui.Image? previous = _rendered;
      setState(() {
        _rendered = image;
      });
      if (previous != null && !previous.debugDisposed) {
        previous.dispose();
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to render reference model: $error\n$stackTrace');
    } finally {
      if (!mounted || generation != _renderGeneration) {
        _renderInProgress = false;
        return;
      }
      _renderInProgress = false;
      if (_dirty) {
        _markDirty();
      }
    }
  }

  Future<ui.Image> _decodeRgbaImage(
    Uint8List bytes,
    int width,
    int height,
  ) {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bytes,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  void _rasterizeMesh({
    required BedrockMesh mesh,
    required Uint8List colorBuffer,
    required Uint32List? colorBuffer32,
    required Float32List depthBuffer,
    required int width,
    required int height,
    required Vector3 modelExtent,
    required double yaw,
    required double pitch,
    required double zoom,
    required Uint8List? textureRgba,
    required int textureWidth,
    required int textureHeight,
    required int modelTextureWidth,
    required int modelTextureHeight,
  }) {
    if (mesh.triangles.isEmpty || width <= 0 || height <= 0) {
      return;
    }

    final double extent = math.max(
      modelExtent.x.abs(),
      math.max(modelExtent.y.abs(), modelExtent.z.abs()),
    );
    if (extent <= 0) {
      return;
    }

    final bool hasTexture =
        textureRgba != null &&
        textureWidth > 0 &&
        textureHeight > 0 &&
        modelTextureWidth > 0 &&
        modelTextureHeight > 0;
    final double uScale =
        hasTexture ? textureWidth / modelTextureWidth : 1.0;
    final double vScale =
        hasTexture ? textureHeight / modelTextureHeight : 1.0;

    final Matrix4 rotation = Matrix4.identity()
      ..rotateY(yaw)
      ..rotateX(pitch);
    final Float64List r = rotation.storage;

    double transformX(double x, double y, double z) =>
        r[0] * x + r[4] * y + r[8] * z;
    double transformY(double x, double y, double z) =>
        r[1] * x + r[5] * y + r[9] * z;
    double transformZ(double x, double y, double z) =>
        r[2] * x + r[6] * y + r[10] * z;

    final double centerX = width * 0.5;
    final double centerY = height * 0.5;
    final double baseScale = (math.min(width.toDouble(), height.toDouble()) / extent) * 0.9;
    final double scale = baseScale * zoom;
    final double cameraDistance = extent * 2.4;

    double edge(
      double ax,
      double ay,
      double bx,
      double by,
      double cx,
      double cy,
    ) {
      return (cx - ax) * (by - ay) - (cy - ay) * (bx - ax);
    }

    int clampInt(int value, int min, int max) {
      if (value < min) return min;
      if (value > max) return max;
      return value;
    }

    for (final BedrockMeshTriangle tri in mesh.triangles) {
      final Vector3 normal = tri.normal;
      final double nx = transformX(normal.x, normal.y, normal.z);
      final double ny = transformY(normal.x, normal.y, normal.z);
      final double nz = transformZ(normal.x, normal.y, normal.z);
      if (nz >= 0) {
        continue;
      }

      final double light =
          math.max(0, nx * _lightDirection.x + ny * _lightDirection.y + nz * _lightDirection.z);
      final double brightness = (0.55 + 0.45 * light).clamp(0.0, 1.0);
      final int shade = (brightness * 255).round().clamp(0, 255);

      final Vector3 p0 = tri.p0;
      final Vector3 p1 = tri.p1;
      final Vector3 p2 = tri.p2;

      final double x0w = transformX(p0.x, p0.y, p0.z);
      final double y0w = transformY(p0.x, p0.y, p0.z);
      final double z0w = transformZ(p0.x, p0.y, p0.z);
      final double x1w = transformX(p1.x, p1.y, p1.z);
      final double y1w = transformY(p1.x, p1.y, p1.z);
      final double z1w = transformZ(p1.x, p1.y, p1.z);
      final double x2w = transformX(p2.x, p2.y, p2.z);
      final double y2w = transformY(p2.x, p2.y, p2.z);
      final double z2w = transformZ(p2.x, p2.y, p2.z);

      final double z0 = z0w + cameraDistance;
      final double z1 = z1w + cameraDistance;
      final double z2 = z2w + cameraDistance;
      if (z0 <= 0 || z1 <= 0 || z2 <= 0) {
        continue;
      }

      final double invZ0 = 1.0 / z0;
      final double invZ1 = 1.0 / z1;
      final double invZ2 = 1.0 / z2;

      final double s0 = cameraDistance * invZ0;
      final double s1 = cameraDistance * invZ1;
      final double s2 = cameraDistance * invZ2;

      final double x0 = centerX + x0w * s0 * scale;
      final double y0 = centerY + (-y0w) * s0 * scale;
      final double x1 = centerX + x1w * s1 * scale;
      final double y1 = centerY + (-y1w) * s1 * scale;
      final double x2 = centerX + x2w * s2 * scale;
      final double y2 = centerY + (-y2w) * s2 * scale;

      final double area = edge(x0, y0, x1, y1, x2, y2);
      if (area == 0) {
        continue;
      }
      final double invArea = 1.0 / area;

      final double minX = math.min(x0, math.min(x1, x2));
      final double maxX = math.max(x0, math.max(x1, x2));
      final double minY = math.min(y0, math.min(y1, y2));
      final double maxY = math.max(y0, math.max(y1, y2));
      int xStart = clampInt(minX.floor(), 0, width - 1);
      int xEnd = clampInt(maxX.ceil(), 0, width - 1);
      int yStart = clampInt(minY.floor(), 0, height - 1);
      int yEnd = clampInt(maxY.ceil(), 0, height - 1);

      final Offset uv0 = tri.uv0;
      final Offset uv1 = tri.uv1;
      final Offset uv2 = tri.uv2;
      final double u0 = uv0.dx * uScale;
      final double v0 = uv0.dy * vScale;
      final double u1 = uv1.dx * uScale;
      final double v1 = uv1.dy * vScale;
      final double u2 = uv2.dx * uScale;
      final double v2 = uv2.dy * vScale;

      final double u0OverZ = u0 * invZ0;
      final double v0OverZ = v0 * invZ0;
      final double u1OverZ = u1 * invZ1;
      final double v1OverZ = v1 * invZ1;
      final double u2OverZ = u2 * invZ2;
      final double v2OverZ = v2 * invZ2;

      for (int y = yStart; y <= yEnd; y++) {
        final double py = y + 0.5;
        final int row = y * width;
        for (int x = xStart; x <= xEnd; x++) {
          final double px = x + 0.5;
          final double w0 = edge(x1, y1, x2, y2, px, py);
          final double w1 = edge(x2, y2, x0, y0, px, py);
          final double w2 = edge(x0, y0, x1, y1, px, py);
          if (area > 0) {
            if (w0 < 0 || w1 < 0 || w2 < 0) {
              continue;
            }
          } else {
            if (w0 > 0 || w1 > 0 || w2 > 0) {
              continue;
            }
          }

          final double a = w0 * invArea;
          final double b = w1 * invArea;
          final double c = w2 * invArea;

          final double invZ = a * invZ0 + b * invZ1 + c * invZ2;
          if (invZ <= 0) {
            continue;
          }

          final int index = row + x;
          if (invZ <= depthBuffer[index]) {
            continue;
          }

          int rOut;
          int gOut;
          int bOut;
          int aOut;

          if (hasTexture) {
            final double u = (a * u0OverZ + b * u1OverZ + c * u2OverZ) / invZ;
            final double v = (a * v0OverZ + b * v1OverZ + c * v2OverZ) / invZ;
            final int tu = clampInt(u.floor(), 0, textureWidth - 1);
            final int tv = clampInt(v.floor(), 0, textureHeight - 1);
            final int texIndex = (tv * textureWidth + tu) * 4;
            final int tr = textureRgba![texIndex];
            final int tg = textureRgba[texIndex + 1];
            final int tb = textureRgba[texIndex + 2];
            final int ta = textureRgba[texIndex + 3];
            if (ta == 0) {
              continue;
            }
            rOut = (tr * shade) ~/ 255;
            gOut = (tg * shade) ~/ 255;
            bOut = (tb * shade) ~/ 255;
            aOut = ta;
          } else {
            rOut = shade;
            gOut = shade;
            bOut = shade;
            aOut = 255;
          }

          depthBuffer[index] = invZ.toDouble();
          if (colorBuffer32 != null) {
            colorBuffer32[index] =
                rOut | (gOut << 8) | (bOut << 16) | (aOut << 24);
          } else {
            final int byteIndex = index * 4;
            colorBuffer[byteIndex] = rOut;
            colorBuffer[byteIndex + 1] = gOut;
            colorBuffer[byteIndex + 2] = bOut;
            colorBuffer[byteIndex + 3] = aOut;
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth;
        final double maxHeight = constraints.maxHeight;
        if (!maxWidth.isFinite || !maxHeight.isFinite || maxWidth <= 0 || maxHeight <= 0) {
          return const SizedBox.expand();
        }

        final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        final double scale = devicePixelRatio <= 0
            ? 1.0
            : devicePixelRatio.clamp(1.0, _kMaxRenderScale);
        final int width = math.max(1, (maxWidth * scale).round());
        final int height = math.max(1, (maxHeight * scale).round());

        final bool sizeChanged =
            width != _renderWidth ||
            height != _renderHeight ||
            scale != _renderScale;
        if (sizeChanged) {
          _renderWidth = width;
          _renderHeight = height;
          _renderScale = scale;
          _markDirty();
        } else if (_dirty && !_renderInProgress) {
          _maybeStartRender();
        }

        final ui.Image? image = _rendered;
        if (image == null || image.debugDisposed) {
          return CustomPaint(
            painter: _BedrockModelPainter(
              baseModel: widget.baseModel,
              modelTextureWidth: widget.modelTextureWidth,
              modelTextureHeight: widget.modelTextureHeight,
              texture: widget.texture,
              yaw: widget.yaw,
              pitch: widget.pitch,
              zoom: widget.zoom,
              animation: widget.animation,
              animationController: widget.animationController,
            ),
          );
        }

        return RawImage(
          image: image,
          scale: _renderScale,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.none,
        );
      },
    );
  }
}

class _BedrockModelPainter extends CustomPainter {
  _BedrockModelPainter({
    required this.baseModel,
    required this.modelTextureWidth,
    required this.modelTextureHeight,
    required this.texture,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    this.animation,
    this.animationController,
  }) : super(repaint: animationController);

  final BedrockModelMesh baseModel;
  final int modelTextureWidth;
  final int modelTextureHeight;
  final ui.Image? texture;
  final double yaw;
  final double pitch;
  final double zoom;
  final BedrockAnimation? animation;
  final AnimationController? animationController;

  static final Vector3 _lightDirection = Vector3(0.35, 0.7, -1)..normalize();

  @override
  void paint(Canvas canvas, Size size) {
    final BedrockMesh mesh = _buildMeshForFrame();
    if (mesh.triangles.isEmpty || size.isEmpty) {
      return;
    }
    final Vector3 meshSize = baseModel.mesh.size;
    final double extent = math.max(
      meshSize.x.abs(),
      math.max(meshSize.y.abs(), meshSize.z.abs()),
    );
    if (extent <= 0) {
      return;
    }

    final ui.Image? tex = texture;
    final bool hasTexture = tex != null && !tex.debugDisposed;
    final double uScale = hasTexture && modelTextureWidth > 0
        ? tex.width / modelTextureWidth
        : 1.0;
    final double vScale = hasTexture && modelTextureHeight > 0
        ? tex.height / modelTextureHeight
        : 1.0;

    final Matrix4 rotation = Matrix4.identity()
      ..rotateY(yaw)
      ..rotateX(pitch);

    final Offset center = size.center(Offset.zero);
    final double baseScale = (math.min(size.width, size.height) / extent) * 0.9;
    final double scale = baseScale * zoom;
    final double cameraDistance = extent * 2.4;

    final List<_ProjectedTriangle> projected = <_ProjectedTriangle>[];

    for (final BedrockMeshTriangle tri in mesh.triangles) {
      final Vector3 n = rotation.transform3(tri.normal.clone());
      if (n.z >= 0) {
        continue;
      }
      final double light = math.max(0, n.dot(_lightDirection));
      final double brightness = (0.55 + 0.45 * light).clamp(0.0, 1.0);
      final int shade = (brightness * 255).round().clamp(0, 255);
      final Color color = Color.fromARGB(255, shade, shade, shade);

      final Vector3 p0 = rotation.transform3(tri.p0.clone());
      final Vector3 p1 = rotation.transform3(tri.p1.clone());
      final Vector3 p2 = rotation.transform3(tri.p2.clone());

      final double z0 = p0.z + cameraDistance;
      final double z1 = p1.z + cameraDistance;
      final double z2 = p2.z + cameraDistance;
      if (z0 <= 0 || z1 <= 0 || z2 <= 0) {
        continue;
      }

      final double s0 = cameraDistance / z0;
      final double s1 = cameraDistance / z1;
      final double s2 = cameraDistance / z2;

      final Offset v0 = center + Offset(p0.x * s0 * scale, -p0.y * s0 * scale);
      final Offset v1 = center + Offset(p1.x * s1 * scale, -p1.y * s1 * scale);
      final Offset v2 = center + Offset(p2.x * s2 * scale, -p2.y * s2 * scale);

      projected.add(
        _ProjectedTriangle(
          depth: (z0 + z1 + z2) / 3,
          p0: v0,
          p1: v1,
          p2: v2,
          uv0: Offset(tri.uv0.dx * uScale, tri.uv0.dy * vScale),
          uv1: Offset(tri.uv1.dx * uScale, tri.uv1.dy * vScale),
          uv2: Offset(tri.uv2.dx * uScale, tri.uv2.dy * vScale),
          color: color,
        ),
      );
    }

    if (projected.isEmpty) {
      return;
    }

    projected.sort((a, b) => b.depth.compareTo(a.depth));

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    if (!hasTexture) {
      final Paint wire = Paint()
        ..color = const Color(0xFF4D4D4D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      for (final tri in projected) {
        final Path path = Path()
          ..moveTo(tri.p0.dx, tri.p0.dy)
          ..lineTo(tri.p1.dx, tri.p1.dy)
          ..lineTo(tri.p2.dx, tri.p2.dy)
          ..close();
        canvas.drawPath(path, wire);
      }
      canvas.restore();
      return;
    }

    final Paint paint = Paint()
      ..filterQuality = FilterQuality.none
      ..shader = ui.ImageShader(
        tex!,
        ui.TileMode.clamp,
        ui.TileMode.clamp,
        Matrix4.identity().storage,
      );

    final List<Offset> positions = <Offset>[];
    final List<Offset> texCoords = <Offset>[];
    final List<Color> colors = <Color>[];
    for (final tri in projected) {
      positions.addAll([tri.p0, tri.p1, tri.p2]);
      texCoords.addAll([tri.uv0, tri.uv1, tri.uv2]);
      colors.addAll([tri.color, tri.color, tri.color]);
    }

    final ui.Vertices vertices = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texCoords,
      colors: colors,
    );
    canvas.drawVertices(vertices, ui.BlendMode.modulate, paint);
    canvas.restore();
  }

  BedrockMesh _buildMeshForFrame() {
    final BedrockAnimation? animation = this.animation;
    final AnimationController? controller = animationController;
    if (animation == null || controller == null) {
      return baseModel.mesh;
    }

    final Duration? elapsed = controller.lastElapsedDuration;
    final double lifeTimeSeconds = elapsed == null
        ? 0
        : elapsed.inMicroseconds / 1000000.0;
    final double timeSeconds = animation.lengthSeconds <= 0
        ? 0
        : controller.value * animation.lengthSeconds;

    final Map<String, BedrockBonePose> pose = animation.samplePose(
      baseModel.model,
      timeSeconds: timeSeconds,
      lifeTimeSeconds: lifeTimeSeconds,
    );

    return buildBedrockMeshForPose(
      baseModel.model,
      center: baseModel.center,
      pose: pose,
    );
  }

  @override
  bool shouldRepaint(covariant _BedrockModelPainter oldDelegate) {
    return oldDelegate.baseModel != baseModel ||
        oldDelegate.texture != texture ||
        oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.zoom != zoom ||
        oldDelegate.modelTextureWidth != modelTextureWidth ||
        oldDelegate.modelTextureHeight != modelTextureHeight ||
        oldDelegate.animation != animation;
  }
}

class _ProjectedTriangle {
  const _ProjectedTriangle({
    required this.depth,
    required this.p0,
    required this.p1,
    required this.p2,
    required this.uv0,
    required this.uv1,
    required this.uv2,
    required this.color,
  });

  final double depth;
  final Offset p0;
  final Offset p1;
  final Offset p2;
  final Offset uv0;
  final Offset uv1;
  final Offset uv2;
  final Color color;
}
