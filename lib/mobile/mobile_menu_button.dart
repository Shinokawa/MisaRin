import 'package:fluent_ui/fluent_ui.dart';
import 'mobile_bottom_sheet.dart';
import 'mobile_menu_sheet.dart';
import 'mobile_rounded_button.dart';

class MobileMenuButton extends StatelessWidget {
  const MobileMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 42, 12, 12),
      child: MobileRoundedButton(
        onPressed: () => _showMenu(context),
        child: Icon(
          FluentIcons.global_nav_button,
          size: 28,
          color: theme.resources.textFillColorPrimary,
        ),
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
