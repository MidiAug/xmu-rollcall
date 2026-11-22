import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Visible framing for the camera; the decoder retains its own capture scope.
class QrScanFrame extends StatelessWidget {
  const QrScanFrame({super.key});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(painter: _QrScanFramePainter(AppPalette.of(context))),
  );
}

class _QrScanFramePainter extends CustomPainter {
  const _QrScanFramePainter(this.palette);
  final AppPalette palette;
  @override
  void paint(Canvas canvas, Size size) {
    final frame = Offset.zero & size;
    canvas.drawRect(
      frame,
      Paint()
        ..color = palette.scannerInk.withValues(alpha: .25)
        ..style = PaintingStyle.stroke,
    );
    final corners = Path();
    for (final point in [
      frame.topLeft,
      frame.topRight,
      frame.bottomLeft,
      frame.bottomRight,
    ]) {
      final dx = point.dx == frame.left ? 26.0 : -26.0;
      final dy = point.dy == frame.top ? 26.0 : -26.0;
      corners
        ..moveTo(point.dx + dx, point.dy)
        ..lineTo(point.dx, point.dy)
        ..lineTo(point.dx, point.dy + dy);
    }
    canvas.drawPath(
      corners,
      Paint()
        ..color = palette.scannerAccent
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawLine(
      Offset(14, size.height / 2),
      Offset(size.width - 14, size.height / 2),
      Paint()
        ..color = palette.scannerAccent.withValues(alpha: .7)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_QrScanFramePainter old) => palette != old.palette;
}
