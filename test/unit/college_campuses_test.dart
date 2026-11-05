import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/location/campus_places.dart';
import 'package:xmu_rollcall/features/location/college_campuses.dart';
import 'package:xmu_rollcall/features/location/place_matching.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';

void main() {
  test(
    'college fallback distinguishes international colleges and room priority',
    () {
      expect(campusForCollege('厦门大学信息学院'), Campus.xiangan);
      expect(campusForCollege('管理学院'), Campus.siming);
      expect(campusForCollege('国际学院'), Campus.zhangzhou);
      expect(campusForCollege('海外教育学院'), Campus.xiangan);
      expect(campusForCollege('未知学院'), isNull);
      expect(
        preferredCampus([], [], collegeCampus: Campus.zhangzhou),
        Campus.zhangzhou,
      );
      expect(
        preferredCampus(['学武楼A404'], [], collegeCampus: Campus.zhangzhou),
        Campus.xiangan,
      );
    },
  );

  test(
    'student college metadata is optional and isolated in owner snapshots',
    () async {
      SharedPreferences.setMockInitialValues({});
      expect(academicStudentCollege({'XYMC': '信息学院', 'XH': 'private'}), '信息学院');
      expect(
        academicStudentCollege({'DWDM': '123', 'KKDWDM_DISPLAY': '信息学院'}),
        '',
      );
      final value = AcademicSchedule(
        term: '20261',
        monday: DateTime(2026, 9, 7),
        fetchedAt: DateTime(2026, 10, 28),
        rows: [],
        studentCollege: '信息学院',
      );
      await AcademicScheduleStore.write(1, value);
      final read = await AcademicScheduleStore.read(1, useUserStart: false);
      expect(read!.studentCollege, '信息学院');
      expect(await AcademicScheduleStore.read(2, useUserStart: false), isNull);
      final legacy = value.toJson()..remove('studentCollege');
      expect(AcademicSchedule.fromJson(legacy).studentCollege, '');
      expect(value.toJson().containsKey('XH'), isFalse);
    },
  );
}
