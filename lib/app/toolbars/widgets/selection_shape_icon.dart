import 'package:flutter/widgets.dart';

import '../../../canvas/canvas_tools.dart';

class SelectionShapeIcon extends StatelessWidget {
  const SelectionShapeIcon({
    super.key,
    required this.shape,
    required this.color,
    this.size = 24,
  });

  final SelectionShape shape;
  final Color color;
  final double size;

  static const Map<SelectionShape, String> _assetMap = {
    SelectionShape.rectangle: 'icons/warp1.png',
    SelectionShape.ellipse: 'icons/warp2.png',
    SelectionShape.polygon: 'icons/warp3.png',
  };

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _assetMap[shape]!,
      width: size,
      height: size,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.high,
    );
  }
}
