import 'package:fluent_ui/fluent_ui.dart';

import '../theme/theme_controller.dart';
import 'misarin_dialog.dart';

Future<void> showSettingsDialog(BuildContext context) {
  return showMisarinDialog<void>(
    context: context,
    title: const Text('设置'),
    content: const _SettingsDialogContent(),
    contentWidth: 420,
    maxWidth: 520,
    actions: [
      Button(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('好的'),
      ),
    ],
  );
}

class _SettingsDialogContent extends StatelessWidget {
  const _SettingsDialogContent();

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final controller = ThemeController.of(context);
    final ThemeMode themeMode = controller.themeMode;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoLabel(
          label: '主题模式',
          child: ComboBox<ThemeMode>(
            isExpanded: true,
            value: themeMode,
            items: const [
              ComboBoxItem(
                value: ThemeMode.light,
                child: Text('浅色'),
              ),
              ComboBoxItem(
                value: ThemeMode.dark,
                child: Text('深色'),
              ),
              ComboBoxItem(
                value: ThemeMode.system,
                child: Text('跟随系统'),
              ),
            ],
            onChanged: (mode) {
              if (mode == null) {
                return;
              }
              controller.onThemeModeChanged(mode);
            },
          ),
        ),
        const SizedBox(height: 16),
        Text('设置模块正在规划中，敬请期待。', style: theme.typography.bodyLarge),
        const SizedBox(height: 12),
        Text('我们会在后续版本提供更多个性化选项。', style: theme.typography.body),
      ],
    );
  }
}
