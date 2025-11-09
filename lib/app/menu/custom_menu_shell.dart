import 'package:flutter/widgets.dart';

import 'custom_menu_bar.dart';
import 'menu_action_dispatcher.dart';
import 'menu_definitions.dart';

class CustomMenuShell extends StatelessWidget {
  const CustomMenuShell({super.key, required this.child, this.navigatorKey});

  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    final MenuActionDispatcher dispatcher = MenuActionDispatcher.instance;
    return AnimatedBuilder(
      animation: dispatcher,
      builder: (context, menuChild) {
        if (menuChild == null) {
          return const SizedBox.shrink();
        }
        final List<MenuDefinition> menus = MenuDefinitionBuilder.build(
          dispatcher.current,
        );
        return _MenuOverlay(
          menus: menus,
          navigatorKey: navigatorKey,
          child: menuChild,
        );
      },
      child: child,
    );
  }
}

class _MenuOverlay extends StatefulWidget {
  const _MenuOverlay({
    required this.menus,
    required this.child,
    this.navigatorKey,
  });

  final List<MenuDefinition> menus;
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<_MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<_MenuOverlay> {
  late final OverlayEntry _overlayEntry;

  @override
  void initState() {
    super.initState();
    _overlayEntry = OverlayEntry(builder: _buildOverlayContent);
  }

  @override
  void didUpdateWidget(covariant _MenuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _overlayEntry.markNeedsBuild();
  }

  Widget _buildOverlayContent(BuildContext context) {
    return Column(
      children: [
        CustomMenuBar(menus: widget.menus, navigatorKey: widget.navigatorKey),
        Expanded(child: widget.child),
      ],
    );
  }

  @override
  void dispose() {
    _overlayEntry.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(initialEntries: <OverlayEntry>[_overlayEntry]);
  }
}
