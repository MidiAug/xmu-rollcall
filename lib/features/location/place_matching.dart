import 'campus_places.dart';
import 'location_models.dart';

String normalizePlaceName(String text) {
  var value = String.fromCharCodes(
    text.runes.map((r) => r >= 0xff01 && r <= 0xff5e ? r - 0xfee0 : r),
  ).toLowerCase();
  const numbers = {
    '一': '1',
    '二': '2',
    '三': '3',
    '四': '4',
    '五': '5',
    '六': '6',
    '七': '7',
    '八': '8',
    '九': '9',
  };
  value = value.replaceAllMapped(
    RegExp(r'[一二三四五六七八九](?=号?楼|\)|$|\s*\d)'),
    (m) => numbers[m[0]]!,
  );
  return value.replaceAll(RegExp(r'[\s　（）()·,，_-]'), '');
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
  for (final c in Campus.values) {
    if (room.contains(c.label)) return c;
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
}) {
  final outsideBrackets = room.replaceAll(RegExp(r'（[^）]*）|\([^)]*\)'), '');
  if (room.trim().isEmpty || RegExp(r'[/、；;]').hasMatch(outsideBrackets)) {
    return null;
  }
  final hint = campusInName(room) ?? campus;
  var key = normalizePlaceName(room);
  for (final c in Campus.values) {
    key = key.replaceAll(c.label, '');
  }
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
          !RegExp(r'^(?:[a-z]区?)?\d{2,5}(?:室|教室)?$').hasMatch(tail)) {
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
  for (final p in campusPlaces) {
    consider(p.saved, [p.name, ...p.aliases]);
  }
  return matches.length == 1 ? matches.values.single : null;
}

Campus preferredCampus(Iterable<String> rooms, List<SavedLocation> custom) {
  final votes = <Campus, int>{};
  for (final room in rooms) {
    final place = matchCoursePlace(room, custom);
    final campus =
        campusInName(room) ?? (place == null ? null : campusForPoint(place));
    if (campus != null) votes[campus] = (votes[campus] ?? 0) + 1;
  }
  return Campus.values.reduce(
    (a, b) => (votes[b] ?? 0) > (votes[a] ?? 0) ? b : a,
  );
}
