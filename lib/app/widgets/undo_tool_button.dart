import 'package:fluent_ui/fluent_ui.dart';

class UndoToolButton extends StatelessWidget {
  const UndoToolButton({
    super.key,
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = enabled
        ? const Color(0xFF0078D4)
        : const Color(0xFFD6D6D6);
    final Color backgroundColor = enabled
        ? const Color(0xFFE5F1FB)
        : const Color(0xFFF4F4F4);
    final Color iconColor = enabled
        ? const Color(0xFF003A6D)
        : const Color(0xFF7A7A7A);

    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: Color(0x260078D4),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ]
              : const [],
        ),
        child: Icon(FluentIcons.undo, color: iconColor, size: 14),
      ),
    );
  }
}
