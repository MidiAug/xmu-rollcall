import 'package:flutter/material.dart';
import 'dart:async';
import 'package:window_manager/window_manager.dart';
import 'package:zxing2/qrcode.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/platform/desktop_qr_scanner.dart';

const desktopQrPreviewPayload =
    'https://c-mobile.xmu.edu.cn/j?p=0~%10dx!3~DEVELOPMENT_PREVIEW_ONLY!4~%106y1';

class DesktopQrPreviewApp extends StatelessWidget {
  const DesktopQrPreviewApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    home: const DesktopQrPreviewPage(autoOpen: true),
  );
}

class DesktopQrPreviewPage extends StatefulWidget {
  const DesktopQrPreviewPage({super.key, this.autoOpen = false});
  final bool autoOpen;
  @override
  State<DesktopQrPreviewPage> createState() => _DesktopQrPreviewPageState();
}

class _DesktopQrPreviewPageState extends State<DesktopQrPreviewPage> {
  bool _open = false;
  String _status = '点击“扫码签到”，主窗口旁会额外出现透明扫码窗。';
  @override
  void initState() {
    super.initState();
    if (widget.autoOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
    }
  }

  Future<void> _scan() async {
    if (_open || !mounted) return;
    setState(() {
      _open = true;
      _status = '扫码窗已打开：拖动它覆盖左侧二维码，或拖入/选择一张图片。';
    });
    try {
      final raw = await DesktopQrScanner.open(preview: true);
      if (mounted) {
        setState(
          () => _status = raw == null
              ? '已关闭扫码窗。可以再次打开。'
              : raw == desktopQrPreviewPayload
              ? '已识别预览二维码。没有提交签到，可以再次测试。'
              : '识别成功：${raw.length} 个字符。预览模式没有提交签到。',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _status = '扫码窗打开失败，请查看诊断日志。');
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }

  @override
  void dispose() {
    if (_open) unawaited(DesktopQrScanner.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff3f5f7),
    body: Column(
      children: [
        DragToMoveArea(
          child: Container(
            height: 54,
            padding: const EdgeInsets.only(left: 24, right: 12),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner, size: 19),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '电脑扫码  开发预览',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: '关闭预览',
                  onPressed: () => windowManager.close(),
                  icon: const Icon(Icons.close, size: 19),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Wrap(
              spacing: 36,
              runSpacing: 28,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 280,
                        height: 280,
                        child: CustomPaint(painter: PreviewQrPainter()),
                      ),
                      SizedBox(height: 16),
                      Text('把透明识别框拖到这个二维码上方'),
                    ],
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '主程序保留\n扫码框独立弹出',
                        style: TextStyle(
                          fontSize: 27,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '• 拖动标题栏或透明区域移动窗口\n• 拖动边框调整识别范围\n• 把图片拖进框内，或点击“选择图片”\n• 暂停按钮只暂停屏幕识别\n• 本页只做本地识别，不登录、不签到',
                        style: TextStyle(height: 1.9, color: Color(0xff566272)),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _open ? null : _scan,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(_open ? '扫码窗口已打开' : '扫码签到'),
                      ),
                      const SizedBox(height: 20),
                      Text(_status, style: const TextStyle(height: 1.6)),
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

class PreviewQrPainter extends CustomPainter {
  const PreviewQrPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final matrix = Encoder.encode(
      desktopQrPreviewPayload,
      ErrorCorrectionLevel.m,
    ).matrix!;
    final cell = size.shortestSide / (matrix.width + 8);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final paint = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (var y = 0; y < matrix.height; y++) {
      for (var x = 0; x < matrix.width; x++) {
        if (matrix.get(x, y) == 1) {
          canvas.drawRect(
            Rect.fromLTWH(
              (x + 4) * cell,
              (y + 4) * cell,
              cell + 0.1,
              cell + 0.1,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
