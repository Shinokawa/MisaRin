part of 'controller.dart';

bool _controllerRunAntialiasPass(
  BitmapCanvasController _,
  Uint32List src,
  Uint32List dest,
  int width,
  int height,
  double blendFactor,
) {
  dest.setAll(0, src);
  if (blendFactor <= 0) {
    return false;
  }
  final double factor = blendFactor.clamp(0.0, 1.0);
  bool modified = false;
  for (int y = 0; y < height; y++) {
    final int rowOffset = y * width;
    for (int x = 0; x < width; x++) {
      final int index = rowOffset + x;
      final int center = src[index];
      final int alpha = (center >> 24) & 0xff;
      final int centerR = (center >> 16) & 0xff;
      final int centerG = (center >> 8) & 0xff;
      final int centerB = center & 0xff;

      int totalWeight = BitmapCanvasController._kAntialiasCenterWeight;
      int weightedAlpha = alpha *
          BitmapCanvasController._kAntialiasCenterWeight;
      int weightedPremulR = centerR * alpha *
          BitmapCanvasController._kAntialiasCenterWeight;
      int weightedPremulG = centerG * alpha *
          BitmapCanvasController._kAntialiasCenterWeight;
      int weightedPremulB = centerB * alpha *
          BitmapCanvasController._kAntialiasCenterWeight;

      for (int i = 0;
          i < BitmapCanvasController._kAntialiasDx.length;
          i++) {
        final int nx = x + BitmapCanvasController._kAntialiasDx[i];
        final int ny = y + BitmapCanvasController._kAntialiasDy[i];
        if (nx < 0 || nx >= width || ny < 0 || ny >= height) {
          continue;
        }
        final int neighbor = src[ny * width + nx];
        final int neighborAlpha = (neighbor >> 24) & 0xff;
        final int weight = BitmapCanvasController._kAntialiasWeights[i];
        totalWeight += weight;
        if (neighborAlpha == 0) {
          continue;
        }
        weightedAlpha += neighborAlpha * weight;
        weightedPremulR += ((neighbor >> 16) & 0xff) * neighborAlpha * weight;
        weightedPremulG += ((neighbor >> 8) & 0xff) * neighborAlpha * weight;
        weightedPremulB += (neighbor & 0xff) * neighborAlpha * weight;
      }

      if (totalWeight <= 0) {
        continue;
      }

      final int candidateAlpha = (weightedAlpha ~/ totalWeight).clamp(0, 255);
      final int deltaAlpha = candidateAlpha - alpha;
      if (deltaAlpha == 0) {
        continue;
      }

      final int newAlpha = (alpha + (deltaAlpha * factor).round()).clamp(
        0,
        255,
      );
      if (newAlpha == alpha) {
        continue;
      }

      int newR = centerR;
      int newG = centerG;
      int newB = centerB;
      if (deltaAlpha > 0) {
        final int boundedWeightedAlpha = math.max(weightedAlpha, 1);
        newR = (weightedPremulR ~/ boundedWeightedAlpha).clamp(0, 255);
        newG = (weightedPremulG ~/ boundedWeightedAlpha).clamp(0, 255);
        newB = (weightedPremulB ~/ boundedWeightedAlpha).clamp(0, 255);
      }

      dest[index] = (newAlpha << 24) | (newR << 16) | (newG << 8) | newB;
      modified = true;
    }
  }
  return modified;
}

