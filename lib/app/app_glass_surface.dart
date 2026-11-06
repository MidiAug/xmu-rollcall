import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Frosted chrome is clipped to its own bounds. Static content surfaces use
/// blur=0 so scrolling data never pays for a backdrop filter per row.
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.blur = 18,
    this.opacity = .78,
    this.cacheShadows = false,
  });
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final double blur, opacity;

  /// Opt-in for static surfaces that otherwise compile size-dependent blur
  /// shaders during Windows resizing. Backdrop-filtered surfaces stay vector.
  final bool cacheShadows;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final radius = borderRadius ?? BorderRadius.circular(AppRadii.island);
    final highContrast = MediaQuery.highContrastOf(context);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: highContrast ? p.surface : null,
        gradient: highContrast
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  p.surface.withValues(alpha: opacity == 1 ? 1 : .97),
                  Color.lerp(
                    p.surface,
                    p.surfaceHigh,
                    p.isDark ? .20 : .32,
                  )!.withValues(alpha: opacity),
                ],
              ),
        border: Border.all(
          color: p.isDark
              ? Colors.white.withValues(alpha: .12)
              : p.border.withValues(alpha: .8),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
    final shadows = BoxDecoration(
      borderRadius: radius,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: p.isDark ? .18 : .045),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: p.isDark ? .08 : .025),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ],
    );
    final clipped = ClipRRect(
      borderRadius: radius,
      child: blur > 0 && !highContrast
          ? BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: surface,
            )
          : surface,
    );
    return blur == 0 && cacheShadows
        ? _CachedSurfaceShadow(decoration: shadows, child: clipped)
        : DecoratedBox(decoration: shadows, child: clipped);
  }
}

// Only a flat middle strip is stretched; corners and falloff retain their
// device-pixel size. Smaller surfaces keep the original vector shadows.
class _ShadowMetrics {
  _ShadowMetrics(BoxDecoration decoration, this.dpr) {
    final r = decoration.borderRadius! as BorderRadius;
    final radius = [
      r.topLeft.x,
      r.topLeft.y,
      r.topRight.x,
      r.topRight.y,
      r.bottomLeft.x,
      r.bottomLeft.y,
      r.bottomRight.x,
      r.bottomRight.y,
    ].reduce(math.max);
    var left = 0.0, right = 0.0, top = 0.0, bottom = 0.0, padding = 0.0;
    for (final shadow in decoration.boxShadow!) {
      final falloff = shadow.blurSigma * 3 + shadow.spreadRadius.abs();
      left = math.max(left, radius + falloff + shadow.offset.dx);
      right = math.max(right, radius + falloff - shadow.offset.dx);
      top = math.max(top, radius + falloff + shadow.offset.dy);
      bottom = math.max(bottom, radius + falloff - shadow.offset.dy);
      padding = math.max(
        padding,
        falloff + math.max(shadow.offset.dx.abs(), shadow.offset.dy.abs()) + 2,
      );
    }
    final lp = (left * dpr).ceil(),
        rp = (right * dpr).ceil(),
        tp = (top * dpr).ceil(),
        bp = (bottom * dpr).ceil();
    final pad = (padding * dpr).ceil();
    inset = pad / dpr;
    base = Size((lp + rp + 1) / dpr, (tp + bp + 1) / dpr);
    pixels = Size(
      (lp + rp + 1 + 2 * pad).toDouble(),
      (tp + bp + 1 + 2 * pad).toDouble(),
    );
    // Image.centerSlice is logical: paintImage multiplies it by ImageInfo.scale.
    center = Rect.fromLTWH(
      (pad + lp) / dpr,
      (pad + tp) / dpr,
      1 / dpr,
      1 / dpr,
    );
  }
  final double dpr;
  late final double inset;
  late final Size base, pixels;
  late final Rect center;
}

typedef _ShadowImageKey = ({BoxDecoration decoration, double dpr});

class _SurfaceShadowImage extends ImageProvider<_ShadowImageKey> {
  const _SurfaceShadowImage(this.decoration);
  final BoxDecoration decoration;
  @override
  Future<_ShadowImageKey> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture((
        decoration: decoration,
        dpr: configuration.devicePixelRatio ?? 1,
      ));
  @override
  ImageStreamCompleter loadImage(
    _ShadowImageKey key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(_generate(key));
  Future<ImageInfo> _generate(_ShadowImageKey key) async {
    final m = _ShadowMetrics(key.decoration, key.dpr);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(key.dpr);
    final painter = key.decoration.createBoxPainter();
    painter.paint(
      canvas,
      Offset(m.inset, m.inset),
      ImageConfiguration(size: m.base),
    );
    painter.dispose();
    final picture = recorder.endRecording();
    try {
      return ImageInfo(
        image: await picture.toImage(
          m.pixels.width.toInt(),
          m.pixels.height.toInt(),
        ),
        scale: key.dpr,
      );
    } finally {
      picture.dispose();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is _SurfaceShadowImage && decoration == other.decoration;
  @override
  int get hashCode => decoration.hashCode;
}

class _CachedSurfaceShadow extends StatelessWidget {
  const _CachedSurfaceShadow({required this.decoration, required this.child});
  final BoxDecoration decoration;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final m = _ShadowMetrics(
      decoration,
      MediaQuery.devicePixelRatioOf(context),
    );
    Widget fallback() => Padding(
      padding: EdgeInsets.all(m.inset),
      child: DecoratedBox(decoration: decoration),
    );
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          left: -m.inset,
          right: -m.inset,
          top: -m.inset,
          bottom: -m.inset,
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, bounds) {
                if (bounds.maxWidth - 2 * m.inset < m.base.width ||
                    bounds.maxHeight - 2 * m.inset < m.base.height) {
                  return fallback();
                }
                return Image(
                  image: _SurfaceShadowImage(decoration),
                  centerSlice: m.center,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.low,
                  excludeFromSemantics: true,
                  frameBuilder: (context, image, frame, synchronous) =>
                      frame == null ? fallback() : image,
                  errorBuilder: (context, error, stack) => fallback(),
                );
              },
            ),
          ),
        ),
        child,
      ],
    );
  }
}
