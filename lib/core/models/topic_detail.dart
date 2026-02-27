import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lunaris/core/models/post.dart';

part 'topic_detail.freezed.dart';
part 'topic_detail.g.dart';

@freezed
class TopicDetail with _$TopicDetail {
  const factory TopicDetail({
    required int id,
    required String title,
    required String fancyTitle,
    required String slug,
    required int postsCount,
    @Default(0) int replyCount,
    required int highestPostNumber,
    required int categoryId,
    required DateTime createdAt,
    DateTime? lastPostedAt,
    @Default(false) bool pinned,
    @Default(false) bool closed,
    @Default(false) bool archived,
    @Default(false) bool visible,
    @Default(false) bool bookmarked,
    @Default(0) int likeCount,
    @Default(0) int views,
    int? notificationLevel,
    int? lastReadPostNumber,
    @Default([]) List<String> tags,
    @Default([]) List<int> postStream,
    @Default([]) List<Post> posts,
    String? categorySlug,
    int? currentPostNumber,
    int? acceptedAnswerPostNumber,
    String? acceptedAnswerUsername,
    @Default(0) int voteCount,
    @Default(false) bool canVote,
    @Default(false) bool userVoted,
    DateTime? eventStartsAt,
    DateTime? eventEndsAt,
  }) = _TopicDetail;

  factory TopicDetail.fromJson(Map<String, dynamic> json) =>
      _$TopicDetailFromJson(json);

  factory TopicDetail.fromApiJson(Map<String, dynamic> json) {
    final postStreamData =
        json['post_stream'] as Map<String, dynamic>? ?? {};
    final streamIds = (postStreamData['stream'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        [];
    final loadedPosts = (postStreamData['posts'] as List<dynamic>?)
            ?.map((p) => Post.fromApiJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    final tags = (json['tags'] as List<dynamic>?)
            ?.map((t) => t.toString())
            .toList() ??
        [];

    final acceptedAnswer = json['accepted_answer'] as Map<String, dynamic>?;

    return TopicDetail(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      fancyTitle: json['fancy_title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      postsCount: json['posts_count'] as int? ?? 0,
      replyCount: json['reply_count'] as int? ?? 0,
      highestPostNumber: json['highest_post_number'] as int? ?? 0,
      categoryId: json['category_id'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastPostedAt: json['last_posted_at'] != null
          ? DateTime.parse(json['last_posted_at'] as String)
          : null,
      pinned: json['pinned'] as bool? ?? false,
      closed: json['closed'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      visible: json['visible'] as bool? ?? true,
      bookmarked: json['bookmarked'] as bool? ?? false,
      likeCount: json['like_count'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
      notificationLevel: json['notification_level'] as int?,
      lastReadPostNumber: json['last_read_post_number'] as int?,
      tags: tags,
      postStream: streamIds,
      posts: loadedPosts,
      categorySlug: json['category_slug'] as String?,
      currentPostNumber: json['current_post_number'] as int?,
      acceptedAnswerPostNumber: acceptedAnswer?['post_number'] as int?,
      acceptedAnswerUsername: acceptedAnswer?['username'] as String?,
      voteCount: json['vote_count'] as int? ?? 0,
      canVote: json['can_vote'] as bool? ?? false,
      userVoted: json['user_voted'] as bool? ?? false,
      eventStartsAt: json['event_starts_at'] != null
          ? DateTime.tryParse(json['event_starts_at'] as String)
          : null,
      eventEndsAt: json['event_ends_at'] != null
          ? DateTime.tryParse(json['event_ends_at'] as String)
          : null,
    );
  }
}
