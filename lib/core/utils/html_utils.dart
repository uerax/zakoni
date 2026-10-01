/// XML 1.0 (Fifth Edition) valid character check.
bool _isXmlSafeCodePoint(int code) {
  return code == 0x9 ||
      code == 0xa ||
      code == 0xd ||
      (code >= 0x20 && code <= 0xd7ff) ||
      (code >= 0xe000 && code <= 0x10ffff && code != 0xfffe && code != 0xffff);
}

final _htmlEntityRegex = RegExp(r'&(?:#(?:[xX]([0-9a-fA-F]+)|(\d+))|([a-zA-Z]+));');

/// Single-pass HTML entity decoder.
/// Prevents recursive multi-pass decoding (e.g. `&amp;#39;` -> `&#39;`, never to `'`).
/// Safely handles decimal, hex (`&#x..;` / `&#X..;`), and common named entities.
String decodeHtmlEntities(String s) {
  if (s.isEmpty || !s.contains('&')) return s;

  return s.replaceAllMapped(_htmlEntityRegex, (match) {
    final hex = match.group(1);
    final dec = match.group(2);
    final named = match.group(3);

    if (dec != null) {
      final code = int.tryParse(dec);
      if (code != null && _isXmlSafeCodePoint(code)) {
        return String.fromCharCode(code);
      }
      return match.group(0)!;
    }

    if (hex != null) {
      final code = int.tryParse(hex, radix: 16);
      if (code != null && _isXmlSafeCodePoint(code)) {
        return String.fromCharCode(code);
      }
      return match.group(0)!;
    }

    switch (named) {
      case 'amp':
        return '&';
      case 'lt':
        return '<';
      case 'gt':
        return '>';
      case 'quot':
        return '"';
      case 'apos':
        return "'";
      case 'nbsp':
        return ' ';
      default:
        return match.group(0)!;
    }
  });
}
