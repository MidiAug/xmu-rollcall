class LogisticsRepair {
  LogisticsRepair(Map<String, dynamic> json)
    : id = _required(json, 'id'),
      number = _required(json, 'serialNumber'),
      project = _required(json, 'projectName'),
      content = _required(json, 'content'),
      area = _text(json['areaName']),
      address = _text(json['address']),
      department = _text(json['repairDeptName']),
      worker = _text(json['workerName']),
      completed = json['ifComplete'] == '1',
      evaluated = json['ifCommont'] == '1',
      logs = _rows(json['logs']).map(LogisticsRepairLog.new).toList();
  final String id, number, project, content, area, address, department, worker;
  final bool completed, evaluated;
  final List<LogisticsRepairLog> logs;
  String get status => completed && !evaluated
      ? '待评价'
      : completed
      ? '已完工'
      : logs.firstOrNull?.title ?? '状态待核对';
  Map<String, dynamic> toJson() => {
    'id': id,
    'serialNumber': number,
    'projectName': project,
    'content': content,
    'areaName': area,
    'address': address,
    'repairDeptName': department,
    'workerName': worker,
    'ifComplete': completed ? '1' : '0',
    'ifCommont': evaluated ? '1' : '0',
    'logs': logs.map((e) => e.toJson()).toList(),
  };
}

class LogisticsRepairLog {
  LogisticsRepairLog(Map<String, dynamic> json)
    : title = _required(json, 'statusName'),
      time = _text(json['createTime']),
      content = _text(json['content']);
  final String title, time, content;
  Map<String, dynamic> toJson() => {
    'statusName': title,
    'createTime': time,
    'content': content,
  };
}

class LogisticsMessage {
  LogisticsMessage(Map<String, dynamic> json)
    : title = _required(json, 'title'),
      content = _text(json['content']),
      time = _text(json['sendTime']),
      unread = json['status'] == 0;
  final String title, content, time;
  final bool unread;
  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
    'sendTime': time,
    'status': unread ? 0 : 1,
  };
}

class LogisticsSnapshot {
  const LogisticsSnapshot({
    required this.repairs,
    required this.messages,
    required this.total,
    required this.page,
    required this.fetchedAt,
  });
  factory LogisticsSnapshot.fromJson(Map<String, dynamic> json) =>
      LogisticsSnapshot(
        repairs: _rows(json['repairs']).map(LogisticsRepair.new).toList(),
        messages: _rows(json['messages']).map(LogisticsMessage.new).toList(),
        total: (json['total'] as num).toInt(),
        page: (json['page'] as num).toInt(),
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      );
  final List<LogisticsRepair> repairs;
  final List<LogisticsMessage> messages;
  final int total, page;
  final DateTime fetchedAt;
  Map<String, dynamic> toJson() => {
    'repairs': repairs.map((e) => e.toJson()).toList(),
    'messages': messages.map((e) => e.toJson()).toList(),
    'total': total,
    'page': page,
    'fetchedAt': fetchedAt.toIso8601String(),
  };
}

String _text(Object? value) => value is String ? value.trim() : '';
String _required(Map<String, dynamic> json, String key) {
  final value = _text(json[key]);
  if (value.isEmpty) throw const FormatException('后勤数据字段缺失，请稍后重试');
  return value;
}

List<Map<String, dynamic>> _rows(Object? value) {
  if (value is! List || value.any((e) => e is! Map<String, dynamic>)) {
    throw const FormatException('后勤列表格式异常');
  }
  return value.cast<Map<String, dynamic>>();
}
