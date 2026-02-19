part of 'app_preferences.dart';

const String _folderName = 'MisaRin';
const String _fileName = 'app_preferences.rinconfig';
const String _preferencesStorageKey = 'misa_rin.preferences';
const int _version = 41;
const int _defaultHistoryLimit = 30;
const int _minHistoryLimit = 5;
const int _maxHistoryLimit = 200;
const ThemeMode _defaultThemeMode = ThemeMode.system;
const Locale? _defaultLocaleOverride = null;
const double _defaultPenStrokeWidth = 3.0;
const double _defaultSprayStrokeWidth = kDefaultSprayStrokeWidth;
const SprayMode _defaultSprayMode = SprayMode.smudge;
const bool _defaultSimulatePenPressure = false;
const StrokePressureProfile _defaultPenPressureProfile =
    StrokePressureProfile.auto;
const int _defaultPenAntialiasLevel = 1;
const bool _defaultStylusPressureEnabled = true;
const double _defaultStylusCurve = 0.85;
const bool _defaultAutoSharpPeakEnabled = false;
const PenStrokeSliderRange _defaultPenStrokeSliderRange =
    PenStrokeSliderRange.compact;
const double _defaultStrokeStabilizerStrength = 10.0 / 30.0;
const double _defaultStreamlineStrength = 0.0;
const BrushShape _defaultBrushShape = BrushShape.circle;
const bool _defaultBrushRandomRotationEnabled = false;
const bool _defaultHollowStrokeEnabled = false;
const double _defaultHollowStrokeRatio = 0.7;
const bool _defaultHollowStrokeEraseOccludedParts = false;
const double _strokeStabilizerLowerBound = 0.0;
const double _strokeStabilizerUpperBound = 1.0;
const Color _defaultColorLineColor = kDefaultColorLineColor;
const Color _defaultPrimaryColor = Color(0xFF000000);
const bool _defaultBucketSwallowColorLine = false;
const BucketSwallowColorLineMode _defaultBucketSwallowColorLineMode =
    BucketSwallowColorLineMode.all;
const int _defaultBucketTolerance = 0;
const int _defaultBucketFillGap = 0;
const int _defaultMagicWandTolerance = 0;
const bool _defaultBrushToolsEraserMode = false;
const bool _defaultTouchDrawingEnabled = true;
const bool _defaultShapeToolFillEnabled = false;
const int _defaultBucketAntialiasLevel = 0;
const bool _defaultShowFpsOverlay = false;
const bool _defaultPixelGridVisible = false;
const WorkspaceLayoutPreference _defaultWorkspaceLayout =
    WorkspaceLayoutPreference.floating;
const double _defaultSai2ToolPanelSplit = 0.5;
const double _defaultSai2LayerPanelSplit = 0.5;
const int _defaultNewCanvasWidth = 1920;
const int _defaultNewCanvasHeight = 1080;
const Color _defaultNewCanvasBackgroundColor = Color(0xFFFFFFFF);
const int _minNewCanvasDimension = 1;
const int _maxNewCanvasDimension = 16000;
const CanvasBackend _defaultCanvasBackend = CanvasBackend.rustWgpu;

const double _stylusCurveLowerBound = 0.25;
const double _stylusCurveUpperBound = 3.2;
