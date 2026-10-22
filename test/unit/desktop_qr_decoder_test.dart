import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';
import 'package:xmu_rollcall/features/rollcall/desktop_qr_decoder.dart';

const _payload =
    'https://c-mobile.xmu.edu.cn/j?p=0~%10dx!3~DEVELOPMENT_PREVIEW_ONLY!4~%106y1';

img.Image sample({bool inverted = false, bool transparent = false}) {
  final matrix = Encoder.encode(_payload, ErrorCorrectionLevel.m).matrix!;
  const cell = 8;
  final size = (matrix.width + 8) * cell;
  final image = img.Image(width: size, height: size, numChannels: 4);
  img.fill(
    image,
    color: img.ColorRgba8(
      inverted ? 0 : 255,
      inverted ? 0 : 255,
      inverted ? 0 : 255,
      transparent ? 0 : 255,
    ),
  );
  for (var y = 0; y < matrix.height; y++) {
    for (var x = 0; x < matrix.width; x++) {
      if (matrix.get(x, y) == 1) {
        for (var dy = 0; dy < cell; dy++) {
          for (var dx = 0; dx < cell; dx++) {
            final value = inverted ? 255 : 0;
            image.setPixelRgba(
              (x + 4) * cell + dx,
              (y + 4) * cell + dy,
              value,
              value,
              value,
              255,
            );
          }
        }
      }
    }
  }
  return image;
}

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('xmu_desktop_qr_test_');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  test('screen BGRA pixels decode regular and inverted QR codes', () {
    for (final inverted in [false, true]) {
      final image = sample(inverted: inverted);
      expect(
        decodeDesktopQrFrame({
          'width': image.width,
          'height': image.height,
          'bgra': image.getBytes(order: img.ChannelOrder.bgra),
        }),
        _payload,
      );
    }
  });
  test(
    'image path supports PNG, transparent PNG, JPEG and rotated QR',
    () async {
      final images = [
        sample(),
        sample(transparent: true),
        img.copyRotate(sample(), angle: 90),
      ];
      for (var i = 0; i < images.length; i++) {
        final file = File('${directory.path}/$i.png');
        await file.writeAsBytes(img.encodePng(images[i]));
        expect(decodeDesktopQrImage(file.path), _payload);
      }
      final jpeg = File('${directory.path}/photo.jpg');
      await jpeg.writeAsBytes(img.encodeJpg(sample(), quality: 90));
      expect(decodeDesktopQrImage(jpeg.path), _payload);
      if (const bool.fromEnvironment('WRITE_DESKTOP_QR_SAMPLES')) {
        final samples = await Directory(
          '.dart_tool/desktop-qr-preview',
        ).create(recursive: true);
        await File(
          '${samples.path}/二维码样例.png',
        ).writeAsBytes(img.encodePng(sample()));
        await File(
          '${samples.path}/透明背景二维码.png',
        ).writeAsBytes(img.encodePng(sample(transparent: true)));
        await jpeg.copy('${samples.path}/二维码照片.jpg');
      }
    },
  );
  test('blank frames and malformed frame sizes do not decode', () {
    expect(
      decodeDesktopQrFrame({
        'width': 100,
        'height': 100,
        'bgra': Uint8List(40000)..fillRange(0, 40000, 255),
      }),
      isNull,
    );
    expect(
      decodeDesktopQrFrame({
        'width': 9999,
        'height': 9999,
        'bgra': Uint8List(0),
      }),
      isNull,
    );
    expect(
      decodeDesktopQrFrame({'width': 10, 'height': 10, 'bgra': Uint8List(1)}),
      isNull,
    );
  });
  test(
    'missing and unsupported files fail without starting screen capture',
    () async {
      expect(
        () => decodeDesktopQrImage('${directory.path}/missing.png'),
        throwsFormatException,
      );
      final invalid = await File(
        '${directory.path}/invalid.png',
      ).writeAsString('not an image');
      expect(() => decodeDesktopQrImage(invalid.path), throwsFormatException);
    },
  );
}
