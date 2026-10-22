import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/rollcall/desktop_qr_decoder.dart';
import 'package:xmu_rollcall/features/rollcall/qr_payload.dart';

const _capture = MethodChannel('xmu_rollcall/desktop_capture');

class DesktopQrScanApp extends StatelessWidget {
  const DesktopQrScanApp({
    super.key,
    required this.controller,
    required this.owner,
  });
  final WindowController controller;
  final WindowController owner;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark(),
    color: Colors.transparent,
    home: DesktopQrScanWindow(controller: controller, owner: owner),
  );
}

class DesktopQrScanWindow extends StatefulWidget {
  const DesktopQrScanWindow({
    super.key,
    required this.controller,
    required this.owner,
  });
  final WindowController controller;
  final WindowController owner;
  @override
  State<DesktopQrScanWindow> createState() => _DesktopQrScanWindowState();
}

class _DesktopQrScanWindowState extends State<DesktopQrScanWindow> {
  final _hole = GlobalKey();
  Timer? _timer;
  int? _session;
  int? _rollcallId;
  String? _courseId;
  bool _preview = false;
  bool _paused = false;
  bool _busy = false;
  bool _picking = false;
  bool _hovering = false;
  String? _pendingImage;
  String _status = '把屏幕上的二维码移入框内';
  String? _lastRejected;
  bool _screenFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    await _capture.invokeMethod<void>('configure');
    _capture.setMethodCallHandler((call) async {
      if (call.method == 'closeRequested') await _finish(null);
    });
    await widget.controller.setWindowMethodHandler((call) async {
      if (call.method == 'scan_cancel') {
        await _finish(null);
        return null;
      }
      if (call.method != 'scan_start') return null;
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final session = args['sessionId'] as int;
      _timer?.cancel();
      setState(() {
        _session = session;
        _rollcallId = args['rollcallId'] as int?;
        _courseId = args['courseId'] as String?;
        _preview = args['preview'] == true;
        _paused = false;
        _hovering = false;
        _pendingImage = null;
        _lastRejected = null;
        _screenFailed = false;
        _status = '把屏幕上的二维码移入框内';
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || _session != session) return null;
      await _capture.invokeMethod<void>('show');
      if (!mounted || _session != session) return null;
      _timer = Timer.periodic(
        const Duration(milliseconds: 650),
        (_) => _scanScreen(),
      );
      return null;
    });
    await widget.owner.invokeMethod('qr_ready', {
      'windowId': widget.controller.windowId,
    });
  }

  Future<void> _log(
    String event, {
    String level = 'I',
    Map<String, dynamic> fields = const {},
  }) async {
    await widget.owner.invokeMethod('qr_log', {
      'event': event,
      'level': level,
      'fields': {'rollcallId': _rollcallId, ...fields},
    });
  }

  Future<void> _finish(String? raw) async {
    final session = _session;
    if (session == null) return;
    _session = null;
    _timer?.cancel();
    await _capture.invokeMethod<void>('hide');
    await widget.owner.invokeMethod('qr_complete', {
      'sessionId': session,
      'raw': raw,
    });
  }

  Future<void> _accept(String? raw, String source, int session) async {
    if (!mounted || _session != session) return;
    if (source == 'screen' && (_paused || _picking || _hovering)) return;
    if (raw == null || raw.isEmpty) {
      if (source == 'image') setState(() => _status = '图片中未找到二维码，试试清晰的原图');
      return;
    }
    if (!_preview) {
      try {
        parseQrRollcallData(
          raw,
          expectedRollcallId: _rollcallId,
          expectedCourseId: _courseId,
        );
      } on FormatException {
        if (_lastRejected != raw) {
          _lastRejected = raw;
          await _log(
            'qr.desktop.rejected',
            level: 'W',
            fields: {'source': source, 'payloadLen': raw.length},
          );
        }
        if (mounted) setState(() => _status = '这个二维码不属于本次签到，请重新选择');
        return;
      }
    }
    await _log(
      'qr.desktop.detected',
      fields: {'source': source, 'payloadLen': raw.length, 'preview': _preview},
    );
    if (_session == session) await _finish(raw);
  }

  Future<void> _drainImage() async {
    final path = _pendingImage;
    final session = _session;
    if (path == null || session == null) return;
    _pendingImage = null;
    setState(() => _status = '正在识别图片…');
    try {
      await _accept(
        await compute(decodeDesktopQrImage, path),
        'image',
        session,
      );
    } catch (error) {
      await _log(
        'qr.desktop.image_error',
        level: 'W',
        fields: {'errorType': error.runtimeType.toString()},
      );
      if (mounted && _session == session) {
        setState(() => _status = '图片无法读取，请选择 PNG、JPG 或 WebP 图片');
      }
    }
  }

