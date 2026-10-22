import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/features/rollcall/qr_payload.dart';

/// Full-screen camera QR capture; pops with raw barcode string.
class QrScanCameraPage extends StatefulWidget {
  const QrScanCameraPage({super.key, this.rollcallId, this.courseId});
  final int? rollcallId;
  final String? courseId;

  @override
  State<QrScanCameraPage> createState() => _QrScanCameraPageState();
}

class _QrScanCameraPageState extends State<QrScanCameraPage> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );
  var _handled = false;
  String? _lastRejected;
  MobileScannerErrorCode? _lastError;

  @override
  void initState() {
    super.initState();
    AppLog.event('qr.scan.open', fields: {'rollcallId': widget.rollcallId});
    _controller.addListener(_cameraChanged);
  }

  void _cameraChanged() {
    final error = _controller.value.error;
    if (error == null || error.errorCode == _lastError) return;
    _lastError = error.errorCode;
    AppLog.event(
      'qr.scan.camera_error',
      level: 'W',
      fields: {
        'rollcallId': widget.rollcallId,
        'errorCode': error.errorCode.name,
      },
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_cameraChanged);
    _controller.dispose();
    AppLog.event(
      'qr.scan.close',
      fields: {'rollcallId': widget.rollcallId, 'captured': _handled},
    );
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;
      try {
        parseQrRollcallData(
          raw,
          expectedRollcallId: widget.rollcallId,
          expectedCourseId: widget.courseId,
        );
      } on FormatException catch (error) {
        if (_lastRejected != raw) {
          _lastRejected = raw;
          AppLog.event(
            'qr.scan.rejected',
            level: 'W',
            fields: {'rollcallId': widget.rollcallId, 'reason': error.message},
          );
          AppToast.show(context, error.message, error: true);
        }
        continue;
      }
      _handled = true;
      AppLog.event(
        'qr.scan.detected',
        fields: {'rollcallId': widget.rollcallId, 'payloadLen': raw.length},
      );
      Navigator.of(context).pop(raw);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubpageScaffold(
      title: '扫描二维码',
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            onDetectError: (error, stack) => AppLog.logAppError(
              error: error,
              stackTrace: stack,
              source: 'qr.scan.detect',
            ),
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography_outlined, size: 40),
                    const SizedBox(height: 16),
                    Text(
                      error.errorCode == MobileScannerErrorCode.permissionDenied
                          ? '未获得相机权限，请在系统设置中允许使用相机后重试。'
                          : '相机暂时不可用，请重试或返回粘贴二维码内容。',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () async {
                        try {
                          await _controller.start();
                        } catch (e, st) {
                          AppLog.logAppError(
                            error: e,
                            stackTrace: st,
                            source: 'qr.scan.retry',
                          );
                        }
                      },
                      child: const Text('重试相机'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: IgnorePointer(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    onPressed: () async {
                      try {
                        await _controller.toggleTorch();
                      } catch (e, st) {
                        AppLog.logAppError(
                          error: e,
                          stackTrace: st,
                          source: 'qr.scan.torch',
                        );
                      }
                    },
                    tooltip: '开关补光灯',
                    icon: const Icon(Icons.flashlight_on_outlined),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '将老师屏幕上的二维码置于框内',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                      shadows: const [
                        Shadow(blurRadius: 8, color: Colors.black54),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
