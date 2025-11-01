import 'package:fluent_ui/fluent_ui.dart';

class ExitToolButton extends StatelessWidget {
  const ExitToolButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFFDE7E9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD13438), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1AD13438),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(FluentIcons.back, color: Color(0xFF8A1414), size: 14),
      ),
    );
  }
}
