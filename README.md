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

Misa Rin 是一款基于 Rust (WGPU) 与 Flutter 开发的高性能数字绘画与像素创作软件。其核心架构采用 **Rust CPU 光栅化 + WGPU 渲染管线** 的混合模式，既保证了笔刷运算的像素级精度，又实现了秒级启动与极致流畅的交互体验。

无论是像素画、赛璐璐风格插画，还是工业级二值化生产，都可以在这个统一的、无限边界的画布中高效完成。

> **注意**：本项目目前处于早期开发阶段 (Alpha)，功能尚在快速迭代中，请避免在关键生产环境中使用。

### 核心特性

*   **混合渲染架构**
    笔刷引擎由 Rust 在 CPU 端进行高精度光栅化，支持亚像素级抗锯齿与完美的像素对齐；画布合成与显示则由 WGPU 接管，充分利用现代 GPU 性能。
*   **专为鼠标绘图优化**
    内置速度-压力映射模型与 **Streamline (流线型)** 平滑算法。即便使用鼠标，也能通过“自动尖锐 (Auto Sharp Taper)”功能画出带有自然压感与锐利笔锋的线条。
*   **工业级赛璐璐工作流**
    致敬并改良了日本动画工业（PaintMan/Retas）的高效二值化生产流程。支持全程无抗锯齿（Aliased）作画，配合“色线吞并”与“非破坏性二值化”技术，大幅提升填色与分层效率。

### 功能详情

**专业笔刷引擎**
*   **多形态笔尖**：原生支持圆形、三角形、正方形及五角星笔尖。
*   **动态控制**：支持随机旋转 (Jitter)、随运笔方向旋转 (Smooth Rotation) 及散布 (Scatter) 效果。
*   **特殊效果**：支持空心笔刷 (Hollow) 模式，可调节空心比例并自动去除重叠部分，快速绘制线稿。
*   **像素完美**：提供“像素对齐 (Snap to Pixel)”模式，专为像素画创作设计。

**图像处理与辅助**
*   **非破坏性编辑**：内置 HSB、亮度/对比度、色彩范围（减色/分色）等实时调整工具。
*   **线稿提取**：专业的扫描件处理工具，支持去背（白底转透明）、RGB 通道线稿提取及漏色修补。
*   **智能辅助**：内置 1/2/3 点透视辅助线，笔刷可自动吸附透视方向。
*   **高清导出**：独家二次边缘柔化算法，支持将二值化作品导出为平滑的高清插画。

**文本与排版**
*   **专业排版**：支持横排与竖排文本输入，完美适配漫画嵌字需求。
*   **样式控制**：可自由调节字体（支持预览与收藏）、字号、行距及字间距。
*   **特效支持**：支持文字描边 (Stroke)，提升海报设计与标题的表现力。

**工作区**
*   **3D 参考**：内置 Steve/Alex 模型查看器，支持导入自定义 Bedrock 模型，可实时烘焙贴图与预览阴影。
*   **无限画布**：基于分块渲染 (Chunk-based Rendering) 技术，支持无限尺寸画布与无限制撤销/重做。

### 获取与体验

