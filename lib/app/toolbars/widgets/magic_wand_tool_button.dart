import 'package:fluent_ui/fluent_ui.dart';

import 'toolbar_tool_button_frame.dart';

class MagicWandToolButton extends StatelessWidget {
  const MagicWandToolButton({
    super.key,
    required this.isSelected,
    required this.onPressed,
  });

  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ToolbarToolButtonFrame(
      isSelected: isSelected,
      onPressed: onPressed,
      builder: (context, iconColor, _) =>
          Icon(FluentIcons.auto_enhance_on, color: iconColor, size: 20),
    );
  }
}
