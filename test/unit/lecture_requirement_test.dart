import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/cache_revisions.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'package:xmu_rollcall/features/lectures/lecture_summary.dart';
import 'package:xmu_rollcall/features/lectures/lecture_provider.dart';
import 'package:xmu_rollcall/features/lectures/lecture_requirement_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'uses explicit personal-plan minimum without borrowing credits or unrelated numbers',
    () {
      final v = parseLectureRequirement([
        {'MC': '学位论文', 'MRZ': '论文不少于100页'},
        {
          'MC': '行业前沿讲座/学术与技术交流',
          'MRZ': '<p>至少参与 20 场讲座；学分1，提交1000-2000字总结。</p>',
        },
      ], DateTime(2026));
      expect(v!.minimum, 20);
      expect(v.description, contains('1000-2000'));
      expect(
        parseLectureRequirement([
          {'MC': '学术讲座', 'MRZ': '具体次数按学院规定'},
        ], DateTime(2026))!.minimum,
        isNull,
      );
      expect(
        parseLectureRequirement([
          {'MC': '学术讲座', 'MRZ': '硕士至少20场，博士至少40场'},
        ], DateTime(2026))!.minimum,
        isNull,
      );
      expect(
        parseLectureRequirement([
          {'MC': '学位论文', 'MRZ': '至少100页'},
        ], DateTime(2026)),
        isNull,
      );
    },
  );
  test('rejects incomplete plan pages instead of guessing a requirement', () {
    expect(
      () => lecturePlanRows({
        'code': 0,
        'datas': {
          'plan': {'rows': [], 'totalSize': 10},
        },
      }, 'plan'),
      throwsFormatException,
    );
  });
  test(
    'tool summary is cache-only, preserves unknown totals and isolates selected accounts',
    () async {
      const first = (ownerId: 1, userId: 1, assistId: null);
      final selected = StateProvider<BrowserIdentity>((ref) => first);
      SharedPreferences.setMockInitialValues({
        lectureCacheKey(first): jsonEncode({
          'page': const LecturePage([], 15, null, successCount: 15).toJson(),
        }),
        lectureRequirementKey(first): jsonEncode(
          LectureRequirement(
            title: '讲座',
            description: '至少20场',
            minimum: 20,
            fetchedAt: DateTime(2026),
          ).toJson(),
        ),
      });
      final c = ProviderContainer(
        overrides: [
          browserIdentityProvider.overrideWith((ref) => ref.watch(selected)),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(cachedLectureSummaryProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await c.read(cachedLectureSummaryProvider.future), (
        success: 15,
        required: 20,
      ));
      c.read(selected.notifier).state = (ownerId: 1, userId: 2, assistId: 2);
      expect(await c.read(cachedLectureSummaryProvider.future), (
        success: null,
        required: null,
      ));
      final p = await SharedPreferences.getInstance();
      await p.setString(
        lectureCacheKey(c.read(selected)),
        jsonEncode({
          'page': const LecturePage([], 9, null, successCount: 9).toJson(),
        }),
      );
      c.read(lectureCacheRevisionProvider.notifier).state++;
      expect(await c.read(cachedLectureSummaryProvider.future), (
        success: 9,
        required: null,
      ));
    },
  );
}
