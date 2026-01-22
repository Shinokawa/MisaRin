part of 'painting_board.dart';

extension _PaintingBoardLayerTransformPanelBuilder
    on _PaintingBoardLayerTransformMixin {
  Widget? _buildLayerTransformPanelBody() {
    if (!_layerTransformModeActive) {
      return null;
    }
    final _LayerTransformStateModel? state = _layerTransformState;
    final bool ready = state != null;
    final FluentThemeData theme = FluentTheme.of(context);
    final l10n = context.l10n;
    return Positioned(
      left: _layerTransformPanelOffset.dx,
      top: _layerTransformPanelOffset.dy,
      child: MeasuredSize(
        onChanged: _handleLayerTransformPanelSizeChanged,
        child: WorkspaceFloatingPanel(
          width: _kLayerTransformPanelWidth,
          minHeight: _kLayerTransformPanelMinHeight,
          title: l10n.freeTransformTitle,
          onDragUpdate: _updateLayerTransformPanelOffset,
          onClose: _cancelLayerFreeTransform,
          footerPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          child: ready
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.rotationLabel(
                        (state!.rotation * 180 / math.pi).toStringAsFixed(1),
                      ),
                      style: theme.typography.body,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.scaleLabel(
                        (state.scaleX * 100).toStringAsFixed(1),
                        (state.scaleY * 100).toStringAsFixed(1),
                      ),
                      style: theme.typography.body,
                    ),
                  ],
                )
              : Row(
                  children: [
                    const ProgressRing(),
                    const SizedBox(width: 8),
                    Text(l10n.preparingLayer),
                  ],
                ),
          footer: Row(
            children: [
              Button(
                onPressed: ready && !_layerTransformApplying
                    ? () {
                        setState(() {
                          state!.reset();
                          _layerTransformRevision++;
                        });
                        _updateRustLayerTransformPreview();
                      }
                    : null,
                child: Text(l10n.reset),
              ),
              const Spacer(),
              Button(
                onPressed: _layerTransformApplying
                    ? null
                    : _cancelLayerFreeTransform,
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: ready && !_layerTransformApplying
                    ? () => _confirmLayerFreeTransform()
                    : null,
                child: _layerTransformApplying
                    ? const ProgressRing()
                    : Text(l10n.apply),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
