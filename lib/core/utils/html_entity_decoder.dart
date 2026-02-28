const _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': '\u00A0',
  'ndash': '\u2013',
  'mdash': '\u2014',
  'laquo': '\u00AB',
  'raquo': '\u00BB',
  'hellip': '\u2026',
  'copy': '\u00A9',
  'reg': '\u00AE',
  'trade': '\u2122',
};

final _entityPattern = RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);');

String decodeHtmlEntities(String input) {
  return input.replaceAllMapped(_entityPattern, (match) {
    final entity = match.group(1)!;
    if (entity.startsWith('#x') || entity.startsWith('#X')) {
      final codePoint = int.tryParse(entity.substring(2), radix: 16);
      if (codePoint != null) return String.fromCharCode(codePoint);
    } else if (entity.startsWith('#')) {
      final codePoint = int.tryParse(entity.substring(1));
      if (codePoint != null) return String.fromCharCode(codePoint);
    } else {
      final replacement = _namedEntities[entity.toLowerCase()];
      if (replacement != null) return replacement;
    }
    return match.group(0)!;
  });
}
