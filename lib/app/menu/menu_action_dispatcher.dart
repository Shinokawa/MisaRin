import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';

typedef MenuAsyncAction = FutureOr<void> Function();
typedef MenuPaletteAction = FutureOr<void> Function(String paletteId);

class MenuPaletteMenuEntry {
  const MenuPaletteMenuEntry({required this.id, required this.label});

  final String id;
  final String label;
}

class MenuActionHandler {
  const MenuActionHandler({
    this.newProject,
    this.open,
    this.importImage,
    this.importImageFromClipboard,
    this.preferences,
    this.about,
    this.save,
    this.saveAs,
    this.export,
    this.undo,
    this.redo,
    this.zoomIn,
    this.zoomOut,
    this.rotateCanvas90Clockwise,
    this.rotateCanvas90CounterClockwise,
    this.rotateCanvas180Clockwise,
    this.rotateCanvas180CounterClockwise,
    this.cut,
    this.copy,
    this.paste,
    this.newLayer,
    this.generatePalette,
    this.importPalette,
    this.selectPaletteFromMenu,
    this.paletteMenuEntries = const <MenuPaletteMenuEntry>[],
    this.resizeImage,
    this.resizeCanvas,
    this.mergeLayerDown,
    this.adjustHueSaturation,
    this.adjustBrightnessContrast,
    this.selectAll,
    this.invertSelection,
    this.showLayerAntialiasPanel,
  });

  const MenuActionHandler.empty()
    : newProject = null,
      open = null,
      importImage = null,
      importImageFromClipboard = null,
      preferences = null,
      about = null,
      save = null,
      saveAs = null,
      export = null,
      undo = null,
      redo = null,
      zoomIn = null,
      zoomOut = null,
      rotateCanvas90Clockwise = null,
      rotateCanvas90CounterClockwise = null,
      rotateCanvas180Clockwise = null,
      rotateCanvas180CounterClockwise = null,
      cut = null,
      copy = null,
      paste = null,
      newLayer = null,
      generatePalette = null,
      importPalette = null,
      selectPaletteFromMenu = null,
      resizeImage = null,
      resizeCanvas = null,
      mergeLayerDown = null,
      adjustHueSaturation = null,
      adjustBrightnessContrast = null,
      selectAll = null,
      invertSelection = null,
      showLayerAntialiasPanel = null,
      paletteMenuEntries = const <MenuPaletteMenuEntry>[];

  final MenuAsyncAction? newProject;
  final MenuAsyncAction? open;
  final MenuAsyncAction? importImage;
  final MenuAsyncAction? importImageFromClipboard;
  final MenuAsyncAction? preferences;
  final MenuAsyncAction? about;
  final MenuAsyncAction? save;
  final MenuAsyncAction? saveAs;
  final MenuAsyncAction? export;
  final MenuAsyncAction? undo;
  final MenuAsyncAction? redo;
  final MenuAsyncAction? zoomIn;
  final MenuAsyncAction? zoomOut;
  final MenuAsyncAction? rotateCanvas90Clockwise;
  final MenuAsyncAction? rotateCanvas90CounterClockwise;
  final MenuAsyncAction? rotateCanvas180Clockwise;
  final MenuAsyncAction? rotateCanvas180CounterClockwise;
  final MenuAsyncAction? cut;
  final MenuAsyncAction? copy;
  final MenuAsyncAction? paste;
  final MenuAsyncAction? newLayer;
  final MenuAsyncAction? generatePalette;
  final MenuAsyncAction? importPalette;
  final MenuPaletteAction? selectPaletteFromMenu;
  final List<MenuPaletteMenuEntry> paletteMenuEntries;
  final MenuAsyncAction? resizeImage;
  final MenuAsyncAction? resizeCanvas;
  final MenuAsyncAction? mergeLayerDown;
  final MenuAsyncAction? adjustHueSaturation;
  final MenuAsyncAction? adjustBrightnessContrast;
  final MenuAsyncAction? selectAll;
  final MenuAsyncAction? invertSelection;
  final MenuAsyncAction? showLayerAntialiasPanel;
}

class MenuActionDispatcher extends ChangeNotifier {
  MenuActionDispatcher._();

  static final MenuActionDispatcher instance = MenuActionDispatcher._();

  final LinkedHashMap<Object, MenuActionHandler> _handlers =
      LinkedHashMap<Object, MenuActionHandler>();
  bool _notifyScheduled = false;

  MenuActionHandler get current => _handlers.isEmpty
      ? const MenuActionHandler.empty()
      : _handlers.values.last;

  void register(Object token, MenuActionHandler handler) {
    _handlers[token] = handler;
    _scheduleNotify();
  }

  void unregister(Object token) {
    final removed = _handlers.remove(token);
    if (removed != null) {
      _scheduleNotify();
    }
  }

  void _scheduleNotify() {
    final WidgetsBinding binding = WidgetsBinding.instance;
    if (_notifyScheduled) {
      return;
    }
    _notifyScheduled = true;
    binding.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
  }
}

class MenuActionBinding extends StatefulWidget {
  const MenuActionBinding({
    super.key,
    required this.handler,
    required this.child,
  });

  final MenuActionHandler handler;
  final Widget child;

  @override
  State<MenuActionBinding> createState() => _MenuActionBindingState();
}

class _MenuActionBindingState extends State<MenuActionBinding> {
  final Object _token = Object();

  @override
  void initState() {
    super.initState();
    MenuActionDispatcher.instance.register(_token, widget.handler);
  }

  @override
  void didUpdateWidget(MenuActionBinding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.handler, widget.handler)) {
      MenuActionDispatcher.instance.register(_token, widget.handler);
    }
  }

  @override
  void dispose() {
    MenuActionDispatcher.instance.unregister(_token);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
