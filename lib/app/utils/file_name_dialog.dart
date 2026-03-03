import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:misa_rin/mobile/mobile_bottom_sheet.dart';
import 'package:misa_rin/mobile/mobile_utils.dart';

import '../l10n/l10n.dart';

Future<String?> showFileNameDialog({
  required BuildContext context,
  required String title,
  required String suggestedFileName,
  String? description,
  String? confirmLabel,
}) async {
  final l10n = context.l10n;
  final TextEditingController controller =
      TextEditingController(text: suggestedFileName);
  String? error;
  Future<String?> showDesktopDialog() {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final FluentThemeData theme = FluentTheme.of(context);
        return ContentDialog(
          title: Text(title),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (description != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(description!),
                    ),
                  TextBox(
                    controller: controller,
                    autofocus: true,
                    onChanged: (value) {
                      setState(() {
                        error = value.trim().isEmpty
                            ? l10n.fileNameCannotBeEmpty
                            : null;
                      });
                    },
                    onSubmitted: (_) {
                      final String trimmed = controller.text.trim();
                      if (trimmed.isNotEmpty) {
                        Navigator.of(context).pop(trimmed);
                      }
                    },
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: theme.typography.caption?.copyWith(
                          color: Colors.red,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          actions: [
            Button(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final String trimmed = controller.text.trim();
                if (trimmed.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(trimmed);
              },
              child: Text(confirmLabel ?? l10n.save),
            ),
          ],
        );
      },
    );
  }

  Future<String?> showMobileSheet() {
    return showMobileBottomSheet<String>(
      context: context,
      heightFactor: 0.7,
      builder: (BuildContext context) {
        final FluentThemeData theme = FluentTheme.of(context);
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.typography.subtitle?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 6),
                    Text(description!, style: theme.typography.caption),
                  ],
                  const SizedBox(height: 12),
                  TextBox(
                    controller: controller,
                    autofocus: true,
                    onChanged: (value) {
                      setState(() {
                        error = value.trim().isEmpty
                            ? l10n.fileNameCannotBeEmpty
                            : null;
                      });
                    },
                    onSubmitted: (_) {
                      final String trimmed = controller.text.trim();
                      if (trimmed.isNotEmpty) {
                        Navigator.of(context).pop(trimmed);
                      }
                    },
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: theme.typography.caption?.copyWith(
                        color: Colors.red,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Button(
                          onPressed: () => Navigator.of(context).pop(null),
                          child: Text(l10n.cancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            final String trimmed = controller.text.trim();
                            if (trimmed.isEmpty) {
                              setState(() {
                                error = l10n.fileNameCannotBeEmpty;
                              });
                              return;
                            }
                            Navigator.of(context).pop(trimmed);
                          },
                          child: Text(confirmLabel ?? l10n.save),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  final String? result =
      isMobileOrPhone(context) ? await showMobileSheet() : await showDesktopDialog();
  controller.dispose();
  final String value = result?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }
  return value;
}
