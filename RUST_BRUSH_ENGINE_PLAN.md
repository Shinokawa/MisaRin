# 🎨 Rust 笔刷引擎重构计划 (The "SAI2-Level" Roadmap)

本计划旨在通过引入 Rust 驱动的独立渲染管线，解决 Dart UI 线程瓶颈，实现媲美 SAI2/Clip Studio Paint 的零延迟、高平滑度手感。

## 🎯 核心目标
1.  **输入与渲染解耦**：笔刷渲染不再依赖 Flutter UI 线程，彻底消除 UI 卡顿对画画的影响。
2.  **物理级实时平滑**：从简单的“事后修正”升级为实时的“质量-弹簧-阻尼”物理模拟。
3.  **120Hz+ 渲染率**：利用 Rust 直接操作共享内存（Texture），突破 Flutter 60Hz 刷新率限制（在高刷屏上）。

---

## 🛠 阶段一：输入系统的 Rust 化 (Input Pipeline)

目前：Flutter `Listener` -> Dart Controller -> UI Repaint
**目标**：Flutter `Listener` -> Rust Engine -> Shared Texture

- [ ] **Rust 笔触状态机 (Stroke State Machine)**
    - 创建 Rust 结构体 `BrushEngine`，管理当前笔画的状态（位置、压力、速度、倾斜）。
    - 暴露 API：`start_stroke(x, y, p)`, `move_stroke(x, y, p)`, `end_stroke()`.

- [ ] **高频输入缓冲 (Input Buffering)**
    - Flutter 的 `PointerEvent` 可能会一次性发来多个历史点（coalesced events）。
    - 将这些点全部传给 Rust，Rust 使用插值算法填补两帧之间的空隙，避免“断触”。

## ⚖️ 阶段二：物理稳定器与插值 (Stabilizer & Interpolation)

目前：Dart `_StreamlineStabilizer` (部分事后处理)
**目标**：Rust 实时物理模拟

- [ ] **实现 Mass-Spring-Damper 稳定器**
    - 在 Rust 中实现一个虚拟的“物理笔尖”，它被鼠标/手写笔的位置通过弹簧牵引。
    - **收益**：手抖会被物理惯性自然过滤，产生极其圆润自然的线条，且没有“延迟感”（Latency is masked by physics）。

- [ ] **实时 B-Spline / Catmull-Rom 插值**
    - 不再等待笔画结束。在 Rust 中，每收到一个新的输入点，立刻计算出前一个线段的样条曲线，并生成高密度的绘制点（Dabs）。

## 🖼 阶段三：共享纹理渲染 (Shared Texture Rendering)

目前：Dart `CustomPainter` (UI 线程) -> `canvas.drawLine`
**目标**：Rust -> `Vec<u8>` -> Flutter `Texture` Widget

- [ ] **建立共享内存 (Shared Memory)**
    - 在 Rust 端分配一块 RGBA 内存（对应屏幕尺寸）。
    - 通过 `frb` (Flutter Rust Bridge) 或 `ffi` 将内存指针传递给 Flutter 的 `Texture` 组件。

- [ ] **软件光栅化器 (Software Rasterizer)**
    - 在 Rust 中实现笔刷的“盖章”（Stamping）逻辑。
    - 遍历插值生成的点，在共享内存上进行像素混合（Blend）。
    - **注意**：利用 Rust 的 `SIMD` 指令加速像素混合，确保 4K 画布也能跑满 120fps。

- [ ] **脏矩形更新 (Dirty Rect Update)**
    - 每次笔刷移动，只通知 Flutter 更新受影响的区域（Dirty Rect），避免全屏重绘，降低 GPU 负载。

## 📦 阶段四：笔刷动力学 (Brush Dynamics)

- [ ] **压力映射曲线 (Pressure Curve)**
    - 在 Rust 中实现贝塞尔曲线映射：`Input Pressure -> Size/Opacity/Flow`。
    - 让用户可以自定义“硬”、“软”手感。

- [ ] **纹理笔刷支持 (Texture/Bitmapped Brushes)**
    - 支持加载 PNG 笔尖形状。
    - 在 Rust 光栅化器中支持旋转、随机抖动（Jitter）和纹理平铺。

---

## ⚠️ 迁移风险提示
1.  **并发锁**：Rust 渲染线程和主线程可能会竞争同一块内存，需要设计无锁队列（Ring Buffer）来传递输入事件。
2.  **平台兼容性**：`Texture` Widget 在不同平台（Windows/macOS/Linux/Mobile）的底层实现略有不同，需要针对性测试。
