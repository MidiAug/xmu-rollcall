import 'package:xmu_rollcall/features/lectures/lecture_requirement.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/academic/academic_session.dart';
import 'package:xmu_rollcall/features/academic/academic_identity.dart';
import 'package:xmu_rollcall/features/lectures/lecture_client.dart';

Map<String, dynamic> lectureFixture({String id = 'fixture-lecture'}) => {
  'ID': id,
  'Serial': id,
  'Name': '测试学术讲座',
  'BeginOn': '2030-1-1 14:00:00',
  'EndOn': '2030-01-01 16:00:00',
  'Address': '测试楼101',
  'Hoster': '测试学院',
  'SignUpBegin': '2020-01-01 00:00:00',
  'SignUpEnd': '2030-01-01 13:00:00',
  'Content': '<p>讲座摘要 &amp; 参与说明</p><script>hidden()</script>',
  'State': '成功',
};

class LectureFixtureClient extends LectureClient {
  int lists = 0;
  bool fail = false;
  @override
  Future<void> connect({
    required String username,
    required String? deviceKey,
  }) async {
    if (deviceKey == null) throw const LectureLoginRequired();
  }

  @override
  Future<LecturePage> attended({int page = 1}) async {
    lists++;
    if (fail) throw const FormatException('测试更新失败');
    return LecturePage(
      [LectureEntry.fromJson(lectureFixture(id: 'fixture-$page'))],
      25,
      page == 1 ? 2 : null,
      successCount: 15,
    );
  }
}

class LectureRequirementFixtureReader extends LectureRequirementReader {
  LectureRequirementFixtureReader()
    : super(AcademicSession(store: SecureStore.memory()));
  @override
  Future<LectureRequirement?> fetch(int uid, AcademicIdentity identity) async =>
      LectureRequirement(
        title: '行业前沿讲座/学术与技术交流',
        description: '在学期间至少参与20场讲座，另需提交总结。',
        minimum: 20,
        fetchedAt: DateTime.now(),
      );
}
