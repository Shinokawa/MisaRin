import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import '../../canvas/canvas_settings.dart';
import '../constants/antialias_levels.dart';
import 'misarin_dialog.dart';

class CanvasExportOptions {
  const CanvasExportOptions({required this.width, required this.height});

  final int width;
  final int height;
}

Future<CanvasExportOptions?> showCanvasExportDialog({
  required BuildContext context,
  required CanvasSettings settings,
  Future<bool> Function(int level)? onApplyAntialias,
}) async {
  final TextEditingController scaleController = TextEditingController(
    text: '1.0',
  );
  double scale = 1.0;
  String? scaleError;
  StateSetter? dialogSetState;
  int antialiasLevel = 2;
  bool antialiasApplying = false;
  String? antialiasStatus;
  bool antialiasFailed = false;
  CanvasExportOptions? result;

  await showMisarinDialog<CanvasExportOptions>(
    context: context,
    title: const Text('导出 PNG 设置'),
    contentWidth: 420,
    content: StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        dialogSetState = setState;
        final FluentThemeData theme = FluentTheme.of(context);
        final double outputWidth = settings.width * scale;
        final double outputHeight = settings.height * scale;
        final List<double> presets = <double>[0.25, 0.5, 1.0, 2.0, 4.0];

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('导出倍率'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormBox(
                    controller: scaleController,
                    placeholder: '如：1.0',
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (String value) {
                      final double? parsed = double.tryParse(value);
                      setState(() {
                        if (parsed == null || parsed <= 0) {
                          scaleError = '请输入大于 0 的数值';
                        } else {
                          scaleError = null;
                          scale = parsed;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Button(
                  onPressed: () {
                    setState(() {
                      scale = 1.0;
                      scaleController.text = '1.0';
                      scaleError = null;
                    });
                  },
                  child: const Text('重置'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final double value in presets)
                  Button(
                    onPressed: () {
                      setState(() {
                        scale = value;
                        scaleController.text = value.toString();
                        scaleError = null;
                      });
                    },
                    child: Text('${value}x'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('输出尺寸：${outputWidth.round()} × ${outputHeight.round()} 像素'),
            if (scaleError != null) ...[
              const SizedBox(height: 8),
              Text(
                scaleError!,
                style: const TextStyle(color: Color(0xFFD13438)),
              ),
            ],
            if (onApplyAntialias != null) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Text('导出前的抗锯齿处理', style: theme.typography.bodyStrong),
              const SizedBox(height: 8),
              Slider(
                min: 0,
                max: 3,
                divisions: 3,
                value: antialiasLevel.toDouble(),
                label: '等级 $antialiasLevel',
                onChanged: (value) {
                  dialogSetState?.call(() {
                    antialiasLevel = value.round();
                    antialiasStatus = null;
                    antialiasFailed = false;
                  });
                },
              ),
              const SizedBox(height: 4),
              Text(
                kAntialiasLevelDescriptions[antialiasLevel],
                style: theme.typography.caption,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Button(
                    onPressed: antialiasApplying
                        ? null
                        : () async {
                            dialogSetState?.call(() {
                              antialiasApplying = true;
                              antialiasStatus = null;
                              antialiasFailed = false;
                            });
                            bool success = false;
                            try {
                              success = await onApplyAntialias(antialiasLevel);
                            } finally {
                              dialogSetState?.call(() {
                                antialiasApplying = false;
                                antialiasFailed = !success;
                                antialiasStatus = success
                                    ? '已对当前图层应用等级 $antialiasLevel 抗锯齿。'
                                    : '无法应用抗锯齿，请确保图层未锁定且包含像素。';
                              });
                            }
                          },
                    child: antialiasApplying
                        ? const ProgressRing()
                        : const Text('应用到当前图层'),
                  ),
                ],
              ),
              if (antialiasStatus != null) ...[
                const SizedBox(height: 6),
                Text(
                  antialiasStatus!,
                  style: TextStyle(
                    color: antialiasFailed
                        ? const Color(0xFFD13438)
                        : const Color(0xFF107C10),
                  ),
                ),
              ],
            ],
          ],
        );
      },
    ),
    actions: [
      Button(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          final double? parsed = double.tryParse(scaleController.text);
          if (parsed == null || parsed <= 0) {
            dialogSetState?.call(() {
              scaleError = '请输入大于 0 的数值';
            });
            return;
          }
          scale = parsed;
          final CanvasExportOptions options = CanvasExportOptions(
            width: (settings.width * scale).round().clamp(1, 100000),
            height: (settings.height * scale).round().clamp(1, 100000),
          );
          Navigator.of(context).pop(options);
        },
        child: const Text('导出'),
      ),
    ],
  ).then((CanvasExportOptions? value) {
    result = value;
  });

  scaleController.dispose();
  return result;
}
