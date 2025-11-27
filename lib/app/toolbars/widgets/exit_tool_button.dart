import 'package:fluent_ui/fluent_ui.dart';

class ExitToolButton extends StatefulWidget {
  const ExitToolButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<ExitToolButton> createState() => _ExitToolButtonState();
}

class _ExitToolButtonState extends State<ExitToolButton> {
  bool _hovered = false;

  void _handleHover(bool hovered) {
    if (_hovered == hovered) {
      return;
    }
    setState(() => _hovered = hovered);
  }

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final bool isDark = theme.brightness.isDark;
    final Color borderColor = isDark
        ? const Color(0xFFEA5F66)
        : const Color(0xFFD13438);
    final Color backgroundColor = isDark
        ? const Color(0xFF3C1C1E)
        : const Color(0xFFFDE7E9);
    final Color iconColor = isDark
        ? const Color(0xFFFFB3B6)
        : const Color(0xFF8A1414);
    final Color shadowColor = isDark
        ? const Color(0x55EA5F66)
        : const Color(0x1AD13438);

    final bool showHover = _hovered;
    final Color hoverOverlay = (isDark ? Colors.white : Colors.black)
        .withOpacity(isDark ? 0.1 : 0.06);
    final Color resolvedBackground = showHover
        ? Color.alphaBlend(hoverOverlay, backgroundColor)
        : backgroundColor;
    final Color resolvedBorder = showHover
        ? Color.lerp(borderColor, Colors.white, isDark ? 0.2 : 0.05) ??
              borderColor
        : borderColor;
    final Color resolvedIcon = showHover
        ? Color.lerp(iconColor, Colors.white, 0.25)!
        : iconColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: resolvedBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: resolvedBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: showHover
                    ? shadowColor.withOpacity(isDark ? 0.9 : 0.7)
                    : shadowColor,
                blurRadius: showHover ? 12 : 9,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(FluentIcons.back, color: resolvedIcon, size: 20),
        ),
      ),
    );
  }
}
