import 'package:fluent_ui/fluent_ui.dart';

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
