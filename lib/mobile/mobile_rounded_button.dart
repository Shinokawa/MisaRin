import 'package:fluent_ui/fluent_ui.dart';

import '../app/toolbars/widgets/canvas_toolbar.dart';

class MobileRoundedButton extends StatefulWidget {
  const MobileRoundedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.size = CanvasToolbar.buttonSize,
    this.padding = const EdgeInsets.all(6),
  });

  final VoidCallback onPressed;
  final Widget child;
  final double size;
  final EdgeInsets padding;

  @override
  State<MobileRoundedButton> createState() => _MobileRoundedButtonState();
}

class _MobileRoundedButtonState extends State<MobileRoundedButton> {
  bool _hovered = false;

  void _setHover(bool hovered) {
    if (_hovered == hovered) {
      return;
    }
    setState(() => _hovered = hovered);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final bool isDark = theme.brightness.isDark;
    final Color borderColor = isDark
        ? const Color(0xFF373737)
        : const Color(0xFFD6D6D6);
    final Color baseBackground = isDark
        ? const Color(0xFF1B1B1F)
        : Colors.white;
    final Color hoverOverlay = (isDark ? Colors.white : Colors.black)
        .withOpacity(isDark ? 0.08 : 0.05);
    final Color background = _hovered
        ? Color.alphaBlend(hoverOverlay, baseBackground)
        : baseBackground;
    final Color border = _hovered
        ? Color.lerp(
                borderColor,
                isDark ? Colors.white : Colors.black,
                isDark ? 0.25 : 0.15,
              ) ??
              borderColor
        : borderColor;
    final List<BoxShadow>? shadows = _hovered
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ]
        : null;

    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          width: widget.size,
          height: widget.size,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: 1.5),
            boxShadow: shadows,
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}
