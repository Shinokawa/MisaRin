import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart'
    show AnimatedSwitcher, ValueListenableBuilder;

/// 鼠标悬停超过指定时间后，在默认 Tooltip 下方追加功能说明。
class HoverDetailTooltip extends StatefulWidget {
  const HoverDetailTooltip({
    super.key,
    required this.message,
    required this.child,
    this.detail,
    this.detailDelay = const Duration(seconds: 3),
    this.style,
    this.displayHorizontally = false,
    this.useMousePosition = true,
  });

  /// Tooltip 第一行的文字，会立即显示。
  final String message;

  /// 延迟展示的详细说明。
  final String? detail;

  /// 详细说明出现前的等待时长。
  final Duration detailDelay;

  final Widget child;
  final TooltipThemeData? style;
  final bool displayHorizontally;
  final bool useMousePosition;

  @override
  State<HoverDetailTooltip> createState() => _HoverDetailTooltipState();
}

class _HoverDetailTooltipState extends State<HoverDetailTooltip> {
  Timer? _detailTimer;
  final ValueNotifier<bool> _showDetailNotifier = ValueNotifier<bool>(false);

  bool get _hasDetail =>
      widget.detail != null && widget.detail!.trim().isNotEmpty;

  @override
  void didUpdateWidget(covariant HoverDetailTooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasDetail) {
      _cancelTimer();
      _showDetailNotifier.value = false;
    }
  }

  @override
  void dispose() {
    _cancelTimer();
    _showDetailNotifier.dispose();
    super.dispose();
  }

  void _cancelTimer() {
    _detailTimer?.cancel();
    _detailTimer = null;
  }

  void _handleEnter(PointerEnterEvent event) {
    if (!_hasDetail) {
      return;
    }
    _detailTimer?.cancel();
    _detailTimer = Timer(widget.detailDelay, () {
      if (mounted) {
        _showDetailNotifier.value = true;
      }
    });
  }

  void _handleExit(PointerExitEvent event) {
    _cancelTimer();
    _showDetailNotifier.value = false;
  }

  InlineSpan _buildRichMessage(BuildContext context) {
    final fluentTheme = FluentTheme.of(context);
    final tooltipTheme = TooltipTheme.of(context).merge(widget.style);
    final TextStyle baseStyle =
        tooltipTheme.textStyle ??
        fluentTheme.typography.caption ??
        const TextStyle(fontSize: 12);

    if (!_hasDetail) {
      return TextSpan(text: widget.message);
    }

    final double baseFontSize = baseStyle.fontSize ?? 12;
    final Color detailColor =
        (baseStyle.color ??
                (fluentTheme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black))
            .withOpacity(0.85);

    final TextStyle detailStyle = baseStyle.copyWith(
      fontSize: (baseFontSize - 1).clamp(9.0, 20.0),
      height: 1.3,
      color: detailColor,
    );

    return TextSpan(
      text: '',
      semanticsLabel: widget.message,
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _TooltipRichContent(
            message: widget.message,
            messageStyle: baseStyle,
            detail: widget.detail!,
            detailStyle: detailStyle,
            showDetailListenable: _showDetailNotifier,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      richMessage: _buildRichMessage(context),
      style: widget.style,
      displayHorizontally: widget.displayHorizontally,
      useMousePosition: widget.useMousePosition,
      child: MouseRegion(
        onEnter: _handleEnter,
        onExit: _handleExit,
        child: widget.child,
      ),
    );
  }
}

class _TooltipRichContent extends StatelessWidget {
  const _TooltipRichContent({
    required this.message,
    required this.messageStyle,
    required this.detail,
    required this.detailStyle,
    required this.showDetailListenable,
  });

  final String message;
  final TextStyle messageStyle;
  final String detail;
  final TextStyle detailStyle;
  final ValueListenable<bool> showDetailListenable;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: messageStyle, softWrap: true),
        ValueListenableBuilder<bool>(
          valueListenable: showDetailListenable,
          builder: (context, show, _) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 140),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: show
                  ? Padding(
                      key: const ValueKey('tooltip-detail'),
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(detail, style: detailStyle, softWrap: true),
                    )
                  : const SizedBox.shrink(
                      key: ValueKey('tooltip-detail-hidden'),
                    ),
            );
          },
        ),
      ],
    );
  }
}
