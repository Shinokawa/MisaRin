// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get webLoadingInitializingCanvas => '正在初始化画板…';

  @override
  String get webLoadingMayTakeTime => 'Web 端加载需要一些时间，请稍候。';

  @override
  String get closeAppTitle => '关闭应用';

  @override
  String unsavedProjectsWarning(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '检测到 $count 个未保存的项目。如果现在退出，最近的修改将会丢失。',
      one: '检测到 1 个未保存的项目。如果现在退出，最近的修改将会丢失。',
    );
    return '$_temp0';
  }

  @override
  String get cancel => '取消';

  @override
  String get discardAndExit => '丢弃并退出';

  @override
  String get homeTagline => '创作从这里开始';

  @override
  String get homeNewProject => '新建项目';

  @override
  String get homeNewProjectDesc => '从空白画布开启新的创意';

  @override
  String get homeOpenProject => '打开项目';

  @override
  String get homeOpenProjectDesc => '从磁盘加载 .rin / .psd 文件';

  @override
  String get homeRecentProjects => '最近打开';

  @override
  String get homeRecentProjectsDesc => '快速恢复自动保存的项目';

  @override
  String get homeProjectManager => '项目管理';

  @override
  String get homeProjectManagerDesc => '批量查看或清理自动保存的项目文件';

  @override
  String get homeSettings => '设置';

  @override
  String get homeSettingsDesc => '预览即将上线的个性化选项';

  @override
  String get homeAbout => '关于';

  @override
  String get homeAboutDesc => '了解项目 Misa Rin';

  @override
  String createProjectFailed(Object error) {
    return '创建项目失败：$error';
  }

  @override
  String get openProjectDialogTitle => '打开项目';

  @override
  String get openingProjectTitle => '正在打开项目…';

  @override
  String openingProjectMessage(Object fileName) {
    return '正在加载 $fileName';
  }

  @override
  String get cannotReadPsdContent => '无法读取 PSD 文件内容。';

  @override
  String get cannotReadProjectFileContent => '无法读取项目文件内容。';

  @override
  String openedProjectInfo(Object name) {
    return '已打开项目：$name';
  }

  @override
  String openProjectFailed(Object error) {
    return '打开项目失败：$error';
  }

  @override
  String get importImageDialogTitle => '导入图片';

  @override
  String importedImageInfo(Object name) {
    return '已导入图片：$name';
  }

  @override
  String importImageFailed(Object error) {
    return '导入图片失败：$error';
  }

  @override
  String get clipboardNoBitmapFound => '剪贴板中没有找到可以导入的位图。';

  @override
  String get clipboardImageDefaultName => '剪贴板图像';

  @override
  String get importedClipboardImageInfo => '已导入剪贴板图像';

  @override
  String importClipboardImageFailed(Object error) {
    return '导入剪贴板图像失败：$error';
  }

  @override
  String get webPreparingCanvasTitle => '正在准备画布…';

  @override
  String get webPreparingCanvasMessage => 'Web 端需要一些时间才能完成初始化，请稍候。';

  @override
  String get aboutTitle => '关于 Misa Rin';

  @override
  String get aboutDescription =>
      'Misa Rin 是一款专注于创意绘制与项目管理的应用，旨在为创作者提供流畅的绘图体验与可靠的项目存档能力。';

  @override
  String get aboutAppIdLabel => '应用标识';

  @override
  String get aboutAppVersionLabel => '应用版本';

  @override
  String get aboutDeveloperLabel => '开发者';

  @override
  String get close => '关闭';

  @override
  String get settingsTitle => '设置';

  @override
  String get tabletTest => '数位板测试';

  @override
  String get restoreDefaults => '恢复默认';

  @override
  String get ok => '好的';

  @override
  String get themeModeLabel => '主题模式';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get stylusPressureSettingsLabel => '数位笔压设置';

  @override
  String get enableStylusPressure => '启用数位笔笔压';

  @override
  String get responseCurveLabel => '响应曲线';

  @override
  String get responseCurveDesc => '调整压力与笔触粗细之间的过渡速度。';

  @override
  String get brushSizeSliderRangeLabel => '笔刷大小滑块区间';

  @override
  String get brushSizeSliderRangeDesc => '影响工具面板内的笔刷大小滑块，有助于在不同精度间快速切换。';

  @override
  String get penSliderRangeCompact => '1 - 60 px（粗调）';

  @override
  String get penSliderRangeMedium => '0.1 - 500 px（中档）';

  @override
  String get penSliderRangeFull => '0.01 - 1000 px（全范围）';

  @override
  String get historyLimitLabel => '撤销/恢复步数上限';

  @override
  String historyLimitCurrent(Object count) {
    return '当前上限：$count 步';
  }

  @override
  String historyLimitDesc(Object min, Object max) {
    return '调整撤销/恢复历史的保存数量，范围 $min-$max。';
  }

  @override
  String get developerOptionsLabel => '开发者选项';

  @override
  String get performanceOverlayLabel => '性能监控面板';

  @override
  String get performanceOverlayDesc =>
      '打开后会在屏幕角落显示 Flutter Performance Pulse 仪表盘，实时展示 FPS、CPU、内存与磁盘等数据。';

  @override
  String get tabletInputTestTitle => '数位板输入测试';

  @override
  String get recentProjectsTitle => '最近打开';

  @override
  String recentProjectsLoadFailed(Object error) {
    return '加载最近项目失败：$error';
  }

  @override
  String get recentProjectsEmpty => '暂无最近打开的项目';

  @override
  String get openFileLocation => '打开文件所在路径';

  @override
  String lastOpened(Object date) {
    return '最后打开：$date';
  }

  @override
  String canvasSize(Object width, Object height) {
    return '画布尺寸：$width x $height';
  }

  @override
  String get menuFile => '文件';

  @override
  String get menuEdit => '编辑';

  @override
  String get menuImage => '图像';

  @override
  String get menuLayer => '图层';

  @override
  String get menuSelection => '选择';

  @override
  String get menuFilter => '滤镜';

  @override
  String get menuTool => '工具';

  @override
  String get menuView => '视图';

  @override
  String get menuWorkspace => '工作区';

  @override
  String get menuWindow => '窗口';

  @override
  String get menuAbout => '关于 Misa Rin';

  @override
  String get menuPreferences => '偏好设置…';

  @override
  String get menuNewEllipsis => '新建…';

  @override
  String get menuOpenEllipsis => '打开…';

  @override
  String get menuImportImageEllipsis => '导入图像…';

  @override
  String get menuImportImageFromClipboard => '从剪贴板导入图像';

  @override
  String get menuSave => '保存';

  @override
  String get menuSaveAsEllipsis => '另存为…';

  @override
  String get menuExportEllipsis => '导出…';

  @override
  String get menuCloseAll => '关闭全部';

  @override
  String get menuUndo => '撤销';

  @override
  String get menuRedo => '恢复';

  @override
  String get menuCut => '剪切';

  @override
  String get menuCopy => '复制';

  @override
  String get menuPaste => '粘贴';

  @override
  String get menuImageTransform => '图像变换';

  @override
  String get menuRotate90CW => '顺时针 90 度';

  @override
  String get menuRotate90CCW => '逆时针 90 度';

  @override
  String get menuRotate180CW => '顺时针 180 度';

  @override
  String get menuRotate180CCW => '逆时针 180 度';

  @override
  String get menuImageSizeEllipsis => '图像大小…';

  @override
  String get menuCanvasSizeEllipsis => '画布大小…';

  @override
  String get menuNewSubmenu => '新建';

  @override
  String get menuNewLayerEllipsis => '图层…';

  @override
  String get menuMergeDown => '向下合并';

  @override
  String get menuRasterize => '栅格化';

  @override
  String get menuTransform => '变换';

  @override
  String get menuSelectAll => '全选';

  @override
  String get menuInvertSelection => '反选';

  @override
  String get menuPalette => '调色盘';

  @override
  String get menuGeneratePaletteFromCanvasEllipsis => '取色当前画布生成调色盘…';

  @override
  String get menuGenerateGradientPalette => '使用当前颜色生成渐变调色盘';

  @override
  String get menuImportPaletteEllipsis => '导入调色盘…';

  @override
  String get menuReferenceImage => '参考图像';

  @override
  String get menuCreateReferenceImage => '创建参考图像';

  @override
  String get menuImportReferenceImageEllipsis => '导入参考图像…';

  @override
  String get menuZoomIn => '放大';

  @override
  String get menuZoomOut => '缩小';

  @override
  String get menuShowGrid => '显示网格';

  @override
  String get menuHideGrid => '隐藏网格';

  @override
  String get menuBlackWhite => '黑白';

  @override
  String get menuDisableBlackWhite => '取消黑白';

  @override
  String get menuMirrorPreview => '镜像预览';

  @override
  String get menuDisableMirror => '取消镜像';

  @override
  String get menuShowPerspectiveGuide => '显示透视线';

  @override
  String get menuHidePerspectiveGuide => '隐藏透视线';

  @override
  String get menuPerspectiveMode => '透视模式';

  @override
  String get menuPerspective1Point => '1 点透视';

  @override
  String get menuPerspective2Point => '2 点透视';

  @override
  String get menuPerspective3Point => '3 点透视';

  @override
  String get menuWorkspaceDefault => '默认';

  @override
  String get menuWorkspaceSai2 => 'SAI2';

  @override
  String get menuSwitchWorkspace => '切换工作区';

  @override
  String get menuResetWorkspace => '复位工作区';

  @override
  String get menuEdgeSofteningEllipsis => '边缘柔化…';

  @override
  String get menuNarrowLinesEllipsis => '线条收窄…';

  @override
  String get menuExpandFillEllipsis => '填色拉伸…';

  @override
  String get menuGaussianBlurEllipsis => '高斯模糊…';

  @override
  String get menuRemoveColorLeakEllipsis => '去除漏色…';

  @override
  String get menuHueSaturationEllipsis => '色相/饱和度…';

  @override
  String get menuBrightnessContrastEllipsis => '亮度/对比度…';

  @override
  String get menuColorRangeEllipsis => '色彩范围…';

  @override
  String get menuBlackWhiteEllipsis => '黑白…';

  @override
  String get menuBinarizeEllipsis => '二值化…';

  @override
  String get menuInvertColors => '颜色反转';
}

