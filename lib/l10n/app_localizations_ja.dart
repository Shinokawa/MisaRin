// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get webLoadingInitializingCanvas => 'キャンバスを初期化しています…';

  @override
  String get webLoadingMayTakeTime => 'Web 版の読み込みには少し時間がかかります。しばらくお待ちください。';

  @override
  String get closeAppTitle => 'アプリを終了';

  @override
  String unsavedProjectsWarning(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '未保存のプロジェクトが $count 件あります。今終了すると、最新の変更が失われます。',
      one: '未保存のプロジェクトが 1 件あります。今終了すると、最新の変更が失われます。',
    );
    return '$_temp0';
  }

  @override
  String get cancel => 'キャンセル';

  @override
  String get discardAndExit => '破棄して終了';

  @override
  String get homeTagline => 'ここから制作を始めましょう';

  @override
  String get homeNewProject => '新規プロジェクト';

  @override
  String get homeNewProjectDesc => '空のキャンバスから新しいアイデアを始める';

  @override
  String get homeOpenProject => 'プロジェクトを開く';

  @override
  String get homeOpenProjectDesc => 'ディスクから .rin / .psd ファイルを読み込む';

  @override
  String get homeRecentProjects => '最近開いた';

  @override
  String get homeRecentProjectsDesc => '自動保存したプロジェクトをすばやく復元';

  @override
  String get homeProjectManager => 'プロジェクト管理';

  @override
  String get homeProjectManagerDesc => '自動保存プロジェクトをまとめて表示／整理';

  @override
  String get homeSettings => '設定';

  @override
  String get homeSettingsDesc => '近日公開のカスタマイズ項目をプレビュー';

  @override
  String get homeAbout => 'このアプリについて';

  @override
  String get homeAboutDesc => 'Misa Rin について';

  @override
  String createProjectFailed(Object error) {
    return 'プロジェクトの作成に失敗しました: $error';
  }

  @override
  String get openProjectDialogTitle => 'プロジェクトを開く';

  @override
  String get openingProjectTitle => 'プロジェクトを開いています…';

  @override
  String openingProjectMessage(Object fileName) {
    return '$fileName を読み込み中';
  }

  @override
  String get cannotReadPsdContent => 'PSD ファイルの内容を読み取れません。';

  @override
  String get cannotReadProjectFileContent => 'プロジェクトファイルの内容を読み取れません。';

  @override
  String openedProjectInfo(Object name) {
    return 'プロジェクトを開きました: $name';
  }

  @override
  String openProjectFailed(Object error) {
    return 'プロジェクトを開けませんでした: $error';
  }

  @override
  String get importImageDialogTitle => '画像をインポート';

  @override
  String importedImageInfo(Object name) {
    return '画像をインポートしました: $name';
  }

  @override
  String importImageFailed(Object error) {
    return '画像のインポートに失敗しました: $error';
  }

  @override
  String get clipboardNoBitmapFound => 'クリップボードにインポートできるビットマップが見つかりません。';

  @override
  String get clipboardImageDefaultName => 'クリップボード画像';

  @override
  String get importedClipboardImageInfo => 'クリップボード画像をインポートしました';

  @override
  String importClipboardImageFailed(Object error) {
    return 'クリップボード画像のインポートに失敗しました: $error';
  }

  @override
  String get webPreparingCanvasTitle => 'キャンバスを準備しています…';

  @override
  String get webPreparingCanvasMessage => 'Web 版の初期化には少し時間がかかります。しばらくお待ちください。';

  @override
  String get aboutTitle => 'Misa Rin について';

  @override
  String get aboutDescription =>
      'Misa Rin は、創作とプロジェクト管理に特化したアプリです。スムーズな描画体験と信頼できるプロジェクト保存機能を提供します。';

  @override
  String get aboutAppIdLabel => 'アプリ ID';

  @override
  String get aboutAppVersionLabel => 'バージョン';

  @override
  String get aboutDeveloperLabel => '開発者';

  @override
  String get close => '閉じる';

  @override
  String get settingsTitle => '設定';

  @override
  String get tabletTest => 'ペンタブテスト';

  @override
  String get restoreDefaults => '既定に戻す';

  @override
  String get ok => 'OK';

  @override
  String get themeModeLabel => 'テーマ';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get themeSystem => 'システム';

  @override
  String get stylusPressureSettingsLabel => '筆圧設定';

  @override
  String get enableStylusPressure => '筆圧を有効にする';

  @override
  String get responseCurveLabel => '応答曲線';

  @override
  String get responseCurveDesc => '圧力とストローク幅の変化の速さを調整します。';

  @override
  String get brushSizeSliderRangeLabel => 'ブラシサイズ スライダー範囲';

  @override
  String get brushSizeSliderRangeDesc =>
      'ツールパネルのブラシサイズスライダーに影響します。精度をすばやく切り替えるのに役立ちます。';

  @override
  String get penSliderRangeCompact => '1 - 60 px（粗め）';

  @override
  String get penSliderRangeMedium => '0.1 - 500 px（中）';

  @override
  String get penSliderRangeFull => '0.01 - 1000 px（全範囲）';

  @override
  String get historyLimitLabel => '取り消し/やり直しの上限';

  @override
  String historyLimitCurrent(Object count) {
    return '現在の上限: $count ステップ';
  }

  @override
  String historyLimitDesc(Object min, Object max) {
    return '取り消し/やり直し履歴の保存数を調整します（$min-$max）。';
  }

  @override
  String get developerOptionsLabel => '開発者オプション';

  @override
  String get performanceOverlayLabel => 'パフォーマンス表示';

  @override
  String get performanceOverlayDesc =>
      '画面隅に Flutter Performance Pulse ダッシュボードを表示し、FPS、CPU、メモリ、ディスクなどをリアルタイムで確認できます。';

  @override
  String get tabletInputTestTitle => 'ペンタブ入力テスト';

  @override
  String get recentProjectsTitle => '最近開いた';

  @override
  String recentProjectsLoadFailed(Object error) {
    return '最近のプロジェクトの読み込みに失敗しました: $error';
  }

  @override
  String get recentProjectsEmpty => '最近のプロジェクトはありません';

  @override
  String get openFileLocation => 'ファイルの場所を開く';

  @override
  String lastOpened(Object date) {
    return '最終オープン: $date';
  }

  @override
  String canvasSize(Object width, Object height) {
    return 'キャンバスサイズ: $width x $height';
  }

  @override
  String get menuFile => 'ファイル';

  @override
  String get menuEdit => '編集';

  @override
  String get menuImage => '画像';

  @override
  String get menuLayer => 'レイヤー';

  @override
  String get menuSelection => '選択';

  @override
  String get menuFilter => 'フィルター';

  @override
  String get menuTool => 'ツール';

  @override
  String get menuView => '表示';

  @override
  String get menuWorkspace => 'ワークスペース';

  @override
  String get menuWindow => 'ウィンドウ';

  @override
  String get menuAbout => 'Misa Rin について';

  @override
  String get menuPreferences => '環境設定…';

  @override
  String get menuNewEllipsis => '新規…';

  @override
  String get menuOpenEllipsis => '開く…';

  @override
  String get menuImportImageEllipsis => '画像をインポート…';

  @override
  String get menuImportImageFromClipboard => 'クリップボードから画像をインポート';

  @override
  String get menuSave => '保存';

  @override
  String get menuSaveAsEllipsis => '別名で保存…';

  @override
  String get menuExportEllipsis => '書き出し…';

  @override
  String get menuCloseAll => 'すべて閉じる';

  @override
  String get menuUndo => '取り消し';

  @override
  String get menuRedo => 'やり直し';

  @override
  String get menuCut => '切り取り';

  @override
  String get menuCopy => 'コピー';

  @override
  String get menuPaste => '貼り付け';

  @override
  String get menuImageTransform => '変形';

  @override
  String get menuRotate90CW => '90° 右回転';

  @override
  String get menuRotate90CCW => '90° 左回転';

  @override
  String get menuRotate180CW => '180° 右回転';

  @override
  String get menuRotate180CCW => '180° 左回転';

  @override
  String get menuImageSizeEllipsis => '画像サイズ…';

  @override
  String get menuCanvasSizeEllipsis => 'キャンバスサイズ…';

  @override
  String get menuNewSubmenu => '新規';

  @override
  String get menuNewLayerEllipsis => 'レイヤー…';

  @override
  String get menuMergeDown => '下のレイヤーに結合';

  @override
  String get menuRasterize => 'ラスタライズ';

  @override
  String get menuTransform => '変形';

  @override
  String get menuSelectAll => 'すべて選択';

  @override
  String get menuInvertSelection => '選択範囲を反転';

  @override
  String get menuPalette => 'パレット';

  @override
  String get menuGeneratePaletteFromCanvasEllipsis => '現在のキャンバスからパレットを生成…';

  @override
  String get menuGenerateGradientPalette => '現在の色からグラデーションパレットを生成';

  @override
  String get menuImportPaletteEllipsis => 'パレットをインポート…';

  @override
  String get menuReferenceImage => '参照画像';

  @override
  String get menuCreateReferenceImage => '参照画像を作成';

  @override
  String get menuImportReferenceImageEllipsis => '参照画像をインポート…';

  @override
  String get menuZoomIn => '拡大';

  @override
  String get menuZoomOut => '縮小';

  @override
  String get menuShowGrid => 'グリッドを表示';

  @override
  String get menuHideGrid => 'グリッドを非表示';

  @override
  String get menuBlackWhite => '白黒';

  @override
  String get menuDisableBlackWhite => '白黒を解除';

  @override
  String get menuMirrorPreview => 'ミラープレビュー';

  @override
  String get menuDisableMirror => 'ミラーを解除';

  @override
  String get menuShowPerspectiveGuide => '透視線を表示';

  @override
  String get menuHidePerspectiveGuide => '透視線を非表示';

  @override
  String get menuPerspectiveMode => '透視モード';

  @override
  String get menuPerspective1Point => '1 点透視';

  @override
  String get menuPerspective2Point => '2 点透視';

  @override
  String get menuPerspective3Point => '3 点透視';

  @override
  String get menuWorkspaceDefault => 'デフォルト';

  @override
  String get menuWorkspaceSai2 => 'SAI2';

  @override
  String get menuSwitchWorkspace => 'ワークスペースを切り替え';

  @override
  String get menuResetWorkspace => 'ワークスペースをリセット';

  @override
  String get menuEdgeSofteningEllipsis => 'エッジの柔化…';

  @override
  String get menuNarrowLinesEllipsis => '線を細く…';

  @override
  String get menuExpandFillEllipsis => '塗りの拡張…';

  @override
  String get menuGaussianBlurEllipsis => 'ガウスぼかし…';

  @override
  String get menuRemoveColorLeakEllipsis => '色漏れを除去…';

  @override
  String get menuHueSaturationEllipsis => '色相/彩度…';

  @override
  String get menuBrightnessContrastEllipsis => '明るさ/コントラスト…';

  @override
  String get menuColorRangeEllipsis => '色域…';

  @override
  String get menuBlackWhiteEllipsis => '白黒…';

  @override
  String get menuBinarizeEllipsis => '二値化…';

  @override
  String get menuInvertColors => '色を反転';
}
