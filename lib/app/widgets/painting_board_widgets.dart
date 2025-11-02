part of 'painting_board.dart';

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class SelectToolIntent extends Intent {
  const SelectToolIntent(this.tool);

  final CanvasTool tool;
}

class ExitBoardIntent extends Intent {
  const ExitBoardIntent();
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.width,
    required this.title,
    required this.child,
  });

  final double width;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final BorderRadius borderRadius = BorderRadius.circular(20);
    final Color fallbackColor =
        theme.brightness.isDark ? const Color(0xFF1F1F1F) : Colors.white;
    Color backgroundColor = theme.cardColor;
    if (backgroundColor.alpha != 0xFF) {
      backgroundColor = fallbackColor;
    }
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.typography.subtitle,
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
