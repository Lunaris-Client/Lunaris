import 'dart:convert';

class NotificationSettings {
  final bool enabled;
  final bool showInAppToasts;
  final bool showSystemNotifications;
  final bool quietHoursEnabled;
  final int quietHoursStart;
  final int quietHoursEnd;
  final bool filterReplies;
  final bool filterMentions;
  final bool filterLikes;
  final bool filterMessages;
  final bool filterOther;

  const NotificationSettings({
    this.enabled = true,
    this.showInAppToasts = true,
    this.showSystemNotifications = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart = 22,
    this.quietHoursEnd = 8,
    this.filterReplies = true,
    this.filterMentions = true,
    this.filterLikes = true,
    this.filterMessages = true,
    this.filterOther = true,
  });

  NotificationSettings copyWith({
    bool? enabled,
    bool? showInAppToasts,
    bool? showSystemNotifications,
    bool? quietHoursEnabled,
    int? quietHoursStart,
    int? quietHoursEnd,
    bool? filterReplies,
    bool? filterMentions,
    bool? filterLikes,
    bool? filterMessages,
    bool? filterOther,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      showInAppToasts: showInAppToasts ?? this.showInAppToasts,
      showSystemNotifications:
          showSystemNotifications ?? this.showSystemNotifications,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      filterReplies: filterReplies ?? this.filterReplies,
      filterMentions: filterMentions ?? this.filterMentions,
      filterLikes: filterLikes ?? this.filterLikes,
      filterMessages: filterMessages ?? this.filterMessages,
      filterOther: filterOther ?? this.filterOther,
    );
  }

  bool get isInQuietHours {
    if (!quietHoursEnabled) return false;
    final now = DateTime.now().hour;
    if (quietHoursStart <= quietHoursEnd) {
      return now >= quietHoursStart && now < quietHoursEnd;
    }
    // Wraps midnight (e.g., 22:00 - 08:00)
    return now >= quietHoursStart || now < quietHoursEnd;
  }

  bool shouldNotify(int notificationType) {
    if (!enabled || isInQuietHours) return false;
    return shouldShowType(notificationType);
  }

  bool shouldShowType(int notificationType) {
    const replyTypes = {2, 9};
    const mentionTypes = {1, 3, 15};
    const likeTypes = {5, 19};
    const messageTypes = {6, 7, 16};
    const chatTypes = {29, 30, 31, 32, 40};

    if (replyTypes.contains(notificationType)) return filterReplies;
    if (mentionTypes.contains(notificationType)) return filterMentions;
    if (likeTypes.contains(notificationType)) return filterLikes;
    if (messageTypes.contains(notificationType)) return filterMessages;
    if (chatTypes.contains(notificationType)) return filterMessages;
    return filterOther;
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'showInAppToasts': showInAppToasts,
    'showSystemNotifications': showSystemNotifications,
    'quietHoursEnabled': quietHoursEnabled,
    'quietHoursStart': quietHoursStart,
    'quietHoursEnd': quietHoursEnd,
    'filterReplies': filterReplies,
    'filterMentions': filterMentions,
    'filterLikes': filterLikes,
    'filterMessages': filterMessages,
    'filterOther': filterOther,
  };

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      enabled: json['enabled'] as bool? ?? true,
      showInAppToasts: json['showInAppToasts'] as bool? ?? true,
      showSystemNotifications: json['showSystemNotifications'] as bool? ?? true,
      quietHoursEnabled: json['quietHoursEnabled'] as bool? ?? false,
      quietHoursStart: json['quietHoursStart'] as int? ?? 22,
      quietHoursEnd: json['quietHoursEnd'] as int? ?? 8,
      filterReplies: json['filterReplies'] as bool? ?? true,
      filterMentions: json['filterMentions'] as bool? ?? true,
      filterLikes: json['filterLikes'] as bool? ?? true,
      filterMessages: json['filterMessages'] as bool? ?? true,
      filterOther: json['filterOther'] as bool? ?? true,
    );
  }

  String encode() => jsonEncode(toJson());

  factory NotificationSettings.decode(String raw) {
    return NotificationSettings.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }
}
