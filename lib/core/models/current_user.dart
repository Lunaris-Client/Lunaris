import 'package:freezed_annotation/freezed_annotation.dart';

part 'current_user.freezed.dart';
part 'current_user.g.dart';

@freezed
class CurrentUser with _$CurrentUser {
  const factory CurrentUser({
    required int id,
    required String username,
    String? name,
    @JsonKey(name: 'avatar_template') String? avatarTemplate,
    @JsonKey(name: 'trust_level') int? trustLevel,
    @JsonKey(name: 'admin') @Default(false) bool isAdmin,
    @JsonKey(name: 'moderator') @Default(false) bool isModerator,
    @JsonKey(name: 'unread_notifications') @Default(0) int unreadNotifications,
    @JsonKey(name: 'unread_high_priority_notifications')
    @Default(0)
    int unreadHighPriorityNotifications,
    String? title,
  }) = _CurrentUser;

  factory CurrentUser.fromJson(Map<String, dynamic> json) =>
      _$CurrentUserFromJson(json);
}
