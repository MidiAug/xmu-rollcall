part 'teaching_catalog.g.dart';

/// Published snapshot of the independently maintained location directory.
class TeachingPoint {
  const TeachingPoint(
    this.id,
    this.name,
    this.campus,
    this.latitude,
    this.longitude,
    this.source,
  );
  final String id, name, campus, source;
  final double latitude, longitude;
  bool get usable => source != 'polygon_centroid';
}

class TeachingRegion {
  const TeachingRegion(this.id, this.code, this.aliases, this.point);
  final String id, code;
  final List<String> aliases;
  final TeachingPoint? point;
}

class TeachingAlias {
  const TeachingAlias(
    this.name,
    this.target,
    this.campus,
    this.department,
    this.groupId,
    this.event,
    this.exact,
  );
  final String name, target, campus, department, groupId, event;
  final bool exact;
}

class TeachingBuilding {
  const TeachingBuilding(
    this.id,
    this.name,
    this.campus,
    this.aliases,
    this.rules,
    this.regions,
    this.point,
  );
  final String id, name, campus;
  final List<String> aliases;
  final List<TeachingAlias> rules;
  final List<TeachingRegion> regions;
  final TeachingPoint? point;
}

class TeachingGroup {
  const TeachingGroup(
    this.id,
    this.name,
    this.campus,
    this.aliases,
    this.point,
  );
  final String id, name, campus;
  final List<String> aliases;
  final TeachingPoint? point;
}

String _width(String value) {
  const roman = 'ⅠⅡⅢⅣⅤⅥⅦⅧⅨⅩⅪⅫ';
  return String.fromCharCodes(
    value.runes.map((r) => r >= 0xff01 && r <= 0xff5e ? r - 0xfee0 : r),
  ).replaceAllMapped(
    RegExp('[Ⅰ-Ⅻⅰ-ⅻ]'),
    (m) => '${roman.indexOf(m[0]!.toUpperCase()) + 1}',
  );
}

({String name, String? campus}) teachingNameParts(
  String value, [
  String? campus,
]) {
  var text = _width(
    value,
  ).trim().replaceFirst(RegExp(r'^(?:厦门大学|厦大)\s*[:：-]?\s*'), '');
  final prefix = RegExp(r'^(本部|思明|翔安|漳州)(?:校区)?\s*[:：-]?\s*').firstMatch(text);
  if (prefix != null && !RegExp(r'^(?:翔安医院|思明区|翔安区|漳州开发区)').hasMatch(text)) {
    campus = prefix[1] == '本部' ? '思明' : prefix[1];
    text = text.substring(prefix.end);
  }
  if (text.startsWith('海韵校区')) {
    campus = '思明';
    text = text.replaceFirst(RegExp(r'^海韵校区\s*-?\s*'), '海韵园');
  }
  // A campus annotation may precede the classroom number, e.g. 成智楼(思明)324.
  text = text.replaceAllMapped(RegExp(r'\((本部|思明|翔安|漳州)(?:校区)?\)'), (m) {
    campus = m[1] == '本部' ? '思明' : m[1];
    return '';
  });
  return (name: text, campus: campus);
}

String normalizeTeachingName(String value) {
  String number(String raw) {
    if (int.tryParse(raw) case final n?) return '$n';
    const digits = '零一二三四五六七八九';
    int digit(String c) => c == '两'
        ? 2
        : c == '〇'
        ? 0
        : digits.indexOf(c);
    if (!RegExp('[十百千]').hasMatch(raw)) {
      return '${int.parse(raw.split('').map(digit).join())}';
    }
    var sum = 0, current = 0;
    for (final c in raw.split('')) {
      final unit = const {'十': 10, '百': 100, '千': 1000}[c];
      if (unit != null) {
        sum += (current == 0 ? 1 : current) * unit;
        current = 0;
      } else {
        current = digit(c);
      }
    }
    return '${sum + current}';
  }

  const n = r'\d+|[零〇一二两三四五六七八九十百千]+';
  var text = teachingNameParts(
    value,
  ).name.toLowerCase().replaceAll(RegExp(r'[\s　]'), '');
  text = text.replaceAllMapped(RegExp('^($n)\$'), (m) => '${number(m[1]!)}号楼');
  text = text.replaceFirst(RegExp(r'^政法(?=[a-z](?:\d|号?[栋座楼区]|#|$))'), '法学院');
  text = text.replaceAllMapped(
    RegExp('($n)(?:号[楼栋座]|号|#[楼栋座]?|栋|座|楼(?=\$|[a-z\\d(]))'),
    (m) => '${number(m[1]!)}号楼',
  );
  text = text.replaceAllMapped(
    RegExp('(嘉庚|南强|南光|群贤|同安|集美|映雪|科研|化)($n)(?:号楼)?'),
    (m) => '${m[1]}${number(m[2]!)}号楼',
  );
  text = text.replaceAllMapped(
    RegExp(r'(^|[^a-z\d])([a-z]\d{0,2})(?:号?[栋座楼]|区|#[楼栋座]?)'),
    (m) => '${m[1]}${m[2]}',
  );
  return text.replaceAll(RegExp(r'[()（）]'), '');
}

