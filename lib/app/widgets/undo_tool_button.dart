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
        ? const Color(0xFF0F7A0B)
        : const Color(0xFFC6D7C6);
    final Color backgroundColor = enabled
        ? const Color(0xFFEAF7EA)
        : const Color(0xFFF2F7F2);
    final Color iconColor = enabled
        ? const Color(0xFF0B5A09)
        : const Color(0xFF8AA08A);

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
                    color: Color(0x260F7A0B),
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
