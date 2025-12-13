import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/image_resize_sampling.dart';

class ImageResizeConfig {
  const ImageResizeConfig({
    required this.width,
    required this.height,
    required this.lockAspectRatio,
    required this.sampling,
  });

  final int width;
  final int height;
  final bool lockAspectRatio;
  final ImageResizeSampling sampling;
}

Future<ImageResizeConfig?> showImageSizeDialog(
  BuildContext context, {
  required int initialWidth,
  required int initialHeight,
}) {
  return showDialog<ImageResizeConfig>(
    context: context,
    builder: (context) => _ImageSizeDialog(
      initialWidth: initialWidth,
      initialHeight: initialHeight,
    ),
  );
}

class _ImageSizeDialog extends StatefulWidget {
  const _ImageSizeDialog({
    required this.initialWidth,
    required this.initialHeight,
  });

  final int initialWidth;
  final int initialHeight;

  @override
  State<_ImageSizeDialog> createState() => _ImageSizeDialogState();
}

class _ImageSizeDialogState extends State<_ImageSizeDialog> {
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  late double _aspectRatio;
  bool _lockAspectRatio = true;
  String? _errorMessage;
  bool _isSyncingControllers = false;
  ImageResizeSampling _sampling = ImageResizeSampling.nearest;

  @override
  void initState() {
    super.initState();
    _widthController = TextEditingController(
      text: widget.initialWidth.toString(),
    )..addListener(_handleWidthChanged);
    _heightController = TextEditingController(
      text: widget.initialHeight.toString(),
    )..addListener(_handleHeightChanged);
    _aspectRatio = widget.initialWidth / widget.initialHeight;
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _handleWidthSubmitted(String value) {
    _updateLinkedDimension(fromWidth: true);
  }

  void _handleHeightSubmitted(String value) {
    _updateLinkedDimension(fromWidth: false);
  }

  void _handleWidthChanged() {
    if (_isSyncingControllers) {
      return;
    }
    _handleUserDimensionChanged();
    _updateLinkedDimension(fromWidth: true);
  }

  void _handleHeightChanged() {
    if (_isSyncingControllers) {
      return;
    }
    _handleUserDimensionChanged();
    _updateLinkedDimension(fromWidth: false);
  }

  void _handleUserDimensionChanged() {
    setState(() {
      _errorMessage = null;
    });
  }

  void _updateLinkedDimension({required bool fromWidth}) {
    if (!_lockAspectRatio) {
      return;
    }
    final String sourceText =
        fromWidth ? _widthController.text : _heightController.text;
    final int? sourceValue = int.tryParse(sourceText);
    if (sourceValue == null || sourceValue <= 0) {
      return;
    }
    if (fromWidth) {
      final int height = (sourceValue / _aspectRatio).round();
      _updateHeight(height);
    } else {
      final int width = (sourceValue * _aspectRatio).round();
      _updateWidth(width);
    }
  }

  void _updateWidth(int value) {
    final String text = value.clamp(1, 100000).toString();
    if (_widthController.text == text) {
      return;
    }
    _isSyncingControllers = true;
    _widthController.text = text;
    _isSyncingControllers = false;
    setState(() {});
  }

  void _updateHeight(int value) {
    final String text = value.clamp(1, 100000).toString();
    if (_heightController.text == text) {
      return;
    }
    _isSyncingControllers = true;
    _heightController.text = text;
    _isSyncingControllers = false;
    setState(() {});
  }

  void _toggleAspectLock(bool value) {
    setState(() {
      _lockAspectRatio = value;
      if (_lockAspectRatio) {
        _handleWidthSubmitted(_widthController.text);
      }
    });
  }

  void _submit() {
    final int? width = int.tryParse(_widthController.text);
    final int? height = int.tryParse(_heightController.text);
    if (width == null || height == null || width <= 0 || height <= 0) {
      setState(() => _errorMessage = context.l10n.invalidDimensions);
      return;
    }
    Navigator.of(context).pop(
      ImageResizeConfig(
        width: width,
        height: height,
        lockAspectRatio: _lockAspectRatio,
        sampling: _sampling,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final l10n = context.l10n;
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 380),
      title: Text(l10n.imageSizeTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoLabel(
            label: l10n.widthPx,
            child: TextBox(
              controller: _widthController,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              keyboardType: TextInputType.number,
              onSubmitted: _handleWidthSubmitted,
            ),
          ),
          const SizedBox(height: 12),
          InfoLabel(
            label: l10n.heightPx,
            child: TextBox(
              controller: _heightController,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              keyboardType: TextInputType.number,
              onSubmitted: _handleHeightSubmitted,
            ),
          ),
          const SizedBox(height: 12),
          ToggleSwitch(
            checked: _lockAspectRatio,
            content: Text(l10n.lockAspectRatio),
            onChanged: _toggleAspectLock,
          ),
          const SizedBox(height: 12),
          InfoLabel(
            label: l10n.samplingMethod,
            child: ComboBox<ImageResizeSampling>(
              value: _sampling,
              items: [
                for (final ImageResizeSampling option
                    in ImageResizeSampling.values)
                  ComboBoxItem<ImageResizeSampling>(
                    value: option,
                    child: Text(option.label(l10n)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _sampling = value);
                }
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _sampling.description(l10n),
            style: theme.typography.caption,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.currentSize(_widthController.text, _heightController.text),
            style: theme.typography.caption,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: theme.typography.caption?.copyWith(color: Colors.red),
            ),
          ],
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.confirm)),
      ],
    );
  }
}
