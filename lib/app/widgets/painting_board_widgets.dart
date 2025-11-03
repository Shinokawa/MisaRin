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
    this.expand = false,
    this.trailing,
  });

  final double width;
  final String title;
  final Widget child;
  final bool expand;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final BorderRadius borderRadius = BorderRadius.circular(20);
    final Color fallbackColor = theme.brightness.isDark
        ? const Color(0xFF1F1F1F)
        : Colors.white;
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
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(title, style: theme.typography.subtitle),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                ],
              ),
              const SizedBox(height: 14),
              if (expand) Expanded(child: child) else child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolSettingsCard extends StatelessWidget {
  const _ToolSettingsCard({
    required this.activeTool,
    required this.penStrokeWidth,
    required this.onPenStrokeWidthChanged,
  });

  final CanvasTool activeTool;
  final double penStrokeWidth;
  final ValueChanged<double> onPenStrokeWidthChanged;

  static const double _minPenStrokeWidth = 1;
  static const double _maxPenStrokeWidth = 60;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final BorderRadius borderRadius = BorderRadius.circular(16);
    final Color fallbackColor = theme.brightness.isDark
        ? const Color(0xFF1F1F1F)
        : Colors.white;
    Color backgroundColor = theme.cardColor;
    if (backgroundColor.alpha != 0xFF) {
      backgroundColor = fallbackColor;
    }

    Widget settingsContent;
    if (activeTool == CanvasTool.pen) {
      final String strokeLabel = '${penStrokeWidth.toStringAsFixed(0)} px';
      settingsContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('笔刷大小', style: theme.typography.bodyStrong),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Slider(
                  value: penStrokeWidth.clamp(
                    _minPenStrokeWidth,
                    _maxPenStrokeWidth,
                  ),
                  min: _minPenStrokeWidth,
                  max: _maxPenStrokeWidth,
                  divisions:
                      (_maxPenStrokeWidth - _minPenStrokeWidth).round(),
                  onChanged: onPenStrokeWidthChanged,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 52,
                child: Text(
                  strokeLabel,
                  style: theme.typography.caption,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      settingsContent = Text(
        '该工具暂无可调节参数',
        style: theme.typography.body,
      );
    }

    return SizedBox(
      width: _toolSettingsCardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('工具设置', style: theme.typography.subtitle),
              const SizedBox(height: 12),
              settingsContent,
            ],
          ),
        ),
      ),
    );
  }
}
