import 'package:freezed_annotation/freezed_annotation.dart';

part 'post.freezed.dart';
part 'post.g.dart';

@freezed
class Post with _$Post {
  const factory Post({
    required int id,
    required int postNumber,
    required String username,
    String? name,
    String? avatarTemplate,
    required String cooked,
    required DateTime createdAt,
    DateTime? updatedAt,
    int? replyToPostNumber,
    @Default(0) int replyCount,
    @Default(0) int quoteCount,
    @Default(0) int likeCount,
    @Default(0) int reads,
    @Default(0) int score,
    @Default(false) bool yours,
    @Default(0) int topicId,
    int? userId,
    String? userTitle,
    int? trustLevel,
    @Default(false) bool admin,
    @Default(false) bool moderator,
    @Default(false) bool staff,
    @Default(false) bool hidden,
    @Default(false) bool wiki,
    @Default(false) bool canEdit,
    @Default(false) bool canDelete,
    @Default(false) bool canRecover,
    @Default(false) bool canWiki,
    @Default(false) bool bookmarked,
    int? bookmarkId,
    @Default(false) bool read,
    String? flairName,
    String? flairUrl,
    String? flairBgColor,
    String? flairColor,
    @Default([]) List<PostActionSummary> actionsSummary,
    @Default(false) bool acceptedAnswer,
    @Default(false) bool canAcceptAnswer,
    @Default(false) bool canUnacceptAnswer,
  }) = _Post;

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);

  factory Post.fromApiJson(Map<String, dynamic> json) {
    final actions =
        (json['actions_summary'] as List<dynamic>?)
            ?.map(
              (a) => PostActionSummary.fromApiJson(a as Map<String, dynamic>),
            )
            .toList() ??
        [];

    return Post(
      id: json['id'] as int,
      postNumber: json['post_number'] as int,
      username: json['username'] as String? ?? '',
      name: json['name'] as String?,
      avatarTemplate: json['avatar_template'] as String?,
      cooked: json['cooked'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : null,
      replyToPostNumber: json['reply_to_post_number'] as int?,
      replyCount: json['reply_count'] as int? ?? 0,
      quoteCount: json['quote_count'] as int? ?? 0,
      likeCount:
          json['actions_summary'] != null
              ? _extractLikeCount(json['actions_summary'] as List)
              : 0,
      reads: json['reads'] as int? ?? 0,
      score: (json['score'] as num?)?.toInt() ?? 0,
      yours: json['yours'] as bool? ?? false,
      topicId: json['topic_id'] as int? ?? 0,
      userId: json['user_id'] as int?,
      userTitle: json['user_title'] as String?,
      trustLevel: json['trust_level'] as int?,
      admin: json['admin'] as bool? ?? false,
      moderator: json['moderator'] as bool? ?? false,
      staff: json['staff'] as bool? ?? false,
      hidden: json['hidden'] as bool? ?? false,
      wiki: json['wiki'] as bool? ?? false,
      canEdit: json['can_edit'] as bool? ?? false,
      canDelete: json['can_delete'] as bool? ?? false,
      canRecover: json['can_recover'] as bool? ?? false,
      canWiki: json['can_wiki'] as bool? ?? false,
      bookmarked: json['bookmarked'] as bool? ?? false,
      bookmarkId: json['bookmark_id'] as int?,
      read: json['read'] as bool? ?? false,
      flairName: json['flair_name'] as String?,
      flairUrl: json['flair_url'] as String?,
      flairBgColor: json['flair_bg_color'] as String?,
      flairColor: json['flair_color'] as String?,
      actionsSummary: actions,
      acceptedAnswer: json['accepted_answer'] as bool? ?? false,
      canAcceptAnswer: json['can_accept_answer'] as bool? ?? false,
      canUnacceptAnswer: json['can_unaccept_answer'] as bool? ?? false,
    );
  }
}

int _extractLikeCount(List actions) {
  for (final a in actions) {
    if (a is Map && a['id'] == 2) return (a['count'] as int?) ?? 0;
  }
  return 0;
}

@freezed
class PostActionSummary with _$PostActionSummary {
  const factory PostActionSummary({
    required int id,
    @Default(0) int count,
    @Default(false) bool acted,
    @Default(false) bool canAct,
    @Default(false) bool canUndo,
  }) = _PostActionSummary;

  factory PostActionSummary.fromJson(Map<String, dynamic> json) =>
      _$PostActionSummaryFromJson(json);

  factory PostActionSummary.fromApiJson(Map<String, dynamic> json) {
    return PostActionSummary(
      id: json['id'] as int,
      count: json['count'] as int? ?? 0,
      acted: json['acted'] as bool? ?? false,
      canAct: json['can_act'] as bool? ?? false,
      canUndo: json['can_undo'] as bool? ?? false,
    );
  }
}
