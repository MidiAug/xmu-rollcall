import 'package:flutter/material.dart';

/// Lucide [user-check](https://lucide.dev/icons/user-check) (ISC) — matches app / tray icon.
class UserCheckIcon extends StatelessWidget {
  const UserCheckIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _UserCheckPainter(color),
    );
  }
}

class _UserCheckPainter extends CustomPainter {
  _UserCheckPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawCircle(Offset(9 * s, 7 * s), 4 * s, paint);

    final body = Path()
      ..moveTo(16 * s, 21 * s)
      ..lineTo(16 * s, 19 * s)
      ..arcToPoint(
        Offset(12 * s, 15 * s),
        radius: Radius.circular(4 * s),
        clockwise: false,
      )
      ..lineTo(6 * s, 15 * s)
      ..arcToPoint(
        Offset(2 * s, 19 * s),
        radius: Radius.circular(4 * s),
        clockwise: false,
      )
      ..lineTo(2 * s, 21 * s);
    canvas.drawPath(body, paint);

    final check = Path()
      ..moveTo(16 * s, 11 * s)
      ..lineTo(18 * s, 13 * s)
      ..lineTo(22 * s, 9 * s);
    canvas.drawPath(check, paint);
  }

  @override
  bool shouldRepaint(covariant _UserCheckPainter oldDelegate) =>
      oldDelegate.color != color;
}
