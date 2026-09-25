import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/rollcall/session_prior.dart';

/// Session prior under an active rollcall card (footnote well).
///
/// Identify / Task live above; this is a quieter inset context block.
class SessionPriorPanel extends ConsumerWidget {
  const SessionPriorPanel({
    super.key,
    required this.courseId,
    required this.currentType,
    this.previewState,
  });

  final String courseId;
  final RollcallType currentType;
  final SessionPriorState? previewState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final forced = previewState;
    if (forced != null) return _wrapOrHint(palette, forced);

    final async = ref.watch(sessionPriorProvider(courseId));
    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => _hint(palette, '本段记录加载中'),
      error: (_, _) => _hint(palette, '本段记录暂不可用'),
      data: (state) => _wrapOrHint(palette, state),
    );
  }

  Widget _wrapOrHint(AppPalette palette, SessionPriorState state) {
    if (state.unscoped || state.snapshot == null) {
      return _hint(palette, '暂无课表段信息');
    }
    return _PriorBody(state: state, currentType: currentType);
  }

  Widget _hint(AppPalette palette, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.lg),
      child: _PriorWell(
        palette: palette,
        child: Text(
          text,
          style: TextStyle(fontSize: 12, height: 1.4, color: palette.muted),
        ),
      ),
    );
  }
}

/// Soft inset so prior reads as a distinct footnote, not more form fields.
class _PriorWell extends StatelessWidget {
  const _PriorWell({required this.palette, required this.child});

  final AppPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.content,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.sm,
          AppSpace.sm,
          AppSpace.sm,
          AppSpace.sm,
        ),
        child: child,
      ),
    );
  }
}

class _PriorBody extends StatelessWidget {
  const _PriorBody({
    required this.state,
    required this.currentType,
  });

  final SessionPriorState state;
  final RollcallType currentType;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final snap = state.snapshot!;
    final block = snap.block;
    final axisStart = minutesOfDay(block.windowStart);
    final axisEnd = minutesOfDay(block.windowEnd);
    final span = (axisEnd - axisStart).clamp(1, 24 * 60);

    final entries = snap.typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final majority = entries.isEmpty ? null : entries.first.key;
    final mismatch = snap.hasEnoughSamples &&
        majority != null &&
        majority != currentType &&
        currentType != RollcallType.unknown;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.lg),
      child: _PriorWell(
        palette: palette,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    snap.headerLabel,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: palette.ink.withValues(alpha: 0.78),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Text(
                  _typeSentence(snap, entries),
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: palette.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            SizedBox(
              height: 40,
              child: CustomPaint(
                painter: _TimelinePainter(
                  axisStart: axisStart,
                  span: span,
                  points: snap.pointsMinutes,
                  bandStart: snap.commonStartMinutes,
                  bandEnd: snap.commonEndMinutes,
                  nowMinutes: state.nowMinutes,
                  track: palette.surfaceHigh,
                  band: palette.selected,
                  dot: palette.primary,
                  now: palette.ink,
                  labelStyle: TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    color: palette.muted.withValues(alpha: 0.9),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),
            if (mismatch) ...[
              const SizedBox(height: AppSpace.sm),
              _MismatchNote(
                palette: palette,
                text: '本次是${rollcallTypeZh(currentType)}，和往常不太一样',
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _typeSentence(
    SessionPriorSnapshot snap,
    List<MapEntry<RollcallType, int>> entries,
  ) {
    if (!snap.hasEnoughSamples || entries.isEmpty) {
      return '本段历史不足';
    }
    final top = entries.first;
    final name = rollcallTypeZh(top.key);
    final n = snap.sampleCount;
    if (top.value == n) {
      return '近 $n 次都是$name';
    }
    return '多为$name ${top.value}/$n';
  }
}

class _MismatchNote extends StatelessWidget {
  const _MismatchNote({required this.palette, required this.text});

  final AppPalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Container(
            width: 2.5,
            height: 12,
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: palette.ink.withValues(alpha: 0.72),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.axisStart,
    required this.span,
    required this.points,
    required this.bandStart,
    required this.bandEnd,
    required this.nowMinutes,
    required this.track,
    required this.band,
    required this.dot,
    required this.now,
    required this.labelStyle,
  });

  final int axisStart;
  final int span;
  final List<int> points;
  final int bandStart;
  final int bandEnd;
  final int? nowMinutes;
  final Color track;
  final Color band;
  final Color dot;
  final Color now;
  final TextStyle labelStyle;

  double _x(int minutes, double width) {
    final t = ((minutes - axisStart) / span).clamp(0.0, 1.0);
    return t * width;
  }

  static String _hm(int minutes) {
    final h = (minutes ~/ 60).clamp(0, 23);
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 14.0;
    final midY = (size.height - labelH) * 0.42;

    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      Paint()
        ..color = track
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    if (points.isNotEmpty) {
      final x0 = _x(bandStart, size.width);
      final x1 = _x(bandEnd, size.width);
      canvas.drawRRect(
        RRect.fromLTRBR(
          x0,
          midY - 5,
          x1.clamp(x0 + 2, size.width),
          midY + 5,
          const Radius.circular(2.5),
        ),
        Paint()..color = band,
      );
    }

    final ring = Paint()..color = track;
    final fill = Paint()..color = dot;
    for (final p in points) {
      final c = Offset(_x(p, size.width), midY);
      canvas.drawCircle(c, 4.2, ring);
      canvas.drawCircle(c, 2.9, fill);
    }

    final n = nowMinutes;
    if (n != null && n >= axisStart && n <= axisStart + span) {
      final x = _x(n, size.width);
      canvas.drawLine(
        Offset(x, midY - 9),
        Offset(x, midY + 9),
        Paint()
          ..color = now
          ..strokeWidth = 1.2,
      );
      final path = Path()
        ..moveTo(x, midY - 11)
        ..lineTo(x - 3.0, midY - 6)
        ..lineTo(x + 3.0, midY - 6)
        ..close();
      canvas.drawPath(path, Paint()..color = now);
    }

    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(text: _hm(axisStart), style: labelStyle);
    tp.layout();
    tp.paint(canvas, Offset(0, size.height - labelH + 1));

    tp.text = TextSpan(text: _hm(axisStart + span), style: labelStyle);
    tp.layout();
    tp.paint(canvas, Offset(size.width - tp.width, size.height - labelH + 1));
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) {
    return old.points != points ||
        old.nowMinutes != nowMinutes ||
        old.bandStart != bandStart ||
        old.bandEnd != bandEnd ||
        old.axisStart != axisStart ||
        old.span != span;
  }
}
