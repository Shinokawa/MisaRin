import 'package:fluent_ui/fluent_ui.dart';

import 'toolbar_tool_button_frame.dart';

class ViewRotateToolButton extends StatelessWidget {
  const ViewRotateToolButton({
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
          Icon(FluentIcons.rotate, color: iconColor, size: 20),
    );
  }
}
