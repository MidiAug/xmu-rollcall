import 'package:xmu_rollcall/core/text/html_plain_text.dart';
import 'package:xmu_rollcall/features/academic/academic_identity.dart';
import 'package:xmu_rollcall/features/academic/academic_session.dart';

class LectureRequirement {
  const LectureRequirement({
    required this.title,
    required this.description,
    required this.minimum,
    required this.fetchedAt,
  });
  final String title, description;
  final int? minimum;
  final DateTime fetchedAt;
  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'minimum': minimum,
    'fetchedAt': fetchedAt.toIso8601String(),
  };
  factory LectureRequirement.fromJson(Map<String, dynamic> v) =>
      LectureRequirement(
        title: v['title'] as String,
        description: v['description'] as String,
        minimum: v['minimum'] as int?,
        fetchedAt: DateTime.parse(v['fetchedAt'] as String),
      );
}

List<Map<String, dynamic>> lecturePlanRows(
  Map<String, dynamic> v,
  String block,
) {
  final data = v['datas'];
  final node = data is Map ? data[block] : null;
  if ('${v['code']}' != '0' ||
      node is! Map ||
      node['rows'] is! List ||
      int.tryParse('${node['totalSize']}') != (node['rows'] as List).length) {
    throw const FormatException('个人培养方案响应不完整');
  }
  return (node['rows'] as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
}

LectureRequirement? parseLectureRequirement(
  List<Map<String, dynamic>> rows,
  DateTime at,
) {
  final matches = rows
      .where((v) => RegExp('讲座|学术与技术交流').hasMatch('${v['MC']}'))
      .toList();
  if (matches.isEmpty) return null;
  final descriptions = matches
      .map((v) => readableHtmlText('${v['MRZ'] ?? ''}'))
      .toList();
  final counts = <int>{};
  for (final text in descriptions) {
    for (final m in RegExp(
      r'(?:至少|不少于|不得少于)[^。；\n\d]{0,10}(\d+)\s*场',
    ).allMatches(text)) {
      final count = int.parse(m[1]!);
      if (count > 0) counts.add(count);
    }
  }
  return LectureRequirement(
    title: matches.map((v) => '${v['MC']}').join(' / '),
    description: descriptions.join('\n\n'),
    minimum: counts.length == 1 ? counts.single : null,
    fetchedAt: at,
  );
}

class LectureRequirementReader {
  LectureRequirementReader(this.session);
  final AcademicSession session;
  Future<LectureRequirement?> fetch(int uid, AcademicIdentity identity) async {
    const base = '/gsapp/sys/wdpyfaapp/modules/pyfaxq/';
    try {
      await session.connect(
        uid,
        applicationId: '5006012186614764',
        username: identity.username,
        password: identity.password,
        sso: identity.sso,
      );
      final headers = {
        'Referer': AcademicSession.jw
            .resolve('/gsapp/sys/wdpyfaapp/*default/index.do')
            .toString(),
        'Origin': AcademicSession.jw.origin,
        'X-Requested-With': 'XMLHttpRequest',
      };
      final binding = await session.json(
        '${base}gjxhcxdyfadm.do',
        data: {'XH': identity.username},
        headers: headers,
      );
      final plans = lecturePlanRows(binding, 'gjxhcxdyfadm');
      if (plans.length != 1 ||
          plans.single['XH'] != identity.username ||
          '${plans.single['FADM'] ?? ''}'.isEmpty) {
        throw const FormatException('个人培养方案与当前账号不匹配');
      }
      final payload = await session.json(
        '${base}gjfadmhqdydpyfanr.do',
        data: {'DM': plans.single['FADM']},
        headers: headers,
      );
      final result = parseLectureRequirement(
        lecturePlanRows(payload, 'gjfadmhqdydpyfanr'),
        DateTime.now(),
      );
      await session.persist(uid);
      return result;
    } finally {
      session.close();
    }
  }
}
