import 'dart:ui';

enum CanvasCreationLogic { singleThread, multiThread }

class CanvasSettings {
  const CanvasSettings({
    required this.width,
    required this.height,
    required this.backgroundColor,
    this.creationLogic = CanvasCreationLogic.singleThread,
  });

  final double width;
  final double height;
  final Color backgroundColor;
  final CanvasCreationLogic creationLogic;

  Size get size => Size(width, height);

  CanvasSettings copyWith({
    double? width,
    double? height,
    Color? backgroundColor,
    CanvasCreationLogic? creationLogic,
  }) {
    return CanvasSettings(
      width: width ?? this.width,
      height: height ?? this.height,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      creationLogic: creationLogic ?? this.creationLogic,
    );
  }

  static const CanvasSettings defaults = CanvasSettings(
    width: 1920,
    height: 1080,
    backgroundColor: Color(0xFFFFFFFF),
    creationLogic: CanvasCreationLogic.singleThread,
  );
}
