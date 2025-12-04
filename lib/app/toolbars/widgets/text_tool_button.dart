import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;

import 'toolbar_tool_button_frame.dart';

class TextToolButton extends StatelessWidget {
  const TextToolButton({
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
      builder: (context, iconColor, _) => Icon(
        Icons.text_fields,
        size: 25,
        color: iconColor,
      ),
    );
  }
}
