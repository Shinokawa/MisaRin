import 'package:fluent_ui/fluent_ui.dart';

import '../../canvas/canvas_settings.dart';
import '../dialogs/canvas_settings_dialog.dart';
import 'canvas_page.dart';

class MisarinHomePage extends StatelessWidget {
  const MisarinHomePage({super.key});

  Future<void> _handleCreateCanvas(BuildContext context) async {
    final CanvasSettings? settings = await showCanvasSettingsDialog(context);
    if (settings == null || !context.mounted) {
      return;
    }
    await Navigator.of(
      context,
    ).push(FluentPageRoute(builder: (_) => CanvasPage(settings: settings)));
  }

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      content: ScaffoldPage(
        header: const PageHeader(title: Text('主页面')),
        content: Center(
          child: Card(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '欢迎使用 misa rin',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => _handleCreateCanvas(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Text('新建画布'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
