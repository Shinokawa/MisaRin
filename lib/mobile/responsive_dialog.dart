import 'package:fluent_ui/fluent_ui.dart';

import 'mobile_bottom_sheet.dart';
import 'mobile_utils.dart';

Future<T?> showResponsiveDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  if (isMobileOrPhone(context)) {
    return showMobileBottomSheet<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      child: builder(context),
    );
  }

  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: builder,
  );
}
