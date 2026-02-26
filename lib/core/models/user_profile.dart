class UserProfile {
  final int id;
  final String username;
  final String? name;
  final String? avatarTemplate;
  final String? title;
  final String? bioRaw;
  final String? bioCooked;
  final String? bioExcerpt;
  final String? websiteName;
  final String? location;
  final int trustLevel;
  final bool admin;
  final bool moderator;
  final DateTime createdAt;
  final DateTime? lastPostedAt;
  final DateTime? lastSeenAt;
  final int? badgeCount;
  final String? primaryGroupName;
  final String? flairName;
  final String? flairUrl;
  final String? flairBgColor;
  final String? flairColor;
  final bool canSendPrivateMessages;
  final bool canSendPrivateMessageToUser;

  final int daysVisited;
  final int postsReadCount;
  final int topicCount;
  final int postCount;
  final int likesGiven;
  final int likesReceived;
  final int topicsEntered;

  const UserProfile({
    required this.id,
    required this.username,
    this.name,
    this.avatarTemplate,
    this.title,
    this.bioRaw,
    this.bioCooked,
    this.bioExcerpt,
    this.websiteName,
    this.location,
    this.trustLevel = 0,
    this.admin = false,
    this.moderator = false,
    required this.createdAt,
    this.lastPostedAt,
    this.lastSeenAt,
    this.badgeCount,
    this.primaryGroupName,
    this.flairName,
    this.flairUrl,
    this.flairBgColor,
    this.flairColor,
    this.canSendPrivateMessages = false,
    this.canSendPrivateMessageToUser = false,
    this.daysVisited = 0,
    this.postsReadCount = 0,
    this.topicCount = 0,
    this.postCount = 0,
    this.likesGiven = 0,
    this.likesReceived = 0,
    this.topicsEntered = 0,
  });

  factory UserProfile.fromApiJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? json;
    return UserProfile(
      id: user['id'] as int,
      username: user['username'] as String? ?? '',
      name: user['name'] as String?,
      avatarTemplate: user['avatar_template'] as String?,
      title: user['title'] as String?,
      bioRaw: user['bio_raw'] as String?,
      bioCooked: user['bio_cooked'] as String?,
      bioExcerpt: user['bio_excerpt'] as String?,
      websiteName: user['website_name'] as String?,
      location: user['location'] as String?,
      trustLevel: user['trust_level'] as int? ?? 0,
      admin: user['admin'] as bool? ?? false,
      moderator: user['moderator'] as bool? ?? false,
      createdAt: DateTime.parse(
        user['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      lastPostedAt:
          user['last_posted_at'] != null
              ? DateTime.tryParse(user['last_posted_at'] as String)
              : null,
      lastSeenAt:
          user['last_seen_at'] != null
              ? DateTime.tryParse(user['last_seen_at'] as String)
              : null,
      badgeCount: user['badge_count'] as int?,
      primaryGroupName: user['primary_group_name'] as String?,
      flairName: user['flair_name'] as String?,
      flairUrl: user['flair_url'] as String?,
      flairBgColor: user['flair_bg_color'] as String?,
      flairColor: user['flair_color'] as String?,
      canSendPrivateMessages:
          user['can_send_private_messages'] as bool? ?? false,
      canSendPrivateMessageToUser:
          user['can_send_private_message_to_user'] as bool? ?? false,
    );
  }

  UserProfile withSummary(Map<String, dynamic> summaryJson) {
    final userSummary =
        summaryJson['user_summary'] as Map<String, dynamic>? ?? {};
    return UserProfile(
      id: id,
      username: username,
      name: name,
      avatarTemplate: avatarTemplate,
      title: title,
      bioRaw: bioRaw,
      bioCooked: bioCooked,
      bioExcerpt: bioExcerpt,
      websiteName: websiteName,
      location: location,
      trustLevel: trustLevel,
      admin: admin,
      moderator: moderator,
      createdAt: createdAt,
      lastPostedAt: lastPostedAt,
      lastSeenAt: lastSeenAt,
      badgeCount: badgeCount,
      primaryGroupName: primaryGroupName,
      flairName: flairName,
      flairUrl: flairUrl,
      flairBgColor: flairBgColor,
      flairColor: flairColor,
      canSendPrivateMessages: canSendPrivateMessages,
      canSendPrivateMessageToUser: canSendPrivateMessageToUser,
      daysVisited: userSummary['days_visited'] as int? ?? daysVisited,
      postsReadCount:
          userSummary['posts_read_count'] as int? ?? postsReadCount,
      topicCount: userSummary['topic_count'] as int? ?? topicCount,
      postCount: userSummary['post_count'] as int? ?? postCount,
      likesGiven: userSummary['likes_given'] as int? ?? likesGiven,
      likesReceived: userSummary['likes_received'] as int? ?? likesReceived,
      topicsEntered: userSummary['topics_entered'] as int? ?? topicsEntered,
    );
  }
}

class UserBadge {
  final int id;
  final String name;
  final String? description;
  final int badgeTypeId;
  final String? icon;
  final String? imageUrl;
  final int grantCount;

  const UserBadge({
    required this.id,
    required this.name,
    this.description,
    this.badgeTypeId = 3,
    this.icon,
    this.imageUrl,
    this.grantCount = 1,
  });

  String get badgeTypeName => switch (badgeTypeId) {
    1 => 'Gold',
    2 => 'Silver',
    _ => 'Bronze',
  };

  factory UserBadge.fromApiJson(Map<String, dynamic> json) {
    return UserBadge(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      badgeTypeId: json['badge_type_id'] as int? ?? 3,
      icon: json['icon'] as String?,
      imageUrl: json['image_url'] as String?,
      grantCount: json['grant_count'] as int? ?? 1,
    );
  }
}

class UserAction {
  final int actionType;
  final int? topicId;
  final int? postId;
  final int? postNumber;
  final String? title;
  final String? excerpt;
  final String? username;
  final String? avatarTemplate;
  final String? actingUsername;
  final String? actingAvatarTemplate;
  final String? slug;
  final int? categoryId;
  final DateTime? createdAt;

  const UserAction({
    required this.actionType,
    this.topicId,
    this.postId,
    this.postNumber,
    this.title,
    this.excerpt,
    this.username,
    this.avatarTemplate,
    this.actingUsername,
    this.actingAvatarTemplate,
    this.slug,
    this.categoryId,
    this.createdAt,
  });

  String get actionLabel => switch (actionType) {
    1 => 'liked',
    2 => 'was liked',
    4 => 'created topic',
    5 => 'replied',
    6 => 'replied',
    7 => 'mentioned',
    9 => 'quoted',
    11 => 'edited',
    12 => 'bookmarked',
    _ => 'activity',
  };

  factory UserAction.fromApiJson(Map<String, dynamic> json) {
    return UserAction(
      actionType: json['action_type'] as int,
      topicId: json['topic_id'] as int?,
      postId: json['post_id'] as int?,
      postNumber: json['post_number'] as int?,
      title: json['title'] as String?,
      excerpt: json['excerpt'] as String?,
      username: json['username'] as String?,
      avatarTemplate: json['avatar_template'] as String?,
      actingUsername: json['acting_username'] as String?,
      actingAvatarTemplate: json['acting_avatar_template'] as String?,
      slug: json['slug'] as String?,
      categoryId: json['category_id'] as int?,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'] as String)
              : null,
    );
  }
}
