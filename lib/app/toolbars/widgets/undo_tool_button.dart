import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';

class UndoToolButton extends StatefulWidget {
  const UndoToolButton({
    super.key,
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<UndoToolButton> createState() => _UndoToolButtonState();
}

class _UndoToolButtonState extends State<UndoToolButton> {
  bool _hovered = false;
  int _lastStylusPressEpochMs = 0;

  bool _isNonMousePointer(PointerDeviceKind kind) {
    return kind != PointerDeviceKind.mouse &&
        kind != PointerDeviceKind.trackpad;
  }

  void _triggerPressed() {
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastStylusPressEpochMs < 180) {
      return;
    }
    _lastStylusPressEpochMs = now;
    widget.onPressed();
  }

  void _handleHover(bool hovered) {
    if (_hovered == hovered) {
      return;
    }
    setState(() => _hovered = hovered);
  }

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final bool isDark = theme.brightness.isDark;
    final bool enabled = widget.enabled;

    final Color enabledBorder = isDark
        ? const Color(0xFF4AA553)
        : const Color(0xFF0F7A0B);
    final Color disabledBorder = isDark
        ? const Color(0xFF2E3C30)
        : const Color(0xFFC6D7C6);
    final Color enabledBackground = isDark
        ? const Color(0xFF17331B)
        : const Color(0xFFEAF7EA);
    final Color hoverBackground = isDark
        ? const Color(0xFF1F3A22)
        : const Color(0xFFE2F3E2);
    final Color disabledBackground = isDark
        ? const Color(0xFF1F2721)
        : const Color(0xFFF2F7F2);
    final Color enabledIcon = isDark
        ? const Color(0xFF90F09D)
        : const Color(0xFF0B5A09);
    final Color hoverIcon = isDark
        ? const Color(0xFFB6F9C0)
        : const Color(0xFF094507);
    final Color disabledIcon = isDark
        ? const Color(0xFF5F7262)
        : const Color(0xFF8AA08A);

    final bool showHover = enabled && _hovered;
    final Color borderColor = enabled
        ? (showHover
              ? Color.lerp(enabledBorder, Colors.white, isDark ? 0.2 : 0.05)!
              : enabledBorder)
        : disabledBorder;
    final Color backgroundColor = enabled
        ? (showHover ? hoverBackground : enabledBackground)
        : disabledBackground;
    final Color iconColor = enabled
        ? (showHover ? hoverIcon : enabledIcon)
        : disabledIcon;

    final List<BoxShadow> shadows = <BoxShadow>[];
    if (enabled) {
      shadows.add(
        BoxShadow(
          color: Color.lerp(
            Colors.transparent,
            enabledBorder,
            isDark ? 0.4 : 0.2,
          )!.withOpacity(showHover ? 1 : 0.85),
          blurRadius: showHover ? 9 : 7,
          offset: const Offset(0, 3),
        ),
      );
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (enabled) {
          _handleHover(true);
        }
      },
      onExit: (_) {
        if (enabled) {
          _handleHover(false);
        }
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: enabled
            ? (event) {
                if (_isNonMousePointer(event.kind)) {
                  _triggerPressed();
                }
              }
            : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _triggerPressed : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: shadows,
            ),
            child: Icon(FluentIcons.undo, color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }
}
