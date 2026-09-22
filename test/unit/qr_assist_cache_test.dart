import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/features/rollcall/qr_selection_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssistIdentity sharedCourses JSON', () {
    test('round-trips and tolerates missing fields', () {
      const id = AssistIdentity(
        userId: 3,
        displayName: '李',
        kind: AssistCredentialKind.session,
        sharedCourses: [
          AssistSharedCourse(id: '10', title: '线性代数'),
        ],
      );
      final back = AssistIdentity.fromJson(id.toJson());
      expect(back.sharedCourses.single.id, '10');
      expect(back.sharedCourses.single.title, '线性代数');

      final legacy = AssistIdentity.fromJson({
        'userId': 1,
        'displayName': '旧',
        'kind': 'session',
      });
      expect(legacy.sharedCourses, isEmpty);
    });

    test('sharedCourseStatus three-way', () {
      expect(
        const AssistIdentity(
          userId: 1,
          displayName: 'a',
          kind: AssistCredentialKind.session,
        ).sharedCourseStatus,
        AssistSharedCourseStatus.neverSynced,
      );
      expect(
        AssistIdentity(
          userId: 1,
          displayName: 'a',
          kind: AssistCredentialKind.session,
          sharedCoursesSyncedAt: DateTime.utc(2026, 1, 1),
        ).sharedCourseStatus,
        AssistSharedCourseStatus.none,
      );
      expect(
        AssistIdentity(
          userId: 1,
          displayName: 'a',
          kind: AssistCredentialKind.session,
          sharedCourses: const [AssistSharedCourse(id: '1')],
          sharedCoursesSyncedAt: DateTime.utc(2026, 1, 1),
        ).sharedCourseStatus,
        AssistSharedCourseStatus.some,
      );
    });
  });

  group('QrSelectionStore', () {
    test('read write per courseId', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = QrSelectionStore(prefs);
      await store.write(
        '501',
        const QrSelectionSnapshot(
          includeOwner: false,
          assistUserIds: {9, 2},
        ),
      );
      final snap = await store.read('501');
      expect(snap!.includeOwner, isFalse);
      expect(snap.assistUserIds, {2, 9});
      expect(await store.read('other'), isNull);
    });
  });
}
