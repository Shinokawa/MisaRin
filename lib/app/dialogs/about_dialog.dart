import 'package:fluent_ui/fluent_ui.dart';

import 'misarin_dialog.dart';

Future<void> showAboutMisarinDialog(BuildContext context) {
  final theme = FluentTheme.of(context);
  return showMisarinDialog<void>(
    context: context,
    title: const Text('关于 Misa Rin'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Misa Rin 是一款专注于创意绘制与项目管理的应用，'
          '旨在为创作者提供流畅的绘图体验与可靠的项目存档能力。',
          style: theme.typography.body,
        ),
        const SizedBox(height: 12),
        InfoLabel(
          label: '应用标识',
          child: SelectableText(
            'com.aimessoft.misarin',
            style: theme.typography.bodyStrong,
          ),
        ),
      ],
    ),
    contentWidth: 420,
    maxWidth: 520,
    actions: [
      Button(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('关闭'),
      ),
    ],
  );
}