class TeachingMatch {
  const TeachingMatch(this.buildingId, this.regionId, this.point);
  final String buildingId;
  final String? regionId;
  final TeachingPoint? point;
}

final _aliases =
    <({TeachingBuilding building, String key, TeachingAlias rule})>[
      for (final b in teachingBuildings)
        for (final rule in [
          for (final name in [
            b.name,
            b.name.split(RegExp('[（(]')).first,
            ...b.aliases,
          ])
            TeachingAlias(name, b.id, b.campus, '', '', '', false),
          for (final r in b.regions)
            for (final name in r.aliases)
              TeachingAlias(name, r.id, b.campus, '', '', '', false),
          ...b.rules,
        ])
          (building: b, key: normalizeTeachingName(rule.name), rule: rule),
    ];

final _aliasesByInitial =
    <
      String,
      List<({TeachingBuilding building, String key, TeachingAlias rule})>
    >{
      for (final initial
          in _aliases
              .where((e) => e.key.isNotEmpty)
              .map((e) => e.key[0])
              .toSet())
        initial: _aliases.where((e) => e.key.startsWith(initial)).toList(),
    };

/// Missing context and equal candidates stay unresolved, including bare 1#.
TeachingMatch? matchTeachingLocation(
  String room, {
  String? campus,
  String department = '',
  String groupId = '',
}) {
  final query = teachingNameParts(room, campus),
      key = normalizeTeachingName(query.name);
  if (key.isEmpty) return null;
  if (RegExp(
    r'[/、；;,，]',
  ).hasMatch(query.name.replaceAll(RegExp(r'\([^)]*\)'), ''))) {
    return null;
  }
  final candidates = <({TeachingBuilding b, String target, int length})>[];
  for (final entry in _aliasesByInitial[key[0]] ?? const []) {
    final rule = entry.rule, b = entry.building, alias = entry.key;
    if (alias.isEmpty ||
        (query.campus != null && rule.campus != query.campus)) {
      continue;
    }
    if (rule.department.isNotEmpty && rule.department != department) continue;
    if (rule.department.isNotEmpty && query.campus == null) continue;
    if (rule.event.isNotEmpty) continue;
    if (rule.groupId.isNotEmpty && rule.groupId != groupId) {
      final groups = teachingGroups.where((g) => g.id == rule.groupId);
      if (!groups.any(
        (g) => [
          g.name,
          ...g.aliases,
        ].any((n) => key.contains(normalizeTeachingName(n))),
      )) {
        continue;
      }
    }
    if (rule.groupId.isEmpty &&
        rule.department.isEmpty &&
        RegExp(r'^(?:\d+号楼|[a-z]\d*)$').hasMatch(alias)) {
      continue;
    }
    if (rule.exact ? key != alias : !key.startsWith(alias)) continue;
    final tail = key.substring(alias.length);
    if (tail.isNotEmpty &&
        !RegExp(
          r'^(?:[a-z]|[零〇一二两三四五六七八九十百\d]|[东南西北中]|教室|会议室|报告厅|实验室|机房|办公室|阶梯|研讨室|多媒体|模拟法庭|小?合唱厅|体育部)',
        ).hasMatch(tail)) {
      continue;
    }
    var target = rule.target;
    if (target == b.id) {
      final regions =
          b.regions.where((r) {
            final code = normalizeTeachingName(r.code);
            return tail.startsWith(code) &&
                (tail.length == code.length ||
                    RegExp(
                      r'^(?:\d|[区楼栋座]|[零〇一二三四五六七八九十]|教室|会议|报告|合唱)',
                    ).hasMatch(tail.substring(code.length)));
          }).toList()..sort(
            (a, b) => normalizeTeachingName(
              b.code,
            ).length.compareTo(normalizeTeachingName(a.code).length),
          );
      if (regions.isNotEmpty) target = regions.first.id;
    }
    candidates.add((b: b, target: target, length: alias.length));
  }
  if (candidates.isEmpty) {
    final groups = teachingGroups
        .where(
          (g) =>
              (query.campus == null || g.campus == query.campus) &&
              [
                g.name,
                ...g.aliases,
              ].any((a) => normalizeTeachingName(a) == key),
        )
        .toList();
    return groups.length == 1
        ? TeachingMatch('group:${groups.single.id}', null, groups.single.point)
        : null;
  }
  candidates.sort((a, b) => b.length.compareTo(a.length));
  final best = candidates
      .where((c) => c.length == candidates.first.length)
      .toList();
  if (best.map((c) => c.b.id).toSet().length != 1) return null;
  final regions = best.where((c) => c.target != c.b.id).toList();
  if (regions.map((c) => c.target).toSet().length > 1) return null;
  final chosen = regions.isNotEmpty ? regions.first : best.first;
  final r = chosen.b.regions.where((r) => r.id == chosen.target).firstOrNull;
  return TeachingMatch(chosen.b.id, r?.id, r?.point ?? chosen.b.point);
}