/// The translations for Chinese, as used in China (`zh_CN`).
class AppLocalizationsZhCn extends AppLocalizationsZh {
  AppLocalizationsZhCn() : super('zh_CN');

  @override
  String get webLoadingInitializingCanvas => '正在初始化画板…';

  @override
  String get webLoadingMayTakeTime => 'Web 端加载需要一些时间，请稍候。';

  @override
  String get closeAppTitle => '关闭应用';

  @override
  String unsavedProjectsWarning(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '检测到 $count 个未保存的项目。如果现在退出，最近的修改将会丢失。',
      one: '检测到 1 个未保存的项目。如果现在退出，最近的修改将会丢失。',
    );
    return '$_temp0';
  }

  @override
  String get cancel => '取消';

  @override
  String get discardAndExit => '丢弃并退出';

  @override
  String get homeTagline => '创作从这里开始';

  @override
  String get homeNewProject => '新建项目';

  @override
  String get homeNewProjectDesc => '从空白画布开启新的创意';

  @override
  String get homeOpenProject => '打开项目';

  @override
  String get homeOpenProjectDesc => '从磁盘加载 .rin / .psd 文件';

  @override
  String get homeRecentProjects => '最近打开';

  @override
  String get homeRecentProjectsDesc => '快速恢复自动保存的项目';

  @override
  String get homeProjectManager => '项目管理';

  @override
  String get homeProjectManagerDesc => '批量查看或清理自动保存的项目文件';

  @override
  String get homeSettings => '设置';

  @override
  String get homeSettingsDesc => '预览即将上线的个性化选项';

  @override
  String get homeAbout => '关于';

  @override
  String get homeAboutDesc => '了解项目 Misa Rin';

  @override
  String createProjectFailed(Object error) {
    return '创建项目失败：$error';
  }

  @override
  String get openProjectDialogTitle => '打开项目';

  @override
  String get openingProjectTitle => '正在打开项目…';

  @override
  String openingProjectMessage(Object fileName) {
    return '正在加载 $fileName';
  }

  @override
  String get cannotReadPsdContent => '无法读取 PSD 文件内容。';

  @override
  String get cannotReadProjectFileContent => '无法读取项目文件内容。';

  @override
  String openedProjectInfo(Object name) {
    return '已打开项目：$name';
  }

  @override
  String openProjectFailed(Object error) {
    return '打开项目失败：$error';
  }

  @override
  String get importImageDialogTitle => '导入图片';

  @override
  String importedImageInfo(Object name) {
    return '已导入图片：$name';
  }

  @override
  String importImageFailed(Object error) {
    return '导入图片失败：$error';
  }

  @override
  String get clipboardNoBitmapFound => '剪贴板中没有找到可以导入的位图。';

  @override
  String get clipboardImageDefaultName => '剪贴板图像';

  @override
  String get importedClipboardImageInfo => '已导入剪贴板图像';

  @override
  String importClipboardImageFailed(Object error) {
    return '导入剪贴板图像失败：$error';
  }

  @override
  String get webPreparingCanvasTitle => '正在准备画布…';

  @override
  String get webPreparingCanvasMessage => 'Web 端需要一些时间才能完成初始化，请稍候。';

  @override
  String get aboutTitle => '关于 Misa Rin';

  @override
  String get aboutDescription =>
      'Misa Rin 是一款专注于创意绘制与项目管理的应用，旨在为创作者提供流畅的绘图体验与可靠的项目存档能力。';

  @override
  String get aboutAppIdLabel => '应用标识';

  @override
  String get aboutAppVersionLabel => '应用版本';

  @override
  String get aboutDeveloperLabel => '开发者';

  @override
  String get close => '关闭';

  @override
  String get settingsTitle => '设置';

  @override
  String get tabletTest => '数位板测试';

  @override
  String get restoreDefaults => '恢复默认';

  @override
  String get ok => '好的';

  @override
  String get themeModeLabel => '主题模式';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get stylusPressureSettingsLabel => '数位笔压设置';

  @override
  String get enableStylusPressure => '启用数位笔笔压';

  @override
  String get responseCurveLabel => '响应曲线';

  @override
  String get responseCurveDesc => '调整压力与笔触粗细之间的过渡速度。';

  @override
  String get brushSizeSliderRangeLabel => '笔刷大小滑块区间';

  @override
  String get brushSizeSliderRangeDesc => '影响工具面板内的笔刷大小滑块，有助于在不同精度间快速切换。';

  @override
  String get penSliderRangeCompact => '1 - 60 px（粗调）';

  @override
  String get penSliderRangeMedium => '0.1 - 500 px（中档）';

  @override
  String get penSliderRangeFull => '0.01 - 1000 px（全范围）';

  @override
  String get historyLimitLabel => '撤销/恢复步数上限';

  @override
  String historyLimitCurrent(Object count) {
    return '当前上限：$count 步';
  }

  @override
  String historyLimitDesc(Object min, Object max) {
    return '调整撤销/恢复历史的保存数量，范围 $min-$max。';
  }

  @override
  String get developerOptionsLabel => '开发者选项';

  @override
  String get performanceOverlayLabel => '性能监控面板';

  @override
  String get performanceOverlayDesc =>
      '打开后会在屏幕角落显示 Flutter Performance Pulse 仪表盘，实时展示 FPS、CPU、内存与磁盘等数据。';

  @override
  String get tabletInputTestTitle => '数位板输入测试';

  @override
  String get recentProjectsTitle => '最近打开';

  @override
  String recentProjectsLoadFailed(Object error) {
    return '加载最近项目失败：$error';
  }

  @override
  String get recentProjectsEmpty => '暂无最近打开的项目';

  @override
  String get openFileLocation => '打开文件所在路径';

  @override
  String lastOpened(Object date) {
    return '最后打开：$date';
  }

  @override
  String canvasSize(Object width, Object height) {
    return '画布尺寸：$width x $height';
  }

  @override
  String get menuFile => '文件';

  @override
  String get menuEdit => '编辑';

  @override
  String get menuImage => '图像';

  @override
  String get menuLayer => '图层';

  @override
  String get menuSelection => '选择';

  @override
  String get menuFilter => '滤镜';

  @override
  String get menuTool => '工具';

  @override
  String get menuView => '视图';

  @override
  String get menuWorkspace => '工作区';

  @override
  String get menuWindow => '窗口';

  @override
  String get menuAbout => '关于 Misa Rin';

  @override
  String get menuPreferences => '偏好设置…';

  @override
  String get menuNewEllipsis => '新建…';

  @override
  String get menuOpenEllipsis => '打开…';

  @override
  String get menuImportImageEllipsis => '导入图像…';

  @override
  String get menuImportImageFromClipboard => '从剪贴板导入图像';

  @override
  String get menuSave => '保存';

  @override
  String get menuSaveAsEllipsis => '另存为…';

  @override
  String get menuExportEllipsis => '导出…';

  @override
  String get menuCloseAll => '关闭全部';

  @override
  String get menuUndo => '撤销';

  @override
  String get menuRedo => '恢复';

  @override
  String get menuCut => '剪切';

  @override
  String get menuCopy => '复制';

  @override
  String get menuPaste => '粘贴';

  @override
  String get menuImageTransform => '图像变换';

  @override
  String get menuRotate90CW => '顺时针 90 度';

  @override
  String get menuRotate90CCW => '逆时针 90 度';

  @override
  String get menuRotate180CW => '顺时针 180 度';

  @override
  String get menuRotate180CCW => '逆时针 180 度';

  @override
  String get menuImageSizeEllipsis => '图像大小…';

  @override
  String get menuCanvasSizeEllipsis => '画布大小…';

  @override
  String get menuNewSubmenu => '新建';

  @override
  String get menuNewLayerEllipsis => '图层…';

  @override
  String get menuMergeDown => '向下合并';

  @override
  String get menuRasterize => '栅格化';

  @override
  String get menuTransform => '变换';

  @override
  String get menuSelectAll => '全选';

  @override
  String get menuInvertSelection => '反选';

  @override
  String get menuPalette => '调色盘';

  @override
  String get menuGeneratePaletteFromCanvasEllipsis => '取色当前画布生成调色盘…';

  @override
  String get menuGenerateGradientPalette => '使用当前颜色生成渐变调色盘';

  @override
  String get menuImportPaletteEllipsis => '导入调色盘…';

  @override
  String get menuReferenceImage => '参考图像';

  @override
  String get menuCreateReferenceImage => '创建参考图像';

  @override
  String get menuImportReferenceImageEllipsis => '导入参考图像…';

  @override
  String get menuZoomIn => '放大';

  @override
  String get menuZoomOut => '缩小';

  @override
  String get menuShowGrid => '显示网格';

  @override
  String get menuHideGrid => '隐藏网格';

  @override
  String get menuBlackWhite => '黑白';

  @override
  String get menuDisableBlackWhite => '取消黑白';

  @override
  String get menuMirrorPreview => '镜像预览';

  @override
  String get menuDisableMirror => '取消镜像';

  @override
  String get menuShowPerspectiveGuide => '显示透视线';

  @override
  String get menuHidePerspectiveGuide => '隐藏透视线';

  @override
  String get menuPerspectiveMode => '透视模式';

  @override
  String get menuPerspective1Point => '1 点透视';

  @override
  String get menuPerspective2Point => '2 点透视';

  @override
  String get menuPerspective3Point => '3 点透视';

  @override
  String get menuWorkspaceDefault => '默认';

  @override
  String get menuWorkspaceSai2 => 'SAI2';

  @override
  String get menuSwitchWorkspace => '切换工作区';

  @override
  String get menuResetWorkspace => '复位工作区';

  @override
  String get menuEdgeSofteningEllipsis => '边缘柔化…';

  @override
  String get menuNarrowLinesEllipsis => '线条收窄…';

  @override
  String get menuExpandFillEllipsis => '填色拉伸…';

  @override
  String get menuGaussianBlurEllipsis => '高斯模糊…';

  @override
  String get menuRemoveColorLeakEllipsis => '去除漏色…';

  @override
  String get menuHueSaturationEllipsis => '色相/饱和度…';

  @override
  String get menuBrightnessContrastEllipsis => '亮度/对比度…';

  @override
  String get menuColorRangeEllipsis => '色彩范围…';

  @override
  String get menuBlackWhiteEllipsis => '黑白…';

  @override
  String get menuBinarizeEllipsis => '二值化…';

  @override
  String get menuInvertColors => '颜色反转';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get webLoadingInitializingCanvas => '正在初始化畫板…';

  @override
  String get webLoadingMayTakeTime => 'Web 端載入需要一些時間，請稍候。';

  @override
  String get closeAppTitle => '關閉應用';

  @override
  String unsavedProjectsWarning(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '偵測到 $count 個未儲存的專案。如果現在退出，最近的修改將會遺失。',
      one: '偵測到 1 個未儲存的專案。如果現在退出，最近的修改將會遺失。',
    );
    return '$_temp0';
  }

  @override
  String get cancel => '取消';

  @override
  String get discardAndExit => '捨棄並退出';

  @override
  String get homeTagline => '創作從這裡開始';

  @override
  String get homeNewProject => '新建專案';

  @override
  String get homeNewProjectDesc => '從空白畫布開啟新的創意';

  @override
  String get homeOpenProject => '開啟專案';

  @override
  String get homeOpenProjectDesc => '從磁碟載入 .rin / .psd 檔案';

  @override
  String get homeRecentProjects => '最近開啟';

  @override
  String get homeRecentProjectsDesc => '快速恢復自動儲存的專案';

  @override
  String get homeProjectManager => '專案管理';

  @override
  String get homeProjectManagerDesc => '批次檢視或清理自動儲存的專案檔案';

  @override
  String get homeSettings => '設定';

  @override
  String get homeSettingsDesc => '預覽即將上線的個人化選項';

  @override
  String get homeAbout => '關於';

  @override
  String get homeAboutDesc => '了解專案 Misa Rin';

  @override
  String createProjectFailed(Object error) {
    return '建立專案失敗：$error';
  }

  @override
  String get openProjectDialogTitle => '開啟專案';

  @override
  String get openingProjectTitle => '正在開啟專案…';

  @override
  String openingProjectMessage(Object fileName) {
    return '正在載入 $fileName';
  }

  @override
  String get cannotReadPsdContent => '無法讀取 PSD 檔案內容。';

  @override
  String get cannotReadProjectFileContent => '無法讀取專案檔案內容。';

  @override
  String openedProjectInfo(Object name) {
    return '已開啟專案：$name';
  }

  @override
  String openProjectFailed(Object error) {
    return '開啟專案失敗：$error';
  }

  @override
  String get importImageDialogTitle => '匯入圖片';

  @override
  String importedImageInfo(Object name) {
    return '已匯入圖片：$name';
  }

  @override
  String importImageFailed(Object error) {
    return '匯入圖片失敗：$error';
  }

  @override
  String get clipboardNoBitmapFound => '剪貼簿中沒有找到可以匯入的位圖。';

  @override
  String get clipboardImageDefaultName => '剪貼簿影像';

  @override
  String get importedClipboardImageInfo => '已匯入剪貼簿影像';

  @override
  String importClipboardImageFailed(Object error) {
    return '匯入剪貼簿影像失敗：$error';
  }

  @override
  String get webPreparingCanvasTitle => '正在準備畫布…';

  @override
  String get webPreparingCanvasMessage => 'Web 端需要一些時間才能完成初始化，請稍候。';

  @override
  String get aboutTitle => '關於 Misa Rin';

  @override
  String get aboutDescription =>
      'Misa Rin 是一款專注於創意繪製與專案管理的應用，旨在為創作者提供流暢的繪圖體驗與可靠的專案存檔能力。';

  @override
  String get aboutAppIdLabel => '應用識別';

  @override
  String get aboutAppVersionLabel => '應用版本';

  @override
  String get aboutDeveloperLabel => '開發者';

  @override
  String get close => '關閉';

  @override
  String get settingsTitle => '設定';

  @override
  String get tabletTest => '數位板測試';

  @override
  String get restoreDefaults => '恢復預設';

  @override
  String get ok => '好的';

  @override
  String get themeModeLabel => '主題模式';

  @override
  String get themeLight => '淺色';

  @override
  String get themeDark => '深色';

  @override
  String get themeSystem => '跟隨系統';

  @override
  String get stylusPressureSettingsLabel => '數位筆壓設定';

  @override
  String get enableStylusPressure => '啟用數位筆筆壓';

  @override
  String get responseCurveLabel => '回應曲線';

  @override
  String get responseCurveDesc => '調整壓力與筆觸粗細之間的過渡速度。';

  @override
  String get brushSizeSliderRangeLabel => '筆刷大小滑桿區間';

  @override
  String get brushSizeSliderRangeDesc => '影響工具面板內的筆刷大小滑桿，有助於在不同精度間快速切換。';

  @override
  String get penSliderRangeCompact => '1 - 60 px（粗調）';

  @override
  String get penSliderRangeMedium => '0.1 - 500 px（中檔）';

  @override
  String get penSliderRangeFull => '0.01 - 1000 px（全範圍）';

  @override
  String get historyLimitLabel => '復原/重做步數上限';

  @override
  String historyLimitCurrent(Object count) {
    return '目前上限：$count 步';
  }

  @override
  String historyLimitDesc(Object min, Object max) {
    return '調整復原/重做歷史的儲存數量，範圍 $min-$max。';
  }

  @override
  String get developerOptionsLabel => '開發者選項';

  @override
  String get performanceOverlayLabel => '效能監控面板';

  @override
  String get performanceOverlayDesc =>
      '開啟後會在螢幕角落顯示 Flutter Performance Pulse 儀表板，即時展示 FPS、CPU、記憶體與磁碟等資料。';

  @override
  String get tabletInputTestTitle => '數位板輸入測試';

  @override
  String get recentProjectsTitle => '最近開啟';

  @override
  String recentProjectsLoadFailed(Object error) {
    return '載入最近專案失敗：$error';
  }

  @override
  String get recentProjectsEmpty => '暫無最近開啟的專案';

  @override
  String get openFileLocation => '開啟檔案所在路徑';

  @override
  String lastOpened(Object date) {
    return '最後開啟：$date';
  }

  @override
  String canvasSize(Object width, Object height) {
    return '畫布尺寸：$width x $height';
  }

  @override
  String get menuFile => '檔案';

  @override
  String get menuEdit => '編輯';

  @override
  String get menuImage => '影像';

  @override
  String get menuLayer => '圖層';

  @override
  String get menuSelection => '選取';

  @override
  String get menuFilter => '濾鏡';

  @override
  String get menuTool => '工具';

  @override
  String get menuView => '檢視';

  @override
  String get menuWorkspace => '工作區';

  @override
  String get menuWindow => '視窗';

  @override
  String get menuAbout => '關於 Misa Rin';

  @override
  String get menuPreferences => '偏好設定…';

  @override
  String get menuNewEllipsis => '新建…';

  @override
  String get menuOpenEllipsis => '開啟…';

  @override
  String get menuImportImageEllipsis => '匯入影像…';

  @override
  String get menuImportImageFromClipboard => '從剪貼簿匯入影像';

  @override
  String get menuSave => '儲存';

  @override
  String get menuSaveAsEllipsis => '另存為…';

  @override
  String get menuExportEllipsis => '匯出…';

  @override
  String get menuCloseAll => '關閉全部';

  @override
  String get menuUndo => '復原';

  @override
  String get menuRedo => '重做';

  @override
  String get menuCut => '剪下';

  @override
  String get menuCopy => '複製';

  @override
  String get menuPaste => '貼上';

  @override
  String get menuImageTransform => '影像變換';

  @override
  String get menuRotate90CW => '順時針 90 度';

  @override
  String get menuRotate90CCW => '逆時針 90 度';

  @override
  String get menuRotate180CW => '順時針 180 度';

  @override
  String get menuRotate180CCW => '逆時針 180 度';

  @override
  String get menuImageSizeEllipsis => '影像大小…';

  @override
  String get menuCanvasSizeEllipsis => '畫布大小…';

  @override
  String get menuNewSubmenu => '新建';

  @override
  String get menuNewLayerEllipsis => '圖層…';

  @override
  String get menuMergeDown => '向下合併';

  @override
  String get menuRasterize => '柵格化';

  @override
  String get menuTransform => '變換';

  @override
  String get menuSelectAll => '全選';

  @override
  String get menuInvertSelection => '反選';

  @override
  String get menuPalette => '調色盤';

  @override
  String get menuGeneratePaletteFromCanvasEllipsis => '取色目前畫布生成調色盤…';

  @override
  String get menuGenerateGradientPalette => '使用目前顏色生成漸層調色盤';

  @override
  String get menuImportPaletteEllipsis => '匯入調色盤…';

  @override
  String get menuReferenceImage => '參考影像';

  @override
  String get menuCreateReferenceImage => '建立參考影像';

  @override
  String get menuImportReferenceImageEllipsis => '匯入參考影像…';

  @override
  String get menuZoomIn => '放大';

  @override
  String get menuZoomOut => '縮小';

  @override
  String get menuShowGrid => '顯示網格';

  @override
  String get menuHideGrid => '隱藏網格';

  @override
  String get menuBlackWhite => '黑白';

  @override
  String get menuDisableBlackWhite => '取消黑白';

  @override
  String get menuMirrorPreview => '鏡像預覽';

  @override
  String get menuDisableMirror => '取消鏡像';

  @override
  String get menuShowPerspectiveGuide => '顯示透視線';

  @override
  String get menuHidePerspectiveGuide => '隱藏透視線';

  @override
  String get menuPerspectiveMode => '透視模式';

  @override
  String get menuPerspective1Point => '1 點透視';

  @override
  String get menuPerspective2Point => '2 點透視';

  @override
  String get menuPerspective3Point => '3 點透視';

  @override
  String get menuWorkspaceDefault => '預設';

  @override
  String get menuWorkspaceSai2 => 'SAI2';

  @override
  String get menuSwitchWorkspace => '切換工作區';

  @override
  String get menuResetWorkspace => '重置工作區';

  @override
  String get menuEdgeSofteningEllipsis => '邊緣柔化…';

  @override
  String get menuNarrowLinesEllipsis => '線條收窣…';

  @override
  String get menuExpandFillEllipsis => '填色拉伸…';

  @override
  String get menuGaussianBlurEllipsis => '高斯模糊…';

  @override
  String get menuRemoveColorLeakEllipsis => '去除漏色…';

  @override
  String get menuHueSaturationEllipsis => '色相/飽和度…';

  @override
  String get menuBrightnessContrastEllipsis => '亮度/對比度…';

  @override
  String get menuColorRangeEllipsis => '色彩範圍…';

  @override
  String get menuBlackWhiteEllipsis => '黑白…';

  @override
  String get menuBinarizeEllipsis => '二值化…';

  @override
  String get menuInvertColors => '顏色反轉';
}
