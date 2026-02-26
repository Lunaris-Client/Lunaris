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
