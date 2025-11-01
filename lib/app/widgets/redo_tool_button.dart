import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

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
    final theme = FluentTheme.of(context);
    final bool isDark = theme.brightness.isDark;
    final Color borderColor = enabled
        ? (isDark ? const Color(0xFF3C8AD1) : const Color(0xFF0B6BAA))
        : (isDark ? const Color(0xFF2A3945) : const Color(0xFFC4D4E1));
    final Color backgroundColor = enabled
        ? (isDark ? const Color(0xFF14273B) : const Color(0xFFE6F1FB))
        : (isDark ? const Color(0xFF1D242B) : const Color(0xFFF1F5F8));
    final Color iconColor = enabled
        ? (isDark ? const Color(0xFF9CD0FF) : const Color(0xFF004E8C))
        : (isDark ? const Color(0xFF5F6E7D) : const Color(0xFF7F8FA0));
    final Color shadowColor = enabled
        ? (isDark ? const Color(0x663C8AD1) : const Color(0x260B6BAA))
        : Colors.transparent;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              if (enabled)
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 7,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: Icon(FluentIcons.redo, color: iconColor, size: 20),
        ),
      ),
    );
  }
}
