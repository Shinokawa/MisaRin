# Misa Rin

<p align="center">
  <a href="#lang-zh-cn">简体中文</a> ·
  <a href="#lang-zh-tw">繁體中文</a> ·
  <a href="#lang-en">English</a> ·
  <a href="#lang-ko">한국어</a> ·
  <a href="#lang-ja">日本語</a>
</p>

<img width="1470" height="879" alt="Misa Rin screenshot" src="https://github.com/user-attachments/assets/b524add6-66ab-4567-889c-9f9e076ec737" />

<a id="lang-zh-cn"></a>

## 简体中文

Misa Rin 是一款聚焦桌面端的现代化数字绘画与像素创作软件。界面基于 Fluent UI，在 **12MB** 的极致体积下，实现了秒级启动与媲美原生应用的流畅体验。

无论是速写、像素草图、UI 设计还是工业级赛璐璐平涂，都可以在一个统一的、无限边界的画布里完成。

> 注意：项目仍处于早期开发阶段 (Alpha)，请勿将其用于关键生产项目。

---

## 核心亮点

- **极致轻量**：仅约 **12MB** 的包体大小，零依赖，秒启动，拒绝臃肿。
- **混合渲染引擎**：采用 **矢量流光栅化 (Deferred Rasterization)** 技术，绘画时享受矢量般的 120Hz 丝滑预览，松手即刻生成位图。
- **鼠标党福音**：内置 **速度-压力映射模型** 与 **自动尖锐出峰** 算法，配合带压感的贝塞尔曲线工具，无需数位板也能画出带有完美笔锋的线稿。
- **跨平台同构**：基于 Flutter 与 CanvasKit，在 Windows、macOS、Linux 与 Web 上提供完全一致的性能与交互体验。

## 绘画与创作

- **专业笔刷引擎**：
    - **多形状笔尖**：原生支持圆形、三角形、正方形、五角星笔尖，满足像素画与硬边概括需求。
    - **随机旋转（印章）**：方形/三角形/五角星印章支持随机旋转，让散点与装饰笔触更自然。
    - **物理开关**：支持一键“转换为擦除”模式，保留当前笔刷纹理进行擦除；支持独立开关“数位笔压”与“模拟笔压”。
    - **矢量作画**：可选开启矢量预览，提供绝对流畅的笔触反馈；抬笔后支持 StreamLine 平滑重算，并以补间动画回弹到更顺的结果。
    - **空心描边/空心笔刷**：支持空心比例与“吃掉重叠部分”，快速画出干净的描边与线稿效果。
    - **透视辅助**：支持 1/2/3 点透视线与透视笔，绘制时可按透视方向吸附。
- **选区与编辑**：提供“选区笔”，像画笔一样涂抹创建选区，可与现有选区叠加。
- **强大的文本工具**：支持 **横排/竖排** 文本输入，可自由调节字体（支持预览与收藏）、字号、行距、字间距，并支持 **文字描边 (Stroke)**，完美适应漫画嵌字与海报设计。
- **专注画布**：自研分块渲染 (Chunk-based Rendering) 引擎，支持无限尺寸画布、无限撤销/重做与多文档标签页管理。

## Retas 风格二值化工作流 (Industrial Workflow)

Misa Rin 致敬并重现了日本动画工业（PaintMan/Retas）的高效二值化生产流程，专为赛璐璐风格与像素艺术家打造：

1.  **非破坏性二值化**：支持全程使用锯齿（Aliased）线条作画与填色，彻底告别“油漆桶白边”与繁琐的容差调整。
2.  **色线吞并 (Color Trace Enclosure)**：面板内置红/绿/蓝/黑专用色线按钮，油漆桶填色时自动吞并色线（色トレス/Color Trace），实现工业级的高速分色。
3.  **后期边缘柔化渲染**：独家的 **二次算法边缘柔化** 功能，允许在导出时将二值化画面一键渲染为平滑且保留线条密度的高清插画。

## 图像处理与滤镜

内置轻量级图像处理管线，无需导出即可完成后期调整：
- **基础调整**：色相/饱和度 (HSB)、亮度/对比度、黑白、二值化、颜色反转。
- **线稿处理**：扫描纸绘（纸白转透明，提取黑/红/绿/蓝线条，可调黑/白点与中间调）、去除漏色。
- **形态学工具**：线条收窄、填色拉伸。
- **颜色处理**：色彩范围（减色/分色效果，支持实时预览）。
- **特效滤镜**：高斯模糊 (Gaussian Blur)。
- **渲染控制**：可调节等级的边缘柔化 (Anti-aliasing) 滤镜。

## 视图与辅助