*   **桌面版 (推荐)**：前往 [Releases](https://github.com/MCDFsteve/MisaRin/releases) 下载最新安装包。适用于生产环境，支持多线程处理与本地文件管理。
*   **网页版**：访问 https://misarin.aimes-soft.com 可即时体验。

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
- *Keywords for developers: Flutter, CanvasKit, Pixel Art, Cel Shading, Retas, PaintMan, Color Trace (色トレス), Binary Pen (二值化ペン).*

本项目使用 **MIT License** 开源，随意下载、修改、分享与魔改。

<br>
<br>

<a id="lang-zh-tw"></a>

## 繁體中文

Misa Rin 是一款基於 Rust (WGPU) 與 Flutter 開發的高效能數位繪畫與像素創作軟體。其核心架構採用 **Rust CPU 光柵化 + WGPU 渲染管線** 的混合模式，既保證了筆刷運算的像素級精度，又實現了秒級啟動與極致流暢的互動體驗。

無論是像素畫、賽璐璐風格插畫，還是工業級二值化生產，都可以在這個統一的、無限邊界的畫布中高效完成。

> **注意**：專案仍處於早期開發階段 (Alpha)，功能尚在快速迭代中，請避免在關鍵生產環境中使用。

### 核心特性

*   **混合渲染架構**
    筆刷引擎由 Rust 在 CPU 端進行高精度光柵化，支援亞像素級抗鋸齒與完美的像素對齊；畫布合成與顯示則由 WGPU 接管，充分利用現代 GPU 效能。
*   **專為滑鼠繪圖優化**
    內建速度-壓力映射模型與 **Streamline (流線型)** 平滑演算法。即便使用滑鼠，也能透過「自動尖銳 (Auto Sharp Taper)」功能畫出帶有自然壓感與銳利筆鋒的線條。
*   **工業級賽璐璐工作流**
    致敬並改良了日本動畫工業（PaintMan/Retas）的高效二值化生產流程。支援全程無抗鋸齒（Aliased）作畫，配合「色線吞併」與「非破壞性二值化」技術，大幅提升填色與分層效率。

### 功能詳情

**專業筆刷引擎**
*   **多形態筆尖**：原生支援圓形、三角形、正方形及五角星筆尖。
*   **動態控制**：支援隨機旋轉 (Jitter)、隨運筆方向旋轉 (Smooth Rotation) 及散布 (Scatter) 效果。
*   **特殊效果**：支援空心筆刷 (Hollow) 模式，可調節空心比例並自動去除重疊部分，快速繪製線稿。
*   **像素完美**：提供「像素對齊 (Snap to Pixel)」模式，專為像素畫創作設計。

**文字與排版**
*   **專業排版**：支援橫排與直排文字輸入，完美適配漫畫嵌字需求。
*   **樣式控制**：可自由調節字體（支援預覽與收藏）、字號、行距及字間距。
*   **特效支援**：支援文字描邊 (Stroke)，提升海報設計與標題的表現力。

**影像處理與輔助**
*   **非破壞性編輯**：內建 HSB、亮度/對比度、色彩範圍（減色/分色）等即時調整工具。
*   **線稿處理**：專業的掃描件處理工具，支援去背（白底轉透明）、RGB 通道線稿提取及漏色修補。
*   **智慧輔助**：內建 1/2/3 點透視輔助線，筆刷可自動吸附透視方向。
*   **高清匯出**：獨家二次邊緣柔化演算法，支援將二值化作品匯出為平滑的高清插畫。

**工作區**
*   **3D 參考**：內建 Steve/Alex 模型檢視器，支援匯入自訂 Bedrock 模型，可即時烘焙貼圖與預覽陰影。
*   **無限畫布**：基於分塊渲染 (Chunk-based Rendering) 技術，支援無限尺寸畫布與無限制撤銷/重做。

### 取得與體驗

*   **桌面版 (推薦)**：前往 [Releases](https://github.com/MCDFsteve/MisaRin/releases) 下載最新安裝包。適用於生產環境，支援多執行緒處理與本機檔案管理。
*   **網頁版**：訪問 https://misarin.aimes-soft.com 可即時體驗。

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
- *Keywords for developers: Flutter, CanvasKit, Pixel Art, Cel Shading, Retas, PaintMan, Color Trace (色トレス), Binary Pen (二值化ペン).*

本專案使用 **MIT License** 開源，隨意下載、修改、分享與魔改。

<br>
<br>

<a id="lang-en"></a>

## English

Misa Rin is a high-performance digital painting and pixel art software built with Rust (WGPU) and Flutter. Its core architecture employs a hybrid mode of **Rust CPU Rasterization + WGPU Render Pipeline**, ensuring pixel-perfect precision for brush operations while achieving instant startup and an ultra-smooth interactive experience.

Whether it's pixel art, cel-style illustration, or industrial-grade binary production, everything can be efficiently completed on this unified, infinite canvas.

> **Note**: This project is still in early development (Alpha). Features are iterating rapidly; please avoid using it in critical production environments.

### Core Features

*   **Hybrid Rendering Architecture**
    The brush engine performs high-precision rasterization on the CPU via Rust, supporting sub-pixel anti-aliasing and perfect pixel alignment; canvas composition and display are handled by WGPU, fully utilizing modern GPU performance.
*   **Optimized for Mouse Drawing**
    Built-in speed-pressure mapping model and **Streamline** smoothing algorithm. Even with a mouse, you can draw lines with natural pressure sensitivity and sharp tips using the "Auto Sharp Taper" feature.
*   **Industrial Cel-Shading Workflow**
    Pays tribute to and improves upon the efficient binary production workflow of the Japanese animation industry (PaintMan/Retas). Supports full-process aliased drawing, combined with "Color Trace Enclosure" and "Non-destructive Binarization" technologies, significantly boosting coloring and layering efficiency.

### Feature Details

**Professional Brush Engine**
*   **Multi-shape Tips**: Natively supports circle, triangle, square, and star tips.
*   **Dynamic Control**: Supports random rotation (Jitter), rotation following stroke direction (Smooth Rotation), and Scatter effects.
*   **Special Effects**: Supports Hollow brush mode, with adjustable hollow ratio and automatic removal of overlapping parts for quick line art drawing.
*   **Pixel Perfect**: Provides "Snap to Pixel" mode, designed specifically for pixel art creation.

**Text & Typography**
*   **Professional Typesetting**: Supports horizontal and vertical text input, perfectly adapting to comic lettering needs.
*   **Style Control**: Freely adjust fonts (with preview and favorites), size, leading, and tracking.
*   **Effects Support**: Supports text stroke, enhancing the expressiveness of poster designs and titles.

**Image Processing & Helpers**
*   **Non-destructive Editing**: Built-in real-time adjustment tools like HSB, Brightness/Contrast, and Color Range (Subtractive/Separation).
*   **Line Art Extraction**: Professional scan processing tools, supporting background removal (white to transparent), RGB channel line extraction, and bleed repair.
*   **Smart Helpers**: Built-in 1/2/3-point perspective guides, with brush automatic snapping to perspective directions.
*   **HD Export**: Exclusive secondary edge-softening algorithm, supporting the export of binary artwork as smooth, high-definition illustrations.

**Workspace**
*   **3D Reference**: Built-in Steve/Alex model viewer, supports importing custom Bedrock models, with real-time texture baking and shadow preview.
*   **Infinite Canvas**: Based on Chunk-based Rendering technology, supporting infinite canvas size and unlimited undo/redo.

### Get & Try

*   **Desktop (Recommended)**: Download the latest installer from [Releases](https://github.com/MCDFsteve/MisaRin/releases). Suitable for production environments, supports multi-threaded processing and local file management.
*   **Web**: Visit https://misarin.aimes-soft.com for an instant experience.

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
- *Keywords for developers: Flutter, CanvasKit, Pixel Art, Cel Shading, Retas, PaintMan, Color Trace (色トレス), Binary Pen (二值化ペン).*

Released under the **MIT License** — feel free to download, modify, and share.

<br>
<br>

<a id="lang-ko"></a>

## 한국어

Misa Rin은 Rust(WGPU)와 Flutter로 개발된 고성능 디지털 드로잉 및 픽셀 아트 제작 소프트웨어입니다. 핵심 아키텍처는 **Rust CPU 래스터화 + WGPU 렌더 파이프라인**의 하이브리드 모드를 채택하여, 브러시 연산의 픽셀 단위 정밀도를 보장하면서도 즉각적인 시작과 극도로 부드러운 상호작용 경험을 실현했습니다.

픽셀 아트, 셀 스타일 일러스트레이션, 또는 산업용 이진화 작업까지, 이 통일된 무한 캔버스에서 효율적으로 완성할 수 있습니다.

> **주의**: 본 프로젝트는 아직 초기 개발 단계(Alpha)이며, 기능이 빠르게 반복되고 있으므로 중요한 프로덕션 환경에서의 사용은 피해주십시오.

### 핵심 기능

*   **하이브리드 렌더링 아키텍처**
    브러시 엔진은 Rust를 통해 CPU에서 고정밀 래스터화를 수행하여 서브 픽셀 앤티앨리어싱과 완벽한 픽셀 정렬을 지원하며, 캔버스 합성과 디스플레이는 WGPU가 담당하여 최신 GPU 성능을 최대한 활용합니다.
*   **마우스 드로잉 최적화**
    속도-압력 매핑 모델과 **Streamline(유선형)** 스무딩 알고리즘이 내장되어 있습니다. 마우스를 사용하더라도 "자동 샤프 테이퍼(Auto Sharp Taper)" 기능을 통해 자연스러운 필압과 날카로운 펜촉 효과를 낼 수 있습니다.
*   **산업용 셀 스타일 워크플로**
    일본 애니메이션 산업(PaintMan/Retas)의 효율적인 이진화 생산 공정을 오마주하고 개량했습니다. 전 과정 앨리어싱(Aliased) 작화를 지원하며, "색선 포섭(Color Trace Enclosure)" 및 "비파괴적 이진화" 기술과 결합하여 채색 및 레이어 작업 효율을 대폭 향상시켰습니다.

### 기능 상세

**전문 브러시 엔진**
*   **다양한 팁 형태**: 원형, 삼각형, 사각형 및 별 모양 팁을 기본 지원합니다.
*   **동적 제어**: 랜덤 회전(Jitter), 획 방향에 따른 회전(Smooth Rotation) 및 산포(Scatter) 효과를 지원합니다.
*   **특수 효과**: 중공(Hollow) 브러시 모드를 지원하여, 중공 비율 조절 및 겹친 부분 자동 제거가 가능해 빠른 선화 작업이 가능합니다.
*   **픽셀 퍼펙트**: 픽셀 아트 창작을 위해 설계된 "픽셀 정렬(Snap to Pixel)" 모드를 제공합니다.

**텍스트 & 타이포그래피**
*   **전문 조판**: 가로 및 세로 텍스트 입력을 지원하여 만화 식자 작업에 완벽하게 대응합니다.
*   **스타일 제어**: 글꼴(미리보기 및 즐겨찾기 지원), 크기, 행간 및 자간을 자유롭게 조절할 수 있습니다.
*   **효과 지원**: 텍스트 외곽선(Stroke)을 지원하여 포스터 디자인과 타이틀의 표현력을 높입니다.

**이미지 처리 & 보조**
*   **비파괴적 편집**: HSB, 밝기/대비, 색상 범위(감산/분색) 등 실시간 조정 도구가 내장되어 있습니다.
*   **선화 추출**: 전문 스캔 처리 도구로 배경 제거(흰색을 투명으로), RGB 채널 선화 추출 및 번짐 보정을 지원합니다.
*   **스마트 보조**: 1/2/3점 투시 보조선이 내장되어 있으며, 브러시가 투시 방향에 자동으로 스냅됩니다.
*   **HD 내보내기**: 독자적인 2차 가장자리 부드럽게(Edge-softening) 알고리즘으로, 이진화된 작품을 매끄러운 고화질 일러스트로 내보낼 수 있습니다.

**작업 공간**
*   **3D 참조**: Steve/Alex 모델 뷰어가 내장되어 있으며, 사용자 정의 Bedrock 모델 가져오기를 지원하고 실시간 텍스처 베이킹 및 그림자 미리보기가 가능합니다.
*   **무한 캔버스**: 청크 기반 렌더링(Chunk-based Rendering) 기술을 기반으로 무한 캔버스 크기와 무제한 실행 취소/다시 실행을 지원합니다.

### 다운로드 & 체험

*   **데스크톱(추천)**: [Releases](https://github.com/MCDFsteve/MisaRin/releases)에서 최신 설치 패키지를 다운로드하세요. 프로덕션 환경에 적합하며 멀티스레드 처리 및 로컬 파일 관리를 지원합니다.
*   **웹 버전**: https://misarin.aimes-soft.com을 방문하여 즉시 체험해 보세요.

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

Misa Rin は Rust (WGPU) と Flutter で開発された高性能なデジタルペイント／ピクセル制作ソフトです。中核となるアーキテクチャは **Rust CPU ラスタライズ + WGPU レンダリングパイプライン** のハイブリッドモードを採用し、ブラシ演算のピクセル単位の精度を保証しつつ、瞬時の起動と極めて滑らかなインタラクションを実現しました。

ピクセルアート、アニメ塗りイラスト、あるいは工業レベルの二値化制作まで、すべてを 1 つの統一された無限キャンバスで効率よく完結できます。

> **注意**：本プロジェクトはまだ初期開発段階（Alpha）であり、機能が急速に反復されています。重要なプロダクション環境での使用は避けてください。

### コア機能

*   **ハイブリッドレンダリングアーキテクチャ**
    ブラシエンジンは Rust を介して CPU 上で高精度なラスタライズを行い、サブピクセルのアンチエイリアスと完璧なピクセルアライメントをサポートします。キャンバスの合成と表示は WGPU が担当し、最新の GPU 性能を最大限に活用します。
*   **マウス描画への最適化**
    速度-筆圧マッピングモデルと **Streamline（流線型）** スムージングアルゴリズムを内蔵しています。マウスを使用しても、「自動入り抜き（Auto Sharp Taper）」機能により、自然な筆圧感と鋭いペン先を持つ線を描くことができます。
*   **工業級アニメ塗りワークフロー**
    日本のアニメーション産業（PaintMan/Retas）の効率的な二値化生産フローをオマージュし、改良しました。全工程でのアンチエイリアスなし（Aliased）作画をサポートし、「色トレス線閉鎖（Color Trace Enclosure）」や「非破壊二値化」技術と組み合わせることで、彩色とレイヤー分けの効率を大幅に向上させました。

### 機能詳細

**プロフェッショナルブラシエンジン**
*   **多形状のペン先**：円、三角、四角、星型のペン先をネイティブサポート。
*   **動的制御**：ランダム回転（Jitter）、筆の進行方向追従回転（Smooth Rotation）、散布（Scatter）効果をサポート。
*   **特殊効果**：中抜き（Hollow）ブラシモードをサポート。中抜き率の調整や、重なり部分の自動除去が可能で、線画を素早く作成できます。
*   **ピクセルパーフェクト**：ピクセルアート制作のために設計された「ピクセル吸着（Snap to Pixel）」モードを提供します。

**テキスト & タイポグラフィ**
*   **プロ向け組版**：横書きおよび縦書きのテキスト入力に対応し、漫画の写植ニーズに完全対応します。
*   **スタイル制御**：フォント（プレビューと「お気に入り」対応）、サイズ、行間、字間を自由に調整できます。
*   **エフェクト対応**：テキストの縁取り（Stroke）をサポートし、ポスターデザインやタイトルの表現力を高めます。

**画像処理 & 補助**
*   **非破壊編集**：HSB、明るさ/コントラスト、色域選択（減色/分色）などのリアルタイム調整ツールを内蔵。
*   **線画抽出**：プロ仕様のスキャン処理ツール。背景除去（白を透明に）、RGB チャンネルごとの線画抽出、塗り残し補正をサポート。
*   **スマート補助**：1/2/3 点透視補助線を内蔵し、ブラシが透視方向に自動的にスナップします。
*   **HD エクスポート**：独自の二次エッジ柔化（Edge-softening）アルゴリズムにより、二値化された作品を滑らかな高解像度イラストとして書き出せます。

**ワークスペース**
*   **3D リファレンス**：Steve/Alex モデルビューワーを内蔵。カスタム Bedrock モデルのインポートに対応し、リアルタイムのテクスチャベイクと陰影プレビューが可能です。
*   **無限キャンバス**：チャンクベースレンダリング（Chunk-based Rendering）技術に基づき、無限のキャンバスサイズと無制限の取り消し/やり直しをサポートします。

### ダウンロード & 体験

*   **デスクトップ版（推奨）**：[Releases](https://github.com/MCDFsteve/MisaRin/releases) から最新のインストーラーをダウンロードしてください。プロダクション環境に適しており、マルチスレッド処理とローカルファイル管理をサポートします。
*   **Web 版**：https://misarin.aimes-soft.com にアクセスして、すぐに体験できます。

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
