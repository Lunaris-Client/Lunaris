class Bookmark {
  final int id;
  final int bookmarkableId;
  final String bookmarkableType;
  final String? name;
  final DateTime? reminderAt;
  final bool pinned;
  final String title;
  final String? excerpt;
  final String? bookmarkableUrl;
  final int? topicId;
  final int? linkedPostNumber;
  final int? categoryId;
  final String? slug;
  final String? username;
  final String? avatarTemplate;
  final DateTime? createdAt;
  final int autoDeletePreference;

  const Bookmark({
    required this.id,
    required this.bookmarkableId,
    required this.bookmarkableType,
    this.name,
    this.reminderAt,
    this.pinned = false,
    required this.title,
    this.excerpt,
    this.bookmarkableUrl,
    this.topicId,
    this.linkedPostNumber,
    this.categoryId,
    this.slug,
    this.username,
    this.avatarTemplate,
    this.createdAt,
    this.autoDeletePreference = 0,
  });

  factory Bookmark.fromApiJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return Bookmark(
      id: json['id'] as int,
      bookmarkableId: json['bookmarkable_id'] as int? ?? 0,
      bookmarkableType: json['bookmarkable_type'] as String? ?? 'Post',
      name: json['name'] as String?,
      reminderAt: json['reminder_at'] != null
          ? DateTime.tryParse(json['reminder_at'] as String)
          : null,
      pinned: json['pinned'] as bool? ?? false,
      title: json['title'] as String? ?? json['fancy_title'] as String? ?? '',
      excerpt: json['excerpt'] as String?,
      bookmarkableUrl: json['bookmarkable_url'] as String?,
      topicId: json['topic_id'] as int?,
      linkedPostNumber: json['linked_post_number'] as int?,
      categoryId: json['category_id'] as int?,
      slug: json['slug'] as String?,
      username: user?['username'] as String?,
      avatarTemplate: user?['avatar_template'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      autoDeletePreference: json['auto_delete_preference'] as int? ?? 0,
    );
  }

  Bookmark copyWith({
    String? name,
    DateTime? reminderAt,
    bool clearReminder = false,
    bool? pinned,
    int? autoDeletePreference,
  }) {
    return Bookmark(
      id: id,
      bookmarkableId: bookmarkableId,
      bookmarkableType: bookmarkableType,
      name: name ?? this.name,
      reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
      pinned: pinned ?? this.pinned,
      title: title,
      excerpt: excerpt,
      bookmarkableUrl: bookmarkableUrl,
      topicId: topicId,
      linkedPostNumber: linkedPostNumber,
      categoryId: categoryId,
      slug: slug,
      username: username,
      avatarTemplate: avatarTemplate,
      createdAt: createdAt,
      autoDeletePreference: autoDeletePreference ?? this.autoDeletePreference,
    );
  }
}

class AutoDeletePreference {
  static const int never = 0;
  static const int whenReminderSent = 1;
  static const int onOwnerReply = 2;

  static String label(int value) {
    switch (value) {
      case whenReminderSent:
        return 'When reminder sent';
      case onOwnerReply:
        return 'On owner reply';
      default:
        return 'Never';
    }
  }
}
