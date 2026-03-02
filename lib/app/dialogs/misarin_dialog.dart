import 'package:fluent_ui/fluent_ui.dart';

import '../../mobile/responsive_dialog.dart';
import '../../mobile/mobile_utils.dart';

Future<T?> showMisarinDialog<T>({
  required BuildContext context,
  Widget? title,
  required Widget content,
  List<Widget> actions = const <Widget>[],
  double? contentWidth = 440,
  double maxWidth = 560,
  bool barrierDismissible = true,
}) {
  return showResponsiveDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => MisarinDialog(
      title: title,
      content: content,
      actions: actions,
      contentWidth: contentWidth,
      maxWidth: maxWidth,
    ),
  );
}

class MisarinDialog extends StatelessWidget {
  const MisarinDialog({
    super.key,
    this.title,
    required this.content,
    this.actions = const <Widget>[],
    this.contentWidth = 440,
    this.maxWidth = 560,
  });

  final Widget? title;
  final Widget content;
  final List<Widget> actions;
  final double? contentWidth;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (isMobileOrPhone(context)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
        child: Column(
          children: [
            if (title != null) ...[
              DefaultTextStyle(
                style: FluentTheme.of(context).typography.title ?? const TextStyle(),
                child: title!,
              ),
              const SizedBox(height: 16),
            ],
            // 内容区域占据绝大部分空间并可滚动
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: content,
              ),
            ),
            // 底部按钮区域固定在底部
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: actions,
              ),
            ],
          ],
        ),
      );
    }

    final Widget body = contentWidth == null
        ? content
        : SizedBox(width: contentWidth, child: content);
    return ContentDialog(
      title: title,
      constraints: BoxConstraints(maxWidth: maxWidth),
      content: body,
      actions: actions.isEmpty ? null : actions,
    );
  }
}
