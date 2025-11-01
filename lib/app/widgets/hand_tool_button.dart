import 'package:fluent_ui/fluent_ui.dart';

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
    final Color borderColor = isSelected
        ? const Color(0xFF0078D4)
        : const Color(0xFFD6D6D6);
    final Color backgroundColor = theme.brightness.isDark
        ? const Color(0xFF1F1F1F)
        : const Color(0xFFFFFFFF);
    final Color iconColor = isSelected
        ? const Color(0xFF005A9E)
        : const Color(0xFF323130);

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x330078D4),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
        ),
        child: Icon(FluentIcons.handwriting, color: iconColor, size: 28),
      ),
    );
  }
}
