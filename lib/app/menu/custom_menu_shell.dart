import 'package:flutter/widgets.dart';

import 'custom_menu_bar.dart';
import 'menu_action_dispatcher.dart';
import 'menu_definitions.dart';

class CustomMenuShell extends StatelessWidget {
  const CustomMenuShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MenuActionDispatcher dispatcher = MenuActionDispatcher.instance;
    return AnimatedBuilder(
      animation: dispatcher,
      builder: (context, menuChild) {
        final List<MenuDefinition> menus = MenuDefinitionBuilder.build(
          dispatcher.current,
        );
        return Column(
          children: [
            CustomMenuBar(menus: menus),
            Expanded(child: menuChild!),
          ],
        );
      },
      child: child,
    );
  }
}
