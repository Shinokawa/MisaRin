import 'package:fluent_ui/fluent_ui.dart';

class LayerVisibilityButton extends StatelessWidget {
  const LayerVisibilityButton({
    super.key,
    required this.visible,
    required this.onChanged,
    this.size = 24,
    this.iconSize = 14,
  });

  final bool visible;
  final ValueChanged<bool>? onChanged;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final bool enabled = onChanged != null;
    final Color accent = theme.accentColor.defaultBrushFor(theme.brightness);
    final Color borderColor = theme.resources.controlStrokeColorDefault;
    final Color background = enabled
        ? Color.lerp(
              borderColor.withValues(alpha: borderColor.a * 0.1),
              accent,
              0.05,
            )!
        : theme.resources.controlFillColorDisabled;
    final Color iconColor =
        enabled
            ? visible
                ? accent
                : theme.brightness.isDark
                    ? const Color(0xFFC0C0C0)
                    : const Color(0xFF666666)
            : theme.resources.textFillColorDisabled;

    final double radius = size * 0.25;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!visible) : null,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: background,
            border: Border.all(
              color: enabled
                  ? borderColor.withValues(alpha: borderColor.a * 0.6)
                  : borderColor.withValues(alpha: borderColor.a * 0.35),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              visible ? FluentIcons.red_eye : FluentIcons.hide3,
              size: iconSize,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
