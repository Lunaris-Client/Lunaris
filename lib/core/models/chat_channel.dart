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
  final List<DmUser> dmUsers;
  final bool isGroupDm;

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
    this.dmUsers = const [],
    this.isGroupDm = false,
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

    final chatable = json['chatable'] as Map<String, dynamic>?;
    final chatableType = json['chatable_type'] as String? ??
        json['channel_type'] as String? ??
        'category';
    List<DmUser> dmUsers = const [];
    bool isGroupDm = false;

    if (chatableType.toLowerCase().contains('direct') && chatable != null) {
      isGroupDm = chatable['group'] as bool? ?? false;
      final usersJson = chatable['users'] as List<dynamic>? ?? [];
      dmUsers = usersJson
          .map((u) => DmUser.fromJson(u as Map<String, dynamic>))
          .toList();
    }

    return ChatChannel(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      channelType: chatableType,
      membershipsCount: json['memberships_count'] as int? ?? 0,
      currentUserMembershipId: membership?['membership_id'] as int?,
      currentUserFollowing: membership?['following'] as bool?,
      status: json['status'] as String? ?? 'open',
      lastMessage: lastMsg,
      unreadCount: membership?['unread_count'] as int?,
      unreadMentions: membership?['unread_mentions'] as int?,
      threadingEnabled: json['threading_enabled'] as bool? ?? false,
      dmUsers: dmUsers,
      isGroupDm: isGroupDm,
    );
  }
}

class DmUser {
  final int id;
  final String username;
  final String? name;
  final String? avatarTemplate;

  const DmUser({
    required this.id,
    required this.username,
    this.name,
    this.avatarTemplate,
  });

  factory DmUser.fromJson(Map<String, dynamic> json) {
    return DmUser(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      name: json['name'] as String?,
      avatarTemplate: json['avatar_template'] as String?,
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
  final String? replyToUsername;
  final String? replyToExcerpt;
  final String? replyToAvatarTemplate;
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
    this.replyToUsername,
    this.replyToExcerpt,
    this.replyToAvatarTemplate,
    this.deleted = false,
    this.reactions = const [],
  });

  ChatMessage copyWith({
    int? id,
    String? message,
    String? cooked,
    String? excerpt,
    int? userId,
    String? username,
    String? avatarTemplate,
    DateTime? createdAt,
    int? threadId,
    int? inReplyToId,
    String? replyToUsername,
    String? replyToExcerpt,
    String? replyToAvatarTemplate,
    bool? deleted,
    List<ChatMessageReaction>? reactions,
    bool clearCooked = false,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      message: message ?? this.message,
      cooked: clearCooked ? null : (cooked ?? this.cooked),
      excerpt: excerpt ?? this.excerpt,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarTemplate: avatarTemplate ?? this.avatarTemplate,
      createdAt: createdAt ?? this.createdAt,
      threadId: threadId ?? this.threadId,
      inReplyToId: inReplyToId ?? this.inReplyToId,
      replyToUsername: replyToUsername ?? this.replyToUsername,
      replyToExcerpt: replyToExcerpt ?? this.replyToExcerpt,
      replyToAvatarTemplate: replyToAvatarTemplate ?? this.replyToAvatarTemplate,
      deleted: deleted ?? this.deleted,
      reactions: reactions ?? this.reactions,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final reactionsJson = json['reactions'] as List<dynamic>? ?? [];
    final inReplyTo = json['in_reply_to'] as Map<String, dynamic>?;
    final replyUser = inReplyTo?['user'] as Map<String, dynamic>?;

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
      replyToUsername: replyUser?['username'] as String?,
      replyToExcerpt: inReplyTo?['excerpt'] as String?,
      replyToAvatarTemplate: replyUser?['avatar_template'] as String?,
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

