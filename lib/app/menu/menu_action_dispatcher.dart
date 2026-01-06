import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';

import '../models/workspace_layout.dart';
import '../../canvas/perspective_guide.dart';

typedef MenuAsyncAction = FutureOr<void> Function();
typedef MenuPaletteAction = FutureOr<void> Function(String paletteId);
typedef MenuWorkspaceLayoutAction =
    FutureOr<void> Function(WorkspaceLayoutPreference preference);
typedef MenuActionEnabledResolver = bool Function();

class MenuPaletteMenuEntry {
  const MenuPaletteMenuEntry({required this.id, required this.label});

  final String id;
  final String label;
}

class MenuActionHandler {
  const MenuActionHandler({
    this.newProject,
    this.open,
    this.closeAll,
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
    this.generateGradientPalette,
    this.importPalette,
    this.selectPaletteFromMenu,
    this.paletteMenuEntries = const <MenuPaletteMenuEntry>[],
    this.resizeImage,
    this.resizeCanvas,
    this.mergeLayerDown,
    this.rasterizeLayer,
    this.rasterizeLayerEnabled,
    this.binarizeLayer,
    this.layerFreeTransform,
    this.adjustHueSaturation,
    this.adjustBrightnessContrast,
    this.adjustBlackWhite,
    this.invertColors,
    this.scanPaperDrawing,
    this.colorRange,
    this.narrowLines,
    this.expandFill,
    this.selectAll,
    this.invertSelection,
    this.showLayerAntialiasPanel,
    this.gaussianBlur,
    this.removeColorLeak,
    this.createReferenceImage,
    this.importReferenceImage,
    this.showSteveReferenceModel,
    this.showAlexReferenceModel,
    this.importReferenceModel,
    this.workspaceLayoutPreference,
    this.switchWorkspaceLayout,
    this.resetWorkspaceLayout,
    this.togglePixelGrid,
    this.pixelGridVisible = false,
    this.toggleViewBlackWhite,
    this.viewBlackWhiteEnabled = false,
    this.toggleViewMirror,
    this.viewMirrorEnabled = false,
    this.togglePerspectiveGuide,
    this.setPerspectiveOnePoint,
    this.setPerspectiveTwoPoint,
    this.setPerspectiveThreePoint,
    this.perspectiveMode = PerspectiveGuideMode.off,
    this.perspectiveVisible = false,
  });

  const MenuActionHandler.empty()
    : newProject = null,
      open = null,
      closeAll = null,
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
      generateGradientPalette = null,
      importPalette = null,
      selectPaletteFromMenu = null,
      resizeImage = null,
      resizeCanvas = null,
      mergeLayerDown = null,
      rasterizeLayer = null,
      rasterizeLayerEnabled = null,
      binarizeLayer = null,
      layerFreeTransform = null,
      adjustHueSaturation = null,
      adjustBrightnessContrast = null,
      adjustBlackWhite = null,
      invertColors = null,
      scanPaperDrawing = null,
      colorRange = null,
      narrowLines = null,
      expandFill = null,
      selectAll = null,
      invertSelection = null,
      showLayerAntialiasPanel = null,
      gaussianBlur = null,
      removeColorLeak = null,
      createReferenceImage = null,
      importReferenceImage = null,
      showSteveReferenceModel = null,
      showAlexReferenceModel = null,
      importReferenceModel = null,
      paletteMenuEntries = const <MenuPaletteMenuEntry>[],
      workspaceLayoutPreference = null,
      switchWorkspaceLayout = null,
      resetWorkspaceLayout = null,
      togglePixelGrid = null,
      pixelGridVisible = false,
      toggleViewBlackWhite = null,
      viewBlackWhiteEnabled = false,
      toggleViewMirror = null,
      viewMirrorEnabled = false,
      togglePerspectiveGuide = null,
      setPerspectiveOnePoint = null,
      setPerspectiveTwoPoint = null,
      setPerspectiveThreePoint = null,
      perspectiveMode = PerspectiveGuideMode.off,
      perspectiveVisible = false;

  final MenuAsyncAction? newProject;
  final MenuAsyncAction? open;
  final MenuAsyncAction? closeAll;
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
  final MenuAsyncAction? generateGradientPalette;
  final MenuAsyncAction? importPalette;
  final MenuPaletteAction? selectPaletteFromMenu;
  final List<MenuPaletteMenuEntry> paletteMenuEntries;
  final MenuAsyncAction? resizeImage;
  final MenuAsyncAction? resizeCanvas;
  final MenuAsyncAction? mergeLayerDown;
  final MenuAsyncAction? rasterizeLayer;
  final MenuActionEnabledResolver? rasterizeLayerEnabled;
  final MenuAsyncAction? binarizeLayer;
  final MenuAsyncAction? layerFreeTransform;
  final MenuAsyncAction? adjustHueSaturation;
  final MenuAsyncAction? adjustBrightnessContrast;
  final MenuAsyncAction? adjustBlackWhite;
  final MenuAsyncAction? invertColors;
  final MenuAsyncAction? scanPaperDrawing;
  final MenuAsyncAction? colorRange;
  final MenuAsyncAction? narrowLines;
  final MenuAsyncAction? expandFill;
  final MenuAsyncAction? selectAll;
  final MenuAsyncAction? invertSelection;
  final MenuAsyncAction? showLayerAntialiasPanel;
  final MenuAsyncAction? gaussianBlur;
  final MenuAsyncAction? removeColorLeak;
  final MenuAsyncAction? createReferenceImage;
  final MenuAsyncAction? importReferenceImage;
  final MenuAsyncAction? showSteveReferenceModel;
  final MenuAsyncAction? showAlexReferenceModel;
  final MenuAsyncAction? importReferenceModel;
  final WorkspaceLayoutPreference? workspaceLayoutPreference;
  final MenuWorkspaceLayoutAction? switchWorkspaceLayout;
  final MenuAsyncAction? resetWorkspaceLayout;
  final MenuAsyncAction? togglePixelGrid;
  final bool pixelGridVisible;
  final MenuAsyncAction? toggleViewBlackWhite;
  final bool viewBlackWhiteEnabled;
  final MenuAsyncAction? toggleViewMirror;
  final bool viewMirrorEnabled;
  final MenuAsyncAction? togglePerspectiveGuide;
  final MenuAsyncAction? setPerspectiveOnePoint;
  final MenuAsyncAction? setPerspectiveTwoPoint;
  final MenuAsyncAction? setPerspectiveThreePoint;
  final PerspectiveGuideMode perspectiveMode;
  final bool perspectiveVisible;
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

  void refresh() {
    _scheduleNotify();
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
