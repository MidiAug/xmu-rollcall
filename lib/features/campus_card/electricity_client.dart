import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'campus_card_models.dart';

String _text(String html) => html
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .trim();
Map<String, String> _attrs(String tag) => {
  for (final m in RegExp(
    r'''([\w-]+)\s*=\s*(["'])(.*?)\2''',
    dotAll: true,
  ).allMatches(tag))
    m[1]!.toLowerCase(): _text(m[3]!),
};
List<CardChoice> electricOptions(String html, String name) {
  final select = RegExp(
    '<select[^>]*name="$name"[^>]*>(.*?)</select>',
    dotAll: true,
  ).firstMatch(html)?.group(1);
  if (select == null) throw const FormatException('电费查询页面已变化，请稍后重试');
  return [
    for (final m in RegExp(
      r'<option\b([^>]*)>(.*?)</option>',
      dotAll: true,
    ).allMatches(select))
      if ((_attrs(m[1]!)['value'] ?? '').isNotEmpty)
        CardChoice(_attrs(m[1]!)['value']!, _text(m[2]!)),
  ];
}

Map<String, String> _fields(String html) => {
  for (final m in RegExp(
    r'<input\b[^>]*>',
    caseSensitive: false,
  ).allMatches(html))
    if (_attrs(m[0]!) case {
      'name': final String name,
      'value': final String value,
    })
      name: value,
};

class ElectricReading {
  const ElectricReading({
    required this.room,
    required this.balance,
    required this.kwh,
    required this.checkedAt,
    this.reportedAt,
  });
  final CardElectricRoom room;
  final double balance, kwh;
  final DateTime checkedAt;
  final String? reportedAt;
  Map<String, dynamic> toJson() => {
    'room': room.toJson(),
    'balance': balance,
    'kwh': kwh,
    'checkedAt': checkedAt.toIso8601String(),
    'reportedAt': reportedAt,
  };
  factory ElectricReading.fromJson(Map<String, dynamic> v) => ElectricReading(
    room: CardElectricRoom.fromJson(cardMap(v['room'])),
    balance: cardNumber(v['balance']).toDouble(),
    kwh: cardNumber(v['kwh']).toDouble(),
    checkedAt: DateTime.parse(v['checkedAt'] as String),
    reportedAt: v['reportedAt'] as String?,
  );
}

ElectricReading parseElectricReading(String html, CardElectricRoom room) {
  final label = RegExp(
    r'<label[^>]*id="lableft"[^>]*>(.*?)</label>',
    dotAll: true,
  ).firstMatch(html)?.group(1);
  final text = _text(label ?? '');
  final amount = RegExp(r'账户余额[：:]\s*(-?\d+(?:\.\d+)?)\s*元').firstMatch(text);
  final energy = RegExp(r'剩余电量[：:]\s*(-?\d+(?:\.\d+)?)\s*度').firstMatch(text);
  if (amount == null || energy == null) {
    throw const FormatException('未查询到该宿舍电费，请核对宿舍');
  }
  final dates = <String>[];
  for (final row in RegExp(
    r'<tr[^>]*id="dxgvElec_DXDataRow\d+"[^>]*>(.*?)</tr>',
    dotAll: true,
  ).allMatches(html)) {
    final date = RegExp(
      r'\d{4}[-/]\d{1,2}[-/]\d{1,2}',
    ).firstMatch(_text(row[1]!))?.group(0);
    if (date != null) dates.add(date.replaceAll('/', '-'));
  }
  dates.sort((a, b) => DateTime.parse(b).compareTo(DateTime.parse(a)));
  return ElectricReading(
    room: room,
    balance: double.parse(amount[1]!),
    kwh: double.parse(energy[1]!),
    checkedAt: DateTime.now(),
    reportedAt: dates.firstOrNull,
  );
}

/// The school's anonymous, read-only form. No WeCom cookies or IDS credentials.
class ElectricityClient {
  ElectricityClient({Dio? dio, RateLimiter? limiter})
    : dio = dio ?? Dio(),
      limiter = limiter ?? RateLimiter() {
    this.dio.interceptors.add(CookieManager(CookieJar()));
    this.dio.options.connectTimeout = const Duration(seconds: 15);
    this.dio.options.receiveTimeout = const Duration(seconds: 25);
  }
  static const endpoint =
      'https://elec.xmu.edu.cn/PdmlWebSetup/Pages/SMSMain.aspx';
  final Dio dio;
  final RateLimiter limiter;
  Future<bool> Function()? identityGuard;
  Future<String>? _initial;
  final _areaPages = <String, Future<String>>{};
  Future<String> _request([Map<String, String>? form]) async {
    final response = await limiter.schedule(() async {
      if (identityGuard != null && !await identityGuard!()) {
        throw StateError('账号已切换');
      }
      return dio.request<String>(
        endpoint,
        data: form,
        options: Options(
          method: form == null ? 'GET' : 'POST',
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
          followRedirects: false,
        ),
      );
    });
    if (identityGuard != null && !await identityGuard!()) {
      throw StateError('账号已切换');
    }
    if (response.statusCode != 200 || response.data == null) {
      throw const FormatException('暂时无法查询宿舍电费，请检查校园网络后重试');
    }
    return response.data!;
  }

  Future<ElectricReading> read(CardElectricRoom room) async {
    var html = await (_initial ??= _request());
    final areas = electricOptions(html, 'drxiaoqu');
    final area = areas
        .where((v) => v.id == room.area.id || v.name == room.area.name)
        .firstOrNull;
    if (area == null) throw const FormatException('查询站未提供该园区');
    html = await (_areaPages[area.id] ??= _request({
      ..._fields(html),
      'drxiaoqu': area.id,
      'drlou': '',
      'txtRoomid': '',
      'dxbtnQuery': '查询',
    }));
    final buildings = electricOptions(html, 'drlou');
    String normal(String value) => value.replaceAll(RegExp(r'[\s#号楼幢栋]'), '');
    var building = buildings
        .where(
          (v) =>
              v.id == room.building.id ||
              normal(v.name) == normal(room.building.name),
        )
        .firstOrNull;
    // Legacy directories use e.g. DX1, while the current directory uses 笃行1号.
    // A single building number is only resolved inside the already matched area.
    if (building == null) {
      final number = RegExp(r'\d+').allMatches(room.building.name).toList();
      if (number.length == 1) {
        final candidates = buildings.where((v) {
          final ns = RegExp(r'\d+').allMatches(v.name).toList();
          return ns.length == 1 &&
              int.parse(ns.single[0]!) == int.parse(number.single[0]!);
        }).toList();
        if (candidates.length == 1) building = candidates.single;
      }
    }
    if (building == null) throw const FormatException('两个查询站的楼栋尚未对应，请核对楼栋');
    html = await _request({
      ..._fields(html),
      'drxiaoqu': area.id,
      'drlou': building.id,
      'txtRoomid': room.id,
      'dxbtnQuery': '查询',
    });
    return parseElectricReading(html, room);
  }

  void close() => dio.close(force: true);
}
