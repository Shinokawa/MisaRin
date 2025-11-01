import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

class ExitToolButton extends StatelessWidget {
  const ExitToolButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final bool isDark = theme.brightness.isDark;
    final Color borderColor =
        isDark ? const Color(0xFFEA5F66) : const Color(0xFFD13438);
    final Color backgroundColor =
        isDark ? const Color(0xFF3C1C1E) : const Color(0xFFFDE7E9);
    final Color iconColor =
        isDark ? const Color(0xFFFFB3B6) : const Color(0xFF8A1414);
    final Color shadowColor =
        isDark ? const Color(0x55EA5F66) : const Color(0x1AD13438);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 9,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(FluentIcons.back, color: iconColor, size: 20),
        ),
      ),
    );
  }
}
