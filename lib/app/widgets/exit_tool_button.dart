import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

class ExitToolButton extends StatelessWidget {
  const ExitToolButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFDE7E9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD13438), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1AD13438),
                blurRadius: 9,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child:
              const Icon(FluentIcons.back, color: Color(0xFF8A1414), size: 20),
        ),
      ),
    );
  }
}
