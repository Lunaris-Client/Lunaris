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
  final int? profileViews;

  // Admin-specific fields (only populated when viewer is staff)
  final String? email;
  final String? ipAddress;
  final String? registrationIpAddress;
  final DateTime? suspendedTill;
  final String? suspendReason;
  final DateTime? silencedTill;
  final String? silenceReason;
  final bool? active;
  final bool? staged;
  final bool canGrantAdmin;
  final bool canRevokeAdmin;
  final bool canGrantModeration;
  final bool canRevokeModeration;
  final bool canImpersonate;
  final bool canDeleteAllPosts;
  final bool canBeDeleted;
  final bool canBeAnonymized;
  final bool canBeMerged;
  final bool canActivate;
  final bool canDeactivate;
  final bool canSendActivationEmail;
  final bool canChangeTrustLevel;
  final bool canDisableSecondFactor;
  final bool secondFactorEnabled;
  final int? penaltySilenced;
  final int? penaltySuspended;
  final int warningsReceivedCount;
  final int flagsReceivedCount;
  final int flagsGivenCount;
  final int privateTopicsCount;

  final int daysVisited;
  final int postsReadCount;
  final int topicCount;
  final int postCount;
  final int likesGiven;
  final int likesReceived;
  final int topicsEntered;
  final int timeRead;
  final int recentTimeRead;
  final int topicCreatedCount;

  final List<SummaryTopic> topTopics;
  final List<SummaryReply> topReplies;
  final List<SummaryLink> topLinks;
  final List<SummaryUser> mostLikedByUsers;
  final List<SummaryUser> mostLikedUsers;
  final List<SummaryUser> mostRepliedToUsers;

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
    this.profileViews,
    this.email,
    this.ipAddress,
    this.registrationIpAddress,
    this.suspendedTill,
    this.suspendReason,
    this.silencedTill,
    this.silenceReason,
    this.active,
    this.staged,
    this.canGrantAdmin = false,
    this.canRevokeAdmin = false,
    this.canGrantModeration = false,
    this.canRevokeModeration = false,
    this.canImpersonate = false,
    this.canDeleteAllPosts = false,
    this.canBeDeleted = false,
    this.canBeAnonymized = false,
    this.canBeMerged = false,
    this.canActivate = false,
    this.canDeactivate = false,
    this.canSendActivationEmail = false,
    this.canChangeTrustLevel = false,
    this.canDisableSecondFactor = false,
    this.secondFactorEnabled = false,
    this.penaltySilenced,
    this.penaltySuspended,
    this.warningsReceivedCount = 0,
    this.flagsReceivedCount = 0,
    this.flagsGivenCount = 0,
    this.privateTopicsCount = 0,
    this.daysVisited = 0,
    this.postsReadCount = 0,
    this.topicCount = 0,
    this.postCount = 0,
    this.likesGiven = 0,
    this.likesReceived = 0,
    this.topicsEntered = 0,
    this.timeRead = 0,
    this.recentTimeRead = 0,
    this.topicCreatedCount = 0,
    this.topTopics = const [],
    this.topReplies = const [],
    this.topLinks = const [],
    this.mostLikedByUsers = const [],
    this.mostLikedUsers = const [],
    this.mostRepliedToUsers = const [],
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
      profileViews: user['profile_view_count'] as int?,
    );
  }

  UserProfile withSummary(Map<String, dynamic> summaryJson) {
    final userSummary =
        summaryJson['user_summary'] as Map<String, dynamic>? ?? {};

    final topicsJson = userSummary['topics'] as List<dynamic>? ?? [];
    final repliesJson = userSummary['replies'] as List<dynamic>? ?? [];
    final linksJson = userSummary['links'] as List<dynamic>? ?? [];
    final likedByJson = userSummary['most_liked_by_users'] as List<dynamic>? ?? [];
    final likedJson = userSummary['most_liked_users'] as List<dynamic>? ?? [];
    final repliedToJson = userSummary['most_replied_to_users'] as List<dynamic>? ?? [];

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
      profileViews: profileViews,
      email: email,
      ipAddress: ipAddress,
      registrationIpAddress: registrationIpAddress,
      suspendedTill: suspendedTill,
      suspendReason: suspendReason,
      silencedTill: silencedTill,
      silenceReason: silenceReason,
      active: active,
      staged: staged,
      canGrantAdmin: canGrantAdmin,
      canRevokeAdmin: canRevokeAdmin,
      canGrantModeration: canGrantModeration,
      canRevokeModeration: canRevokeModeration,
      canImpersonate: canImpersonate,
      canDeleteAllPosts: canDeleteAllPosts,
      canBeDeleted: canBeDeleted,
      canBeAnonymized: canBeAnonymized,
      canBeMerged: canBeMerged,
      canActivate: canActivate,
      canDeactivate: canDeactivate,
      canSendActivationEmail: canSendActivationEmail,
      canChangeTrustLevel: canChangeTrustLevel,
      canDisableSecondFactor: canDisableSecondFactor,
      secondFactorEnabled: secondFactorEnabled,
      penaltySilenced: penaltySilenced,
      penaltySuspended: penaltySuspended,
      warningsReceivedCount: warningsReceivedCount,
      flagsReceivedCount: flagsReceivedCount,
      flagsGivenCount: flagsGivenCount,
      privateTopicsCount: privateTopicsCount,
      daysVisited: userSummary['days_visited'] as int? ?? daysVisited,
      postsReadCount:
          userSummary['posts_read_count'] as int? ?? postsReadCount,
      topicCount: userSummary['topic_count'] as int? ?? topicCount,
      postCount: userSummary['post_count'] as int? ?? postCount,
      likesGiven: userSummary['likes_given'] as int? ?? likesGiven,
      likesReceived: userSummary['likes_received'] as int? ?? likesReceived,
      topicsEntered: userSummary['topics_entered'] as int? ?? topicsEntered,
      timeRead: userSummary['time_read'] as int? ?? timeRead,
      recentTimeRead: userSummary['recent_time_read'] as int? ?? recentTimeRead,
      topicCreatedCount: userSummary['topic_count'] as int? ?? topicCreatedCount,
      topTopics: topicsJson
          .map((t) => SummaryTopic.fromJson(t as Map<String, dynamic>))
          .toList(),
      topReplies: repliesJson
          .map((r) => SummaryReply.fromJson(r as Map<String, dynamic>))
          .toList(),
      topLinks: linksJson
          .map((l) => SummaryLink.fromJson(l as Map<String, dynamic>))
          .toList(),
      mostLikedByUsers: likedByJson
          .map((u) => SummaryUser.fromJson(u as Map<String, dynamic>))
          .toList(),
      mostLikedUsers: likedJson
          .map((u) => SummaryUser.fromJson(u as Map<String, dynamic>))
          .toList(),
      mostRepliedToUsers: repliedToJson
          .map((u) => SummaryUser.fromJson(u as Map<String, dynamic>))
          .toList(),
    );
  }

  UserProfile withAdminDetails(Map<String, dynamic> json) {
    final penalties = json['penalty_counts'] as Map<String, dynamic>? ?? {};
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
      trustLevel: json['trust_level'] as int? ?? trustLevel,
      admin: json['admin'] as bool? ?? admin,
      moderator: json['moderator'] as bool? ?? moderator,
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
      profileViews: profileViews,
      email: json['email'] as String?,
      ipAddress: json['ip_address'] as String?,
      registrationIpAddress: json['registration_ip_address'] as String?,
      suspendedTill: json['suspended_till'] != null
          ? DateTime.tryParse(json['suspended_till'] as String)
          : null,
      suspendReason: json['full_suspend_reason'] as String? ??
          json['suspend_reason'] as String?,
      silencedTill: json['silenced_till'] != null
          ? DateTime.tryParse(json['silenced_till'] as String)
          : null,
      silenceReason: json['silence_reason'] as String?,
      active: json['active'] as bool?,
      staged: json['staged'] as bool?,
      canGrantAdmin: json['can_grant_admin'] as bool? ?? false,
      canRevokeAdmin: json['can_revoke_admin'] as bool? ?? false,
      canGrantModeration: json['can_grant_moderation'] as bool? ?? false,
      canRevokeModeration: json['can_revoke_moderation'] as bool? ?? false,
      canImpersonate: json['can_impersonate'] as bool? ?? false,
      canDeleteAllPosts: json['can_delete_all_posts'] as bool? ?? false,
      canBeDeleted: json['can_be_deleted'] as bool? ?? false,
      canBeAnonymized: json['can_be_anonymized'] as bool? ?? false,
      canBeMerged: json['can_be_merged'] as bool? ?? false,
      canActivate: json['can_activate'] as bool? ?? false,
      canDeactivate: json['can_deactivate'] as bool? ?? false,
      canSendActivationEmail: json['can_send_activation_email'] as bool? ?? false,
      canChangeTrustLevel: json['can_change_trust_level'] as bool? ?? false,
      canDisableSecondFactor: json['can_disable_second_factor'] as bool? ?? false,
      secondFactorEnabled: json['second_factor_enabled'] as bool? ?? false,
      penaltySilenced: penalties['silenced'] as int?,
      penaltySuspended: penalties['suspended'] as int?,
      warningsReceivedCount: json['warnings_received_count'] as int? ?? 0,
      flagsReceivedCount: json['flags_received_count'] as int? ?? 0,
      flagsGivenCount: json['flags_given_count'] as int? ?? 0,
      privateTopicsCount: json['private_topics_count'] as int? ?? 0,
      // Preserve summary data
      daysVisited: daysVisited,
      postsReadCount: postsReadCount,
      topicCount: topicCount,
      postCount: postCount,
      likesGiven: likesGiven,
      likesReceived: likesReceived,
      topicsEntered: topicsEntered,
      timeRead: timeRead,
      recentTimeRead: recentTimeRead,
      topicCreatedCount: topicCreatedCount,
      topTopics: topTopics,
      topReplies: topReplies,
      topLinks: topLinks,
      mostLikedByUsers: mostLikedByUsers,
      mostLikedUsers: mostLikedUsers,
      mostRepliedToUsers: mostRepliedToUsers,
    );
  }

  bool get isSuspended =>
      suspendedTill != null && suspendedTill!.isAfter(DateTime.now());

  bool get isSilenced =>
      silencedTill != null && silencedTill!.isAfter(DateTime.now());

  /// Whether the viewing staff member can suspend this user.
  /// Discourse requires the target to NOT be staff (admin or moderator).
  bool get canSuspend => !admin && !moderator;

  /// Whether the viewing staff member can silence this user.
  /// Discourse requires the target to NOT be staff (admin or moderator).
  bool get canSilence => !admin && !moderator;

  bool get hasAdminData => email != null || ipAddress != null ||
      canGrantAdmin || canRevokeAdmin || canGrantModeration ||
      canRevokeModeration || canBeDeleted || canBeAnonymized ||
      canSuspend || canActivate || canDeactivate;

  String get trustLevelLabel => switch (trustLevel) {
    0 => 'New User',
    1 => 'Basic User',
    2 => 'Member',
    3 => 'Regular',
    4 => 'Leader',
    _ => 'Trust Level $trustLevel',
  };

  String get formattedReadTime => _formatDuration(timeRead);

  static String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours < 24) {
      return remainingMinutes > 0 ? '${hours}h ${remainingMinutes}m' : '${hours}h';
    }
    final days = hours ~/ 24;
    final remainingHours = hours % 24;
    return remainingHours > 0 ? '${days}d ${remainingHours}h' : '${days}d';
  }
}