bool _controllerRunEdgeAwareColorSmoothPass(
  BitmapCanvasController _,
  Uint32List src,
  Uint32List dest,
  Uint32List blurBuffer,
  int width,
  int height,
) {
  _controllerComputeGaussianBlur(src, blurBuffer, width, height);
  bool modified = false;
  for (int y = 0; y < height; y++) {
    final int rowOffset = y * width;
    for (int x = 0; x < width; x++) {
      final int index = rowOffset + x;
      final int baseColor = src[index];
      final int alpha = (baseColor >> 24) & 0xff;
      if (alpha == 0) {
        dest[index] = baseColor;
        continue;
      }

      final double gradient =
          _controllerComputeEdgeGradient(src, width, height, x, y);
      final double weight = _controllerEdgeSmoothWeight(gradient);
      if (weight <= 0) {
        dest[index] = baseColor;
        continue;
      }
      final int blurred = blurBuffer[index];
      final int newColor = _controllerLerpArgb(baseColor, blurred, weight);
      dest[index] = newColor;
      if (newColor != baseColor) {
        modified = true;
      }
    }
  }
  return modified;
}

double _controllerComputeEdgeGradient(
  Uint32List src,
  int width,
  int height,
  int x,
  int y,
) {
  final int index = y * width + x;
  final int center = src[index];
  final int alpha = (center >> 24) & 0xff;
  if (alpha == 0) {
    return 0;
  }
  final double centerLuma = _controllerComputeLuma(center);
  double maxDiff = 0;

  void accumulate(int nx, int ny) {
    if (nx < 0 || nx >= width || ny < 0 || ny >= height) {
      return;
    }
    final int neighbor = src[ny * width + nx];
    final int neighborAlpha = (neighbor >> 24) & 0xff;
    if (neighborAlpha == 0) {
      return;
    }
    final double diff = (centerLuma - _controllerComputeLuma(neighbor)).abs();
    if (diff > maxDiff) {
      maxDiff = diff;
    }
  }

  accumulate(x - 1, y);
  accumulate(x + 1, y);
  accumulate(x, y - 1);
  accumulate(x, y + 1);
  accumulate(x - 1, y - 1);
  accumulate(x + 1, y - 1);
  accumulate(x - 1, y + 1);
  accumulate(x + 1, y + 1);
  return maxDiff;
}

double _controllerEdgeSmoothWeight(double gradient) {
  if (gradient <= BitmapCanvasController._kEdgeDetectMin) {
    return 0;
  }
  final double normalized =
      ((gradient - BitmapCanvasController._kEdgeDetectMin) /
              (BitmapCanvasController._kEdgeDetectMax -
                  BitmapCanvasController._kEdgeDetectMin))
          .clamp(0.0, 1.0);
  return math.pow(normalized, BitmapCanvasController._kEdgeSmoothGamma) *
      BitmapCanvasController._kEdgeSmoothStrength;
}

void _controllerComputeGaussianBlur(
  Uint32List src,
  Uint32List dest,
  int width,
  int height,
) {
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      double weightedAlpha = 0;
      double weightedR = 0;
      double weightedG = 0;
      double weightedB = 0;
      double totalWeight = 0;
      int kernelIndex = 0;
      for (int ky = -2; ky <= 2; ky++) {
        final int ny = (y + ky).clamp(0, height - 1);
        final int rowOffset = ny * width;
        for (int kx = -2; kx <= 2; kx++) {
          final int nx = (x + kx).clamp(0, width - 1);
          final int weight = BitmapCanvasController._kGaussianKernel5x5[
              kernelIndex++];
          final int sample = src[rowOffset + nx];
          final int alpha = (sample >> 24) & 0xff;
          if (alpha == 0) {
            continue;
          }
          totalWeight += weight;
          weightedAlpha += alpha * weight;
          weightedR += ((sample >> 16) & 0xff) * alpha * weight;
          weightedG += ((sample >> 8) & 0xff) * alpha * weight;
          weightedB += (sample & 0xff) * alpha * weight;
        }
      }
      if (totalWeight == 0) {
        dest[y * width + x] = src[y * width + x];
        continue;
      }
      final double normalizedAlpha = weightedAlpha / totalWeight;
      final double premulAlpha = math.max(weightedAlpha, 1.0);
      final int outAlpha = normalizedAlpha.round().clamp(0, 255);
      final int outR = (weightedR / premulAlpha).round().clamp(0, 255);
      final int outG = (weightedG / premulAlpha).round().clamp(0, 255);
      final int outB = (weightedB / premulAlpha).round().clamp(0, 255);
      dest[y * width + x] =
          (outAlpha << 24) | (outR << 16) | (outG << 8) | outB;
    }
  }
}

