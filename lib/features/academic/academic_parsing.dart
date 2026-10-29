int academicInt(Object? value) => int.tryParse('$value') ?? 0;
String academicText(Object? value) => value?.toString().trim() ?? '';

/// Read only the student's named college, never a course's teaching department.
String academicStudentCollege(Object? person) {
  if (person is! Map) return '';
  for (final key in const [
    'XYMC',
    'YXMC',
    'YXBMC',
    'XYDM_DISPLAY',
    'YXDM_DISPLAY',
    'DWDM_DISPLAY',
    'DWMC',
    'college_name',
    'department_name',
  ]) {
    final value = person[key];
    if (value is String && value.contains(RegExp('学院|研究院|学部'))) {
      return value.trim();
    }
  }
  return '';
}

/// EMAP sends numeric HHmm; some deployments return HH:mm strings.
int academicMinute(Object? value) {
  final raw = academicText(value);
  final parts = raw.contains(':')
      ? raw.split(':')
      : RegExp(r'^\d{3,4}$').hasMatch(raw)
      ? [raw.substring(0, raw.length - 2), raw.substring(raw.length - 2)]
      : <String>[];
  if (parts.length < 2) throw const FormatException('教务节次时间异常');
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
    throw const FormatException('教务节次时间异常');
  }
  return h * 60 + m;
}

Set<int> academicWeeks(Object? value) {
  final mask = academicText(value);
  if (!RegExp(r'^[01]{1,60}$').hasMatch(mask)) {
    throw const FormatException('教务周次格式异常');
  }
  return {
    for (var i = 0; i < mask.length; i++)
      if (mask[i] == '1') i + 1,
  };
}
