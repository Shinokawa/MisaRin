import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show Listenable, ValueNotifier;
import 'package:flutter/material.dart' show Material;
import 'package:flutter/widgets.dart'
    show
        Animation,
        AnimationController,
        CurvedAnimation,
        Navigator,
        Offset,
        Overlay,
        OverlayEntry,
        PageRouteBuilder,
        Tween,
        TickerProviderStateMixin;

/// 移动端统一上拉菜单配置常量
class MobileBottomSheetConstants {
  static const double topGap = 75.0;
  static const double maxHeightFactor = 0.7;
  static const double borderRadius = 24.0;
}

class MobileBottomSheetController {
  static final ValueNotifier<int> activeCount = ValueNotifier<int>(0);

  static bool get isActive => activeCount.value > 0;

  static void _push() {
    activeCount.value += 1;
  }

  static void _pop() {
    if (activeCount.value <= 0) {
      return;
    }
    activeCount.value -= 1;
  }
}

Future<T?> showMobileBottomSheet<T>({
  required BuildContext context,
  Widget? child,
  WidgetBuilder? builder,
  Listenable? rebuildListenable,
  bool barrierDismissible = true,
  double? heightFactor,
  bool trackActive = true,
}) {
  assert(
    (child != null) ^ (builder != null),
    'Provide either child or builder.',
  );
  final theme = FluentTheme.of(context);
  final screenHeight = MediaQuery.sizeOf(context).height;
  final double resolvedHeightFactor =
      (heightFactor ?? MobileBottomSheetConstants.maxHeightFactor)
          .clamp(0.2, 1.0)
          .toDouble();
  // 固定高度 = 屏幕高度 * 比例（默认 50%）
  final sheetHeight = screenHeight * resolvedHeightFactor;
  final WidgetBuilder resolvedBuilder = builder ?? (_) => child!;
  final Widget content = rebuildListenable == null
      ? Builder(builder: resolvedBuilder)
      : AnimatedBuilder(
          animation: rebuildListenable,
          builder: (context, _) => resolvedBuilder(context),
        );

  if (trackActive) {
    MobileBottomSheetController._push();
  }
  final Future<T?> future = showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withOpacity(0.4),
    transitionDuration: const Duration(milliseconds: 350),
    useRootNavigator: true,
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
  if (trackActive) {
    future.whenComplete(MobileBottomSheetController._pop);
  }
  return future;
}

Future<T?> showMobileBottomSheetOnRootOverlay<T>({
  required BuildContext context,
  Widget? child,
  WidgetBuilder? builder,
  Listenable? rebuildListenable,
  bool barrierDismissible = true,
  double? heightFactor,
  bool trackActive = true,
}) {
  assert(
    (child != null) ^ (builder != null),
    'Provide either child or builder.',
  );
  final OverlayState? overlay = Overlay.of(context, rootOverlay: true);
  if (overlay == null) {
    return Future<T?>.value(null);
  }

  final double resolvedHeightFactor =
      (heightFactor ?? MobileBottomSheetConstants.maxHeightFactor)
          .clamp(0.2, 1.0)
          .toDouble();
  final WidgetBuilder resolvedBuilder = builder ?? (_) => child!;
  final Completer<T?> completer = Completer<T?>();

  if (trackActive) {
    MobileBottomSheetController._push();
  }

  late OverlayEntry entry;
  void handleClosed(T? result) {
    if (entry.mounted) {
      entry.remove();
    }
    if (trackActive) {
      MobileBottomSheetController._pop();
    }
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  entry = OverlayEntry(
    builder: (overlayContext) {
      return _MobileBottomSheetOverlayHost<T>(
        builder: resolvedBuilder,
        rebuildListenable: rebuildListenable,
        barrierDismissible: barrierDismissible,
        heightFactor: resolvedHeightFactor,
        onClosed: handleClosed,
      );
    },
  );

  overlay.insert(entry);
  return completer.future;
}

class _MobileBottomSheetOverlayHost<T> extends StatefulWidget {
  const _MobileBottomSheetOverlayHost({
    required this.builder,
    required this.rebuildListenable,
    required this.barrierDismissible,
    required this.heightFactor,
    required this.onClosed,
  });

  final WidgetBuilder builder;
  final Listenable? rebuildListenable;
  final bool barrierDismissible;
  final double heightFactor;
  final void Function(T?) onClosed;

  @override
  State<_MobileBottomSheetOverlayHost<T>> createState() =>
      _MobileBottomSheetOverlayHostState<T>();
}

class _MobileBottomSheetOverlayHostState<T>
    extends State<_MobileBottomSheetOverlayHost<T>>
    with TickerProviderStateMixin {
  static const Duration _kTransitionDuration =
      Duration(milliseconds: 320);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _kTransitionDuration,
  );
  late final Animation<double> _fadeAnimation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slideAnimation = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    ),
  );

  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close([T? result]) {
    if (_closing) {
      return;
    }
    _closing = true;
    _controller.reverse().whenComplete(() {
      widget.onClosed(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double sheetHeight = screenHeight * widget.heightFactor;
    final Widget content = widget.rebuildListenable == null
        ? Builder(builder: widget.builder)
        : AnimatedBuilder(
            animation: widget.rebuildListenable!,
            builder: (context, _) => widget.builder(context),
          );

    Widget buildBarrier() {
      final Color color = Colors.black.withOpacity(0.4);
      if (widget.barrierDismissible) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _close(),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ColoredBox(color: color),
          ),
        );
      }
      return AbsorbPointer(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ColoredBox(color: color),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        buildBarrier(),
        SlideTransition(
          position: _slideAnimation,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                height: sheetHeight,
                decoration: BoxDecoration(
                  color: theme.micaBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(
                      MobileBottomSheetConstants.borderRadius,
                    ),
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
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.resources.controlStrokeColorDefault
                            .withOpacity(0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(
                            MobileBottomSheetConstants.borderRadius,
                          ),
                        ),
                        child: Navigator(
                          onPopPage: (route, result) {
                            if (!route.didPop(result)) {
                              return false;
                            }
                            _close(result as T?);
                            return true;
                          },
                          onGenerateRoute: (settings) => PageRouteBuilder<void>(
                            settings: settings,
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                            pageBuilder: (_, __, ___) => content,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
