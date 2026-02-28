import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/api/discourse_api_client.dart';
import 'package:lunaris/core/auth/auth_service.dart';
import 'package:lunaris/core/models/chat_channel.dart';
import 'package:lunaris/core/providers/providers.dart';

class ChatChannelListState {
  final List<ChatChannel> channels;
  final bool isLoading;
  final Object? error;

  const ChatChannelListState({
    this.channels = const [],
    this.isLoading = true,
    this.error,
  });

  ChatChannelListState copyWith({
    List<ChatChannel>? channels,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) {
    return ChatChannelListState(
      channels: channels ?? this.channels,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  List<ChatChannel> get publicChannels =>
      channels.where((c) => !c.isDirectMessage).toList();

  List<ChatChannel> get directMessages =>
      channels.where((c) => c.isDirectMessage).toList();

  int get totalUnreadCount =>
      channels.fold(0, (sum, c) => sum + (c.unreadCount ?? 0));
}

final chatChannelListProvider = StateNotifierProvider.family<
    ChatChannelListNotifier, ChatChannelListState, String>(
  (ref, serverUrl) => ChatChannelListNotifier(
    ref.watch(discourseApiClientProvider),
    ref.watch(authServiceProvider),
    serverUrl,
  ),
);

class ChatChannelListNotifier extends StateNotifier<ChatChannelListState> {
  final DiscourseApiClient _apiClient;
  final AuthService _authService;
  final String _serverUrl;
  DateTime? _lastFetchTime;
  static const _fetchCooldown = Duration(seconds: 5);

  ChatChannelListNotifier(this._apiClient, this._authService, this._serverUrl)
      : super(const ChatChannelListState()) {
    fetch(force: true);
  }

  Future<void> fetch({bool force = false}) async {
    if (!force && _lastFetchTime != null) {
      final elapsed = DateTime.now().difference(_lastFetchTime!);
      if (elapsed < _fetchCooldown) {
        debugPrint('[ChatChannels] fetch: skipped (cooldown ${elapsed.inMilliseconds}ms < ${_fetchCooldown.inMilliseconds}ms)');
        return;
      }
    }
    try {
      state = state.copyWith(isLoading: true, clearError: true);
      debugPrint('[ChatChannels] fetch: loading apiKey...');
      final apiKey = await _authService.loadApiKey(_serverUrl);
      if (apiKey == null) {
        debugPrint('[ChatChannels] fetch: apiKey is null, aborting');
        if (mounted) state = state.copyWith(isLoading: false);
        return;
      }

      debugPrint('[ChatChannels] fetch: calling API...');
      final sw = Stopwatch()..start();
      final data = await _apiClient.fetchChatChannels(_serverUrl, apiKey);
      sw.stop();
      debugPrint('[ChatChannels] fetch: API responded in ${sw.elapsedMilliseconds}ms, keys=${data.keys.toList()}');
      final publicJson =
          data['public_channels'] as List<dynamic>? ?? [];
      final dmJson =
          data['direct_message_channels'] as List<dynamic>? ?? [];

      final tracking = data['tracking'] as Map<String, dynamic>? ?? {};
      final channelTracking =
          tracking['channel_tracking'] as Map<String, dynamic>? ?? {};

      var channels = [
        ...publicJson
            .map((c) => ChatChannel.fromJson(c as Map<String, dynamic>)),
        ...dmJson
            .map((c) => ChatChannel.fromJson(c as Map<String, dynamic>)),
      ];

      channels = channels.map((channel) {
        final info =
            channelTracking[channel.id.toString()] as Map<String, dynamic>?;
        if (info == null) return channel;
        return channel.copyWith(
          unreadCount: info['unread_count'] as int? ?? 0,
          unreadMentions: info['mention_count'] as int? ?? 0,
        );
      }).toList();

      debugPrint('[ChatChannels] fetch: parsed ${channels.length} channels (${publicJson.length} public + ${dmJson.length} dm)');
      if (!mounted) return;
      _lastFetchTime = DateTime.now();
      state = state.copyWith(channels: channels, isLoading: false);
    } catch (e) {
      debugPrint('[ChatChannels] fetch: ERROR $e');
      if (!mounted) return;
      state = state.copyWith(error: e, isLoading: false);
    }
  }

  void markChannelAsRead(int channelId) {
    if (!mounted) return;
    state = state.copyWith(
      channels: state.channels.map((c) {
        if (c.id == channelId) {
          return c.copyWith(unreadCount: 0, unreadMentions: 0);
        }
        return c;
      }).toList(),
    );
  }

  Future<void> refresh({bool force = false}) async => fetch(force: force);
}

class ChatMessagesState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;

  const ChatMessagesState({
    this.messages = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  ChatMessagesState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return ChatMessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ChatMessagesParams {
  final String serverUrl;
  final int channelId;

  const ChatMessagesParams({
    required this.serverUrl,
    required this.channelId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessagesParams &&
          serverUrl == other.serverUrl &&
          channelId == other.channelId;

  @override
  int get hashCode => Object.hash(serverUrl, channelId);
}

final chatMessagesProvider = StateNotifierProvider.family<
    ChatMessagesNotifier, ChatMessagesState, ChatMessagesParams>(
  (ref, params) => ChatMessagesNotifier(
    ref.watch(discourseApiClientProvider),
    ref.watch(authServiceProvider),
    params,
  ),
);

class ChatMessagesNotifier extends StateNotifier<ChatMessagesState> {
  final DiscourseApiClient _apiClient;
  final AuthService _authService;
  final ChatMessagesParams _params;

  ChatMessagesNotifier(this._apiClient, this._authService, this._params)
      : super(const ChatMessagesState());

  Future<void> fetch() async {
    try {
      debugPrint('[ChatMessages] fetch: ch=${_params.channelId} loading apiKey...');
      state = state.copyWith(isLoading: true, clearError: true);
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) {
        debugPrint('[ChatMessages] fetch: ch=${_params.channelId} apiKey is null, aborting');
        if (mounted) state = state.copyWith(isLoading: false);
        return;
      }

      debugPrint('[ChatMessages] fetch: ch=${_params.channelId} calling API...');
      final sw = Stopwatch()..start();
      final data = await _apiClient.fetchChatMessages(
        _params.serverUrl,
        apiKey,
        _params.channelId,
        pageSize: 50,
      );
      sw.stop();
      debugPrint('[ChatMessages] fetch: ch=${_params.channelId} API responded in ${sw.elapsedMilliseconds}ms, dataKeys=${data.keys.toList()}');

      final messagesJson = data['messages'] as List<dynamic>? ?? [];
      debugPrint('[ChatMessages] fetch: ch=${_params.channelId} parsed ${messagesJson.length} messages');
      final messages = messagesJson
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      if (!mounted) return;
      state = state.copyWith(
        messages: messages,
        isLoading: false,
        hasMore: messagesJson.length >= 50,
      );

    } catch (e) {
      debugPrint('[ChatMessages] fetch: ch=${_params.channelId} ERROR ${e.runtimeType}: $e');
      if (!mounted) return;
      // If we already have cached messages, keep showing them instead of error
      if (state.messages.isNotEmpty) {
        state = state.copyWith(isLoading: false);
      } else {
        state = state.copyWith(error: e, isLoading: false);
      }
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.messages.isEmpty) return;
    try {
      state = state.copyWith(isLoadingMore: true);
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) return;

      final data = await _apiClient.fetchChatMessages(
        _params.serverUrl,
        apiKey,
        _params.channelId,
        pageSize: 50,
        beforeMessageId: state.messages.first.id,
      );

      final messagesJson = data['messages'] as List<dynamic>? ?? [];
      final older = messagesJson
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      if (!mounted) return;
      state = state.copyWith(
        messages: [...older, ...state.messages],
        isLoadingMore: false,
        hasMore: messagesJson.length >= 50,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> sendMessage(
    String text, {
    int? inReplyToId,
    String? username,
    String? avatarTemplate,
    int? userId,
    List<int>? uploadIds,
  }) async {
    try {
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) return;

      final data = await _apiClient.sendChatMessage(
        _params.serverUrl,
        apiKey,
        _params.channelId,
        message: text,
        inReplyToId: inReplyToId,
        uploadIds: uploadIds,
      );

      if (mounted) {
        final messageId = data['message_id'] as int?;
        if (messageId != null) {
          final newMsg = ChatMessage(
            id: messageId,
            message: text,
            username: username,
            avatarTemplate: avatarTemplate,
            userId: userId,
            createdAt: DateTime.now(),
            inReplyToId: inReplyToId,
          );
          state = state.copyWith(messages: [...state.messages, newMsg]);
        }
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e);
    }
  }

  void addMessage(ChatMessage message) {
    if (!mounted) return;
    final idx = state.messages.indexWhere((m) => m.id == message.id);
    if (idx >= 0) {
      final existing = state.messages[idx];
      if (existing.cooked == null && message.cooked != null) {
        final updated = List<ChatMessage>.from(state.messages);
        updated[idx] = message;
        state = state.copyWith(messages: updated);
      }
      return;
    }
    state = state.copyWith(messages: [...state.messages, message]);
  }

  Future<void> editMessage(int messageId, String newText) async {
    try {
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) return;

      await _apiClient.editChatMessage(
        _params.serverUrl,
        apiKey,
        _params.channelId,
        messageId,
        message: newText,
      );

      if (!mounted) return;
      state = state.copyWith(
        messages: state.messages.map((m) {
          if (m.id == messageId) {
            return m.copyWith(message: newText, clearCooked: true);
          }
          return m;
        }).toList(),
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e);
    }
  }

  Future<void> deleteMessage(int messageId) async {
    try {
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) return;

      await _apiClient.deleteChatMessage(
        _params.serverUrl,
        apiKey,
        _params.channelId,
        messageId,
      );

      if (!mounted) return;
      state = state.copyWith(
        messages: state.messages.map((m) {
          if (m.id == messageId) {
            return m.copyWith(deleted: true);
          }
          return m;
        }).toList(),
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e);
    }
  }

  Future<void> refresh() async => fetch();

  void handleChatChannelMessage(Map<String, dynamic> data) {
    if (!mounted) return;
    final type = data['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'sent':
        _handleSent(data);
      case 'edit':
      case 'processed':
        _handleEdit(data);
      case 'delete':
        _handleDelete(data);
      case 'restore':
        _handleRestore(data);
      case 'reaction':
        _handleReaction(data);
    }
  }

  void _handleSent(Map<String, dynamic> data) {
    final msgData = data['chat_message'] as Map<String, dynamic>?;
    if (msgData == null) return;
    final message = ChatMessage.fromJson(msgData);
    addMessage(message);
  }

  void _handleEdit(Map<String, dynamic> data) {
    final msgData = data['chat_message'] as Map<String, dynamic>?;
    if (msgData == null) return;
    final editedId = msgData['id'] as int?;
    if (editedId == null) return;

    state = state.copyWith(
      messages: state.messages.map((m) {
        if (m.id == editedId) {
          return m.copyWith(
            message: msgData['message'] as String? ?? m.message,
            cooked: msgData['cooked'] as String? ?? m.cooked,
            excerpt: msgData['excerpt'] as String? ?? m.excerpt,
          );
        }
        return m;
      }).toList(),
    );
  }

  void _handleDelete(Map<String, dynamic> data) {
    final deletedId = data['deleted_id'] as int?;
    if (deletedId == null) return;

    state = state.copyWith(
      messages: state.messages.map((m) {
        if (m.id == deletedId) return m.copyWith(deleted: true);
        return m;
      }).toList(),
    );
  }

  void _handleRestore(Map<String, dynamic> data) {
    final msgData = data['chat_message'] as Map<String, dynamic>?;
    if (msgData == null) return;
    final restoredMsg = ChatMessage.fromJson(msgData);

    final exists = state.messages.any((m) => m.id == restoredMsg.id);
    if (exists) {
      state = state.copyWith(
        messages: state.messages.map((m) {
          if (m.id == restoredMsg.id) return restoredMsg;
          return m;
        }).toList(),
      );
    } else {
      final msgs = [...state.messages, restoredMsg];
      msgs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = state.copyWith(messages: msgs);
    }
  }

  void _handleReaction(Map<String, dynamic> data) {
    final messageId = data['chat_message_id'] as int?;
    final emoji = data['emoji'] as String?;
    final action = data['action'] as String?;
    final userData = data['user'] as Map<String, dynamic>?;
    if (messageId == null || emoji == null || action == null) return;

    state = state.copyWith(
      messages: state.messages.map((m) {
        if (m.id != messageId) return m;

        final reactions = List<ChatMessageReaction>.from(m.reactions);
        final existingIdx = reactions.indexWhere((r) => r.emoji == emoji);

        if (action == 'add') {
          final reactionUser =
              userData != null ? ReactionUser.fromJson(userData) : null;
          if (existingIdx >= 0) {
            final existing = reactions[existingIdx];
            reactions[existingIdx] = ChatMessageReaction(
              emoji: existing.emoji,
              count: existing.count + 1,
              reacted: existing.reacted,
              users: reactionUser != null
                  ? [...existing.users, reactionUser]
                  : existing.users,
            );
          } else {
            reactions.add(ChatMessageReaction(
              emoji: emoji,
              count: 1,
              reacted: false,
              users: reactionUser != null ? [reactionUser] : [],
            ));
          }
        } else if (action == 'remove' && existingIdx >= 0) {
          final existing = reactions[existingIdx];
          if (existing.count <= 1) {
            reactions.removeAt(existingIdx);
          } else {
            final userId = userData?['id'] as int?;
            reactions[existingIdx] = ChatMessageReaction(
              emoji: existing.emoji,
              count: existing.count - 1,
              reacted: existing.reacted,
              users: userId != null
                  ? existing.users.where((u) => u.id != userId).toList()
                  : existing.users,
            );
          }
        }

        return m.copyWith(reactions: reactions);
      }).toList(),
    );
  }

  Future<void> markAllRead() async {
    if (state.messages.isEmpty) return;
    final apiKey = await _authService.loadApiKey(_params.serverUrl);
    if (apiKey == null) return;
    await _markRead(apiKey, state.messages.last.id);
  }

  Future<void> _markRead(String apiKey, int messageId) async {
    try {
      await _apiClient.markChatChannelRead(
        _params.serverUrl,
        apiKey,
        _params.channelId,
        messageId: messageId,
      );
    } catch (_) {}
  }
}

class ThreadMessagesParams {
  final String serverUrl;
  final int channelId;
  final int threadId;

  const ThreadMessagesParams({
    required this.serverUrl,
    required this.channelId,
    required this.threadId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThreadMessagesParams &&
          serverUrl == other.serverUrl &&
          channelId == other.channelId &&
          threadId == other.threadId;

  @override
  int get hashCode => Object.hash(serverUrl, channelId, threadId);
}

final threadMessagesProvider = StateNotifierProvider.family<
    ThreadMessagesNotifier, ChatMessagesState, ThreadMessagesParams>(
  (ref, params) => ThreadMessagesNotifier(
    ref.watch(discourseApiClientProvider),
    ref.watch(authServiceProvider),
    params,
  ),
);

class ThreadMessagesNotifier extends StateNotifier<ChatMessagesState> {
  final DiscourseApiClient _apiClient;
  final AuthService _authService;
  final ThreadMessagesParams _params;

  ThreadMessagesNotifier(this._apiClient, this._authService, this._params)
      : super(const ChatMessagesState()) {
    fetch();
  }

  Future<void> fetch() async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) return;

      final data = await _apiClient.fetchChatThreadMessages(
        _params.serverUrl,
        apiKey,
        _params.channelId,
        _params.threadId,
        pageSize: 50,
      );

      final messagesJson = data['messages'] as List<dynamic>? ?? [];
      final messages = messagesJson
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      if (!mounted) return;
      state = state.copyWith(
        messages: messages,
        isLoading: false,
        hasMore: messagesJson.length >= 50,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e, isLoading: false);
    }
  }

  Future<void> sendMessage(
    String text, {
    String? username,
    String? avatarTemplate,
    int? userId,
  }) async {
    try {
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) return;

      final data = await _apiClient.sendChatThreadMessage(
        _params.serverUrl,
        apiKey,
        _params.channelId,
        _params.threadId,
        message: text,
      );

      if (mounted) {
        final messageId = data['message_id'] as int?;
        if (messageId != null) {
          final newMsg = ChatMessage(
            id: messageId,
            message: text,
            username: username,
            avatarTemplate: avatarTemplate,
            userId: userId,
            createdAt: DateTime.now(),
          );
          state = state.copyWith(messages: [...state.messages, newMsg]);
        }
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e);
    }
  }

  void addMessage(ChatMessage message) {
    if (!mounted) return;
    final idx = state.messages.indexWhere((m) => m.id == message.id);
    if (idx >= 0) {
      final existing = state.messages[idx];
      if (existing.cooked == null && message.cooked != null) {
        final updated = List<ChatMessage>.from(state.messages);
        updated[idx] = message;
        state = state.copyWith(messages: updated);
      }
      return;
    }
    state = state.copyWith(messages: [...state.messages, message]);
  }

  Future<void> refresh() async => fetch();
}
