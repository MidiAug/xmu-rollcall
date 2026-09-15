import 'dart:convert';

/// Normalize scanned / pasted QR content into TronClass `data` token.
String parseQrRollcallData(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('二维码内容为空');
  }

  if (trimmed.startsWith('{')) {
    try {
      final map = jsonDecode(trimmed);
      if (map is Map && map['data'] != null) {
        final d = '${map['data']}'.trim();
        if (d.isNotEmpty) return d;
      }
    } catch (_) {
      // fall through
    }
  }

  final asUri = Uri.tryParse(trimmed);
  if (asUri != null &&
      (asUri.hasScheme || trimmed.contains('?')) &&
      asUri.queryParameters['data'] != null) {
    final d = asUri.queryParameters['data']!.trim();
    if (d.isNotEmpty) return d;
  }

  // Some scanners wrap URL-encoded JSON.
  if (trimmed.contains('%7B') || trimmed.contains('%22')) {
    try {
      final decoded = Uri.decodeComponent(trimmed);
      if (decoded != trimmed) return parseQrRollcallData(decoded);
    } catch (_) {}
  }

  return trimmed;
}
