class Reviewable {
  final int id;
  final String type;
  final int? topicId;
  final String? topicUrl;
  final String? targetType;
  final int? targetId;
  final String? targetUrl;
  final int? categoryId;
  final DateTime createdAt;
  final double score;
  final int version;
  final int status;
  final String? cookedContent;
  final String? rawContent;
  final List<ReviewableAction> actions;
  final List<ReviewableScore> scores;
  final ReviewableUser? createdBy;
  final ReviewableUser? targetCreatedBy;

  const Reviewable({
    required this.id,
    required this.type,
    this.topicId,
    this.topicUrl,
    this.targetType,
    this.targetId,
    this.targetUrl,
    this.categoryId,
    required this.createdAt,
    this.score = 0,
    this.version = 0,
    this.status = 0,
    this.cookedContent,
    this.rawContent,
    this.actions = const [],
    this.scores = const [],
    this.createdBy,
    this.targetCreatedBy,
  });

  String get statusLabel {
    switch (status) {
      case 0:
        return 'Pending';
      case 1:
        return 'Approved';
      case 2:
        return 'Rejected';
      case 3:
        return 'Ignored';
      case 4:
        return 'Deleted';
      default:
        return 'Unknown';
    }
  }

  String get typeLabel {
    switch (type) {
      case 'ReviewableFlaggedPost':
        return 'Flagged Post';
      case 'ReviewableQueuedPost':
        return 'Queued Post';
      case 'ReviewableUser':
        return 'User';
      case 'ReviewableChatMessage':
        return 'Chat Message';
      default:
        return type.replaceAll('Reviewable', '');
    }
  }

  factory Reviewable.fromJson(
    Map<String, dynamic> json,
    Map<int, ReviewableUser> usersById,
  ) {
    final bundledActions = json['bundled_actions'] as List<dynamic>? ?? [];
    final actions = <ReviewableAction>[];
    for (final bundle in bundledActions) {
      final actionList =
          (bundle as Map<String, dynamic>)['actions'] as List<dynamic>? ?? [];
      for (final a in actionList) {
        actions.add(ReviewableAction.fromJson(a as Map<String, dynamic>));
      }
    }

    final scoresJson = json['reviewable_scores'] as List<dynamic>? ?? [];

    final createdById = json['created_by_id'] as int?;
    final targetCreatedById = json['target_created_by_id'] as int?;

    String? cooked;
    String? raw;
    final payload = json['payload'] as Map<String, dynamic>?;
    if (payload != null) {
      cooked = payload['cooked'] as String?;
      raw = payload['raw'] as String?;
    }

    return Reviewable(
      id: json['id'] as int,
      type: json['type'] as String? ?? '',
      topicId: json['topic_id'] as int?,
      topicUrl: json['topic_url'] as String?,
      targetType: json['target_type'] as String?,
      targetId: json['target_id'] as int?,
      targetUrl: json['target_url'] as String?,
      categoryId: json['category_id'] as int?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      score: (json['score'] as num?)?.toDouble() ?? 0,
      version: json['version'] as int? ?? 0,
      status: json['status'] as int? ?? 0,
      cookedContent: cooked,
      rawContent: raw,
      actions: actions,
      scores: scoresJson
          .map((s) => ReviewableScore.fromJson(s as Map<String, dynamic>))
          .toList(),
      createdBy: createdById != null ? usersById[createdById] : null,
      targetCreatedBy:
          targetCreatedById != null ? usersById[targetCreatedById] : null,
    );
  }
}

class ReviewableAction {
  final String id;
  final String? label;
  final String? icon;
  final bool requiresConfirmation;

  const ReviewableAction({
    required this.id,
    this.label,
    this.icon,
    this.requiresConfirmation = false,
  });

  factory ReviewableAction.fromJson(Map<String, dynamic> json) {
    return ReviewableAction(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ??
          json['button_class'] as String? ??
          json['id'] as String? ??
          '',
      icon: json['icon'] as String?,
      requiresConfirmation: json['require_reject_reason'] as bool? ?? false,
    );
  }
}

class ReviewableScore {
  final int id;
  final int? userId;
  final int scoreType;
  final double score;
  final DateTime? createdAt;
  final String? reason;

  const ReviewableScore({
    required this.id,
    this.userId,
    required this.scoreType,
    this.score = 0,
    this.createdAt,
    this.reason,
  });

  factory ReviewableScore.fromJson(Map<String, dynamic> json) {
    return ReviewableScore(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int?,
      scoreType: json['score_type'] as int? ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      reason: json['reason'] as String?,
    );
  }
}

class ReviewableUser {
  final int id;
  final String username;
  final String? avatarTemplate;

  const ReviewableUser({
    required this.id,
    required this.username,
    this.avatarTemplate,
  });

  factory ReviewableUser.fromJson(Map<String, dynamic> json) {
    return ReviewableUser(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      avatarTemplate: json['avatar_template'] as String?,
    );
  }
}
