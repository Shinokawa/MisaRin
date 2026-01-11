# 🦀 Rust 性能优化迁移清单 (Performance Roadmap)

该清单记录了项目中可以从 Dart 迁移到 Rust 的高计算量模块。通过迁移这些模块，可以大幅提升处理大画布、多图层以及复杂笔刷时的实时响应速度。

---

## 🚀 核心渲染引擎迁移 (性能起飞点)

### 1. 图层合成引擎 (Layer Compositing)
- **优先级**: 🔴 极高 (核心瓶颈)
- **位置**: `lib/backend/canvas_composite_worker.dart`, `lib/canvas/blend_mode_math.dart`
- **现状**: 在 Dart Isolate 中手动循环像素进行 Blend Mode 计算。
- **优化点**: 
  - 利用 Rust 的 **SIMD** (单指令多数据) 加速像素数学运算。
  - 使用 **Rayon** 进行多线程并行合成（图片切块处理）。
- **预期收益**: 提升 10-50 倍合成速度，消除多图层卡顿。

### 2. 笔刷软光栅化器 (Brush Rasterizer)
- **优先级**: 🔴 高
- **位置**: `lib/bitmap_canvas/bitmap_canvas.dart` -> `_drawPolygonStamp`, `_drawCapsuleSegment`
- **现状**: 在 Dart 中手动计算每个像素的几何覆盖率（Coverage）并进行 6x 超采样抗锯齿。
- **优化点**: 
  - 将复杂的几何数学运算（SDF、多边形裁剪）移至 Rust。
  - 减少 Dart 侧大数组的频繁遍历。
- **预期收益**: 大尺寸、高精度笔刷挥就时更加丝滑，无延迟。

### 3. 高质量图像变换 (Image Transforms)
- **优先级**: 🔴 高
- **位置**: `lib/app/widgets/painting_board_base.dart` -> `_rotateBitmapRgba`, `_scaleBitmapBilinear`
- **现状**: Dart 手写双线性插值旋转和缩放，大图层变换时有明显延迟。
- **优化点**: 
  - 使用 Rust 实现 Lanczos3 或 Bicubic 高质量重采样算法。
  - 利用 SIMD 加速像素重映射。
- **预期收益**: 自由变换（Transform）操作实时响应，缩放画质显著提升。

---

## 🟡 第二阶段：中等难度，体验优化 (UX Boost)

### 4. 内存级撤销栈压缩 (Undo Stack Compression)
- **优先级**: 🟡 高 (对 Web/移动端极其重要)
- **位置**: `lib/app/widgets/painting_board_state.dart` (Undo Stack)
- **现状**: 内存中直接存储原始 `Uint8List` 像素数据，历史记录极占内存。
- **优化点**: 
  - 使用 Rust 的 **LZ4** 或 **Zstd** 算法对内存中的历史快照进行极速压缩。
- **预期收益**: 内存占用降低 60%-90%，支持成百上千步撤销而不崩溃。

### 5. 调色板量化与匹配 (Color Quantization)
- **优先级**: 🟡 中
- **位置**: `lib/app/widgets/painting_board_filters_color_range_compute.dart` -> `_findNearestPaletteColor`
- **现状**: 遍历像素寻找最接近的调色板颜色，计算量随像素数线性增长。
- **优化点**: 
  - 在 Rust 中使用 **Octree** 或 **K-Means** 算法进行色彩索引匹配。
- **预期收益**: “图片转像素风”等色彩滤镜实现秒级处理。

### 6. 魔棒工具 (Magic Wand)
- **优先级**: 🟢 高 (开发量极小)
- **位置**: `lib/backend/canvas_painting_worker.dart` -> `_paintingWorkerFloodMask`
- **现状**: 纯 Dart 实现的 Flood Fill 掩码提取。
- **优化点**: 复用已有的 Rust `bucket_fill` 逻辑，仅需修改返回值为掩码 Buffer。
- **预期收益**: 秒开大区域选区。

### 4. 选区轮廓生成 (Marching Squares)
- **优先级**: 🟡 中
- **位置**: `lib/app/widgets/painting_board_selection_path_from_mask.dart` -> `_selectionPathFromMask`
- **现状**: 遍历像素掩码生成 Flutter Path 对象，大图下极慢。
- **优化点**: 在 Rust 中执行 Marching Squares 算法，只向 Dart 返回顶点坐标数组。
- **预期收益**: 消除创建选区时的 UI “冻结”感。

---

## 🟡 功能性优化

### 5. 喷枪粒子模拟 (Spray Engine)
- **优先级**: 🟡 中
- **位置**: `lib/painting/krita_spray_engine.dart`
- **现状**: 每一帧生成大量随机粒子并计算分布。
- **优化点**: 将粒子生命周期和物理位置计算移入 Rust。

### 6. PSD 文件解析 (PSD Importer)
- **优先级**: 🟡 中
- **位置**: `lib/app/psd/psd_importer.dart`
- **现状**: 纯 Dart 解析复杂的 PSD 二进制结构。
- **优化点**: 引入 Rust `psd` crate 进行解析，实现 Zero-copy 图层数据传输。

---

## 🛠 实施指南
1. **优先处理合成引擎**：这是绘图软件的“心脏”，收益最高。
2. **利用 Zero-copy**：通过 `flutter_rust_bridge` 的 `ZeroCopy` 机制处理大图 Buffer。
3. **保持异步**：确保 Rust 调用不阻塞主线程。
