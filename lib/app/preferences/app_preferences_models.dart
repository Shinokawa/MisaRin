part of 'app_preferences.dart';

enum PenStrokeSliderRange {
  compact(min: 1.0, max: 60.0),
  medium(min: 1.0, max: 500.0),
  full(min: 1.0, max: 1000.0),
  huge(min: 1.0, max: 5000.0);

  const PenStrokeSliderRange({required this.min, required this.max});

  final double min;
  final double max;

  double clamp(double value) {
    final num clamped = value.clamp(min, max);
    return clamped.toDouble();
  }

  PenStrokeSliderRange next() {
    switch (this) {
      case PenStrokeSliderRange.compact:
        return PenStrokeSliderRange.medium;
      case PenStrokeSliderRange.medium:
        return PenStrokeSliderRange.full;
      case PenStrokeSliderRange.full:
        return PenStrokeSliderRange.huge;
      case PenStrokeSliderRange.huge:
        return PenStrokeSliderRange.compact;
    }
  }
}

enum BucketSwallowColorLineMode { all, red, green, blue }
