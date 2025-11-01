import 'package:fluent_ui/fluent_ui.dart';

class RedoToolButton extends StatelessWidget {
  const RedoToolButton({
    super.key,
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = enabled
        ? const Color(0xFF0B6BAA)
        : const Color(0xFFC4D4E1);
    final Color backgroundColor = enabled
        ? const Color(0xFFE6F1FB)
        : const Color(0xFFF1F5F8);
    final Color iconColor = enabled
        ? const Color(0xFF004E8C)
        : const Color(0xFF7F8FA0);

    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: Color(0x260B6BAA),
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  ),
                ]
              : const [],
        ),
        child: Icon(FluentIcons.redo, color: iconColor, size: 20),
      ),
    );
  }
}
