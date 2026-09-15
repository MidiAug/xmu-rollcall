import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/features/assist/assist_qr_batch.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

void main() {
  group('filterAssistForCourse', () {
    test('keeps identities whose course set contains courseId', () {
      final a = const AssistIdentity(userId: 1, displayName: '甲');
      final b = const AssistIdentity(userId: 2, displayName: '乙');
      final c = const AssistIdentity(userId: 3, displayName: '丙');
      final filtered = filterAssistForCourse(
        courseId: '99',
        identities: [a, b, c],
        courseIdsByUser: {
          1: {'99', '1'},
          2: {'7'},
          3: {'99'},
        },
      );
      expect(filtered.map((e) => e.userId), [1, 3]);
    });

    test('when courseId missing returns empty (cannot claim same-course)', () {
      expect(
        filterAssistForCourse(
          courseId: null,
          identities: [
            const AssistIdentity(userId: 1, displayName: '甲'),
          ],
          courseIdsByUser: {
            1: {'99'},
          },
        ),
        isEmpty,
      );
    });
  });

  group('AssistQrBatchRunner', () {
    test('submits serially and collects per-target results', () async {
      final order = <String>[];
      final runner = AssistQrBatchRunner(
        submit: (target, data) async {
          order.add(target.label);
          await Future<void>.delayed(const Duration(milliseconds: 5));
          if (target.label == '乙') {
            return const AnswerResult(ok: false, message: 'fail');
          }
          return const AnswerResult(ok: true, message: 'ok');
        },
      );

      final results = await runner.run(
        qrData: 'DATA',
        targets: [
          AssistQrTarget(
            key: SessionKey.owner,
            label: '我',
            userId: 0,
          ),
          AssistQrTarget(
            key: SessionKey.assist(2),
            label: '乙',
            userId: 2,
          ),
          AssistQrTarget(
            key: SessionKey.assist(3),
            label: '丙',
            userId: 3,
          ),
        ],
      );

      expect(order, ['我', '乙', '丙']);
      expect(results.map((r) => r.ok).toList(), [true, false, true]);
      expect(results[1].message, 'fail');
    });
  });
}
