import 'package:fluent_ui/fluent_ui.dart';

class MobileStyle {
  // 基础尺寸
  static const double controlHeight = 52.0;
  static const double fontSize = 18.0;
  static const double labelFontSize = 15.0;
  static const double iconSize = 24.0;
  
  // 内边距
  static const EdgeInsets edgeInsets = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

  /// 获取适用于移动端的 Typography
  static Typography getTypography(Typography base) {
    return Typography.raw(
      display: base.display?.copyWith(fontSize: fontSize + 12),
      titleLarge: base.titleLarge?.copyWith(fontSize: fontSize + 8),
      title: base.title?.copyWith(fontSize: fontSize + 4),
      subtitle: base.subtitle?.copyWith(fontSize: fontSize + 2, fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: fontSize + 2),
      bodyStrong: base.bodyStrong?.copyWith(fontSize: fontSize, fontWeight: FontWeight.w600),
      body: base.body?.copyWith(fontSize: fontSize),
      caption: base.caption?.copyWith(fontSize: labelFontSize),
    );
  }

  /// 包装一个带有移动端特征的 TextBox
  static Widget wrapTextBox(Widget child) {
    return SizedBox(
      height: controlHeight,
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: fontSize),
        child: child,
      ),
    );
  }
}
