import 'dart:io';
import 'package:image/image.dart' as img;

// Run from the repository root: dart run scripts/generate_tray_status_icons.dart
// Retain the existing brand icon and draw a static status badge at each DPI.
void main() {
  final base = img.decodePng(
    File('assets/tray/tray_icon.png').readAsBytesSync(),
  )!;
  img.Image active(int size) {
    final canvas = img.copyResize(base, width: size * 4, height: size * 4);
    final scale = canvas.width;
    for (final badge in [
      (radius: .17, color: img.ColorRgb8(255, 255, 255)),
      (radius: .125, color: img.ColorRgb8(22, 163, 74)),
    ]) {
      img.fillCircle(
        canvas,
        x: (scale * .79).round(),
        y: (scale * .20).round(),
        radius: (scale * badge.radius).round(),
        color: badge.color,
        antialias: true,
      );
    }
    return img.copyResize(
      canvas,
      width: size,
      height: size,
      interpolation: img.Interpolation.average,
    );
  }

  File(
    'assets/tray/tray_icon_active.png',
  ).writeAsBytesSync(img.encodePng(active(256)));
  File('assets/tray/tray_icon_active.ico').writeAsBytesSync(
    img.IcoEncoder().encodeImages([
      for (final size in [16, 20, 24, 32, 40, 48, 64, 128, 256]) active(size),
    ]),
  );
}
