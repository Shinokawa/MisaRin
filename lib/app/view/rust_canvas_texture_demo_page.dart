import 'package:fluent_ui/fluent_ui.dart';

import '../widgets/rust_canvas_texture_widget.dart';

class RustCanvasTextureDemoPage extends StatelessWidget {
  const RustCanvasTextureDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      content: ScaffoldPage(
        padding: EdgeInsets.zero,
        content: Stack(
          children: [
            const Positioned.fill(child: RustCanvasTextureWidget()),
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