- **视图旋转**：旋转工具可自由旋转画布视图并一键复位（不影响实际像素）。
- **专注辅助**：像素网格、镜像预览、黑白预览。
- **画布变换**：支持画布旋转 90°/180°、图像大小与画布大小调整、图层自由变换（持续优化缩放锚点与画布大小锚点可读性）。
- **交互细节**：优化图层重命名交互与文本选择样式等细节体验。
- **3D 参考模型**：内置 Steve/Alex 模型查看器，支持导入自定义 Bedrock 模型；支持多角度观察、实时贴图烘焙（Bake）与 Z-Buffer 阴影预览，辅助皮肤绘制与光影参考。

## 导入与导出

- **文件格式**：支持保存为 `.rin`；导入/导出 PSD（保留图层结构）。
- **导出**：PNG（倍率与导出前边缘柔化）、SVG（自动矢量化，最大颜色数/路径简化可调）。
- **素材与色彩**：支持拖拽/剪贴板导入图片；从画布取色生成调色盘与渐变调色盘，并支持导入/导出调色盘；支持参考图像面板。

## 获取与体验

- **桌面版 (推荐)**：前往 [Releases](https://github.com/MCDFsteve/MisaRin/releases) 下载最新安装包。
    - *适用于生产环境，支持多线程处理与本地文件管理。*
- **网页版**：访问 https://misarin.aimes-soft.com
    - *适用于即时体验与轻量摸鱼，无需安装。*

## 快速上手

1.  启动应用后，通过“新建”向导创建画布，或直接从 **剪贴板/拖拽** 导入图像创建新画布（也支持导入 PSD）；也可以通过“打开项目”直接导入 PNG/JPG/JPEG/WEBP/AVIF 创建文档。
2.  如需自行构建，请确保安装 Flutter 3.9+：
    ```bash
    flutter pub get
    flutter run -d <windows|macos|linux>
    ```

> 提示：支持切换 **SAI2 工作区布局**，老用户可零成本迁移；macOS 版本会自动挂载原生系统菜单。

## 个性化

- 支持 亮色 / 暗色 / 跟随系统 主题切换。
- 支持语言切换（跟随系统 / 中文 / English / 日本語 / 한국어）。
- 可自定义界面缩放与画布手势灵敏度。
- 可选显示 FPS/性能脉冲浮层，便于定位卡顿与性能问题。

## 反馈与参与

Misa Rin 致力于探索 Flutter 在高性能图形领域的极限。

- 欢迎通过 Issue/PR 分享你的创意、提出 Bug。
- 如果你是日本动画流程的爱好者或开发者，欢迎通过 Discussion 探讨 Retas 工作流的改进。
- Release 说明由发布工作流自动汇总提交信息。
- *Keywords for developers: Flutter, CanvasKit, Pixel Art, Cel Shading, Retas, PaintMan, Color Trace (色トレス), Binary Pen (二值化ペン).*

本项目使用 **MIT License** 开源，随意下载、修改、分享与魔改。

<br>
<br>

<a id="lang-zh-tw"></a>

## 繁體中文

Misa Rin 是一款聚焦桌面端的現代化數位繪畫與像素創作軟體。介面基於 Fluent UI，在 **12MB** 的極致體積下，實現秒級啟動與媲美原生應用的流暢體驗。

無論是速寫、像素草圖、UI 設計還是工業級賽璐璐平塗，都可以在一個統一的、無限邊界的畫布裡完成。

> 注意：專案仍處於早期開發階段 (Alpha)，請勿將其用於關鍵生產專案。

---

## 核心亮點

- **極致輕量**：僅約 **12MB** 的安裝包大小，零依賴，秒啟動，拒絕臃腫。
- **混合渲染引擎**：採用 **向量流光柵化 (Deferred Rasterization)** 技術，繪畫時享受向量般的 120Hz 絲滑預覽，鬆手即刻生成位圖。
- **滑鼠族福音**：內建 **速度-壓力映射模型** 與 **自動尖銳出峰** 演算法，配合帶壓感的貝茲曲線工具，無需繪圖板也能畫出帶有完美筆鋒的線稿。
- **跨平台同構**：基於 Flutter 與 CanvasKit，在 Windows、macOS、Linux 與 Web 上提供完全一致的性能與互動體驗。

## 繪畫與創作

- **專業筆刷引擎**：
    - **多形狀筆尖**：原生支援圓形、三角形、正方形、五角星筆尖，滿足像素畫與硬邊概括需求。
    - **隨機旋轉（印章）**：方形/三角形/五角星印章支援隨機旋轉，讓散點與裝飾筆觸更自然。
    - **物理開關**：支援一鍵「轉換為擦除」模式，保留目前筆刷紋理進行擦除；支援獨立開關「數位筆壓」與「模擬筆壓」。
    - **向量作畫**：可選啟用向量預覽，提供極致流暢的筆觸回饋；抬筆後支援 StreamLine 平滑重算，並以補間動畫回彈到更順的結果。
    - **空心描邊/空心筆刷**：支援空心比例與「吃掉重疊部分」，快速畫出乾淨的描邊與線稿效果。
    - **透視輔助**：支援 1/2/3 點透視線與透視筆，繪製時可按透視方向吸附。
- **選區與編輯**：提供「選區筆」，像畫筆一樣塗抹建立選區，可與現有選區疊加。
- **強大的文字工具**：支援 **橫排/直排** 文字輸入，可自由調整字體（支援預覽與收藏）、字號、行距、字間距，並支援 **文字描邊 (Stroke)**，完美適應漫畫嵌字與海報設計。
- **專注畫布**：自研分塊渲染 (Chunk-based Rendering) 引擎，支援無限尺寸畫布、無限撤銷/重做與多文件分頁管理。

## Retas 風格二值化工作流 (Industrial Workflow)

Misa Rin 致敬並重現了日本動畫工業（PaintMan/Retas）的高效二值化生產流程，專為賽璐璐風格與像素藝術家打造：

1.  **非破壞性二值化**：支援全程使用鋸齒（Aliased）線條作畫與填色，徹底告別「油漆桶白邊」與繁瑣的容差調整。
2.  **色線吞併 (Color Trace Enclosure)**：面板內建紅/綠/藍/黑專用色線按鈕，油漆桶填色時自動吞併色線（色トレス/Color Trace），實現工業級的高速分色。
3.  **後期邊緣柔化渲染**：獨家的 **二次演算法邊緣柔化** 功能，允許在匯出時將二值化畫面一鍵渲染為平滑且保留線條密度的高清插畫。

## 影像處理與濾鏡

內建輕量級影像處理管線，無需匯出即可完成後期調整：
- **基礎調整**：色相/飽和度 (HSB)、亮度/對比度、黑白、二值化、顏色反轉。
- **線稿處理**：掃描紙繪（紙白轉透明，提取黑/紅/綠/藍線條，可調黑/白點與中間調）、去除漏色。
- **形態學工具**：線條收窄、填色拉伸。
- **顏色處理**：色彩範圍（減色/分色效果，支援即時預覽）。
- **特效濾鏡**：高斯模糊 (Gaussian Blur)。
- **渲染控制**：可調整等級的邊緣柔化 (Anti-aliasing) 濾鏡。

## 視圖與輔助

- **視圖旋轉**：旋轉工具可自由旋轉畫布視圖並一鍵復位（不影響實際像素）。
- **專注輔助**：像素網格、鏡像預覽、黑白預覽。
- **畫布變換**：支援畫布旋轉 90°/180°、影像大小與畫布大小調整、圖層自由變換（持續優化縮放錨點與畫布大小錨點可讀性）。
- **互動細節**：優化圖層重命名互動與文字選取樣式等細節體驗。
- **3D 參考模型**：內建 Steve/Alex 模型檢視器，支援匯入自訂 Bedrock 模型；支援多角度觀察、即時貼圖烘焙（Bake）與 Z-Buffer 陰影預覽，輔助皮膚繪製與光影參考。

## 匯入與匯出

- **檔案格式**：支援儲存為 `.rin`；匯入/匯出 PSD（保留圖層結構）。
- **匯出**：PNG（倍率與匯出前邊緣柔化）、SVG（自動向量化，最大顏色數/路徑簡化可調）。
- **素材與色彩**：支援拖曳/剪貼簿匯入圖片；從畫布取色生成調色盤與漸層調色盤，並支援匯入/匯出調色盤；支援參考圖像面板。

## 取得與體驗

- **桌面版（推薦）**：前往 [Releases](https://github.com/MCDFsteve/MisaRin/releases) 下載最新安裝包。
    - *適用於生產環境，支援多執行緒處理與本機檔案管理。*
- **網頁版**：訪問 https://misarin.aimes-soft.com
    - *適用於即時體驗與輕量摸魚，無需安裝。*

## 快速上手

1.  啟動應用後，透過「新建」精靈建立畫布，或直接從 **剪貼簿/拖曳** 匯入影像建立新畫布（也支援匯入 PSD）；也可以透過「開啟專案」直接匯入 PNG/JPG/JPEG/WEBP/AVIF 建立文件。
2.  如需自行建置，請確保已安裝 Flutter 3.9+：
    ```bash
    flutter pub get
    flutter run -d <windows|macos|linux>
    ```

> 提示：支援切換 **SAI2 工作區佈局**，老用戶可零成本遷移；macOS 版本會自動掛載原生系統選單。

## 個人化

- 支援 亮色 / 暗色 / 跟隨系統 主題切換。
- 支援語言切換（跟隨系統 / 中文 / English / 日本語 / 한국어）。
- 可自訂介面縮放與畫布手勢靈敏度。
- 可選顯示 FPS/性能脈衝浮層，便於定位卡頓與性能問題。

## 回饋與參與

Misa Rin 致力於探索 Flutter 在高效能圖形領域的極限。

- 歡迎透過 Issue/PR 分享你的創意、提出 Bug。
- 如果你是日本動畫流程的愛好者或開發者，歡迎透過 Discussion 探討 Retas 工作流的改進。
- Release 說明由發佈工作流自動彙整提交資訊。
- *Keywords for developers: Flutter, CanvasKit, Pixel Art, Cel Shading, Retas, PaintMan, Color Trace (色トレス), Binary Pen (二值化ペン).*

本專案使用 **MIT License** 開源，隨意下載、修改、分享與魔改。

<br>
<br>

<a id="lang-en"></a>

## English

Misa Rin is a modern digital painting and pixel creation app focused on desktop. With a Fluent UI-inspired interface and an ultra-small **12MB** footprint, it starts instantly and feels as smooth as a native app.

Whether you're doing quick sketches, pixel drafts, UI design, or industrial-grade cel-style flat coloring, everything happens on a unified, infinite canvas.

> Note: This project is still in early development (Alpha). Do not use it for critical production work.

---

## Core Highlights

- **Ultra-lightweight**: ~**12MB** package, instant startup, no bloat.
- **Hybrid rendering engine**: **Deferred Rasterization** enables vector-like 120Hz previews while drawing, then rasterizes on release.
- **Mouse-first**: Speed-to-pressure mapping + an automatic sharp-tip algorithm; paired with a pressure-enabled Bezier tool, you can draw tapered lineart even without a tablet.
- **Cross-platform parity**: Flutter + CanvasKit deliver consistent performance and interaction on Windows, macOS, Linux, and Web.

## Drawing & Creation

- **Professional brush engine**:
    - **Multiple tip shapes**: circle, triangle, square, star.
    - **Random rotation (stamps)**: random rotation for square/triangle/star stamps for more natural scatter and decorative strokes.
    - **Physical toggles**: one-click “convert to eraser” while keeping brush texture; independent toggles for pen pressure and simulated pressure.
    - **Vector drawing**: optional vector preview for ultra-smooth feedback; on pen-up, StreamLine re-smooths the preview stroke and animates back to a cleaner result.
    - **Hollow stroke / hollow brush**: adjustable hollow ratio and “eat overlaps” for clean outlines and lineart.
    - **Perspective helpers**: 1/2/3-point perspective lines and a perspective brush with directional snapping.
- **Selection & editing**: “Selection Brush” lets you paint selections like a brush and add to existing selections.
- **Powerful text tool**: horizontal/vertical text, font (with preview & favorites)/size/leading/tracking controls, plus text stroke support.
- **Focused canvas**: Chunk-based Rendering engine with infinite canvas, unlimited undo/redo, and multi-document tabs.

## Retas-style Binary Workflow (Industrial Workflow)

Misa Rin pays tribute to the Japanese animation pipeline (PaintMan/Retas) and recreates an efficient binary-color workflow for cel-style and pixel artists:

1.  **Non-destructive binarization**: draw and fill with aliased lines end-to-end, avoiding “bucket halos” and tolerance tweaking.
2.  **Color Trace Enclosure**: dedicated red/green/blue/black trace-line buttons; bucket fill automatically encloses trace lines (色トレス/Color Trace) for industrial-speed color separation.
3.  **Post edge-softening render**: a unique second-pass edge-softening algorithm to render binary artwork into smooth, high-resolution illustrations while preserving line density.

## Image Processing & Filters

A lightweight image processing pipeline is built in, so you can adjust without exporting:
- **Basic adjustments**: HSB, brightness/contrast, grayscale, binarization, invert.
- **Lineart tools**: scan cleanup (paper white to transparent, extract black/red/green/blue lines, black/white points & midtones), de-bleed.
- **Morphology**: line thinning, fill expansion.
- **Color**: color range (subtractive / color separation effects, real-time preview).
- **Effects**: Gaussian Blur.
- **Render control**: adjustable anti-aliasing filter.

## Views & Helpers

- **View rotation**: freely rotate the canvas view and reset (does not change actual pixels).
- **Focus aids**: pixel grid, mirror preview, B/W preview.
- **Canvas transforms**: rotate 90°/180°, image/canvas resize, layer free transform (with ongoing polish for scaling anchors and canvas-size anchors).
- **Interaction polish**: improved layer renaming, text selection styling, and other UX details.
- **3D Reference Model**: Built-in Steve/Alex model viewer with custom Bedrock model import; supports multi-angle viewing, real-time texture baking, and Z-Buffer shadow preview to assist with skin texturing and lighting.

## Import & Export

- **Formats**: save as `.rin`; import/export PSD (preserves layer structure).
- **Export**: PNG (scale + pre-export edge softening), SVG (auto-vectorization with configurable max colors / path simplification).
- **Assets & color**: drag & drop / clipboard image import; pick colors from canvas to build palettes & gradient palettes (with import/export); reference image panel.

## Get & Try

- **Desktop (recommended)**: download the latest builds from [Releases](https://github.com/MCDFsteve/MisaRin/releases).
    - *For production use, with multithreaded processing and local file management.*
- **Web**: https://misarin.aimes-soft.com
    - *Great for quick trials—no installation required.*

## Quick Start

1.  Create a canvas via the “New” wizard, or import an image via **clipboard/drag & drop** (PSD import is also supported). You can also use “Open Project” to import PNG/JPG/JPEG/WEBP/AVIF and create a document.
2.  To build it yourself, install Flutter 3.9+:
    ```bash
    flutter pub get
    flutter run -d <windows|macos|linux>
    ```

> Tip: The **SAI2 workspace layout** is available for easy migration; on macOS, the app auto-mounts the native system menu.

## Customization

- Light / dark / follow system theme.
- Language switching (follow system / 中文 / English / 日本語 / 한국어).
- Custom UI scale and canvas gesture sensitivity.
- Optional FPS/performance pulse overlay for diagnosing jank and performance issues.

## Feedback & Contributing

Misa Rin explores the limits of Flutter in high-performance graphics.

- Share ideas and report bugs via Issues/PRs.
- If you're interested in the Japanese animation pipeline, join Discussions to improve the Retas workflow.
- Release notes are automatically generated from commits by the publishing workflow.
- *Keywords for developers: Flutter, CanvasKit, Pixel Art, Cel Shading, Retas, PaintMan, Color Trace (色トレス), Binary Pen (二值化ペン).*

Released under the **MIT License** — feel free to download, modify, and share.

<br>
<br>

<a id="lang-ko"></a>

## 한국어

Misa Rin은 데스크톱에 초점을 둔 현대적인 디지털 드로잉·픽셀 아트 제작 소프트웨어입니다. Fluent UI 기반의 UI와 **12MB** 수준의 초경량 크기로, 빠른 실행과 네이티브급 부드러움을 제공합니다.

스케치, 픽셀 스케치, UI 디자인, 산업용 셀룰로이드 평면 채색까지—모든 작업을 하나의 무한 캔버스에서 완성할 수 있습니다.

> 안내: 본 프로젝트는 아직 초기 개발 단계(Alpha)입니다. 중요한 프로덕션 용도로 사용하지 마세요.

---

## 핵심 하이라이트

- **초경량**: 약 **12MB**, 즉시 실행, 불필요한 비대함 없이 가볍게.
- **하이브리드 렌더링 엔진**: **Deferred Rasterization**으로 드로잉 중에는 120Hz 벡터급 미리보기를 제공하고, 손을 떼는 순간 비트맵으로 생성합니다.
- **마우스 친화**: 속도-압력 매핑 + 자동 샤프 팁 알고리즘, 그리고 압력을 지원하는 베지어 도구로 태블릿 없이도 자연스러운 필압 선을 그릴 수 있습니다.
- **크로스플랫폼 동일 경험**: Flutter + CanvasKit 기반으로 Windows/macOS/Linux/Web에서 일관된 성능과 UX를 제공합니다.

## 드로잉 & 제작

- **전문 브러시 엔진**:
    - **다양한 팁 형태**: 원/삼각/사각/별(오각별) 팁을 기본 지원합니다.
    - **랜덤 회전(스탬프)**: 사각/삼각/별 스탬프를 랜덤 회전해 더 자연스러운 산포·장식 스트로크를 만들 수 있습니다.
    - **토글 스위치**: 한 번에 “지우개로 전환”(텍스처 유지); 펜 압력/가상 압력 개별 토글.
    - **벡터 드로잉**: 벡터 미리보기 옵션으로 매우 부드러운 피드백 제공; 펜을 떼면 StreamLine이 스트로크를 스무딩 재계산하고 트윈 애니메이션으로 더 매끄러운 결과로 되돌립니다.
    - **홀로우(윤곽) 스트로크/브러시**: 홀로우 비율과 “겹침 부분 제거”로 깔끔한 라인아트를 빠르게.
    - **원근 보조**: 1/2/3점 원근선 및 원근 브러시, 방향 스냅.
- **선택 영역 & 편집**: “선택 영역 브러시”로 브러시처럼 칠해서 선택 영역을 만들고 기존 선택에 더할 수 있습니다.
- **강력한 텍스트 도구**: 가로/세로 텍스트, 폰트(미리보기 및 즐겨찾기 포함)/크기/행간/자간 조절, 텍스트 스트로크(Stroke) 지원.
- **집중 캔버스**: Chunk-based Rendering 엔진, 무한 캔버스, 무제한 실행 취소/다시 실행, 다중 문서 탭.

## Retas 스타일 이진화 워크플로 (Industrial Workflow)

Misa Rin은 일본 애니메이션 제작 파이프라인(PaintMan/Retas)의 효율적인 이진화 생산 공정을 오마주/재현하여, 셀룰로이드 스타일과 픽셀 아티스트를 위해 설계되었습니다:

1.  **비파괴적 이진화**: Aliased 라인으로 처음부터 끝까지 그리기/채색이 가능해, “버킷 흰 테두리”와 번거로운 허용 오차 조정을 줄입니다.
2.  **Color Trace Enclosure**: 전용 R/G/B/Black 색선 버튼을 제공하며, 버킷 채색 시 색선을 자동으로 포함(色トレス/Color Trace)하여 고속 분색을 구현합니다.
3.  **후처리 에지 소프트닝 렌더**: 독자적인 2차 에지 소프트닝 알고리즘으로, 이진화된 결과를 선 밀도를 유지한 채 매끄러운 고해상도 일러스트로 렌더링합니다.

## 이미지 처리 & 필터

가벼운 이미지 처리 파이프라인을 내장하여, 내보내기 없이도 후반 보정을 할 수 있습니다:
- **기본 조정**: HSB, 밝기/대비, 흑백, 이진화, 색상 반전.
- **라인아트 도구**: 스캔 정리(종이 흰색→투명, 검정/빨강/초록/파랑 선 추출, 흑/백 포인트 & 중간톤), 번짐 제거.
- **형태학 도구**: 선 얇게, 채색 확장.
- **색상 처리**: 색상 범위(감산/분색 효과, 실시간 미리보기).
- **효과**: 가우시안 블러(Gaussian Blur).
- **렌더 제어**: 단계 조절 가능한 안티앨리어싱(Anti-aliasing) 필터.

## 뷰 & 보조 기능

- **뷰 회전**: 캔버스 뷰를 자유롭게 회전하고 원클릭으로 복귀(실제 픽셀에는 영향 없음).
- **집중 보조**: 픽셀 그리드, 미러 프리뷰, 흑백 프리뷰.
- **캔버스 변환**: 90°/180° 회전, 이미지/캔버스 크기 조정, 레이어 자유 변환(스케일 앵커/캔버스 크기 앵커 가독성 지속 개선).
- **UX 디테일**: 레이어 이름 변경, 텍스트 선택 스타일 등 상호작용 디테일 개선.
- **3D 참조 모델**: Steve/Alex 모델 뷰어 내장 및 사용자 정의 Bedrock 모델 가져오기 지원; 다각도 보기, 실시간 텍스처 베이킹(Bake) 및 Z-Buffer 그림자 미리보기를 지원하여 스킨 텍스처링과 조명 참고를 돕습니다.

## 가져오기 & 내보내기

- **파일 형식**: `.rin` 저장 지원; PSD 가져오기/내보내기(레이어 구조 보존).
- **내보내기**: PNG(배율 + 내보내기 전 에지 소프트닝), SVG(자동 벡터화, 최대 색상 수/경로 단순화 조절).
- **소재 & 색상**: 드래그&드롭/클립보드 이미지 가져오기; 캔버스에서 색을 추출해 팔레트/그라데이션 팔레트 생성(가져오기/내보내기 지원); 레퍼런스 이미지 패널.

## 다운로드 & 체험

- **데스크톱(추천)**: [Releases](https://github.com/MCDFsteve/MisaRin/releases)에서 최신 빌드를 다운로드하세요.
    - *프로덕션 사용에 적합하며, 멀티스레드 처리 및 로컬 파일 관리를 지원합니다.*
- **웹 버전**: https://misarin.aimes-soft.com
    - *설치 없이 빠르게 체험할 수 있습니다.*

## 빠른 시작

1.  “새로 만들기” 마법사로 캔버스를 생성하거나, **클립보드/드래그&드롭**으로 이미지를 가져오세요(PSD 가져오기 지원). “프로젝트 열기”에서 PNG/JPG/JPEG/WEBP/AVIF를 바로 가져와 문서를 만들 수도 있습니다.
2.  직접 빌드하려면 Flutter 3.9+를 설치하세요:
    ```bash
    flutter pub get
    flutter run -d <windows|macos|linux>
    ```

> 팁: **SAI2 워크스페이스 레이아웃**을 제공하며, macOS에서는 네이티브 시스템 메뉴가 자동으로 연결됩니다.

## 개인화

- 라이트/다크/시스템 테마.
- 언어 전환(시스템 / 中文 / English / 日本語 / 한국어).
- UI 배율 및 캔버스 제스처 민감도 설정.
- FPS/성능 펄스 오버레이(옵션)로 끊김 및 성능 문제 진단.

## 피드백 & 참여

Misa Rin은 고성능 그래픽 영역에서 Flutter의 한계를 탐구합니다.

- Issues/PR로 아이디어 공유 및 버그 제보를 환영합니다.
- 일본 애니메이션 파이프라인에 관심이 있다면 Discussions에서 Retas 워크플로 개선을 함께 논의해요.
- 릴리즈 노트는 퍼블리시 워크플로가 커밋 정보를 자동으로 반영합니다.
- *Keywords for developers: Flutter, CanvasKit, Pixel Art, Cel Shading, Retas, PaintMan, Color Trace (色トレス), Binary Pen (二值化ペン).*

본 프로젝트는 **MIT License**로 오픈소스이며, 자유롭게 다운로드/수정/공유할 수 있습니다.

<br>
<br>

<a id="lang-ja"></a>

## 日本語

Misa Rin はデスクトップ向けにフォーカスしたモダンなデジタルペイント／ピクセル制作ソフトです。Fluent UI ベースの UI と **12MB** 級の超軽量設計で、秒起動とネイティブ級の滑らかさを実現します。

ラフスケッチ、ピクセル下絵、UI デザイン、工業レベルのセル風ベタ塗りまで、すべてを 1 つの無限キャンバスで完結できます。

> 注意：本プロジェクトはまだ初期開発段階（Alpha）です。重要なプロダクション用途での利用は避けてください。

---

## コアハイライト

- **超軽量**：約 **12MB**、即起動、無駄を削ぎ落とした設計。
- **ハイブリッド描画エンジン**：**Deferred Rasterization** により描画中は 120Hz のベクター級プレビュー、離した瞬間にビットマップ生成。
- **マウスでも描ける**：速度→筆圧マッピングと自動鋭角化アルゴリズム。筆圧対応ベジエツールと組み合わせ、タブレットなしでも綺麗な入り抜き線を描けます。
- **クロスプラットフォーム同等体験**：Flutter + CanvasKit により Windows/macOS/Linux/Web で一貫した性能と操作感。

## 描画 & 制作

- **プロ向けブラシエンジン**：
    - **複数の筆先形状**：円／三角／四角／星（五角星）を標準サポート。
    - **ランダム回転（スタンプ）**：四角/三角/星のスタンプはランダム回転に対応し、散布や装飾ストロークを自然に。
    - **物理スイッチ**：ワンクリックで「消しゴムへ変換」（テクスチャ保持）。筆圧／疑似筆圧を個別に切替可能。
    - **ベクター描画**：ベクタープレビューで極めて滑らかなフィードバック。ペンを離すと StreamLine がスムージング再計算し、補間アニメでより綺麗な結果へ戻します。
    - **中抜きストローク/中抜きブラシ**：中抜き率と「重なりを食べる」でクリーンなアウトラインを素早く作成。
    - **パース補助**：1/2/3 点透視線とパースブラシ。方向にスナップ可能。
- **選択範囲 & 編集**：「選択範囲ブラシ」でブラシのように塗って選択範囲を作成し、既存選択に加算できます。
- **強力なテキストツール**：横書き/縦書き、フォント（プレビュー・お気に入り対応）/サイズ/行間/字間、文字フチ（Stroke）に対応。
- **集中キャンバス**：Chunk-based Rendering エンジンにより無限キャンバス、無制限の Undo/Redo、複数ドキュメントのタブ管理。

## Retas 風二値化ワークフロー (Industrial Workflow)

Misa Rin は日本アニメ制作（PaintMan/Retas）の効率的な二値化生産フローをオマージュ／再現し、セル風・ピクセル制作向けに最適化しています：

1.  **非破壊二値化**：Aliased 線で描画・塗りを完結でき、バケツの白フチや面倒な許容差調整を回避。
2.  **色線吞併 (Color Trace Enclosure)**：赤/緑/青/黒の専用色線ボタン。バケツ塗り時に色線（色トレス/Color Trace）を自動で含め、高速な分色を実現。
3.  **後処理エッジ柔化レンダリング**：独自の 2 段階エッジ柔化アルゴリズムで、線密度を保ちつつ滑らかな高解像度イラストへレンダリング可能。

## 画像処理 & フィルター

軽量な画像処理パイプラインを内蔵し、書き出し不要で調整できます：
- **基本調整**：HSB、明るさ/コントラスト、白黒、二値化、反転。
- **線画処理**：スキャン補正（紙白→透明、黒/赤/緑/青線抽出、黒/白点と中間調調整）、色漏れ除去。
- **形態学ツール**：線の細化、塗りの拡張。
- **色処理**：色域（減色/分色効果、リアルタイムプレビュー）。
- **効果**：ガウスぼかし (Gaussian Blur)。
- **レンダ制御**：段階調整可能なアンチエイリアス (Anti-aliasing) フィルター。

## 表示 & 補助

- **ビュー回転**：キャンバス表示を自由回転しワンクリックで復帰（実ピクセルは不変）。
- **集中補助**：ピクセルグリッド、ミラープレビュー、白黒プレビュー。
- **キャンバス変換**：90°/180° 回転、画像/キャンバスサイズ変更、レイヤー自由変形（スケールアンカーやキャンバスサイズアンカーの可読性を継続改善）。
- **操作の磨き込み**：レイヤー名変更やテキスト選択の見た目など、細部 UX を改善。
- **3D 参照モデル**: Steve/Alex モデルビューワーを内蔵し、カスタム Bedrock モデルのインポートに対応。多角的な観察、リアルタイムテクスチャ焼き込み（Bake）、Z-Buffer 陰影プレビューにより、スキン制作やライティングの参考に最適。

## インポート & エクスポート

- **形式**：`.rin` 保存、PSD のインポート/エクスポート（レイヤー構造保持）。
- **書き出し**：PNG（倍率 + 事前エッジ柔化）、SVG（自動ベクター化。最大色数/パス簡略化を調整可能）。
- **素材 & 色**：ドラッグ&ドロップ/クリップボードで画像を取り込み。キャンバスから色を取得してパレット/グラデーションパレットを生成（入出力対応）。参照画像パネル。

## 入手 & 体験

- **デスクトップ版（推奨）**：[Releases](https://github.com/MCDFsteve/MisaRin/releases) から最新版をダウンロード。
    - *マルチスレッド処理とローカルファイル管理に対応し、実運用にも適しています。*
- **Web 版**：https://misarin.aimes-soft.com
    - *インストール不要で気軽に試せます。*

## クイックスタート

1.  「新規作成」ウィザードでキャンバスを作成、または **クリップボード/ドラッグ&ドロップ** で画像を取り込み（PSD も対応）。「プロジェクトを開く」から PNG/JPG/JPEG/WEBP/AVIF を直接取り込み、ドキュメントを作成することもできます。
2.  自分でビルドする場合は Flutter 3.9+ をインストールしてください：
    ```bash
    flutter pub get
    flutter run -d <windows|macos|linux>
    ```

> ヒント：**SAI2 ワークスペースレイアウト**を切替可能。macOS ではネイティブのシステムメニューが自動で接続されます。

## カスタマイズ

- ライト/ダーク/システムに追従するテーマ。
- 言語切替（システム / 中文 / English / 日本語 / 한국어）。
- UI スケールとキャンバスジェスチャー感度を調整可能。
- FPS/パフォーマンスパルスのオーバーレイ（任意）で、カクつきや性能問題を把握。

## フィードバック & 参加

Misa Rin は高性能グラフィックス領域における Flutter の限界を探求しています。

- Issue/PR でアイデア共有や不具合報告を歓迎します。
- 日本アニメ制作フローに興味がある方は、Discussions で Retas ワークフロー改善を議論しましょう。
- リリースノートは公開ワークフローがコミット情報を自動で反映します。
- *Keywords for developers: Flutter, CanvasKit, Pixel Art, Cel Shading, Retas, PaintMan, Color Trace (色トレス), Binary Pen (二值化ペン).*

本プロジェクトは **MIT License** で公開されています。自由にダウンロード/改変/共有してください。