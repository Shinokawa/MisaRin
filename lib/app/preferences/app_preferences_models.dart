part of 'app_preferences.dart';

enum PenStrokeSliderRange {
  compact(min: 1.0, max: 60.0),
  medium(min: 0.1, max: 500.0),
  full(min: 0.01, max: 1000.0);

  const PenStrokeSliderRange({required this.min, required this.max});

  final double min;
  final double max;

  double clamp(double value) {
    final num clamped = value.clamp(min, max);
    return clamped.toDouble();
  }
}

enum BucketSwallowColorLineMode { all, red, green, blue }
