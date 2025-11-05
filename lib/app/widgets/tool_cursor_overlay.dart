import 'dart:ui' show Offset;

import 'package:fluent_ui/fluent_ui.dart';

import '../../canvas/canvas_tools.dart';

class ToolCursorStyle {
  const ToolCursorStyle({
    required this.anchor,
    required this.overlay,
    this.hideSystemCursor = true,
  });

  final Offset anchor;
  final Widget overlay;
  final bool hideSystemCursor;
}

class ToolCursorStyles {
  static ToolCursorStyle? styleFor(CanvasTool tool) => _styles[tool];

  static bool hasOverlay(CanvasTool tool) => _styles.containsKey(tool);

  static const double _defaultIconSize = 20;
  static const List<Offset> _defaultOutlineOffsets = <Offset>[
    Offset(-0.75, 0),
    Offset(0.75, 0),
    Offset(0, -0.75),
    Offset(0, 0.75),
    Offset(-0.75, -0.75),
    Offset(0.75, -0.75),
    Offset(-0.75, 0.75),
    Offset(0.75, 0.75),
  ];

  static final Map<CanvasTool, ToolCursorStyle> _styles =
      <CanvasTool, ToolCursorStyle>{
    CanvasTool.eyedropper: ToolCursorStyle(
      anchor: const Offset(5, 17),
      overlay: const _OutlinedToolCursorIcon(
        size: _defaultIconSize,
        icon: FluentIcons.eyedropper,
      ),
    ),
    CanvasTool.bucket: ToolCursorStyle(
      anchor: const Offset(8, 18),
      overlay: const _OutlinedToolCursorIcon(
        size: _defaultIconSize,
        icon: FluentIcons.bucket_color,
        mirrorHorizontally: true,
      ),
    ),
    CanvasTool.magicWand: ToolCursorStyle(
      anchor: Offset.zero,
      overlay: const _OutlinedToolCursorIcon(
        size: _defaultIconSize,
        icon: FluentIcons.auto_enhance_on,
        mirrorHorizontally: true,
      ),
    ),
  };

  static Widget _buildIcon({
    required IconData icon,
    required double size,
    required Color color,
    bool mirrorHorizontally = false,
  }) {
    Widget child = Icon(icon, size: size, color: color);
    if (mirrorHorizontally) {
      child = Transform.scale(
        scaleX: -1,
        scaleY: 1,
        alignment: Alignment.center,
        child: child,
      );
    }
    return child;
  }

  static Widget buildOutlinedIcon({
    required IconData icon,
    required double size,
    bool mirrorHorizontally = false,
    Color outlineColor = Colors.white,
    Color fillColor = Colors.black,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final Offset offset in _defaultOutlineOffsets)
            Transform.translate(
              offset: offset,
              child: _buildIcon(
                icon: icon,
                size: size,
                color: outlineColor,
                mirrorHorizontally: mirrorHorizontally,
              ),
            ),
          _buildIcon(
            icon: icon,
            size: size,
            color: fillColor,
            mirrorHorizontally: mirrorHorizontally,
          ),
        ],
      ),
    );
  }
}

class _OutlinedToolCursorIcon extends StatelessWidget {
  const _OutlinedToolCursorIcon({
    required this.icon,
    this.size = ToolCursorStyles._defaultIconSize,
    this.mirrorHorizontally = false,
  });

  final IconData icon;
  final double size;
  final bool mirrorHorizontally;

  @override
  Widget build(BuildContext context) {
    return ToolCursorStyles.buildOutlinedIcon(
      icon: icon,
      size: size,
      mirrorHorizontally: mirrorHorizontally,
    );
  }
}
