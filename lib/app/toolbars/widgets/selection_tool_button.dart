import 'package:fluent_ui/fluent_ui.dart';

import 'package:misa_rin/canvas/canvas_tools.dart';

import 'selection_shape_icon.dart';
import 'toolbar_tool_button_frame.dart';

class SelectionToolButton extends StatelessWidget {
  const SelectionToolButton({
    super.key,
    required this.isSelected,
    required this.selectionShape,
    required this.onPressed,
  });

  final bool isSelected;
  final SelectionShape selectionShape;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ToolbarToolButtonFrame(
      isSelected: isSelected,
      onPressed: onPressed,
      builder: (context, iconColor, _) => Center(
        child: SelectionShapeIcon(
          shape: selectionShape,
          color: iconColor,
          size: 24,
        ),
      ),
    );
  }
}
