import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// Runs in a worker isolate. Screen pixels are never persisted or uploaded.
String? decodeDesktopQrFrame(Map<String, Object> frame) {
  final width = frame['width'] as int;
  final height = frame['height'] as int;
  final bytes = frame['bgra'] as Uint8List;
  if (width <= 0 ||
      height <= 0 ||
      width > 2048 ||
      height > 2048 ||
      bytes.length != width * height * 4) {
    return null;
  }
  final pixels = Int32List(width * height);
  for (var i = 0; i < pixels.length; i++) {
    final offset = i * 4;
    pixels[i] =
        (bytes[offset + 2] << 16) | (bytes[offset + 1] << 8) | bytes[offset];
  }
  return _decode(width, height, pixels);
}

String? _decode(int width, int height, Int32List pixels) {
  final source = RGBLuminanceSource(width, height, pixels);
  for (final input in [source, source.invert()]) {
    try {
      final hints = DecodeHints()..put(DecodeHintType.tryHarder);
      return QRCodeReader()
          .decode(BinaryBitmap(HybridBinarizer(input)), hints: hints)
          .text;
    } on ReaderException {
      // No QR, or not yet fully inside the frame: wait for the next sample.
    }
  }
  return null;
}

String? decodeDesktopQrImage(String path) {
  final file = File(path);
  if (!file.existsSync() || file.lengthSync() > 25 * 1024 * 1024) {
    throw const FormatException('图片不存在或超过 25 MB');
  }
  final bytes = file.readAsBytesSync();
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null || info.width * info.height > 40 * 1000 * 1000) {
    throw const FormatException('图片格式不支持或尺寸过大');
  }
  var image = decoder!.decodeFrame(0);
  if (image == null) throw const FormatException('无法读取图片');
  image = img.bakeOrientation(image);
  if (image.width > 1800 || image.height > 1800) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? 1800 : null,
      height: image.height > image.width ? 1800 : null,
    );
  }
  final pixels = Int32List(image.width * image.height);
  for (final pixel in image) {
    // Composite transparent PNG pixels over white, preserving QR quiet zones.
    final alpha = pixel.aNormalized;
    final r = (pixel.r * alpha + 255 * (1 - alpha)).round();
    final g = (pixel.g * alpha + 255 * (1 - alpha)).round();
    final b = (pixel.b * alpha + 255 * (1 - alpha)).round();
    pixels[pixel.y * image.width + pixel.x] = (r << 16) | (g << 8) | b;
  }
  return _decode(image.width, image.height, pixels);
}
