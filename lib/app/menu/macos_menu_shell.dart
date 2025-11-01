import 'package:flutter/widgets.dart';

import 'macos_menu_builder.dart';

class MacosMenuShell extends StatelessWidget {
  const MacosMenuShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PlatformMenuBar(
      menus: MacosMenuBuilder.build(),
      child: child,
    );
  }
}
