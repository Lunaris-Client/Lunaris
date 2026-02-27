import 'dart:async';
import 'package:dio/dio.dart';

class MessageBusMessage {
  final String channel;
  final int messageId;
  final dynamic data;

  MessageBusMessage({
    required this.channel,
    required this.messageId,
    required this.data,
  });

  factory MessageBusMessage.fromJson(Map<String, dynamic> json) {
    return MessageBusMessage(
      channel: json['channel'] as String,
      messageId: json['message_id'] as int,
      data: json['data'],
    );
  }
}

typedef MessageBusCallback = void Function(MessageBusMessage message);

class MessageBusClient {
  final Dio _dio;
  final String _serverUrl;
  final String _clientId;
  final String _apiKey;

  final Map<String, int> _channelPositions = {};
  final Map<String, MessageBusCallback> _subscriptions = {};

  bool _polling = false;
  bool _disposed = false;
  Timer? _reconnectTimer;

  static const _pollTimeout = Duration(seconds: 25);
  static const _reconnectDelay = Duration(seconds: 5);

  MessageBusClient({
    required String serverUrl,
    required String clientId,
    required String apiKey,
    Dio? dio,
  }) : _serverUrl = serverUrl,
       _clientId = clientId,
       _apiKey = apiKey,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 30),
               headers: {'Accept': 'application/json'},
             ),
           );

  void subscribe(String channel, int lastMessageId, MessageBusCallback cb) {
    _channelPositions[channel] = lastMessageId;
    _subscriptions[channel] = cb;
  }

  void unsubscribe(String channel) {
    _channelPositions.remove(channel);
    _subscriptions.remove(channel);
  }

  void start() {
    if (_polling || _disposed) return;
    _polling = true;
    _poll();
  }

  void stop() {
    _polling = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void dispose() {
    _disposed = true;
    stop();
    _subscriptions.clear();
    _channelPositions.clear();
  }

  Future<void> _poll() async {
    while (_polling && !_disposed) {
      try {
        final body = <String, dynamic>{};
        for (final entry in _channelPositions.entries) {
          body[entry.key] = entry.value;
        }

        final response = await _dio.post(
          '$_serverUrl/message-bus/$_clientId/poll',
          data: body,
          options: Options(
            headers: {'User-Api-Key': _apiKey},
            receiveTimeout: _pollTimeout + const Duration(seconds: 5),
          ),
        );

        if (!_polling || _disposed) break;

        if (response.data is List) {
          final messages =
              (response.data as List)
                  .map(
                    (m) =>
                        MessageBusMessage.fromJson(m as Map<String, dynamic>),
                  )
                  .toList();

          for (final msg in messages) {
            if (_channelPositions.containsKey(msg.channel)) {
              _channelPositions[msg.channel] = msg.messageId;
            }
            _subscriptions[msg.channel]?.call(msg);
          }
        }
      } catch (e) {
        if (!_polling || _disposed) break;
        if (e is DioException && e.type == DioExceptionType.cancel) break;

        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(_reconnectDelay, () {
          if (_polling && !_disposed) _poll();
        });
        return;
      }
    }
  }
}
