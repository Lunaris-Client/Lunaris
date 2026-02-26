import 'package:freezed_annotation/freezed_annotation.dart';

part 'topic.freezed.dart';
part 'topic.g.dart';

@freezed
class Topic with _$Topic {
  const factory Topic({
    required int id,
    required String title,
    required String fancyTitle,
    required String slug,
    required int postsCount,
    @Default(0) int replyCount,
    required int highestPostNumber,
    String? imageUrl,
    required DateTime createdAt,
    DateTime? lastPostedAt,
    required DateTime bumpedAt,
    required String archetype,
    @Default(false) bool unseen,
    @Default(false) bool pinned,
    @Default(false) bool pinnedGlobally,
    @Default(false) bool visible,
    @Default(false) bool closed,
    @Default(false) bool archived,
    @Default(0) int views,
    @Default(0) int likeCount,
    required int categoryId,
    String? excerpt,
    int? lastReadPostNumber,
    @Default(0) int unreadPosts,
    int? notificationLevel,
    bool? bookmarked,
    bool? liked,
    @Default([]) List<TopicTag> tags,
    @Default([]) List<TopicPoster> posters,
    @Default([]) List<TopicThumbnail> thumbnails,
    String? lastPosterUsername,
  }) = _Topic;

  factory Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);

  factory Topic.fromApiJson(
    Map<String, dynamic> json,
    Map<int, TopicUser> usersById,
  ) {
    final posters = (json['posters'] as List<dynamic>?)
            ?.map((p) => TopicPoster.fromApiJson(
                  p as Map<String, dynamic>,
                  usersById,
                ))
            .toList() ??
        [];

    final tags = (json['tags'] as List<dynamic>?)?.map((t) {
          if (t is Map<String, dynamic>) {
            return TopicTag(
              name: t['name'] as String? ?? '',
              slug: t['slug'] as String?,
            );
          }
          return TopicTag(name: t.toString());
        }).toList() ??
        [];

    final thumbnails = (json['thumbnails'] as List<dynamic>?)
            ?.map(
                (t) => TopicThumbnail.fromApiJson(t as Map<String, dynamic>))
            .toList() ??
        [];

    return Topic(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      fancyTitle: json['fancy_title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      postsCount: json['posts_count'] as int? ?? 0,
      replyCount: json['reply_count'] as int? ?? 0,
      highestPostNumber: json['highest_post_number'] as int? ?? 0,
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastPostedAt: json['last_posted_at'] != null
          ? DateTime.parse(json['last_posted_at'] as String)
          : null,
      bumpedAt: DateTime.parse(json['bumped_at'] as String),
      archetype: json['archetype'] as String? ?? 'regular',
      unseen: json['unseen'] as bool? ?? false,
      pinned: json['pinned'] as bool? ?? false,
      pinnedGlobally: json['pinned_globally'] as bool? ?? false,
      visible: json['visible'] as bool? ?? true,
      closed: json['closed'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      views: json['views'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
      categoryId: json['category_id'] as int? ?? 0,
      excerpt: json['excerpt'] as String?,
      lastReadPostNumber: json['last_read_post_number'] as int?,
      unreadPosts: json['unread_posts'] as int? ?? 0,
      notificationLevel: json['notification_level'] as int?,
      bookmarked: json['bookmarked'] as bool?,
      liked: json['liked'] as bool?,
      tags: tags,
      posters: posters,
      thumbnails: thumbnails,
      lastPosterUsername: json['last_poster_username'] as String?,
    );
  }
}

@freezed
class TopicTag with _$TopicTag {
  const factory TopicTag({
    required String name,
    String? slug,
  }) = _TopicTag;

  factory TopicTag.fromJson(Map<String, dynamic> json) =>
      _$TopicTagFromJson(json);
}

@freezed
class TopicUser with _$TopicUser {
  const factory TopicUser({
    required int id,
    required String username,
    String? name,
    required String avatarTemplate,
    int? trustLevel,
    bool? admin,
    bool? moderator,
  }) = _TopicUser;

  factory TopicUser.fromJson(Map<String, dynamic> json) =>
      _$TopicUserFromJson(json);

  factory TopicUser.fromApiJson(Map<String, dynamic> json) {
    return TopicUser(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      name: json['name'] as String?,
      avatarTemplate: json['avatar_template'] as String? ?? '',
      trustLevel: json['trust_level'] as int?,
      admin: json['admin'] as bool?,
      moderator: json['moderator'] as bool?,
    );
  }
}

@freezed
class TopicPoster with _$TopicPoster {
  const factory TopicPoster({
    String? extras,
    required String description,
    required int userId,
    TopicUser? user,
  }) = _TopicPoster;

  factory TopicPoster.fromJson(Map<String, dynamic> json) =>
      _$TopicPosterFromJson(json);

  factory TopicPoster.fromApiJson(
    Map<String, dynamic> json,
    Map<int, TopicUser> usersById,
  ) {
    final userId = json['user_id'] as int;
    return TopicPoster(
      extras: json['extras'] as String?,
      description: json['description'] as String? ?? '',
      userId: userId,
      user: usersById[userId],
    );
  }
}

@freezed
class TopicThumbnail with _$TopicThumbnail {
  const factory TopicThumbnail({
    int? maxWidth,
    int? maxHeight,
    required int width,
    required int height,
    required String url,
  }) = _TopicThumbnail;

  factory TopicThumbnail.fromJson(Map<String, dynamic> json) =>
      _$TopicThumbnailFromJson(json);

  factory TopicThumbnail.fromApiJson(Map<String, dynamic> json) {
    return TopicThumbnail(
      maxWidth: json['max_width'] as int?,
      maxHeight: json['max_height'] as int?,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      url: json['url'] as String? ?? '',
    );
  }
}

@freezed
class TopicListResponse with _$TopicListResponse {
  const factory TopicListResponse({
    required List<Topic> topics,
    required Map<int, TopicUser> users,
    String? moreTopicsUrl,
    @Default(false) bool canCreateTopic,
    int? perPage,
  }) = _TopicListResponse;

  factory TopicListResponse.fromJson(Map<String, dynamic> json) =>
      _$TopicListResponseFromJson(json);

  factory TopicListResponse.fromApiJson(Map<String, dynamic> json) {
    final usersById = <int, TopicUser>{};
    for (final u in (json['users'] as List<dynamic>?) ?? []) {
      final user = TopicUser.fromApiJson(u as Map<String, dynamic>);
      usersById[user.id] = user;
    }

    final topicList = json['topic_list'] as Map<String, dynamic>? ?? {};
    final topics = (topicList['topics'] as List<dynamic>?)
            ?.map((t) => Topic.fromApiJson(
                  t as Map<String, dynamic>,
                  usersById,
                ))
            .toList() ??
        [];

    return TopicListResponse(
      topics: topics,
      users: usersById,
      moreTopicsUrl: topicList['more_topics_url'] as String?,
      canCreateTopic: topicList['can_create_topic'] as bool? ?? false,
      perPage: topicList['per_page'] as int?,
    );
  }
}
