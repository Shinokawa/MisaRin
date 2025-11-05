import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';

class ProjectPreviewThumbnail extends StatelessWidget {
  const ProjectPreviewThumbnail({
    super.key,
    this.bytes,
    this.width = 96,
    this.height = 72,
    this.placeholderIcon = FluentIcons.picture,
  });

  final Uint8List? bytes;
  final double width;
  final double height;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final Widget placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.resources.subtleFillColorTertiary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.resources.controlStrongStrokeColorDefault,
          width: 0.6,
        ),
      ),
      child: Icon(placeholderIcon, size: 20),
    );

    final Uint8List? data = bytes;
    if (data == null || data.isEmpty) {
      return placeholder;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.memory(
        data,
        width: width,
        height: height,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }
}
