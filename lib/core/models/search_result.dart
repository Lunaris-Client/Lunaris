class SearchResult {
  final List<SearchPost> posts;
  final List<SearchTopic> topics;
  final List<SearchUser> users;
  final List<SearchCategory> categories;
  final List<String> tags;

  const SearchResult({
    this.posts = const [],
    this.topics = const [],
    this.users = const [],
    this.categories = const [],
    this.tags = const [],
  });

  bool get isEmpty =>
      posts.isEmpty &&
      topics.isEmpty &&
      users.isEmpty &&
      categories.isEmpty &&
      tags.isEmpty;

  factory SearchResult.fromApiJson(Map<String, dynamic> json) {
    final posts =
        (json['posts'] as List?)
            ?.map((p) => SearchPost.fromApiJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    final topics =
        (json['topics'] as List?)
            ?.map((t) => SearchTopic.fromApiJson(t as Map<String, dynamic>))
            .toList() ??
        [];

    final users =
        (json['users'] as List?)
            ?.map((u) => SearchUser.fromApiJson(u as Map<String, dynamic>))
            .toList() ??
        [];

    final categories =
        (json['categories'] as List?)
            ?.map(
              (c) => SearchCategory.fromApiJson(c as Map<String, dynamic>),
            )
            .toList() ??
        [];

    final tags =
        (json['tags'] as List?)?.map((t) {
          if (t is Map) return t['name']?.toString() ?? '';
          return t.toString();
        }).where((t) => t.isNotEmpty).toList() ??
        [];

    return SearchResult(
      posts: posts,
      topics: topics,
      users: users,
      categories: categories,
      tags: tags,
    );
  }
}

class SearchPost {
  final int id;
  final String username;
  final String? avatarTemplate;
  final String blurb;
  final int topicId;
  final String? topicTitle;
  final int? postNumber;
  final int? likeCount;
  final DateTime? createdAt;

  const SearchPost({
    required this.id,
    required this.username,
    this.avatarTemplate,
    required this.blurb,
    required this.topicId,
    this.topicTitle,
    this.postNumber,
    this.likeCount,
    this.createdAt,
  });

  factory SearchPost.fromApiJson(Map<String, dynamic> json) {
    return SearchPost(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      avatarTemplate: json['avatar_template'] as String?,
      blurb: json['blurb'] as String? ?? '',
      topicId: json['topic_id'] as int? ?? 0,
      postNumber: json['post_number'] as int?,
      likeCount: json['like_count'] as int?,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'] as String)
              : null,
    );
  }
}

class SearchTopic {
  final int id;
  final String title;
  final String? fancyTitle;
  final String slug;
  final int postsCount;
  final int views;
  final int likeCount;
  final int categoryId;
  final DateTime? createdAt;
  final DateTime? bumpedAt;
  final bool closed;
  final bool archived;
  final List<String> tags;

  const SearchTopic({
    required this.id,
    required this.title,
    this.fancyTitle,
    required this.slug,
    this.postsCount = 0,
    this.views = 0,
    this.likeCount = 0,
    this.categoryId = 0,
    this.createdAt,
    this.bumpedAt,
    this.closed = false,
    this.archived = false,
    this.tags = const [],
  });

  factory SearchTopic.fromApiJson(Map<String, dynamic> json) {
    return SearchTopic(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      fancyTitle: json['fancy_title'] as String?,
      slug: json['slug'] as String? ?? '',
      postsCount: json['posts_count'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
      categoryId: json['category_id'] as int? ?? 0,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'] as String)
              : null,
      bumpedAt:
          json['bumped_at'] != null
              ? DateTime.tryParse(json['bumped_at'] as String)
              : null,
      closed: json['closed'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      tags:
          (json['tags'] as List?)?.map((t) => t.toString()).toList() ?? const [],
    );
  }
}

class SearchUser {
  final int id;
  final String username;
  final String? name;
  final String? avatarTemplate;

  const SearchUser({
    required this.id,
    required this.username,
    this.name,
    this.avatarTemplate,
  });

  factory SearchUser.fromApiJson(Map<String, dynamic> json) {
    return SearchUser(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      name: json['name'] as String?,
      avatarTemplate: json['avatar_template'] as String?,
    );
  }
}

class SearchCategory {
  final int id;
  final String name;
  final String slug;
  final String color;

  const SearchCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.color,
  });

  factory SearchCategory.fromApiJson(Map<String, dynamic> json) {
    return SearchCategory(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      color: json['color'] as String? ?? '0088CC',
    );
  }
}
