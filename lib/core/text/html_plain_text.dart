// Plain text only: never execute HTML or fetch remote embeds.
String readableHtmlText(String source) {
  var text = source.replaceAll(
    RegExp(
      r'<(script|style)[^>]*>.*?</\1>',
      caseSensitive: false,
      dotAll: true,
    ),
    '',
  );
  text = text.replaceAll(
    RegExp(r'<br\s*/?>|</(?:p|div|li|h[1-6])>', caseSensitive: false),
    '\n',
  );
  text = text.replaceAll(RegExp(r'<[^>]+>'), '');
  const entities = {
    '&nbsp;': ' ',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&amp;': '&',
  };
  for (final e in entities.entries) {
    text = text.replaceAll(e.key, e.value);
  }
  text = text.replaceAllMapped(RegExp(r'&#(x[0-9a-fA-F]+|[0-9]+);'), (m) {
    final raw = m[1]!;
    final n = raw.startsWith('x')
        ? int.tryParse(raw.substring(1), radix: 16)
        : int.tryParse(raw);
    return n != null && n > 0 && n <= 0x10ffff ? String.fromCharCode(n) : m[0]!;
  });
  return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
