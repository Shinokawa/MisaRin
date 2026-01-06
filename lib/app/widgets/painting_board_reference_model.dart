part of 'painting_board.dart';

const String _kSteveReferenceModelAsset = 'assets/bedrock_models/armor_steve.json';
const String _kAlexReferenceModelAsset = 'assets/bedrock_models/armor_alex.json';

const double _referenceModelCardWidth = 420;
const double _referenceModelViewportHeight = 320;

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
      debugPrint('Failed to load built-in reference model: $error\n$stackTrace');
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
      throw const FormatException('Not a Bedrock geometry / client entity file');
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
    final String geometryText =
        utf8.decode(geometryBytes, allowMalformed: true);
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
      debugPrint('Failed to refresh reference model texture: $error\n$stackTrace');
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
      final Size size =
          entry.size ?? const Size(_referenceModelCardWidth, 420);
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
      final _ReferenceModelCardEntry entry = _referenceModelCards.removeAt(index);
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
  final VoidCallback onClose;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onRefreshTexture;
  final ValueChanged<Size> onSizeChanged;

  @override
  State<_ReferenceModelCard> createState() => _ReferenceModelCardState();
}

class _ReferenceModelCardState extends State<_ReferenceModelCard> {
  double _yaw = math.pi / 4;
  double _pitch = -math.pi / 12;
  double _zoom = 1.0;

  void _resetView() {
    setState(() {
      _yaw = math.pi / 4;
      _pitch = -math.pi / 12;
      _zoom = 1.0;
    });
  }

  void _updateRotation(Offset delta) {
    setState(() {
      _yaw += delta.dx * 0.01;
      _pitch = (_pitch + delta.dy * 0.01).clamp(-math.pi / 2, math.pi / 2);
    });
  }

  void _updateZoom(double delta) {
    setState(() {
      _zoom = (_zoom + delta).clamp(0.35, 6.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final Color border = theme.resources.controlStrokeColorDefault;
    final Color background = theme.brightness.isDark
        ? const Color(0xFF101010)
        : const Color(0xFFF7F7F7);

    return MeasuredSize(
      onChanged: widget.onSizeChanged,
      child: WorkspaceFloatingPanel(
        title: widget.title,
        width: _referenceModelCardWidth,
        headerActions: [
          IconButton(
            icon: const Icon(FluentIcons.refresh, size: 14),
            iconButtonMode: IconButtonMode.small,
            style: ButtonStyle(
              padding: WidgetStateProperty.all(const EdgeInsets.all(4)),
            ),
            onPressed: widget.onRefreshTexture,
          ),
          IconButton(
            icon: const Icon(FluentIcons.reset, size: 14),
            iconButtonMode: IconButtonMode.small,
            style: ButtonStyle(
              padding: WidgetStateProperty.all(const EdgeInsets.all(4)),
            ),
            onPressed: _resetView,
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
                  onPanUpdate: (details) => _updateRotation(details.delta),
                  child: CustomPaint(
                    painter: _BedrockModelPainter(
                      mesh: widget.modelMesh.mesh,
                      modelTextureWidth: widget.modelMesh.model.textureWidth,
                      modelTextureHeight: widget.modelMesh.model.textureHeight,
                      texture: widget.texture,
                      yaw: _yaw,
                      pitch: _pitch,
                      zoom: _zoom,
                    ),
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

class _BedrockModelPainter extends CustomPainter {
  _BedrockModelPainter({
    required this.mesh,
    required this.modelTextureWidth,
    required this.modelTextureHeight,
    required this.texture,
    required this.yaw,
    required this.pitch,
    required this.zoom,
  });

  final BedrockMesh mesh;
  final int modelTextureWidth;
  final int modelTextureHeight;
  final ui.Image? texture;
  final double yaw;
  final double pitch;
  final double zoom;

  static final Vector3 _lightDirection = Vector3(0.35, 0.7, -1)..normalize();

  @override
  void paint(Canvas canvas, Size size) {
    if (mesh.triangles.isEmpty || size.isEmpty) {
      return;
    }
    final Vector3 meshSize = mesh.size;
    final double extent = math.max(
      meshSize.x.abs(),
      math.max(meshSize.y.abs(), meshSize.z.abs()),
    );
    if (extent <= 0) {
      return;
    }

    final ui.Image? tex = texture;
    final bool hasTexture = tex != null && !tex.debugDisposed;
    final double uScale =
        hasTexture && modelTextureWidth > 0
            ? tex.width / modelTextureWidth
            : 1.0;
    final double vScale =
        hasTexture && modelTextureHeight > 0
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

  @override
  bool shouldRepaint(covariant _BedrockModelPainter oldDelegate) {
    return oldDelegate.mesh != mesh ||
        oldDelegate.texture != texture ||
        oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.zoom != zoom ||
        oldDelegate.modelTextureWidth != modelTextureWidth ||
        oldDelegate.modelTextureHeight != modelTextureHeight;
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
