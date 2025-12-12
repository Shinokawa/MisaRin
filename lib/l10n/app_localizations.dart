import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
    Locale('zh', 'CN'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @webLoadingInitializingCanvas.
  ///
  /// In en, this message translates to:
  /// **'Initializing canvas…'**
  String get webLoadingInitializingCanvas;

  /// No description provided for @webLoadingMayTakeTime.
  ///
  /// In en, this message translates to:
  /// **'Loading on web may take a moment. Please wait.'**
  String get webLoadingMayTakeTime;

  /// No description provided for @closeAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Quit App'**
  String get closeAppTitle;

  /// No description provided for @unsavedProjectsWarning.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Detected 1 unsaved project. If you quit now, your recent changes will be lost.} other{Detected {count} unsaved projects. If you quit now, your recent changes will be lost.}}'**
  String unsavedProjectsWarning(num count);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @discardAndExit.
  ///
  /// In en, this message translates to:
  /// **'Discard and Quit'**
  String get discardAndExit;

  /// No description provided for @homeTagline.
  ///
  /// In en, this message translates to:
  /// **'Start creating here'**
  String get homeTagline;

  /// No description provided for @homeNewProject.
  ///
  /// In en, this message translates to:
  /// **'New Project'**
  String get homeNewProject;

  /// No description provided for @homeNewProjectDesc.
  ///
  /// In en, this message translates to:
  /// **'Start a new idea from a blank canvas'**
  String get homeNewProjectDesc;

  /// No description provided for @homeOpenProject.
  ///
  /// In en, this message translates to:
  /// **'Open Project'**
  String get homeOpenProject;

  /// No description provided for @homeOpenProjectDesc.
  ///
  /// In en, this message translates to:
  /// **'Load a .rin / .psd file from disk'**
  String get homeOpenProjectDesc;

  /// No description provided for @homeRecentProjects.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get homeRecentProjects;

  /// No description provided for @homeRecentProjectsDesc.
  ///
  /// In en, this message translates to:
  /// **'Quickly restore autosaved projects'**
  String get homeRecentProjectsDesc;

  /// No description provided for @homeProjectManager.
  ///
  /// In en, this message translates to:
  /// **'Project Manager'**
  String get homeProjectManager;

  /// No description provided for @homeProjectManagerDesc.
  ///
  /// In en, this message translates to:
  /// **'View or clean up autosaved project files in bulk'**
  String get homeProjectManagerDesc;

  /// No description provided for @homeSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettings;

  /// No description provided for @homeSettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Preview personalization options coming soon'**
  String get homeSettingsDesc;

  /// No description provided for @homeAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get homeAbout;

  /// No description provided for @homeAboutDesc.
  ///
  /// In en, this message translates to:
  /// **'Learn more about Misa Rin'**
  String get homeAboutDesc;

  /// No description provided for @createProjectFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create project: {error}'**
  String createProjectFailed(Object error);

  /// No description provided for @openProjectDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Project'**
  String get openProjectDialogTitle;

  /// No description provided for @openingProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Opening project…'**
  String get openingProjectTitle;

  /// No description provided for @openingProjectMessage.
  ///
  /// In en, this message translates to:
  /// **'Loading {fileName}'**
  String openingProjectMessage(Object fileName);

  /// No description provided for @cannotReadPsdContent.
  ///
  /// In en, this message translates to:
  /// **'Unable to read PSD file contents.'**
  String get cannotReadPsdContent;

  /// No description provided for @cannotReadProjectFileContent.
  ///
  /// In en, this message translates to:
  /// **'Unable to read project file contents.'**
  String get cannotReadProjectFileContent;

  /// No description provided for @openedProjectInfo.
  ///
  /// In en, this message translates to:
  /// **'Opened project: {name}'**
  String openedProjectInfo(Object name);

  /// No description provided for @openProjectFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open project: {error}'**
  String openProjectFailed(Object error);

  /// No description provided for @importImageDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Image'**
  String get importImageDialogTitle;

  /// No description provided for @importedImageInfo.
  ///
  /// In en, this message translates to:
  /// **'Imported image: {name}'**
  String importedImageInfo(Object name);

  /// No description provided for @importImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to import image: {error}'**
  String importImageFailed(Object error);

  /// No description provided for @clipboardNoBitmapFound.
  ///
  /// In en, this message translates to:
  /// **'No bitmap found in clipboard to import.'**
  String get clipboardNoBitmapFound;

  /// No description provided for @clipboardImageDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Clipboard Image'**
  String get clipboardImageDefaultName;

  /// No description provided for @importedClipboardImageInfo.
  ///
  /// In en, this message translates to:
  /// **'Imported clipboard image'**
  String get importedClipboardImageInfo;

  /// No description provided for @importClipboardImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to import clipboard image: {error}'**
  String importClipboardImageFailed(Object error);

  /// No description provided for @webPreparingCanvasTitle.
  ///
  /// In en, this message translates to:
  /// **'Preparing canvas…'**
  String get webPreparingCanvasTitle;

  /// No description provided for @webPreparingCanvasMessage.
  ///
  /// In en, this message translates to:
  /// **'Initializing on web may take a moment. Please wait.'**
  String get webPreparingCanvasMessage;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Misa Rin'**
  String get aboutTitle;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Misa Rin is an app focused on creative drawing and project management, designed to provide creators with a smooth painting experience and reliable project archiving.'**
  String get aboutDescription;

  /// No description provided for @aboutAppIdLabel.
  ///
  /// In en, this message translates to:
  /// **'App ID'**
  String get aboutAppIdLabel;

  /// No description provided for @aboutAppVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutAppVersionLabel;

  /// No description provided for @aboutDeveloperLabel.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get aboutDeveloperLabel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @tabletTest.
  ///
  /// In en, this message translates to:
  /// **'Tablet Test'**
  String get tabletTest;

  /// No description provided for @restoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore Defaults'**
  String get restoreDefaults;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageJapanese;

  /// No description provided for @languageKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get languageKorean;

  /// No description provided for @languageChineseSimplified.
  ///
  /// In en, this message translates to:
  /// **'Chinese (Simplified)'**
  String get languageChineseSimplified;

  /// No description provided for @languageChineseTraditional.
  ///
  /// In en, this message translates to:
  /// **'Chinese (Traditional)'**
  String get languageChineseTraditional;

  /// No description provided for @themeModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get themeModeLabel;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @stylusPressureSettingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Stylus Pressure'**
  String get stylusPressureSettingsLabel;

  /// No description provided for @enableStylusPressure.
  ///
  /// In en, this message translates to:
  /// **'Enable stylus pressure'**
  String get enableStylusPressure;

  /// No description provided for @responseCurveLabel.
  ///
  /// In en, this message translates to:
  /// **'Response curve'**
  String get responseCurveLabel;

  /// No description provided for @responseCurveDesc.
  ///
  /// In en, this message translates to:
  /// **'Adjust how pressure transitions into stroke width.'**
  String get responseCurveDesc;

  /// No description provided for @brushSizeSliderRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Brush size slider range'**
  String get brushSizeSliderRangeLabel;

  /// No description provided for @brushSizeSliderRangeDesc.
  ///
  /// In en, this message translates to:
  /// **'Affects the brush size slider in the tool panel, helping you switch precision quickly.'**
  String get brushSizeSliderRangeDesc;

  /// No description provided for @penSliderRangeCompact.
  ///
  /// In en, this message translates to:
  /// **'1 - 60 px (coarse)'**
  String get penSliderRangeCompact;

  /// No description provided for @penSliderRangeMedium.
  ///
  /// In en, this message translates to:
  /// **'0.1 - 500 px (medium)'**
  String get penSliderRangeMedium;

  /// No description provided for @penSliderRangeFull.
  ///
  /// In en, this message translates to:
  /// **'0.01 - 1000 px (full)'**
  String get penSliderRangeFull;

  /// No description provided for @historyLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Undo/Redo limit'**
  String get historyLimitLabel;

  /// No description provided for @historyLimitCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current limit: {count} steps'**
  String historyLimitCurrent(Object count);

  /// No description provided for @historyLimitDesc.
  ///
  /// In en, this message translates to:
  /// **'Adjust how many undo/redo steps are kept. Range {min}-{max}.'**
  String historyLimitDesc(Object min, Object max);

  /// No description provided for @developerOptionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Developer Options'**
  String get developerOptionsLabel;

  /// No description provided for @performanceOverlayLabel.
  ///
  /// In en, this message translates to:
  /// **'Performance overlay'**
  String get performanceOverlayLabel;

  /// No description provided for @performanceOverlayDesc.
  ///
  /// In en, this message translates to:
  /// **'Shows a Flutter Performance Pulse dashboard in the corner with FPS, CPU, memory, disk, etc.'**
  String get performanceOverlayDesc;

  /// No description provided for @tabletInputTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Tablet Input Test'**
  String get tabletInputTestTitle;

  /// No description provided for @recentProjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recentProjectsTitle;

  /// No description provided for @recentProjectsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load recent projects: {error}'**
  String recentProjectsLoadFailed(Object error);

  /// No description provided for @recentProjectsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recent projects'**
  String get recentProjectsEmpty;

  /// No description provided for @openFileLocation.
  ///
  /// In en, this message translates to:
  /// **'Reveal in File Manager'**
  String get openFileLocation;

  /// No description provided for @lastOpened.
  ///
  /// In en, this message translates to:
  /// **'Last opened: {date}'**
  String lastOpened(Object date);

  /// No description provided for @canvasSize.
  ///
  /// In en, this message translates to:
  /// **'Canvas size: {width} x {height}'**
  String canvasSize(Object width, Object height);

  /// No description provided for @menuFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get menuFile;

  /// No description provided for @menuEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get menuEdit;

  /// No description provided for @menuImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get menuImage;

  /// No description provided for @menuLayer.
  ///
  /// In en, this message translates to:
  /// **'Layer'**
  String get menuLayer;

  /// No description provided for @menuSelection.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get menuSelection;

  /// No description provided for @menuFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get menuFilter;

  /// No description provided for @menuTool.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get menuTool;

  /// No description provided for @menuView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get menuView;

  /// No description provided for @menuWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get menuWorkspace;

  /// No description provided for @menuWindow.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get menuWindow;

  /// No description provided for @menuAbout.
  ///
  /// In en, this message translates to:
  /// **'About Misa Rin'**
  String get menuAbout;

  /// No description provided for @menuPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences…'**
  String get menuPreferences;

  /// No description provided for @menuNewEllipsis.
  ///
  /// In en, this message translates to:
  /// **'New…'**
  String get menuNewEllipsis;

  /// No description provided for @menuOpenEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Open…'**
  String get menuOpenEllipsis;

  /// No description provided for @menuImportImageEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Import Image…'**
  String get menuImportImageEllipsis;

  /// No description provided for @menuImportImageFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Import Image from Clipboard'**
  String get menuImportImageFromClipboard;

  /// No description provided for @menuSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get menuSave;

  /// No description provided for @menuSaveAsEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Save As…'**
  String get menuSaveAsEllipsis;

  /// No description provided for @menuExportEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Export…'**
  String get menuExportEllipsis;

  /// No description provided for @menuCloseAll.
  ///
  /// In en, this message translates to:
  /// **'Close All'**
  String get menuCloseAll;

  /// No description provided for @menuUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get menuUndo;

  /// No description provided for @menuRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get menuRedo;

  /// No description provided for @menuCut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get menuCut;

  /// No description provided for @menuCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get menuCopy;

  /// No description provided for @menuPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get menuPaste;

  /// No description provided for @menuImageTransform.
  ///
  /// In en, this message translates to:
  /// **'Transform'**
  String get menuImageTransform;

  /// No description provided for @menuRotate90CW.
  ///
  /// In en, this message translates to:
  /// **'Rotate 90° CW'**
  String get menuRotate90CW;

  /// No description provided for @menuRotate90CCW.
  ///
  /// In en, this message translates to:
  /// **'Rotate 90° CCW'**
  String get menuRotate90CCW;

  /// No description provided for @menuRotate180CW.
  ///
  /// In en, this message translates to:
  /// **'Rotate 180° CW'**
  String get menuRotate180CW;

  /// No description provided for @menuRotate180CCW.
  ///
  /// In en, this message translates to:
  /// **'Rotate 180° CCW'**
  String get menuRotate180CCW;

  /// No description provided for @menuImageSizeEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Image Size…'**
  String get menuImageSizeEllipsis;

  /// No description provided for @menuCanvasSizeEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Canvas Size…'**
  String get menuCanvasSizeEllipsis;

  /// No description provided for @menuNewSubmenu.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get menuNewSubmenu;

  /// No description provided for @menuNewLayerEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Layer…'**
  String get menuNewLayerEllipsis;

  /// No description provided for @menuMergeDown.
  ///
  /// In en, this message translates to:
  /// **'Merge Down'**
  String get menuMergeDown;

  /// No description provided for @menuRasterize.
  ///
  /// In en, this message translates to:
  /// **'Rasterize'**
  String get menuRasterize;

  /// No description provided for @menuTransform.
  ///
  /// In en, this message translates to:
  /// **'Transform'**
  String get menuTransform;

  /// No description provided for @menuSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get menuSelectAll;

  /// No description provided for @menuInvertSelection.
  ///
  /// In en, this message translates to:
  /// **'Invert Selection'**
  String get menuInvertSelection;

  /// No description provided for @menuPalette.
  ///
  /// In en, this message translates to:
  /// **'Palette'**
  String get menuPalette;

  /// No description provided for @menuGeneratePaletteFromCanvasEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Generate palette from current canvas…'**
  String get menuGeneratePaletteFromCanvasEllipsis;

  /// No description provided for @menuGenerateGradientPalette.
  ///
  /// In en, this message translates to:
  /// **'Generate gradient palette from current colors'**
  String get menuGenerateGradientPalette;

  /// No description provided for @menuImportPaletteEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Import palette…'**
  String get menuImportPaletteEllipsis;

  /// No description provided for @menuReferenceImage.
  ///
  /// In en, this message translates to:
  /// **'Reference Images'**
  String get menuReferenceImage;

  /// No description provided for @menuCreateReferenceImage.
  ///
  /// In en, this message translates to:
  /// **'Create Reference Image'**
  String get menuCreateReferenceImage;

  /// No description provided for @menuImportReferenceImageEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Import Reference Image…'**
  String get menuImportReferenceImageEllipsis;

  /// No description provided for @menuZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get menuZoomIn;

  /// No description provided for @menuZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get menuZoomOut;

  /// No description provided for @menuShowGrid.
  ///
  /// In en, this message translates to:
  /// **'Show Grid'**
  String get menuShowGrid;

  /// No description provided for @menuHideGrid.
  ///
  /// In en, this message translates to:
  /// **'Hide Grid'**
  String get menuHideGrid;

  /// No description provided for @menuBlackWhite.
  ///
  /// In en, this message translates to:
  /// **'Black & White'**
  String get menuBlackWhite;

  /// No description provided for @menuDisableBlackWhite.
  ///
  /// In en, this message translates to:
  /// **'Disable Black & White'**
  String get menuDisableBlackWhite;

  /// No description provided for @menuMirrorPreview.
  ///
  /// In en, this message translates to:
  /// **'Mirror Preview'**
  String get menuMirrorPreview;

  /// No description provided for @menuDisableMirror.
  ///
  /// In en, this message translates to:
  /// **'Disable Mirror'**
  String get menuDisableMirror;

  /// No description provided for @menuShowPerspectiveGuide.
  ///
  /// In en, this message translates to:
  /// **'Show Perspective Guide'**
  String get menuShowPerspectiveGuide;

  /// No description provided for @menuHidePerspectiveGuide.
  ///
  /// In en, this message translates to:
  /// **'Hide Perspective Guide'**
  String get menuHidePerspectiveGuide;

  /// No description provided for @menuPerspectiveMode.
  ///
  /// In en, this message translates to:
  /// **'Perspective Mode'**
  String get menuPerspectiveMode;

  /// No description provided for @menuPerspective1Point.
  ///
  /// In en, this message translates to:
  /// **'1-Point'**
  String get menuPerspective1Point;

  /// No description provided for @menuPerspective2Point.
  ///
  /// In en, this message translates to:
  /// **'2-Point'**
  String get menuPerspective2Point;

  /// No description provided for @menuPerspective3Point.
  ///
  /// In en, this message translates to:
  /// **'3-Point'**
  String get menuPerspective3Point;

  /// No description provided for @menuWorkspaceDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get menuWorkspaceDefault;

  /// No description provided for @menuWorkspaceSai2.
  ///
  /// In en, this message translates to:
  /// **'SAI2'**
  String get menuWorkspaceSai2;

  /// No description provided for @menuSwitchWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Switch Workspace'**
  String get menuSwitchWorkspace;

  /// No description provided for @menuResetWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Reset Workspace'**
  String get menuResetWorkspace;

  /// No description provided for @menuEdgeSofteningEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Edge Softening…'**
  String get menuEdgeSofteningEllipsis;

  /// No description provided for @menuNarrowLinesEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Narrow Lines…'**
  String get menuNarrowLinesEllipsis;

  /// No description provided for @menuExpandFillEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Expand Fill…'**
  String get menuExpandFillEllipsis;

  /// No description provided for @menuGaussianBlurEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Gaussian Blur…'**
  String get menuGaussianBlurEllipsis;

  /// No description provided for @menuRemoveColorLeakEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Remove Color Leak…'**
  String get menuRemoveColorLeakEllipsis;

  /// No description provided for @menuHueSaturationEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Hue/Saturation…'**
  String get menuHueSaturationEllipsis;

  /// No description provided for @menuBrightnessContrastEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Brightness/Contrast…'**
  String get menuBrightnessContrastEllipsis;

  /// No description provided for @menuColorRangeEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Color Range…'**
  String get menuColorRangeEllipsis;

  /// No description provided for @menuBlackWhiteEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Black & White…'**
  String get menuBlackWhiteEllipsis;

  /// No description provided for @menuBinarizeEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Binarize…'**
  String get menuBinarizeEllipsis;

  /// No description provided for @menuInvertColors.
  ///
  /// In en, this message translates to:
  /// **'Invert Colors'**
  String get menuInvertColors;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'CN':
            return AppLocalizationsZhCn();
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
