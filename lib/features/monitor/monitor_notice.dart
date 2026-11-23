import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notice kind emitted when a non-selected account discovers or auto-answers a rollcall.
enum MonitorNoticeKind { discovered, autoAnswerSucceeded, autoAnswerFailed }

/// In-app notification payload for background-account monitor events.
class MonitorNoticeEvent {
  const MonitorNoticeEvent({
    required this.id,
    required this.accountScope,
    required this.accountLabel,
    required this.kind,
    this.courseTitle = '',
    this.count = 1,
  });

  final int id;
  final int? accountScope;
  final String accountLabel;
  final MonitorNoticeKind kind;
  final String courseTitle;
  final int count;

  bool get isError => kind == MonitorNoticeKind.autoAnswerFailed;

  String formatMessage() {
    switch (kind) {
      case MonitorNoticeKind.discovered:
        if (count > 1) return '$accountLabel 发现 $count 项新签到';
        if (courseTitle.isNotEmpty) return '$accountLabel 发现新签到：$courseTitle';
        return '$accountLabel 发现新签到';
      case MonitorNoticeKind.autoAnswerSucceeded:
        if (courseTitle.isNotEmpty) return '$accountLabel 已自动签到：$courseTitle';
        return '$accountLabel 已自动签到';
      case MonitorNoticeKind.autoAnswerFailed:
        if (courseTitle.isNotEmpty) return '$accountLabel 自动签到失败：$courseTitle';
        return '$accountLabel 自动签到失败';
    }
  }
}

final monitorNoticeProvider = StateProvider<MonitorNoticeEvent?>((ref) => null);

int _nextMonitorNoticeId = 0;

int nextMonitorNoticeId() => ++_nextMonitorNoticeId;
