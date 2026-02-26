import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:uuid/uuid.dart';

import 'package:lunaris/core/auth/rsa_key_helper.dart';

class AuthSession {
  final String serverUrl;
  final String clientId;
  final String nonce;
  final RSAPublicKey publicKey;
  final RSAPrivateKey privateKey;
  final String redirectUrl;

  AuthSession({
    required this.serverUrl,
    required this.clientId,
    required this.nonce,
    required this.publicKey,
    required this.privateKey,
    required this.redirectUrl,
  });
}

class AuthResult {
  final String apiKey;
  final String nonce;
  final bool push;
  final int apiVersion;

  AuthResult({
    required this.apiKey,
    required this.nonce,
    required this.push,
    required this.apiVersion,
  });
}

class AuthService {
  static const _scopes = 'read,write,notifications,push,session_info';
  static const _appName = 'Lunaris';
  static const _storage = FlutterSecureStorage();

  AuthSession? _pendingSession;
  HttpServer? _desktopServer;

  AuthSession? get pendingSession => _pendingSession;

  bool get _isDesktop =>
      !kIsWeb &&
      (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  Future<String> buildAuthUrl(String serverUrl) async {
    final clientId = const Uuid().v4();
    final nonce = _generateNonce();
    final keyPair = await compute(_generateKeyPairIsolate, null);

    final publicKeyPem = RsaKeyHelper.encodePublicKeyToPem(keyPair.publicKey);
    final privateKeyPem =
        RsaKeyHelper.encodePrivateKeyToPem(keyPair.privateKey);

    await _storage.write(
      key: 'auth_private_key_$clientId',
      value: privateKeyPem,
    );

    String redirectUrl;
    if (_isDesktop) {
      redirectUrl = await _startDesktopRedirectServer();
    } else {
      redirectUrl = 'lunaris://auth_redirect';
    }

    _pendingSession = AuthSession(
      serverUrl: serverUrl,
      clientId: clientId,
      nonce: nonce,
      publicKey: keyPair.publicKey,
      privateKey: keyPair.privateKey,
      redirectUrl: redirectUrl,
    );

    final params = {
      'client_id': clientId,
      'application_name': _appName,
      'public_key': publicKeyPem,
      'nonce': nonce,
      'scopes': _scopes,
      'auth_redirect': redirectUrl,
    };
    final query = params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$serverUrl/user-api-key/new?$query';
  }

  AuthResult decryptPayload(String base64Payload) {
    if (_pendingSession == null) {
      throw StateError('No pending auth session');
    }

    final cleanPayload = base64Payload.replaceAll(RegExp(r'\s'), '');
    final encrypted = base64Decode(cleanPayload);
    final decrypted = RsaKeyHelper.decrypt(
      _pendingSession!.privateKey,
      encrypted,
    );

    final json = jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>;
    return AuthResult(
      apiKey: json['key'] as String,
      nonce: json['nonce'] as String,
      push: json['push'] as bool? ?? false,
      apiVersion: json['api'] as int? ?? 0,
    );
  }

  bool verifyNonce(AuthResult result) {
    return _pendingSession != null && result.nonce == _pendingSession!.nonce;
  }

  Future<void> storeApiKey(String serverUrl, String apiKey) async {
    await _storage.write(key: 'api_key_$serverUrl', value: apiKey);
  }

  Future<String?> loadApiKey(String serverUrl) async {
    return await _storage.read(key: 'api_key_$serverUrl');
  }

  Future<void> deleteApiKey(String serverUrl) async {
    await _storage.delete(key: 'api_key_$serverUrl');
  }

  Future<void> clearPendingSession() async {
    if (_pendingSession != null) {
      await _storage.delete(
          key: 'auth_private_key_${_pendingSession!.clientId}');
      _pendingSession = null;
    }
    await stopDesktopServer();
  }

  /// On desktop, spin up a temporary localhost HTTP server to receive
  /// the auth redirect, since custom URL schemes are unreliable.
  Future<String> _startDesktopRedirectServer() async {
    await stopDesktopServer();
    _desktopServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = _desktopServer!.port;
    return 'http://localhost:$port/auth_callback';
  }

  Future<Map<String, String>> waitForDesktopCallback() async {
    if (_desktopServer == null) {
      throw StateError('Desktop redirect server not running');
    }

    await for (final request in _desktopServer!) {
      if (request.uri.path != '/auth_callback') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        continue;
      }

      final params = request.uri.queryParameters;

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write('''
<!DOCTYPE html>
<html>
<head><title>Lunaris</title></head>
<body style="font-family:system-ui;text-align:center;padding:60px">
<h2>Authentication successful</h2>
<p>You can close this tab and return to Lunaris.</p>
</body>
</html>
''');
      await request.response.close();
      await stopDesktopServer();

      return Map<String, String>.from(params);
    }

    throw StateError('Server closed without receiving auth callback');
  }

  Future<void> stopDesktopServer() async {
    await _desktopServer?.close(force: true);
    _desktopServer = null;
  }

  String _generateNonce() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}

AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _generateKeyPairIsolate(
    void _) {
  return RsaKeyHelper.generateKeyPair();
}
