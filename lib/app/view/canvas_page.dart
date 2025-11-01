import 'package:file_selector/file_selector.dart' as fs;
import 'package:fluent_ui/fluent_ui.dart';

import '../../canvas/canvas_exporter.dart';
import '../../canvas/canvas_settings.dart';
import '../widgets/painting_board.dart';

class CanvasPage extends StatefulWidget {
  const CanvasPage({super.key, required this.settings});

  final CanvasSettings settings;

  @override
  State<CanvasPage> createState() => _CanvasPageState();
}

class _CanvasPageState extends State<CanvasPage> {
  final GlobalKey<PaintingBoardState> _boardKey =
      GlobalKey<PaintingBoardState>();
  final CanvasExporter _exporter = CanvasExporter();
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;

  void _handleDirtyChanged(bool dirty) {
    if (_hasUnsavedChanges == dirty) {
      return;
    }
    setState(() => _hasUnsavedChanges = dirty);
  }

  Future<void> _handleExitRequest() async {
    if (_isSaving) {
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
    final fs.FileSaveLocation? saveLocation = await fs.getSaveLocation(
      acceptedTypeGroups: const [
        fs.XTypeGroup(label: 'PNG 图片', extensions: ['png']),
      ],
      suggestedName: 'misa_rin_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    if (saveLocation == null) {
      return false;
    }
    final String savePath = saveLocation.path;
    final String normalizedPath = savePath.toLowerCase().endsWith('.png')
        ? savePath
        : '$savePath.png';

    try {
      setState(() => _isSaving = true);
      final bytes = await _exporter.exportToPng(
        settings: widget.settings,
        strokes: board.snapshotStrokes(),
      );
      final String fileName = normalizedPath.split(RegExp(r'[\\/]')).last;
      final fs.XFile file = fs.XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: fileName,
      );
      await file.saveTo(normalizedPath);
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
              settings: widget.settings,
              onRequestExit: _handleExitRequest,
              onDirtyChanged: _handleDirtyChanged,
            ),
          ),
        ),
      ),
    );
  }
}

enum _ExitAction { save, discard, cancel }
