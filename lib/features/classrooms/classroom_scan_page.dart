import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/rollcall/qr_scan_frame.dart';
import 'classroom_catalog_page.dart';
import 'classroom_page_session.dart';

String? classroomRoomFromQr(String text) {
  try {
    final u = Uri.tryParse(text.trim());
    if (u == null || u.scheme != 'https' || u.host != 'eclass.xmu.edu.cn') {
      return null;
    }
    final q = {
      ...u.queryParameters,
      if (u.fragment.contains('?'))
        ...Uri.splitQueryString(
          u.fragment.substring(u.fragment.indexOf('?') + 1),
        ),
    };
    final id = q['room_id'] ?? q['id'];
    return id != null &&
            RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
            ).hasMatch(id)
        ? id
        : null;
  } on FormatException {
    return null;
  }
}

class ClassroomScanPage extends ConsumerStatefulWidget {
  const ClassroomScanPage({super.key});
  @override
  ConsumerState<ClassroomScanPage> createState() => _ScanState();
}

class _ScanState extends ConsumerState<ClassroomScanPage>
    with ClassroomPageSession<ClassroomScanPage> {
  final text = TextEditingController();
  MobileScannerController? camera;
  bool opening = false;
  @override
  void dispose() {
    text.dispose();
    camera?.dispose();
    super.dispose();
  }

  Future<void> open(String raw) async {
    if (opening || !current) return;
    final room = classroomRoomFromQr(raw);
    if (room == null) {
      setState(() => error = '这不是可识别的厦大教室码');
      return;
    }
    setState(() {
      opening = true;
      error = null;
    });
    await camera?.stop();
    if (!mounted || !current) return;
    await AppPageRoutes.push<void>(context, ClassroomDetailPage(id: room));
    if (current) {
      setState(() => opening = false);
      await camera?.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    watchSession();
    final p = Theme.of(context).platform;
    return SubpageScaffold(
      title: '扫一扫',
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            if (camera != null)
              SizedBox(
                height: 320,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: camera!,
                      onDetect: (c) {
                        for (final b in c.barcodes) {
                          if (b.rawValue != null) open(b.rawValue!);
                        }
                      },
                    ),
                    const QrScanFrame(),
                  ],
                ),
              ),
            if (p == TargetPlatform.android || p == TargetPlatform.iOS)
              AppButton(
                label: '打开摄像头',
                onPressed: () async {
                  if (camera == null) {
                    setState(
                      () => camera = MobileScannerController(
                        formats: const [BarcodeFormat.qrCode],
                      ),
                    );
                  } else {
                    await camera!.start();
                  }
                },
              ),
            const SizedBox(height: AppSpace.lg),
            TextField(
              controller: text,
              decoration: const InputDecoration(labelText: '教室二维码内容'),
            ),
            if (error != null) Text(error!),
            const SizedBox(height: AppSpace.md),
            AppButton(label: '识别教室', onPressed: () => open(text.text)),
          ],
        ),
      ),
    );
  }
}
