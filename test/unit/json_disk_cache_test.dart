import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

class _RejectWrites extends InMemorySharedPreferencesStore {
  _RejectWrites() : super.withData({});
  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('JsonDiskCache round-trips list envelope', () async {
    final items = [
      const HomeworkItem(id: 1, title: 'A').toJson(),
      const HomeworkItem(id: 2, title: 'B', courseId: 9).toJson(),
    ];
    final at = DateTime.now().subtract(const Duration(hours: 2));
    await JsonDiskCache.writeList('homework_todos_1', items, fetchedAt: at);

    final snap = await JsonDiskCache.readList('homework_todos_1');
    expect(snap, isNotNull);
    expect(snap!.fetchedAt.difference(at).inSeconds.abs(), lessThan(2));
    expect(snap.items.length, 2);
    expect(HomeworkItem.fromJson(snap.items[0]).title, 'A');
    expect(snap.isFresh(const Duration(minutes: 10)), isFalse);
    expect(snap.isFresh(const Duration(hours: 3)), isTrue);
  });

  test('JsonDiskCache clearAll drops swr keys only', () async {
    await JsonDiskCache.writeList('course_history_1', [
      const CourseRollcallRecord(
        courseId: 'c1',
        courseTitle: '课',
        rollcallId: 'r1',
        rollcallTime: null,
        typeLabel: '数字',
        signedStatus: '已签',
        platformStatus: '',
      ).toJson(),
    ]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('other_key', 'keep');

    await JsonDiskCache.clearAll();
    expect(await JsonDiskCache.readList('course_history_1'), isNull);
    expect(prefs.getString('other_key'), 'keep');
  });
  test(
    'rejected persistent write reports failure instead of a successful cache save',
    () async {
      SharedPreferencesStorePlatform.instance = _RejectWrites();
      await expectLater(
        JsonDiskCache.writeList('rejected', [
          {'id': 7},
        ]),
        throwsStateError,
      );
      await (await SharedPreferences.getInstance()).reload();
      expect(await JsonDiskCache.readList('rejected'), isNull);
    },
  );

  test('CourseRollcallRecord toJson/fromJson', () {
    const r = CourseRollcallRecord(
      courseId: '10',
      courseTitle: '高等数学',
      rollcallId: '99',
      rollcallTime: null,
      typeLabel: '雷达',
      signedStatus: '未签到',
      platformStatus: 'on',
      detail: 'x',
    );
    final back = CourseRollcallRecord.fromJson(r.toJson());
    expect(back.courseTitle, '高等数学');
    expect(back.rollcallId, '99');
    expect(back.detail, 'x');
  });
}
