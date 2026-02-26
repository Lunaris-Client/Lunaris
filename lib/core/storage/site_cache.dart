import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SiteCache {
  static const _staleThreshold = Duration(minutes: 5);
  String? _resolvedDir;

  Future<String> _cacheDir() async {
    if (_resolvedDir != null) return _resolvedDir!;
    final dir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${dir.path}/site_cache');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    _resolvedDir = cacheDir.path;
    return _resolvedDir!;
  }

  String _fileKey(String serverUrl) {
    return serverUrl
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .toLowerCase();
  }

  Future<Map<String, dynamic>?> load(String serverUrl) async {
    try {
      final path = '${await _cacheDir()}/${_fileKey(serverUrl)}.json';
      final file = File(path);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String serverUrl, Map<String, dynamic> data) async {
    final path = '${await _cacheDir()}/${_fileKey(serverUrl)}.json';
    await File(path).writeAsString(jsonEncode(data));
  }

  Future<void> clear(String serverUrl) async {
    try {
      final path = '${await _cacheDir()}/${_fileKey(serverUrl)}.json';
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  bool isStale(DateTime fetchedAt) {
    return DateTime.now().difference(fetchedAt) > _staleThreshold;
  }
}
