import 'dart:ui';

Color parseHexColor(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length == 3) {
    final expanded = cleaned.split('').map((c) => '$c$c').join();
    return Color(int.parse('FF$expanded', radix: 16));
  }
  if (cleaned.length == 6) {
    return Color(int.parse('FF$cleaned', radix: 16));
  }
  return Color(int.parse(cleaned, radix: 16));
}

String stripHtml(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&hellip;', '...')
      .trim();
}

String formatCount(int count) {
  if (count >= 10000) return '${(count / 1000).toStringAsFixed(0)}k';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
  return count.toString();
}

String resolveAvatarUrl(String serverUrl, String template, {int size = 48}) {
  final resolved = template.replaceAll('{size}', '$size');
  if (resolved.startsWith('http')) return resolved;
  return '$serverUrl$resolved';
}
