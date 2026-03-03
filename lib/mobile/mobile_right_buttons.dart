import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show Listenable;
import 'mobile_bottom_sheet.dart';
import 'mobile_rounded_button.dart';
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
            MobileRoundedButton(
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
