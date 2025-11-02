import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';

import '../../canvas/canvas_exporter.dart';
import '../dialogs/misarin_dialog.dart';
import '../menu/menu_action_dispatcher.dart';
import '../menu/menu_app_actions.dart';
import '../project/project_document.dart';
import '../project/project_repository.dart';
import '../widgets/canvas_title_bar.dart';
import '../widgets/painting_board.dart';
import '../workspace/canvas_workspace_controller.dart';

class CanvasPage extends StatefulWidget {
  const CanvasPage({super.key, required this.document});

  final ProjectDocument document;

  @override
  State<CanvasPage> createState() => CanvasPageState();
}

class CanvasPageState extends State<CanvasPage> {
  final GlobalKey<PaintingBoardState> _boardKey =
      GlobalKey<PaintingBoardState>();
  final CanvasExporter _exporter = CanvasExporter();
  final ProjectRepository _repository = ProjectRepository.instance;
  final CanvasWorkspaceController _workspace =
      CanvasWorkspaceController.instance;

  late ProjectDocument _document;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  bool _isAutoSaving = false;
  Timer? _autoSaveTimer;

  void _handleDirtyChanged(bool dirty) {
    if (_hasUnsavedChanges == dirty) {
      return;
    }
    setState(() => _hasUnsavedChanges = dirty);
    _workspace.markDirty(_document.id, dirty);
  }

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    _workspace.open(_document, activate: true);
    _workspace.markDirty(_document.id, false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureInitialSave();
    });
    _autoSaveTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _saveProject();
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  Future<void> _ensureInitialSave() async {
    if (!mounted) {
      return;
    }
    if (_document.path != null) {
      return;
    }
    await _saveProject(force: true);
  }

  Future<bool> _saveProject({bool force = false}) async {
    if (!mounted) {
      return false;
    }
    if (_isAutoSaving) {
      return false;
    }
    final PaintingBoardState? board = _boardKey.currentState;
    if (board == null) {
      return false;
    }
    final bool shouldPersist =
        force || _document.path == null || _hasUnsavedChanges;
    if (!shouldPersist) {
      return false;
    }
    setState(() => _isAutoSaving = true);
    try {
      final strokes = board.snapshotStrokes();
      final preview = await _exporter.exportToPng(
        settings: _document.settings,
        strokes: strokes,
        maxDimension: 256,
      );
      final ProjectDocument updated = _document.copyWith(
        strokes: strokes,
        previewBytes: preview,
      );
      final ProjectDocument saved = await _repository.saveDocument(updated);
      if (!mounted) {
        return true;
      }
      setState(() {
        _document = saved;
        _isAutoSaving = false;
      });
      _workspace.updateDocument(saved);
      _workspace.markDirty(saved.id, false);
      board.markSaved();
      return true;
    } catch (error) {
      if (mounted) {
        setState(() => _isAutoSaving = false);
        _showInfoBar('保存项目失败：$error', severity: InfoBarSeverity.error);
      }
      return false;
    }
  }

  Future<void> _handleExitRequest() async {
    final bool canLeave = await _ensureCanLeave(
      dialogTitle: '返回主页面',
      dialogContent: '是否在返回前保存当前画布？',
      includeCanvasExport: true,
    );
    if (!canLeave) {
      return;
    }
    await _closePage();
  }

  Future<_ExitAction?> _showExitDialog({
    String title = '返回主页面',
    String content = '是否在返回前保存当前画布？',
  }) {
    return showDialog<_ExitAction>(
      context: context,
      builder: (context) => MisarinDialog(
        title: Text(title),
        content: Text(content),
        contentWidth: 360,
        maxWidth: 480,
        actions: [
          Button(
            onPressed: () => Navigator.of(context).pop(_ExitAction.cancel),
            child: const Text('取消'),
          ),
          Button(
            onPressed: () => Navigator.of(context).pop(_ExitAction.discard),
            child: const Text('不保存'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_ExitAction.save),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<bool> _ensureCanLeave({
    required String dialogTitle,
    required String dialogContent,
    required bool includeCanvasExport,
  }) async {
    if (_isSaving || _isAutoSaving) {
      return false;
    }
    if (!_hasUnsavedChanges) {
      return true;
    }
    final _ExitAction? action = await _showExitDialog(
      title: dialogTitle,
      content: dialogContent,
    );
    if (!mounted || action == null) {
      return false;
    }
    switch (action) {
      case _ExitAction.save:
        final bool projectSaved = await _saveProject(force: true);
        if (!projectSaved) {
          return false;
        }
        if (includeCanvasExport) {
          final bool exported = await _saveCanvas();
          if (!exported) {
            return false;
          }
        }
        _workspace.markDirty(_document.id, false);
        return true;
      case _ExitAction.discard:
        _workspace.markDirty(_document.id, false);
        return true;
      case _ExitAction.cancel:
        return false;
    }
  }

  Future<bool> _saveCanvas() async {
    final PaintingBoardState? board = _boardKey.currentState;
    if (board == null) {
      _showInfoBar('画布尚未准备好，无法保存。', severity: InfoBarSeverity.error);
      return false;
    }
    final String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: '保存画布为 PNG',
      fileName: 'misa_rin_${DateTime.now().millisecondsSinceEpoch}.png',
      type: FileType.custom,
      allowedExtensions: const ['png'],
    );
    if (outputPath == null) {
      return false;
    }
    final String normalizedPath = outputPath.toLowerCase().endsWith('.png')
        ? outputPath
        : '$outputPath.png';

    try {
      setState(() => _isSaving = true);
      final bytes = await _exporter.exportToPng(
        settings: _document.settings,
        strokes: board.snapshotStrokes(),
      );
      final file = File(normalizedPath);
      await file.writeAsBytes(bytes, flush: true);
      board.markSaved();
      _workspace.markDirty(_document.id, false);
      _showInfoBar('已保存到 $normalizedPath', severity: InfoBarSeverity.success);
      return true;
    } catch (error) {
      _showInfoBar('保存失败：$error', severity: InfoBarSeverity.error);
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showInfoBar(
    String message, {
    InfoBarSeverity severity = InfoBarSeverity.info,
  }) {
    if (!mounted) {
      return;
    }
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        severity: severity,
        title: Text(message),
        action: IconButton(
          icon: const Icon(FluentIcons.clear),
          onPressed: close,
        ),
      ),
    );
  }

  Future<void> _closePage() async {
    if (!mounted) {
      return;
    }
    _workspace.remove(_document.id);
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<void> openDocument(ProjectDocument document) async {
    if (document.id == _document.id) {
      _workspace.setActive(document.id);
      return;
    }
    final bool canLeave = await _ensureCanLeave(
      dialogTitle: '切换画布',
      dialogContent: '是否在切换前保存当前画布？',
      includeCanvasExport: false,
    );
    if (!canLeave) {
      _workspace.setActive(_document.id);
      return;
    }
    if (_workspace.entryById(document.id) == null) {
      _workspace.open(document, activate: false);
    } else {
      _workspace.updateDocument(document);
    }
    _workspace.setActive(document.id);
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      FluentPageRoute(builder: (_) => CanvasPage(document: document)),
    );
  }

  Future<void> _handleTabSelected(String id) async {
    if (id == _document.id) {
      _workspace.setActive(id);
      return;
    }
    final CanvasWorkspaceEntry? entry = _workspace.entryById(id);
    if (entry == null) {
      return;
    }
    final bool canLeave = await _ensureCanLeave(
      dialogTitle: '切换画布',
      dialogContent: '是否在切换前保存当前画布？',
      includeCanvasExport: false,
    );
    if (!canLeave) {
      _workspace.setActive(_document.id);
      return;
    }
    _workspace.setActive(id);
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      FluentPageRoute(builder: (_) => CanvasPage(document: entry.document)),
    );
  }

  Future<void> _handleTabClosed(String id) async {
    if (id != _document.id) {
      _workspace.remove(id);
      return;
    }
    final CanvasWorkspaceEntry? neighbor = _workspace.neighborFor(id);
    final bool canLeave = await _ensureCanLeave(
      dialogTitle: '关闭画布',
      dialogContent: '是否在关闭前保存当前画布？',
      includeCanvasExport: true,
    );
    if (!canLeave) {
      _workspace.setActive(_document.id);
      return;
    }
    if (neighbor != null) {
      final String nextId = neighbor.id;
      final ProjectDocument nextDocument = neighbor.document;
      _workspace.remove(id, activateAfter: nextId);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushReplacement(
        FluentPageRoute(builder: (_) => CanvasPage(document: nextDocument)),
      );
      return;
    }
    await _closePage();
  }

  @override
  Widget build(BuildContext context) {
    final handler = MenuActionHandler(
      newProject: () => AppMenuActions.createProject(context),
      preferences: () => AppMenuActions.openSettings(context),
      about: () => AppMenuActions.showAbout(context),
      save: () async {
        await _saveProject(force: true);
      },
      undo: () {
        final board = _boardKey.currentState;
        board?.undo();
      },
      redo: () {
        final board = _boardKey.currentState;
        board?.redo();
      },
      zoomIn: () {
        final board = _boardKey.currentState;
        board?.zoomIn();
      },
      zoomOut: () {
        final board = _boardKey.currentState;
        board?.zoomOut();
      },
    );

    return MenuActionBinding(
      handler: handler,
      child: NavigationView(
        content: ScaffoldPage(
          padding: EdgeInsets.zero,
          content: Column(
            children: [
              CanvasTitleBar(
                onSelectTab: _handleTabSelected,
                onCloseTab: _handleTabClosed,
                onCreateTab: () => AppMenuActions.createProject(context),
              ),
              Expanded(
                child: Container(
                  color: FluentTheme.of(context).micaBackgroundColor,
                  child: Center(
                    child: PaintingBoard(
                      key: _boardKey,
                      settings: _document.settings,
                      onRequestExit: _handleExitRequest,
                      onDirtyChanged: _handleDirtyChanged,
                      initialStrokes: _document.strokes,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ExitAction { save, discard, cancel }
