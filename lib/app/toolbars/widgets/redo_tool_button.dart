import 'package:fluent_ui/fluent_ui.dart';

class RedoToolButton extends StatefulWidget {
  const RedoToolButton({
    super.key,
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<RedoToolButton> createState() => _RedoToolButtonState();
}

class _RedoToolButtonState extends State<RedoToolButton> {
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
    final bool enabled = widget.enabled;

    final Color enabledBorder = isDark
        ? const Color(0xFF3C8AD1)
        : const Color(0xFF0B6BAA);
    final Color disabledBorder = isDark
        ? const Color(0xFF2A3945)
        : const Color(0xFFC4D4E1);
    final Color enabledBackground = isDark
        ? const Color(0xFF14273B)
        : const Color(0xFFE6F1FB);
    final Color hoverBackground = isDark
        ? const Color(0xFF1E3450)
        : const Color(0xFFDCEBFA);
    final Color disabledBackground = isDark
        ? const Color(0xFF1D242B)
        : const Color(0xFFF1F5F8);
    final Color enabledIcon = isDark
        ? const Color(0xFF9CD0FF)
        : const Color(0xFF004E8C);
    final Color hoverIcon = isDark
        ? const Color(0xFFC1E0FF)
        : const Color(0xFF003865);
    final Color disabledIcon = isDark
        ? const Color(0xFF5F6E7D)
        : const Color(0xFF7F8FA0);

    final bool showHover = enabled && _hovered;
    final Color borderColor = enabled
        ? (showHover
              ? Color.lerp(enabledBorder, Colors.white, isDark ? 0.2 : 0.05)!
              : enabledBorder)
        : disabledBorder;
    final Color backgroundColor = enabled
        ? (showHover ? hoverBackground : enabledBackground)
        : disabledBackground;
    final Color iconColor = enabled
        ? (showHover ? hoverIcon : enabledIcon)
        : disabledIcon;

    final List<BoxShadow> shadows = <BoxShadow>[];
    if (enabled) {
      shadows.add(
        BoxShadow(
          color: Color.lerp(
            Colors.transparent,
            enabledBorder,
            isDark ? 0.4 : 0.2,
          )!.withOpacity(showHover ? 1 : 0.85),
          blurRadius: showHover ? 9 : 7,
          offset: const Offset(0, 3),
        ),
      );
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (enabled) {
          _handleHover(true);
        }
      },
      onExit: (_) {
        if (enabled) {
          _handleHover(false);
        }
      },
      child: GestureDetector(
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: shadows,
          ),
          child: Icon(FluentIcons.redo, color: iconColor, size: 20),
        ),
      ),
    );
  }
}
