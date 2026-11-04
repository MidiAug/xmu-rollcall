import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// A small family of service illustrations, drawn at their final optical size.
/// The app's navigation remains symbolic; these marks identify destinations.
class AppServiceSymbol extends StatelessWidget {
  const AppServiceSymbol({super.key, required this.icon, this.size = 60});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .17),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .29),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: p.isDark
                ? [const Color(0xFF3D4656), const Color(0xFF272D39)]
                : [const Color(0xFFFFFFFF), const Color(0xFFE8EDF5)],
          ),
          border: Border.all(
            color: p.isDark ? const Color(0xFF535C6C) : Colors.white,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: p.isDark ? .18 : .08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: CustomPaint(painter: _ServicePainter(icon, p.isDark)),
      ),
    );
  }
}

class _ServicePainter extends CustomPainter {
  const _ServicePainter(this.icon, this.dark);
  final IconData icon;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 40, size.height / 40);
    final ink = dark ? const Color(0xFFDDE5F3) : const Color(0xFF344A6A);
    final accent = dark ? const Color(0xFF9EBDF2) : const Color(0xFF6485BC);
    final paper = dark ? const Color(0xFF52627B) : const Color(0xFFDEE6F2);
    final white = dark ? const Color(0xFFAEBFD8) : Colors.white;
    final fill = Paint();
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void rect(Rect r, double radius, Color color) => canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(radius)),
      fill..color = color,
    );
    void stroke(Path path, Color color, [double width = 1.6]) =>
        canvas.drawPath(
          path,
          line
            ..color = color
            ..strokeWidth = width,
        );

    if (icon == AppIcons.serviceMap) {
      final map = Path()
        ..moveTo(3, 10)
        ..lineTo(14, 5)
        ..lineTo(26, 9)
        ..lineTo(37, 4)
        ..lineTo(37, 30)
        ..lineTo(26, 36)
        ..lineTo(14, 32)
        ..lineTo(3, 37)
        ..close();
      canvas.drawPath(map, fill..color = paper);
      canvas.drawPath(
        Path()
          ..moveTo(14, 5)
          ..lineTo(26, 9)
          ..lineTo(26, 36)
          ..lineTo(14, 32)
          ..close(),
        fill..color = white,
      );
      stroke(
        Path()
          ..moveTo(7, 28)
          ..lineTo(16, 20)
          ..lineTo(23, 24)
          ..lineTo(31, 14),
        accent,
        2.4,
      );
      canvas.drawCircle(const Offset(31, 14), 3.8, fill..color = ink);
      canvas.drawCircle(const Offset(31, 14), 1.4, fill..color = white);
    } else if (icon == AppIcons.serviceGpa) {
      rect(const Rect.fromLTWH(3, 5, 34, 31), 6, paper);
      rect(const Rect.fromLTWH(8, 23, 5, 8), 1.5, accent);
      rect(const Rect.fromLTWH(17, 18, 5, 13), 1.5, accent);
      rect(const Rect.fromLTWH(26, 12, 5, 19), 1.5, ink);
      stroke(
        Path()
          ..moveTo(8, 15)
          ..lineTo(17, 11)
          ..lineTo(22, 12)
          ..lineTo(30, 5),
        ink,
      );
    } else if (icon == AppIcons.serviceGrading) {
      rect(const Rect.fromLTWH(7, 3, 27, 34), 4, paper);
      rect(const Rect.fromLTWH(7, 3, 23, 30), 4, white);
      stroke(
        Path()
          ..moveTo(13, 11)
          ..lineTo(24, 11)
          ..moveTo(13, 16)
          ..lineTo(21, 16),
        accent,
        2,
      );
      stroke(
        Path()
          ..moveTo(15, 25)
          ..lineTo(20, 30)
          ..lineTo(31, 19),
        ink,
        3,
      );
    } else if (icon == AppIcons.serviceExams ||
        icon == AppIcons.serviceCalendar) {
      rect(const Rect.fromLTWH(4, 6, 32, 30), 6, paper);
      rect(const Rect.fromLTWH(4, 6, 32, 11), 5, ink);
      rect(const Rect.fromLTWH(4, 12, 32, 5), 0, ink);
      stroke(
        Path()
          ..moveTo(12, 3)
          ..lineTo(12, 10)
          ..moveTo(28, 3)
          ..lineTo(28, 10),
        accent,
        2.6,
      );
      if (icon == AppIcons.serviceExams) {
        stroke(
          Path()
            ..moveTo(13, 26)
            ..lineTo(18, 30)
            ..lineTo(27, 21),
          ink,
          2.7,
        );
      } else {
        for (var row = 0; row < 2; row++) {
          for (var col = 0; col < 3; col++) {
            rect(
              Rect.fromLTWH(10 + col * 8, 21 + row * 7, 4, 4),
              1,
              row == 0 && col == 1 ? ink : accent,
            );
          }
        }
      }
    } else {
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: 34,
            color: ink,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset((40 - painter.width) / 2, (40 - painter.height) / 2),
      );
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(_ServicePainter oldDelegate) =>
      oldDelegate.icon != icon || oldDelegate.dark != dark;
}
