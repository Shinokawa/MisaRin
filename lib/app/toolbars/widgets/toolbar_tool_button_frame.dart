import 'package:fluent_ui/fluent_ui.dart';

typedef ToolbarToolButtonBuilder =
    Widget Function(BuildContext context, Color iconColor, bool isHovered);

class ToolbarToolButtonFrame extends StatefulWidget {
  const ToolbarToolButtonFrame({
    super.key,
    required this.isSelected,
    required this.onPressed,
    required this.builder,
  });

  final bool isSelected;
  final VoidCallback onPressed;
  final ToolbarToolButtonBuilder builder;

  @override
  State<ToolbarToolButtonFrame> createState() => _ToolbarToolButtonFrameState();
}

class _ToolbarToolButtonFrameState extends State<ToolbarToolButtonFrame> {
  static const double _buttonExtent = 48;

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
    final Color accent = theme.accentColor.defaultBrushFor(theme.brightness);

    final bool showHover = _hovered && !widget.isSelected;

    final Color baseBorder = isDark
        ? const Color(0xFF373737)
        : const Color(0xFFD6D6D6);
    final Color hoverBorder = isDark
        ? const Color(0xFF4F4F4F)
        : const Color(0xFFBABABA);
    final Color baseBackground = isDark
        ? const Color(0xFF1B1B1F)
        : Colors.white;
    final Color hoverBackground = isDark
        ? const Color(0xFF232328)
        : const Color(0xFFF5F5F5);
    final Color selectedBackground = isDark
        ? const Color(0xFF262626)
        : const Color(0xFFFAFAFA);

    final Color baseIcon = isDark
        ? const Color(0xFFE1E1E7)
        : const Color(0xFF323130);
    final Color hoverIcon = isDark ? Colors.white : const Color(0xFF201F1E);

    final Color backgroundColor = widget.isSelected
        ? selectedBackground
        : (showHover ? hoverBackground : baseBackground);
    final Color borderColor = widget.isSelected
        ? accent
        : (showHover ? hoverBorder : baseBorder);
    final Color iconColor = widget.isSelected
        ? accent
        : (showHover ? hoverIcon : baseIcon);

    final List<BoxShadow> shadows = <BoxShadow>[];
    if (showHover) {
      shadows.add(
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          width: _buttonExtent,
          height: _buttonExtent,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: shadows,
          ),
          child: widget.builder(context, iconColor, _hovered),
        ),
      ),
    );
  }
}
