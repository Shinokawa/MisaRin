import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    SelectionShape.rectangle: 'icons/warp1.svg',
    SelectionShape.ellipse: 'icons/warp2.svg',
    SelectionShape.polygon: 'icons/warp3.svg',
  };

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _assetMap[shape]!,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
