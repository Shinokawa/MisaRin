part of 'painting_board.dart';

class _ClipboardPayload {
  _ClipboardPayload({required this.layerData});

  final CanvasLayerData layerData;
}

mixin _PaintingBoardClipboardMixin on _PaintingBoardBase {
  _ClipboardPayload? _clipboard;

  bool cut() {
    return _copyActiveLayer(clearAfter: true);
  }

  bool copy() {
    return _copyActiveLayer(clearAfter: false);
  }

  bool paste() {
    return _performPaste();
  }

  bool _copyActiveLayer({required bool clearAfter}) {
    final String? activeLayerId = _activeLayerId;
    if (activeLayerId == null) {
      return false;
    }
    final Uint8List? selection = selectionMaskSnapshot;
    final CanvasLayerData? layer = _controller.buildClipboardLayer(
      activeLayerId,
      mask: selection,
    );
    if (layer == null) {
      return false;
    }
    _clipboard = _ClipboardPayload(layerData: layer.copyWith());
    if (!clearAfter) {
      return true;
    }
    _pushUndoSnapshot();
    _controller.clearLayerRegion(activeLayerId, mask: selection);
    setState(() {
      setSelectionState(path: null, mask: null);
      clearSelectionArtifacts();
    });
    _updateSelectionAnimation();
    _markDirty();
    return true;
  }

  bool _performPaste() {
    final _ClipboardPayload? payload = _clipboard;
    if (payload == null) {
      return false;
    }
    final CanvasLayerData source = payload.layerData;
    final String newId = generateLayerId();
    final String pasteName = source.name.isEmpty
        ? '粘贴图层'
        : '${source.name} 副本';
    final CanvasLayerData layerData = source.copyWith(
      id: newId,
      name: pasteName,
      visible: true,
      locked: false,
      clippingMask: false,
    );
    _pushUndoSnapshot();
    _controller.insertLayerFromData(
      layerData,
      aboveLayerId: _activeLayerId,
    );
    _controller.setActiveLayer(newId);
    setState(() {
      setSelectionState(path: null, mask: null);
      clearSelectionArtifacts();
    });
    _updateSelectionAnimation();
    _markDirty();
    return true;
  }
}
