import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

typedef MenuAsyncAction = FutureOr<void> Function();

class MenuActionHandler {
  const MenuActionHandler({
    this.newProject,
    this.preferences,
    this.about,
    this.save,
    this.undo,
    this.redo,
    this.zoomIn,
    this.zoomOut,
  });

  const MenuActionHandler.empty()
    : newProject = null,
      preferences = null,
      about = null,
      save = null,
      undo = null,
      redo = null,
      zoomIn = null,
      zoomOut = null;

  final MenuAsyncAction? newProject;
  final MenuAsyncAction? preferences;
  final MenuAsyncAction? about;
  final MenuAsyncAction? save;
  final MenuAsyncAction? undo;
  final MenuAsyncAction? redo;
  final MenuAsyncAction? zoomIn;
  final MenuAsyncAction? zoomOut;
}

class MenuActionDispatcher extends ChangeNotifier {
  MenuActionDispatcher._();

  static final MenuActionDispatcher instance = MenuActionDispatcher._();

  final LinkedHashMap<Object, MenuActionHandler> _handlers =
      LinkedHashMap<Object, MenuActionHandler>();

  MenuActionHandler get current => _handlers.isEmpty
      ? const MenuActionHandler.empty()
      : _handlers.values.last;

  void register(Object token, MenuActionHandler handler) {
    _handlers[token] = handler;
    notifyListeners();
  }

  void unregister(Object token) {
    final removed = _handlers.remove(token);
    if (removed != null) {
      notifyListeners();
    }
  }
}

class MenuActionBinding extends StatefulWidget {
  const MenuActionBinding({
    super.key,
    required this.handler,
    required this.child,
  });

  final MenuActionHandler handler;
  final Widget child;

  @override
  State<MenuActionBinding> createState() => _MenuActionBindingState();
}

class _MenuActionBindingState extends State<MenuActionBinding> {
  final Object _token = Object();

  @override
  void initState() {
    super.initState();
    MenuActionDispatcher.instance.register(_token, widget.handler);
  }

  @override
  void didUpdateWidget(MenuActionBinding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.handler, widget.handler)) {
      MenuActionDispatcher.instance.register(_token, widget.handler);
    }
  }

  @override
  void dispose() {
    MenuActionDispatcher.instance.unregister(_token);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