  Future<void> _scanScreen() async {
    if (_session == null || _busy || _picking || _hovering) return;
    if (_paused && _pendingImage == null) return;
    final session = _session!;
    _busy = true;
    try {
      if (_pendingImage == null && !_paused) {
        final box = _hole.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        final point = box.localToGlobal(Offset.zero);
        final frame = await _capture
            .invokeMapMethod<String, Object>('capture', {
              'x': point.dx + 8,
              'y': point.dy + 8,
              'width': box.size.width - 16,
              'height': box.size.height - 16,
            });
        if (frame != null) {
          _screenFailed = false;
          await _accept(
            await compute(decodeDesktopQrFrame, frame),
            'screen',
            session,
          );
        }
      }
      while (_pendingImage != null && _session == session) {
        await _drainImage();
      }
    } catch (error) {
      if (_session == session && !_screenFailed) {
        _screenFailed = true;
        await _log(
          'qr.desktop.capture_error',
          level: 'W',
          fields: {'errorType': error.runtimeType.toString()},
        );
      }
      if (mounted && _session == session) {
        setState(() => _status = '屏幕读取暂不可用，仍可拖入或选择图片');
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _pickImage() async {
    if (_picking) return;
    final session = _session;
    if (session == null) return;
    _picking = true;
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: '图片',
            extensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'],
          ),
        ],
      );
      if (file != null && mounted && _session == session) {
        _pendingImage = file.path;
      }
    } catch (error) {
      await _log(
        'qr.desktop.picker_error',
        level: 'W',
        fields: {'errorType': error.runtimeType.toString()},
      );
      if (mounted && _session == session) {
        setState(() => _status = '选图暂不可用，可以将图片拖入识别框');
      }
    } finally {
      _picking = false;
    }
    if (_pendingImage != null) await _scanScreen();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _capture.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final accent = p.primary;
    return Material(
      type: MaterialType.transparency,
      child: DropTarget(
        onDragEntered: (_) => setState(() => _hovering = true),
        onDragExited: (_) => setState(() => _hovering = false),
        onDragDone: (details) {
          setState(() => _hovering = false);
          if (details.files.isNotEmpty) {
            _pendingImage = details.files.first.path;
            _scanScreen();
          }
        },
        child: LayoutBuilder(
          builder: (context, bounds) {
            const header = 78.0, footer = 118.0, inset = 18.0;
            final hole = Rect.fromLTWH(
              inset,
              header,
              bounds.maxWidth - inset * 2,
              bounds.maxHeight - header - footer,
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FramePainter(
                      hole: hole,
                      color: p.surface,
                      accent: accent,
                      active: !_paused,
                      hovered: _hovering,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: header,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) => _capture.invokeMethod<void>(
                      'move',
                      {'dx': details.delta.dx, 'dy': details.delta.dy},
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 14, 12, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              Icons.qr_code_scanner_rounded,
                              color: accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '扫码签到',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: p.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _preview ? '开发预览  不提交签到' : '拖动窗口，对准二维码',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: p.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '关闭扫码窗',
                            onPressed: () => _finish(null),
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: p.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: hole,
                  child: GestureDetector(
                    key: _hole,
                    behavior: HitTestBehavior.translucent,
                    onPanUpdate: (details) => _capture.invokeMethod<void>(
                      'move',
                      {'dx': details.delta.dx, 'dy': details.delta.dy},
                    ),
                    child: _hovering
                        ? Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: p.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '松开图片，开始识别',
                                style: TextStyle(color: accent),
                              ),
                            ),
                          )
                        : const SizedBox.expand(),
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 16,
                  height: footer - 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _paused ? p.muted : accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: p.ink),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '透明区域实时识别，也支持拖入图片',
                        style: TextStyle(fontSize: 11, color: p.muted),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => setState(() {
                                _paused = !_paused;
                                _status = _paused
                                    ? '已暂停屏幕识别，仍可使用图片'
                                    : '把屏幕上的二维码移入框内';
                              }),
                              icon: Icon(
                                _paused
                                    ? Icons.play_arrow_rounded
                                    : Icons.pause_rounded,
                                size: 16,
                              ),
                              label: Text(_paused ? '继续识别' : '暂停识别'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.image_outlined, size: 16),
                              label: const Text('选择图片'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter({
    required this.hole,
    required this.color,
    required this.accent,
    required this.active,
    required this.hovered,
  });
  final Rect hole;
  final Color color;
  final Color accent;
  final bool active;
  final bool hovered;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      )
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(10)));
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(0.5),
        const Radius.circular(18),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.09)
        ..style = PaintingStyle.stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole, const Radius.circular(10)),
      Paint()
        ..color = accent.withValues(alpha: hovered ? 0.7 : 0.2)
        ..style = PaintingStyle.stroke,
    );
    final corners = Path();
    const n = 22.0;
    for (final point in [
      hole.topLeft,
      hole.topRight,
      hole.bottomLeft,
      hole.bottomRight,
    ]) {
      final dx = point.dx == hole.left ? n : -n;
      final dy = point.dy == hole.top ? n : -n;
      corners
        ..moveTo(point.dx + dx, point.dy)
        ..lineTo(point.dx, point.dy)
        ..lineTo(point.dx, point.dy + dy);
    }
    canvas.drawPath(
      corners,
      Paint()
        ..color = active ? accent : Colors.grey
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    if (hovered) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(hole, const Radius.circular(10)),
        Paint()..color = accent.withValues(alpha: 0.12),
      );
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      hole != old.hole ||
      color != old.color ||
      accent != old.accent ||
      active != old.active ||
      hovered != old.hovered;
}
