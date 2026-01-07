part of 'painting_board.dart';

extension _ReferenceModelCardStateActionDialog on _ReferenceModelCardState {
  Future<void> _showActionDialogImpl() async {
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

    double previewYaw = 0;
    double previewPitch = 0;
    double previewZoom = 1.0;
    double previewZoomScaleStart = 1.0;

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
                                          child: Listener(
                                            onPointerSignal: (event) {
                                              if (event is PointerScrollEvent) {
                                                setDialogState(() {
                                                  previewZoom = (previewZoom -
                                                          event.scrollDelta.dy * 0.002)
                                                      .clamp(0.35, 6.0);
                                                });
                                              }
                                            },
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onDoubleTap: () {
                                                setDialogState(() {
                                                  previewYaw = 0;
                                                  previewPitch = 0;
                                                  previewZoom = 1.0;
                                                });
                                              },
                                              onScaleStart: (_) =>
                                                  previewZoomScaleStart = previewZoom,
                                              onScaleUpdate: (details) {
                                                setDialogState(() {
                                                  final double scaleDelta =
                                                      details.scale - 1.0;
                                                  if (scaleDelta.abs() > 0.001) {
                                                    previewZoom =
                                                        (previewZoomScaleStart *
                                                                details.scale)
                                                            .clamp(0.35, 6.0);
                                                    return;
                                                  }

                                                  previewYaw -=
                                                      details.focalPointDelta.dx *
                                                      0.01;
                                                  previewPitch =
                                                      (previewPitch -
                                                              details
                                                                      .focalPointDelta
                                                                      .dy *
                                                                  0.01)
                                                          .clamp(
                                                            -math.pi / 2,
                                                            math.pi / 2,
                                                          );
                                                });
                                              },
                                              child: _BedrockModelZBufferView(
                                                baseModel: widget.modelMesh,
                                                modelTextureWidth:
                                                    widget.modelMesh.model.textureWidth,
                                                modelTextureHeight:
                                                    widget.modelMesh.model.textureHeight,
                                                texture: widget.texture,
                                                yaw: previewYaw,
                                                pitch: previewPitch,
                                                zoom: previewZoom,
                                                animation: selectedAnimation,
                                                animationController: previewController,
                                              ),
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
}

Widget _buildActionTag(BuildContext context, String text) {
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

Future<_ReferenceModelActionCatalog?> _loadReferenceModelActionCatalog(
  BedrockAnimationLibrary library,
) async {
  try {
    final Map<String, _ReferenceModelActionItem> byId =
        <String, _ReferenceModelActionItem>{};
    final List<_ReferenceModelActionItem> items = <_ReferenceModelActionItem>[];

    for (final _ReferenceModelActionSeed seed in _kReferenceModelActionSeeds) {
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
