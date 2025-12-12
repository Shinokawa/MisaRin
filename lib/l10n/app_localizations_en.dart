// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get webLoadingInitializingCanvas => 'Initializing canvas…';

  @override
  String get webLoadingMayTakeTime =>
      'Loading on web may take a moment. Please wait.';

  @override
  String get closeAppTitle => 'Quit App';

  @override
  String unsavedProjectsWarning(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Detected $count unsaved projects. If you quit now, your recent changes will be lost.',
      one:
          'Detected 1 unsaved project. If you quit now, your recent changes will be lost.',
    );
    return '$_temp0';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get discardAndExit => 'Discard and Quit';

  @override
  String get homeTagline => 'Start creating here';

  @override
  String get homeNewProject => 'New Project';

  @override
  String get homeNewProjectDesc => 'Start a new idea from a blank canvas';

  @override
  String get homeOpenProject => 'Open Project';

  @override
  String get homeOpenProjectDesc => 'Load a .rin / .psd file from disk';

  @override
  String get homeRecentProjects => 'Recent';

  @override
  String get homeRecentProjectsDesc => 'Quickly restore autosaved projects';

  @override
  String get homeProjectManager => 'Project Manager';

  @override
  String get homeProjectManagerDesc =>
      'View or clean up autosaved project files in bulk';

  @override
  String get homeSettings => 'Settings';

  @override
  String get homeSettingsDesc => 'Preview personalization options coming soon';

  @override
  String get homeAbout => 'About';

  @override
  String get homeAboutDesc => 'Learn more about Misa Rin';

  @override
  String createProjectFailed(Object error) {
    return 'Failed to create project: $error';
  }

  @override
  String get openProjectDialogTitle => 'Open Project';

  @override
  String get openingProjectTitle => 'Opening project…';

  @override
  String openingProjectMessage(Object fileName) {
    return 'Loading $fileName';
  }

  @override
  String get cannotReadPsdContent => 'Unable to read PSD file contents.';

  @override
  String get cannotReadProjectFileContent =>
      'Unable to read project file contents.';

  @override
  String openedProjectInfo(Object name) {
    return 'Opened project: $name';
  }

  @override
  String openProjectFailed(Object error) {
    return 'Failed to open project: $error';
  }

  @override
  String get importImageDialogTitle => 'Import Image';

  @override
  String importedImageInfo(Object name) {
    return 'Imported image: $name';
  }

  @override
  String importImageFailed(Object error) {
    return 'Failed to import image: $error';
  }

  @override
  String get clipboardNoBitmapFound =>
      'No bitmap found in clipboard to import.';

  @override
  String get clipboardImageDefaultName => 'Clipboard Image';

  @override
  String get importedClipboardImageInfo => 'Imported clipboard image';

  @override
  String importClipboardImageFailed(Object error) {
    return 'Failed to import clipboard image: $error';
  }

  @override
  String get webPreparingCanvasTitle => 'Preparing canvas…';

  @override
  String get webPreparingCanvasMessage =>
      'Initializing on web may take a moment. Please wait.';

  @override
  String get aboutTitle => 'About Misa Rin';

  @override
  String get aboutDescription =>
      'Misa Rin is an app focused on creative drawing and project management, designed to provide creators with a smooth painting experience and reliable project archiving.';

  @override
  String get aboutAppIdLabel => 'App ID';

  @override
  String get aboutAppVersionLabel => 'Version';

  @override
  String get aboutDeveloperLabel => 'Developer';

  @override
  String get close => 'Close';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get tabletTest => 'Tablet Test';

  @override
  String get restoreDefaults => 'Restore Defaults';

  @override
  String get ok => 'OK';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => 'Japanese';

  @override
  String get languageKorean => 'Korean';

  @override
  String get languageChineseSimplified => 'Chinese (Simplified)';

  @override
  String get languageChineseTraditional => 'Chinese (Traditional)';

  @override
  String get themeModeLabel => 'Theme Mode';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get stylusPressureSettingsLabel => 'Stylus Pressure';

  @override
  String get enableStylusPressure => 'Enable stylus pressure';

  @override
  String get responseCurveLabel => 'Response curve';

  @override
  String get responseCurveDesc =>
      'Adjust how pressure transitions into stroke width.';

  @override
  String get brushSizeSliderRangeLabel => 'Brush size slider range';

  @override
  String get brushSizeSliderRangeDesc =>
      'Affects the brush size slider in the tool panel, helping you switch precision quickly.';

  @override
  String get penSliderRangeCompact => '1 - 60 px (coarse)';

  @override
  String get penSliderRangeMedium => '0.1 - 500 px (medium)';

  @override
  String get penSliderRangeFull => '0.01 - 1000 px (full)';

  @override
  String get historyLimitLabel => 'Undo/Redo limit';

  @override
  String historyLimitCurrent(Object count) {
    return 'Current limit: $count steps';
  }

  @override
  String historyLimitDesc(Object min, Object max) {
    return 'Adjust how many undo/redo steps are kept. Range $min-$max.';
  }

  @override
  String get developerOptionsLabel => 'Developer Options';

  @override
  String get performanceOverlayLabel => 'Performance overlay';

  @override
  String get performanceOverlayDesc =>
      'Shows a Flutter Performance Pulse dashboard in the corner with FPS, CPU, memory, disk, etc.';

  @override
  String get tabletInputTestTitle => 'Tablet Input Test';

  @override
  String get recentProjectsTitle => 'Recent';

  @override
  String recentProjectsLoadFailed(Object error) {
    return 'Failed to load recent projects: $error';
  }

  @override
  String get recentProjectsEmpty => 'No recent projects';

  @override
  String get openFileLocation => 'Reveal in File Manager';

  @override
  String lastOpened(Object date) {
    return 'Last opened: $date';
  }

  @override
  String canvasSize(Object width, Object height) {
    return 'Canvas size: $width x $height';
  }

  @override
  String get menuFile => 'File';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuImage => 'Image';

  @override
  String get menuLayer => 'Layer';

  @override
  String get menuSelection => 'Select';

  @override
  String get menuFilter => 'Filter';

  @override
  String get menuTool => 'Tools';

  @override
  String get menuView => 'View';

  @override
  String get menuWorkspace => 'Workspace';

  @override
  String get menuWindow => 'Window';

  @override
  String get menuAbout => 'About Misa Rin';

  @override
  String get menuPreferences => 'Preferences…';

  @override
  String get menuNewEllipsis => 'New…';

  @override
  String get menuOpenEllipsis => 'Open…';

  @override
  String get menuImportImageEllipsis => 'Import Image…';

  @override
  String get menuImportImageFromClipboard => 'Import Image from Clipboard';

  @override
  String get menuSave => 'Save';

  @override
  String get menuSaveAsEllipsis => 'Save As…';

  @override
  String get menuExportEllipsis => 'Export…';

  @override
  String get menuCloseAll => 'Close All';

  @override
  String get menuUndo => 'Undo';

  @override
  String get menuRedo => 'Redo';

  @override
  String get menuCut => 'Cut';

  @override
  String get menuCopy => 'Copy';

  @override
  String get menuPaste => 'Paste';

  @override
  String get menuImageTransform => 'Transform';

  @override
  String get menuRotate90CW => 'Rotate 90° CW';

  @override
  String get menuRotate90CCW => 'Rotate 90° CCW';

  @override
  String get menuRotate180CW => 'Rotate 180° CW';

  @override
  String get menuRotate180CCW => 'Rotate 180° CCW';

  @override
  String get menuImageSizeEllipsis => 'Image Size…';

  @override
  String get menuCanvasSizeEllipsis => 'Canvas Size…';

  @override
  String get menuNewSubmenu => 'New';

  @override
  String get menuNewLayerEllipsis => 'Layer…';

  @override
  String get menuMergeDown => 'Merge Down';

  @override
  String get menuRasterize => 'Rasterize';

  @override
  String get menuTransform => 'Transform';

  @override
  String get menuSelectAll => 'Select All';

  @override
  String get menuInvertSelection => 'Invert Selection';

  @override
  String get menuPalette => 'Palette';

  @override
  String get menuGeneratePaletteFromCanvasEllipsis =>
      'Generate palette from current canvas…';

  @override
  String get menuGenerateGradientPalette =>
      'Generate gradient palette from current colors';

  @override
  String get menuImportPaletteEllipsis => 'Import palette…';

  @override
  String get menuReferenceImage => 'Reference Images';

  @override
  String get menuCreateReferenceImage => 'Create Reference Image';

  @override
  String get menuImportReferenceImageEllipsis => 'Import Reference Image…';

  @override
  String get menuZoomIn => 'Zoom In';

  @override
  String get menuZoomOut => 'Zoom Out';

  @override
  String get menuShowGrid => 'Show Grid';

  @override
  String get menuHideGrid => 'Hide Grid';

  @override
  String get menuBlackWhite => 'Black & White';

  @override
  String get menuDisableBlackWhite => 'Disable Black & White';

  @override
  String get menuMirrorPreview => 'Mirror Preview';

  @override
  String get menuDisableMirror => 'Disable Mirror';

  @override
  String get menuShowPerspectiveGuide => 'Show Perspective Guide';

  @override
  String get menuHidePerspectiveGuide => 'Hide Perspective Guide';

  @override
  String get menuPerspectiveMode => 'Perspective Mode';

  @override
  String get menuPerspective1Point => '1-Point';

  @override
  String get menuPerspective2Point => '2-Point';

  @override
  String get menuPerspective3Point => '3-Point';

  @override
  String get menuWorkspaceDefault => 'Default';

  @override
  String get menuWorkspaceSai2 => 'SAI2';

  @override
  String get menuSwitchWorkspace => 'Switch Workspace';

  @override
  String get menuResetWorkspace => 'Reset Workspace';

  @override
  String get menuEdgeSofteningEllipsis => 'Edge Softening…';

  @override
  String get menuNarrowLinesEllipsis => 'Narrow Lines…';

  @override
  String get menuExpandFillEllipsis => 'Expand Fill…';

  @override
  String get menuGaussianBlurEllipsis => 'Gaussian Blur…';

  @override
  String get menuRemoveColorLeakEllipsis => 'Remove Color Leak…';

  @override
  String get menuHueSaturationEllipsis => 'Hue/Saturation…';

  @override
  String get menuBrightnessContrastEllipsis => 'Brightness/Contrast…';

  @override
  String get menuColorRangeEllipsis => 'Color Range…';

  @override
  String get menuBlackWhiteEllipsis => 'Black & White…';

  @override
  String get menuBinarizeEllipsis => 'Binarize…';

  @override
  String get menuInvertColors => 'Invert Colors';
}
