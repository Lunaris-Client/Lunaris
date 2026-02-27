import 'package:freezed_annotation/freezed_annotation.dart';

part 'server_account.freezed.dart';
part 'server_account.g.dart';

@freezed
class ServerAccount with _$ServerAccount {
  const factory ServerAccount({
    required String id,
    required String serverUrl,
    required String siteName,
    String? siteLogoUrl,
    String? siteDescription,
    String? faviconUrl,
    String? clientId,
    String? username,
    int? userId,
    String? avatarTemplate,
    int? trustLevel,
    @Default(false) bool isAdmin,
    @Default(false) bool isModerator,
    DateTime? lastSyncedAt,
    int? notificationChannelPosition,
    @Default(false) bool isAuthenticated,
  }) = _ServerAccount;

  factory ServerAccount.fromJson(Map<String, dynamic> json) =>
      _$ServerAccountFromJson(json);
}
