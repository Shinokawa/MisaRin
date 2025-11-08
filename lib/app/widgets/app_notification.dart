import 'dart:async';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/widgets.dart';

class AppNotificationAnchor extends StatefulWidget {
  const AppNotificationAnchor({super.key, required this.child});

  final Widget child;

  @override
  State<AppNotificationAnchor> createState() => _AppNotificationAnchorState();
}

class _AppNotificationAnchorState extends State<AppNotificationAnchor> {
  final Object _token = Object();
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleUpdate();
  }

  @override
  void didUpdateWidget(covariant AppNotificationAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleUpdate();
  }

  void _scheduleUpdate() {
    if (_scheduled) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _scheduled = false;
      final RenderObject? renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) {
        return;
      }
      final Offset offset = renderObject.localToGlobal(Offset.zero);
      final Rect rect = offset & renderObject.size;
      _AppNotificationAnchorRegistry.instance.register(_token, rect);
    });
  }

  @override
  void dispose() {
    _AppNotificationAnchorRegistry.instance.unregister(_token);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleUpdate();
    return widget.child;
  }
}

class AppNotifications {
  const AppNotifications._();

  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required String message,
    InfoBarSeverity severity = InfoBarSeverity.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    final OverlayState? overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    _currentEntry?.remove();
    _currentEntry = null;

    final Rect? anchorRect = _AppNotificationAnchorRegistry.instance.rect;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AppNotificationOverlay(
        message: message,
        severity: severity,
        duration: duration,
        anchorRect: anchorRect,
        onClosed: () {
          if (_currentEntry == entry) {
            _currentEntry = null;
          }
          entry.remove();
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _AppNotificationAnchorRegistry {
  _AppNotificationAnchorRegistry._();

  static final _AppNotificationAnchorRegistry instance =
      _AppNotificationAnchorRegistry._();

  Object? _token;

  Rect? _anchorRect;

  Rect? get rect => _anchorRect;

  void register(Object token, Rect rect) {
    _token = token;
    _anchorRect = rect;
  }

  void unregister(Object token) {
    if (_token == token) {
      _token = null;
      _anchorRect = null;
    }
  }
}

class _AppNotificationOverlay extends StatefulWidget {
  const _AppNotificationOverlay({
    required this.message,
    required this.severity,
    required this.duration,
    required this.anchorRect,
    required this.onClosed,
  });

  final String message;
  final InfoBarSeverity severity;
  final Duration duration;
  final Rect? anchorRect;
  final VoidCallback onClosed;

  @override
  State<_AppNotificationOverlay> createState() =>
      _AppNotificationOverlayState();
}

class _AppNotificationOverlayState extends State<_AppNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.2),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ),
  );
  Timer? _timer;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_isClosing) {
      return;
    }
    _isClosing = true;
    _timer?.cancel();
    await _controller.reverse();
    if (mounted) {
      widget.onClosed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget card = FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: _AppNotificationCard(
          message: widget.message,
          severity: widget.severity,
          onClose: _dismiss,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final Size overlaySize = Size(constraints.maxWidth, constraints.maxHeight);
        final _NotificationPosition position =
            _NotificationPosition.fromAnchor(widget.anchorRect, overlaySize);
        return SizedBox.expand(
          child: Stack(children: [
            Positioned(
              left: position.left,
              bottom: position.bottom,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: card,
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _AppNotificationCard extends StatelessWidget {
  const _AppNotificationCard({
    required this.message,
    required this.severity,
    required this.onClose,
  });

  final String message;
  final InfoBarSeverity severity;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final _AppNotificationVisual visual =
        _AppNotificationVisual.resolve(theme, severity);

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: visual.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: visual.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(visual.icon, color: visual.iconColor, size: 14),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: (theme.typography.body ?? const TextStyle(fontSize: 13)).copyWith(
                color: visual.textColor,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onClose,
            icon: Icon(FluentIcons.clear, size: 12, color: visual.iconColor),
            style: const ButtonStyle(
              padding: WidgetStatePropertyAll(EdgeInsets.all(2)),
              backgroundColor: WidgetStatePropertyAll(Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppNotificationVisual {
  const _AppNotificationVisual({
    required this.background,
    required this.border,
    required this.textColor,
    required this.iconColor,
    required this.shadowColor,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color textColor;
  final Color iconColor;
  final Color shadowColor;
  final IconData icon;

  static _AppNotificationVisual resolve(
    FluentThemeData theme,
    InfoBarSeverity severity,
  ) {
    final bool isDark = theme.brightness.isDark;
    final Color fallbackColor = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    Color background = theme.cardColor;
    if (background.alpha != 0xFF) {
      background = fallbackColor;
    }
    final Color border = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);
    final Color textColor =
        theme.typography.body?.color ?? theme.resources.textFillColorPrimary;
    final Color iconColor = _iconColorFor(theme, severity);
    final Color shadowColor = theme.shadowColor.withOpacity(isDark ? 0.4 : 0.18);

    return _AppNotificationVisual(
      background: background,
      border: border,
      textColor: textColor,
      iconColor: iconColor,
      shadowColor: shadowColor,
      icon: _iconForSeverity(severity),
    );
  }

  static IconData _iconForSeverity(InfoBarSeverity severity) {
    switch (severity) {
      case InfoBarSeverity.success:
        return FluentIcons.check_mark;
      case InfoBarSeverity.warning:
        return FluentIcons.warning;
      case InfoBarSeverity.error:
        return FluentIcons.status_error_full;
      case InfoBarSeverity.info:
      default:
        return FluentIcons.info;
    }
  }

  static Color _iconColorFor(FluentThemeData theme, InfoBarSeverity severity) {
    final resources = theme.resources;
    switch (severity) {
      case InfoBarSeverity.success:
        return resources.systemFillColorSuccess;
      case InfoBarSeverity.warning:
        return resources.systemFillColorCaution;
      case InfoBarSeverity.error:
        return resources.systemFillColorCritical;
      case InfoBarSeverity.info:
      default:
        return theme.accentColor.defaultBrushFor(theme.brightness);
    }
  }
}

class _NotificationPosition {
  const _NotificationPosition({required this.left, required this.bottom});

  final double left;
  final double bottom;

  static const double _margin = 16;
  static const double _anchorSpacing = 12;
  static const double _verticalOffset = 8;
  static const double _maxWidth = 320;

  static _NotificationPosition fromAnchor(Rect? anchor, Size overlaySize) {
    double left = _margin;
    double bottom = _margin;
    if (anchor != null) {
      left = anchor.right + _anchorSpacing;
      bottom = overlaySize.height - anchor.bottom + _verticalOffset;
    }
    final double maxLeftBound = overlaySize.width.isFinite
        ? math.max(_margin, overlaySize.width - _maxWidth - _margin)
        : _margin;
    left = left.clamp(_margin, maxLeftBound);
    final double maxBottomBound = overlaySize.height.isFinite
        ? math.max(_margin, overlaySize.height - _margin)
        : _margin;
    bottom = bottom.clamp(_margin, maxBottomBound);
    return _NotificationPosition(left: left, bottom: bottom);
  }
}
