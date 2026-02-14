import 'package:fluent_ui/fluent_ui.dart';

import '../project/project_document.dart';
import '../widgets/backend_canvas_texture_widget.dart';

class BackendCanvasPage extends StatelessWidget {
  const BackendCanvasPage({
    super.key,
    required this.document,
  });

  final ProjectDocument document;

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
            Positioned(
              top: 16,
              left: 92,
              child: Text(
                document.name,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

