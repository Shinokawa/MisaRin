/// 代表整数坐标空间中的矩形，用于像素级渲染区块。
class RasterIntRect {
  const RasterIntRect(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  bool get isEmpty => left >= right || top >= bottom;
}
