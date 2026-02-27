import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lunaris/core/providers/providers.dart';

const _storageKey = 'frequent_emojis';
const _defaultEmojis = ['heart', '+1', 'laughing', 'open_mouth', 'cry', 'angry'];

final frequentEmojiServiceProvider = Provider<FrequentEmojiService>((ref) {
  return FrequentEmojiService(ref.watch(sharedPreferencesProvider));
});

class FrequentEmojiService {
  final SharedPreferences _prefs;

  FrequentEmojiService(this._prefs);

  Map<String, int> _loadCounts() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }

  Future<void> recordUsage(String emoji) async {
    final counts = _loadCounts();
    counts[emoji] = (counts[emoji] ?? 0) + 1;
    await _prefs.setString(_storageKey, json.encode(counts));
  }

  List<String> getTopEmojis(int count) {
    final counts = _loadCounts();
    if (counts.isEmpty) return _defaultEmojis.take(count).toList();

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = sorted.take(count).map((e) => e.key).toList();

    if (top.length < count) {
      for (final d in _defaultEmojis) {
        if (top.length >= count) break;
        if (!top.contains(d)) top.add(d);
      }
    }

    return top;
  }
}
