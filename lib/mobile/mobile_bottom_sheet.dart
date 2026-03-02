import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show Listenable;
import 'package:flutter/material.dart' show Material;

/// 移动端统一上拉菜单配置常量
class MobileBottomSheetConstants {
  static const double topGap = 75.0;
  static const double borderRadius = 24.0;
}

Future<T?> showMobileBottomSheet<T>({
  required BuildContext context,
  Widget? child,
  WidgetBuilder? builder,
  Listenable? rebuildListenable,
  bool barrierDismissible = true,
}) {
  assert(
    (child != null) ^ (builder != null),
    'Provide either child or builder.',
  );
  final theme = FluentTheme.of(context);
  final screenHeight = MediaQuery.sizeOf(context).height;
  // 固定高度 = 屏幕高度 - 顶部留白
  final sheetHeight = screenHeight - MobileBottomSheetConstants.topGap;
  final WidgetBuilder resolvedBuilder = builder ?? (_) => child!;
  final Widget content = rebuildListenable == null
      ? Builder(builder: resolvedBuilder)
      : AnimatedBuilder(
          animation: rebuildListenable,
          builder: (context, _) => resolvedBuilder(context),
        );

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withOpacity(0.4),
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            height: sheetHeight,
            decoration: BoxDecoration(
              color: theme.micaBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(MobileBottomSheetConstants.borderRadius),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // 顶部低调的指示条
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.resources.controlStrokeColorDefault.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                // 内容区域：自动填充剩余空间并允许内部滚动
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(MobileBottomSheetConstants.borderRadius),
                    ),
                    child: content,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      // 使用更平滑的滑入动画
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuart,
        )),
        child: child,
      );
    },
  );
}
