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
}