double _controllerComputeLuma(int color) {
  final int alpha = (color >> 24) & 0xff;
  if (alpha == 0) {
    return 0;
  }
  final int r = (color >> 16) & 0xff;
  final int g = (color >> 8) & 0xff;
  final int b = color & 0xff;
  return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
}

int _controllerLerpArgb(int a, int b, double t) {
  final double clampedT = t.clamp(0.0, 1.0);
  int lerpChannel(int ca, int cb) =>
      (ca + ((cb - ca) * clampedT).round()).clamp(0, 255);

  final int aA = (a >> 24) & 0xff;
  final int aR = (a >> 16) & 0xff;
  final int aG = (a >> 8) & 0xff;
  final int aB = a & 0xff;

  final int bA = (b >> 24) & 0xff;
  final int bR = (b >> 16) & 0xff;
  final int bG = (b >> 8) & 0xff;
  final int bB = b & 0xff;

  final int outA = lerpChannel(aA, bA);
  final int outR = lerpChannel(aR, bR);
  final int outG = lerpChannel(aG, bG);
  final int outB = lerpChannel(aB, bB);
  return (outA << 24) | (outR << 16) | (outG << 8) | outB;
}

bool _controllerApplyAntialiasToActiveLayerRustCpu(
  BitmapCanvasController controller,
  int level, {
  bool previewOnly = false,
}) {
  if (controller._layers.isEmpty) {
    return false;
  }
  final BitmapLayerState layer = controller._activeLayer;
  if (layer.locked) {
    return false;
  }
  final LayerSurface layerSurface = layer.surface;
  if (layerSurface.isTiled) {
    if (!RustCpuFiltersFfi.instance.isSupported) {
      return false;
    }
    final TiledSurface tiled = layerSurface.tiledSurface!;
    final RasterIntRect? contentBounds = tiled.contentBounds();
    if (contentBounds == null || contentBounds.isEmpty) {
      return false;
    }
    const int pad = 2;
    final int expandedLeft = math.max(0, contentBounds.left - pad);
    final int expandedTop = math.max(0, contentBounds.top - pad);
    final int expandedRight =
        math.min(controller._width, contentBounds.right + pad);
    final int expandedBottom =
        math.min(controller._height, contentBounds.bottom + pad);
    if (expandedLeft >= expandedRight || expandedTop >= expandedBottom) {
      return false;
    }
    final RasterIntRect expandedBounds = RasterIntRect(
      expandedLeft,
      expandedTop,
      expandedRight,
      expandedBottom,
    );
    final Uint32List snapshot = layerSurface.readRect(expandedBounds);
    if (snapshot.isEmpty) {
      return false;
    }

    final int tileSize = tiled.tileSize;
    final int startTx = tileIndexForCoord(expandedBounds.left, tileSize);
    final int endTx = tileIndexForCoord(expandedBounds.right - 1, tileSize);
    final int startTy = tileIndexForCoord(expandedBounds.top, tileSize);
    final int endTy = tileIndexForCoord(expandedBounds.bottom - 1, tileSize);

    bool anyChange = false;
    final List<RasterIntRect> patchRects = <RasterIntRect>[];
    final List<Uint32List> patchPixels = <Uint32List>[];

    for (int ty = startTy; ty <= endTy; ty++) {
      for (int tx = startTx; tx <= endTx; tx++) {
        final RasterIntRect tileRect = tileBounds(tx, ty, tileSize);
        final int tileLeft = tileRect.left.clamp(0, controller._width);
        final int tileTop = tileRect.top.clamp(0, controller._height);
        final int tileRight = tileRect.right.clamp(0, controller._width);
        final int tileBottom = tileRect.bottom.clamp(0, controller._height);
        if (tileLeft >= tileRight || tileTop >= tileBottom) {
          continue;
        }
        final RasterIntRect clippedTile =
            RasterIntRect(tileLeft, tileTop, tileRight, tileBottom);

        final int expLeft = math.max(expandedBounds.left, tileLeft - pad);
        final int expTop = math.max(expandedBounds.top, tileTop - pad);
        final int expRight =
            math.min(expandedBounds.right, tileRight + pad);
        final int expBottom =
            math.min(expandedBounds.bottom, tileBottom + pad);
        if (expLeft >= expRight || expTop >= expBottom) {
          continue;
        }
        final RasterIntRect expandedRect =
            RasterIntRect(expLeft, expTop, expRight, expBottom);
        final RasterIntRect snapshotLocal = RasterIntRect(
          expandedRect.left - expandedBounds.left,
          expandedRect.top - expandedBounds.top,
          expandedRect.right - expandedBounds.left,
          expandedRect.bottom - expandedBounds.top,
        );
        final Uint32List expandedPixels = _controllerCopySurfaceRegion(
          snapshot,
          expandedBounds.width,
          snapshotLocal,
        );
        if (expandedPixels.isEmpty) {
          continue;
        }
        final BitmapSurface tempSurface = BitmapSurface(
          width: expandedRect.width,
          height: expandedRect.height,
        );
        tempSurface.pixels.setAll(0, expandedPixels);
        final bool ok = RustCpuFiltersFfi.instance.applyAntialias(
          pixelsPtr: tempSurface.pointerAddress,
          pixelsLen: tempSurface.pixels.length,
          width: expandedRect.width,
          height: expandedRect.height,
          level: level.clamp(0, 9),
          previewOnly: previewOnly,
        );
        if (!ok) {
          tempSurface.dispose();
          continue;
        }
        anyChange = true;
        if (previewOnly) {
          tempSurface.dispose();
          return true;
        }

        final RasterIntRect localCore = RasterIntRect(
          clippedTile.left - expandedRect.left,
          clippedTile.top - expandedRect.top,
          clippedTile.right - expandedRect.left,
          clippedTile.bottom - expandedRect.top,
        );
        if (!localCore.isEmpty) {
          final Uint32List patch = _controllerCopySurfaceRegion(
            tempSurface.pixels,
            expandedRect.width,
            localCore,
          );
          patchRects.add(clippedTile);
          patchPixels.add(patch);
        }
        tempSurface.dispose();
      }
    }

    if (!anyChange || previewOnly) {
      return anyChange;
    }
    for (int i = 0; i < patchRects.length; i++) {
      layerSurface.writeRect(patchRects[i], patchPixels[i]);
    }
    controller._markDirty(
      region: Rect.fromLTRB(
        expandedBounds.left.toDouble(),
        expandedBounds.top.toDouble(),
        expandedBounds.right.toDouble(),
        expandedBounds.bottom.toDouble(),
      ),
      layerId: layer.id,
      pixelsDirty: true,
    );
    controller._notify();
    return true;
  }
  return layerSurface.withBitmapSurface(
    writeBack: !previewOnly,
    action: (BitmapSurface surface) {
      final Uint32List pixels = surface.pixels;
      if (pixels.isEmpty) {
        return false;
      }
      if (!RustCpuFiltersFfi.instance.isSupported ||
          surface.pointerAddress == 0) {
        return false;
      }
      final bool ok = RustCpuFiltersFfi.instance.applyAntialias(
        pixelsPtr: surface.pointerAddress,
        pixelsLen: pixels.length,
        width: controller._width,
        height: controller._height,
        level: level.clamp(0, 9),
        previewOnly: previewOnly,
      );
      if (!ok) {
        return false;
      }
      if (!previewOnly) {
        surface.markDirty();
        controller._markDirty(layerId: layer.id, pixelsDirty: true);
        controller._notify();
      }
      return true;
    },
  );
}
