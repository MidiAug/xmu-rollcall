import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

enum AppSettingsGlyphKind {
  sun,
  globe,
  window,
  calendar,
  mapPin,
  user,
  users,
  power,
  shieldCheck,
  bell,
  database,
  info,
  link,
  trayDown,
  chartBar,
  fileText,
  trash,
  trayUp,
  refreshCw,
  code,
  clock,
}

/// Crisp 24x24 geometric outline glyphs for settings and assist rows.
class AppSettingsGlyph extends StatelessWidget {
  const AppSettingsGlyph(this.kind, {super.key, this.size, this.color});

  final AppSettingsGlyphKind kind;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? 18.0;
    final resolvedColor =
        color ?? iconTheme.color ?? AppPalette.of(context).muted;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(resolvedSize),
        painter: _AppSettingsGlyphPainter(kind, resolvedColor),
      ),
    );
  }
}

class _AppSettingsGlyphPainter extends CustomPainter {
  _AppSettingsGlyphPainter(this.kind, this.color);

  final AppSettingsGlyphKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (kind) {
      case AppSettingsGlyphKind.sun:
        canvas.drawCircle(Offset(12 * s, 12 * s), 4.0 * s, paint);
        for (var i = 0; i < 8; i++) {
          final angle = i * math.pi / 4;
          final cos = math.cos(angle);
          final sin = math.sin(angle);
          canvas.drawLine(
            Offset((12 + 6.6 * cos) * s, (12 + 6.6 * sin) * s),
            Offset((12 + 9.2 * cos) * s, (12 + 9.2 * sin) * s),
            paint,
          );
        }

      case AppSettingsGlyphKind.globe:
        canvas.drawCircle(Offset(12 * s, 12 * s), 9.0 * s, paint);
        canvas.drawLine(Offset(3 * s, 12 * s), Offset(21 * s, 12 * s), paint);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(12 * s, 12 * s),
            width: 7.5 * s,
            height: 18 * s,
          ),
          paint,
        );

      case AppSettingsGlyphKind.window:
        canvas.drawRRect(
          RRect.fromLTRBR(
            4 * s,
            4 * s,
            20 * s,
            20 * s,
            Radius.circular(2.5 * s),
          ),
          paint,
        );
        canvas.drawLine(Offset(4 * s, 9 * s), Offset(20 * s, 9 * s), paint);

      case AppSettingsGlyphKind.calendar:
        canvas.drawRRect(
          RRect.fromLTRBR(
            3.5 * s,
            5 * s,
            20.5 * s,
            20 * s,
            Radius.circular(2.5 * s),
          ),
          paint,
        );
        canvas.drawLine(Offset(8 * s, 3.2 * s), Offset(8 * s, 6.8 * s), paint);
        canvas.drawLine(
          Offset(16 * s, 3.2 * s),
          Offset(16 * s, 6.8 * s),
          paint,
        );
        canvas.drawLine(
          Offset(3.5 * s, 10 * s),
          Offset(20.5 * s, 10 * s),
          paint,
        );

      case AppSettingsGlyphKind.mapPin:
        final pin = Path()
          ..moveTo(5.8 * s, 10 * s)
          ..arcTo(
            Rect.fromCircle(center: Offset(12 * s, 10 * s), radius: 6.2 * s),
            math.pi,
            math.pi,
            false,
          )
          ..cubicTo(
            18.2 * s,
            14.4 * s,
            13.6 * s,
            19.0 * s,
            12 * s,
            20.8 * s,
          )
          ..cubicTo(
            10.4 * s,
            19.0 * s,
            5.8 * s,
            14.4 * s,
            5.8 * s,
            10 * s,
          )
          ..close();
        canvas.drawPath(pin, paint);
        canvas.drawCircle(Offset(12 * s, 10 * s), 2.3 * s, paint);

      case AppSettingsGlyphKind.user:
        canvas.drawCircle(Offset(12 * s, 8 * s), 3.5 * s, paint);
        final shoulders = Path()
          ..moveTo(5.5 * s, 19.5 * s)
          ..arcToPoint(
            Offset(18.5 * s, 19.5 * s),
            radius: Radius.elliptical(6.5 * s, 5.5 * s),
            clockwise: true,
          );
        canvas.drawPath(shoulders, paint);

      case AppSettingsGlyphKind.users:
        canvas.drawCircle(Offset(9.8 * s, 8.5 * s), 3.0 * s, paint);
        final primaryShoulders = Path()
          ..moveTo(4 * s, 19 * s)
          ..arcToPoint(
            Offset(15.5 * s, 19 * s),
            radius: Radius.elliptical(5.75 * s, 5.0 * s),
            clockwise: true,
          );
        canvas.drawPath(primaryShoulders, paint);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(16 * s, 8.8 * s), radius: 2.4 * s),
          -0.42 * math.pi,
          0.84 * math.pi,
          false,
          paint,
        );
        final secondaryShoulder = Path()
          ..moveTo(16.5 * s, 14.2 * s)
          ..quadraticBezierTo(19.6 * s, 15.0 * s, 20 * s, 19 * s);
        canvas.drawPath(secondaryShoulder, paint);

      case AppSettingsGlyphKind.power:
        canvas.drawArc(
          Rect.fromCircle(center: Offset(12 * s, 13 * s), radius: 6.5 * s),
          -48 * math.pi / 180,
          276 * math.pi / 180,
          false,
          paint,
        );
        canvas.drawLine(Offset(12 * s, 4 * s), Offset(12 * s, 12 * s), paint);

      case AppSettingsGlyphKind.shieldCheck:
        final shield = Path()
          ..moveTo(12 * s, 3.2 * s)
          ..lineTo(18.8 * s, 5.8 * s)
          ..lineTo(18.8 * s, 11.4 * s)
          ..cubicTo(
            18.8 * s,
            15.8 * s,
            15.6 * s,
            19.0 * s,
            12 * s,
            20.8 * s,
          )
          ..cubicTo(
            8.4 * s,
            19.0 * s,
            5.2 * s,
            15.8 * s,
            5.2 * s,
            11.4 * s,
          )
          ..lineTo(5.2 * s, 5.8 * s)
          ..close();
        canvas.drawPath(shield, paint);
        final check = Path()
          ..moveTo(9.0 * s, 12.2 * s)
          ..lineTo(11.2 * s, 14.4 * s)
          ..lineTo(15.4 * s, 9.8 * s);
        canvas.drawPath(check, paint);

      case AppSettingsGlyphKind.bell:
        final bell = Path()
          ..moveTo(5.5 * s, 16.5 * s)
          ..cubicTo(
            6.6 * s,
            15.2 * s,
            7.0 * s,
            13.6 * s,
            7.0 * s,
            10.2 * s,
          )
          ..arcToPoint(
            Offset(17.0 * s, 10.2 * s),
            radius: Radius.elliptical(5.0 * s, 5.4 * s),
            clockwise: true,
          )
          ..cubicTo(
            17.0 * s,
            13.6 * s,
            17.4 * s,
            15.2 * s,
            18.5 * s,
            16.5 * s,
          )
          ..close();
        canvas.drawPath(bell, paint);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(12 * s, 16.8 * s), radius: 2.0 * s),
          0.18 * math.pi,
          0.64 * math.pi,
          false,
          paint,
        );

      case AppSettingsGlyphKind.database:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(12 * s, 6.5 * s),
            width: 13.5 * s,
            height: 4.8 * s,
          ),
          paint,
        );
        canvas.drawLine(
          Offset(5.25 * s, 6.5 * s),
          Offset(5.25 * s, 17.5 * s),
          paint,
        );
        canvas.drawLine(
          Offset(18.75 * s, 6.5 * s),
          Offset(18.75 * s, 17.5 * s),
          paint,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(12 * s, 12.0 * s),
            width: 13.5 * s,
            height: 4.8 * s,
          ),
          0,
          math.pi,
          false,
          paint,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(12 * s, 17.5 * s),
            width: 13.5 * s,
            height: 4.8 * s,
          ),
          0,
          math.pi,
          false,
          paint,
        );

      case AppSettingsGlyphKind.info:
        canvas.drawCircle(Offset(12 * s, 12 * s), 8.8 * s, paint);
        canvas.drawLine(
          Offset(12 * s, 11.2 * s),
          Offset(12 * s, 16.2 * s),
          paint,
        );
        canvas.drawLine(Offset(12 * s, 8.0 * s), Offset(12 * s, 8.1 * s), paint);

      case AppSettingsGlyphKind.link:
        final upperLink = Path()
          ..moveTo(9.67 * s, 14.33 * s)
          ..arcToPoint(
            Offset(15.33 * s, 14.33 * s),
            radius: Radius.circular(4.0 * s),
            clockwise: false,
          )
          ..lineTo(18.33 * s, 11.33 * s)
          ..arcToPoint(
            Offset(12.67 * s, 5.67 * s),
            radius: Radius.circular(4.0 * s),
            clockwise: false,
          )
          ..lineTo(11.17 * s, 7.17 * s);
        canvas.drawPath(upperLink, paint);
        final lowerLink = Path()
          ..moveTo(14.33 * s, 9.67 * s)
          ..arcToPoint(
            Offset(8.67 * s, 9.67 * s),
            radius: Radius.circular(4.0 * s),
            clockwise: false,
          )
          ..lineTo(5.67 * s, 12.67 * s)
          ..arcToPoint(
            Offset(11.33 * s, 18.33 * s),
            radius: Radius.circular(4.0 * s),
            clockwise: false,
          )
          ..lineTo(12.83 * s, 16.83 * s);
        canvas.drawPath(lowerLink, paint);

      case AppSettingsGlyphKind.trayDown:
        final tray = Path()
          ..moveTo(5 * s, 14.5 * s)
          ..lineTo(5 * s, 18.8 * s)
          ..lineTo(19 * s, 18.8 * s)
          ..lineTo(19 * s, 14.5 * s);
        canvas.drawPath(tray, paint);
        canvas.drawLine(
          Offset(12 * s, 4.5 * s),
          Offset(12 * s, 14.2 * s),
          paint,
        );
        final arrow = Path()
          ..moveTo(8.6 * s, 10.8 * s)
          ..lineTo(12 * s, 14.2 * s)
          ..lineTo(15.4 * s, 10.8 * s);
        canvas.drawPath(arrow, paint);

      case AppSettingsGlyphKind.chartBar:
        canvas.drawLine(
          Offset(4.2 * s, 19.2 * s),
          Offset(19.8 * s, 19.2 * s),
          paint,
        );
        canvas.drawLine(
          Offset(7.0 * s, 19.2 * s),
          Offset(7.0 * s, 12.8 * s),
          paint,
        );
        canvas.drawLine(
          Offset(12.0 * s, 19.2 * s),
          Offset(12.0 * s, 5.6 * s),
          paint,
        );
        canvas.drawLine(
          Offset(17.0 * s, 19.2 * s),
          Offset(17.0 * s, 9.6 * s),
          paint,
        );

      case AppSettingsGlyphKind.fileText:
        final doc = Path()
          ..moveTo(7.5 * s, 3.8 * s)
          ..lineTo(14.0 * s, 3.8 * s)
          ..lineTo(18.5 * s, 8.3 * s)
          ..lineTo(18.5 * s, 18.2 * s)
          ..arcToPoint(
            Offset(16.5 * s, 20.2 * s),
            radius: Radius.circular(2.0 * s),
            clockwise: true,
          )
          ..lineTo(7.5 * s, 20.2 * s)
          ..arcToPoint(
            Offset(5.5 * s, 18.2 * s),
            radius: Radius.circular(2.0 * s),
            clockwise: true,
          )
          ..lineTo(5.5 * s, 5.8 * s)
          ..arcToPoint(
            Offset(7.5 * s, 3.8 * s),
            radius: Radius.circular(2.0 * s),
            clockwise: true,
          )
          ..close();
        canvas.drawPath(doc, paint);
        final fold = Path()
          ..moveTo(14.0 * s, 3.8 * s)
          ..lineTo(14.0 * s, 8.3 * s)
          ..lineTo(18.5 * s, 8.3 * s);
        canvas.drawPath(fold, paint);
        canvas.drawLine(
          Offset(8.8 * s, 12.2 * s),
          Offset(15.2 * s, 12.2 * s),
          paint,
        );
        canvas.drawLine(
          Offset(8.8 * s, 15.6 * s),
          Offset(13.6 * s, 15.6 * s),
          paint,
        );

      case AppSettingsGlyphKind.trash:
        canvas.drawLine(
          Offset(4.8 * s, 6.5 * s),
          Offset(19.2 * s, 6.5 * s),
          paint,
        );
        final handle = Path()
          ..moveTo(9.5 * s, 6.5 * s)
          ..lineTo(9.5 * s, 4.8 * s)
          ..arcToPoint(
            Offset(10.3 * s, 4.0 * s),
            radius: Radius.circular(0.8 * s),
            clockwise: true,
          )
          ..lineTo(13.7 * s, 4.0 * s)
          ..arcToPoint(
            Offset(14.5 * s, 4.8 * s),
            radius: Radius.circular(0.8 * s),
            clockwise: true,
          )
          ..lineTo(14.5 * s, 6.5 * s);
        canvas.drawPath(handle, paint);
        final body = Path()
          ..moveTo(6.6 * s, 6.5 * s)
          ..lineTo(7.4 * s, 18.2 * s)
          ..arcToPoint(
            Offset(9.0 * s, 19.8 * s),
            radius: Radius.circular(1.8 * s),
            clockwise: false,
          )
          ..lineTo(15.0 * s, 19.8 * s)
          ..arcToPoint(
            Offset(16.6 * s, 18.2 * s),
            radius: Radius.circular(1.8 * s),
            clockwise: false,
          )
          ..lineTo(17.4 * s, 6.5 * s);
        canvas.drawPath(body, paint);
        canvas.drawLine(
          Offset(10.2 * s, 10.2 * s),
          Offset(10.2 * s, 16.2 * s),
          paint,
        );
        canvas.drawLine(
          Offset(13.8 * s, 10.2 * s),
          Offset(13.8 * s, 16.2 * s),
          paint,
        );

      case AppSettingsGlyphKind.trayUp:
        final tray = Path()
          ..moveTo(5 * s, 14.5 * s)
          ..lineTo(5 * s, 18.8 * s)
          ..lineTo(19 * s, 18.8 * s)
          ..lineTo(19 * s, 14.5 * s);
        canvas.drawPath(tray, paint);
        canvas.drawLine(
          Offset(12 * s, 14.2 * s),
          Offset(12 * s, 4.5 * s),
          paint,
        );
        final arrow = Path()
          ..moveTo(8.6 * s, 7.9 * s)
          ..lineTo(12 * s, 4.5 * s)
          ..lineTo(15.4 * s, 7.9 * s);
        canvas.drawPath(arrow, paint);

      case AppSettingsGlyphKind.refreshCw:
        const radius = 7.4;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(12 * s, 12 * s), radius: radius * s),
          15 * math.pi / 180,
          300 * math.pi / 180,
          false,
          paint,
        );
        final tipX = 12 + radius * math.cos(-math.pi / 4);
        final tipY = 12 + radius * math.sin(-math.pi / 4);
        final arrow = Path()
          ..moveTo(tipX * s, (tipY - 3.4) * s)
          ..lineTo(tipX * s, tipY * s)
          ..lineTo((tipX - 3.4) * s, tipY * s);
        canvas.drawPath(arrow, paint);

      case AppSettingsGlyphKind.code:
        final leftBracket = Path()
          ..moveTo(8.0 * s, 8.2 * s)
          ..lineTo(4.2 * s, 12.0 * s)
          ..lineTo(8.0 * s, 15.8 * s);
        canvas.drawPath(leftBracket, paint);
        canvas.drawLine(
          Offset(13.5 * s, 6.5 * s),
          Offset(10.5 * s, 17.5 * s),
          paint,
        );
        final rightBracket = Path()
          ..moveTo(16.0 * s, 8.2 * s)
          ..lineTo(19.8 * s, 12.0 * s)
          ..lineTo(16.0 * s, 15.8 * s);
        canvas.drawPath(rightBracket, paint);

      case AppSettingsGlyphKind.clock:
        canvas.drawCircle(Offset(12 * s, 12 * s), 9.0 * s, paint);
        canvas.drawLine(Offset(12 * s, 7.2 * s), Offset(12 * s, 12 * s), paint);
        canvas.drawLine(Offset(12 * s, 12 * s), Offset(15.2 * s, 13.8 * s), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AppSettingsGlyphPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
