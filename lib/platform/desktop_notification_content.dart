import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

/// User-facing content only; never include codes, raw payloads or account data.
class DesktopNotificationContent {
  const DesktopNotificationContent({required this.title, required this.body});
  final String title;
  final String body;

  String get inAppText => '$title：$body';

  static const test = DesktopNotificationContent(
    title: '通知测试',
    body: '示例课程 · 雷达签到（示例）\n点击返回应用，不会提交签到。',
  );

  factory DesktopNotificationContent.discovery(List<RollcallItem> items) {
    assert(items.isNotEmpty);
    if (items.length == 1) {
      return DesktopNotificationContent(
        title: _course(items.single),
        body: '${_type(items.single)} · 点击查看',
      );
    }
    return DesktopNotificationContent(
      title: '发现 ${items.length} 条签到',
      body: [
        for (final item in items.take(2)) '${_course(item)} · ${_type(item)}',
        if (items.length > 2) '另有 ${items.length - 2} 条，点击查看',
      ].join('\n'),
    );
  }

  factory DesktopNotificationContent.result(RollcallItem item, bool ok) =>
      DesktopNotificationContent(
        title: _course(item),
        body: '${_type(item)} · ${ok ? '自动签到成功' : '自动签到未成功，请打开应用处理'}',
      );

  static String _course(RollcallItem item) {
    final title = item.courseTitle.replaceAll(RegExp(r'\s+'), ' ').trim();
    return title.isEmpty ? '未命名课程' : title;
  }

  static String _type(RollcallItem item) =>
      item.type == RollcallType.unknown ? '签到（类型待确认）' : '${item.typeLabel}签到';
}
