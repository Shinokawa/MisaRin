import 'package:fluent_ui/fluent_ui.dart';

import '../widgets/backend_canvas_texture_widget.dart';

class BackendCanvasTextureDemoPage extends StatelessWidget {
  const BackendCanvasTextureDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      content: ScaffoldPage(
        padding: EdgeInsets.zero,
        content: Stack(
          children: [
            const Positioned.fill(child: BackendCanvasTextureWidget()),
            Positioned(
              top: 12,
              left: 12,
              child: Button(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('返回'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

