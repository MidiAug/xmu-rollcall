import 'package:cookie_jar/cookie_jar.dart';
import 'package:xmu_rollcall/features/classrooms/classroom_client.dart';

const classroomUserFixture = ClassroomUser('test-user', '20260000000001', [
  'campus',
]);
const classroomInfoFixture = ClassroomInfo(
  id: '00000000-0000-0000-0000-000000000001',
  name: '测试楼101',
  building: '测试楼',
  buildingId: 'building',
  category: '多媒体教室',
  capacity: '60',
  introduction: '教室设备与使用介绍',
);
ClassroomHome classroomHomeFixture() => const ClassroomHome(
  user: classroomUserFixture,
  campuses: [ClassroomPlace('campus', '思明校区')],
  buildings: [ClassroomPlace('building', '测试楼', campusId: 'campus')],
  agendas: [],
);

class ClassroomFixtureClient extends ClassroomClient {
  int connectCount = 0, homeCount = 0;
  bool fail = false, uncertain = false;
  final calls = <String>[];
  final writes = <String>[];
  @override
  Future<void> connect({
    required String username,
    String? password,
    CookieJar? sso,
  }) async {
    connectCount++;
    user = classroomUserFixture;
  }

  @override
  Future<ClassroomHome> home() async {
    homeCount++;
    if (fail) throw const FormatException('读取失败');
    return classroomHomeFixture();
  }

  @override
  Future<List<ClassroomInfo>> rooms({String? campus}) async {
    calls.add('rooms');
    return [classroomInfoFixture];
  }

  @override
  Future<ClassroomInfo> room(String id) async => classroomInfoFixture;
  @override
  Future<List<SeatRoom>> seatRooms({
    String? campus,
    String? building,
    int page = 1,
    String keyword = '',
  }) async {
    calls.add('seats:$page');
    return [const SeatRoom('room', '测试自习室', 2, 10)];
  }

  @override
  Future<SeatRules> seatRules(String room) async => const SeatRules(
    open: true,
    days: 7,
    minimum: 30,
    maximum: 120,
    notice: '请在预约开始后30分钟内到场签到',
    promise: '按学校规则使用教室',
  );
  @override
  Future<List<ClassroomDateStatus>> seatDates(String room, int days) async => [
    ClassroomDateStatus(
      classroomDate(DateTime.now().add(const Duration(days: 1))),
      1,
    ),
  ];
  @override
  Future<List<SeatTimeRange>> seatTimes(String room, String date) async => [
    const SeatTimeRange('08:00', '22:00'),
  ];
  @override
  Future<List<ClassroomSeat>> seats(
    String room,
    String date,
    String start,
    String end,
  ) async => [
    const ClassroomSeat(1, 'A01', 1),
    const ClassroomSeat(2, 'A02', 2),
  ];
  @override
  Future<void> bookSeat(
    String room,
    int seat,
    String date,
    String start,
    String end,
  ) async {
    writes.add('seat:$seat');
    if (uncertain) throw const ClassroomWriteUncertain();
  }

  @override
  Future<ClassroomPage<ClassroomBooking>> bookings(int page) async =>
      ClassroomPage([
        ClassroomBooking(
          1,
          '测试自习室',
          'A01',
          writes.contains('cancel') ? '已取消' : '待签到',
          ['明天08:00—08:30'],
          !writes.contains('cancel'),
        ),
      ], null);
  @override
  Future<ClassroomPage<ClassroomBooking>> seminarBookings(int page) async =>
      const ClassroomPage([], null);
  @override
  Future<void> cancelBooking(int id) async {
    writes.add('cancel');
  }

  @override
  Future<List<ClassroomPlace>> floorBuildings() async => [
    const ClassroomPlace('building', '测试楼', campusId: 'campus'),
  ];
  @override
  Future<List<ClassroomInfo>> selfStudy(String building, String date) async => [
    const ClassroomInfo(
      id: 'room',
      name: '测试教室102',
      periods: [
        StudyPeriod(1, '08:00:00', '08:45:00', 1, false),
        StudyPeriod(2, '08:55:00', '09:40:00', 2, false),
      ],
    ),
  ];
  @override
  Future<List<ClassroomInfo>> floors(String building) async => [
    const ClassroomInfo(
      id: 'room',
      name: '测试教室103',
      floor: '1',
      category: '教室',
      occupied: true,
    ),
  ];
  @override
  Future<ClassroomPage<ClassroomLecture>> lectures(int page) async {
    calls.add('lectures:$page');
    return ClassroomPage([
      ClassroomLecture(
        'lecture$page',
        '测试讲座$page',
        '测试主讲人',
        '2026-12-01',
        '15:00',
        '测试楼',
        '讲座内容',
      ),
    ], page == 1 ? 2 : null);
  }

  @override
  Future<ClassroomPage<ClassroomLostItem>> lostItems(int page) async =>
      const ClassroomPage([
        ClassroomLostItem('lost', '雨伞', '蓝色雨伞', '测试楼前台', '2026-11-25'),
      ], null);
  @override
  Future<List<ClassroomFeedback>> feedback() async =>
      writes.contains('feedback')
      ? [const ClassroomFeedback('feedback', '测试反馈', '待处理', '2026-11-25')]
      : [];
  @override
  Future<List<ClassroomFeedbackChoice>> feedbackCategories() async => [
    const ClassroomFeedbackChoice('1', '设备问题'),
  ];
  @override
  Future<List<ClassroomFeedbackChoice>> feedbackTypes() async => [
    const ClassroomFeedbackChoice('1', '建议'),
  ];
  @override
  Future<void> sendFeedback({
    required ClassroomInfo room,
    required String campus,
    required String building,
    required String category,
    required String type,
    required String phone,
    required String content,
  }) async {
    writes.add('feedback');
  }

  @override
  Future<ClassroomPage<ClassroomSeminar>> seminars(
    int page, {
    String? campus,
    String? building,
  }) async => ClassroomPage([
    ClassroomSeminar(
      id: 'seminar',
      name: '测试研讨室',
      location: '测试楼201',
      capacity: 6,
      dates: [classroomDate(DateTime.now().add(const Duration(days: 1)))],
      type: 3,
      mode: 'time_period',
    ),
  ], null);
  @override
  Future<String> seminarRule(String room) async => '请按预约人数使用并按时离开';
  @override
  Future<int> seminarAvailability(
    String room,
    String date,
    String start,
    String end,
  ) async => 6;
  @override
  Future<void> bookSeminar(
    String room,
    String date,
    String start,
    String end,
    String purpose,
    int people,
    bool allowMany,
  ) async {
    writes.add('seminar');
  }
}
