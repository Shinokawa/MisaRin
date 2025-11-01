import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

class HandToolButton extends StatelessWidget {
  const HandToolButton({
    super.key,
    required this.isSelected,
    required this.onPressed,
  });

  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final bool isDark = theme.brightness.isDark;
    final Color accent = theme.accentColor.defaultBrushFor(theme.brightness);
    final Color borderColor = isSelected
        ? accent
        : (isDark ? const Color(0xFF373737) : const Color(0xFFD6D6D6));
    final Color backgroundColor = isSelected
        ? (isDark ? const Color(0xFF262626) : const Color(0xFFFAFAFA))
        : (isDark ? const Color(0xFF1B1B1F) : const Color(0xFFFFFFFF));
    final Color iconColor = isSelected
        ? accent
        : (isDark ? const Color(0xFFE1E1E7) : const Color(0xFF323130));
    final Color shadowColor = isSelected
        ? accent.withOpacity(isDark ? 0.45 : 0.28)
        : (isDark ? Colors.black.withOpacity(0.45) : Colors.black);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: isSelected ? 9 : 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(FluentIcons.handwriting, color: iconColor, size: 20),
        ),
      ),
    );
  }
}
