import 'package:flutter/widgets.dart';

typedef LocaleChanged = void Function(Locale? locale);

class LocaleController extends InheritedWidget {
  const LocaleController({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
    required super.child,
  });

  /// When null, the app follows the platform locale.
  final Locale? locale;
  final LocaleChanged onLocaleChanged;

  static LocaleController of(BuildContext context) {
    final LocaleController? result =
        context.dependOnInheritedWidgetOfExactType<LocaleController>();
    assert(result != null, 'LocaleController not found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(LocaleController oldWidget) {
    return locale != oldWidget.locale;
  }
}

