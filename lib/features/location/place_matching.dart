import 'campus_places.dart';
import 'location_models.dart';
import 'teaching_catalog.dart';

String normalizePlaceName(String text) => normalizeTeachingName(text);

SavedLocation? _catalogLocation(
  String room, {
  Campus? campus,
  String department = '',
  String groupId = '',
}) {
  final result = matchTeachingLocation(
    room,
    campus: campus?.label.replaceFirst('校区', ''),
    department: department,
    groupId: groupId,
  );
  final point = result?.point;
  if (point == null || !point.usable) return null;
  return SavedLocation(
    id: point.id,
    note: point.name,
    latitude: point.latitude,
    longitude: point.longitude,
    createdAt: DateTime(2026, 11, 3),
  );
}

/// A building/wing is one physical location; room numbers remain timetable text.
String coursePlaceGroup(String room) {
  String display(String value) => room.contains('（') || room.contains('）')
      ? value.replaceAll('(', '（').replaceAll(')', '）')
      : value;
  final trimmed = String.fromCharCodes(
    room.trim().runes.map(
      (r) =>
          (r >= 0xff10 && r <= 0xff19 ||
              r >= 0xff21 && r <= 0xff3a ||
              r >= 0xff41 && r <= 0xff5a)
          ? r - 0xfee0
          : r,
    ),
  ).replaceAll('（', '(').replaceAll('）', ')');
  if (RegExp(
    r'[/、；;,，]',
  ).hasMatch(trimmed.replaceAll(RegExp(r'（[^）]*）|\([^)]*\)'), ''))) {
    // Split only outside parenthesized building aliases. A list of rooms in
    // one wing is one point; different wings/buildings remain unresolved.
    final parts = <String>[];
    var depth = 0, start = 0;
    for (var i = 0; i < trimmed.length; i++) {
      final char = trimmed[i];
      if (char == '(') depth++;
      if (char == ')' && depth > 0) depth--;
      if (depth == 0 && RegExp(r'[/、；;,，]').hasMatch(char)) {
        parts.add(trimmed.substring(start, i).trim());
        start = i + 1;
      }
    }
    parts.add(trimmed.substring(start).trim());
    if (parts.any((p) => p.isEmpty)) return display(trimmed);
    final first = coursePlaceGroup(parts.first);
    final wing = RegExp(
      r'^(.*?)\s+([ABC])区$',
      caseSensitive: false,
    ).firstMatch(first);
    final building = wing?.group(1) ?? first;
    for (final part in parts.skip(1)) {
      final next = RegExp(r'^\d{2,5}(?:室|教室)?$').hasMatch(part)
          ? first
          : coursePlaceGroup(
              RegExp(
                    r'^[ABC](?:区)?\s*\d{2,5}(?:室|教室)?$',
                    caseSensitive: false,
                  ).hasMatch(part)
                  ? '$building $part'
                  : part,
            );
      if (normalizePlaceName(next) != normalizePlaceName(first)) {
        return display(trimmed);
      }
    }
    return display(first);
  }
  final wing = RegExp(
    r'^(.*?)[\s　]*([A-Za-zＡ-Ｚａ-ｚ])(?:区)?[\s　]*\d{2,5}(?:室|教室)?$',
  ).firstMatch(trimmed);
  if (wing != null) {
    return display(
      '${wing[1]!.trim()} ${normalizePlaceName(wing[2]!).toUpperCase()}区',
    );
  }
  final roomNumber = RegExp(
    r'^(.*(?:楼|馆|中心)(?:（[^）]*）|\([^)]*\))?)[\s　]*\d{2,5}(?:室|教室)?$',
  ).firstMatch(trimmed);
  return display(roomNumber?.group(1)?.trim() ?? trimmed);
}

/// Expand a combined classroom string into physical building/wing groups.
/// Abbreviated room suffixes inherit the preceding building, not another wing.
List<String> coursePlaceNames(String room) {
  final text = String.fromCharCodes(
    room.runes.map((r) => r >= 0xff01 && r <= 0xff5e ? r - 0xfee0 : r),
  ).replaceAll('（', '(').replaceAll('）', ')');
  final parts = <String>[];
  var depth = 0, start = 0;
  for (var i = 0; i < text.length; i++) {
    if (text[i] == '(') depth++;
    if (text[i] == ')' && depth > 0) depth--;
    if (depth == 0 && RegExp(r'[/、；;,，]').hasMatch(text[i])) {
      parts.add(text.substring(start, i).trim());
      start = i + 1;
    }
  }
  parts.add(text.substring(start).trim());
  if (parts.any((p) => p.isEmpty)) return [coursePlaceGroup(room)];
  var previous = coursePlaceGroup(parts.first);
  final names = <String>[previous];
  for (final part in parts.skip(1)) {
    final building = previous.replaceFirst(
      RegExp(r'\s+[ABC]区$', caseSensitive: false),
      '',
    );
    final expanded =
        RegExp(
          r'^[ABC](?:区)?\s*\d{2,5}(?:室|教室)?$',
          caseSensitive: false,
        ).hasMatch(part)
        ? '$building $part'
        : RegExp(r'^\d{2,5}(?:室|教室)?$').hasMatch(part)
        ? '$previous $part'
        : part;
    previous = coursePlaceGroup(expanded);
    names.add(previous);
  }
  return {
    for (final name in names)
      coursePlaceIdentity(name): (room.contains('（') || room.contains('）')
          ? name.replaceAll('(', '（').replaceAll(')', '）')
          : name),
  }.values.toList();
}

