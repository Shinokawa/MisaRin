import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/widgets.dart' show Image;

import 'package:misa_rin/canvas/canvas_tools.dart';

class ShapeToolButton extends StatelessWidget {
  const ShapeToolButton({
    super.key,
    required this.isSelected,
    required this.variant,
    required this.onPressed,
  });

  final bool isSelected;
  final ShapeToolVariant variant;
  final VoidCallback onPressed;

  static IconData _iconForVariant(ShapeToolVariant variant) {
    switch (variant) {
      case ShapeToolVariant.rectangle:
        return FluentIcons.rectangle_shape;
      case ShapeToolVariant.ellipse:
        return FluentIcons.circle_shape;
      case ShapeToolVariant.triangle:
        return FluentIcons.triangle_shape;
      case ShapeToolVariant.line:
        return FluentIcons.line_style;
    }
  }

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
          child: Center(child: _buildIcon(iconColor)),
        ),
      ),
    );
  }

  Widget _buildIcon(Color color) {
    if (variant == ShapeToolVariant.line) {
      return Image.asset(
        'icons/line2.png',
        width: 24,
        height: 24,
        color: color,
        colorBlendMode: BlendMode.srcIn,
        filterQuality: FilterQuality.high,
      );
    }
    return Icon(_iconForVariant(variant), color: color, size: 24);
  }
}
