import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_performance_pulse/flutter_performance_pulse.dart';

class PerformancePulseOverlay extends StatelessWidget {
  const PerformancePulseOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final bool alignRight = defaultTargetPlatform == TargetPlatform.macOS;
    final double? right = alignRight ? 16 : null;
    final double? left = alignRight ? null : 16;
    final FluentThemeData fluentTheme = FluentTheme.of(context);

    final bool isDarkMode = fluentTheme.brightness == Brightness.dark;
    final Color defaultTextColor =
        fluentTheme.typography.body?.color ?? Colors.black;
    final Color backgroundColor = isDarkMode
        ? const Color(0xFF1F1F1F).withOpacity(0.92)
        : Colors.white.withOpacity(0.95);
    final DashboardTheme dashboardTheme = DashboardTheme(
      backgroundColor: backgroundColor,
      textColor: isDarkMode ? Colors.white : defaultTextColor,
      warningColor: Colors.orange,
      errorColor: Colors.red,
      chartLineColor: fluentTheme.accentColor.light,
      chartFillColor: fluentTheme.accentColor.light.withOpacity(0.2),
    );

    return Positioned(
      top: 16,
      right: right,
      left: left,
      child: IgnorePointer(
        ignoring: true,
        child: material.Theme(
          data: material.ThemeData(
            useMaterial3: true,
            colorScheme: material.ColorScheme.fromSeed(
              seedColor: fluentTheme.accentColor.normal,
              brightness: isDarkMode ? Brightness.dark : Brightness.light,
            ),
          ),
          child: material.Material(
            elevation: 10,
            borderRadius:
                const material.BorderRadius.all(material.Radius.circular(12)),
            child: PerformanceDashboard(
              showFPS: true,
              showCPU: true,
              showDisk: true,
              theme: dashboardTheme,
            ),
          ),
        ),
      ),
    );
  }
}
