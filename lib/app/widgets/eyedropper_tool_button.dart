import 'package:fluent_ui/fluent_ui.dart';

class EyedropperToolButton extends StatelessWidget {
  const EyedropperToolButton({
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
        ? Color.lerp(Colors.transparent, accent, isDark ? 0.45 : 0.28)!
        : Colors.transparent;

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
              if (isSelected)
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 9,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Icon(FluentIcons.color, color: iconColor, size: 20),
        ),
      ),
    );
  }
}
