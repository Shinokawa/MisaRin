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
    final theme = FluentTheme.of(context);
    final bool isDark = theme.brightness.isDark;
    final Color borderColor = enabled
        ? (isDark ? const Color(0xFF4AA553) : const Color(0xFF0F7A0B))
        : (isDark ? const Color(0xFF2E3C30) : const Color(0xFFC6D7C6));
    final Color backgroundColor = enabled
        ? (isDark ? const Color(0xFF17331B) : const Color(0xFFEAF7EA))
        : (isDark ? const Color(0xFF1F2721) : const Color(0xFFF2F7F2));
    final Color iconColor = enabled
        ? (isDark ? const Color(0xFF90F09D) : const Color(0xFF0B5A09))
        : (isDark ? const Color(0xFF5F7262) : const Color(0xFF8AA08A));
    final Color shadowColor = enabled
        ? Color.lerp(
            Colors.transparent,
            isDark ? const Color(0xFF4AA553) : const Color(0xFF0F7A0B),
            isDark ? 0.4 : 0.2,
          )!
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
          child: Icon(FluentIcons.undo, color: iconColor, size: 20),
        ),
      ),
    );
  }
}
