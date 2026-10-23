import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/platform/desktop_notification_content.dart';

RollcallItem item(int id, String course, RollcallType type) => RollcallItem(
  rollcallId: id,
  courseTitle: course,
  createdByName: '教师',
  type: type,
  status: 'absent',
  rollcallStatus: 'in_progress',
  isExpired: false,
  scored: false,
  numberCode: '1234',
  raw: const {'private': 'raw-payload'},
);

void main() {
  test('single discovery highlights real course and each supported type', () {
    for (final type in [
      RollcallType.number,
      RollcallType.radar,
      RollcallType.qrcode,
    ]) {
      final course = item(1, '  工程伦理  ', type);
      final content = DesktopNotificationContent.discovery([course]);
      expect(content.title, '工程伦理');
      expect(content.body, contains('${course.typeLabel}签到'));
      expect(content.body, contains('点击查看'));
      expect(content.inAppText, contains('工程伦理'));
      expect(content.inAppText, isNot(contains('1234')));
      expect(content.inAppText, isNot(contains('raw-payload')));
    }
  });
  test(
    'multiple discoveries preserve course/type pairs and bound summary length',
    () {
      final content = DesktopNotificationContent.discovery([
        item(1, '工程伦理', RollcallType.radar),
        item(2, '机器学习', RollcallType.number),
        item(3, '专业英语', RollcallType.qrcode),
      ]);
      expect(content.title, '发现 3 条签到');
      expect(content.body, '工程伦理 · 雷达签到\n机器学习 · 数字签到\n另有 1 条，点击查看');
    },
  );
  test('missing metadata is explicit and never invents course or type', () {
    final content = DesktopNotificationContent.discovery([
      item(1, '  ', RollcallType.unknown),
    ]);
    expect(content.title, '未命名课程');
    expect(content.body, contains('类型待确认'));
  });
  test('test copy is clearly an example and result keeps course and type', () {
    expect(DesktopNotificationContent.test.title, '通知测试');
    expect(DesktopNotificationContent.test.body, contains('示例课程'));
    expect(DesktopNotificationContent.test.body, contains('不会提交签到'));
    final course = item(1, '机器学习', RollcallType.number);
    expect(DesktopNotificationContent.result(course, true).title, '机器学习');
    expect(
      DesktopNotificationContent.result(course, true).body,
      contains('数字签到 · 自动签到成功'),
    );
    expect(
      DesktopNotificationContent.result(course, false).body,
      contains('未成功'),
    );
  });
}
