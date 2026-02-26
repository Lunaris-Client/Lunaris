import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ContentCache {
  static final ContentCache _instance = ContentCache._();
  factory ContentCache() => _instance;
  ContentCache._();

  static const _defaultMaxSizeMb = 100;
  String? _resolvedDir;

  Future<String> _cacheDir() async {
    if (_resolvedDir != null) return _resolvedDir!;
    final dir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${dir.path}/content_cache');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    _resolvedDir = cacheDir.path;
    return _resolvedDir!;
  }

  String _sanitize(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
  }

  Future<void> saveTopicList(
    String serverUrl,
    String filter,
    Map<String, dynamic> data,
  ) async {
    final key = '${_sanitize(serverUrl)}_topics_${_sanitize(filter)}';
    await _write(key, data);
  }

  Future<Map<String, dynamic>?> loadTopicList(
    String serverUrl,
    String filter,
  ) async {
    final key = '${_sanitize(serverUrl)}_topics_${_sanitize(filter)}';
    return _read(key);
  }

  Future<void> saveTopicDetail(
    String serverUrl,
    int topicId,
    Map<String, dynamic> data,
  ) async {
    final key = '${_sanitize(serverUrl)}_topic_$topicId';
    await _write(key, data);
  }

  Future<Map<String, dynamic>?> loadTopicDetail(
    String serverUrl,
    int topicId,
  ) async {
    final key = '${_sanitize(serverUrl)}_topic_$topicId';
    return _read(key);
  }

  Future<void> saveUserProfile(
    String serverUrl,
    String username,
    Map<String, dynamic> data,
  ) async {
    final key = '${_sanitize(serverUrl)}_user_${_sanitize(username)}';
    await _write(key, data);
  }

  Future<Map<String, dynamic>?> loadUserProfile(
    String serverUrl,
    String username,
  ) async {
    final key = '${_sanitize(serverUrl)}_user_${_sanitize(username)}';
    return _read(key);
  }

  Future<void> _write(String key, Map<String, dynamic> data) async {
    final dir = await _cacheDir();
    final wrapped = {
      'cachedAt': DateTime.now().toIso8601String(),
      'data': data,
    };
    await File('$dir/$key.json').writeAsString(jsonEncode(wrapped));
  }

  Future<Map<String, dynamic>?> _read(String key) async {
    try {
      final dir = await _cacheDir();
      final file = File('$dir/$key.json');
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return raw['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> cachedAt(String serverUrl, String filter) async {
    try {
      final key = '${_sanitize(serverUrl)}_topics_${_sanitize(filter)}';
      final dir = await _cacheDir();
      final file = File('$dir/$key.json');
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final ts = raw['cachedAt'] as String?;
      return ts != null ? DateTime.tryParse(ts) : null;
    } catch (_) {
      return null;
    }
  }

  Future<int> cacheSizeBytes() async {
    try {
      final dir = Directory(await _cacheDir());
      if (!await dir.exists()) return 0;
      int total = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clearAll() async {
    try {
      final dir = Directory(await _cacheDir());
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    } catch (_) {}
  }

  Future<void> clearServer(String serverUrl) async {
    try {
      final prefix = _sanitize(serverUrl);
      final dir = Directory(await _cacheDir());
      if (!await dir.exists()) return;
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.contains(prefix)) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }

  Future<void> evictIfOverLimit(int maxSizeMb) async {
    final maxBytes = (maxSizeMb > 0 ? maxSizeMb : _defaultMaxSizeMb) * 1024 * 1024;
    final current = await cacheSizeBytes();
    if (current <= maxBytes) return;

    try {
      final dir = Directory(await _cacheDir());
      final files = <File>[];
      await for (final entity in dir.list()) {
        if (entity is File) files.add(entity);
      }
      files.sort((a, b) {
        final aTime = a.lastModifiedSync();
        final bTime = b.lastModifiedSync();
        return aTime.compareTo(bTime);
      });

      int size = current;
      for (final file in files) {
        if (size <= maxBytes) break;
        final len = await file.length();
        await file.delete();
        size -= len;
      }
    } catch (_) {}
  }
}
