import 'package:misa_rin/l10n/app_localizations.dart';

enum ImageResizeSampling {
  nearest,
  bilinear,
}

extension ImageResizeSamplingTexts on ImageResizeSampling {
  String label(AppLocalizations l10n) {
    switch (this) {
      case ImageResizeSampling.nearest:
        return l10n.samplingNearestLabel;
      case ImageResizeSampling.bilinear:
        return l10n.samplingBilinearLabel;
    }
  }

  String description(AppLocalizations l10n) {
    switch (this) {
      case ImageResizeSampling.nearest:
        return l10n.samplingNearestDesc;
      case ImageResizeSampling.bilinear:
        return l10n.samplingBilinearDesc;
    }
  }
}
