// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get webLoadingInitializingCanvas => '캔버스를 초기화하는 중…';

  @override
  String get webLoadingMayTakeTime => '웹에서는 로딩에 시간이 조금 걸릴 수 있습니다. 잠시만 기다려 주세요.';

  @override
  String get closeAppTitle => '앱 종료';

  @override
  String unsavedProjectsWarning(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '저장되지 않은 프로젝트 $count개가 감지되었습니다. 지금 종료하면 최신 변경 사항이 사라집니다.',
      one: '저장되지 않은 프로젝트 1개가 감지되었습니다. 지금 종료하면 최신 변경 사항이 사라집니다.',
    );
    return '$_temp0';
  }

  @override
  String get cancel => '취소';

  @override
  String get discardAndExit => '버리고 종료';

  @override
  String get homeTagline => '여기서 창작을 시작하세요';

  @override
  String get homeNewProject => '새 프로젝트';

  @override
  String get homeNewProjectDesc => '빈 캔버스에서 새로운 아이디어를 시작';

  @override
  String get homeOpenProject => '프로젝트 열기';

  @override
  String get homeOpenProjectDesc => '디스크에서 .rin / .psd 파일 불러오기';

  @override
  String get homeRecentProjects => '최근 열기';

  @override
  String get homeRecentProjectsDesc => '자동 저장된 프로젝트를 빠르게 복원';

  @override
  String get homeProjectManager => '프로젝트 관리';

  @override
  String get homeProjectManagerDesc => '자동 저장 프로젝트 파일을 일괄 보기/정리';

  @override
  String get homeSettings => '설정';

  @override
  String get homeSettingsDesc => '공개 예정인 개인화 옵션을 미리보기';

  @override
  String get homeAbout => '정보';

  @override
  String get homeAboutDesc => 'Misa Rin 알아보기';

  @override
  String createProjectFailed(Object error) {
    return '프로젝트 생성 실패: $error';
  }

  @override
  String get openProjectDialogTitle => '프로젝트 열기';

  @override
  String get openingProjectTitle => '프로젝트를 여는 중…';

  @override
  String openingProjectMessage(Object fileName) {
    return '$fileName 로딩 중';
  }

  @override
  String get cannotReadPsdContent => 'PSD 파일 내용을 읽을 수 없습니다.';

  @override
  String get cannotReadProjectFileContent => '프로젝트 파일 내용을 읽을 수 없습니다.';

  @override
  String openedProjectInfo(Object name) {
    return '프로젝트를 열었습니다: $name';
  }

  @override
  String openProjectFailed(Object error) {
    return '프로젝트 열기 실패: $error';
  }

  @override
  String get importImageDialogTitle => '이미지 가져오기';

  @override
  String importedImageInfo(Object name) {
    return '이미지를 가져왔습니다: $name';
  }

  @override
  String importImageFailed(Object error) {
    return '이미지 가져오기 실패: $error';
  }

  @override
  String get clipboardNoBitmapFound => '클립보드에서 가져올 수 있는 비트맵을 찾지 못했습니다.';

  @override
  String get clipboardImageDefaultName => '클립보드 이미지';

  @override
  String get importedClipboardImageInfo => '클립보드 이미지를 가져왔습니다';

  @override
  String importClipboardImageFailed(Object error) {
    return '클립보드 이미지 가져오기 실패: $error';
  }

  @override
  String get webPreparingCanvasTitle => '캔버스를 준비하는 중…';

  @override
  String get webPreparingCanvasMessage =>
      '웹 초기화에는 시간이 조금 걸릴 수 있습니다. 잠시만 기다려 주세요.';

  @override
  String get aboutTitle => 'Misa Rin 정보';

  @override
  String get aboutDescription =>
      'Misa Rin은 창작과 프로젝트 관리에 초점을 맞춘 앱으로, 부드러운 그리기 경험과 신뢰할 수 있는 프로젝트 보관 기능을 제공합니다.';

  @override
  String get aboutAppIdLabel => '앱 ID';

  @override
  String get aboutAppVersionLabel => '버전';

  @override
  String get aboutDeveloperLabel => '개발자';

  @override
  String get close => '닫기';

  @override
  String get settingsTitle => '설정';

  @override
  String get tabletTest => '태블릿 테스트';

  @override
  String get restoreDefaults => '기본값 복원';

  @override
  String get ok => '확인';

  @override
  String get languageLabel => '언어';

  @override
  String get languageSystem => '시스템';

  @override
  String get languageEnglish => '영어';

  @override
  String get languageJapanese => '일본어';

  @override
  String get languageKorean => '한국어';

  @override
  String get languageChineseSimplified => '중국어(간체)';

  @override
  String get languageChineseTraditional => '중국어(번체)';

  @override
  String get themeModeLabel => '테마 모드';

  @override
  String get themeLight => '라이트';

  @override
  String get themeDark => '다크';

  @override
  String get themeSystem => '시스템';

  @override
  String get stylusPressureSettingsLabel => '필압 설정';

  @override
  String get enableStylusPressure => '필압 사용';

  @override
  String get responseCurveLabel => '반응 곡선';

  @override
  String get responseCurveDesc => '압력과 스트로크 두께 사이의 전환 속도를 조정합니다.';

  @override
  String get brushSizeSliderRangeLabel => '브러시 크기 슬라이더 범위';

  @override
  String get brushSizeSliderRangeDesc =>
      '도구 패널의 브러시 크기 슬라이더에 영향을 주며, 정밀도를 빠르게 전환하는 데 도움이 됩니다.';

  @override
  String get penSliderRangeCompact => '1 - 60 px(거친 조정)';

  @override
  String get penSliderRangeMedium => '0.1 - 500 px(중간)';

  @override
  String get penSliderRangeFull => '0.01 - 1000 px(전체)';

  @override
  String get historyLimitLabel => '실행 취소/다시 실행 제한';

  @override
  String historyLimitCurrent(Object count) {
    return '현재 제한: $count단계';
  }

  @override
  String historyLimitDesc(Object min, Object max) {
    return '실행 취소/다시 실행 기록 보관 수를 조정합니다(범위 $min-$max).';
  }

  @override
  String get developerOptionsLabel => '개발자 옵션';

  @override
  String get performanceOverlayLabel => '성능 오버레이';

  @override
  String get performanceOverlayDesc =>
      '화면 모서리에 Flutter Performance Pulse 대시보드를 표시하여 FPS, CPU, 메모리, 디스크 등을 실시간으로 보여 줍니다.';

  @override
  String get tabletInputTestTitle => '태블릿 입력 테스트';

  @override
  String get recentProjectsTitle => '최근 열기';

  @override
  String recentProjectsLoadFailed(Object error) {
    return '최근 프로젝트를 불러오지 못했습니다: $error';
  }

  @override
  String get recentProjectsEmpty => '최근 프로젝트가 없습니다';

  @override
  String get openFileLocation => '파일 위치 열기';

  @override
  String lastOpened(Object date) {
    return '마지막 열기: $date';
  }

  @override
  String canvasSize(Object width, Object height) {
    return '캔버스 크기: $width x $height';
  }

  @override
  String get menuFile => '파일';

  @override
  String get menuEdit => '편집';

  @override
  String get menuImage => '이미지';

  @override
  String get menuLayer => '레이어';

  @override
  String get menuSelection => '선택';

  @override
  String get menuFilter => '필터';

  @override
  String get menuTool => '도구';

  @override
  String get menuView => '보기';

  @override
  String get menuWorkspace => '작업 공간';

  @override
  String get menuWindow => '창';

  @override
  String get menuAbout => 'Misa Rin 정보';

  @override
  String get menuPreferences => '환경 설정…';

  @override
  String get menuNewEllipsis => '새로 만들기…';

  @override
  String get menuOpenEllipsis => '열기…';

  @override
  String get menuImportImageEllipsis => '이미지 가져오기…';

  @override
  String get menuImportImageFromClipboard => '클립보드에서 이미지 가져오기';

  @override
  String get menuSave => '저장';

  @override
  String get menuSaveAsEllipsis => '다른 이름으로 저장…';

  @override
  String get menuExportEllipsis => '내보내기…';

  @override
  String get menuCloseAll => '모두 닫기';

  @override
  String get menuUndo => '실행 취소';

  @override
  String get menuRedo => '다시 실행';

  @override
  String get menuCut => '잘라내기';

  @override
  String get menuCopy => '복사';

  @override
  String get menuPaste => '붙여넣기';

  @override
  String get menuImageTransform => '이미지 변환';

  @override
  String get menuRotate90CW => '시계 방향 90도';

  @override
  String get menuRotate90CCW => '반시계 방향 90도';

  @override
  String get menuRotate180CW => '시계 방향 180도';

  @override
  String get menuRotate180CCW => '반시계 방향 180도';

  @override
  String get menuImageSizeEllipsis => '이미지 크기…';

  @override
  String get menuCanvasSizeEllipsis => '캔버스 크기…';

  @override
  String get menuNewSubmenu => '새로 만들기';

  @override
  String get menuNewLayerEllipsis => '레이어…';

  @override
  String get menuMergeDown => '아래로 병합';

  @override
  String get menuRasterize => '래스터화';

  @override
  String get menuTransform => '변환';

  @override
  String get menuSelectAll => '전체 선택';

  @override
  String get menuInvertSelection => '선택 반전';

  @override
  String get menuPalette => '팔레트';

  @override
  String get menuGeneratePaletteFromCanvasEllipsis => '현재 캔버스에서 팔레트 생성…';

  @override
  String get menuGenerateGradientPalette => '현재 색상으로 그라데이션 팔레트 생성';

  @override
  String get menuImportPaletteEllipsis => '팔레트 가져오기…';

  @override
  String get menuReferenceImage => '참조 이미지';

  @override
  String get menuCreateReferenceImage => '참조 이미지 만들기';

  @override
  String get menuImportReferenceImageEllipsis => '참조 이미지 가져오기…';

  @override
  String get menuZoomIn => '확대';

  @override
  String get menuZoomOut => '축소';

  @override
  String get menuShowGrid => '그리드 표시';

  @override
  String get menuHideGrid => '그리드 숨기기';

  @override
  String get menuBlackWhite => '흑백';

  @override
  String get menuDisableBlackWhite => '흑백 해제';

  @override
  String get menuMirrorPreview => '미러 미리보기';

  @override
  String get menuDisableMirror => '미러 해제';

  @override
  String get menuShowPerspectiveGuide => '원근 가이드 표시';

  @override
  String get menuHidePerspectiveGuide => '원근 가이드 숨기기';

  @override
  String get menuPerspectiveMode => '원근 모드';

  @override
  String get menuPerspective1Point => '1점 원근';

  @override
  String get menuPerspective2Point => '2점 원근';

  @override
  String get menuPerspective3Point => '3점 원근';

  @override
  String get menuWorkspaceDefault => '기본';

  @override
  String get menuWorkspaceSai2 => 'SAI2';

  @override
  String get menuSwitchWorkspace => '작업 공간 전환';

  @override
  String get menuResetWorkspace => '작업 공간 재설정';

  @override
  String get menuEdgeSofteningEllipsis => '가장자리 부드럽게…';

  @override
  String get menuNarrowLinesEllipsis => '선 굵기 줄이기…';

  @override
  String get menuExpandFillEllipsis => '채우기 확장…';

  @override
  String get menuGaussianBlurEllipsis => '가우시안 블러…';

  @override
  String get menuRemoveColorLeakEllipsis => '색 번짐 제거…';

  @override
  String get menuHueSaturationEllipsis => '색상/채도…';

  @override
  String get menuBrightnessContrastEllipsis => '밝기/대비…';

  @override
  String get menuColorRangeEllipsis => '색상 범위…';

  @override
  String get menuBlackWhiteEllipsis => '흑백…';

  @override
  String get menuBinarizeEllipsis => '이진화…';

  @override
  String get menuInvertColors => '색상 반전';

  @override
  String get canvasSizeTitle => 'Canvas Size';

  @override
  String get canvasSizeAnchorLabel => 'Anchor';

  @override
  String get canvasSizeAnchorDesc => 'Resize canvas based on anchor point.';

  @override
  String get confirm => 'Confirm';

  @override
  String get projectManagerTitle => 'Project Manager';

  @override
  String get selectAll => 'Select All';

  @override
  String get openFolder => 'Open Folder';

  @override
  String deleteSelected(Object count) {
    return 'Delete Selected ($count)';
  }

  @override
  String get imageSizeTitle => 'Image Size';

  @override
  String get lockAspectRatio => 'Lock Aspect Ratio';

  @override
  String get realtimeParams => 'Realtime Parameters';

  @override
  String get clearScribble => 'Clear Scribble';

  @override
  String get newCanvasSettingsTitle => 'New Canvas Settings';

  @override
  String get custom => 'Custom';

  @override
  String get colorWhite => 'White';

  @override
  String get colorLightGray => 'Light Gray';

  @override
  String get colorBlack => 'Black';

  @override
  String get create => 'Create';

  @override
  String currentPreset(Object name) {
    return 'Current Preset: $name';
  }

  @override
  String get exportSettingsTitle => 'Export Settings';

  @override
  String get exportTypeLabel => 'Export Type';

  @override
  String get exportTypePng => 'Bitmap PNG';

  @override
  String get exportTypeSvg => 'Vector SVG (Experimental)';

  @override
  String get exportScaleLabel => 'Export Scale';

  @override
  String get reset => 'Reset';

  @override
  String exportOutputSize(Object width, Object height) {
    return 'Output Size: $width x $height px';
  }

  @override
  String get exportAntialiasingLabel => 'Antialiasing';

  @override
  String get enableAntialiasing => 'Enable Antialiasing';

  @override
  String get vectorParamsLabel => 'Vector Parameters';

  @override
  String vectorMaxColors(Object count) {
    return 'Max Colors: $count';
  }

  @override
  String vectorSimplify(Object value) {
    return 'Simplify Strength: $value';
  }

  @override
  String get export => 'Export';

  @override
  String get invalidDimensions => 'Please enter valid dimensions (px).';

  @override
  String get widthPx => 'Width (px)';

  @override
  String get heightPx => 'Height (px)';

  @override
  String get noAutosavedProjects => 'No autosaved projects';

  @override
  String get revealProjectLocation => 'Reveal selected project location';

  @override
  String get deleteSelectedProjects => 'Delete selected projects';

  @override
  String loadFailed(Object error) {
    return 'Failed to load: $error';
  }

  @override
  String deleteFailed(Object error) {
    return 'Failed to delete: $error';
  }

  @override
  String projectFileInfo(Object size, Object date) {
    return 'Size: $size · Modified: $date';
  }

  @override
  String projectCanvasInfo(Object width, Object height) {
    return 'Canvas $width x $height';
  }

  @override
  String get samplingMethod => 'Sampling Method';

  @override
  String currentSize(Object width, Object height) {
    return 'Current Size: $width x $height px';
  }

  @override
  String get samplingNearestLabel => 'Nearest Neighbor';

  @override
  String get samplingNearestDesc => 'Preserves hard edges, good for pixel art.';

  @override
  String get samplingBilinearLabel => 'Bilinear';

  @override
  String get samplingBilinearDesc =>
      'Smooth interpolation, good for general resizing.';

  @override
  String get tabletPressureLatest => 'Latest Pressure';

  @override
  String get tabletPressureMin => 'Pressure Min';

  @override
  String get tabletPressureMax => 'Pressure Max';

  @override
  String get tabletRadiusPx => 'Estimated Radius (px)';

  @override
  String get tabletTiltRad => 'Tilt (radians)';

  @override
  String get tabletSampleCount => 'Sample Count';

  @override
  String get tabletSampleRateHz => 'Sample Rate (Hz)';

  @override
  String get tabletPointerType => 'Pointer Type';

  @override
  String get pointerKindMouse => 'Mouse';

  @override
  String get pointerKindTouch => 'Touch';

  @override
  String get pointerKindStylus => 'Stylus';

  @override
  String get pointerKindInvertedStylus => 'Stylus (Eraser)';

  @override
  String get pointerKindTrackpad => 'Trackpad';

  @override
  String get pointerKindUnknown => 'Unknown';

  @override
  String get presetMobilePortrait => 'Mobile Portrait (1080 x 1920)';

  @override
  String get presetSquare => 'Square (1024 x 1024)';

  @override
  String presetPixelArt(Object width, Object height) {
    return 'Pixel Art ($width x $height)';
  }

  @override
  String get untitledProject => 'Untitled Project';

  @override
  String get invalidResolution => 'Please enter valid resolution';

  @override
  String minResolutionError(Object value) {
    return 'Resolution cannot be less than $value px';
  }

  @override
  String maxResolutionError(Object value) {
    return 'Resolution cannot exceed $value px';
  }

  @override
  String get projectName => 'Project Name';

  @override
  String get workspacePreset => 'Workspace Preset';

  @override
  String get workspacePresetDesc =>
      'Automatically apply common tool settings when creating a canvas.';

  @override
  String get workspaceIllustration => 'Illustration';

  @override
  String get workspaceIllustrationDesc => 'Brush edge softening set to level 1';

  @override
  String get workspaceCelShading => 'Cel Shading';

  @override
  String get workspaceCelShadingDesc1 => 'Brush edge softening set to level 0';

  @override
  String get workspaceCelShadingDesc2 => 'Fill tool expand to line: On';

  @override
  String get workspaceCelShadingDesc3 => 'Fill tool antialiasing: Off';

  @override
  String get workspacePixel => 'Pixel';

  @override
  String get workspacePixelDesc1 =>
      'Brush/Fill tool antialiasing set to level 0';

  @override
  String get workspacePixelDesc2 => 'Show Grid: On';

  @override
  String get workspacePixelDesc3 => 'Vector Drawing: Off';

  @override
  String get workspaceDefault => 'Default';

  @override
  String get workspaceDefaultDesc => 'Do not change current tool settings';

  @override
  String get resolutionPreset => 'Resolution Preset';

  @override
  String get customResolution => 'Custom Resolution';

  @override
  String finalSizePreview(Object width, Object height, Object ratio) {
    return 'Final Size: $width x $height px (Ratio $ratio)';
  }

  @override
  String get enterValidDimensions => 'Please enter valid dimensions';

  @override
  String get backgroundColor => 'Background Color';

  @override
  String get exportBitmapDesc =>
      'Suitable for regular exports requiring raster format, supports scaling and antialiasing.';

  @override
  String get exportVectorDesc =>
      'Automatically transcribes current canvas to vector paths, suitable for editing in vector tools.';

  @override
  String get exampleScale => 'e.g. 1.0';

  @override
  String get enterPositiveValue => 'Please enter a value > 0';

  @override
  String get antialiasingBeforeExport => 'Antialiasing before export';

  @override
  String get antialiasingDesc =>
      'Smoothens edges while preserving line density, a tribute to the texture of Retas animation software.';

  @override
  String levelLabel(Object level) {
    return 'Level $level';
  }

  @override
  String vectorExportSize(Object width, Object height) {
    return 'Export Size: $width x $height (Use Canvas Size)';
  }

  @override
  String colorCount(Object count) {
    return '$count colors';
  }

  @override
  String get vectorSimplifyDesc =>
      'Fewer colors and higher simplification yield simpler SVG; too low values result in too many nodes.';

  @override
  String get antialiasNone =>
      'Level 0 (Off): Preserves pixel hard edges, no antialiasing.';

  @override
  String get antialiasLow =>
      'Level 1 (Low): Slight softening of aliasing, smoothing edges while maintaining line density.';

  @override
  String get antialiasMedium =>
      'Level 2 (Standard): Balance sharpness and softening, presenting clean lines like Retas.';

  @override
  String get antialiasHigh =>
      'Level 3 (High): Strongest softening effect, for edges requiring soft transitions or large scaling.';

  @override
  String get tolerance => 'Tolerance';

  @override
  String get sampleAllLayers => 'Sample All Layers';

  @override
  String get contiguous => 'Contiguous';

  @override
  String get swallowColorLine => 'Swallow Color Line';

  @override
  String get cropOutsideCanvas => 'Crop Outside Canvas';

  @override
  String get noAdjustableSettings => 'No adjustable settings for this tool';

  @override
  String get solidFill => 'Solid Fill';

  @override
  String get autoSharpTaper => 'Auto Sharp Taper';

  @override
  String get stylusPressure => 'Stylus Pressure';

  @override
  String get simulatedPressure => 'Simulated Pressure';

  @override
  String get switchToEraser => 'Switch to Eraser';

  @override
  String get vectorDrawing => 'Vector Drawing';

  @override
  String get smoothCurve => 'Smooth Curve';

  @override
  String get sprayEffect => 'Spray Effect';

  @override
  String get brushShape => 'Brush Shape';

  @override
  String get selectionShape => 'Selection Shape';

  @override
  String get fontSize => 'Font Size';

  @override
  String get lineHeight => 'Line Height';

  @override
  String get letterSpacing => 'Letter Spacing';

  @override
  String get textStroke => 'Text Stroke';

  @override
  String get strokeWidth => 'Stroke Width';

  @override
  String get strokeColor => 'Stroke Color';

  @override
  String get pickColor => 'Pick Color';

  @override
  String get alignment => 'Alignment';

  @override
  String get alignCenter => 'Center';

  @override
  String get alignRight => 'Right';

  @override
  String get alignLeft => 'Left';

  @override
  String get orientation => 'Orientation';

  @override
  String get horizontal => 'Horizontal';

  @override
  String get vertical => 'Vertical';

  @override
  String get textToolHint =>
      'Use the color picker in the bottom left for text fill, and the secondary color for stroke.';

  @override
  String get shapeType => 'Shape Type';

  @override
  String get brushSize => 'Brush Size';

  @override
  String get spraySize => 'Spray Size';

  @override
  String get brushFineTune => 'Brush Fine Tune';

  @override
  String get increase => 'Increase';

  @override
  String get decrease => 'Decrease';

  @override
  String get stabilizer => 'Stabilizer';

  @override
  String get off => 'Off';

  @override
  String get taperEnds => 'Taper Ends';

  @override
  String get taperCenter => 'Taper Center';

  @override
  String get auto => 'Auto';

  @override
  String get softSpray => 'Soft Spray';

  @override
  String get splatter => 'Splatter';

  @override
  String get rectSelection => 'Rectangle Selection';

  @override
  String get ellipseSelection => 'Ellipse Selection';

  @override
  String get polygonLasso => 'Polygon Lasso';

  @override
  String get rectangle => 'Rectangle';

  @override
  String get ellipse => 'Ellipse';

  @override
  String get triangle => 'Triangle';

  @override
  String get line => 'Line';

  @override
  String get circle => 'Circle';

  @override
  String get square => 'Square';

  @override
  String get brushSizeDesc =>
      'Sets the pixel diameter of the current brush. Larger values make thicker lines, smaller for details.';

  @override
  String get spraySizeDesc =>
      'Determines the radius of the spray area. Larger radius covers more area but particles are more dispersed.';

  @override
  String get toleranceDesc =>
      'Controls the threshold for \'color similarity\' for Bucket or Magic Wand. Higher tolerance grabs more similar colors.';

  @override
  String get antialiasingSliderDesc =>
      'Adds multi-sampling smoothing to brush or fill edges, preserving line density. Level 0 keeps pixel style.';

  @override
  String get stabilizerDesc =>
      'Smooths pointer trajectory in real-time to counteract hand tremors. Higher levels are steadier but respond slower.';

  @override
  String get fontSizeDesc =>
      'Adjusts the pixel height of the text for overall scaling.';

  @override
  String get lineHeightDesc =>
      'Controls vertical distance between lines of text.';

  @override
  String get letterSpacingDesc =>
      'Changes horizontal spacing between characters.';

  @override
  String get strokeWidthDesc => 'Sets the thickness of the text stroke.';

  @override
  String get solidFillDesc =>
      'Determines if the shape tool draws a filled block or hollow outline. Toggle on for solid shapes.';

  @override
  String get autoSharpTaperDesc =>
      'Automatically tapers the start and end of strokes for a sharp, cel-shading look.';

  @override
  String get stylusPressureDesc =>
      'Allows stylus pressure to affect brush size/opacity. Turn off to ignore hardware pressure.';

  @override
  String get simulatedPressureDesc =>
      'Simulates pressure based on mouse speed when no pressure device is present.';

  @override
  String get switchToEraserDesc =>
      'Switches current brush/spray to an eraser with the same texture.';

  @override
  String get vectorDrawingDesc =>
      'Previews strokes as vector curves for 120Hz smooth feedback and lossless scaling. Turn off for direct pixel output.';

  @override
  String get smoothCurveDesc =>
      'Further smooths curve nodes when Vector Drawing is on, reducing corners but sacrificing some responsiveness.';

  @override
  String get sampleAllLayersDesc =>
      'Bucket samples colors from all visible layers. Turn off to detect only the current layer.';

  @override
  String get contiguousDesc =>
      'Spreads only to adjacent pixels. Turn off to match the entire canvas.';

  @override
  String get swallowColorLineDesc =>
      'Automatically expands fill into color lines to remove white edges. Dedicated for Retas workflow.';

  @override
  String get cropOutsideCanvasDesc =>
      'Crops pixels outside the canvas when adjusting layers. Turn off to keep all pixels.';

  @override
  String get textAntialiasingDesc =>
      'Enables antialiasing for text rendering, smoothing glyphs while preserving density.';

  @override
  String get textStrokeDesc => 'Enables the stroke channel for text outlines.';

  @override
  String get sprayEffectDesc =>
      'Switches spray model: \'Soft Spray\' for misty gradients, \'Splatter\' for particles.';

  @override
  String get rectSelectDesc => 'Quickly select a rectangular area.';

  @override
  String get ellipseSelectDesc => 'Create circular or elliptical selections.';

  @override
  String get polyLassoDesc =>
      'Draw arbitrary polygon selections point by point.';

  @override
  String get rectShapeDesc =>
      'Draw horizontal rectangles or squares (outline/fill).';

  @override
  String get ellipseShapeDesc => 'Draw elliptical or circular outlines/fills.';

  @override
  String get triangleShapeDesc =>
      'Draw geometric triangles or use a triangle tip for sharp outlines.';

  @override
  String get lineShapeDesc => 'Draw straight lines from start to end.';

  @override
  String get circleTipDesc =>
      'Keep brush tip circular for smooth, soft strokes.';

  @override
  String get squareTipDesc => 'Use a square tip for hard-edged pixel strokes.';

  @override
  String get apply => 'Apply';

  @override
  String get next => 'Next';

  @override
  String get disableVectorDrawing => 'Disable Vector Drawing';

  @override
  String get disableVectorDrawingConfirm =>
      'Are you sure you want to disable vector drawing?';

  @override
  String get disableVectorDrawingDesc =>
      'Performance will decrease after disabling.';

  @override
  String get dontShowAgain => 'Don\'t show again';

  @override
  String get newLayer => 'New Layer';

  @override
  String get mergeDown => 'Merge Down';

  @override
  String get delete => 'Delete';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get rasterizeTextLayer => 'Rasterize Text Layer';

  @override
  String get opacity => 'Opacity';

  @override
  String get blendMode => 'Blend Mode';

  @override
  String get clearFill => 'Clear Fill';

  @override
  String get colorLine => 'Color Line';

  @override
  String get currentColor => 'Current Color';

  @override
  String get rgb => 'RGB';

  @override
  String get hsv => 'HSV';

  @override
  String get preparingLayer => 'Preparing layer...';

  @override
  String get generatePaletteTitle => 'Generate palette from canvas';

  @override
  String get generatePaletteDesc => 'Choose color count or enter custom value.';

  @override
  String get customCount => 'Custom Count';

  @override
  String get selectExportFormat => 'Select Export Format';

  @override
  String get selectPaletteFormatDesc => 'Select palette export format.';

  @override
  String get noColorsDetected => 'No colors detected.';

  @override
  String get alphaThreshold => 'Alpha Threshold';

  @override
  String get blurRadius => 'Blur Radius';

  @override
  String get repairRange => 'Repair Range';

  @override
  String get selectAntialiasLevel => 'Select Antialias Level';

  @override
  String get colorCountLabel => 'Color Count';

  @override
  String get completeTransformFirst =>
      'Please complete the current transform first.';

  @override
  String get enablePerspectiveGuideFirst =>
      'Please enable perspective guide before using perspective pen.';

  @override
  String get lineNotAlignedWithPerspective =>
      'Current line does not align with perspective direction, please adjust angle.';

  @override
  String get layerBackground => 'Background';

  @override
  String layerDefaultName(Object index) {
    return 'Layer $index';
  }

  @override
  String get duplicateLayer => 'Duplicate Layer';

  @override
  String layerCopyName(Object name) {
    return '$name Copy';
  }

  @override
  String get unlockLayer => 'Unlock Layer';

  @override
  String get lockLayer => 'Lock Layer';

  @override
  String get releaseClippingMask => 'Release Clipping Mask';

  @override
  String get createClippingMask => 'Create Clipping Mask';

  @override
  String get hide => 'Hide';

  @override
  String get show => 'Show';

  @override
  String get colorRangeTitle => 'Color Range';

  @override
  String get colorPickerTitle => 'Color Picker';

  @override
  String get layerManagerTitle => 'Layer Manager';

  @override
  String get edgeSoftening => 'Edge Softening';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String undoShortcut(Object shortcut) {
    return 'Undo ($shortcut)';
  }

  @override
  String redoShortcut(Object shortcut) {
    return 'Redo ($shortcut)';
  }

  @override
  String opacityPercent(Object percent) {
    return 'Opacity $percent%';
  }

  @override
  String get clippingMask => 'Clipping Mask';

  @override
  String get deleteLayerTitle => 'Delete Layer';

  @override
  String get deleteLayerDesc => 'Remove this layer. Undo available.';

  @override
  String get mergeDownDesc => 'Merge with the layer below.';

  @override
  String get duplicateLayerDesc => 'Duplicate entire layer content.';

  @override
  String get more => 'More';

  @override
  String get lockLayerDesc => 'Lock to prevent accidental edits.';

  @override
  String get unlockLayerDesc => 'Unlock to enable editing.';

  @override
  String get clippingMaskDescOn => 'Restore to normal layer.';

  @override
  String get clippingMaskDescOff => 'Clip to layer below.';

  @override
  String get red => 'Red';

  @override
  String get green => 'Green';

  @override
  String get blue => 'Blue';

  @override
  String get hue => 'Hue';

  @override
  String get saturation => 'Saturation';

  @override
  String get value => 'Value';

  @override
  String get hsvBoxSpectrum => 'HSV Box Spectrum';

  @override
  String get hueRingSpectrum => 'Hue Ring Spectrum';

  @override
  String get rgbHsvSliders => 'RGB / HSV Sliders';

  @override
  String get boardPanelPicker => 'Board Panel Picker';

  @override
  String get adjustCurrentColor => 'Adjust Current Color';

  @override
  String get adjustStrokeColor => 'Adjust Stroke Color';

  @override
  String copiedHex(Object hex) {
    return 'Copied $hex';
  }

  @override
  String rotationLabel(Object degrees) {
    return 'Rotation: $degrees°';
  }

  @override
  String scaleLabel(Object x, Object y) {
    return 'Scale: $x% x $y%';
  }

  @override
  String get failedToExportTransform => 'Failed to export transform result';

  @override
  String get cannotLocateLayer => 'Cannot locate active layer.';

  @override
  String get layerLockedCannotTransform =>
      'Active layer is locked, cannot transform.';

  @override
  String get cannotEnterTransformMode => 'Cannot enter free transform mode.';

  @override
  String get applyTransformFailed =>
      'Failed to apply transform, please try again.';

  @override
  String get freeTransformTitle => 'Free Transform';

  @override
  String get colorIndicatorDetail =>
      'Click to open color editor, enter values or copy HEX.';

  @override
  String get gplDesc =>
      'Text format compatible with GIMP, Krita, Clip Studio Paint, etc.';

  @override
  String get aseDesc =>
      'Suitable for Aseprite, LibreSprite pixel art software.';

  @override
  String get asepriteDesc =>
      'Uses .aseprite extension for direct opening in Aseprite.';

  @override
  String get gradientPaletteFailed =>
      'Current color cannot generate gradient palette, please try again.';

  @override
  String get gradientPaletteTitle => 'Gradient Palette (Current Color)';

  @override
  String paletteCountRange(Object min, Object max) {
    return 'Range $min - $max';
  }

  @override
  String allowedRange(Object min, Object max) {
    return 'Allowed Range: $min - $max colors';
  }

  @override
  String get enterValidColorCount => 'Please enter a valid color count.';

  @override
  String get paletteGenerationFailed =>
      'Unable to generate palette momentarily, please try again.';

  @override
  String get noValidColorsFound =>
      'No valid colors found, please ensure canvas has content.';

  @override
  String get paletteEmpty => 'This palette has no usable colors.';

  @override
  String paletteMinColors(Object min) {
    return 'Palette requires at least $min colors.';
  }

  @override
  String get paletteDefaultName => 'Palette';

  @override
  String get paletteEmptyExport => 'This palette has no exportable colors.';

  @override
  String get exportPaletteTitle => 'Export Palette';

  @override
  String get webDownloadDesc =>
      'Browser will save palette to default download directory.';

  @override
  String get download => 'Download';

  @override
  String paletteDownloaded(Object name) {
    return 'Palette downloaded: $name';
  }

  @override
  String paletteExported(Object path) {
    return 'Palette exported to $path';
  }

  @override
  String paletteExportFailed(Object error) {
    return 'Failed to export palette: $error';
  }

  @override
  String get selectEditableLayerFirst =>
      'Please select an editable layer first.';

  @override
  String get layerLockedNoFilter =>
      'Active layer is locked, cannot apply filter.';

  @override
  String get textLayerNoFilter =>
      'Active layer is text, please rasterize or switch layer.';

  @override
  String get hueSaturation => 'Hue/Saturation';

  @override
  String get brightnessContrast => 'Brightness/Contrast';

  @override
  String get blackAndWhite => 'Black & White';

  @override
  String get binarize => 'Binarize';

  @override
  String get gaussianBlur => 'Gaussian Blur';

  @override
  String get leakRemoval => 'Leak Removal';

  @override
  String get lineNarrow => 'Line Narrow';

  @override
  String get narrowRadius => 'Narrow Radius';

  @override
  String get fillExpand => 'Fill Expand';

  @override
  String get expandRadius => 'Expand Radius';

  @override
  String get noTransparentPixelsFound =>
      'No processable transparent pixels detected.';

  @override
  String get filterApplyFailed => 'Failed to apply filter, please try again.';

  @override
  String get canvasNotReadyInvert => 'Canvas not ready, cannot invert colors.';

  @override
  String get layerLockedInvert => 'Active layer locked, cannot invert colors.';

  @override
  String get layerEmptyInvert => 'Active layer empty, cannot invert colors.';

  @override
  String get noPixelsToInvert => 'Active layer has no pixels to invert.';

  @override
  String get edgeSofteningFailed =>
      'Cannot apply edge softening, layer might be empty or locked.';

  @override
  String get layerLockedEdgeSoftening =>
      'Active layer locked, cannot apply edge softening.';

  @override
  String get canvasNotReadyColorRange =>
      'Canvas not ready, cannot count color range.';

  @override
  String get layerLockedColorRange =>
      'Active layer locked, cannot set color range.';

  @override
  String get layerEmptyColorRange =>
      'Active layer empty, cannot set color range.';

  @override
  String get noColorsToProcess => 'Active layer has no processable colors.';

  @override
  String get targetColorsNotLess =>
      'Target color count not less than current, layer unchanged.';

  @override
  String get colorRangeApplyFailed =>
      'Failed to apply color range, please try again.';

  @override
  String get colorRangePreviewFailed =>
      'Failed to generate color range preview, please try again.';

  @override
  String get lightness => 'Lightness';

  @override
  String get brightness => 'Brightness';

  @override
  String get contrast => 'Contrast';

  @override
  String get selectSaveFormat => 'Please select a file format to save.';

  @override
  String get saveAsPsd => 'Save as PSD';

  @override
  String get saveAsRin => 'Save as RIN';

  @override
  String get dontSave => 'Don\'t Save';

  @override
  String get save => 'Save';

  @override
  String get renameProject => 'Rename Project';

  @override
  String get enterNewProjectName => 'Please enter a new project name';

  @override
  String get rename => 'Rename';

  @override
  String get canvasNotReady => 'Canvas not ready';

  @override
  String get toolPanel => 'Tool Panel';

  @override
  String get toolbarTitle => 'Toolbar';

  @override
  String get toolOptionsTitle => 'Tool Options';

  @override
  String get defaultProjectDirectory => 'Default Project Directory';

  @override
  String get minimize => 'Minimize';

  @override
  String get maximizeRestore => 'Maximize/Restore';

  @override
  String get fontFamily => 'Font Family';

  @override
  String get importPaletteTitle => 'Import Palette';

  @override
  String get cannotReadFile => 'Cannot read file';

  @override
  String paletteImported(Object name) {
    return 'Palette imported: $name';
  }

  @override
  String paletteImportFailed(Object error) {
    return 'Failed to import palette: $error';
  }

  @override
  String noChangesToSave(Object location) {
    return 'No changes to save to $location';
  }

  @override
  String projectSaved(Object location) {
    return 'Project saved to $location';
  }

  @override
  String projectSaveFailed(Object error) {
    return 'Failed to save project: $error';
  }

  @override
  String get canvasNotReadySave => 'Canvas is not ready to save.';

  @override
  String get saveProjectAs => 'Save Project As';

  @override
  String get webSaveDesc => 'Download the project file to your device.';

  @override
  String psdExported(Object path) {
    return 'PSD exported to $path';
  }

  @override
  String projectDownloaded(Object fileName) {
    return 'Project downloaded: $fileName';
  }

  @override
  String psdDownloaded(Object fileName) {
    return 'PSD downloaded: $fileName';
  }

  @override
  String get exportAsPsdTooltip => 'Export as PSD';

  @override
  String get canvasNotReadyExport => 'Canvas is not ready to export.';

  @override
  String exportFileTitle(Object extension) {
    return 'Export $extension File';
  }

  @override
  String get webExportDesc => 'Download the exported image to your device.';

  @override
  String fileDownloaded(Object extension, Object name) {
    return '$extension file downloaded: $name';
  }

  @override
  String fileExported(Object path) {
    return 'File exported to $path';
  }

  @override
  String exportFailed(Object error) {
    return 'Export failed: $error';
  }

  @override
  String get canvasNotReadyTransform => 'Canvas not ready for transformation.';

  @override
  String get canvasSizeErrorTransform =>
      'Canvas size error during transformation.';

  @override
  String get canvasNotReadyResizeImage => 'Canvas not ready to resize image.';

  @override
  String get resizeImageFailed => 'Failed to resize image.';

  @override
  String get canvasNotReadyResizeCanvas => 'Canvas not ready to resize canvas.';

  @override
  String get resizeCanvasFailed => 'Failed to resize canvas.';

  @override
  String get returnToHome => 'Return to Home';

  @override
  String get saveBeforeReturn =>
      'Do you want to save changes before returning to home?';

  @override
  String get closeCanvas => 'Close Canvas';

  @override
  String get saveBeforeClose => 'Do you want to save changes before closing?';

  @override
  String get nameCannotBeEmpty => 'Name cannot be empty.';

  @override
  String get noSupportedImageFormats => 'No supported image formats found.';

  @override
  String importFailed(Object item, Object error) {
    return 'Failed to import $item: $error';
  }

  @override
  String get createdCanvasFromDrop => 'Created canvas from dropped item.';

  @override
  String createdCanvasesFromDrop(Object count) {
    return 'Created $count canvases from dropped items.';
  }

  @override
  String get dropImageCreateFailed =>
      'Failed to create canvas from dropped image.';

  @override
  String get canvasNotReadyDrop => 'Canvas not ready for drop operation.';

  @override
  String get insertedDropImage => 'Inserted dropped image.';

  @override
  String insertedDropImages(Object count) {
    return 'Inserted $count dropped images.';
  }

  @override
  String get dropImageInsertFailed => 'Failed to insert dropped image.';

  @override
  String get image => 'Image';

  @override
  String get on => 'On';

  @override
  String get perspective1Point => '1-Point Perspective';

  @override
  String get perspective2Point => '2-Point Perspective';

  @override
  String get perspective3Point => '3-Point Perspective';

  @override
  String resolutionLabel(Object resolution) {
    return 'Resolution: $resolution';
  }

  @override
  String zoomLabel(Object zoom) {
    return 'Zoom: $zoom';
  }

  @override
  String positionLabel(Object position) {
    return 'Pos: $position';
  }

  @override
  String gridLabel(Object grid) {
    return 'Grid: $grid';
  }

  @override
  String blackWhiteLabel(Object state) {
    return 'B&W: $state';
  }

  @override
  String mirrorLabel(Object state) {
    return 'Mirror: $state';
  }

  @override
  String perspectiveLabel(Object perspective) {
    return 'Perspective: $perspective';
  }

  @override
  String get fileNameCannotBeEmpty => 'File name cannot be empty.';

  @override
  String get blackPoint => 'Black Point';

  @override
  String get whitePoint => 'White Point';

  @override
  String get midTone => 'Mid Tone';
}
