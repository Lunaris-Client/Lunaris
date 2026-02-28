import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/auth/auth_service.dart';
import 'package:lunaris/core/models/server_account.dart';
import 'package:lunaris/core/providers/badge_counts_provider.dart';
import 'package:lunaris/core/providers/category_unread_provider.dart';
import 'package:lunaris/core/providers/notification_provider.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/core/services/message_bus_client.dart';

class MessageBusEvent {
  final String type;
  final dynamic data;

  MessageBusEvent({required this.type, required this.data});
}

class MessageBusManager extends StateNotifier<MessageBusEvent?> {
  final Ref _ref;
  final AuthService _authService;
  MessageBusClient? _client;
  String? _activeServerUrl;

  MessageBusManager(this._ref, this._authService) : super(null);

  Future<void> connect(ServerAccount server) async {
    if (_activeServerUrl == server.serverUrl && _client != null) return;

    disconnect();
    _activeServerUrl = server.serverUrl;

    final apiKey = await _authService.loadApiKey(server.serverUrl);
    if (apiKey == null || server.clientId == null || server.userId == null) {
      return;
    }

    _client = MessageBusClient(
      serverUrl: server.serverUrl,
      clientId: server.clientId!,
      apiKey: apiKey,
    );

    final userId = server.userId!;
    final startPos = server.notificationChannelPosition ?? -1;

    _client!.subscribe('/notification/$userId', startPos, _onNotification);
    _client!.subscribe('/notification-alert/$userId', -1, _onNotificationAlert);
    _client!.subscribe('/chat/notification-alert/$userId', -1, _onChatNotificationAlert);
    _client!.subscribe('/unread/$userId', -1, _onUnread);
    _client!.subscribe('/new', -1, _onNew);
    _client!.subscribe('/latest', -1, _onLatest);

    _client!.start();
  }

  void disconnect() {
    _client?.dispose();
    _client = null;
    _activeServerUrl = null;
  }

  void _onNotification(MessageBusMessage msg) {
    final serverUrl = _activeServerUrl;
    if (serverUrl == null) return;

    _updateChannelPosition(serverUrl, msg.messageId);
    _ref.read(notificationListProvider(serverUrl).notifier).refresh();
    _ref.read(badgeCountsProvider(serverUrl).notifier).fetch();
    state = MessageBusEvent(type: 'notification', data: msg.data);
  }

  void _onNotificationAlert(MessageBusMessage msg) {
    state = MessageBusEvent(type: 'notification_alert', data: msg.data);
  }

  void _onUnread(MessageBusMessage msg) {
    final serverUrl = _activeServerUrl;
    if (serverUrl != null) {
      _ref.read(badgeCountsProvider(serverUrl).notifier).fetch();
      _ref.read(categoryUnreadProvider(serverUrl).notifier).fetch();
    }
    state = MessageBusEvent(type: 'unread', data: msg.data);
  }

  void _onNew(MessageBusMessage msg) {
    final serverUrl = _activeServerUrl;
    if (serverUrl != null) {
      _ref.read(badgeCountsProvider(serverUrl).notifier).fetch();
      _ref.read(categoryUnreadProvider(serverUrl).notifier).fetch();
    }
    state = MessageBusEvent(type: 'new_topic', data: msg.data);
  }

  void _onLatest(MessageBusMessage msg) {
    state = MessageBusEvent(type: 'latest', data: msg.data);
  }

  void _onChatNotificationAlert(MessageBusMessage msg) {
    final data = msg.data is Map<String, dynamic>
        ? Map<String, dynamic>.from(msg.data as Map<String, dynamic>)
        : <String, dynamic>{};
    if (data.containsKey('channel_id') && !data.containsKey('chat_channel_id')) {
      data['chat_channel_id'] = data['channel_id'];
    }
    state = MessageBusEvent(type: 'notification_alert', data: data);
  }

  void subscribeToTopic(int topicId) {
    _client?.subscribe('/topic/$topicId', -1, (msg) {
      state = MessageBusEvent(
        type: 'topic_update',
        data: {'topic_id': topicId, ...msg.data as Map<String, dynamic>},
      );
    });
  }

  void unsubscribeFromTopic(int topicId) {
    _client?.unsubscribe('/topic/$topicId');
  }

  void subscribeToChatChannel(int channelId) {
    _client?.subscribe('/chat/$channelId', -1, (msg) {
      state = MessageBusEvent(
        type: 'chat_channel_update',
        data: {'channel_id': channelId, ...msg.data as Map<String, dynamic>},
      );
    });
  }

  void unsubscribeFromChatChannel(int channelId) {
    _client?.unsubscribe('/chat/$channelId');
  }

  void _updateChannelPosition(String serverUrl, int messageId) {
    try {
      final accounts = _ref.read(serverAccountsProvider);
      final account = accounts.firstWhere((a) => a.serverUrl == serverUrl);
      _ref
          .read(serverAccountsProvider.notifier)
          .update(account.copyWith(notificationChannelPosition: messageId));
    } catch (_) {}
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

final messageBusProvider =
    StateNotifierProvider<MessageBusManager, MessageBusEvent?>((ref) {
      return MessageBusManager(ref, ref.watch(authServiceProvider));
    });
