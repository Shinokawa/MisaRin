import 'package:fluent_ui/fluent_ui.dart';

import '../../canvas/canvas_tools.dart';

class SelectionToolButton extends StatelessWidget {
  const SelectionToolButton({
    super.key,
    required this.isSelected,
    required this.selectionShape,
    required this.onPressed,
  });

  final bool isSelected;
  final SelectionShape selectionShape;
  final VoidCallback onPressed;

  static const Map<SelectionShape, String> _iconAssetMap = {
    SelectionShape.rectangle: 'icons/warp1.png',
    SelectionShape.ellipse: 'icons/warp2.png',
    SelectionShape.polygon: 'icons/warp3.png',
  };

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
        : (isDark ? Colors.white : const Color(0xFF323130));
    final Color shadowColor = isSelected
        ? Color.lerp(
            Colors.transparent,
            accent,
            isDark ? 0.45 : 0.28,
          )!
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
          child: Center(
            child: Image.asset(
              _iconAssetMap[selectionShape]!,
              width: 24,
              height: 24,
              color: iconColor,
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
