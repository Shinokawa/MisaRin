import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports the layout size of [child] through [onChanged].
class MeasuredSize extends SingleChildRenderObjectWidget {
  const MeasuredSize({
    super.key,
    required this.onChanged,
    required super.child,
  });

  final ValueChanged<Size> onChanged;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _MeasuredSizeRender(onChanged);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MeasuredSizeRender renderObject,
  ) {
    renderObject.onChanged = onChanged;
  }
}

class _MeasuredSizeRender extends RenderProxyBox {
  _MeasuredSizeRender(this.onChanged);

  ValueChanged<Size> onChanged;
  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    final Size size = child?.size ?? Size.zero;
    if (_lastSize == size) {
      return;
    }
    _lastSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(size));
  }
}
