import 'package:freezed_annotation/freezed_annotation.dart';

part 'discourse_notification.freezed.dart';
part 'discourse_notification.g.dart';

@freezed
class DiscourseNotification with _$DiscourseNotification {
  const factory DiscourseNotification({
    required int id,
    required int notificationType,
    required bool read,
    required DateTime createdAt,
    int? topicId,
    int? postNumber,
    String? slug,
    String? fancyTitle,
    String? actingUserAvatarTemplate,
    String? actingUserName,
    required NotificationData data,
  }) = _DiscourseNotification;

  factory DiscourseNotification.fromJson(Map<String, dynamic> json) =>
      _$DiscourseNotificationFromJson(json);

  factory DiscourseNotification.fromApiJson(Map<String, dynamic> json) {
    final dataJson = json['data'] as Map<String, dynamic>? ?? {};
    return DiscourseNotification(
      id: json['id'] as int,
      notificationType: json['notification_type'] as int,
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      topicId: json['topic_id'] as int?,
      postNumber: json['post_number'] as int?,
      slug: json['slug'] as String?,
      fancyTitle: json['fancy_title'] as String?,
      actingUserAvatarTemplate:
          json['acting_user_avatar_template'] as String?,
      actingUserName: json['acting_user_name'] as String?,
      data: NotificationData(
        displayUsername: dataJson['display_username'] as String?,
        originalUsername: dataJson['original_username'] as String?,
        originalPostId: dataJson['original_post_id'] as int?,
        originalPostType: dataJson['original_post_type'] as int?,
        topicTitle: dataJson['topic_title'] as String?,
        badgeName: dataJson['badge_name'] as String?,
        badgeId: dataJson['badge_id'] as int?,
        badgeSlug: dataJson['badge_slug'] as String?,
        groupName: dataJson['group_name'] as String?,
        count: dataJson['count'] as int?,
        chatChannelId: dataJson['chat_channel_id'] as int?,
        chatMessageId: dataJson['chat_message_id'] as int?,
        chatThreadId: dataJson['chat_thread_id'] as int?,
        chatChannelTitle: dataJson['chat_channel_title'] as String?,
        chatChannelSlug: dataJson['chat_channel_slug'] as String?,
        isDirectMessageChannel:
            dataJson['is_direct_message_channel'] as bool?,
        mentionedByUsername:
            dataJson['mentioned_by_username'] as String?,
        invitedByUsername:
            dataJson['invited_by_username'] as String?,
        username: dataJson['username'] as String?,
      ),
    );
  }
}

@freezed
class NotificationData with _$NotificationData {
  const factory NotificationData({
    String? displayUsername,
    String? originalUsername,
    int? originalPostId,
    int? originalPostType,
    String? topicTitle,
    String? badgeName,
    int? badgeId,
    String? badgeSlug,
    String? groupName,
    int? count,
    int? chatChannelId,
    int? chatMessageId,
    int? chatThreadId,
    String? chatChannelTitle,
    String? chatChannelSlug,
    bool? isDirectMessageChannel,
    String? mentionedByUsername,
    String? invitedByUsername,
    String? username,
  }) = _NotificationData;

  factory NotificationData.fromJson(Map<String, dynamic> json) =>
      _$NotificationDataFromJson(json);
}

abstract class NotificationType {
  static const mentioned = 1;
  static const replied = 2;
  static const quoted = 3;
  static const edited = 4;
  static const liked = 5;
  static const privateMessage = 6;
  static const invitedToPrivateMessage = 7;
  static const inviteeAccepted = 8;
  static const posted = 9;
  static const movedPost = 10;
  static const linked = 11;
  static const grantedBadge = 12;
  static const invitedToTopic = 13;
  static const custom = 14;
  static const groupMentioned = 15;
  static const groupMessageSummary = 16;
  static const watchingFirstPost = 17;
  static const topicReminder = 18;
  static const likedConsolidated = 19;
  static const postApproved = 20;
  static const codeReviewCommitApproved = 21;
  static const membershipRequestAccepted = 22;
  static const membershipRequestConsolidated = 23;
  static const bookmarkReminder = 24;
  static const reaction = 25;
  static const votesReleased = 26;
  static const eventReminder = 27;
  static const eventInvitation = 28;
  static const chatMention = 29;
  static const chatMessage = 30;
  static const chatInvitation = 31;
  static const chatGroupMention = 32;
  static const chatWatchedThread = 33;
  static const assignedToPost = 34;
  static const followingCreatedTopic = 800;
  static const followingReplied = 801;
}
