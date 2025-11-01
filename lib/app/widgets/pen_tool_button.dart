import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

class PenToolButton extends StatelessWidget {
  const PenToolButton({
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
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x330078D4),
                      blurRadius: 9,
                      offset: Offset(0, 4),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
          ),
          child: const _PenGraphic(),
        ),
      ),
    );
  }
}

class _PenGraphic extends StatelessWidget {
  const _PenGraphic();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        angle: -0.5,
        child: SizedBox(
          height: 26,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: Colors.black, width: 1.2),
                ),
              ),
              Expanded(
                child: Container(
                  width: 8,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
