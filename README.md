# Misa Rin

Misa Rin 是一款聚焦桌面端的现代化数字绘画与像素创作软件。界面基于 Fluent UI，在 **12MB** 的极致体积下，实现了秒级启动与媲美原生应用的流畅体验。

无论是速写、像素草图、UI 设计还是工业级赛璐璐平涂，都可以在一个统一的、无限边界的画布里完成。

<img width="1470" height="879" alt="image" src="https://github.com/user-attachments/assets/b524add6-66ab-4567-889c-9f9e076ec737" />

> ⚠️ **注意**：项目仍处于早期开发阶段 (Alpha)，请勿将其用于关键生产项目。

---

## ✨ 核心亮点

- **极致轻量**：仅约 **12MB** 的包体大小，零依赖，秒启动，拒绝臃肿。
- **混合渲染引擎**：采用 **矢量流光栅化 (Deferred Rasterization)** 技术，绘画时享受矢量般的 120Hz 丝滑预览，松手即刻生成位图，在超大分辨率下依然流畅。
- **鼠标党福音**：内置 **速度-压力映射模型** 与 **带压感的贝塞尔曲线工具**，无需数位板也能画出带有完美笔锋的线稿。
- **跨平台同构**：基于 Flutter 与 CanvasKit，在 Windows、macOS、Linux 与 Web 上提供完全一致的性能与交互体验。

## 🎨 绘画与创作

- **专注画布**：自研分块渲染 (Chunk-based Rendering) 引擎，支持无限尺寸画布、无限撤销/重做。
- **专业手感**：内置高性能抖动修正 (Stabilizer)，手感对标 SAI2。
- **多种工具**：画笔、油漆桶、取色器、魔棒、套索/多边形选区、图层变换等一应俱全。
- **灵活图层**：支持分组、透明度调节与多种混合模式（Multiply, Overlay, Add 等），满足复杂构图需求。

## 🛠️ Retas 风格二值化工作流 (Industrial Workflow)

Misa Rin 致敬并重现了日本动画工业（PaintMan/Retas）的高效二值化生产流程，专为赛璐璐风格与像素艺术家打造：

1.  **非破坏性二值化**：支持全程使用锯齿（Aliased）线条作画与填色，彻底告别“油漆桶白边”与繁琐的容差调整。
2.  **色线吞并 (Color Trace Enclosure)**：支持使用红/绿/蓝线圈定阴影与高光区域，油漆桶填色时自动吞并色线（色トレス/Color Trace），实现工业级的高速分色。
3.  **后期抗锯齿渲染**：独家的 **二次算法抗锯齿 (Post-process AA)** 功能，允许在导出时将二值化画面一键渲染为平滑的高清插画。

## 📥 获取与体验

- **桌面版 (推荐)**：前往 [Releases](https://github.com/MCDFsteve/MisaRin/releases) 下载最新安装包。
    - *适用于生产环境，支持多线程处理与本地文件管理。*
- **网页版**：访问 https://misarin.aimes-soft.com
    - *适用于即时体验与轻量摸鱼，无需安装。*

## ⌨️ 快速上手

1.  启动应用后，通过“新建”向导创建画布，或直接拖入图片/`.rin` 项目文件。
2.  如需自行构建，请确保安装 Flutter 3.9+：
    ```bash
    flutter pub get
    flutter run -d <windows|macos|linux>
    ```

> **提示**：macOS 版本会自动挂载原生系统菜单；Web 版建议使用 Chrome/Edge 以获得最佳 CanvasKit 性能。

## 📂 导入与导出

- **项目管理**：支持保存为 `.rin` 专有格式（包含完整图层与分块数据），内置项目浏览器。
- **导出图像**：支持导出 PNG/JPG，可自定义缩放倍率；支持导出透明背景图层。

## ⚙️ 个性化

- 支持 亮色 / 暗色 / 跟随系统 主题切换。
- 可自定义界面缩放与画布手势灵敏度。

## 🤝 反馈与参与

Misa Rin 致力于探索 Flutter 在高性能图形领域的极限。

- 欢迎通过 Issue/PR 分享你的创意、提出 Bug。
- 如果你是日本动画流程的爱好者或开发者，欢迎通过 Discussion 探讨 Retas 工作流的改进。
- *Keywords for developers: Flutter, CanvasKit, Pixel Art, Cel Shading, Retas, PaintMan, Color Trace (色トレス), Binary Pen (二值化ペン).*

本项目使用 **MIT License** 开源，随意下载、修改、分享与魔改。
