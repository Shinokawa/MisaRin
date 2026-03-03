import 'package:fluent_ui/fluent_ui.dart';
import 'mobile_rounded_button.dart';

class MobileUndoRedoButtons extends StatelessWidget {
  const MobileUndoRedoButtons({
    super.key,
    required this.onUndo,
    required this.onRedo,
  });

  final VoidCallback onUndo;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final Color iconColor = theme.resources.textFillColorPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 62, 12, 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MobileRoundedButton(
            onPressed: onUndo,
            child: Icon(
              FluentIcons.undo,
              size: 24,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          MobileRoundedButton(
            onPressed: onRedo,
            child: Icon(
              FluentIcons.redo,
              size: 24,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}
