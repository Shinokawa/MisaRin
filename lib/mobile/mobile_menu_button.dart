import 'package:fluent_ui/fluent_ui.dart';
import 'mobile_menu_sheet.dart';
import 'mobile_bottom_sheet.dart';

class MobileMenuButton extends StatelessWidget {
  const MobileMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.micaBackgroundColor.withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.resources.controlStrokeColorDefault,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            FluentIcons.global_nav_button,
            size: 28,
            color: theme.resources.textFillColorPrimary,
          ),
        ),
        onPressed: () => _showMenu(context),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showMobileBottomSheet(
      context: context,
      child: const MobileMenuSheet(),
    );
  }
}
