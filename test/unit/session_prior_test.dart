import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/rollcall/session_prior.dart';

CourseRollcallRecord _row({
  required DateTime at,
  required String type,
  String courseId = '1',
}) {
  return CourseRollcallRecord(
    courseId: courseId,
    courseTitle: '测试课',
    rollcallId: '${at.millisecondsSinceEpoch}',
    rollcallTime: at,
    typeLabel: type,
    signedStatus: '已签到',
    platformStatus: 'on_call_fine',
  );
}

void main() {
  final block56 = SessionBlock(
    startSequence: 5,
    endSequence: 6,
    coreStart: DateTime(2026, 1, 1, 14, 30),
    coreEnd: DateTime(2026, 1, 1, 16, 10),
  );
  final block78 = SessionBlock(
    startSequence: 7,
    endSequence: 8,
    coreStart: DateTime(2026, 1, 1, 16, 40),
    coreEnd: DateTime(2026, 1, 1, 18, 20),
  );

  // 2026-09-22 = Tuesday
  test('does not mix 7-8 history into 5-6 prior', () {
    final history = [
      _row(at: DateTime(2026, 9, 22, 14, 50), type: '二维码'),
      _row(at: DateTime(2026, 9, 22, 15, 10), type: '二维码'),
      _row(at: DateTime(2026, 9, 22, 16, 55), type: '数字'),
    ];
    final prior = buildSessionPrior(
      block: block56,
      weekday: 2,
      history: history,
    );
    expect(prior.sampleCount, 2);
    expect(prior.typeCounts[RollcallType.qrcode], 2);
    expect(prior.typeCounts.containsKey(RollcallType.number), isFalse);
  });

  test('ignores other weekdays', () {
    final history = [
      _row(at: DateTime(2026, 9, 23, 14, 50), type: '数字'), // Wed
      _row(at: DateTime(2026, 9, 22, 14, 55), type: '二维码'),
      _row(at: DateTime(2026, 9, 15, 15, 0), type: '二维码'), // prior Tue
    ];
    final prior = buildSessionPrior(
      block: block56,
      weekday: 2,
      history: history,
    );
    expect(prior.sampleCount, 2);
    expect(prior.typeCounts[RollcallType.qrcode], 2);
  });

  test('7-8 prior excludes 5-6 points', () {
    final history = [
      _row(at: DateTime(2026, 9, 22, 14, 50), type: '二维码'),
      _row(at: DateTime(2026, 9, 22, 17, 0), type: '数字'),
      _row(at: DateTime(2026, 9, 22, 17, 10), type: '数字'),
    ];
    final prior = buildSessionPrior(
      block: block78,
      weekday: 2,
      history: history,
    );
    expect(prior.sampleCount, 2);
    expect(prior.typeCounts[RollcallType.number], 2);
  });

  test('headerLabel has no middle-dot', () {
    final prior = buildSessionPrior(
      block: block56,
      weekday: 2,
      history: [
        _row(at: DateTime(2026, 9, 22, 14, 50), type: '二维码'),
        _row(at: DateTime(2026, 9, 22, 15, 0), type: '二维码'),
      ],
    );
    expect(prior.headerLabel.contains('·'), isFalse);
    expect(prior.headerLabel, contains('周二'));
    expect(prior.headerLabel, contains('第5–6节'));
  });
}
