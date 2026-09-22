import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/features/assist/assist_qr_batch.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

void main() {
  group('filterAssistForCourse', () {
    test('keeps identities whose course set contains courseId', () {
      const a = AssistIdentity(
        userId: 1,
        displayName: '甲',
        kind: AssistCredentialKind.session,
      );
      const b = AssistIdentity(
        userId: 2,
        displayName: '乙',
        kind: AssistCredentialKind.session,
      );
      const c = AssistIdentity(
        userId: 3,
        displayName: '丙',
        kind: AssistCredentialKind.session,
      );
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
            const AssistIdentity(
              userId: 1,
              displayName: '甲',
              kind: AssistCredentialKind.session,
            ),
          ],
          courseIdsByUser: {
            1: {'99'},
          },
        ),
        isEmpty,
      );
    });
  });

  group('filterAssistBySharedCache', () {
    test('uses AssistIdentity.sharedCourses', () {
      const a = AssistIdentity(
        userId: 1,
        displayName: '甲',
        kind: AssistCredentialKind.session,
        sharedCourses: [
          AssistSharedCourse(id: '99', title: '高数'),
        ],
      );
      const b = AssistIdentity(
        userId: 2,
        displayName: '乙',
        kind: AssistCredentialKind.session,
      );
      expect(
        filterAssistBySharedCache(courseId: '99', identities: [a, b])
            .map((e) => e.userId),
        [1],
      );
    });
  });

  group('eligibilityFromActiveList', () {
    RollcallItem item({
      required int id,
      required String status,
    }) {
      return RollcallItem(
        rollcallId: id,
        courseTitle: 'c',
        createdByName: 't',
        type: RollcallType.qrcode,
        status: status,
        rollcallStatus: 'open',
        isExpired: false,
        scored: false,
      );
    }

    test('unsigned when present and not answered', () {
      expect(
        eligibilityFromActiveList(
          rollcallId: 5,
          active: [item(id: 5, status: 'on_call')],
        ),
        AssistQrEligibility.unsigned,
      );
    });

    test('signed when on_call_fine', () {
      expect(
        eligibilityFromActiveList(
          rollcallId: 5,
          active: [item(id: 5, status: 'on_call_fine')],
        ),
        AssistQrEligibility.signedOrDone,
      );
    });

    test('signedOrDone when absent from active list', () {
      expect(
        eligibilityFromActiveList(
          rollcallId: 5,
          active: [item(id: 9, status: 'on_call')],
        ),
        AssistQrEligibility.signedOrDone,
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
