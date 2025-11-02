import 'package:flutter/widgets.dart';

import 'macos_menu_builder.dart';
import 'menu_action_dispatcher.dart';

class MacosMenuShell extends StatelessWidget {
  const MacosMenuShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dispatcher = MenuActionDispatcher.instance;
    return AnimatedBuilder(
      animation: dispatcher,
      builder: (context, menuChild) {
        return PlatformMenuBar(
          menus: MacosMenuBuilder.build(dispatcher.current),
          child: menuChild!,
        );
      },
      child: child,
    );
  }
}
