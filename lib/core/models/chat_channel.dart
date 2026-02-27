class ChatChannel {
  final int id;
  final String title;
  final String? description;
  final String channelType;
  final int membershipsCount;
  final int? currentUserMembershipId;
  final bool? currentUserFollowing;
  final String status;
  final ChatMessage? lastMessage;
  final int? unreadCount;
  final int? unreadMentions;
  final bool threadingEnabled;

  const ChatChannel({
    required this.id,
    required this.title,
    this.description,
    required this.channelType,
    this.membershipsCount = 0,
    this.currentUserMembershipId,
    this.currentUserFollowing,
    this.status = 'open',
    this.lastMessage,
    this.unreadCount,
    this.unreadMentions,
    this.threadingEnabled = false,
  });

  bool get isDirectMessage => channelType.toLowerCase().contains('direct');
  bool get isCategory => !isDirectMessage;

  factory ChatChannel.fromJson(Map<String, dynamic> json) {
    final membership =
        json['current_user_membership'] as Map<String, dynamic>?;

    ChatMessage? lastMsg;
    if (json['last_message'] is Map<String, dynamic>) {
      lastMsg = ChatMessage.fromJson(
        json['last_message'] as Map<String, dynamic>,
      );
    }

    return ChatChannel(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      channelType: json['chatable_type'] as String? ??
          json['channel_type'] as String? ??
          'category',
      membershipsCount: json['memberships_count'] as int? ?? 0,
      currentUserMembershipId: membership?['membership_id'] as int?,
      currentUserFollowing: membership?['following'] as bool?,
      status: json['status'] as String? ?? 'open',
      lastMessage: lastMsg,
      unreadCount: membership?['unread_count'] as int?,
      unreadMentions: membership?['unread_mentions'] as int?,
      threadingEnabled: json['threading_enabled'] as bool? ?? false,
    );
  }
}

class ChatMessage {
  final int id;
  final String message;
  final String? cooked;
  final String? excerpt;
  final int? userId;
  final String? username;
  final String? avatarTemplate;
  final DateTime createdAt;
  final int? threadId;
  final int? inReplyToId;
  final bool deleted;
  final List<ChatMessageReaction> reactions;

  const ChatMessage({
    required this.id,
    required this.message,
    this.cooked,
    this.excerpt,
    this.userId,
    this.username,
    this.avatarTemplate,
    required this.createdAt,
    this.threadId,
    this.inReplyToId,
    this.deleted = false,
    this.reactions = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final reactionsJson = json['reactions'] as List<dynamic>? ?? [];

    return ChatMessage(
      id: json['id'] as int,
      message: json['message'] as String? ?? '',
      cooked: json['cooked'] as String?,
      excerpt: json['excerpt'] as String?,
      userId: user?['id'] as int? ?? json['user_id'] as int?,
      username: user?['username'] as String? ?? json['username'] as String?,
      avatarTemplate: user?['avatar_template'] as String?,
      createdAt: DateTime.tryParse(
            json['created_at'] as String? ?? '',
          ) ??
          DateTime.now(),
      threadId: json['thread_id'] as int?,
      inReplyToId: json['in_reply_to_id'] as int?,
      deleted: json['deleted'] as bool? ?? false,
      reactions: reactionsJson
          .map((r) =>
              ChatMessageReaction.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ChatMessageReaction {
  final String emoji;
  final int count;
  final bool reacted;
  final List<ReactionUser> users;

  const ChatMessageReaction({
    required this.emoji,
    required this.count,
    this.reacted = false,
    this.users = const [],
  });

  factory ChatMessageReaction.fromJson(Map<String, dynamic> json) {
    final usersJson = json['users'] as List<dynamic>? ?? [];
    return ChatMessageReaction(
      emoji: json['emoji'] as String? ?? '',
      count: json['count'] as int? ?? 0,
      reacted: json['reacted'] as bool? ?? false,
      users: usersJson
          .map((u) => ReactionUser.fromJson(u as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReactionUser {
  final int id;
  final String username;
  final String? avatarTemplate;

  const ReactionUser({
    required this.id,
    required this.username,
    this.avatarTemplate,
  });

  factory ReactionUser.fromJson(Map<String, dynamic> json) {
    return ReactionUser(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      avatarTemplate: json['avatar_template'] as String?,
    );
  }
}

