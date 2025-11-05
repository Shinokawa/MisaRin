# Misa Rin

Misa Rin 是一款以桌面端体验为核心的 Flutter 数字绘图/像素编辑器。项目基于 Fluent UI 设计体系，结合自研的 `bitmap_canvas` 渲染内核和图层系统，为 Windows、macOS、Linux 以及 Web 提供统一的多平台绘图体验。

## 功能亮点

- **跨平台桌面体验**：借助 `window_manager` 与 Fluent UI 构建原生感窗口界面，内置菜单/快捷键逻辑在各平台保持一致。
- **自研 Bitmap 画布**：`bitmap_canvas` 模块提供逐像素绘制、图层管理、混合模式、选区与填充等基础能力，支持实时撤销/重做与光标大小反馈。
- **多种绘图工具**：当前已实现画笔、曲线笔、油漆桶、魔棒选区、图层移动、取色器、套索/多边形选区、拖动画布等工具，并配有快捷键提示与笔刷半径显示。
- **项目与历史管理**：`ProjectRepository` 负责本地文件的保存/加载，支持自动生成预览、记录最近项目、项目管理对话框以及撤销栈上限配置。
- **导出与设置**：可通过导出对话框将当前画布按照倍率输出 PNG，同时提供主题模式、取色配置、油漆桶选项等个性化设置。

## 环境要求

- Flutter SDK ≥ 3.9.2（`pubspec.yaml` 中的 `environment.sdk`）
- Dart ≥ 3.9
- 对于桌面目标，需要对应平台的 Flutter 桌面支持已启用

## 快速开始

```bash
# 安装依赖
a flutter pub get

# 运行（示例：macOS 桌面）
a flutter run -d macos

# 运行 Windows / Linux / Web 时将 `-d` 替换为对应设备 ID
```

> 首次运行桌面版本时，应用会自动最大化并载入 Fluent UI 壳层。macOS 平台会包裹 `MacosMenuShell` 以提供原生菜单支持。

## 目录结构速览

```
lib/
├── main.dart                 # 应用入口，初始化偏好与窗口
├── app/
│   ├── app.dart              # 顶层 FluentApp 及主题控制
│   ├── view/                 # 首页等页面
│   ├── dialogs/              # 导出、设置、项目管理等对话框
│   ├── project/              # 项目文档/仓库/最近文件索引
│   ├── widgets/              # 画布、工具栏、颜色面板等 UI 组件
│   ├── preferences/          # AppPreferences & 本地配置
│   └── shortcuts/, menu/, selection/ …
├── bitmap_canvas/            # 自研位图画布与控制器
└── canvas/                   # 画布层数据结构、工具、设置等
```

## 主要依赖

- `fluent_ui`：桌面风格界面与控件
- `window_manager`：原生窗口控制
- `file_picker` / `path_provider`：项目文件读写
- `flutter_localizations`：多语言支持

## 常用脚本

```bash
# 代码格式化
flutter format lib

# 静态检查
dart analyze

# 生成多平台图标
flutter pub run flutter_launcher_icons
```

## 贡献指南

1. Fork 并创建新分支（建议使用 `feature/...` 命名）。
2. 开发前运行 `flutter pub get`，提交前确保 `dart analyze` 通过。
3. 提交信息建议遵循 “type: description” 格式，方便追踪功能变更。

欢迎通过 Issue / PR 分享你的想法（新工具、性能优化、UI 提案等），也欢迎提交 Bug 报告与复现步骤。
