import 'dart:convert';
import 'dart:io';

/// Cookie ↔ JSON helpers shared by owner / assist sessions.
Map<String, dynamic> cookieToJson(Cookie c) => {
      'name': c.name,
      'value': c.value,
      'domain': c.domain,
      'path': c.path,
      'secure': c.secure,
      'httpOnly': c.httpOnly,
    };

Cookie cookieFromJson(Map<String, dynamic> json) {
  return Cookie(json['name'] as String, json['value'] as String)
    ..domain = json['domain'] as String?
    ..path = json['path'] as String? ?? '/'
    ..secure = json['secure'] as bool? ?? false
    ..httpOnly = json['httpOnly'] as bool? ?? false;
}

String encodeCookies(Iterable<Cookie> cookies) =>
    jsonEncode(cookies.map(cookieToJson).toList());

List<Cookie> decodeCookies(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => cookieFromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  } catch (_) {
    return const [];
  }
}

List<Cookie> parseCookieHeader(
  String cookieHeader, {
  required String domain,
}) {
  final cookies = <Cookie>[];
  for (final part in cookieHeader.split(';')) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) continue;
    final eq = trimmed.indexOf('=');
    if (eq <= 0) continue;
    final name = trimmed.substring(0, eq).trim();
    final value = trimmed.substring(eq + 1).trim();
    if (name.isEmpty) continue;
    cookies.add(
      Cookie(name, value)
        ..domain = domain
        ..path = '/',
    );
  }
  return cookies;
}
