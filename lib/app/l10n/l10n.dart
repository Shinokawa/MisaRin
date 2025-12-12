import 'package:flutter/widgets.dart';
import 'package:misa_rin/l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