String coursePlaceIdentity(String room) {
  final maintained =
      matchTeachingLocation(room) ??
      matchTeachingLocation(coursePlaceGroup(room));
  if (maintained != null) {
    return maintained.point?.id ??
        'xmu:teaching:${maintained.regionId ?? maintained.buildingId}';
  }
  return normalizePlaceName(coursePlaceGroup(room));
}

Campus? campusForPoint(SavedLocation place) {
  final ordered = [...Campus.values]
    ..sort(
      (a, b) =>
          metersBetween(
            place.latitude,
            place.longitude,
            a.center.latitude,
            a.center.longitude,
          ).compareTo(
            metersBetween(
              place.latitude,
              place.longitude,
              b.center.latitude,
              b.center.longitude,
            ),
          ),
    );
  final nearest = ordered.first;
  return metersBetween(
            place.latitude,
            place.longitude,
            nearest.center.latitude,
            nearest.center.longitude,
          ) <
          6000
      ? nearest
      : null;
}

Campus? campusInName(String room) {
  final name = teachingNameParts(room).campus;
  if (name != null) {
    return Campus.values.where((c) => c.label == '$name校区').firstOrNull;
  }
  if (room.contains('西部片区') || room.contains('西部区')) return Campus.xiangan;
  if (room.contains('海韵')) return Campus.siming;
  return null;
}

/// Exact custom room first, then longest building prefix with room suffix.
/// Equal candidates remain unresolved; no edit distance guesses between buildings.
SavedLocation? matchCoursePlace(
  String room,
  List<SavedLocation> custom, {
  Campus? campus,
  String department = '',
  String groupId = '',
}) {
  custom = custom.where((p) => !isReferencePlace(p)).toList();
  if (room.trim().isEmpty) return null;
  final grouped = coursePlaceGroup(room);
  final outsideBrackets = grouped.replaceAll(RegExp(r'（[^）]*）|\([^)]*\)'), '');
  if (RegExp(r'[/、；;,，]').hasMatch(outsideBrackets)) return null;
  // Resolve combined rooms through their common building/wing, preserving
  // the original classroom string in timetable data.
  final originalOutside = room
      .replaceAll('（', '(')
      .replaceAll('）', ')')
      .replaceAll(RegExp(r'\([^)]*\)'), '');
  if (RegExp(r'[/、；;,，]').hasMatch(originalOutside)) {
    return matchCoursePlace(
      grouped,
      custom,
      campus: campus,
      department: department,
      groupId: groupId,
    );
  }
  final hint = campusInName(room) ?? campus;
  var key = normalizePlaceName(room);
  for (final c in Campus.values) {
    key = key.replaceAll(c.label, '');
  }
  final groupKey = normalizePlaceName(coursePlaceGroup(room));
  final groupExact = custom
      .where(
        (p) =>
            (hint == null || campusForPoint(p) == hint) &&
            (normalizePlaceName(p.note) == groupKey ||
                (normalizePlaceName(p.note) ==
                        normalizePlaceName(coursePlaceGroup(p.note)) &&
                    coursePlaceIdentity(p.note) == coursePlaceIdentity(room))),
      )
      .toList();
  if (groupExact.length == 1) return groupExact.single;
  if (groupExact.length > 1) return null;
  final oldGroup = custom
      .where(
        (p) =>
            (hint == null || campusForPoint(p) == hint) &&
            coursePlaceIdentity(p.note) == coursePlaceIdentity(room),
      )
      .toList();
  if (oldGroup.length == 1) return oldGroup.single;
  if (oldGroup.length > 1) return null;
  final exact = custom
      .where(
        (p) =>
            (hint == null || campusForPoint(p) == hint) &&
            (normalizePlaceName(p.note) == key ||
                normalizePlaceName(p.note) == normalizePlaceName(room)),
      )
      .toList();
  if (exact.length == 1) return exact.single;
  if (exact.length > 1) return null;
  var bestLength = 0;
  final matches = <String, SavedLocation>{};
  void consider(SavedLocation place, Iterable<String> aliases) {
    if (hint != null && campusForPoint(place) != hint) return;
    for (final raw in aliases) {
      final alias = normalizePlaceName(raw);
      if (alias.isEmpty || !key.startsWith(alias)) continue;
      final tail = key.substring(alias.length);
      if (tail.isNotEmpty &&
          !RegExp(
            r'^(?:[a-z]区?|(?:[a-z]区?)?\d{2,5}(?:室|教室)?)$',
          ).hasMatch(tail)) {
        continue;
      }
      if (alias.length > bestLength) {
        matches.clear();
        bestLength = alias.length;
      }
      if (alias.length == bestLength) matches[place.id] = place;
    }
  }

  for (final p in custom) {
    consider(p, [p.note]);
  }
  if (matches.length > 1) return null;
  if (matches.length == 1) return matches.values.single;
  return _catalogLocation(
    room,
    campus: hint,
    department: department,
    groupId: groupId,
  );
}

Campus preferredCampus(
  Iterable<String> rooms,
  List<SavedLocation> custom, {
  Campus? collegeCampus,
}) {
  final votes = <Campus, int>{};
  for (final room in rooms) {
    final place = matchCoursePlace(room, custom);
    final campus =
        campusInName(room) ?? (place == null ? null : campusForPoint(place));
    if (campus != null) votes[campus] = (votes[campus] ?? 0) + 1;
  }
  if (votes.isEmpty) return collegeCampus ?? Campus.siming;
  return Campus.values.reduce(
    (a, b) => (votes[b] ?? 0) > (votes[a] ?? 0) ? b : a,
  );
}
