import 'dart:ui';

class CanvasSettings {
  const CanvasSettings({
    required this.width,
    required this.height,
    required this.backgroundColor,
  });

  final double width;
  final double height;
  final Color backgroundColor;

  Size get size => Size(width, height);

  CanvasSettings copyWith({
    double? width,
    double? height,
    Color? backgroundColor,
  }) {
    return CanvasSettings(
      width: width ?? this.width,
      height: height ?? this.height,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  static const CanvasSettings defaults = CanvasSettings(
    width: 1920,
    height: 1080,
    backgroundColor: Color(0xFFFFFFFF),
  );
}