class SummaryTopic {
  final int id;
  final String title;
  final String? slug;
  final int likeCount;
  final int postsCount;
  final int? categoryId;
  final DateTime? createdAt;

  const SummaryTopic({
    required this.id,
    required this.title,
    this.slug,
    this.likeCount = 0,
    this.postsCount = 0,
    this.categoryId,
    this.createdAt,
  });

  factory SummaryTopic.fromJson(Map<String, dynamic> json) {
    return SummaryTopic(
      id: json['id'] as int,
      title: json['title'] as String? ?? json['fancy_title'] as String? ?? '',
      slug: json['slug'] as String?,
      likeCount: json['like_count'] as int? ?? 0,
      postsCount: json['posts_count'] as int? ?? 0,
      categoryId: json['category_id'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class SummaryReply {
  final int? postNumber;
  final int likeCount;
  final DateTime? createdAt;
  final SummaryTopic? topic;

  const SummaryReply({
    this.postNumber,
    this.likeCount = 0,
    this.createdAt,
    this.topic,
  });

  factory SummaryReply.fromJson(Map<String, dynamic> json) {
    final topicJson = json['topic'] as Map<String, dynamic>?;
    return SummaryReply(
      postNumber: json['post_number'] as int?,
      likeCount: json['like_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      topic: topicJson != null ? SummaryTopic.fromJson(topicJson) : null,
    );
  }
}

class SummaryLink {
  final String url;
  final String? title;
  final int clicks;
  final int? postNumber;
  final SummaryTopic? topic;

  const SummaryLink({
    required this.url,
    this.title,
    this.clicks = 0,
    this.postNumber,
    this.topic,
  });

  factory SummaryLink.fromJson(Map<String, dynamic> json) {
    final topicJson = json['topic'] as Map<String, dynamic>?;
    return SummaryLink(
      url: json['url'] as String? ?? '',
      title: json['title'] as String?,
      clicks: json['clicks'] as int? ?? 0,
      postNumber: json['post_number'] as int?,
      topic: topicJson != null ? SummaryTopic.fromJson(topicJson) : null,
    );
  }
}

class SummaryUser {
  final int id;
  final String username;
  final String? name;
  final String? avatarTemplate;
  final int count;

  const SummaryUser({
    required this.id,
    required this.username,
    this.name,
    this.avatarTemplate,
    this.count = 0,
  });

  factory SummaryUser.fromJson(Map<String, dynamic> json) {
    return SummaryUser(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      name: json['name'] as String?,
      avatarTemplate: json['avatar_template'] as String?,
      count: json['count'] as int? ?? 0,
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
