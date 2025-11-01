import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';

import '../../canvas/canvas_exporter.dart';
import '../project/project_document.dart';
import '../project/project_repository.dart';
import '../widgets/painting_board.dart';

class CanvasPage extends StatefulWidget {
  const CanvasPage({super.key, required this.document});

  final ProjectDocument document;

  @override
  State<CanvasPage> createState() => _CanvasPageState();
}

class _CanvasPageState extends State<CanvasPage> {
  final GlobalKey<PaintingBoardState> _boardKey =
      GlobalKey<PaintingBoardState>();
  final CanvasExporter _exporter = CanvasExporter();
  final ProjectRepository _repository = ProjectRepository.instance;

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
  }

  @override
  void initState() {
    super.initState();
    _document = widget.document;
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
    if (_isSaving || _isAutoSaving) {
      return;
    }
    if (!_hasUnsavedChanges) {
      await _closePage();
      return;
    }
    final _ExitAction? action = await _showExitDialog();
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _ExitAction.save:
        await _saveProject(force: true);
        final bool saved = await _saveCanvas();
        if (saved) {
          await _closePage();
        }
        break;
      case _ExitAction.discard:
        await _closePage();
        break;
      case _ExitAction.cancel:
        break;
    }
  }

  Future<_ExitAction?> _showExitDialog() {
    return showDialog<_ExitAction>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('返回主页面'),
        content: const Text('是否在返回前保存当前画布？'),
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
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      content: ScaffoldPage(
        padding: EdgeInsets.zero,
        content: Container(
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
    );
  }
}

enum _ExitAction { save, discard, cancel }
