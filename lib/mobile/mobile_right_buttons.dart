import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show Listenable;
import 'mobile_bottom_sheet.dart';
import '../app/dialogs/misarin_dialog.dart';

class MobileRightButtons extends StatelessWidget {
  const MobileRightButtons({
    super.key,
    required this.colorIndicator,
    required this.layerPanelBuilder,
    this.rebuildListenable,
  });

  final Widget colorIndicator;
  final WidgetBuilder layerPanelBuilder;
  final Listenable? rebuildListenable;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            colorIndicator,
            const SizedBox(height: 16),
            _MobileCircleButton(
              onPressed: () => _showLayerManager(context),
              child: const Icon(
                FluentIcons.map_layers,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLayerManager(BuildContext context) {
    showMobileBottomSheet(
      context: context,
      rebuildListenable: rebuildListenable,
      builder: (context) => MisarinDialog(
        title: const Text('Layers'),
        content: layerPanelBuilder(context),
      ),
    );
  }
}

class _MobileCircleButton extends StatelessWidget {
  const _MobileCircleButton({required this.onPressed, required this.child});

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return IconButton(
      onPressed: onPressed,
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: theme.micaBackgroundColor.withOpacity(0.9),
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.resources.controlStrokeColorDefault,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}
